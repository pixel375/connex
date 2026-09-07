extends "res://scripts/main_v036_mount_home.gd"

const VERSION_037 := "0.3.7"

# One authoritative right-side accordion state. Older versions allowed the two
# VBox bodies to become independently visible through inherited refresh paths.
var right_panel_state_v037: String = ""


func _ready() -> void:
	super._ready()
	right_panel_state_v037 = "rotate" if editor_mode_v032 == EDITOR_ROTATE_032 else ""
	_apply_right_panel_state_v037()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_037)
	_refresh_gizmo_validity_v030()
	_status("ROTATE now treats connected construction as one rigid world-space island. Camera angle and pre-existing off-axis placement cannot change or block XYZ gizmo axes.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_037, text]


# -----------------------------------------------------------------------------
# Right-side accordion: one state variable owns both panels.
# -----------------------------------------------------------------------------

func _apply_right_panel_state_v037() -> void:
	if rotation_body == null or move_body == null:
		return
	rotation_body.visible = right_panel_state_v037 == "rotate"
	move_body.visible = right_panel_state_v037 == "move"
	if rotation_collapse_button != null:
		rotation_collapse_button.text = "ROTATE ▾" if rotation_body.visible else "ROTATE ▸"
	if move_collapse_button != null:
		move_collapse_button.text = "MOVE ▾" if move_body.visible else "MOVE ▸"
	_layout_right_panels_v032()


func _sync_right_panel_state_v037() -> void:
	if rotation_body == null or move_body == null:
		return
	var want_rotate: bool = right_panel_state_v037 == "rotate"
	var want_move: bool = right_panel_state_v037 == "move"
	if rotation_body.visible != want_rotate or move_body.visible != want_move:
		_apply_right_panel_state_v037()


func _toggle_rotation_panel() -> void:
	right_panel_state_v037 = "" if right_panel_state_v037 == "rotate" else "rotate"
	_apply_right_panel_state_v037()


func _toggle_move_panel() -> void:
	right_panel_state_v037 = "" if right_panel_state_v037 == "move" else "move"
	_apply_right_panel_state_v037()


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	super._set_editor_mode_v032(mode_value, report)
	if editor_mode_v032 == EDITOR_ROTATE_032:
		right_panel_state_v037 = "rotate"
	elif right_panel_state_v037 == "rotate":
		right_panel_state_v037 = ""
	_apply_right_panel_state_v037()
	_refresh_gizmo_validity_v030()
	_refresh_attach_points_v032()


func _update_ui() -> void:
	super._update_ui()
	# Some inherited update paths touch panel visibility. Restore the single
	# authoritative state after every UI refresh, including Reset Rotation.
	_apply_right_panel_state_v037()


func _process(delta: float) -> void:
	super._process(delta)
	# Final invariant: never allow one frame with both utility panels open.
	_sync_right_panel_state_v037()


# -----------------------------------------------------------------------------
# World XYZ gizmo.
#
# v0.3.6 still built a rotation component by cutting the selected connector's
# primary mount edge and then validating that branch against the remaining
# topology. That makes ordinary world XYZ rotation impossible after a build has
# been moved, reattached, or is simply not aligned to a world cardinal plane.
#
# The XYZ gizmo is now a true game-engine transform gizmo: it rotates the entire
# connected construction island as one rigid transform around the selected
# piece. Every internal socket/cross/axle/O-ring relation is unchanged by that
# common transform, so arbitrary existing orientation is irrelevant. Dedicated
# Roll remains the connection-axis operation for changing a mounted connector's
# orientation relative to its host.
# -----------------------------------------------------------------------------

func _record_nodes_v037(record: Dictionary) -> Array:
	var result: Array = []
	for key_value in ["a", "b", "connector", "rod", "ring"]:
		var body: RigidBody3D = record.get(key_value) as RigidBody3D
		if is_instance_valid(body) and not (body in result):
			result.append(body)
	return result


func _connected_island_v037(start: RigidBody3D) -> Array:
	var result: Array = []
	if not is_instance_valid(start):
		return result
	_rebuild_connection_graph_v020()
	var pending: Array = [start]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var current: RigidBody3D = pending.pop_back() as RigidBody3D
		if not is_instance_valid(current):
			continue
		var current_id: int = current.get_instance_id()
		if seen.has(current_id):
			continue
		seen[current_id] = true
		result.append(current)
		for record_value in connections_v020:
			var record: Dictionary = record_value as Dictionary
			var nodes: Array = _record_nodes_v037(record)
			if not (current in nodes):
				continue
			for node_value in nodes:
				var node: RigidBody3D = node_value as RigidBody3D
				if is_instance_valid(node) and not seen.has(node.get_instance_id()):
					pending.append(node)
	return result


func _rotation_candidate_v030(axis_value: Vector3, steps: int) -> Dictionary:
	if simulating or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a piece"}
	if axis_value.length_squared() < 0.5:
		return {"valid": false, "reason": "invalid world axis"}
	if steps == 0:
		return {"valid": true, "transforms": {}, "component": []}
	var component: Array = _connected_island_v037(selected_piece)
	if component.is_empty():
		return {"valid": false, "reason": "selected piece is unavailable"}
	var axis: Vector3 = axis_value.normalized()
	var anchor: Vector3 = selected_piece.global_position
	var transforms: Dictionary = _rotation_delta_map_v020(component, axis, GIZMO_STEP_030 * float(steps), anchor)
	# Deliberately do not revalidate old/rest world geometry here. Every member of
	# the connection island receives the exact same rigid delta, so all relative
	# geometry is mathematically unchanged even if the island was already off-axis.
	return {"valid": true, "transforms": transforms, "component": component, "anchor": anchor, "axis": axis}


func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not tool_mode_v030.is_empty():
		return false
	var picked: Dictionary = _pick_gizmo_axis_v030(screen_pos)
	if picked.is_empty():
		return false
	var component: Array = _connected_island_v037(selected_piece)
	if component.is_empty():
		_status("Rotation blocked — selected piece is unavailable")
		return false
	gizmo_drag_active_v030 = true
	gizmo_drag_axis_v030 = picked.get("axis", Vector3.ZERO) as Vector3
	gizmo_drag_axis_name_v030 = str(picked.get("name", ""))
	gizmo_drag_center_v030 = selected_piece.global_position
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = component
	gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
	gizmo_drag_last_param_v036 = float(picked.get("param", 0.0))
	gizmo_drag_accum_angle_v036 = 0.0
	_build_rotation_ghost_v030(gizmo_drag_component_v030)
	_status("WORLD %s ring selected — rotating the whole connected island around the selected piece; exact 45° snap" % gizmo_drag_axis_name_v030)
	return true


func _refresh_gizmo_validity_v030() -> void:
	if gizmo_root_v030 == null:
		return
	var enabled: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and tool_mode_v030.is_empty()
	for name_value in ["X", "Y", "Z"]:
		if not gizmo_axes_v030.has(name_value):
			continue
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var ring: MeshInstance3D = data.get("ring") as MeshInstance3D
		var plus_label: Label3D = data.get("plus") as Label3D
		var minus_label: Label3D = data.get("minus") as Label3D
		var base_material: StandardMaterial3D = data.get("material") as StandardMaterial3D
		if is_instance_valid(ring):
			ring.material_override = base_material if enabled else gizmo_disabled_mat_v030
		if is_instance_valid(plus_label):
			plus_label.modulate = base_material.albedo_color if enabled else gizmo_disabled_mat_v030.albedo_color
		if is_instance_valid(minus_label):
			minus_label.modulate = base_material.albedo_color if enabled else gizmo_disabled_mat_v030.albedo_color


# Keep Reset's UI side effects from ever changing the accordion state.
func _reset_rotation_v020() -> void:
	var keep_panel: String = right_panel_state_v037
	super._reset_rotation_v020()
	right_panel_state_v037 = keep_panel
	_apply_right_panel_state_v037()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nROTATE: the X/Y/Z gizmo is a true fixed-world transform gizmo. It rotates the entire connected construction island rigidly around the selected piece, so camera angle, previous movement, and arbitrary existing orientation cannot change the axes or make the gizmo invalid. Every drag still snaps to exact 45° steps.\n\nROLL: Roll is separate from XYZ. It changes a mounted connector around its real connection axis while preserving the rest of the mount. Reset Placement Rotation returns that mount-relative roll/orientation to its recorded placement state.\n\nRIGHT PANELS: Rotate and Move share one accordion state. Opening either closes the other; Reset and other UI refreshes cannot reopen Move underneath Rotate.\n\nATTACH: SOCKET uses rod ends ↔ sockets. AXLE uses hub/O-Ring ↔ exact rod shaft. CROSS uses side socket ↔ rod shaft with the rod perpendicular to the connector face.\n\nCamera: one finger orbit, two fingers pan/zoom. Camera orientation never defines construction or world XYZ rotation axes." % VERSION_037


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var release: Dictionary = parsed as Dictionary
	var latest: String = str(release.get("tag_name", "")).trim_prefix("v")
	if latest.is_empty():
		return
	if _compare_versions_v021(latest, VERSION_037) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_037)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_037, latest])
