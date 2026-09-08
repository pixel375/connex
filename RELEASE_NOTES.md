# Connex Lab v0.3.8

Correctness and CI hardening release based on the v0.3.6 Codex audit.

### Undo / Redo now preserves Reset Placement Rotation home
- v0.3.6 introduced a connector home orientation stored relative to its real host rod;
- the older history snapshot format did not serialize that joint metadata, so an Undo/Redo restore could accidentally learn the restored rolled pose as the new reset home;
- v0.3.8 stores each mount-relative home basis by stable connection UID in history snapshots and restores it after the connection graph is rebuilt;
- Roll → Undo → Redo → Reset now returns the connector to its original mount-relative placement orientation;
- Delete/Undo and other history restores use the same preservation path.

### Disconnected constructions now collide
- rods/connectors use construction collision layer 2 and now mask both the ground and other construction bodies (`mask = 3`);
- loose pieces and disconnected assemblies therefore collide instead of passing through one another during simulation;
- the existing simulation preflight still suppresses self-collision inside rigid fixed components and suppresses redundant fixed constraints;
- collision shapes are still simplified and will be refined separately as visual/physics fidelity improves.

### Signing documentation corrected and guarded
- `SIGNING.md` had drifted to an old/incorrect public certificate fingerprint;
- the authoritative SHA-256 certificate fingerprint is `BF:CD:2B:59:70:91:E4:AA:FE:4F:27:93:FD:14:A7:9A:2A:D4:94:0D:D1:06:9D:18:74:9C:E7:A9:99:50:D4:22`;
- that fingerprint was independently verified from the published v0.3.7 APK with `apksigner`;
- CI now checks Main scene, app version, versionCode, package ID, APK filename and documented signing fingerprint for consistency before the expensive Android build begins;
- release builds still verify the decoded keystore fingerprint before export and the final APK signer after export.

### First behavioral audit regression test
- CI now launches the actual game scene headlessly and constructs a real socket chain;
- it checks construction collision layer/mask behavior;
- it performs Roll → Undo → Redo → Reset and fails if the original mount home is lost;
- every PR must pass this behavioral smoke test in addition to the existing parser/runtime smoke and Android export.

### GitHub Actions permissions tightened
- normal build/PR jobs now use read-only repository contents permission;
- release publication is isolated into a second job with write permission only when an explicit `[release]` push is being published;
- the validated APK artifact is passed from the build job to the release job.

### v0.3.7 rotation/UI behavior retained
- X/Y/Z remains a fixed-WORLD game-engine-style gizmo that rotates the selected connected construction island rigidly around the selected piece;
- camera angle and arbitrary prior orientation do not define the transform axes;
- exact 45° snapping remains;
- Roll remains the real mount-axis operation;
- Rotate and Move remain one mutually-exclusive accordion state.

### Signing / update compatibility
- Android versionCode is 19;
- package ID remains `com.pixel375.connex`;
- v0.3.8 uses the same permanent signing certificate as v0.2.1+;
- it updates in place over permanently signed earlier builds and preserves app data/settings.
