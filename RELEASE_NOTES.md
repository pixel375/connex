# Connex Lab v0.5.24

This update focuses on touch usability, clearer editing feedback, attachment workflow improvements, build inventory visibility, and a substantial BUILD-mode performance pass for larger constructions.

### Selection and editing
- **Deselect** is now the single context-aware deselection control for both selected pieces and selected ATTACH points.
- Deselect remains enabled when only an ATTACH point is selected.
- Undo now automatically clears the current piece selection, ATTACH-point selection, highlights and active editor gizmos so the bottom part arrows return to choosing the next part instead of unintentionally editing the item restored by Undo.
- ATTACH can explicitly reconnect/move a selected connection from its current piece to a compatible point on a different tapped piece while preserving the existing same-piece socket reseat workflow and Undo behavior.

### Larger touch controls
- The Select icon is larger.
- Bottom rod/connector previous-next arrows are larger.
- CREATE / TRANSFORM / ATTACH buttons are taller.
- New Rod and New Connector are now full-width stacked buttons rather than sharing one narrow row.
- Disconnect and Deselect are larger touch targets.

### Rotation feedback
- Holding and dragging a rotation gizmo now shows a circular progress indicator around the selected construction.
- The indicator is axis-colored and includes 45-degree tick marks.
- A colored arc shows the currently snapped rotation angle.
- A white marker moves continuously between snap points so rotationally/symmetrically similar parts are easier to orient.
- The live label shows the active axis and exact snapped angle, and blocked previews are clearly indicated.

### Save confirmation
- A successful manual save now displays a confirmation dialog: **Build has been saved.**
- The dialog includes a clear **Close** button.

### Parts usage inventory
- Every card in the Parts menu now shows how many pieces of that exact type are currently used in the build.
- The Parts header also shows the total number of pieces in the construction.
- Counts are derived from the authoritative live construction, so Delete, Undo, Redo, Restart and loaded saves cannot leave stale totals.
- O-Ring Stops are included in the inventory.

### BUILD-mode performance
- Removed expensive connection/rotation validity calculations that were still running for retired hidden rotation controls after ordinary UI refreshes.
- Removed unnecessary whole-construction trial rotations that were previously performed simply to color or update retired/hidden rotation controls. Rotation remains fully validated when the user actually drags it.
- Normal auto-connect processing now focuses on pieces that actually changed instead of repeatedly scanning every rod against every connector after each edit.
- A complete whole-build connection pass is still retained before SIMULATE and after removals, preserving connection correctness while avoiding the expensive repeated BUILD-mode scans.
- Immediate live ATTACH marker tracking is preserved; the performance work deliberately targets the expensive graph/rotation scans rather than delaying marker updates.
- Parts-browser card refreshes remove old controls immediately rather than keeping duplicate queued card trees alive until the end of the frame.

### Physics and compatibility
- Existing SOCKET, AXLE, CROSS and O-Ring physics behavior is intentionally preserved; this performance pass does not alter the corrected O-Ring stop mechanics.
- Android versionCode: 48
- Android versionName: `0.5.24`
- package ID: `com.pixel375.connex`
- Permanent Connex signing certificate retained for in-place update compatibility.