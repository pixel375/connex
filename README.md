# Connex Lab

**Connex Lab** is an unofficial Android 3D construction simulator inspired by the mechanical geometry of classic K'NEX rods and connectors. It is built with Godot 4.6.3 and compiled with GitHub Actions.

> K'NEX is a trademark of its respective owner. This project is unofficial, unaffiliated, and does not ship official artwork or copied 3D assets.

## Current version — v0.3.4

v0.3.4 rebuilds the two editor areas that were still confusing in v0.3.3: rotation input and ATTACH point selection.

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

### ROTATE

v0.3.4 no longer interprets rotation by dragging projected 3D rings in the world. The right Rotate panel contains a **fixed screen-space X/Y/Z dial**:

- the dial never changes orientation when the camera moves;
- X/Y/Z use the selected piece's deterministic local axes, not camera axes;
- each ring snaps to exact 45° steps;
- tap the left half for negative, right half for positive, or drag around the ring for multiple snapped steps;
- invalid +/- directions are greyed before use;
- the selected rigid branch is rotated around its connection-aware pivot only after the candidate state validates;
- **Roll** remains a separate control around the actual socket/cross/axle mount axis.

Ordinary world taps do not create pieces in ROTATE mode. Use the one-shot **Select** button when you need to choose another piece.

### ATTACH

ATTACH now exposes only real discrete ports:

- rod ends — cyan;
- connector sockets — green;
- connector axle hubs and O-Rings — purple;
- occupied ports — orange;
- selected source — yellow with a label.

The old row of arbitrary rod-body points is gone. For CROSS or AXLE placement, tap directly on the physical rod shaft where you want the connection. Connex creates one temporary rod-body point at that exact location.

Workflow:

1. tap a port or rod shaft to select the source;
2. tap a compatible free counterpart;
3. Connex infers SOCKET / CROSS / AXLE from the two point types;
4. the selected side moves only if the candidate geometry validates against the rest of the connection graph.

Tap the same selected point again or press **Deselect Point** to clear it. Tapping an incompatible or occupied point simply moves the selection to that point. Occupied targets never accept a second connection.

If the selected source is already connected, ATTACH performs an atomic reconnect: the old edge is removed only after the new geometry validates. Failed attempts leave the old connection unchanged.

## Connection graph

Connex explicitly records:

- socket/end snap — a specific rod end ↔ a specific connector socket;
- cross snap — a specific connector socket ↔ an exact recorded rod-body position;
- hub axle — connector hub ↔ rod with axial slide/rotation DOFs;
- O-Ring Stop — rigid axle stop ↔ host axle rod;
- automatic fusion — compatible overlaps create the same graph records as explicit attachments.

## UI layout

- **Top toolbar:** Select, Undo, Redo, Simulate/Build, Restore, Restart, Center, Options, Help.
- **Status strip:** a separate line directly below the toolbar for version/runtime messages.
- **Left:** CREATE / ROTATE / ATTACH, Delete Selected, ATTACH point deselection.
- **Right:** collapsible Rotate and Move panels.
- **Bottom:** permanent rod/connector palette and creation connection mode.

## Camera and Options

- one-finger drag: orbit;
- two-finger drag: pan;
- pinch: zoom;
- workspace: 500 × 500 world units;
- independent reverse Orbit X/Y and Pan X/Y settings;
- camera sensitivity and grid visibility;
- settings persist in `user://connex_settings.cfg`.

Camera movement changes the view only. The v0.3.4 rotation dial is screen-space and the actual rotation axes come from the selected piece, so viewing angle is not part of the rotation calculation.

## Updates and signing

Starting with v0.2.1, release APKs use one permanent Android signing certificate and package ID `com.pixel375.connex`. v0.3.4 uses the same certificate and Android versionCode 15, so it installs in place over permanently signed earlier versions and preserves settings/data.

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
