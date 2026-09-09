# Connex Lab v0.5.7

Single-bug correction release: automatic attachment of the opposite end of a newly placed rod.

### New rod second-end attachment
- when a rod is created by tapping a connector socket, the tapped end is connected as before;
- before that placement is committed, v0.5.7 immediately checks the rod's opposite end;
- if that far end lines up with a compatible free socket on another connector, it is immediately created as a real `SOCKET` graph connection;
- ATTACH mode is not required;
- both rod ends and both connector sockets are marked occupied in the same placement state;
- the existing exact geometry closure is applied before the state is stored.

### Simulation persistence
- the second-end socket joint exists before SIMULATE is pressed;
- simulation therefore receives the already-complete connection graph instead of trying to infer the missing edge after physics begins;
- the v0.5.7 regression starts simulation and verifies the far-end joint remains physically bound and the rod/socket points remain together.

### Scope
- no camera, UI, rotation, movement, connector-design, or other gameplay behavior is changed in this release;
- v0.5.7 is intentionally limited to this rod-placement auto-attachment bug.

### Validation
- all previous regressions through v0.5.6 remain enabled;
- the dedicated v0.5.7 test creates two pre-existing 8-port connectors at the exact Blue-54 spacing, places a rod from the first connector without using ATTACH mode, requires two real socket records immediately, then presses SIMULATE and verifies the second end stays attached;
- Android export and permanent release signing must pass before publication.

### Signing / update compatibility
- Android versionCode is 31;
- Android versionName is `0.5.7`;
- package ID remains `com.pixel375.connex`;
- the existing permanent Connex signing certificate is retained for in-place update over v0.5.6.
