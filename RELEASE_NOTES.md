# Connex Lab v0.5.5

Phantom-highlight and closed-loop attachment correction release.

### Phantom selection geometry actually removed
- the remaining cyan phantom geometry after changing an 11/14-point connector was traced to old connector meshes waiting in Godot's `queue_free()` deletion queue;
- those queued source meshes were still present long enough to be cloned into the replacement selection outline;
- connector rebuilds now detach old meshes, collision shapes and spatial roots synchronously before new geometry is created;
- recursive highlight generation also ignores any node already queued for deletion;
- changing 14-point → 1/2/3/4-way now builds the highlight only from the connector geometry that really exists.

### Close connections now snap as geometry, not only as graph records
- v0.5.4 could record a valid same-structure loop connection while leaving the rod end and socket visibly apart;
- v0.5.5 projects recorded attachment points into a physically closed BUILD pose instead of accepting that visible gap as the connection's rest pose;
- iterative position/orientation projection distributes a small closure correction through an already-connected construction while keeping the root piece fixed;
- newly detected loop closures receive priority so the endpoint the user is trying to join is not left as the remaining visible error;
- corrected transforms become the stored BUILD pose used by Restore.

### Simulation no longer exposes stored loop gaps
- the existing physics stabilizer still suppresses mathematically redundant fixed joints in closed loops to avoid over-constrained solver instability;
- immediately before that suppression step, v0.5.5 re-normalizes all recorded attachment geometry;
- this prevents a suppressed redundant edge from revealing a gap that had been saved into the build pose.

### Wider but safer automatic capture
- free rod ends/sockets retain a substantially wider phone-friendly capture shell than older releases;
- farther candidates must now have much stronger opposing insertion direction and a limited lateral miss;
- distance, lateral offset and direction are jointly scored so a nearby 8/11/14-point hub does not snap to an unrelated neighboring port;
- explicit Disconnect snap-back protection remains authoritative.

### Validation
- the complete behavioral regression suite through v0.5.4 remains active;
- the new v0.5.5 regression verifies that queued old meshes cannot enter a replacement highlight;
- it verifies automatic capture beyond v0.5.4's 2.0-unit mathematical endpoint range;
- it constructs a deliberately misaligned same-island closed loop, auto-attaches the final free endpoint, verifies the visible gap is projected closed, then runs redundant-joint simulation preflight and verifies the closure remains closed;
- Android export and permanent signing must pass before publication.

### Signing / update compatibility
- Android versionCode is 29;
- Android versionName is `0.5.5`;
- package ID remains `com.pixel375.connex`;
- v0.5.5 uses the existing permanent Connex signing certificate and updates in place over v0.5.4.
