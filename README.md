# Connex Lab

**Connex Lab** is an unofficial Android 3D construction simulator inspired by the mechanical geometry of classic K'NEX rods and connectors. It is built with Godot 4.6.3 and compiled with GitHub Actions.

> K'NEX is a trademark of its respective owner. This project is unofficial, unaffiliated, and does not ship official artwork or copied 3D assets.

## Current version — v0.2.0

v0.2.0 replaces the older CREATE/EDIT and incremental X/Y/Z rotation model with a connection-first construction system.

The simulator models these connection types explicitly:

- **Socket/end snap** — a specific rod end connects to a specific radial connector socket.
- **Cross snap** — a specific connector socket clips across a rod body at a recorded position along that rod.
- **Hub axle** — a rod through a connector's centre hole can rotate and slide axially.
- **Axle-on-existing-rod** — an already-connected rod can receive another connector through its hub as a sliding axle connection.
- **O-Ring Stop** — a small axle stop mounts to an axle rod and moves with that rod.
- **Automatic fusion** — compatible overlapping free rod ends and connector sockets become the same structural connection records as manually placed connections.

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
- O-Ring Stop (special axle part)

## Building and selection

There is **no CREATE / EDIT switch** in v0.2.0.

- Construction taps always perform the currently selected SOCKET / AXLE / CROSS placement action when the tapped geometry is valid.
- The **newest created piece becomes selected automatically**.
- The selected piece stays selected until another piece is created or the user explicitly changes selection.
- To select an older piece, press **Select** once and tap it. Select is a one-shot action and immediately ends after that tap.
- Normal construction taps do not silently change the persistent selection.
- The strong cyan outline always marks the current selected piece.

The bottom palette is context-sensitive:

- Rod arrows edit the selected rod when a rod is selected; otherwise they choose the next rod type to place.
- Connector arrows edit the selected connector when a compatible connector is selected; otherwise they choose the next connector type to place.
- O-Ring Stop remains part of the normal connector list.

### SOCKET

- Tap a free connector socket to add exactly one rod.
- Tap a free rod end to add a connector.
- A socket already occupied by a rod rejects another placement.
- If a free rod end reaches a compatible free socket elsewhere in the build, the connection is automatically fused and recorded.

### AXLE

- Tap a connector hub to insert the selected rod through it.
- Tap an existing rod to place the selected connector onto that rod as a sliding axle connector.
- Existing rods can receive axle connectors even when their ends are already used by socket connections.
- Select O-Ring Stop and tap an axle rod to add a physical axle stop.

### CROSS

- Tap a rod body to cross-snap the selected connector.
- The connection remembers the exact connector socket, host rod, and point along the host rod.
- Compatible existing overlaps can also be recognized and fused as cross connections after normal rod-end/socket matches are considered first.

## Connection-first rotation

v0.2.0 no longer repeatedly rotates a connector around its changing local X/Y/Z axes and then tries to rediscover where its rods went.

Each connection records the real mount geometry. Rotation is previewed against that connection graph before anything changes.

### Free/root assemblies

A connector with no incoming mount can rotate its rigidly connected branch in **45° camera-relative steps** using the Up / Down / Left / Right controls. Roll rotates around the connector's own normal.

### Mounted connectors

A mounted connector uses **Roll ⟲ / Roll ⟳** around its real mount axis:

- socket-mounted connector → incoming rod axis;
- cross-mounted connector → host cross-rod axis;
- axle-mounted connector → axle axis.

The rigid downstream branch moves with the selected connector around that pivot rather than leaving its attached rods behind and attempting to remap them afterward.

### Validity and transactional behavior

- Every exact socket, cross, axle, and O-Ring relationship is checked before a candidate transform is accepted.
- Rotation controls that cannot produce a valid result are disabled before they are pressed.
- A rejected rotation is a **true no-op**: it does not alter transforms, mount identity, socket occupancy, joint frames, auto-fuse state, or Undo/Redo history.
- Closed rigid loops that cannot rotate around a single mount without breaking another connection are detected and locked rather than corrupted.
- **Reset Rotation** uses the same validator to return a connector toward its placement orientation without breaking its recorded connections.

## Move controls

The collapsible left panel operates on the persistent selected piece.

- Forward / Back / Left / Right move its fixed component relative to the camera.
- Y− / Y+ move vertically.
- Axle − / Axle + slide compatible selected axle components along the axle axis.
- O-Ring Stops can be repositioned along their host axle.

## Camera and Options

- One-finger drag orbits.
- Two-finger drag pans.
- Pinch zooms.
- The workspace is 500 × 500 world units.
- Options can independently reverse horizontal/vertical orbit and horizontal/vertical pan directions.
- Camera sensitivity and grid visibility are configurable.
- Options are saved immediately to `user://connex_settings.cfg` and persist between launches.

## UI layout

- **Top:** Select, Undo, Redo, Simulate/Build, Restore, Restart, Center, Options, Help.
- **Bottom:** permanent rod/connector palette and SOCKET/AXLE/CROSS mode.
- **Right:** collapsible connection-aware rotation panel with camera arrows, mount Roll, Reset Rotation, and Delete Selected.
- **Left:** collapsible movement/axle-slide panel.

## Physics

Godot's `Generic6DOFJoint3D` is still used for runtime physical constraints: socket/cross joints lock six degrees of freedom, while axle joints lock transverse motion and tilt but leave axial translation and axial rotation free.

Before simulation, Connex v0.2.0:

1. runs the same authoritative auto-connect scan used while building;
2. rebuilds the explicit connection graph;
3. refreshes joint frames from the recorded connection geometry;
4. suppresses redundant fixed-joint cycles in the active solver;
5. disables self-collision inside rigidly connected components;
6. suppresses duplicate/redundant axle constraints.

The first connector is **not pinned**. All normal construction pieces use the same gravity rules.

The physical model still intentionally simplifies real plastic behavior:

- rods are rigid rather than flexible;
- snap joints do not detach under load;
- collision shapes are simplified for phone performance;
- manufacturing tolerance, wear, friction, pull-out force, and plastic deformation are not yet calibrated;
- gears, motors, chain, wheels, flexi-rods, and blue/purple 3D interlocking connectors are future work.

## Procedural visuals

All piece geometry is generated in code rather than copied from official meshes. Current visuals use fluted rod shafts, keyed-looking rod ends, open connector hubs/collars, and open-jaw radial sockets while keeping geometry procedural and easy to tune.

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
