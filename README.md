# ReGenX v2 — regenerative brake-assist for a bicycle

A rear geared hub motor (Bafang G020) whose planet carrier gets its own brake
lever. Holding the carrier makes the motor a generator: energy goes into a
supercapacitor bank and returns as short throttle boosts. No traction battery.
A Raspberry Pi Pico (MicroPython) holds the carrier at a set slip by adjusting
the regen current through a VESC motor controller.

## Status

| Part | State |
|---|---|
| Electrical design | Released (spec, drawing, BOM). Not built or measured; spec §11 lists what is unmeasured |
| Firmware | Complete; host tests pass in CI. Not yet run on hardware (RGX-2-003 §10) |
| Carrier-brake mechanism | Concept study only; depends on a G020 teardown |
| Constants | Gains, gear ratio, pole pairs and calibrations are placeholders, marked `[BENCH]` in `firmware/config.py` |
| Part numbers | Not chosen for S1, S2, F1 fuse block, J4 (BOM lists candidates) |

## Contents

| Path | |
|---|---|
| `design/` | **Authoritative.** Spec RGX-2-001, drawing RGX-2-100 (PDF, printed from its HTML source), BOM RGX-2-002 (parts, sources, inspection checks), firmware architecture RGX-2-003, planetary simulator (HTML) |
| `firmware/` | MicroPython for the Pico (six files) and `deploy.sh`, which copies them to it |
| `tests/` | Host tests, run through a model of the hub and the VESC |
| `research/` | Decision log, component selection, carrier-brake study; `design/` wins where they differ |

```
pip install -r requirements-dev.txt
python -m pytest        # host tests
firmware/deploy.sh      # to a Pico running MicroPython v1.29.0
```

Designators: **A1** VESC (Flipsky Mini FSESC4.20) · **U2** Pico · **M1** motor ·
**C1–C3** supercap bank · **BT1** keep-alive pack · **S1** main switch ·
**F1** main fuse · **R1** precharge resistor · **J3** throttle · **DS1** display.

## Conventions

**sun** = motor rotor, **ring** = wheel shell, **carrier** = braked member
(one-way clutch plus friction brake). `k = Z_ring / Z_sun ≈ 5` (unmeasured).
Positive = forward wheel motion; positive current into the bank is charging.

```
ω_carrier = (ω_sun + k·ω_ring) / (1+k)
T_sun : T_ring : T_carrier = 1 : k : −(1+k)
```

With the carrier held, sun and ring counter-rotate; the VESC is configured so
this reads as positive ERPM (RGX-2-003 §11 item 4). If the sun carries no
torque, nothing does: the carrier brake works only while the motor
regenerates. Carrier slip equals the fraction of braking power lost as heat in
the carrier brake.

Drawing: ASME Y14.44 designators and Y14.100 title blocks; IEEE 315
semiconductor symbols, IEC-style resistors and fuses. Zone grid A–D / 1–4,
origin top-left. Dots mark junctions; crossings without dots are not
connected. Flags refer to the notes block on their own sheet.
