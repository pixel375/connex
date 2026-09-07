# Connex Lab

**Connex Lab** is an unofficial Android 3D construction simulator inspired by the mechanical geometry of classic K'NEX rods and connectors. It is built with Godot 4.6.3 and compiled with GitHub Actions.

> K'NEX is a trademark of its respective owner. This project is unofficial, unaffiliated, and does not ship official artwork or copied 3D assets.

## Current version — v0.1.5

The simulator models the connection rules rather than treating the pieces like generic blocks:

- **Socket/end snap** — rods connect to keyed radial connector sockets.
- **Cross snap** — connectors can snap to the body of a rod at 90°.
- **Hub axle** — rods through a connector's centre hole remain free to rotate and slide axially.
- **Axle-on-existing-rod** — an existing connected rod can also receive a new sliding connector through its hub.
- **O-Ring Stop** — a small axle stop can be placed on an axle rod to prevent a sliding connector from passing it.
- **45° connector geometry** — classic socket directions use 45° increments.
- **Rigid-body simulation** — build geometry is frozen during editing and released under gravity in SIMULATE.

## Pieces

### Rods

| Simulator name | Nominal classic size | Physical length used |
|---|---:|---:|
| Green 16 | 16 mm | 17.5 mm |
| White 32 | 32 mm | 33 mm |
| Blue 54 | 54 mm | 55 mm |
| Yellow 86 | 86 mm | 86 mm |
| Red 128 | 128 mm | 130 mm |
| Gray 190 | 190 mm | 192 mm |

The simulation uses a 10 mm = 1 world-unit scale and roughly a 10.1 mm connector-centre-to-socket-end offset.

### Connectors

- Gray 1-way
- Orange straight 2-way
- Light gray angled 2-way
- Red 3-way
- Green 4-way
- Yellow 5-way
- White 8-way
- O-Ring Stop (special axle connector)

## CREATE and EDIT

v0.1.5 separates construction from manipulation to make touch interaction predictable.

### CREATE

CREATE only places parts.

- The permanent bottom palette chooses the rod, connector, and connection mode.
- **SOCKET:** tap a free connector socket to add the selected rod; tap a free rod end to add the selected connector.
- **AXLE:** tap a connector to insert the selected rod through its hub, or tap an existing rod to place the selected connector on that rod as a sliding axle connector.
- **CROSS:** tap a rod body to cross-snap the selected connector.
- Select **O-Ring Stop** from the normal connector list and tap an axle rod to place it.

### EDIT

EDIT only selects/manipulates; taps do not create parts.

- A vivid cyan emissive outline marks the selected piece.
- The collapsible right panel provides **X− / X+ / Y− / Y+ / Z− / Z+** rotation, **Mount** rotation, **Reset Rotation**, and **Delete**.
- Cross-mounted connectors rotate around the actual host-rod cross axis and orbit the snap point instead of rotating incorrectly around their own centre.
- Invalid rotations are transactional: if a change would break socket, cross, or axle geometry, nothing is mutated.
- The collapsible left panel moves the selected fixed component in the camera plane or vertically.
- **Axle − / Axle +** slides compatible rods/connectors through an axle and repositions O-Ring Stops along their host axle.

## Camera and Options

- One-finger drag orbits.
- Two-finger drag pans.
- Pinch zooms.
- The workspace is 500 × 500 world units.
- **Options** can independently reverse horizontal/vertical orbit and horizontal/vertical pan directions.
- Camera sensitivity and grid visibility are configurable.
- Options are saved immediately to `user://connex_settings.cfg` and persist between launches.

## UI layout

- **Top:** CREATE/EDIT, Undo, Redo, Simulate/Build, Restore, Restart, Center, Options, Help.
- **Bottom:** permanent rod/connector palette and SOCKET/AXLE/CROSS mode.
- **Right:** collapsible rotation/edit panel.
- **Left:** collapsible movement/axle-slide panel.

## Physics

Godot's `Generic6DOFJoint3D` maps to the connection model: socket/cross joints lock six degrees of freedom, while axle joints lock transverse motion and tilt but leave axial translation and axial rotation free.

Before simulation, Connex reduces redundant fixed-joint cycles into a spanning rigid graph and disables self-collision inside rigidly fixed components. This is intended to avoid the delayed oscillation/explosion failure that can occur when multiple mathematically redundant constraints and internal collision impulses fight each other.

The first connector is **not pinned**. All normal construction pieces use the same gravity rules.

The model still intentionally simplifies real plastic behavior:

- rods are rigid rather than flexible;
- snap joints do not detach under load;
- collision shapes are simplified for phone performance;
- manufacturing tolerance, wear, friction, pull-out force, and plastic deformation are not yet calibrated;
- gears, motors, chain, wheels, flexi-rods, and blue/purple 3D interlocking connectors are future work.

## Procedural visuals

All piece geometry is generated in code. v0.1.5 refines the silhouettes with fluted rod shafts, keyed rod ends, thinner open connector hubs/collars, and more recognizable open-jaw socket geometry. This avoids licensing ambiguity from third-party meshes while keeping dimensions easy to tune.

## Build and APK

Every pull request is parsed, smoke-tested headlessly, and exported to an ARM64 Android APK by `.github/workflows/android.yml`. Release merges publish the APK and SHA-256 checksum to GitHub Releases.

The APK is **debug-signed for direct sideload/testing**, not with a persistent Play Store production key.

## Research basis

The mechanical model is documented in [`RESEARCH.md`](RESEARCH.md). Reference material includes:

- US Patent 5,350,331 — *Construction toy system*: https://patents.google.com/patent/US5350331
- US Patent application 2019/0160390 — connector/rod geometry and material discussion: https://patents.google.com/patent/US20190160390A1/en
- Basic Building Set manual: https://d2npjmct0hwe3x.cloudfront.net/wp-content/uploads/manuals/Basic-Building-Set-30010.pdf
- MIT legacy K'NEX overview: https://web.mit.edu/~naha/Public/knex/about/Basic/knex.html
- K'NEX part catalogue/community references: https://catalogue.knexchange.org/

## License

Source code is MIT licensed. See `LICENSE`.
