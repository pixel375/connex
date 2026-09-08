extends "res://scripts/main_v050_hotfix.gd"

const VERSION_051 := "0.5.1-dev"
const SPACE_ITEM_051 := 0
const SPACE_WORLD_051 := 1

var transform_space_v051: int = SPACE_ITEM_051
var rotate_space_button_v051: Button
var move_space_button_v051: Button
var physics_panel_v051: PanelContainer
var physics_button_v051: Button
var physics_box_v051: VBoxContainer


func _ready() -> void:
	super._ready()
	_install_space_controls_v051()
	_build_physics_panel_v051()
	_apply_hybrid_palette_v051()
	_update_mode_ui_v032()
	_update_transform_ui_v051()
	_status("Item-aware editor active — ITEM is the default transform space; WORLD explicitly moves/rotates the connected construction.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_051, text]


# -----------------------------------------------------------------------------
# Mode highlighting: v0.4 inserted MOVE as mode id 3 but displayed it at array
# index 2, which made MOVE highlight ATTACH and ATTACH highlight MOVE.
# -----------------------------------------------------------------------------

func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	var entries: Array = [
		[create_button_v032, EDITOR_CREATE_032, "CREATE"],
		[rotate_button_v032, EDITOR_ROTATE_032, "ROTATE"],
		[move_mode_button_v042, EDITOR_MOVE_042, "MOVE"],
		[attach_button_v032, EDITOR_ATTACH_032, "ATTACH"]
	]
	for entry_value in entries:
		var entry: Array = entry_value as Array
		var button: Button = entry[0] as Button
		if button == null:
			continue
		var active: bool = editor_mode_v032 == int(entry[1])
		button.text = ("● " if active else "") + str(entry[2])
		button.self_modulate = Color(0.68, 0.94, 1.0) if active else Color.WHITE
	if mode_hint_v032 != null:
		if editor_mode_v032 == EDITOR_MOVE_042:
			mode_hint_v032.text = ("Item-valid movement only" if transform_space_v051 == SPACE_ITEM_051 else "WORLD XYZ group movement")
		elif editor_mode_v032 == EDITOR_ROTATE_032:
			mode_hint_v032.text = ("Item-valid rotation only" if transform_space_v051 == SPACE_ITEM_051 else "WORLD XYZ group rotation")


# -----------------------------------------------------------------------------
# ATTACH cleanup and reconnect behavior.
# -----------------------------------------------------------------------------

func _update_attach_preview_v042() -> void:
	# The cursor tether/line created more ambiguity than guidance on touch screens.
	# ATTACH is now marker-only.
	if attach_preview_line_v042 != null:
		attach_preview_line_v042.visible = false


func _same_connector_socket_target_v051(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	if attach_mode != 0 or str(source.get("type", "")) != "socket":
		return {}
	var connector: RigidBody3D = source.get("body") as RigidBody3D
	if not is_instance_valid(connector):
		return {}
	var candidates: Array = []
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		if point.get("body") == connector and str(point.get("type", "")) == "socket" and int(point.get("slot", -1)) != int(source.get("slot", -1)):
			if _connection_record_for_point_v032(point).is_empty():
				candidates.append(point)
	return _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PICK_RADIUS_V040)


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	# Special case for the common "move this occupied rod to another fork" action.
	# When the overlapping occupied marker selected the connector socket rather
	# than the rod end, tapping another socket on that SAME connector now means
	# "move the rod end here" instead of being rejected as same-body geometry.
	if not attach_point_selected_v032.is_empty() and attach_mode == 0:
		var source: Dictionary = attach_point_selected_v032
		var record: Dictionary = _connection_record_for_point_v032(source)
		if str(source.get("type", "")) == "socket" and not record.is_empty() and str(record.get("kind", "")) == "socket":
			var new_socket: Dictionary = _same_connector_socket_target_v051(screen_pos, source)
			if not new_socket.is_empty():
				var rod: RigidBody3D = record.get("rod") as RigidBody3D
				var rod_end: int = int(record.get("rod_end", 0))
				if is_instance_valid(rod) and rod_end != 0:
					var moving_end: Dictionary = {"type": "rod_end", "body": rod, "sign": rod_end, "point": _rod_end_v020(rod, rod_end)}
					if _connect_points_v035(moving_end, new_socket):
						attach_point_selected_v032 = {}
						attach_overlay_dirty_v050 = true
						_refresh_attach_points_v032()
						_status("SOCKET re-attached — occupied connection moved to the selected connector fork")
						return
	attach_overlay_dirty_v050 = true
	super._handle_attach_point_tap_v032(screen_pos)


func _clear_cross_plus_v051() -> void:
	if attach_points_root_v032 == null:
		return
	for child_value in attach_points_root_v032.get_children():
		var child: Node = child_value as Node
		if child != null and str(child.name).begins_with("CrossPlusV051"):
			attach_points_root_v032.remove_child(child)
			child.queue_free()


func _refresh_attach_points_v032() -> void:
	super._refresh_attach_points_v032()
	if attach_points_root_v032 == null:
		return
	_clear_cross_plus_v051()
	if editor_mode_v032 != EDITOR_ATTACH_032 or attach_mode != 2 or simulating:
		return
	# CROSS points are deliberately represented by a bold billboarded + instead
	# of the generic spheres. Hide generic marker meshes, keep the selected label.
	for child_value in attach_points_root_v032.get_children():
		if child_value is MeshInstance3D:
			(child_value as MeshInstance3D).visible = false
	var selected_key: String = _point_key_v032(attach_point_selected_v032)
	var index: int = 0
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		var type_value: String = str(point.get("type", ""))
		if type_value not in ["socket", "rod_body"]:
			continue
		var key: String = _point_key_v032(point)
		var selected: bool = not selected_key.is_empty() and key == selected_key
		var label: Label3D = Label3D.new()
		label.name = "CrossPlusV051_%d" % index
		index += 1
		label.text = "+"
		label.font_size = 72 if selected else 54
		label.modulate = Color(1.0, 0.92, 0.08) if selected else (Color(0.18, 1.0, 0.46) if type_value == "socket" else Color(0.22, 0.62, 1.0))
		label.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
		label.outline_size = 11
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		attach_points_root_v032.add_child(label)
		label.global_position = point.get("point", Vector3.ZERO) as Vector3


# -----------------------------------------------------------------------------
# Hybrid parts palette: keep the fast arrows AND the full Parts browser.
# -----------------------------------------------------------------------------

func _clean_bottom_palette_v050() -> void:
	super._clean_bottom_palette_v050()
	_apply_hybrid_palette_v051()


func _apply_hybrid_palette_v051() -> void:
	if bottom_panel == null or rod_label == null:
		return
	var row: HBoxContainer = rod_label.get_parent() as HBoxContainer
	if row == null:
		return
	for child_value in row.get_children():
		var button: Button = child_value as Button
		if button == null:
			continue
		match button.text:
			"◀ Rod":
				button.text = "◀R"
				button.visible = true
				button.custom_minimum_size.x = 58.0
			"Rod ▶":
				button.text = "R▶"
				button.visible = true
				button.custom_minimum_size.x = 58.0
			"◀ Conn":
				button.text = "◀C"
				button.visible = true
				button.custom_minimum_size.x = 58.0
			"Conn ▶":
				button.text = "C▶"
				button.visible = true
				button.custom_minimum_size.x = 58.0
	if parts_button_v050 != null:
		parts_button_v050.custom_minimum_size.x = 92.0
	rod_label.custom_minimum_size.x = 150.0
	connector_label.custom_minimum_size.x = 180.0


# -----------------------------------------------------------------------------
# Options accessibility. Saves and Physics are promoted to top-level buttons;
# the old appended sliders no longer disappear below a non-scrollable panel.
# -----------------------------------------------------------------------------

func _add_options_sections_v050() -> void:
	if options_panel == null:
		return
	var box: VBoxContainer = _find_first_vbox_v050(options_panel)
	if box == null:
		return
	builds_button_v050 = _ui_button("Saves & Recovery", func() -> void: _show_builds_panel_v050(false), true)
	physics_button_v051 = _ui_button("Physics Settings", _show_physics_panel_v051, true)
	box.add_child(builds_button_v050)
	box.add_child(physics_button_v051)
	# Put these immediately below the title/note instead of after updater content.
	box.move_child(builds_button_v050, mini(2, box.get_child_count() - 1))
	box.move_child(physics_button_v051, mini(3, box.get_child_count() - 1))


func _build_physics_panel_v051() -> void:
	if physics_panel_v051 != null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	physics_panel_v051 = PanelContainer.new()
	physics_panel_v051.anchor_left = 0.27
	physics_panel_v051.anchor_right = 0.73
	physics_panel_v051.anchor_top = 0.10
	physics_panel_v051.anchor_bottom = 0.88
	physics_panel_v051.add_theme_stylebox_override("panel", _panel_style(0.995, 16, 0.60))
	physics_panel_v051.visible = false
	layer.add_child(physics_panel_v051)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	physics_panel_v051.add_child(margin)
	physics_box_v051 = VBoxContainer.new()
	physics_box_v051.add_theme_constant_override("separation", 8)
	margin.add_child(physics_box_v051)
	var title: Label = Label.new()
	title.text = "PHYSICS SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	physics_box_v051.add_child(title)
	physics_gravity_label_v050 = _physics_slider_row_v050(physics_box_v051, "Gravity", 0.0, 24.0, 0.25, physics_gravity_v050, _on_gravity_v050)
	physics_friction_label_v050 = _physics_slider_row_v050(physics_box_v051, "Surface friction", 0.0, 1.0, 0.02, physics_friction_v050, _on_friction_v050)
	physics_bounce_label_v050 = _physics_slider_row_v050(physics_box_v051, "Bounce", 0.0, 0.60, 0.01, physics_bounce_v050, _on_bounce_v050)
	physics_linear_label_v050 = _physics_slider_row_v050(physics_box_v051, "Linear damping", 0.0, 2.0, 0.02, physics_linear_damp_v050, _on_linear_damp_v050)
	physics_angular_label_v050 = _physics_slider_row_v050(physics_box_v051, "Angular damping", 0.0, 2.0, 0.02, physics_angular_damp_v050, _on_angular_damp_v050)
	physics_box_v051.add_child(_ui_button("Reset Physics Defaults", _reset_physics_v050))
	physics_box_v051.add_child(_ui_button("Close", _hide_physics_panel_v051, true))
	_refresh_physics_labels_v050()


func _show_physics_panel_v051() -> void:
	if physics_panel_v051 == null:
		_build_physics_panel_v051()
	physics_panel_v051.visible = true
	if options_panel != null:
		options_panel.visible = false
	if builds_panel_v050 != null:
		builds_panel_v050.visible = false
	if parts_panel_v050 != null:
		parts_panel_v050.visible = false


func _hide_physics_panel_v051() -> void:
	if physics_panel_v051 != null:
		physics_panel_v051.visible = false


# -----------------------------------------------------------------------------
# ITEM vs WORLD transforms.
# ITEM is default. Free pieces use their local XYZ. Connected pieces expose only
# physically meaningful cross/axle DOFs. WORLD deliberately transforms the full
# connected island as v0.5 did.
# -----------------------------------------------------------------------------

func _install_space_controls_v051() -> void:
	if rotation_body != null and rotate_space_button_v051 == null:
		rotate_space_button_v051 = _ui_button("Transform: ITEM", func() -> void: _toggle_transform_space_v051(), true)
		rotation_body.add_child(rotate_space_button_v051)
		rotation_body.move_child(rotate_space_button_v051, mini(1, rotation_body.get_child_count() - 1))
	if move_body != null and move_space_button_v051 == null:
		move_space_button_v051 = _ui_button("Transform: ITEM", func() -> void: _toggle_transform_space_v051(), true)
		move_body.add_child(move_space_button_v051)
		move_body.move_child(move_space_button_v051, 0)


func _toggle_transform_space_v051() -> void:
	transform_space_v051 = SPACE_WORLD_051 if transform_space_v051 == SPACE_ITEM_051 else SPACE_ITEM_051
	move_drag_active_v042 = false
	gizmo_drag_active_v030 = false
	_clear_rotation_ghost_v030()
	_update_transform_ui_v051()
	_update_ui()
	_status("Transform space: %s" % ("ITEM — only valid piece/connection motion is exposed" if transform_space_v051 == SPACE_ITEM_051 else "WORLD — the connected construction moves as a group"))


func _mobility_v051() -> Dictionary:
	if not is_instance_valid(selected_piece):
		return {"kind": "none"}
	_rebuild_connection_graph_v020()
	var records: Array = _connections_for_piece_v020(selected_piece)
	if records.is_empty():
		return {"kind": "free", "axis": Vector3.ZERO, "record": {}}
	var selected_kind: String = str(selected_piece.get_meta("kind", ""))
	var matches: Array = []
	for record_value in records:
		var record: Dictionary = record_value as Dictionary
		var kind: String = str(record.get("kind", ""))
		if kind == "cross" and selected_kind == "connector" and record.get("connector") == selected_piece:
			matches.append(record)
		elif kind == "axle" and (record.get("connector") == selected_piece or record.get("rod") == selected_piece):
			matches.append(record)
		elif kind == "o_ring" and selected_kind == "o_ring" and record.get("ring") == selected_piece:
			matches.append(record)
	if matches.size() != 1:
		return {"kind": "fixed", "axis": Vector3.ZERO, "record": {}}
	var record: Dictionary = matches[0] as Dictionary
	var rod: RigidBody3D = record.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return {"kind": "fixed", "axis": Vector3.ZERO, "record": {}}
	return {"kind": str(record.get("kind", "")), "axis": _rod_axis_v020(rod).normalized(), "record": record}


func _item_basis_for_axis_v051(axis_value: Vector3) -> Basis:
	var y_axis: Vector3 = axis_value.normalized()
	var x_axis: Vector3 = _world_perpendicular_v035(y_axis)
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _local_axis_v051(name_value: String) -> Vector3:
	if not is_instance_valid(selected_piece):
		return Vector3.ZERO
	var local: Vector3 = Vector3.RIGHT if name_value == "X" else (Vector3.UP if name_value == "Y" else Vector3.BACK)
	return (selected_piece.global_transform.basis.orthonormalized() * local).normalized()


func _item_component_v051(mobility: Dictionary) -> Array:
	if not is_instance_valid(selected_piece):
		return []
	var kind: String = str(mobility.get("kind", "none"))
	if kind == "free":
		return [selected_piece]
	if kind in ["cross", "axle", "o_ring"]:
		var record: Dictionary = mobility.get("record", {}) as Dictionary
		return _fixed_component_v020(selected_piece, int(record.get("uid", -1)))
	return []


func _rotate_map_v051(component: Array, pivot: Vector3, axis_value: Vector3, angle: float) -> Dictionary:
	var result: Dictionary = {}
	var rotation: Basis = Basis(axis_value.normalized(), angle)
	for body_value in component:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var old: Transform3D = body.global_transform
		var updated: Transform3D = old
		updated.origin = pivot + rotation * (old.origin - pivot)
		updated.basis = (rotation * old.basis).orthonormalized()
		result[body.get_instance_id()] = updated
	return result


func _rotation_candidate_v030(axis_value: Vector3, direction_sign: int) -> Dictionary:
	if transform_space_v051 == SPACE_WORLD_051:
		return super._rotation_candidate_v030(axis_value, direction_sign)
	if not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "no selected piece"}
	var mobility: Dictionary = _mobility_v051()
	var kind: String = str(mobility.get("kind", "none"))
	var component: Array = _item_component_v051(mobility)
	if component.is_empty():
		return {"valid": false, "reason": "this connection is rigid; use WORLD to rotate the construction"}
	var requested_axis: Vector3 = axis_value.normalized()
	var pivot: Vector3 = selected_piece.global_position
	var excluded_uid: int = -1
	if kind in ["cross", "axle"]:
		var allowed_axis: Vector3 = mobility.get("axis", Vector3.ZERO) as Vector3
		if absf(requested_axis.dot(allowed_axis)) < 0.985:
			return {"valid": false, "reason": "%s connection only rotates around the host rod" % kind.to_upper()}
		requested_axis = allowed_axis if requested_axis.dot(allowed_axis) >= 0.0 else -allowed_axis
		var record: Dictionary = mobility.get("record", {}) as Dictionary
		excluded_uid = int(record.get("uid", -1))
		var rod: RigidBody3D = record.get("rod") as RigidBody3D
		if kind == "cross" and is_instance_valid(rod):
			pivot = rod.global_position + _rod_axis_v020(rod) * float(record.get("host_along", 0.0))
		elif kind == "axle":
			var connector: RigidBody3D = record.get("connector") as RigidBody3D
			if is_instance_valid(connector):
				pivot = connector.global_position
	elif kind != "free":
		return {"valid": false, "reason": "this item has no free rotational DOF; use WORLD for the full construction"}
	var transforms: Dictionary = _rotate_map_v051(component, pivot, requested_axis, GIZMO_STEP_030 * float(direction_sign))
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "another connection blocks this rotation"))}
	return {"valid": true, "transforms": transforms, "axis": requested_axis, "kind": kind}


