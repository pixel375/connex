extends "res://scripts/main_v033.gd"

const VERSION_034 := "0.3.4"
const ATTACH_PICK_RADIUS_034 := 34.0

var screen_gizmo_v034: Control


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_034)
	_status("CREATE mode — v0.3.4 uses a camera-independent HUD rotation dial and simplified physical attachment ports.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_034, text]


# -----------------------------------------------------------------------------
# Rotation v0.3.4
#
# The old 3D projected rings used ray/plane intersection. Although their world
# axes were fixed, the gesture itself was still interpreted through the camera
# projection and felt different from different viewpoints. v0.3.4 removes that
# input path completely. The dial below is a pure 2D HUD control. Its X/Y/Z
# rings never move with the camera; only the resulting 3D transform does.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	_hide_legacy_rotation_labels_v034(rotation_body)
	if rotation_body != null:
		rotation_body.add_child(_section_label("PART-LOCAL XYZ DIAL • CAMERA-INDEPENDENT"))
		var instructions := Label.new()
		instructions.text = "Drag a ring or tap its left/right half. Every step is exactly 45°. Gray = blocked by the connection graph."
		instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instructions.add_theme_font_size_override("font_size", 11)
		instructions.add_theme_color_override("font_color", Color(0.65, 0.74, 0.82))
		rotation_body.add_child(instructions)
		var center := CenterContainer.new()
		center.custom_minimum_size = Vector2(0.0, 196.0)
		rotation_body.add_child(center)
		var gizmo_script: Script = load("res://scripts/rotation_gizmo_screen.gd")
		if gizmo_script != null:
			screen_gizmo_v034 = gizmo_script.new() as Control
			if screen_gizmo_v034 != null:
				center.add_child(screen_gizmo_v034)
				screen_gizmo_v034.connect("rotation_requested", Callable(self, "_on_screen_rotation_requested_v034"))
	_update_screen_gizmo_v034()


func _hide_legacy_rotation_labels_v034(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		if child_value is Label:
			var label := child_value as Label
			var upper := label.text.to_upper()
			if "CAMERA-RELATIVE" in upper or "WORLD XYZ GIZMO" in upper or "DRAG RINGS" in upper:
				label.visible = false
		_hide_legacy_rotation_labels_v034(child_value)


func _begin_gizmo_drag_v030(_screen_pos: Vector2) -> bool:
	# The world-projected 3D rings are display-only legacy objects now. All
	# rotation input is consumed by rotation_gizmo_screen.gd.
	return false


func _process(delta: float) -> void:
	super._process(delta)
	if gizmo_root_v030 != null:
		gizmo_root_v030.visible = false
	if screen_gizmo_v034 != null:
		screen_gizmo_v034.visible = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating


func _selected_local_axis_v034(axis_name: String) -> Vector3:
	if not is_instance_valid(selected_piece):
		return Vector3.ZERO
	var basis_value: Basis = selected_piece.global_transform.basis.orthonormalized()
	match axis_name:
		"X":
			return basis_value.x.normalized()
		"Y":
			return basis_value.y.normalized()
		"Z":
			return basis_value.z.normalized()
	return Vector3.ZERO


func _rotation_candidate_v034(axis_name: String, steps: int) -> Dictionary:
	if simulating or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a piece"}
	if steps == 0:
		return {"valid": true, "transforms": {}}
	var axis_value: Vector3 = _selected_local_axis_v034(axis_name)
	if axis_value.length_squared() < 0.5:
		return {"valid": false, "reason": "invalid local axis"}
	var context: Dictionary = _rotation_context_v030(selected_piece)
	if not bool(context.get("valid", false)):
		return context
	var component: Array = context.get("component", []) as Array
	var anchor: Vector3 = context.get("anchor", selected_piece.global_position) as Vector3
	var transforms: Dictionary = _rotation_delta_map_v020(component, axis_value, GIZMO_STEP_030 * float(steps), anchor)
	var validation: Dictionary = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "connections block that rotation")), "transforms": transforms}
	return {"valid": true, "transforms": transforms, "axis": axis_value, "anchor": anchor}


func _on_screen_rotation_requested_v034(axis_name: String, steps: int) -> void:
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating:
		return
	var preview: Dictionary = _rotation_candidate_v034(axis_name, steps)
	if not bool(preview.get("valid", false)):
		_status("%s rotation blocked — %s" % [axis_name, str(preview.get("reason", "connection geometry prevents it"))])
		_update_screen_gizmo_v034()
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated local %s by %d°" % [axis_name, steps * 45])
	_update_screen_gizmo_v034()


