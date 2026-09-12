extends "res://scripts/main_v091.gd"

const VERSION_092 := "0.5.28"

# v0.5.28 visible-first placement already defers history, auto-connect and graph
# bookkeeping. Profiling showed the remaining ~100 ms synchronous cost in CI was
# the selection-driven _update_ui() invoked by _set_selected() before the frame
# could be presented. The real body is already created and connected at that
# point, so defer that UI repaint as well. The v0.5.26 single-refresh commit path
# performs the authoritative UI refresh during the post-draw finalize.
func _update_ui() -> void:
	if placement_fast_context_v091 and not placement_commit_flushing_v091:
		return
	super._update_ui()
