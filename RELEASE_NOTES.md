# Connex Lab v0.3.0

Major editor architecture update focused on predictable mechanical rotation and explicit connection editing.

### 3D rotation gizmo
- removes the camera-relative Up / Down / Left / Right rotation system;
- adds an engine-style world-axis XYZ rotation gizmo around the selected piece or its real mount anchor;
- X, Y and Z are fixed physical world axes and never change meaning when the camera moves;
- touch/mouse ring dragging uses ray-to-plane geometry rather than screen-delta guessing;
- rotation snaps to exact 45-degree states;
- each axis shows + / - validity before interaction; blocked directions are greyed;
- a translucent cyan ghost previews valid snapped candidates and a red ghost previews blocked candidates;
- no transform or graph mutation is committed until the final snapped state validates;
- mounted connectors retain dedicated Roll -45 / +45 around the actual incoming socket rod, cross rod or axle axis.

### Deterministic placement
- default connector roll, cross orientation and axle orientation no longer depend on camera direction;
- the same host geometry now produces the same initial connector orientation from every camera view.

### Re-seat mount socket
- ordinary rotation no longer silently changes which connector jaw owns a connection;
- Re-seat explicitly exposes the currently mounted connector socket in cyan;
- valid alternative mount sockets are green and blocked alternatives are grey;
- choosing a valid alternative keeps the host connection point fixed and changes only the authoritative socket identity plus the required rigid component transform;
- re-seat validates all existing socket/cross/axle/O-Ring relationships before committing.

### Explicit Detach / Attach topology editor
- Detach is a one-shot topology tool: choose the selected piece's highlighted connection anchor to remove that graph edge while leaving both pieces exactly where they are;
- intentionally detached overlapping pairs are blocked from silently auto-fusing back together until explicitly attached again;
- Attach uses the current SOCKET / AXLE / CROSS mode;
- drag a tether from a highlighted free source handle on the selected piece to a compatible target;
- free connector sockets, rod ends and hubs are highlighted as discrete targets; continuous rod-body targets are resolved at the exact release point;
- compatible geometry snaps the selected rigid component as one unit only after every pre-existing connection validates;
- closing an existing rigid loop does not move the structure: the already-present geometry must actually line up before the new connection is accepted;
- manual Attach creates the same authoritative connection records used by normal placement and automatic fusion;
- O-Ring stops can be detached and explicitly re-attached to axle rods.

### Undo / Redo and graph integrity
- rotate, re-seat, detach and attach operations are atomic construction-history actions;
- intentional detach blocks are included in Undo / Redo state;
- restart clears detach blocks and editor tools;
- selection, connector-type changes, rod changes, simulation transitions and deletion cancel transient tools/ghosts safely.

### Existing systems retained
- persistent selected-piece workflow from v0.2;
- automatic overlap fusion;
- SOCKET / AXLE / CROSS construction modes;
- O-Ring Stop in the normal connector list;
- left-side movement and axle-slide controls;
- simulation graph stabilization from earlier releases;
- Options persistence and the in-app GitHub Releases updater from v0.2.1.

### Signing / update compatibility
- package ID remains `com.pixel375.connex`;
- release APK is signed with the same permanent Connex certificate introduced in v0.2.1;
- devices already running v0.2.1 should be able to install v0.3.0 as a normal in-place update and keep app data;
- GitHub Actions verifies the permanent certificate before publishing the release.
