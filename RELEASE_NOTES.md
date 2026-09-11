# Connex Lab v0.5.20

This release follows Android device testing of v0.5.19 and fixes four editor/workflow regressions around ATTACH selection, O-Ring palette behavior, attachment-marker tracking, and reconnecting multi-rod connectors.

### Select pieces normally while ATTACH is active
The top **Select** action now takes priority over attachment-point picking when ATTACH mode is active. Press Select, tap the connector/rod/O-Ring you actually want, and the one-shot piece selection completes normally. ATTACH point picking resumes immediately afterward.

This fixes the case where ATTACH allowed green/orange points to be selected but prevented changing which physical connector was highlighted/selected.

### O-Ring selection no longer blocks ordinary rod creation
O-Ring Stop remains a special rod-mounted part, but selecting it in the connector palette no longer hijacks normal SOCKET creation. In CREATE + SOCKET, tapping a free connector socket still creates the currently selected rod exactly like it does when any ordinary connector is selected. Tapping an appropriate rod still follows the O-Ring placement path.

### ATTACH markers now track the real build pose
The attachment overlay now watches authoritative piece transforms while ATTACH is visible. If a piece or restored structure moves, the overlay is rebuilt from the current transforms rather than waiting for a later click to dirty the cache.

Old marker nodes are removed from the overlay immediately before rebuilding, so markers cannot remain visually suspended at a pre-Restore/pre-movement position for an extra frame. Restore and the return from SIMULATE also explicitly force a rebuild.

### Multi-rod reconnect now restores the other aligned rods
This fixes a recurring disconnect/reconnect bug. **Disconnect Selected** intentionally prevents every former connector/rod pair from immediately auto-fusing while the pieces are still touching. Previously, explicitly reconnecting one rod cleared that protection only for the one pair clicked. If the connector originally had two or more rods, the other rods stayed permanently excluded from auto-connect even after the connector had snapped back into the exact original position.

A successful explicit SOCKET reconnect now releases the old detach quarantine for that connector only, then runs the existing commit-time auto-connect pass. Any other free rod ends that are still geometrically aligned with free sockets on that same connector reconnect in the same edit/Undo step. Unrelated intentional disconnects elsewhere in the construction remain blocked.

### Existing fixes retained
The v0.5.19 precise crowded ATTACH picking and 11/14-point spatial CROSS orientation remain active, along with legacy AXLE save healing, midpoint CROSS rod insertion/sliding, simplified physical O-Rings, deterministic AXLE/CROSS stops, save/load repair, closed-loop handling, and the existing physics stability work.

### Regression coverage
The v0.5.20 gate reproduces the four Android reports directly: changing selected pieces while ATTACH is active; creating a rod from a free SOCKET while O-Ring Stop is selected; moving a connector and verifying its ATTACH markers immediately leave the old coordinates and appear at the new coordinates; and the exact two-rods → Disconnect Selected → reconnect one rod → second rod auto-reconnect sequence.

The v0.5.19 ATTACH/spatial-CROSS regression, legacy AXLE repair, midpoint CROSS slide, socket workflow, O-Ring stability and four-post AXLE/CROSS stop roundtrip regressions are retained.

### Android / update compatibility
- Android versionCode: 44
- Android versionName: `0.5.20`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