func _roll_candidate_v030(direction_sign: int) -> Dictionary:
	var mobility: Dictionary = _mobility_v051()
	if str(mobility.get("kind", "")) in ["cross", "axle"]:
		return _rotation_candidate_v030(mobility.get("axis", Vector3.ZERO) as Vector3, direction_sign)
	return super._roll_candidate_v030(direction_sign)


func _apply_roll_v030(direction_sign: int) -> void:
	var mobility: Dictionary = _mobility_v051()
	if str(mobility.get("kind", "")) in ["cross", "axle"]:
		var preview: Dictionary = _roll_candidate_v030(direction_sign)
		if not bool(preview.get("valid", false)):
			_status("Item roll blocked — %s" % str(preview.get("reason", "constraint")))
			return
		_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated ITEM around host rod by %d°" % (direction_sign * 45))
		return
	super._apply_roll_v030(direction_sign)


func _apply_world_rotation_step_v042(axis_name: String, direction_sign: int) -> void:
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not is_instance_valid(selected_piece):
		return
	var axis: Vector3 = _world_axis_v035(axis_name) if transform_space_v051 == SPACE_WORLD_051 else _local_axis_v051(axis_name)
	var mobility: Dictionary = _mobility_v051()
	if transform_space_v051 == SPACE_ITEM_051 and str(mobility.get("kind", "")) in ["cross", "axle"]:
		axis = mobility.get("axis", axis) as Vector3
		if axis_name != "Y":
			_status("ITEM %s — only the host-rod rotation ring is valid" % str(mobility.get("kind", "")).to_upper())
			return
	var preview: Dictionary = _rotation_candidate_v030(axis, direction_sign)
	if not bool(preview.get("valid", false)):
		_status("%s rotation blocked — %s" % ["WORLD" if transform_space_v051 == SPACE_WORLD_051 else "ITEM", str(preview.get("reason", "constraint"))])
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated %s %s by %d°" % ["WORLD" if transform_space_v051 == SPACE_WORLD_051 else "ITEM", axis_name, direction_sign * 45])


