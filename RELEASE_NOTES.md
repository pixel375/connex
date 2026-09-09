# Connex Lab v0.5.12

Focused physics correction for two v0.5.11 device regressions. Camera behavior is intentionally unchanged.

### Structure Rigidity no longer locks a running simulation
v0.5.11 applied Structure Rigidity by rewriting Generic6DOF angular limits immediately while SIMULATE was active. If a stabilized closed-loop SOCKET had already flexed outside the newly selected limit, the physics solver could respond with a large correction and make the construction appear frozen or locked.

v0.5.12 treats Structure Rigidity as a simulation-start setting:
- moving the rigidity slider during SIMULATE saves the new value but does **not** alter any active joint limits;
- the current run keeps the rigidity value it started with;
- the selected value is applied the next time SIMULATE starts;
- the Physics label shows that the changed value is for the **NEXT RUN** while simulation is active;
- Reset Physics follows the same solver-safe rule for Structure Rigidity.

### AXLE rods keep responding to gravity
AXLE connections intentionally leave translation and rotation along the axle axis free. A vertical axle rod could nevertheless settle into a sleeping state and appear pinned even though its slide degree of freedom was open.

v0.5.12:
- identifies axle rods from the authoritative connection graph;
- keeps axle rods awake while SIMULATE is running;
- keeps them dynamic and responsive to gravity/support changes along the free slide axis;
- restores the normal sleep policy when returning to BUILD/Restore.

### Existing physics protections retained
- Structure Rigidity remains 92% by default;
- normal SOCKETs remain rigid;
- only redundant closed-loop SOCKET edges receive the small configurable flex allowance;
- every real SOCKET remains physically active in SIMULATE, preserving the permanent v0.5.8 closed-loop rule;
- v0.5.10 overlap-only auto-connect remains unchanged and SIMULATE does not reshape the build;
- camera controls are untouched.

### Validation
- all regressions through v0.5.11 pass on the v0.5.12 runtime;
- the existing long closed-frame physics stability test remains green;
- the 600-frame Structure Rigidity stability test remains green;
- a new v0.5.12 regression confirms that changing rigidity during SIMULATE leaves the active solver limits unchanged, applies the new setting only on the next run, and verifies that a supported vertical axle rod slides downward through its hub under gravity.

### Signing / update compatibility
- Android versionCode is 36;
- Android versionName is `0.5.12`;
- package ID remains `com.pixel375.connex`;
- the existing permanent Connex signing certificate is retained for an in-place update over v0.5.11.
