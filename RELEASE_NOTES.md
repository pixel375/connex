# Connex Lab v0.5.4

Phone interaction and auto-attachment correction release.

### Transform release no longer changes selection
- releasing a Rotate or Move gizmo is now explicitly treated as the end of the transform gesture, not as a new tap;
- a short post-release suppression window prevents the connector under the lifted finger from becoming selected;
- normal direct selection in Rotate and Move remains unchanged for genuine taps.

### Connector selection highlight rebuild
- changing a selected 11- or 14-point connector to a smaller connector now destroys the old cloned selection outline before geometry is rebuilt;
- the selection glow is regenerated from the new connector geometry immediately;
- stale top/bottom/spatial highlight geometry no longer remains after changing connector type.

### Stronger close-range auto-attachment
- free rod ends and free connector sockets use a substantially larger phone-friendly proximity capture shell;
- candidate matching ranks both distance and opposing direction so dense multi-port connectors prefer the intended nearby socket;
- explicit Disconnect snap-back blocks remain authoritative;
- if two close pieces are still separate rigid islands, the smaller/non-root island is translated rigidly to close the visible gap before the fixed connection is created;
- if the pieces already belong to the same closed structure, the new close connection is recorded without distorting the existing rigid loop.

### Validation
- all behavioral regression tests through v0.5.3 remain active;
- new v0.5.4 coverage verifies transform-release selection suppression, stale spatial-highlight replacement, capture beyond the previous 1.10 range, real connection creation, and visible gap closure for separate islands;
- Android export is required to pass before the release is published.

### Signing / update compatibility
- Android versionCode is 28;
- Android versionName is `0.5.4`;
- package ID remains `com.pixel375.connex`;
- v0.5.4 uses the existing permanent Connex signing certificate and updates in place over v0.5.3.