func _clamp_slide_delta_v051(mobility: Dictionary, delta: float) -> float:
	var record: Dictionary = mobility.get("record", {}) as Dictionary
	var rod: RigidBody3D = record.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return 0.0
	var half_len: float = maxf(0.15, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.48)
	var kind: String = str(mobility.get("kind", ""))
	if kind == "cross" or kind == "o_ring":
		var current: float = float(record.get("host_along", 0.0))
		return clampf(current + delta, -half_len, half_len) - current
	if kind == "axle":
		var connector: RigidBody3D = record.get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			return 0.0
		var axis: Vector3 = mobility.get("axis", Vector3.UP) as Vector3
		var current_along: float = (connector.global_position - rod.global_position).dot(axis)
		if selected_piece == rod:
			return current_along - clampf(current_along - delta, -half_len, half_len)
		return clampf(current_along + delta, -half_len, half_len) - current_along
	return delta


func _apply_item_move_v051(axis_value: Vector3, requested_delta: float, label_value: String) -> void:
	var mobility: Dictionary = _mobility_v051()
	var kind: String = str(mobility.get("kind", "none"))
	var component: Array = _item_component_v051(mobility)
	if component.is_empty():
		_status("ITEM move blocked — this connection is rigid; use WORLD to move the construction")
		return
	var axis: Vector3 = axis_value.normalized()
	var excluded_uid: int = -1
	var delta_value: float = requested_delta
	if kind in ["cross", "axle", "o_ring"]:
		var allowed_axis: Vector3 = mobility.get("axis", Vector3.ZERO) as Vector3
		if absf(axis.dot(allowed_axis)) < 0.985:
			_status("ITEM %s can only slide along the host rod" % kind.to_upper())
			return
		axis = allowed_axis if axis.dot(allowed_axis) >= 0.0 else -allowed_axis
		delta_value = _clamp_slide_delta_v051(mobility, requested_delta * (1.0 if axis.dot(allowed_axis) >= 0.0 else -1.0))
		excluded_uid = int((mobility.get("record", {}) as Dictionary).get("uid", -1))
	if absf(delta_value) < 0.0001:
		_status("ITEM slide is already at the end of the rod")
		return
	var delta: Vector3 = axis * delta_value
	var transforms: Dictionary = _translation_map_v042(component, delta)
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		_status("ITEM move blocked — %s" % str(validation.get("reason", "another connection prevents the move")))
		return
	_apply_transforms_raw_v030(transforms)
	if kind in ["cross", "o_ring"]:
		var record: Dictionary = mobility.get("record", {}) as Dictionary
		var joint: Joint3D = record.get("joint") as Joint3D
		var new_along: float = float(record.get("host_along", 0.0)) + delta.dot(mobility.get("axis", Vector3.UP) as Vector3)
		if is_instance_valid(joint):
			joint.set_meta("host_along_v020", new_along)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	_status(label_value)


