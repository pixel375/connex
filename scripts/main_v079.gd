extends "res://scripts/main_v078.gd"

const VERSION_079 := "0.5.21"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_079)
	_status("v0.5.21 ready — unified TRANSFORM keeps direct CROSS/AXLE move-drag compatibility.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_079, text]


# Older MOVE-era callers and retained regressions invoke the move-drag primitive
# directly rather than entering through _handle_move_input_v042(). TRANSFORM uses
# the old ROTATE mode id so both ring and arrow gizmos can coexist. Present that
# one call as MOVE internally, then restore TRANSFORM immediately; this is the
# same compatibility bridge used by the live input path in v0.5.21.
func _begin_move_drag_v042(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_ROTATE_032:
		return super._begin_move_drag_v042(screen_pos)
	var keep_mode: int = editor_mode_v032
	editor_mode_v032 = EDITOR_MOVE_042
	var result: bool = super._begin_move_drag_v042(screen_pos)
	editor_mode_v032 = keep_mode
	return result
