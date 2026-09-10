# Connex Lab v0.5.17

This release fixes the AXLE/CROSS-stop failure where a freshly built mechanism could pass through physical stops, while the same visible construction could become locked after saving and loading it again.

### Deterministic AXLE physics
AXLE joints are now normalized before simulation to the intended two free degrees of freedom: translation along the shaft and rotation around it. Both rigid islands participating in an authoritative AXLE mechanism remain awake while physics is running, and temporary solver bookkeeping no longer decides whether a real AXLE is allowed to move.

Physical collision is preserved across the two sides of an AXLE. Ordinary CROSS-mounted connectors and O-Ring Stops therefore remain real physical blockers for an AXLE-mounted connector instead of accidentally inheriting broad rigid-component collision exclusions. The direct hub-to-shaft collision exception is retained because the simplified hub collider is solid and the shaft passes through it by design.

### Save/load AXLE reconstruction fix
The save/load path now records AXLE identity explicitly and reconstructs AXLE relationships from stable piece IDs. It no longer relies on the older generic joint serializer to infer AXLE-vs-fixed behavior from a joint name.

A second restore bug was found and fixed: affected saves could reconstruct the same hub/shaft pair twice — once as the correct AXLE and again as a false fixed/socket connection. The stable-simulation preflight then saw both sides as one rigid component and disabled the real AXLE as redundant, producing the reported "does not move after reload" behavior. v0.5.17 removes those false fixed duplicates during restore and writes new saves with the correct joint type.

The restore repair also keeps compatibility with older v0.5.16-and-earlier saves by using saved AXLE records, surviving AXLE joints, and the existing hub/shaft geometry as recovery evidence when necessary.

### Regression coverage
A dedicated four-post regression reproduces the reported construction: one rigid square frame on four AXLE hubs, four vertical shafts, and four ordinary Gray 1-way CROSS connectors used as physical stops. The same fixture is run once as a fresh build and again after the exact named-save/load round trip used by the app.

The regression requires all four hubs to retain their AXLE free motion, slide under gravity, remain centered on their shafts, stay awake, collide with their CROSS stops, never pass through those stops, and produce the same result after save/load. The retained AXLE, O-Ring, closed-loop, rigidity, editor, and long-running physics regressions remain enabled as release gates.

### Android / update compatibility
- Android versionCode: 41
- Android versionName: `0.5.17`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