func _apply_world_move_step_v042(axis: Vector3, steps: int) -> void:
	if transform_space_v051 == SPACE_WORLD_051:
		super._apply_world_move_step_v042(axis, steps)
		return
	if simulating or editor_mode_v032 != EDITOR_MOVE_042 or not is_instance_valid(selected_piece):
		return
	var mobility: Dictionary = _mobility_v051()
	var kind: String = str(mobility.get("kind", "none"))
	var axis_value: Vector3 = axis.normalized()
	if kind == "free":
		var name_value: String = _axis_name_v042(axis)
		axis_value = _local_axis_v051(name_value)
	elif kind in ["cross", "axle", "o_ring"]:
		if absf(axis.dot(Vector3.UP)) < 0.99:
			_status("ITEM %s — only the host-axis move arrows are valid" % kind.to_upper())
			return
		axis_value = mobility.get("axis", Vector3.UP) as Vector3
	_apply_item_move_v051(axis_value, MOVE_STEP_042 * float(steps), "Moved ITEM by %.2f" % (MOVE_STEP_042 * float(steps)))


func _pick_move_axis_v042(screen_pos: Vector2) -> Dictionary:
	if move_gizmo_root_v042 == null or not move_gizmo_root_v042.visible or camera == null or not is_instance_valid(selected_piece):
		return {}
	var center: Vector3 = selected_piece.global_position
	var scale_value: float = move_gizmo_root_v042.scale.x
	var best: Dictionary = {}
	var best_distance: float = MOVE_GIZMO_PICK_PX_042
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = move_gizmo_axes_v042.get(name_value, {}) as Dictionary
		var root: Node3D = data.get("root") as Node3D
		if data.is_empty() or not is_instance_valid(root) or not root.visible:
			continue
		var axis: Vector3 = data.get("axis", Vector3.ZERO) as Vector3
		var positive: Vector3 = center + axis * MOVE_GIZMO_LENGTH_042 * scale_value
		var negative: Vector3 = center - axis * MOVE_GIZMO_LENGTH_042 * scale_value
		if camera.is_position_behind(positive) or camera.is_position_behind(negative):
			continue
		var screen_positive: Vector2 = camera.unproject_position(positive)
		var screen_negative: Vector2 = camera.unproject_position(negative)
		var screen_axis: Vector2 = screen_positive - screen_negative
		if screen_axis.length() < 28.0:
			continue
		var pick: Dictionary = _point_segment_pick_v035(screen_pos, screen_negative, screen_positive)
		var distance: float = float(pick.get("distance", 9999.0))
		if distance <= best_distance:
			best_distance = distance
			best = {"name": name_value, "axis": axis, "screen_dir": screen_axis.normalized()}
	return best


