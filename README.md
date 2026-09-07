# Connex Lab

**Connex Lab** is an unofficial Android 3D construction simulator inspired by the mechanical geometry of classic K'NEX rods and connectors. It is built with Godot 4.6.3 and compiled with GitHub Actions.

> K'NEX is a trademark of its respective owner. This project is unofficial, unaffiliated, and does not ship official artwork or copied 3D assets.

## Current version — v0.3.7

v0.3.7 changes normal X/Y/Z rotation into a true rigid-island world transform so moved/off-axis constructions can always rotate, while hardening the right-side Rotate/Move accordion so both panels cannot remain open together.

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

## Editor modes

Large buttons on the left choose one of three modes.

### CREATE

Normal construction mode. The bottom palette chooses rod/connector types and SOCKET / AXLE / CROSS creation behavior. Rotation and attachment overlays are hidden.

Connector placement orientation is deterministic in **world space**. Creation code no longer uses camera up/right vectors to choose connector roll, so changing the camera cannot rotate a newly created part differently.

### ROTATE

ROTATE uses a game-engine-style X/Y/Z ring gizmo around the selected piece:

- red X, green Y and blue Z rings are fixed **WORLD axes**;
- the gizmo is attached visually to the selected piece, not embedded in a menu;
- camera angle changes only how the rings are projected on screen, never which physical axis is used;
- every drag snaps to exact 45° world-axis increments;
- **v0.3.7 rotates the entire connected construction island as one rigid transform around the selected piece**;
- socket, CROSS, axle and O-Ring relationships therefore keep exactly the same relative geometry during normal XYZ rotation;
- previous movement, reattachment, arbitrary world orientation, or an already off-axis construction cannot make XYZ rotation invalid merely because it no longer matches an old world/rest angle;
- disconnected constructions remain independent because only the selected piece's connected island rotates;
- **Roll** remains a separate operation around the actual socket/cross/axle mount axis;
- **Reset Placement Rotation** restores the connector's stored mount-relative placement orientation rather than an old absolute world-space basis.

Ordinary world taps do not create pieces in ROTATE mode. Use the one-shot **Select** button when you need to choose another piece.

### ATTACH

ATTACH follows the bottom connection mode explicitly.

**SOCKET**
- visible points: rod ends + connector sockets only;
- rod shafts are not attachment points in SOCKET mode;
- valid pair: rod end ↔ connector socket.

**AXLE**
- visible discrete points: connector hubs + O-Rings;
- tap the exact desired position on a physical rod shaft for the rod-side point;
- valid pair: connector hub/O-Ring ↔ rod shaft.

**CROSS**
- visible discrete points: connector sockets;
- tap the exact desired position on a physical rod shaft for the rod-side point;
- valid pair: connector side socket ↔ rod shaft;
- the rod is **perpendicular to the connector's flat face**, parallel to the connector's axle axis, but passes through a side clamp instead of the center hole.

Workflow:

1. choose SOCKET / AXLE / CROSS at the bottom;
2. tap one valid source point;
3. Connex keeps that source selected in yellow;
4. only a compatible counterpart is accepted for the second tap;
5. the selected point is recomputed from the piece's current transform if the piece moves;
6. point picking uses larger projected targets plus a physical raycast fallback for crowded/overlapping geometry;
7. press **Deselect Point** to clear the source explicitly.

If the chosen rod and connector already have a different connection type, Connex can replace that existing pair edge. The old connection is excluded from rigid-component validation first, the replacement geometry is calculated, and the old edge is removed only after the new state validates. Invalid attempts leave the original connection intact.

When a connector's primary mount is replaced, the new connection becomes its primary pivot when appropriate so later Roll/reset operations continue to use the correct topology.

## Connection graph

Connex explicitly records:

- socket/end snap — a specific rod end ↔ a specific connector socket;
- cross snap — a specific connector socket ↔ an exact recorded rod-body position, with rod axis parallel to the connector normal;
- hub axle — connector hub ↔ rod with axial slide/rotation DOFs;
- O-Ring Stop — rigid axle stop ↔ host axle rod;
- automatic fusion — compatible overlaps create the same graph records as explicit attachments.

## UI layout

- **Top toolbar:** Select, Undo, Redo, Simulate/Build, Restore, Restart, Center, Options, Help.
- **Status strip:** a separate line directly below the toolbar for version/runtime messages.
- **Left:** CREATE / ROTATE / ATTACH, Delete Selected, ATTACH point deselection.
- **Right:** Rotate and Move share one authoritative accordion state. Opening either closes the other, entering ROTATE opens Rotate, and UI refreshes such as Reset cannot reopen Move underneath it.
- **Bottom:** permanent rod/connector palette and creation connection mode.

## Camera and Options

- one-finger drag: orbit;
- two-finger drag: pan;
- pinch: zoom;
- workspace: 500 × 500 world units;
- independent reverse Orbit X/Y and Pan X/Y settings;
- camera sensitivity and grid visibility;
- settings persist in `user://connex_settings.cfg`.

Camera movement changes the view only. Placement orientation and X/Y/Z rotation never derive their physical axes or connector roll from the camera.

## Updates and signing

Starting with v0.2.1, release APKs use one permanent Android signing certificate and package ID `com.pixel375.connex`. v0.3.7 uses the same certificate and Android versionCode 18, so it installs in place over permanently signed earlier versions and preserves settings/data.

Options contains **App Updates**. Since v0.3.3, Connex reads the latest GitHub Release, downloads the APK with Godot `HTTPRequest` into `user://`, displays progress, verifies the GitHub Release SHA-256 digest when available, then opens the verified APK through Godot's Android FileProvider / normal package installer path.

While this repository remains public, release metadata/APKs come directly from GitHub Releases without embedding a token. If source development later moves private, releases should move to a separate public update feed/release repository rather than embedding private GitHub credentials in the APK.

## Physics

Godot `Generic6DOFJoint3D` constraints remain the runtime representation. Fixed socket/cross connections lock all DOFs while axle joints retain axial translation and rotation. Before simulation Connex re-runs auto-fusion, rebuilds the authoritative graph, refreshes joint frames, suppresses redundant fixed cycles, and suppresses self-collision inside rigid fixed components.

A future physics upgrade may collapse fully fixed assemblies into compound rigid bodies, leaving only true axle/sliding joints in the solver.

## Build

Every pull request is parsed, smoke-tested headlessly, and exported to an ARM64 Android APK by `.github/workflows/android.yml`. Release merges use the permanent Connex keystore, verify the certificate fingerprint, and publish the APK plus SHA-256 checksum to GitHub Releases.

## Research basis

See [`RESEARCH.md`](RESEARCH.md). Key references include US Patent 5,350,331, later connector/rod patent material, classic K'NEX manuals, MIT's legacy K'NEX overview, and community part catalogues.

## License

Source code is MIT licensed. See `LICENSE`.
