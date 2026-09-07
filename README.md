# Connex Lab

**Connex Lab** is an unofficial Android 3D construction simulator inspired by the mechanical geometry of classic K'NEX rods and connectors. It is built with Godot 4.6.3 and compiled with GitHub Actions.

> K'NEX is a trademark of its respective owner. This project is unofficial, unaffiliated, and does not ship official artwork or copied 3D assets.

## Current version — v0.3.3

v0.3.3 keeps the v0.3.2 three-mode editor and replaces the unreliable Android DownloadManager updater path with a Godot-native download/verification/install flow. Runtime status text also has its own strip so it can no longer squeeze the top toolbar buttons.

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

Large buttons on the left choose one of three modes:

### CREATE

Normal construction mode. The bottom palette chooses rod/connector types and the usual SOCKET / AXLE / CROSS creation behavior. Rotation gizmos and attachment-point overlays are hidden so a normal build tap cannot be confused with editing.

### ROTATE

The selected piece/rigid branch uses the v0.3 fixed-world rotation gizmo:

- red X, green Y, blue Z circular rings;
- camera movement changes only the view, never the physical axis;
- ray-to-plane drag geometry;
- exact 45° snapping;
- invalid snapped states remain blocked;
- mounted connectors retain real-mount Roll around the actual incoming socket rod, cross rod, or axle.

Ordinary world taps do not create pieces while ROTATE is active. Use the one-shot **Select** button when you need to choose an older piece.

### ATTACH

ATTACH replaces the older Re-seat / Detach / Attach button stack with direct point selection.

Visible points include:

- rod ends — cyan;
- rod-body mount points — blue;
- connector sockets — green;
- connector axle hubs and O-Rings — purple;
- occupied points — orange;
- currently selected point — large yellow marker with a label.

Workflow:

1. tap one point;
2. tap a compatible free counterpart;
3. Connex infers SOCKET / CROSS / AXLE from the two point types;
4. the first-selected side moves to the target only if every existing connection still validates.

Tap the same point again or press **Deselect Point** to clear it. Tapping another incompatible or occupied point simply moves the point selection.

If the first-selected point is already connected, ATTACH acts as an atomic reconnect: Connex validates the replacement before removing the old edge. Invalid attempts leave the original connection untouched. Successful reconnects are one Undo/Redo action.

## Connection graph

Connex explicitly records:

- socket/end snap — a specific rod end ↔ a specific connector socket;
- cross snap — a specific connector socket ↔ a recorded rod-body position;
- hub axle — connector hub ↔ rod with axial slide/rotation DOFs;
- O-Ring Stop — rigid axle stop ↔ host axle rod;
- automatic fusion — compatible overlaps create the same graph records as explicit attachments.

## UI layout

- **Top toolbar:** Select, Undo, Redo, Simulate/Build, Restore, Restart, Center, Options, Help. It contains buttons only.
- **Status strip:** a separate line directly below the toolbar for version/runtime messages, so long messages cannot steal button space.
- **Left:** CREATE / ROTATE / ATTACH, Delete Selected, and ATTACH point deselection.
- **Right:** collapsible Rotate and Move utility panels. Both start collapsed and operate as an accordion.
- **Bottom:** permanent rod/connector palette and creation connection mode.

## Camera and Options

- one-finger drag: orbit;
- two-finger drag: pan;
- pinch: zoom;
- workspace: 500 × 500 world units;
- independent reverse Orbit X/Y and Pan X/Y settings;
- camera sensitivity and grid visibility;
- settings persist in `user://connex_settings.cfg`.

## Updates and signing

Starting with v0.2.1, release APKs use one permanent Android signing certificate and package ID `com.pixel375.connex`. v0.3.3 uses the same certificate and Android versionCode 14, so it installs in place over permanently signed earlier versions and preserves settings/data.

Options contains **App Updates**. v0.3.3 no longer constructs Android `DownloadManager.Request` objects through `JavaClassWrapper`. Instead it:

1. reads the latest public GitHub Release metadata;
2. downloads the APK with Godot `HTTPRequest` into `user://`;
3. shows transfer progress;
4. verifies the downloaded APK against the SHA-256 digest published by GitHub Releases when available;
5. opens the verified local APK through Godot `OS.shell_open()`, whose Android implementation uses the app FileProvider and Android's normal package installer.

A verified APK remains available for another **Install** tap if Android first requires the user to grant “install unknown apps” permission. Failed or partial downloads are removed and the UI returns to **Retry Download**.

Users whose installed v0.3.1/v0.3.2 copy hits the old `Android could not create the download request` failure need to install v0.3.3 manually once, because the bug is inside that already-installed updater code. Later updates use the rebuilt path.

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