func _begin_move_drag_v042(screen_pos: Vector2) -> bool:
	if transform_space_v051 == SPACE_WORLD_051:
		return super._begin_move_drag_v042(screen_pos)
	if editor_mode_v032 != EDITOR_MOVE_042 or simulating or not is_instance_valid(selected_piece):
		return false
	var picked: Dictionary = _pick_move_axis_v042(screen_pos)
	if picked.is_empty():
		return false
	var mobility: Dictionary = _mobility_v051()
	var component: Array = _item_component_v051(mobility)
	if component.is_empty():
		return false
	move_drag_active_v042 = true
	move_drag_axis_name_v042 = str(picked.get("name", ""))
	move_drag_axis_v042 = picked.get("axis", Vector3.ZERO) as Vector3
	move_drag_screen_dir_v042 = picked.get("screen_dir", Vector2.RIGHT) as Vector2
	move_drag_start_screen_v042 = screen_pos
	move_drag_steps_v042 = 0
	move_drag_component_v042 = component
	move_drag_preview_v042 = {"valid": true, "transforms": {}}
	_build_rotation_ghost_v030(component)
	_status("ITEM move — drag the valid arrow; %.2f-unit snap" % MOVE_STEP_042)
	return true


func _finish_move_drag_v042() -> void:
	if transform_space_v051 == SPACE_WORLD_051:
		super._finish_move_drag_v042()
		return
	if not move_drag_active_v042:
		return
	var steps: int = move_drag_steps_v042
	var axis: Vector3 = move_drag_axis_v042
	move_drag_active_v042 = false
	move_drag_steps_v042 = 0
	move_drag_component_v042 = []
	move_drag_preview_v042 = {}
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Move unchanged")
		return
	_apply_item_move_v051(axis, MOVE_STEP_042 * float(steps), "Moved ITEM by %.2f" % (MOVE_STEP_042 * float(steps)))


