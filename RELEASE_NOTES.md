# Connex Lab v0.3.4

Rotation and attachment interaction rebuild focused on removing the two most confusing editor behaviors from v0.3.3.

### Camera-independent rotation dial
- removes the projected 3D world-ring drag input path;
- adds a fixed screen-space X/Y/Z rotation dial in the Rotate panel;
- the dial never moves or reorients with the 3D camera, so changing the view cannot change the meaning of the gesture;
- X/Y/Z use the selected piece's deterministic local axes and the existing connection-aware pivot/rigid-branch solver;
- every rotation snaps to exact 45-degree increments;
- left half of a ring is negative, right half is positive;
- invalid plus/minus directions are grey before use based on the connection graph;
- multi-step drag still validates the final snapped state transactionally;
- Roll remains separate and still uses the real socket/cross/axle mount axis.

### ATTACH mode simplified
- removes the five artificial rod-body dots that previously covered every rod;
- visible markers are now only real discrete ports: rod ends, connector sockets, connector hubs, and O-Rings;
- port markers are much smaller and act as guides rather than debug spheres covering the model;
- CROSS/AXLE positions are chosen by tapping directly on the physical rod shaft at the exact desired position;
- only that one temporary rod-body point is highlighted in yellow;
- source -> target remains a two-tap workflow;
- occupied targets cannot accept a second connection and become the new selected source instead;
- reconnect stays atomic: old topology is removed only after the replacement geometry validates;
- O-Ring attachment remains a special axle-stop operation.

### Existing systems retained
- CREATE / ROTATE / ATTACH editor modes;
- explicit connection graph, auto-fusion, Undo/Redo and simulation stabilization;
- separate runtime status strip below the top toolbar;
- v0.3.3 Godot-native updater with SHA-256 verification;
- persistent camera/options settings.

### Signing / update compatibility
- Android versionCode is 15;
- package ID remains `com.pixel375.connex`;
- v0.3.4 uses the same permanent signing certificate introduced in v0.2.1;
- it installs in place over permanently signed earlier builds and preserves app data/settings;
- GitHub Actions verifies the permanent certificate before publishing.
