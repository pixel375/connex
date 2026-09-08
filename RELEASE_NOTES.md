# Connex Lab v0.3.10

O-Ring behavior and editor-interaction reliability update.

### O-Ring Stop behaves like a dedicated axle stop
- the visible center hole is smaller/tighter;
- O-Rings can now be placed on **any existing rod**, not only rods that were originally inserted as axles;
- when O-Ring Stop is the next Conn part, CREATE ignores the current SOCKET / AXLE / CROSS setting and always places the O-Ring with axle-style semantics;
- newly placed O-Rings are selected automatically and use the same construction collision layer/mask as the other pieces.

### Rotation no longer loses selection
- the v0.3.9 empty-space deselect behavior is still available in CREATE;
- ROTATE and ATTACH now protect the current piece selection from empty/near-miss taps;
- this prevents the synthetic/post-drag tap after a gizmo rotation from clearing the selected piece;
- explicit Deselect Piece remains available on the left.

### ATTACH target picking is more forgiving
- compatible second-step targets use a much larger mobile touch radius;
- occupied neighboring sockets are filtered out instead of winning the nearest-point pick over a free socket;
- if the user taps the physical body of a connector/rod but misses its small marker, Connex falls back to the nearest free compatible port on that exact piece;
- failed target/geometry attempts keep the original attachment source selected so another target can be tried immediately;
- SOCKET therefore behaves much more reliably on crowded 5-way and 8-way connectors.

### Regression coverage
- v0.3.8 history/collision audit remains active;
- v0.3.9 deselect/O-Ring selector smoke remains active;
- v0.3.10 adds an interaction smoke that verifies a non-axle rod accepts an O-Ring while CROSS is selected, checks the tighter O-Ring mesh and collision policy, confirms a ROTATE empty tap cannot clear selection, and proves a connector-body tap can resolve to a free SOCKET target and create the connection.

### Signing / update compatibility
- Android versionCode is 21;
- package ID remains `com.pixel375.connex`;
- v0.3.10 uses the same permanent signing certificate as v0.2.1+ and updates in place over permanently signed earlier builds.
