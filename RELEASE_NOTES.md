# Connex Lab v0.5.26

This corrective release addresses the save-list, updater, ATTACH-selection and Android latency issues reported after v0.5.25.

### Saves & autosaves
- Saves are now sorted by their actual saved timestamp, newest first.
- Touch-drag scrolling is handled directly by the Saves ItemList, so the list can be scrolled normally on Android.
- Autosave is now idle-debounced instead of firing 350 ms after every edit.
- Snapshot serialization and file flushing run on a worker thread instead of blocking the Android UI thread.
- The fixed crash-recovery autosave remains available.
- Five rolling automatic save points are kept; older automatic/recovery saves are pruned automatically.
- Named saves continue to be unlimited and are never included in the five-autosave cap.

### Updater
- Fixed the update checker comparing the latest GitHub release against an inherited v0.5.0 constant.
- The updater now compares against the actual running v0.5.26 version and clears any stale install state when the installed version is current.
- Rechecking while already on the latest release now shows Up to date instead of offering the same APK again.

### ATTACH / selection
- Deselect now dirties and rebuilds the ATTACH overlay before clearing a selected point, so both the underlying selection and highlighted marker disappear together.
- The visible unified Deselect button is rebound to the latest point-aware callback after UI setup.
- Occupied connector sockets no longer expose a competing ATTACH marker.
- When a rod end is connected into a socket, the rod-end ATTACH point owns that location, making reconnect/move selection unambiguous.

### Android edit-latency work
- Collapsed multiple inherited full UI refreshes during one history commit into one final visible refresh.
- Removed synchronous autosave text serialization and file flushing from the interactive editor path.
- Autosave now waits for an idle window and writes in the background, while pause/close still forces a safe final recovery write.
- Existing v0.5.25 targeted auto-connect remains in place.

### Preserved behavior
- SOCKET, AXLE, CROSS and corrected O-Ring physics behavior is unchanged.
- Save/load topology, Undo/Redo, cross-piece ATTACH retargeting, rotation progress and Parts usage counts remain intact.

### Android
- versionCode: 50
- versionName: `0.5.26`
- package ID: `com.pixel375.connex`
- Permanent Connex signing certificate retained for in-place update compatibility.