func _update_screen_gizmo_v034() -> void:
	if screen_gizmo_v034 == null:
		return
	var usable: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece)
	for axis_name in ["X", "Y", "Z"]:
		var minus_ok: bool = usable and bool(_rotation_candidate_v034(axis_name, -1).get("valid", false))
		var plus_ok: bool = usable and bool(_rotation_candidate_v034(axis_name, 1).get("valid", false))
		screen_gizmo_v034.call("set_axis_validity", axis_name, minus_ok, plus_ok)


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	super._set_editor_mode_v032(mode_value, report)
	if editor_mode_v032 == EDITOR_ROTATE_032 and rotation_body != null and not rotation_body.visible:
		_toggle_rotation_panel()
	_update_screen_gizmo_v034()


func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	if mode_hint_v032 == null:
		return
	match editor_mode_v032:
		EDITOR_ROTATE_032:
			mode_hint_v032.text = "Fixed HUD XYZ dial + real-mount Roll"
		EDITOR_ATTACH_032:
			mode_hint_v032.text = "Tap a port; tap a rod shaft for CROSS/AXLE"


func _update_ui() -> void:
	super._update_ui()
	_update_screen_gizmo_v034()


# -----------------------------------------------------------------------------
# ATTACH v0.3.4
#
# No arbitrary five-dot rod-body grid. Only true discrete ports are drawn.
# Rod-body attachment is chosen by tapping the actual rod shaft, producing one
# exact temporary point at the tap location.
# -----------------------------------------------------------------------------

func _all_attach_points_v032() -> Array:
	var result: Array = []
	_rebuild_connection_graph_v020()
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var kind: String = str(body.get_meta("kind", ""))
		if kind == "rod":
			for sign_value in [-1, 1]:
				result.append({"type": "rod_end", "body": body, "sign": sign_value, "point": _rod_end_v020(body, sign_value)})
		elif kind == "connector":
			var def_index: int = int(body.get_meta("connector_type", -1))
			if def_index >= 0 and def_index < connector_defs.size():
				for slot_value in connector_defs[def_index]["slots"]:
					var slot: int = int(slot_value)
					result.append({"type": "socket", "body": body, "slot": slot, "point": _socket_world_v020(body, slot)["point"]})
			result.append({"type": "connector_hub", "body": body, "point": body.global_position})
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			result.append({"type": "o_ring", "body": ring, "point": ring.global_position})
	return result


func _refresh_attach_points_v032() -> void:
	if attach_points_root_v032 == null:
		return
	_clear_children_v030(attach_points_root_v032)
	if editor_mode_v032 != EDITOR_ATTACH_032 or simulating or help_panel.visible or options_panel.visible:
		return

	var current_key: String = _point_key_v032(attach_point_selected_v032)
	var found_selected: bool = current_key.is_empty()
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		var selected: bool = not current_key.is_empty() and _point_key_v032(point) == current_key
		if selected:
			found_selected = true
			attach_point_selected_v032 = point.duplicate(true)
		var occupied: bool = not _connection_record_for_point_v032(point).is_empty()
		var type_value: String = str(point.get("type", ""))
		var scale_value: float = 0.18 if selected else (0.105 if type_value in ["connector_hub", "o_ring"] else 0.085)
		var material: StandardMaterial3D = _point_material_v032(point, selected)
		if occupied and not selected:
			scale_value = 0.075
		_make_handle_v030(attach_points_root_v032, point["point"] as Vector3, material, scale_value)

	# A rod-body selection exists only at the exact place the user tapped. It is
	# intentionally not replicated down the rod as a cloud of possible points.
	if not attach_point_selected_v032.is_empty() and str(attach_point_selected_v032.get("type", "")) == "rod_body":
		var selected_body: RigidBody3D = attach_point_selected_v032.get("body") as RigidBody3D
		if is_instance_valid(selected_body):
			found_selected = true
			_make_handle_v030(attach_points_root_v032, attach_point_selected_v032["point"] as Vector3, point_selected_mat_v032, 0.18)

	if not found_selected:
		attach_point_selected_v032 = {}

	if not attach_point_selected_v032.is_empty():
		var label := Label3D.new()
		label.text = _point_display_v032(attach_point_selected_v032)
		label.font_size = 23
		label.modulate = Color(1.0, 0.94, 0.22)
		label.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
		label.outline_size = 6
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		attach_points_root_v032.add_child(label)
		label.global_position = (attach_point_selected_v032["point"] as Vector3) + Vector3.UP * 0.40
	_update_mode_ui_v032()


