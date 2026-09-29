# Components: motor and motor controller

Why the Bafang G020 and the Flipsky Mini FSESC4.20, and the facts about them
the design depends on. Selection dates and reasoning are in `decisions.md`.

---

## 1. Motor: Bafang G020

**Requirements:** rear hub, single-stage planetary, a reachable carrier, motor
halls, and a multi-pulse shell speed sensor.

**Topology.** In a geared hub motor the ring teeth are part of the shell, so the
arrangement is fixed:

```
sun     = motor rotor               (input)
ring    = hub shell = wheel         (output)
carrier = one-way clutch to axle    (reaction member)
k       = Z_ring / Z_sun            (G020 "5:1" → k ≈ 5)
```

The clutch holds the carrier against **backward** rotation, which makes motoring
work, and lets it overrun **forward**, which makes coasting free. The carrier
brake has to resist the forward direction, the one the clutch does not.

**Known data.**

| | G020 |
|---|---|
| Planetary | Single stage, ~5:1, nylon planet gears |
| Torque rating | ~45 N·m at the wheel |
| Rotor | 20 magnets (10 pole pairs) |
| Speed | No load 245 rpm at 36 V (325 rpm at 48 V: the same winding, ≈ 6.8 wheel-rpm/V); rated 205 rpm at 36 V |
| Flux linkage | ≈ 16.2 mWb: line-to-line back-EMF equals 36 V at the no-load speed, `λ = V / (√3·ω_e)` |
| Phase resistance | ≈ 0.25 Ω: about 0.5 Ω between any two phase wires is reported for the SWX02. The droop from no-load to rated speed at 80 % efficiency gives ≈ 0.34 Ω, an upper bound since it includes controller and wiring drops |
| Efficiency | ≥ 80 % (Bafang) |
| Motor speed | Three halls on the rotor, read by the VESC |
| Wheel speed | 6 magnets in the case read by a Honeywell SS43F, on the white wire (confirmed for SWX02 / RM G020; KT controllers use `P2 = 6` for it) |
| Cable | One 9-pin Higo Z910: three phases, 5 V, ground, three halls, white speed wire |

The shell sensor reads the shell, not the rotor: hall speed drops to zero while
coasting because the clutch disengages the rotor, which is why hub makers add
it.

**Alternatives.** The Bafang G310/G311 are ruled out: double-stage planets, two
carriers, no single member to brake. The Shengyi SX2 (single stage, 4.78:1,
helical steel gears, 15 pole pairs, documented by Grin Technologies) fits
technically but costs more; the G020 is cheaper and serves as the teardown
motor. On the SX hubs, disc bolts that are too long reach the clutch, so the
clutch sits just behind the disc-side plate. That is a hint about carrier
access, not confirmed for the G020.

**What 6 pulses per revolution means for slip.** At 200 wheel rpm there are
50 ms between edges. Slip is a difference between two numbers near 960 rpm, so
that staleness sets a floor on a usable slip setpoint:

| Slip setpoint | Signal | Error from 50 ms staleness |
|---|---|---|
| 5 % | 48 rpm | ~70 %, unusable |
| 10 % | 96 rpm | ~35 %, marginal |
| 15 % | 144 rpm | ~24 %, workable |

`SLIP_SET` is 0.12. Since the heat fraction equals the slip, that still recovers
about 88 % of the braking energy. Finer resolution would need more magnets in
the side cover, or a sensor on the carrier itself.

---

## 2. Motor controller: Flipsky Mini FSESC4.20

VESC 4.12-class board: 8–60 V, 50 A continuous / 150 A peak, sensored FOC, 5 V
1.5 A BEC, 3.3 V UART, 80 g, 67 × 39 × 18 mm.

**What it has to do.** Accept a commanded current, positive for assist and
negative for regen, at 100 Hz or more; run sensored FOC down to low speed; run
from a bank that swings between about 9 and 40 V, which means starting at a low
voltage, a low-voltage cutoff that can be set very low, and at least 50 V
maximum; and have configurable regen current and voltage limits.

**Why this one.** The minimum voltage filters out most of the field:

| Controller | Range | Minimum |
|---|---|---|
| **Flipsky Mini FSESC4.20** (owned) | 8–60 V | **8 V** |
| Flipsky FSESC 6.6 | 8–60 V | 8 V |
| Trampa VESC 6 MkVI | 8–60 V | 8 V |
| Flipsky 75100 / Ubox 85 V | 14–84 V | 14 V |
| Grin Baserunner V6 | 19–60 V | 19 V |
| Grin Phaserunner V6 | 24–72 V | 24 V |

Every VESC bottoms out at 8 V, where its front-end supply stops. The DRV8323's
6 V figure is the gate driver's lockout, not the board's. A 4S keep-alive pack
reaches about 16 V through its blocking diode, so the 19 V and 24 V floors
would need a boost converter back in the precharge path. With the floor equal
across the VESC family, the owned Mini was kept. A VESC 6-class board would add
three-shunt current sensing, the DRV8323 gate driver and 60 A continuous.

**Ratings.** 50 A continuous is optimistic for an 80 g board without airflow;
about 20–30 A is realistic. The duty is short boosts and braking events, so the
150 A peak governs. The DRV8302 gate driver is this generation's usual failure
point.

**How the VESC regenerates** (from the firmware source, vedderb/bldc 6.06:
`motor/mcpwm_foc.c`, `motor/mc_interface.c`, `comm/timeout.c`).

