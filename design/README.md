# ReGenX v2 — released design

**Authoritative:** where any other document disagrees with these files, these
win.

| File | Contents |
|---|---|
| [`RGX-2-001-SPEC.md`](RGX-2-001-SPEC.md) | Specification, **Rev E**: system definition, governing equations, computed performance, component and interface schedules, protection coordination, unverified parameters and measurement schedule |
| [`RGX-2-100-schematic.html`](RGX-2-100-schematic.html) | Drawing, **Rev F**: three sheets (system, power, MCU and sensors), parts lists, notes, interface schedule, revision history. Open in a browser |
| [`RGX-2-002-BOM.xlsx`](RGX-2-002-BOM.xlsx) | Bill of materials, **Rev A**: parts with sources and prices (CAD), compatibility checks, incoming-inspection checklist, queued changes, sources |
| [`RGX-2-003-FW.md`](RGX-2-003-FW.md) | Firmware architecture, **Rev E**: the firmware as built, and what is not yet verified on hardware |
| [`planetary-freegen-sim.html`](planetary-freegen-sim.html) | Interactive planetary model: torque directions for assist, coast and regen. Open in a browser |

## Drawing conventions

ASME Y14.44 reference designators, ASME Y14.100 title blocks. Semiconductor
symbols per IEEE 315; resistors and fuses are IEC-style rectangles. Zone grid
A–D / 1–4 on both edges, origin top-left. Junction dots mark connections;
crossings without dots are not connected. Signals crossing a sheet boundary
carry a net name. Flags reference the notes block on their own sheet.

Positive current into the bank is charging. Positive motor torque accelerates
the wheel. Carrier slip is `ω_carrier` relative to the freewheel direction.
