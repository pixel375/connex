# Connex Lab v0.4.0

First editor-UX modernization chunk.

### Cleaner editor modes
- left-side modes are now **CREATE / ROTATE / MOVE / ATTACH**;
- MOVE is a first-class editor mode directly beneath ROTATE;
- right-side Rotate and Move utility panels start collapsed and remain optional;
- the bottom palette is shorter and the old long instructional line is hidden to leave more room for the construction.

### Move gizmo
- MOVE displays world X/Y/Z translation arrows directly on the selected piece;
- drag an axis to move the entire connected construction island rigidly;
- movement snaps every 0.5 world units;
- the compact Move panel also provides deterministic X/Y/Z ± step buttons and axle sliding.

### Disconnect Selected
- new left-side button disconnects the selected physical piece from all of its recorded graph connections;
- geometry stays exactly where it is;
- manual-detach blocking prevents the same overlapping pair from instantly auto-fusing again;
- the operation commits one build/history state and keeps the piece selected.

### Rotation usability
- the selected-piece world rotation gizmo remains the primary tool;
- the Rotate panel now includes deterministic World X/Y/Z ±45° fallback buttons;
- plus/minus direction indicators are evaluated separately so a blocked direction can be greyed without disabling the opposite direction;
- Roll remains the separate mount-axis operation.

### ATTACH guidance
- after the first source point is selected, incompatible or occupied discrete points are dimmed;
- compatible free points are highlighted bright green;
- a live preview line runs from the selected source to the pointer/current target;
- green line = compatible target, red line = no valid target yet;
- existing SOCKET / AXLE / CROSS connection behavior is preserved.

### Visual polish
- Godot's default boot splash image is disabled;
- piece materials use a smoother plastic roughness model;
- key, fill and rim lighting improve shape readability and separation without changing piece colors;
- UI spacing/panel layout is tightened to reduce clutter.

### Regression coverage
- all v0.3.8 through v0.3.11 behavior tests remain active;
- new `editor_ux_smoke_v042.gd` verifies the disabled boot splash, world move mode, rigid-island translation, Disconnect Selected, and exact-step world rotation fallback.

### Signing / update compatibility
- Android versionCode is 23;
- package ID remains `com.pixel375.connex`;
- v0.4.0 uses the same permanent signing certificate and updates in place over v0.2.1+ permanently signed builds.
