# Connex Lab v0.5.8

Single-bug correction release: keep automatically attached rod/socket connections physically attached when SIMULATE starts.

### Root cause fixed
- v0.5.7 correctly created the second `SOCKET` record when a newly placed rod lined up with another connector;
- however, the legacy simulation preflight deliberately removed one fixed joint from every closed rigid loop as a "redundant constraint";
- in a closed K'NEX frame, that removed edge could be the newly auto-attached rod end;
- the build therefore looked connected in BUILD but that endpoint had no active solver constraint after SIMULATE and opened under gravity.

### Closed-loop sockets remain real connections
- v0.5.8 keeps the existing pre-simulation graph preparation, geometry normalization, collision handling, and duplicate-axle filtering;
- after the legacy loop analysis, any real `SOCKET` joint that was disabled only because it closes a rigid loop is restored before physics is released;
- automatically attached second rod ends therefore stay physically bound to their connector sockets in closed frames;
- ATTACH mode is still not required.

### Scope
- no camera, UI, movement, rotation, connector geometry, selection, scrolling, or attachment-picking behavior is changed;
- this release changes only simulation handling of already-recorded closed-loop `SOCKET` connections.

### Validation
- all existing regressions through v0.5.7 remain enabled;
- the dedicated v0.5.8 regression builds a four-connector rectangular closed frame;
- the fourth side is created through the real production SOCKET placement path and its far end must auto-attach before simulation;
- the test requires the legacy redundant-cycle path to be exercised, then verifies no real SOCKET remains disabled;
- it runs the actual SIMULATE path for 60 physics frames and verifies the loop-closing rod endpoint remains in its socket.

### Signing / update compatibility
- Android versionCode is 32;
- Android versionName is `0.5.8`;
- package ID remains `com.pixel375.connex`;
- the existing permanent Connex signing certificate is retained for an in-place update over v0.5.7.
