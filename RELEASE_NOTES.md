# Connex Lab v0.5.3

Touch interaction, attachment rewiring and rotation-reset correction release.

### Real touch scrolling
- Options, Parts, Saves/Recovery, Help, Physics, Rotate and Move now support full-panel finger pull/swipe scrolling;
- users no longer need to grab the thin scrollbar;
- vertical swipe intent is detected before button/slider release so a real scroll gesture does not accidentally activate the underlying control;
- Saves keeps its own ItemList scrolling behavior when the list itself is swiped.

### Modal input ownership
- open modal menus now intercept outside touches before higher CanvasLayer controls can receive them;
- construction, toolbar and editor actions behind an open modal no longer receive leaked taps.

### Rotate / Move terminology and reset
- WORLD transform mode is renamed STRUCTURE in the user interface;
- STRUCTURE continues to transform the complete connected construction;
- Reset Placement Rotation now zeros the selected connector's STRUCTURE/world rotation;
- free ITEM connectors reset to exact zero rotation;
- socket-, CROSS- and AXLE-mounted ITEM connectors reset to their canonical physically valid zero-roll state;
- ITEM gizmo axes are synchronized before validity coloring, removing the initial gray-valid-ring state.

### Selection and CREATE behavior
- when Select is armed, CREATE placement is disabled until selection succeeds or Select is cancelled;
- tapping a connector while Select is armed can no longer place a rod instead.

### Attachment rewiring
- tapping an occupied SOCKET where a rod end overlaps the connector now resolves to the actual connected rod end when that is the movable endpoint;
- already-attached ends can be moved/re-seated without the old "no free compatible rod end" dead end;
- the attachment solver no longer guesses an unrelated existing link between the same two pieces as the connection being moved;
- rigid-loop closure is allowed when the requested new attachment points are already geometrically aligned;
- perfectly aligned free rod-end/socket pairs can auto-attach even when those pieces already share another rigid link;
- explicit manual disconnect snap-back protection remains respected.

### 11 / 14-point selection visuals
- selection highlight traversal is recursive;
- nested top/bottom spatial jaws and arc geometry on 11- and 14-point connectors glow with the rest of the selected connector.

### Validation
- complete legacy behavioral suite through v0.5.2 remains active;
- dedicated v0.5.3 regression coverage verifies pull scrolling, STRUCTURE reset, Select precedence, occupied-end normalization, immediate valid gizmo coloring, recursive spatial highlight and rigid-loop attachment;
- Android debug export passed on the v0.5.3 candidate before promotion.

### Signing / update compatibility
- Android versionCode is 27;
- Android versionName is `0.5.3`;
- package ID remains `com.pixel375.connex`;
- v0.5.3 uses the existing permanent signing certificate and updates in place over permanently signed Connex builds.
