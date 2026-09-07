# Connex Lab v0.3.5

World-rotation and attachment-state-machine correction release.

### Rotation moved back onto the selected object
- removes the v0.3.4 screen-space dial from the right-side menu;
- restores a game-engine-style X/Y/Z ring gizmo around the selected piece;
- the gizmo root is forced to identity/world orientation every frame, so X/Y/Z are fixed WORLD axes rather than part-local or camera axes;
- rotation candidates continue to use the connection-aware pivot/rigid-component validator;
- drag distance only chooses an integer step count; the actual transform is always an exact world-axis 45-degree multiple;
- invalid + / - directions remain greyed using graph validation;
- Roll remains separate and rotates around the real socket/cross/axle mount axis.

### Creation orientation is no longer camera-derived
- connector-on-rod-end placement no longer uses `camera.global_transform.basis.y` to choose connector roll;
- the inherited placement orientation solver now ignores camera vectors and constructs connector roll from stable world axes;
- axle connector orientation is likewise built from deterministic world axes;
- CROSS placement inherits the same stable world-perpendicular rule.

### ATTACH now obeys SOCKET / AXLE / CROSS
- SOCKET exposes only rod ends and connector sockets; tapping a rod shaft can no longer create a fake body point in SOCKET mode;
- AXLE exposes connector hubs / O-Rings and accepts an exact tap on a rod shaft;
- CROSS exposes connector sockets and accepts an exact tap on a rod shaft;
- after a source is selected, only the compatible counterpart type is accepted; unrelated taps no longer silently move the selection;
- Deselect Point explicitly clears the source;
- rod-shaft picking can ray past an overlapping connector to find the rod behind it, improving reliability near joints.

### Re-attachment fixed
- switching an existing rod/connector pair from SOCKET to CROSS or AXLE now treats the old pair edge as the connection being replaced even when the newly selected rod-body/hub point was not itself marked occupied;
- the old edge is excluded from rigid-component and geometry validation before calculating the replacement;
- occupied targets belonging to unrelated connections remain blocked;
- replacement is still atomic: the old connection is removed only after the new snapped geometry validates.

### Right-side layout
- the rotation utility menu contains only selection info, world-gizmo guidance, real-mount Roll, and Reset;
- the obsolete v0.3.4 dial is hidden with its parent so it consumes no layout space;
- Rotate and Move retain accordion behavior with non-overlapping fixed bounds below the status strip.

### Signing / update compatibility
- Android versionCode is 16;
- package ID remains `com.pixel375.connex`;
- v0.3.5 uses the same permanent release signing certificate as v0.2.1+;
- it updates in place over permanently signed earlier versions and preserves app data/settings;
- GitHub Actions verifies the signing certificate before publishing.
