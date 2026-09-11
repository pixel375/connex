# Connex Lab v0.5.21

This release redesigns camera navigation and the transform editor for touch screens while keeping the existing connection and physics behavior intact.

### Analog construction camera
A translucent analog joystick now sits inside the lower-left of the usable 3D viewport. It moves the camera forward/back/left/right relative to the current view heading with full analog input rather than fixed camera steps.

The camera's orbit target moves together with this translation, so subsequent look/orbit gestures keep working around the place you actually navigated to instead of circling an old point behind the camera.

Two holdable **UP / DOWN** controls on the right edge provide camera elevation. Existing empty-space one-finger look/orbit, pinch zoom and two-finger pan remain available. Two-finger pan no longer resets camera elevation.

### CREATE / TRANSFORM / ATTACH
The separate ROTATE and MOVE modes are now one **TRANSFORM** mode. Translation arrows and 45-degree rotation rings are shown together on the selected construction, removing a mode switch from normal editing.

The old MOVE mode remains internally compatible with older save/editor code and retained regressions, including the dedicated CROSS-rod SLIDE gizmo.

### Cleaner transform UI
The old right-side ROTATE and MOVE panels with duplicate X/Y/Z step buttons are retired. Those axes are already represented by the on-piece gizmos.

A compact expandable **TRANSFORM** card keeps only the controls that still add something useful:
- ITEM / WORLD transform-space toggle
- mount-relative Roll − / Roll +
- Reset Placement Rotation
- axle Slide − / Slide +

The left editor toolbar is also condensed to CREATE / TRANSFORM / ATTACH plus the existing contextual disconnect/delete/deselect actions.

### Better Center behavior
**Center** now focuses the currently selected piece. If nothing is selected, it frames the whole construction. Holding Center performs a full camera heading, pitch and distance reset.

### Touch scrolling no longer activates items on release
Scrollable menus now use a larger touch drag deadzone and allow their child cards/buttons to pass drag gestures to the parent ScrollContainer. Starting a menu scroll over a button/card and releasing after the scroll therefore no longer activates the item underneath the finger.

### Existing fixes retained
v0.5.20 multi-rod reconnect repair, ATTACH selection, O-Ring socket creation and live attachment markers remain active. The v0.5.19 crowded ATTACH picking and spatial 11/14-point CROSS orientation, legacy AXLE save healing, midpoint CROSS insertion/sliding, physical O-Rings, deterministic AXLE/CROSS stops and save/load repair are also retained.

### Regression coverage
The v0.5.21 gate verifies the unified transform layout, simultaneous movement/rotation gizmos, ITEM/WORLD control, analog camera translation, elevation, Center focus, viewport-safe control placement and scroll-safe menu cards. It also reruns the v0.5.20 reconnect/ATTACH regression, v0.5.19 spatial CROSS regression, CROSS slide, legacy AXLE repair, socket workflow, both O-Ring stability cases and the four-post AXLE/CROSS save/load roundtrip.

### Android / update compatibility
- Android versionCode: 45
- Android versionName: `0.5.21`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
