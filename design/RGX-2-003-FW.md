# ReGenX v2 — Firmware Architecture

**Document** RGX-2-003 **Rev E** · against RGX-2-001 Rev E / RGX-2-100 Rev F /
RGX-2-002 Rev A · 2026-09-29

Rev E describes the firmware as built in `firmware/`. Earlier revisions (the
Rev B decision register, Rev C/D amendments) are in the git history; the
reasoning behind each change is in `research/decisions.md`.

## 1. Overview

Every 10 ms, core 0 reads the VESC's latest reply, the wheel speed and the
throttle, computes carrier slip, decides a motor current, clamps it, and sends
it with the next telemetry request. Core 1 draws the display at 5 Hz. Nothing
is logged and nothing is written to flash.

| File | Lines | Role |
|---|---|---|
| `config.py` | 85 | Every constant; `[BENCH]` = placeholder until measured |
| `control.py` | 111 | The tick: slip, regen law, envelope, snapshot for the display |
| `vesc.py` | 126 | VESC UART protocol: frames, CRC, parser, per-tick schedule |
| `sensors.py` | 126 | Wheel speed (PIO) and throttle (ADC) |
| `ui.py` | 90 | Display on core 1 |
| `main.py` | 50 | Wiring, core-1 launch, fixed-rate loop, watchdog |

## 2. Platform

Raspberry Pi Pico (RP2040), **MicroPython v1.29.0**, pinned (`tools/deploy.sh`
warns on any other version; CI compiles against the same release). Core 0 runs
only control; core 1 runs only the display, so display I/O cannot delay the
VESC link. MicroPython's RP2040 threads run without a global lock, so both
cores allocate from one heap concurrently.

## 3. Control (`control.py`)

**Run flag.** Current is commanded only while the link has delivered
`LINK_RECOVER_FRAMES` (10) consecutive clean replies with VESC fault code 0.
Otherwise the command is 0 A. Recovery is automatic.

**Slip.** `s = 1 − ERPM / (POLE_PAIRS · K_RATIO · wheel_rpm)`, clamped to
[0, 1]: 1 = carrier freewheeling, 0 = carrier held. Below `W_MIN_RPM` (24 rpm,
≈ 3 km/h) slip reads 1. Only the product `POLE_PAIRS · K_RATIO` is used; during
assist the clutch holds the carrier, so `ERPM = POLE_PAIRS · K_RATIO ·
wheel_rpm` exactly.

**Regen law** (`request()`). Throttle > 0 commands assist,
`I_ASSIST_MAX × throttle`, and ends regen. Otherwise a velocity-form PI on the
slip error `e = SLIP_SET − s` (`SLIP_SET` 0.12):

```
regen = |regen sent last tick| + SLIP_KP·Δe + SLIP_KI·e·dt,  clamped to [0, I_REGEN_MAX]
```

Regen grows while the carrier is held (s < 0.12) until it just slips, so the
braking torque follows the lever; with the carrier released (s → 1) regen falls
to 0. The velocity form works from the current actually sent, so nothing winds
up while the envelope clamps. Below `W_MIN_RPM`, e is at its minimum and regen
can only fall.

**Envelope** (`envelope()`). Current builds by at most `SLEW_STEP_A` (2 A) per
tick; any reduction, including a reversal, is immediate. The result is clamped
so the VESC's terminal voltage stays within [`V_TERM_MIN`, `V_TERM_MAX`] =
[9, 39] V, using the open-circuit estimate `v_oc = v_in + i_in·R_BANK`. The
clamp only shrinks the current and never flips its sign.

**Sign convention.** The VESC's motor direction is set so +current drives the
wheel forward (`tools/A1-SETUP.md` item 4). ERPM is then ≥ 0 whenever torque
flows: + amps = assist, − amps = regen.

**Latency.** Slip onset is seen one to two wheel-sensor pulses late (63–126 ms
at 20 km/h); regen then builds at `SLEW_STEP_A` per tick (0.2 s to 40 A).

## 4. VESC link (`vesc.py`)

UART0, GP0/GP1, 115200 baud, 1 KB receive buffer. Each tick sends one buffer:
`COMM_SET_CURRENT` (milliamps) followed by `COMM_GET_VALUES_SELECTIVE` with
mask `0x818D` (FET temperature, motor current, input current, ERPM, input
voltage, fault code). The 27-byte reply is read at the start of the next tick.
Wire use: about 17 % of transmit and 23 % of receive capacity.

