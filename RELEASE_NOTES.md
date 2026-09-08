# Connex Lab v0.5.1

Connection-aware transform and editor-correctness update.

### ITEM / WORLD transforms
- Rotate and Move now share an explicit **ITEM / WORLD** transform-space switch;
- **ITEM** is the default and aligns the gizmo to the selected piece or its physically valid connection axis;
- **WORLD** deliberately moves/rotates the entire connected construction using world XYZ;
- free pieces expose their own local X/Y/Z axes;
- CROSS and AXLE connections expose only the degree(s) of freedom their host rod actually allows;
- invalid arrows/rings are hidden rather than presenting movement that cannot succeed;
- right-side step buttons use the same transform-space choice as the gizmo.

### CROSS / AXLE behavior
- a CROSS-mounted connector can slide along its host rod and rotate around that rod;
- AXLE-mounted pieces can slide along and rotate around the axle axis while preserving fixed attachments on the moving side;
- rigidly socket-mounted items do not pretend to have an independent ITEM transform; use WORLD when intentionally repositioning the whole connected assembly;
- Roll now uses the valid host-rod axis for CROSS / AXLE cases instead of being disabled or rotating the whole construction.

### ATTACH fixes
- MOVE and ATTACH no longer highlight each other;
- the buggy cursor tether/line is removed;
- CROSS attachment markers are rendered as bold `+` symbols;
- an occupied socket connection can be selected and moved directly to another free fork on the same connector;
- out-of-plane sockets on the 11-point and 14-point 3D connectors use a larger marker-first picking area and retain rebuild-safe socket assemblies.

### Parts workflow and connector visuals
- compact previous/next rod and connector controls are restored alongside the full Parts browser;
- the Parts browser now includes a live 3D rendering of the currently chosen part using the same procedural geometry as the build;
- connector socket jaws have been reshaped with rounded rails/tips and a visibly open fork mouth instead of a closed rectangular bridge across the gap;
- the design remains procedural and unofficial; no official or copied 3D assets are bundled.

### Camera and UI accessibility
- two-finger panning once again moves the camera target vertically as well as horizontally;
- the Rotate/Move side panel receives more usable vertical space so its lower controls are reachable;
- **Saves & Recovery** and **Physics Settings** are promoted to visible Options actions;
- Physics has its own accessible panel with gravity, friction, bounce, linear damping and angular damping controls.

### Regression coverage
- the full v0.3.8 through v0.5.0 behavioral suite remains active;
- the legacy world-transform smoke now explicitly selects WORLD space;
- new v0.5.1 coverage verifies mode highlighting, ITEM default/synchronized controls, Saves/Physics accessibility, Parts rendering, vertical camera pan and 11/14-point spatial ports.

### Signing / update compatibility
- Android versionCode is 25;
- package ID remains `com.pixel375.connex`;
- v0.5.1 uses the existing permanent signing certificate and updates in place over v0.2.1+ permanently signed builds.
