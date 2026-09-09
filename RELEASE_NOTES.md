# Connex Lab v0.5.13

Focused physics-stability release for O-Ring Stops and awkward mixed axle/socket constructions. Camera behavior is intentionally unchanged.

### O-Ring Stops no longer become invisible world anchors
O-Ring Stops were stored separately from the normal construction-body list. SIMULATE released the normal bodies but left O-Ring rigid bodies frozen in world space while their hard fixed joint remained attached to the host rod. That could make an O-Ring appear to ignore gravity and could inject large constraint energy into the entire construction.

v0.5.13 changes the simulation representation of an O-Ring Stop:
- the editable O-Ring remains a normal separate piece in BUILD;
- when SIMULATE starts, its standalone rigid-body joint is removed from the active solver;
- its collision shape is temporarily incorporated into the host rod, so it still behaves as a physical axle stop;
- the visible ring is parented directly to the rod at its exact saved local position and therefore follows gravity and motion with the rod without lag;
- BUILD/Restore restores the original editable O-Ring body, collision state, parent and fixed joint.

This removes the tiny high-frequency rigid-body/weld pair that was responsible for the O-Ring static behavior and a major source of solver instability.

### Mixed-build impact stability
Some unusual axle/socket constructions could look correct for several seconds and then gain impossible energy after an uneven ground impact, launching pieces or the whole construction across the scene.

v0.5.13 strengthens that path with:
- the O-Ring host-physics integration above;
- Jolt as the 3D physics backend;
- higher solver iteration counts for constrained assemblies;
- continuous collision detection while SIMULATE is active to reduce deep penetration from long thin rods during fast impacts;
- the existing high-threshold runaway-energy guard retained only as an emergency fallback. The normal v0.5.13 stress fixture is required to complete without using it.

### Existing behavior retained
- every real SOCKET remains physically active in SIMULATE, preserving the permanent v0.5.8 closed-loop rule;
- v0.5.10 overlap-only auto-connect remains unchanged and SIMULATE does not reshape the build;
- Structure Rigidity remains a next-run setting while simulation is active;
- axle rods remain awake and free to slide along their intended axle axis;
- camera controls are untouched.

### Validation
All regressions from v0.5.2 through v0.5.12 pass on the v0.5.13 runtime.

The new v0.5.13 stress regression intentionally builds a difficult assembly with a long vertical axle, two independently sliding axle hubs, five offset spokes and two O-Ring Stops, then lets it fall and strike the ground asymmetrically for an extended physics run. The same fixture previously reached runaway speeds above 300 linear and 3000 angular. With the final v0.5.13 implementation it completes without invoking the emergency guard, with validated maxima of:
- linear speed: 16.77;
- angular speed: 5.15.

The test also verifies that both O-Rings visibly fall with their host rod, remain exactly fixed at their intended rod positions, retain physical stop collision through the host rod, and restore correctly for BUILD editing.

### Signing / update compatibility
- Android versionCode is 37;
- Android versionName is `0.5.13`;
- package ID remains `com.pixel375.connex`;
- the existing permanent Connex signing certificate is retained for an in-place update over v0.5.12.