func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var best: Dictionary = {}
	var best_distance: float = WORLD_GIZMO_PICK_PX_035
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = gizmo_axes_v030.get(name_value, {}) as Dictionary
		var ring: MeshInstance3D = data.get("ring") as MeshInstance3D
		if not is_instance_valid(ring) or not ring.visible:
			continue
		var pick: Dictionary = _ring_pick_v035(data.get("axis", Vector3.ZERO) as Vector3, screen_pos, best_distance)
		if not pick.is_empty() and float(pick.get("distance", 9999.0)) <= best_distance:
			best_distance = float(pick.get("distance", 9999.0))
			best = {"name": name_value, "axis": data.get("axis", Vector3.ZERO), "tangent": pick.get("tangent", Vector2.RIGHT)}
	return best


func _layout_right_panels_v032() -> void:
	if rotation_panel == null or move_panel == null:
		return
	rotation_panel.anchor_left = 1.0
	rotation_panel.anchor_right = 1.0
	move_panel.anchor_left = 1.0
	move_panel.anchor_right = 1.0
	rotation_panel.offset_left = -236.0
	rotation_panel.offset_right = -8.0
	move_panel.offset_left = -236.0
	move_panel.offset_right = -8.0
	var top_value: float = 112.0
	var collapsed: float = 48.0
	var gap: float = 6.0
	var bottom_limit: float = maxf(top_value + 260.0, get_viewport().get_visible_rect().size.y - 108.0)
	if right_panel_state_v037 == "rotate":
		var rotate_bottom: float = bottom_limit - collapsed - gap
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = rotate_bottom
		move_panel.offset_top = rotate_bottom + gap
		move_panel.offset_bottom = rotate_bottom + gap + collapsed
	elif right_panel_state_v037 == "move":
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = bottom_limit
	else:
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = top_value + collapsed * 2.0 + gap
	rotation_panel.clip_contents = true
	move_panel.clip_contents = true


