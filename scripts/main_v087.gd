extends "res://scripts/main_v086.gd"

const VERSION_087 := "0.5.24"

var suppress_autofuse_v087: bool = false


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_087)
	_status("v0.5.24 ready — UI refinements, reconnect workflow, live rotation feedback, inventory counts and build-mode performance optimizations are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_087, text]


# main_v077 adds Android-friendly scroll handling after every Parts rebuild.
# v0.5.24 replaces the card contents to show live inventory counts, so reapply
# that inherited touch configuration after the custom card refresh.
func _refresh_parts_browser_v050() -> void:
	super._refresh_parts_browser_v050()
	if parts_panel_v050 != null:
		_configure_scroll_touch_v077(parts_panel_v050, false)


# Disconnect is an explicit user request to keep overlapping parts detached.
# Never let any automatic overlap matcher run inside that same history commit;
# the manual-detach quarantine must be authoritative before later build edits.
func _auto_connect_all_v020() -> int:
	if suppress_autofuse_v087:
		return 0
	return super._auto_connect_all_v020()


func _disconnect_selected_v042() -> void:
	suppress_autofuse_v087 = true
	super._disconnect_selected_v042()
	suppress_autofuse_v087 = false
	_rebuild_connection_graph_v020()
	_snapshot_autofuse_bodies_v086()
	_refresh_parts_usage_if_open_v086()


# The old right-side exact-step rotation panel is retired by unified TRANSFORM.
# Do not run six full construction previews merely to update invisible buttons.
# The visible gizmo validates the actual requested step during a drag/commit.
func _update_rotation_fallback_buttons_v042(enabled: bool) -> void:
	for button_value in [rot_x_minus_v042, rot_x_plus_v042, rot_y_minus_v042, rot_y_plus_v042, rot_z_minus_v042, rot_z_plus_v042]:
		var button := button_value as Button
		if button != null:
			button.disabled = not enabled
