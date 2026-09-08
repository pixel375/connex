# Connex Lab v0.5.2

Interaction-reliability and touch-editor overhaul.

### Scrollable editor surfaces
- Options, Parts, Physics, Rotate and Move are now real touch-scrollable surfaces;
- Rotate and Move side panels only exist while their matching editor mode is active;
- those side panels are non-collapsible and disappear immediately when switching modes;
- modal menus block construction/world input behind them.

### Direct selection and transform behavior
- ROTATE and MOVE no longer require arming the separate Select button; tap a piece directly;
- ITEM remains the default transform space, while WORLD deliberately transforms the connected construction;
- ordinary attached ITEM movement follows the selected piece's local alignment;
- socket-, CROSS- and AXLE-mounted connectors rotate around their real attachment/rod axis;
- Roll and the visible ITEM rotation gizmo now use the same physically valid axis;
- CROSS, AXLE and O-Ring movement commits use the same validated transform as the drag preview;
- invalid transform axes are hidden rather than shown and rejected later;
- the rotation gizmo starts from the actual finger-down angle, removing the initial jump/snap.

### ATTACH / CREATE reliability
- valid re-seat sockets keep their valid target color;
- CROSS `+` markers are substantially larger;
- rod-end and socket creation taps use larger screen-space picking targets;
- nearby compatible second rod ends auto-connect more reliably, reducing one-sided structures that fall apart in simulation;
- Disconnect opens a visible gap and snap-blocks the old pair until explicitly re-attached.

### 11 / 14-point connector fixes
- all 11 and 14 sockets participate in attachment picking;
- out-of-plane sockets receive enlarged marker-first targets;
- spatial connectors now use the current rounded/open-jaw connector design across all ports;
- changing an 11/14-point connector back to a planar connector removes spatial/top geometry immediately instead of leaving stale pieces behind.

### Parts, camera and physics
- Parts retains the hybrid quick previous/next controls plus the rendered 3D Parts browser;
- Parts preview no longer intercepts scroll gestures;
- camera zoom range is expanded to 3–420 while preserving two-finger pan/zoom;
- Reset Physics Defaults now restores both physics values and the visible slider positions;
- Undo/Redo preserves the current rod/connector palette selection instead of treating palette choice as build history.

### Validation
- v0.5.2 has dedicated interaction-reliability coverage for scroll surfaces, modal blocking, mode-owned panels, Physics reset, attached local-axis movement, socket-axis rotation, O-Ring/CROSS/AXLE move commits, spatial connector lifecycle and palette-safe history;
- the complete legacy behavioral suite through v0.5.1 remains active;
- Android export has passed on the validated v0.5.2 interaction runtime.

### Signing / update compatibility
- Android versionCode is 26;
- Android versionName is `0.5.2`;
- package ID remains `com.pixel375.connex`;
- v0.5.2 uses the existing permanent signing certificate and updates in place over permanently signed Connex builds.
