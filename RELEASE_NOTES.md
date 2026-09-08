# Connex Lab v0.3.9

Selection and O-Ring usability update.

### Deselect Piece
- a new **Deselect Piece** button is available on the left editor panel;
- tapping genuinely empty workspace also clears the current piece selection;
- ATTACH points and the ROTATE gizmo are treated as interactive targets, so tapping/dragging those controls does not accidentally deselect the piece;
- selection tools are cancelled cleanly when the piece is deselected.

### Bottom palette now clearly separates editing from future placement
- while a compatible piece is selected, the existing Rod / Conn controls retain their current edit behavior;
- with nothing selected, those controls are strictly future-piece selectors and never modify an already-created part;
- the labels explicitly show `NEXT • ...` while nothing is selected;
- the left hint also states that the bottom palette is choosing the next part.

### O-Ring Stop is now directly reachable
- **O-Ring Stop** remains a real entry in the Conn list and can now be reached reliably after clearing selection;
- when O-Ring Stop is chosen as the next connector, Connex explains that it is placed on a rod already being used as an axle;
- the new regression test verifies that cycling the future Conn selector reaches O-Ring Stop without changing the existing connector, then places an O-Ring on real axle geometry.

### Regression coverage
- the v0.3.8 mount-home/collision audit smoke remains active;
- v0.3.9 adds a dedicated headless selection/O-Ring smoke test;
- parser/runtime smoke, Android export, signing verification, and release metadata checks remain required.

### Signing / update compatibility
- Android versionCode is 20;
- package ID remains `com.pixel375.connex`;
- v0.3.9 uses the same permanent signing certificate as v0.2.1+ and updates in place over permanently signed earlier builds.