- **Charging.** There is no separate boost mode. The FOC current loop settles at
  `vq ≈ λ·ω_e − R·|iq|`, so the bridge and the phase inductance act as a
  synchronous boost converter: the bank charges at any voltage above the
  motor's back-EMF, with no minimum speed.
- **Direction.** `SET_CURRENT` is signed torque. A negative current brakes a
  forward-turning rotor, but at or near standstill it drives the rotor
  backward. `SET_CURRENT_BRAKE` always opposes the rotation and never motors,
  but it is not purely regenerative: it shorts all three phases (duty 0)
  whenever speed or `vq` changes sign, at near-zero duty, and at the start of
  braking until the current reaches the set value, and while shorted the
  energy goes into the windings as heat. The firmware uses negative
  `SET_CURRENT` (RGX-2-003 §3).
- **Release.** Any command below `cc_min_current` (0.05 A), including 0 A, stops
  switching within about 1 ms: all six FETs off. The UART timeout and every
  fault do the same. The phases are never shorted unless
  `foc_short_ls_on_zero_duty` is set (off by default).
- **Limits**, computed at 1 kHz from the filtered input voltage:

| Setting | Acts on |
|---|---|
| Motor Current Max Brake | Regen phase current (torque); derated only by temperature |
| Battery Current Max Regen | Charge current, converted to phase current as `I_bus ≈ mod_q·iq`. Next to a ±40 A motor limit it never binds |
| Battery regen cut start / end | Since 6.05. Tapers the charge-current limit to 0 between the two voltages. Default 1000 / 1100 V, i.e. off |
| Max input voltage | Not a limit but a fault: sustained excess raises fault 1 (over-voltage) |
| Battery cut start / end | Tapers assist only; regen is unaffected |

- **Faults.** On any fault the VESC stops switching, ignores commands for
  500 ms (re-armed if the fault recurs), then clears it by itself; the next
  command restarts the motor. Codes: 1 over-voltage, 2 under-voltage,
  3 gate driver, 4 absolute over-current (130 A default), 5 FET
  over-temperature, 6 motor over-temperature, 7–8 gate-driver supply,
  9 MCU under-voltage, 10 watchdog reset.
- **Telemetry.** `current_motor` is the average since the last read of the
  total dq current magnitude, signed by power flow (negative in regen), and 0
  while released. `current_in` is estimated (this board has no DC current
  sensor), negative while charging. `rpm` is electrical RPM. `v_in` is
  low-pass filtered. Any other reader, such as VESC Tool, resets the averages.
- v1's ride logs (in the archived repository) show regen reaching 40 A on this
  board.

**Power peak at low speed.** In the VESC's FOC model (amplitude-invariant, R per
phase, `P = 1.5·(vd·id + vq·iq)`), regen current I takes
`1.5·λ·ω_e·I` from the shaft and loses `1.5·R·I²` in the windings (λ = flux
linkage, ω_e = electrical speed, R = phase resistance), so the bank receives
`1.5·I·(λ·ω_e − R·I)`. That peaks at `I = λ·ω_e/(2R)` and reaches zero at
`I = λ·ω_e/R`; beyond that the controller draws from the bank to brake. With the
G020 constants above (λ = 0.0162 Wb, R = 0.25 Ω, 10 pole pairs, k = 5):

| Speed | λ·ω_e | Peak-power current | Net-zero current | Firmware cap (30 % yield) |
|---|---|---|---|---|
| 3 km/h | 2.0 V | 4 A | 8 A | 5.3 A |
| 10 km/h | 6.7 V | 13 A | 27 A | 18 A |
| 20 km/h | 13.5 V | 27 A | 54 A | 35 A |
| 25 km/h | 16.8 V | 34 A | 67 A | 40 A (`I_REGEN_MAX`) |

The firmware caps regen so at least 30 % of the braking energy reaches the bank
(RGX-2-003 §3, yield limit).

**Above the bank voltage.** The bridge can oppose at most about
`0.95·Vbus/√3` of peak phase back-EMF (`l_max_duty` 0.95). Beyond that:

- **While switching,** the current loop saturates and the rotor brakes harder
  than commanded, at roughly `(vq_max − λ·ω_e)/R`; a smaller command cannot
  reduce it.
- **With the bridge off** (0 A, timeout, fault), the body diodes rectify
  whenever the line-to-line back-EMF `√3·λ·ω_e` exceeds the bank voltage. The
  firmware's own comment: the diodes "can see a lot of current and unexpected
  braking happens".
- **Field weakening** (`foc_fw_current_max`, 0 = off by default) injects
  negative d-axis current above about 85 % duty, in regen as well as assist,
  which lowers the voltage needed and can keep control above the crossover if
  the configured current is large enough. The firmware does not check that it
  is.

With kV ≈ 6.8 wheel-rpm/V the diode crossover is about 10.9 km/h at the 12.7 V
resting bank, 34 km/h at 40 V and 39 km/h at the 45.4 V absolute ceiling; the
switching limit is about 5 % lower (spec §9 bank-overvoltage caveat, §11
item 2). These only occur with the carrier held, since a freewheeling carrier
leaves the rotor still. Telemetry mask bit 6 (duty) reaches 0.95 at the
switching limit.

---

## 3. Open

- CAN on this board: unconfirmed (it may be pads only or absent).
- Minimum start-up voltage, rising and falling (spec §11 item 3).
- G020 kV and phase resistance (spec §11 item 2): they fix the crossover speed
  and the power-peak currents above.
- Whether the VESC's hall detection maps the G020's halls without a custom table.
- Regen into a capacitor bank on real hardware: the firmware has no
  battery-specific logic beyond the voltage and current limits above, but it is
  untested.
