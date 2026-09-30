# Carrier-brake mechanism

**Status: concept selected, not built.** Spec §11 gate 1, "carrier accessible
to a caliper on a rear hub", is the one assumption whose failure obsoletes the
electrical design. Everything below waits on the G020 teardown (§5).

---

## 1. Criteria

| # | Criterion |
|---|---|
| 1 | Coasting unchanged: carrier overruns freely, rotor stationary, zero drag |
| 2 | Lever force sets carrier holding torque continuously; slip is the control variable |
| 3 | Torque capacity ≥ 80 N·m at the carrier (§3) |
| 4 | Fits the 135 mm rear dropout with cassette and wheel disc brake intact |
| 5 | Brake reaction torque has a defined path to the frame, not through the wheel |
| 6 | Stock freewheel behaviour in drive (assist) preserved |
| 7 | Serviceable without motor teardown |

---

## 2. What is static in a geared hub

Every part belongs to one of three motion classes:

| Class | Members | Motion |
|---|---|---|
| Static | axle, stator, cable, torque arm | fixed to frame |
| Carrier | planet carrier, pins, the stock one-way clutch | freewheels; the member to brake |
| Wheel | hub shell, **both side covers**, ring gear, freehub, cassette, spokes, disc rotor | wheel speed |

So nothing static can mount to a cover except at the axle centreline, and the
carrier is buried radially inside the ring gear: its only reachable surface is
its outboard face, across a few millimetres of gap to the rotating cover.

Bafang BPM-class teardowns show the one-way clutch integrated with the carrier
and gripping the axle ("Case B"). Then the stock motor already has the
Freegen architecture:

```
DRIVE:  sun torque → carrier reacts rearward → clutch grips axle → ring/shell driven
COAST:  shell drags carrier forward → clutch overruns → rotor stationary
REGEN:  friction brake holds the carrier → sun spins, generates
```

The conversion is additive: bring a brake surface off the carrier face. No
clutch is added, removed or reversed. If the teardown instead finds the clutch
between ring and shell with a rigid carrier ("Case A"), the conversion needs
carrier bearings and a separate ≥80 N·m one-way clutch, and the concept is
re-judged before any further spend.

Prior art: Grin's Freegen (80 mm rotor on the carrier, right-side caliper) and
ChargeBike; two independent implementations on this motor family.

---

## 3. Sizing

The brake never sees more than the gear-referred generating torque:
`T_carrier = (1+k)/k · T_wheel`. With k ≈ 5 and the motor's 45 N·m wheel
rating, 54 N·m; design capacity 80 N·m. Once the carrier is fully held the
brake is static and transmits only what the motor reacts, so over-squeezing
cannot overload it. Brake failure fails safe: less regen, and the wheel's own
brake is independent.

Slip heat is `s · P_braking` and the control law keeps s small, so the friction
interface sees 100–300 J per stop at ≤ 1 m/s rubbing speed: two orders of
magnitude below a bicycle disc brake. No rotor mass, no fade compound, wear
permits near-zero running clearance, and the friction surface can be the
carrier's own steel. What remains from brake practice is the force problem:
1.5–3 kN of normal force from ≤ ~1 kN of cable tension. The one duty limit is
a long descent ridden at large slip.

With dead electronics a held carrier produces no braking torque (spec §1), so
the carrier lever is never the fail-safe; the wheel's own brake is.

---

## 4. Selected concept

**2a, friction disc to an axle-grounded spider**, entirely inside the hub
([`carrier-brake-path2-viz.html`](carrier-brake-path2-viz.html) shows the
coast, slip and held states).

- A spider plate sits on the axle flats (no axle machining) and carries the
  actuation cam; a friction disc splined to a ring on the carrier face is
  squeezed between the spider and a pressure plate. Both clamp faces are
  static, so the carrier sees pure torque and no thrust into the gear train.
- Two faces at r ≈ 27 mm need F ≈ 2.9 kN, from a ball-ramp or cam at 10–20×
  cable advantage. Axial stack 10–13 mm.
