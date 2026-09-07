# Connex Lab

**Connex Lab** is an unofficial Android 3D construction simulator inspired by the mechanical geometry of classic K'NEX rods and connectors. It is built with Godot 4.6.3 and compiled with GitHub Actions.

> K'NEX is a trademark of its respective owner. This project is unofficial, unaffiliated, and does not ship official artwork or copied 3D assets.

## Current version — v0.3.0

v0.3.0 separates **piece transforms** from **connection topology**. Rotation no longer decides which connector socket owns a rod, and camera orientation no longer determines a physical rotation axis.

### Core connection graph

The simulator explicitly records:

- **Socket/end snap** — a specific rod end ↔ a specific connector socket.
- **Cross snap** — a specific connector socket ↔ a recorded point along a rod body.
- **Hub axle** — connector hub ↔ rod with axial slide/rotation DOFs.
- **O-Ring Stop** — rigid axle stop ↔ host axle rod.
- **Automatic fusion** — compatible overlaps create the same graph records as manual attachments.

## Pieces

### Rods

| Simulator name | Physical length used |
|---|---:|
| Green 16 | 17.5 mm |
| White 32 | 33 mm |
| Blue 54 | 55 mm |
| Yellow 86 | 86 mm |
| Red 128 | 130 mm |
| Gray 190 | 192 mm |

The simulator uses roughly 10 mm = 1 world unit and a 10.1 mm connector-centre-to-socket-end offset.

### Connectors

Gray 1-way, Orange straight 2-way, Light gray angled 2-way, Red 3-way, Green 4-way, Yellow 5-way, White 8-way, and the special **O-Ring Stop** axle part.

## Selection and building

There is no CREATE / EDIT switch.

- The newest created piece becomes selected automatically.
- Selection persists until another piece is created or **Select** is pressed once and an older piece is tapped.
- Normal construction taps do not silently change selection.
- The cyan outline marks the selected piece.
- Bottom Rod/Conn arrows edit the selected matching piece or choose the next placement type when another kind is selected.

Construction modes remain **SOCKET / AXLE / CROSS**.

## v0.3 rotation gizmo

The old camera-relative arrow rotation controls are removed.

- Red **X**, green **Y**, and blue **Z** circular rings are fixed world axes.
- Moving the camera changes only how the gizmo is viewed, never what an axis means.
- Dragging a ring uses ray-to-rotation-plane intersection.
- Rotation snaps to exact **45°** states.
- `X+ / X-`, `Y+ / Y-`, and `Z+ / Z-` validity is computed before interaction; blocked directions are greyed.
- A cyan translucent ghost previews a valid snapped result; a red ghost shows a blocked candidate.
- Nothing is committed until every recorded connection validates.
- Mounted connectors keep **Roll -45° / +45°** around the actual incoming socket rod, cross rod, or axle.
- Placement orientation is deterministic and no longer camera-dependent.

## Re-seat connection

**Re-seat Mount Socket** explicitly changes which connector jaw owns an existing socket/cross mount.

- current mount socket = cyan;
- valid alternatives = green;
- invalid/occupied alternatives = grey.

Choosing a new socket keeps the host connection point fixed, computes the required rigid transform, validates the entire graph, then atomically changes the stored socket identity.

## Detach / Attach

Topology changes are explicit rather than being overloaded onto rotation.

### Detach

Press **Detach Connection**, then tap one orange connection anchor on the selected piece. The graph edge is removed but both pieces stay exactly where they are. That pair is temporarily excluded from automatic overlap fusion so it does not instantly reconnect itself.

### Attach / Re-attach

Attach uses the current SOCKET / AXLE / CROSS mode.

1. Select the source piece.
2. Press **Attach / Re-attach**.
3. Start a drag from a highlighted free source handle.
4. Drag the tether to a compatible target and release.

Free rod ends, connector sockets, hubs, and continuous rod-body targets are supported. The selected rigid component snaps only after all existing connections validate. If the target is already part of the same rigid component, the geometry must already line up; Connex will not distort a closed loop to force it.

Manual Attach produces the same authoritative connection records as normal placement and auto-fusion.

## Move controls

The left panel operates on the persistent selected piece:

- Forward / Back / Left / Right;
- Y− / Y+;
- Axle − / Axle + for sliding compatible axle-mounted parts and O-Rings.

## Camera and Options

- one-finger drag: orbit;
- two-finger drag: pan;
- pinch: zoom;
- workspace: 500 × 500 world units;
- independent reverse Orbit X/Y and Pan X/Y options;
- camera sensitivity and grid visibility;
- settings persist in `user://connex_settings.cfg`.

## Updates and signing

Starting with v0.2.1, release APKs use one permanent Android signing certificate and package ID `com.pixel375.connex`. v0.3.0 continues using that certificate, so an installed v0.2.1 can update in place.

Options contains **App Updates**. While the repository is public, Connex checks the public GitHub Releases API, downloads a newer APK through Android DownloadManager, and hands it to Android's package installer. Android still requires its normal install confirmation. If source development later moves private, releases should move to a separate public update feed/release repository rather than embedding a private GitHub token in the APK.

## Physics

Godot `Generic6DOFJoint3D` constraints remain the runtime physics representation. Fixed socket/cross connections lock all DOFs while axle joints retain axial translation and rotation. Before simulation Connex re-runs auto-fusion, rebuilds the authoritative graph, refreshes frames, suppresses redundant fixed cycles, and suppresses self-collision inside rigid fixed components.

A later physics upgrade may collapse fully fixed assemblies into compound rigid bodies, leaving only real axle/sliding joints in the solver.

## Procedural visuals

All piece geometry is generated in code rather than copied from official meshes. Rods use fluted shafts/keyed-looking ends; connectors use procedural open hubs and jaw-like radial sockets.

## Build

Every pull request is parsed, smoke-tested headlessly, and exported to an ARM64 Android APK by `.github/workflows/android.yml`. Release merges are signed with the permanent Connex keystore, certificate-verified, and published with a SHA-256 checksum.

## Research basis

See [`RESEARCH.md`](RESEARCH.md). Key references include US Patent 5,350,331, later connector/rod patent material, classic K'NEX manuals, MIT's legacy K'NEX overview, and community part catalogues.

## License

Source code is MIT licensed. See `LICENSE`.
