# Connex Lab v0.5.27

This release targets the remaining multi-second BUILD-mode click latency reported on large constructions after v0.5.26.

### Root cause and performance fix
- Found an obsolete v0.1.7 whole-construction auto-fuse matcher still running after the modern targeted auto-connect matcher on every edit commit.
- That legacy matcher could make up to six full passes over the construction, repeatedly scanning rod ends against every connector/socket and connector sockets against every rod.
- The duplicate legacy matcher is now bypassed during the authoritative modern commit path.
- Normal BUILD edits continue to use the current targeted auto-connect system introduced in v0.5.25.
- Full modern whole-build connection validation remains available for removal/free-port cases and before SIMULATE.
- No physics constraints or O-Ring behavior were changed.

### Large-build regression
- Added a dedicated latency regression that creates a 60-piece background construction, then measures one real connector-socket → rod create action.
- The tested staging tree completed that create path in 134.22 ms with 62 bodies on the shared CI runner.
- The regression also verifies that the obsolete v0.1.7 scan is actually bypassed and that the newly created rod remains correctly connected through the modern graph.

### Preserved fixes from v0.5.26
- Saves remain newest-first with Android touch-drag scrolling.
- Automatic/recovery saves remain capped at five while named saves stay unlimited.
- Autosave serialization/file writing remains off the interactive UI thread.
- Update checking continues to compare against the actual running version.
- Deselect continues to clear ATTACH-point state and marker highlighting.
- Occupied connector sockets remain hidden as ATTACH targets while the connected rod end owns that location.

### Regression coverage
- Full editor, save/load, ATTACH, socket, CROSS, AXLE, rigidity, O-Ring and simulation regression suites pass on the v0.5.27 staging tree.
- Corrected O-Ring CROSS-style mounting and real collision-stop behavior remain unchanged.

### Android
- versionCode: 51
- versionName: `0.5.27`
- package ID: `com.pixel375.connex`
- Permanent Connex signing certificate retained for in-place update compatibility.