func _update_transform_ui_v051() -> void:
	var label: String = "Transform: %s" % ("ITEM" if transform_space_v051 == SPACE_ITEM_051 else "WORLD")
	if rotate_space_button_v051 != null:
		rotate_space_button_v051.text = label
	if move_space_button_v051 != null:
		move_space_button_v051.text = label
	var mobility: Dictionary = _mobility_v051()
	var kind: String = str(mobility.get("kind", "none"))
	if rotation_hint_v035 != null:
		if transform_space_v051 == SPACE_WORLD_051:
			rotation_hint_v035.text = "WORLD transforms the entire connected construction. Switch to ITEM for physical connection-aware motion."
		elif kind == "free":
			rotation_hint_v035.text = "ITEM axes follow this piece. Free pieces expose local X/Y/Z."
		elif kind in ["cross", "axle"]:
			rotation_hint_v035.text = "ITEM %s: only rotation around the host rod is valid." % kind.to_upper()
		else:
			rotation_hint_v035.text = "ITEM is rigid at this connection. Use WORLD only when you intentionally want to rotate the full construction."


func _update_ui() -> void:
	super._update_ui()
	_update_transform_ui_v051()
	var item_mode: bool = transform_space_v051 == SPACE_ITEM_051
	var mobility: Dictionary = _mobility_v051() if is_instance_valid(selected_piece) else {"kind": "none"}
	var kind: String = str(mobility.get("kind", "none"))
	# Existing six fallback buttons become LOCAL X/Y/Z in ITEM mode. For cross/
	# axle only Y represents the host axis and the other directions disappear.
	var rotation_buttons: Array = [rot_x_minus_v042, rot_x_plus_v042, rot_y_minus_v042, rot_y_plus_v042, rot_z_minus_v042, rot_z_plus_v042]
	var move_buttons: Array = [move_x_minus_v042, move_x_plus_v042, move_y_minus_v042, move_y_plus_v042, move_z_minus_v042, move_z_plus_v042]
	for i in range(rotation_buttons.size()):
		var rb: Button = rotation_buttons[i] as Button
		var mb: Button = move_buttons[i] as Button
		var axis_index: int = i / 2
		var visible_axis: bool = not item_mode or kind == "free" or (kind in ["cross", "axle", "o_ring"] and axis_index == 1)
		if rb != null:
			rb.visible = visible_axis
		if mb != null:
			mb.visible = visible_axis
	if roll_minus_v035 != null and item_mode and kind in ["cross", "axle"]:
		roll_minus_v035.disabled = not bool(_roll_candidate_v030(-1).get("valid", false))
	if roll_plus_v035 != null and item_mode and kind in ["cross", "axle"]:
		roll_plus_v035.disabled = not bool(_roll_candidate_v030(1).get("valid", false))


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(selected_piece):
		return
	var mobility: Dictionary = _mobility_v051()
	var kind: String = str(mobility.get("kind", "none"))
	var constrained: bool = transform_space_v051 == SPACE_ITEM_051 and kind in ["cross", "axle", "o_ring"]
	var free_item: bool = transform_space_v051 == SPACE_ITEM_051 and kind == "free"
	var basis_value: Basis = Basis.IDENTITY
	if free_item:
		basis_value = selected_piece.global_transform.basis.orthonormalized()
	elif constrained:
		basis_value = _item_basis_for_axis_v051(mobility.get("axis", Vector3.UP) as Vector3)
	# Rotation gizmo: parent basis controls rendered ring orientation; dictionary
	# axes are updated so picking/validation uses the exact same world directions.
	if gizmo_root_v030 != null and gizmo_root_v030.visible:
		gizmo_root_v030.global_basis = basis_value if transform_space_v051 == SPACE_ITEM_051 else Basis.IDENTITY
		for name_value in ["X", "Y", "Z"]:
			var data: Dictionary = gizmo_axes_v030.get(name_value, {}) as Dictionary
			if data.is_empty():
				continue
			var local_axis: Vector3 = Vector3.RIGHT if name_value == "X" else (Vector3.UP if name_value == "Y" else Vector3.BACK)
			data["axis"] = ((basis_value * local_axis).normalized() if transform_space_v051 == SPACE_ITEM_051 else local_axis)
			var ring: MeshInstance3D = data.get("ring") as MeshInstance3D
			var plus: Label3D = data.get("plus") as Label3D
			var minus: Label3D = data.get("minus") as Label3D
			var show_axis: bool = not constrained or name_value == "Y"
			if is_instance_valid(ring): ring.visible = show_axis
			if is_instance_valid(plus): plus.visible = show_axis
			if is_instance_valid(minus): minus.visible = show_axis
	# Move gizmo follows the same basis and hides impossible directions.
	if move_gizmo_root_v042 != null and move_gizmo_root_v042.visible:
		move_gizmo_root_v042.global_basis = basis_value if transform_space_v051 == SPACE_ITEM_051 else Basis.IDENTITY
		for name_value in ["X", "Y", "Z"]:
			var data: Dictionary = move_gizmo_axes_v042.get(name_value, {}) as Dictionary
			if data.is_empty():
				continue
			var local_axis: Vector3 = Vector3.RIGHT if name_value == "X" else (Vector3.UP if name_value == "Y" else Vector3.BACK)
			data["axis"] = ((basis_value * local_axis).normalized() if transform_space_v051 == SPACE_ITEM_051 else local_axis)
			var root: Node3D = data.get("root") as Node3D
			if is_instance_valid(root):
				root.visible = not constrained or name_value == "Y"


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nTRANSFORMS: ITEM is the default. Free pieces use their own local X/Y/Z. A CROSS connector only slides along and rotates around its host rod. An AXLE rod/connector only slides along and rotates around the axle. Rigid socket-connected items expose no fake item DOF. WORLD is explicit and transforms the connected construction as a group.\n\nATTACH: the cursor tether is removed. CROSS points use bold + markers. An occupied SOCKET can be selected and moved directly to another free fork on the same connector.\n\nPARTS: fast previous/next arrows are restored alongside the full Parts browser.\n\nOPTIONS: Saves & Recovery and Physics Settings are promoted to visible top-level buttons.\n\nCamera: one finger orbit; two fingers pan/zoom." % VERSION_051