func _pick_attach_point_v034(screen_pos: Vector2) -> Dictionary:
	var discrete: Dictionary = _nearest_projected_candidate_v030(_all_attach_points_v032(), screen_pos, ATTACH_PICK_RADIUS_034)
	if not discrete.is_empty():
		return discrete
	var hit: Dictionary = _raycast_piece(screen_pos)
	if hit.is_empty():
		return {}
	var rod: RigidBody3D = hit.get("collider") as RigidBody3D
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		return {}
	var axis: Vector3 = _rod_axis_v020(rod)
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.38)
	var hit_point: Vector3 = hit.get("position", rod.global_position) as Vector3
	var along: float = clampf((hit_point - rod.global_position).dot(axis), -half_len, half_len)
	return {"type": "rod_body", "body": rod, "along": along, "point": rod.global_position + axis * along}


func _same_attach_point_v034(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if a.get("body") != b.get("body") or str(a.get("type", "")) != str(b.get("type", "")):
		return false
	if str(a.get("type", "")) == "rod_body":
		return absf(float(a.get("along", 0.0)) - float(b.get("along", 0.0))) < 0.18
	return _point_key_v032(a) == _point_key_v032(b)


func _pair_mode_v032(a: Dictionary, b: Dictionary) -> int:
	var at: String = str(a.get("type", ""))
	var bt: String = str(b.get("type", ""))
	if (at == "o_ring" and bt == "rod_body") or (at == "rod_body" and bt == "o_ring"):
		return 1
	return super._pair_mode_v032(a, b)


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	if simulating:
		return
	var picked: Dictionary = _pick_attach_point_v034(screen_pos)
	if picked.is_empty():
		_status("ATTACH mode — tap a colored port, or tap directly on a rod shaft for a CROSS/AXLE point")
		return

	if not attach_point_selected_v032.is_empty() and _same_attach_point_v034(attach_point_selected_v032, picked):
		_deselect_attach_point_v032(false)
		_status("Attachment point deselected")
		return

	if attach_point_selected_v032.is_empty():
		attach_point_selected_v032 = picked.duplicate(true)
		_refresh_attach_points_v032()
		_status("Selected %s. Tap a compatible free counterpart." % _point_display_v032(picked))
		return

	var first: Dictionary = attach_point_selected_v032
	var inferred_mode: int = _pair_mode_v032(first, picked)
	if inferred_mode < 0:
		attach_point_selected_v032 = picked.duplicate(true)
		_refresh_attach_points_v032()
		_status("Selected %s" % _point_display_v032(picked))
		return

	var first_record: Dictionary = _connection_record_for_point_v032(first)
	var target_record: Dictionary = _connection_record_for_point_v032(picked)
	if not target_record.is_empty():
		if not first_record.is_empty() and int(first_record.get("uid", -1)) == int(target_record.get("uid", -2)):
			_deselect_attach_point_v032(false)
			_status("Those two points are already connected")
			return
		attach_point_selected_v032 = picked.duplicate(true)
		_refresh_attach_points_v032()
		_status("That port is occupied. It is now selected instead of accepting a second connection.")
		return

	var source: Dictionary = first
	var target: Dictionary = picked
	# O-Rings are the moving axle-stop piece even if the rod shaft was tapped first.
	if str(first.get("type", "")) == "rod_body" and str(picked.get("type", "")) == "o_ring":
		source = picked
		target = first

	if _connect_points_v032(source, target, inferred_mode):
		attach_point_selected_v032 = {}
		_refresh_attach_points_v032()
	else:
		_refresh_attach_points_v032()


# -----------------------------------------------------------------------------
# Version/help/updater awareness.
# -----------------------------------------------------------------------------

func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCREATE: normal construction only.\n\nROTATE: the right panel contains a screen-space X/Y/Z dial. The dial itself never moves or reorients with the camera. Its rings rotate the selected rigid branch around the selected piece's deterministic local X/Y/Z axes in exact 45° steps. Left ring half = negative, right half = positive; gray halves are invalid. Roll remains the separate real mount-axis operation.\n\nATTACH: only real discrete ports are shown: rod ends, connector sockets, axle hubs, and O-Rings. There are no artificial rod-body dot grids. For CROSS or AXLE, tap directly on the physical rod shaft at the desired position. First tap selects a source in yellow; second compatible free point connects/reconnects atomically. Occupied targets cannot accept another edge.\n\nCamera: one finger orbit, two fingers pan/zoom. Camera orientation never changes rotation math.\n\nOptions and updater settings persist between launches." % VERSION_034


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
	if _compare_versions_v021(latest, VERSION_034) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_034)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_034, latest])
