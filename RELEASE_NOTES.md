# Connex Lab v0.6.0

Mechanical-editor correction release based directly on phone testing of v0.5.0.

### ITEM vs WORLD transforms
- Rotate and Move now default to **ITEM • MECHANICAL**;
- each right-side panel has an explicit ITEM / WORLD switch;
- ITEM shows only degrees of freedom that the selected connection can physically use;
- WORLD is the deliberate whole-connected-construction transform;
- the exact-step buttons and the in-world gizmos follow the same selected transform space.

Mechanical ITEM behavior includes:
- CROSS connector: one rotation ring around the host rod and one translation axis along the rod;
- AXLE rod/connector: rotation only around the axle and translation only through the hub;
- single socket-mounted connector: mount-axis roll;
- disconnected piece: local X/Y/Z;
- fixed connections without a valid independent DOF: impossible arrows/rings are hidden instead of pretending the move is valid.

### Rotate / Move fixes
- fixes the MOVE / ATTACH active-button highlight mix-up;
- cross rotation no longer rotates the whole construction;
- Roll on cross/axle/socket mounts uses the same mechanical item-axis logic;
- axle Move uses the existing proven axle-slide path;
- cross Move updates the recorded position along the host rod rather than breaking the snap;
- Rotate and Move detail panels are scrollable so exact-step controls cannot be clipped below the phone viewport.

### Attachment fixes
- removes the buggy live tether/line preview entirely;
- attachment is now a direct source-point -> destination-point workflow;
- tapping an occupied connector socket resolves to its attached rod end, allowing that existing rod to be moved/re-seated onto another free socket;
- CROSS connection targets use bold **+** markers instead of generic dots;
- marker display is filtered to the current SOCKET / AXLE / CROSS mode to reduce clutter;
- touch picking is enlarged and all special 11-point / 14-point out-of-plane socket IDs are included as real selectable attachment targets.

### Parts workflow
- restores the fast **Rod / Conn previous-next arrows**;
- keeps **PARTS…** as the expanded chooser, making the bottom controls a hybrid rather than replacing the quick selector;
- selecting an existing construction piece no longer changes the future-part palette;
- Parts cards now contain on-device 3D renderings of each rod/connector rather than text-only cards.

### Connector geometry
- replaces box-heavy connector jaws with original procedural rounded geometry;
- fork arms use rounded capsule-like ribs and remain visibly open through the socket gap;
- removes the visible closed rectangular bridge across the fork mouth;
- the same open rounded design is used for planar and out-of-plane sockets;
- the model remains procedural/original and does not bundle third-party STL/mesh assets.

### Options / camera
- Options is now scrollable, making **Saves & Recovery** and all **Physics** sliders reachable on phones;
- restores a dedicated two-finger centroid pan path while retaining one-finger orbit and pinch zoom;
- Physics values continue to persist between launches.

### Regression coverage
- all existing v0.3.8 through v0.5.0 regression smokes remain active;
- new `mechanical_editor_smoke_v060.gd` verifies mode highlighting, removal of the tether, hybrid/3D Parts, scrollable Options, all 14 spatial ports, rounded connector geometry, CROSS item rotation/slide, AXLE item slide and two-finger pan.

### Signing / update compatibility
- Android versionCode is 25;
- package ID remains `com.pixel375.connex`;
- v0.6.0 uses the same permanent signing certificate and updates in place over v0.2.1+ permanently signed builds.
