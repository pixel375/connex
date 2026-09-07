# Connex Lab

**Connex Lab** is an unofficial Android 3D construction simulator inspired by the mechanical geometry of classic K'NEX rods and connectors. It is built with Godot 4.6.3 and compiled on GitHub Actions.

> K'NEX is a trademark of its respective owner. This open-source project is unofficial, unaffiliated, and does not ship official artwork or copied 3D assets.

## v0.1.0 — first playable prototype

The first version focuses on the mechanical rules that make the classic system distinctive instead of treating pieces like generic blocks:

- **Socket/end snap:** rods join connector sockets laterally and are keyed as a rigid connection.
- **Cross snap:** a connector can snap sideways onto the intermediate rod body at 90°.
- **Hub axle:** a rod can pass through a connector's central hole and remains free to rotate and slide along that axis.
- **45° connector geometry:** classic planar socket directions are represented in 45° increments.
- **Classic rod scale:** six standard rod sizes are represented using measured physical lengths.
- **Rigid-body physics:** gravity and joint constraints run when switching from Build to Simulate.
- **Procedural pieces:** all v0.1 geometry is generated in code; there are no imported K'NEX models.

## Pieces in v0.1

### Rods

| Simulator name | Nominal classic size | Physical length used |
|---|---:|---:|
| Green 16 | 16 mm | 17.5 mm |
| White 32 | 32 mm | 33 mm |
| Blue 54 | 54 mm | 55 mm |
| Yellow 86 | 86 mm | 86 mm |
| Red 128 | 128 mm | 130 mm |
| Gray 190 | 190 mm | 192 mm |

The simulation uses a 10 mm = 1 world-unit scale and a roughly 10.1 mm connector-center-to-socket-end offset.

### Connectors

- Gray 1-way
- Orange straight 2-way
- Light gray angled 2-way
- Red 3-way
- Green 4-way
- Yellow 5-way
- White 8-way

Blue/purple perpendicular 3D interlocking connectors are documented in `RESEARCH.md` but intentionally deferred until the core placement/physics loop is proven on phones.

## Phone controls

- **Drag empty space:** orbit camera.
- **Pinch:** zoom.
- **Rod / Conn arrows:** choose the next rod or connector.
- **SOCKET:** tap near a free connector socket. A selected rod plus the selected connector is snapped into the exact geometric continuation. If an existing connector is already at the matching center, the simulator closes the connection instead.
- **AXLE:** tap a connector to insert the selected rod through its hub.
- **CROSS:** tap a rod to snap the selected connector onto its body at 90°.
- **Twist:** rotate the plane of the newly attached connector around the incoming rod in 45° steps, enabling 3D structures with planar connectors.
- **Undo:** remove the most recent connection.
- **Reset:** restore the authored build pose after a physics run.
- **Simulate / Build:** release physics or return to the frozen construction pose.

The first white connector is an anchored construction origin so a structure has something fixed to react against during physics testing.

## Architecture

Godot was selected over a custom Android renderer or a UI-only approach because this project needs both mobile 3D interaction and joint physics. A `Generic6DOFJoint3D` maps well to the connection model: socket and cross-snap joints lock all six degrees of freedom, while an axle joint locks transverse translation and tilt but leaves axial translation and axial rotation free.

Everything in v0.1 is GDScript/procedural geometry. This keeps the repository small, avoids licensing ambiguity around third-party piece meshes, and makes the mechanical dimensions easy to tune from measured data.

## What “physics accurate” means in v0.1

The **connection topology, geometric spacing, gravity, rigid-body behavior, and hub degrees of freedom** are modeled. Real rods and connectors also flex, deform locally when snapped, have manufacturing tolerances, friction, wear, and connection pull-out forces. Reliable public engineering constants for all of those are not available, so v0.1 does **not** pretend to simulate them exactly. Those are calibration targets for later versions.

Current simplifications:

- rods are rigid bodies (no bending/flex yet);
- snap joints do not detach under load;
- collision shapes are simplified for mobile performance;
- hub friction/clearance is approximated as an unconstrained axial/rotary joint;
- gears, wheels, motors, chain, spacers, clips and flexi-rods are not yet implemented;
- blue/purple 3D connector interlock is not yet implemented.

## Build and APK

Every pull request is parsed, smoke-tested headlessly and exported to an ARM64 Android APK by `.github/workflows/android.yml`. The v0.1.0 release workflow publishes `Connex-v0.1.0.apk` plus its SHA-256 checksum to GitHub Releases.

The v0.1 APK is **debug-signed for direct testing**, not signed with a persistent Play Store production key.

## Research basis

The mechanical model is documented in detail in [`RESEARCH.md`](RESEARCH.md). Key primary/reference material includes:

- US Patent 5,350,331 — *Construction toy system*: https://patents.google.com/patent/US5350331
- US Patent application 2019/0160390 — connector/rod geometry and material discussion: https://patents.google.com/patent/US20190160390A1/en
- Basic Building Set manual — the three fundamental rod/connector assembly methods: https://d2npjmct0hwe3x.cloudfront.net/wp-content/uploads/manuals/Basic-Building-Set-30010.pdf
- MIT legacy K'NEX overview — classic connector colors/types and center-hole behavior: https://web.mit.edu/~naha/Public/knex/about/Basic/knex.html
- K'NEX part catalogue/community references for classic piece taxonomy and dimensions: https://catalogue.knexchange.org/

## License

Source code is MIT licensed. See `LICENSE`.
