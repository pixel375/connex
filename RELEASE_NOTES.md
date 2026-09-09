# Connex Lab v0.5.11

Physics follow-up for the excessive closed-frame sag seen in v0.5.10. Camera behavior is intentionally unchanged in this release.

### Structure Rigidity
- adds a new **Structure Rigidity** physics control from 0–100%;
- default is **92%**;
- the setting is saved between sessions and Reset Physics returns it to 92%;
- 0% reproduces the loose v0.5.9 redundant-cycle behavior;
- 100% is nearly rigid but intentionally keeps a tiny amount of compliance instead of restoring the unstable exact redundant weld.

### Closed-loop SOCKET behavior
v0.5.9 prevented delayed physics explosions by freeing all angular axes on the redundant SOCKET edge of each closed rigid loop. That kept the socket position connected, but effectively inserted a ball-style hinge into a frame and allowed large flat structures to sag into a bowl.

v0.5.11 keeps the same stable cycle-breaking architecture while limiting that angular movement:
- normal, non-redundant SOCKETs remain fully fixed;
- only cycle-closing redundant SOCKET edges receive the Structure Rigidity flex limit;
- at the 92% default, each stabilized cycle edge is limited to roughly ±0.93°;
- at 100%, the remaining compliance is roughly ±0.35°;
- every real SOCKET remains physically active in SIMULATE, preserving the permanent v0.5.8 closed-loop attachment rule.

### Existing fixes retained
- v0.5.10 overlap-only auto-connect remains unchanged;
- SIMULATE still does not reshape the build or manufacture nearby connections;
- closed-loop SOCKETs remain physically connected;
- duplicate axle suppression and the existing simulation-stability protections remain active;
- camera controls are untouched.

### Validation
- complete regression suite through v0.5.10 remains active;
- the long closed-frame + axle stability test now requires flex-limited closed-loop SOCKETs rather than free angular hinges;
- a new v0.5.11 rigidity regression verifies the UI setting, 0% and 100% endpoints, real SOCKET preservation, near-rigid default limits, and a 600-physics-frame stability run without runaway energy.

### Signing / update compatibility
- Android versionCode is 35;
- Android versionName is `0.5.11`;
- package ID remains `com.pixel375.connex`;
- the existing permanent Connex signing certificate is retained for an in-place update over v0.5.10.
