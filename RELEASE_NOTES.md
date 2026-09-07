# Connex Lab v0.3.2

Editor workflow simplification focused on making construction, rotation, and connection editing easier to understand on a phone.

### Three editor modes
- replaces the v0.3 Re-seat / Detach / Attach / Cancel tool stack with three large persistent modes on the left: **CREATE**, **ROTATE**, and **ATTACH**;
- **CREATE** performs normal construction only; rotation gizmos and attachment handles are hidden;
- **ROTATE** shows the fixed-world XYZ gizmo and real-mount Roll controls; ordinary world taps do not accidentally create parts;
- **ATTACH** shows connection points directly and uses a simple tap-point → tap-compatible-point workflow;
- **Delete Selected** moves to the left-side mode panel;
- Move and Rotate utility panels now live on the right and start collapsed; opening one collapses the other.

### Point-based ATTACH mode
- shows rod ends, multiple rod-body mount points, every connector socket, connector axle hubs, and O-Rings;
- point colors are deliberately distinct: cyan rod ends, blue rod-body points, green sockets, purple hubs/O-Rings, orange occupied points, and a large yellow marker/label for the selected point;
- tapping a point selects it; tapping it again or pressing **Deselect Point** clears it;
- tapping another incompatible/occupied point moves the point selection rather than invoking another hidden tool state;
- tapping a compatible free counterpart performs the connection;
- SOCKET / CROSS / AXLE topology is inferred from the two point types instead of requiring the old attach-tool mode;
- the first-selected side is the side that moves to the target.

### Atomic reconnect
- an already-connected first point can be moved/reconnected directly to a compatible free target;
- Connex validates the candidate movement against every other recorded connection before removing the old edge;
- an invalid reconnect leaves the original connection completely untouched;
- a valid reconnect removes only that one old edge, moves the selected rigid component, creates the replacement edge, and stores the result as one Undo/Redo action;
- occupied targets cannot accept a second connection;
- intentionally replaced connections retain the anti-auto-refuse block so the old touching pair cannot silently reconnect itself.

### Existing systems retained
- fixed-world X/Y/Z 45-degree rotation gizmo and real-mount Roll;
- explicit authoritative connection graph and automatic overlap fusion;
- SOCKET / AXLE / CROSS creation modes and O-Ring Stop;
- simulation stabilization;
- persistent camera/options settings;
- v0.3.1 DownloadManager updater reliability fix.

### Signing / update compatibility
- Android versionCode is 13;
- package ID remains `com.pixel375.connex`;
- v0.3.2 uses the same permanent signing certificate introduced in v0.2.1;
- it installs in place over v0.2.1, v0.3.0, or v0.3.1 and preserves app data/settings;
- GitHub Actions verifies the permanent certificate before publishing.