**Timeouts.** The current command is also the keepalive. The VESC's UART app
timeout (200 ms, brake current 0) releases the motor if commands stop. On the
Pico side, 25 ticks (250 ms) without a clean reply clears the run flag.

**Parser.** Accepts only the one reply: start byte 2, length 22, command 50,
CRC16-XMODEM, end byte 3. Anything else is skipped a byte at a time; a
candidate that fails its CRC or end byte counts as a bad frame. Because every
reply has the same length, an incomplete candidate at the end of the buffer
is always the last one, and the tail is kept for the next tick.

## 5. Sensors (`sensors.py`)

**Wheel.** A PIO state machine at 2 MHz times each high and low phase of the
6-pulse-per-revolution shell sensor, in microseconds. Any two consecutive
phases make one period, so the speed updates at every edge. Phases under
3 ms are rejected as noise. Between edges the speed is capped by the time
since the last edge; below 10 rpm it reads 0. A phase cut short by noise can
read up to 2× for one or two samples; C6 (10 nF) filters microsecond spikes.

**Throttle.** ADC0 (GP26) through R7. Readings outside 0.20–0.85 of the supply
read 0 and disarm assist. Assist arms only after the throttle reads idle, at
power-on and after any out-of-window reading. Scaling uses `THR_IDLE` and
`THR_FULL` with a 5 % deadband.

## 6. Display (`ui.py`)

SSD1306 on I²C0 at 400 kHz, redrawn every 200 ms from a snapshot array that
core 0 writes each tick. Three lines: speed (km/h), bank voltage, and the motor
current the VESC measures. Below them, up to three problem lines, most serious
first:

| Line | Meaning |
|---|---|
| `NO LINK` | No clean reply for 250 ms, or still counting clean replies after one; 0 A commanded |
| `VESC FAULT n` | VESC fault code `n`; 0 A until 10 clean replies after it clears |
| `HOT t C` / `COLD t C` | VESC transistor temperature above `TEMP_HOT` (80 °C) or below `TEMP_COLD` (−10 °C). Display only |
| `BAD FRAMES n` | Corrupted replies since power-on |
| `LATE TICKS n` | Control ticks that overran 10 ms since power-on |
| `SCREEN ERR n` | Display errors since power-on; the display is reinitialised after each |

## 7. Main loop and failure behaviour (`main.py`)

Fixed rate on `ticks_ms`: a late tick is counted and the schedule realigned,
never run twice in a row. `gc.collect()` runs every 10 ticks. A 2 s watchdog is
armed after start-up. If the script stops before that, the Pico sits at the
REPL and the VESC's 200 ms timeout releases the motor. A file `/nomain` on the
Pico skips `run()` at boot; `tools/deploy.sh` uses it to copy files past the
watchdog.

## 8. Constants

All in `config.py`. Measured values are still needed for these `[BENCH]`
constants: `K_RATIO`, `POLE_PAIRS`, `WHEEL_CIRC_M`, `SLIP_SET`, `SLIP_KP`,
`SLIP_KI`, `R_BANK` (bank ESR plus wiring; the voltage clamp assumes it is at
least the true value), `THR_IDLE`, `THR_FULL`, `TEMP_HOT`, `TEMP_COLD`. The
current limits `I_ASSIST_MAX` / `I_REGEN_MAX` (40 A) mirror the VESC's
configured limits.

## 9. Tests

`tests/` runs under CPython with stand-ins for the hardware. Control is
exercised through a plant model of the planetary and clutch (assist, coasting,
braking against a friction band of set grip, bank near full, link loss, VESC
faults). The parser is tested against every single-bit error in a reply and
200 random garbage streams. CI also compiles every firmware file with
`mpy-cross` for the RP2040.

## 10. Not yet verified on hardware

- `main.py`, the PIO program, the SSD1306 driver and the UART settings (not
  covered by host tests).
- The reply layout against the real VESC (the tests use their own encoder).
- Tick time and garbage-collection pauses on the RP2040 (`LATE TICKS`).
- Two-core stability over long runs.
- Link integrity under motor current steps with the Rev F grounding
  (`BAD FRAMES`).
- Every `[BENCH]` value, and the regen behaviour, which needs the carrier brake.

## Sources

- [VESC UART protocol](https://vedderb-bldc.mintlify.app/communication/uart-protocol)
- [VESC firmware changelog](https://github.com/vedderb/bldc/blob/master/CHANGELOG.md)
- [MicroPython for the Raspberry Pi Pico](https://micropython.org/download/RPI_PICO/)
