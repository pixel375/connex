# Connex Lab v0.3.7

Rotation-island and right-panel state fix.

### XYZ gizmo no longer breaks on moved/off-axis constructions
- X/Y/Z remain fixed WORLD axes and still snap to exact 45-degree increments;
- the normal XYZ gizmo now behaves like a game-engine transform gizmo: it rotates the entire connected construction island rigidly around the selected piece;
- socket, CROSS, axle and O-Ring relationships inside that island receive the same rigid transform, so their relative geometry cannot be altered by the XYZ operation;
- the gizmo no longer cuts the selected connector's primary mount edge and then tries to validate an arbitrarily oriented branch against old world/rest geometry;
- previous movement, reattachment, arbitrary world angle, or an already off-axis build therefore cannot make the XYZ rings stop working;
- disconnected constructions remain independent: only the selected piece's connected island moves;
- dedicated Roll remains the mount-relative operation for changing a connector around its real rod/axle/CROSS axis.

### Rotate / Move accordion hardened
- Rotate and Move now have one authoritative state variable instead of two independently visible panel bodies;
- opening Rotate always closes Move, and opening Move always closes Rotate;
- entering ROTATE sets the accordion to Rotate;
- every UI refresh re-applies the authoritative state;
- a final per-frame invariant repairs any inherited visibility change before both panels can remain open;
- Reset Placement Rotation preserves the current accordion state explicitly, fixing the case where pressing Reset opened Move underneath Rotate.

### Reset behavior retained
- v0.3.7 inherits the v0.3.6 mount-relative home orientation store;
- Reset Placement Rotation still restores a connector relative to its current host rod rather than an old absolute world basis.

### Signing / update compatibility
- Android versionCode is 18;
- package ID remains `com.pixel375.connex`;
- v0.3.7 uses the same permanent signing certificate as v0.2.1+;
- it updates in place over permanently signed earlier builds and preserves app data/settings;
- GitHub Actions verifies the signing certificate before publishing.