- Torque reacts through the axle into the existing torque arm, which now sees
  up to 54 N·m in the opposite sense to drive: size it for the reversal.
- Actuation, two variants: (i) a keyed collar at the cover bore moved 1–2 mm
  by a cam lever between cover and dropout; (ii) a pushrod through a 6 mm
  centre bore in the free axle end (retains 94 % of bending section, Sturmey-
  Archer precedent). Rider's existing rear lever and cable either way.
- Nothing visible outside the hub but the actuator entry. Cassette, freehub,
  chainline and the wheel's disc brake are untouched.

Fallbacks, chosen by the teardown:

| | 2a disc to spider | 2e shoe in a drum lip | 2b multi-plate | 1a/1b external, on a tube through the cover |
|---|---|---|---|---|
| When | default | axial gap short: lip depth only | 2a lacks modulation authority | only if a cover bore gives an easy exit |
| Clamp | 2.9 kN | 3.9 kN from cam | 0.9–1.3 kN over 4–6 faces | Grin-proven, but the tube surfaces into cassette or rotor space |
| Depends on | q5 | q3, q5 | q5 | q2, q4b |

Rejected: pawl latch (no real lever feel without a simulator), eddy-current
(no torque at stall), hysteresis/MR (mass, cost, powered), viscous (torque set
by geometry, not rider), wrap-spring (binary), braking through the mesh (no
access).

---

## 5. Teardown questions

| # | Question | Decides |
|---|---|---|
| 1 | Clutch carrier-to-axle (Case B) or ring-to-shell (Case A)? | Whole conversion path |
| 2 | Which side cover exposes the carrier? | Adapter side |
| 3 | Carrier material, thickness, holes or keyways usable for an adapter | Adapter attachment |
| 4 | Radial clearance between carrier OD and cover bore | Adapter and lip diameter |
| 4a | Carrier outboard face: usable annulus, flatness, features | Friction radius, carrier ring |
| 4b | Freehub bore over the axle, spacer stack, both ends | Whether a Path 1 tube exit exists |
| 4c | Which axle end is free of the cable channel; length and hardness for a 6 mm bore | Pushrod vs collar |
| 4d | Cover centre bore: bearing size, seat, seal | Collar sleeve; dished-cover feasibility |
| 5 | Axial gap, carrier face to cover inner face | 2a vs 2e, or a remade cover |
| 6 | Axle diameter, flat width, thread, spacer stack | Torque-arm plate, spacers |
| 7 | Cover fasteners and seal | Re-sealability, criterion 7 |
| 8 | Clutch direction vs cassette drive direction | Confirms the senses in §2 |
| 9 | Carrier runout | Disc mounting tolerance |

Photograph every stage on grid paper; the record is the CAD input. Custom
parts for 2a (spider, carrier ring, friction disc, pressure plate, cam, collar
or pushrod, torque-arm plate) are all flat or simply turned. They become the
RGX-2-2xx mechanical series once the concept survives the teardown.

```
motor arrives → teardown (§5) → GATE: Case B, carrier reachable
pass          → CAD from measurements → printed fit check → fabricate → spin tests
fail (Case A) → invasive-conversion decision before further spend
```

---

## Sources

- [Grin, Freegen and Magic Drive](https://ebikes.ca/product-info/grin-kits/freegen-magic-drive.html)
- [Endless Sphere, ChargeBike variable-regen geared hub](https://endless-sphere.com/sphere/threads/new-geared-hubmotor-variable-regen-e-braking-system-that-still-freewheels-by-chargebike.122120/)
- [Bruce Teakle, Bafang BPM teardown](http://bruceteakle.blogspot.com/2018/02/reversing-bafang-8fun-bpm-motor.html): clutch grips the axle, integral with the carrier
- [Endless Sphere, Bafang BPM teardown and pictures](https://endless-sphere.com/sphere/threads/bafang-bpm-geared-hub-specs-teardown-and-pics.51237/)
- [GreenBikeKit, Bafang clutch assemblies](https://www.greenbikekit.com/bafang-bldc-hub-motor-clutches.html): clutch sold integral with carrier and nylon gears
