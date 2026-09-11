# Connex Lab v0.5.25

This is a focused hotfix for the two regressions reported after v0.5.24: the left editor controls became too large, and BUILD interaction latency became worse even on small constructions.

### Left toolbar
- Restored CREATE / TRANSFORM / ATTACH controls to their normal pre-v0.5.24 height.
- Restored Disconnect and Deselect to their normal compact height.
- Restored New Rod and New Connector to their normal button height while keeping the useful full-width stacked layout.
- Reduced the left panel footprint accordingly.

### BUILD-mode performance hotfix
- Removed the v0.5.24 whole-body change-discovery pass from ordinary commits. It previously allocated and compared per-body state for the entire build before deciding what to auto-connect.
- Replaced the v0.5.24 fixed 32-pass local auto-connect loop with bounded edit-local matching.
- Normal CREATE / ATTACH / palette edits now start from the currently edited piece instead of first scanning every body for changes.
- TRANSFORM checks only the selected fixed component, and only members whose transforms actually moved are considered for new automatic connections.
- Connection-graph rebuilds now occur only after an actual successful automatic match rather than through repeated empty passes.
- The auto-connect snapshot cache now stores only one Transform3D per body instead of nested state dictionaries.
- When the Parts browser is already open, live usage counts update existing cards in place instead of destroying and recreating the complete card grid after every commit.
- Full whole-build auto-connect remains in place before SIMULATE and after removals, so correctness is retained where a global pass is actually required.

### Preserved from v0.5.24
- Save confirmation dialog.
- Live per-part usage counts.
- Undo automatically deselects the restored item.
- Unified Deselect behavior.
- Cross-piece ATTACH retargeting.
- Rotation progress indicator.
- Existing SOCKET, AXLE, CROSS and corrected O-Ring physics behavior is unchanged.

### Android
- versionCode: 49
- versionName: `0.5.25`
- package ID: `com.pixel375.connex`
- Permanent Connex signing certificate retained for in-place update compatibility.