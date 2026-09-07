extends "res://scripts/main_v031.gd"

const VERSION_032 := "0.3.2"
const EDITOR_CREATE_032 := 0
const EDITOR_ROTATE_032 := 1
const EDITOR_ATTACH_032 := 2
const POINT_PICK_RADIUS_032 := 56.0

var editor_mode_v032: int = EDITOR_CREATE_032
var mode_panel_v032: PanelContainer
var create_button_v032: Button
var rotate_button_v032: Button
var attach_button_v032: Button
var delete_button_v032: Button
var deselect_point_button_v032: Button
var mode_hint_v032: Label

var attach_points_root_v032: Node3D
var attach_point_selected_v032: Dictionary = {}
var point_rod_mat_v032: StandardMaterial3D
var point_socket_mat_v032: StandardMaterial3D
var point_body_mat_v032: StandardMaterial3D
var point_hub_mat_v032: StandardMaterial3D
var point_occupied_mat_v032: StandardMaterial3D
var point_selected_mat_v032: StandardMaterial3D


func _ready() -> void:
	super._ready()
	_build_attach_point_overlay_v032()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_032)
	_set_editor_mode_v032(EDITOR_CREATE_032, false)
	_status("CREATE mode — build normally. Use the large left buttons to switch to ROTATE or ATTACH.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_032, text]


# -----------------------------------------------------------------------------
# UI: three large editor modes on the left; Move + Rotate become a right-side
# accordion and start collapsed. The v0.3 topology button stack is retired.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()

	for old_button in [reseat_button_v030, detach_button_v030, attach_button_v030, cancel_tool_button_v030]:
		if old_button != null:
			old_button.visible = false
	if topology_label_v030 != null:
		topology_label_v030.visible = false
	if delete_button != null:
		delete_button.visible = false

	var mode_layer := CanvasLayer.new()
	mode_layer.layer = 3
	add_child(mode_layer)
	mode_panel_v032 = PanelContainer.new()
	mode_panel_v032.offset_left = 8.0
	mode_panel_v032.offset_right = 226.0
	mode_panel_v032.offset_top = 76.0
	mode_panel_v032.offset_bottom = 430.0
	mode_panel_v032.add_theme_stylebox_override("panel", _panel_style(0.97, 12))
	mode_layer.add_child(mode_panel_v032)

	var mode_box := VBoxContainer.new()
	mode_box.add_theme_constant_override("separation", 8)
	mode_panel_v032.add_child(mode_box)
	mode_box.add_child(_section_label("EDITOR MODE"))

	create_button_v032 = _ui_button("CREATE", func() -> void: _set_editor_mode_v032(EDITOR_CREATE_032), true)
	rotate_button_v032 = _ui_button("ROTATE", func() -> void: _set_editor_mode_v032(EDITOR_ROTATE_032), true)
	attach_button_v032 = _ui_button("ATTACH", func() -> void: _set_editor_mode_v032(EDITOR_ATTACH_032), true)
	for button_value in [create_button_v032, rotate_button_v032, attach_button_v032]:
		var button: Button = button_value as Button
		button.custom_minimum_size = Vector2(194.0, 58.0)
		button.add_theme_font_size_override("font_size", 18)
		mode_box.add_child(button)

	var separator := HSeparator.new()
	mode_box.add_child(separator)
	delete_button_v032 = _ui_button("Delete Selected", _delete_selected, true)
	delete_button_v032.custom_minimum_size.y = 52.0
	mode_box.add_child(delete_button_v032)
	deselect_point_button_v032 = _ui_button("Deselect Point", _deselect_attach_point_v032, true)
	deselect_point_button_v032.custom_minimum_size.y = 48.0
	mode_box.add_child(deselect_point_button_v032)

	mode_hint_v032 = Label.new()
	mode_hint_v032.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_hint_v032.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_hint_v032.add_theme_font_size_override("font_size", 11)
	mode_hint_v032.add_theme_color_override("font_color", Color(0.64, 0.74, 0.84))
	mode_box.add_child(mode_hint_v032)

	# Both inherited utility panels now live on the right and begin collapsed.
	if rotation_body != null:
		rotation_body.visible = false
	if move_body != null:
		move_body.visible = false
	if rotation_collapse_button != null:
		rotation_collapse_button.text = "ROTATE ▸"
	if move_collapse_button != null:
		move_collapse_button.text = "MOVE ▸"
	_layout_right_panels_v032()
	_update_mode_ui_v032()


func _layout_right_panels_v032() -> void:
	if rotation_panel == null or move_panel == null:
		return
	rotation_panel.anchor_left = 1.0
	rotation_panel.anchor_right = 1.0
	move_panel.anchor_left = 1.0
	move_panel.anchor_right = 1.0
	rotation_panel.offset_left = -246.0
	rotation_panel.offset_right = -8.0
	move_panel.offset_left = -246.0
	move_panel.offset_right = -8.0

	var rotate_open: bool = rotation_body != null and rotation_body.visible
	var move_open: bool = move_body != null and move_body.visible
	if rotate_open:
		rotation_panel.offset_top = 76.0
		rotation_panel.offset_bottom = 500.0
		move_panel.offset_top = 506.0
		move_panel.offset_bottom = 558.0
	elif move_open:
		rotation_panel.offset_top = 76.0
		rotation_panel.offset_bottom = 128.0
		move_panel.offset_top = 134.0
		move_panel.offset_bottom = 540.0
	else:
		rotation_panel.offset_top = 76.0
		rotation_panel.offset_bottom = 128.0
		move_panel.offset_top = 134.0
		move_panel.offset_bottom = 186.0


func _toggle_rotation_panel() -> void:
	if rotation_body == null:
		return
	var opening: bool = not rotation_body.visible
	rotation_body.visible = opening
	if opening and move_body != null:
		move_body.visible = false
	if rotation_collapse_button != null:
		rotation_collapse_button.text = "ROTATE ▾" if opening else "ROTATE ▸"
	if move_collapse_button != null:
		move_collapse_button.text = "MOVE ▸"
	_layout_right_panels_v032()


func _toggle_move_panel() -> void:
	if move_body == null:
		return
	var opening: bool = not move_body.visible
	move_body.visible = opening
	if opening and rotation_body != null:
		rotation_body.visible = false
	if move_collapse_button != null:
		move_collapse_button.text = "MOVE ▾" if opening else "MOVE ▸"
	if rotation_collapse_button != null:
		rotation_collapse_button.text = "ROTATE ▸"
	_layout_right_panels_v032()


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	if simulating:
		if report:
			_status("Return to BUILD before changing editor mode")
		return
	editor_mode_v032 = clampi(mode_value, EDITOR_CREATE_032, EDITOR_ATTACH_032)
	select_armed_v020 = false
	_cancel_editor_tools_v030(false)
	_deselect_attach_point_v032(false)
	_update_mode_ui_v032()
	_refresh_editor_overlay_v030()
	_refresh_attach_points_v032()
	if not report:
		return
	match editor_mode_v032:
		EDITOR_CREATE_032:
			_status("CREATE mode — normal taps place rods/connectors. Rotation and attachment handles are hidden.")
		EDITOR_ROTATE_032:
			_status("ROTATE mode — drag the fixed-world XYZ gizmo or use mount Roll. World taps do not create parts.")
		EDITOR_ATTACH_032:
			_status("ATTACH mode — tap one visible connection point, then a compatible point. The first-selected side moves.")


func _update_mode_ui_v032() -> void:
	var buttons: Array = [create_button_v032, rotate_button_v032, attach_button_v032]
	for i in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		var active: bool = i == editor_mode_v032
		button.text = ("● " if active else "") + ["CREATE", "ROTATE", "ATTACH"][i]
		button.self_modulate = Color(0.70, 0.94, 1.0) if active else Color.WHITE
	if delete_button_v032 != null:
		delete_button_v032.disabled = simulating or not is_instance_valid(selected_piece)
	if deselect_point_button_v032 != null:
		deselect_point_button_v032.visible = editor_mode_v032 == EDITOR_ATTACH_032
		deselect_point_button_v032.disabled = attach_point_selected_v032.is_empty()
	if mode_hint_v032 != null:
		match editor_mode_v032:
			EDITOR_CREATE_032:
				mode_hint_v032.text = "Build pieces normally"
			EDITOR_ROTATE_032:
				mode_hint_v032.text = "XYZ gizmo + mount Roll"
			EDITOR_ATTACH_032:
				mode_hint_v032.text = "Tap point → tap compatible point"


func _update_ui() -> void:
	super._update_ui()
	_update_mode_ui_v032()
	var rotate_mode: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating
	if roll_minus_v030 != null:
		roll_minus_v030.disabled = roll_minus_v030.disabled or not rotate_mode
	if roll_plus_v030 != null:
		roll_plus_v030.disabled = roll_plus_v030.disabled or not rotate_mode
	if reset_rotation_v020 != null:
		reset_rotation_v020.disabled = reset_rotation_v020.disabled or not rotate_mode
	_refresh_attach_points_v032()


# -----------------------------------------------------------------------------
# Mode-aware world interaction.
# -----------------------------------------------------------------------------

func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_ROTATE_032:
		return false
	return super._begin_gizmo_drag_v030(screen_pos)


func _handle_tap(screen_pos: Vector2) -> void:
	if editor_mode_v032 == EDITOR_ATTACH_032:
		_handle_attach_point_tap_v032(screen_pos)
		return
	if editor_mode_v032 == EDITOR_ROTATE_032:
		if select_armed_v020:
			super._handle_tap(screen_pos)
		else:
			_status("ROTATE mode — drag the gizmo. Use Select first if you want a different piece.")
		return
	super._handle_tap(screen_pos)


func _process(delta: float) -> void:
	super._process(delta)
	if gizmo_root_v030 != null:
		gizmo_root_v030.visible = gizmo_root_v030.visible and editor_mode_v032 == EDITOR_ROTATE_032
	if attach_points_root_v032 != null:
		attach_points_root_v032.visible = editor_mode_v032 == EDITOR_ATTACH_032 and not simulating and not help_panel.visible and not options_panel.visible


# -----------------------------------------------------------------------------
# Simple click-click attachment-point editor.
# -----------------------------------------------------------------------------

func _build_attach_point_overlay_v032() -> void:
	point_rod_mat_v032 = _overlay_material_v030(Color(0.08, 0.82, 1.0))
	point_socket_mat_v032 = _overlay_material_v030(Color(0.18, 1.0, 0.46))
	point_body_mat_v032 = _overlay_material_v030(Color(0.22, 0.52, 1.0))
	point_hub_mat_v032 = _overlay_material_v030(Color(0.72, 0.36, 1.0))
	point_occupied_mat_v032 = _overlay_material_v030(Color(1.0, 0.48, 0.10))
	point_selected_mat_v032 = _overlay_material_v030(Color(1.0, 0.92, 0.08))
	attach_points_root_v032 = Node3D.new()
	attach_points_root_v032.name = "AttachmentPointsV032"
	add_child(attach_points_root_v032)
	_refresh_attach_points_v032()


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
			var axis: Vector3 = _rod_axis_v020(body)
			var half_len: float = maxf(0.10, float(body.get_meta("visual_length", 0.0)) * 0.5 - 0.42)
			for fraction in [-0.72, -0.36, 0.0, 0.36, 0.72]:
				var along: float = half_len * float(fraction)
				result.append({"type": "rod_body", "body": body, "along": along, "point": body.global_position + axis * along})
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


func _point_key_v032(point: Dictionary) -> String:
	if point.is_empty():
		return ""
	var body: RigidBody3D = point.get("body") as RigidBody3D
	if not is_instance_valid(body):
		return ""
	var uid: int = _ensure_piece_uid_v020(body)
	var type_value: String = str(point.get("type", ""))
	match type_value:
		"rod_end":
			return "%d:rod_end:%d" % [uid, int(point.get("sign", 0))]
		"socket":
			return "%d:socket:%d" % [uid, int(point.get("slot", -1))]
		"connector_hub":
			return "%d:hub" % uid
		"o_ring":
			return "%d:ring" % uid
		"rod_body":
			return "%d:body:%d" % [uid, int(round(float(point.get("along", 0.0)) * 1000.0))]
	return "%d:%s" % [uid, type_value]


func _connection_record_for_point_v032(point: Dictionary) -> Dictionary:
	if point.is_empty():
		return {}
	var body: RigidBody3D = point.get("body") as RigidBody3D
	if not is_instance_valid(body):
		return {}
	var type_value: String = str(point.get("type", ""))
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var kind: String = str(record.get("kind", ""))
		match type_value:
			"rod_end":
				if kind == "socket" and record.get("rod") == body and int(record.get("rod_end", 0)) == int(point.get("sign", 0)):
					return record
			"socket":
				if kind in ["socket", "cross"] and record.get("connector") == body and int(record.get("slot", -1)) == int(point.get("slot", -2)):
					return record
			"connector_hub":
				if kind == "axle" and record.get("connector") == body:
					return record
			"o_ring":
				if kind == "o_ring" and record.get("ring") == body:
					return record
	return {}


func _point_material_v032(point: Dictionary, selected: bool) -> StandardMaterial3D:
	if selected:
		return point_selected_mat_v032
	if not _connection_record_for_point_v032(point).is_empty():
		return point_occupied_mat_v032
	match str(point.get("type", "")):
		"rod_end":
			return point_rod_mat_v032
		"socket":
			return point_socket_mat_v032
		"connector_hub", "o_ring":
			return point_hub_mat_v032
		_:
			return point_body_mat_v032


func _point_display_v032(point: Dictionary) -> String:
	var body: RigidBody3D = point.get("body") as RigidBody3D
	var type_value: String = str(point.get("type", ""))
	var name_value: String = "Point"
	match type_value:
		"rod_end":
			name_value = "Rod end %s" % ("+" if int(point.get("sign", 0)) > 0 else "−")
		"rod_body":
			name_value = "Rod body"
		"socket":
			name_value = "Connector socket %d°" % int(point.get("slot", -1))
		"connector_hub":
			name_value = "Connector axle hub"
		"o_ring":
			name_value = "O-Ring"
	var state_value: String = "CONNECTED" if not _connection_record_for_point_v032(point).is_empty() else "FREE"
	return "%s • %s • %s" % [name_value, _piece_display_name(body) if is_instance_valid(body) else "piece", state_value]


func _refresh_attach_points_v032() -> void:
	if attach_points_root_v032 == null:
		return
	_clear_children_v030(attach_points_root_v032)
	if editor_mode_v032 != EDITOR_ATTACH_032 or simulating or help_panel.visible or options_panel.visible:
		return
	var current_key: String = _point_key_v032(attach_point_selected_v032)
	var matched_selection: bool = current_key.is_empty()
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		var key: String = _point_key_v032(point)
		var selected: bool = not current_key.is_empty() and key == current_key
		if selected:
			matched_selection = true
			attach_point_selected_v032 = point.duplicate(true)
		var marker_scale: float = 0.32 if selected else (0.18 if str(point.get("type", "")) != "rod_body" else 0.13)
		_make_handle_v030(attach_points_root_v032, point["point"] as Vector3, _point_material_v032(point, selected), marker_scale)
		if selected:
			var label := Label3D.new()
			label.text = _point_display_v032(point)
			label.font_size = 34
			label.modulate = Color(1.0, 0.94, 0.25)
			label.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
			label.outline_size = 7
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			attach_points_root_v032.add_child(label)
			label.global_position = (point["point"] as Vector3) + Vector3.UP * 0.52
	if not matched_selection:
		attach_point_selected_v032 = {}
	_update_mode_ui_v032()


func _deselect_attach_point_v032(report: bool = true) -> void:
	var had_selection: bool = not attach_point_selected_v032.is_empty()
	attach_point_selected_v032 = {}
	if attach_points_root_v032 != null:
		_refresh_attach_points_v032()
	if report and had_selection:
		_status("Attachment point deselected")


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	if simulating:
		return
	var candidates: Array = _all_attach_points_v032()
	var picked: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, POINT_PICK_RADIUS_032)
	if picked.is_empty():
		_status("ATTACH mode — tap one of the visible connection points")
		return
	var picked_key: String = _point_key_v032(picked)
	var selected_key: String = _point_key_v032(attach_point_selected_v032)
	if not selected_key.is_empty() and picked_key == selected_key:
		_deselect_attach_point_v032(false)
		_status("Attachment point deselected")
		return
	if attach_point_selected_v032.is_empty():
		attach_point_selected_v032 = picked.duplicate(true)
		_refresh_attach_points_v032()
		_status("Selected %s. Tap a compatible counterpart." % _point_display_v032(picked))
		return

	var first: Dictionary = attach_point_selected_v032
	var inferred_mode: int = _pair_mode_v032(first, picked)
	if inferred_mode < 0:
		attach_point_selected_v032 = picked.duplicate(true)
		_refresh_attach_points_v032()
		_status("Point selection moved to %s" % _point_display_v032(picked))
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
		_status("That target is already occupied; it is now the selected point to move/reconnect.")
		return

	if _connect_points_v032(first, picked, inferred_mode):
		attach_point_selected_v032 = {}
		_refresh_attach_points_v032()
	else:
		_refresh_attach_points_v032()


func _pair_mode_v032(a: Dictionary, b: Dictionary) -> int:
	var at: String = str(a.get("type", ""))
	var bt: String = str(b.get("type", ""))
	if (at == "rod_end" and bt == "socket") or (at == "socket" and bt == "rod_end"):
		return 0
	if (at == "connector_hub" and bt == "rod_body") or (at == "rod_body" and bt == "connector_hub"):
		return 1
	if (at == "socket" and bt == "rod_body") or (at == "rod_body" and bt == "socket"):
		return 2
	if at == "o_ring" and bt == "rod_body":
		return 1
	return -1


func _validate_transforms_excluding_v032(transforms: Dictionary, excluded_uid: int) -> Dictionary:
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		if int(record.get("uid", -1)) == excluded_uid:
			continue
		var result: Dictionary = _validate_record_v020(record, transforms)
		if not bool(result.get("valid", false)):
			return result
	return {"valid": true}


func _connect_points_v032(source: Dictionary, target: Dictionary, inferred_mode: int) -> bool:
	var source_body: RigidBody3D = source.get("body") as RigidBody3D
	var target_body: RigidBody3D = target.get("body") as RigidBody3D
	if not is_instance_valid(source_body) or not is_instance_valid(target_body) or source_body == target_body:
		_status("Connection blocked — source and target must be different pieces")
		return false

	_rebuild_connection_graph_v020()
	var old_record: Dictionary = _connection_record_for_point_v032(source)
	var excluded_uid: int = int(old_record.get("uid", -1)) if not old_record.is_empty() else -1
	var source_component: Array = _fixed_component_v020(source_body, excluded_uid)
	var same_component: bool = _component_has_piece_v020(source_component, target_body)
	var transforms: Dictionary = {}
	var previous_attach_mode: int = attach_mode
	attach_mode = inferred_mode

	if same_component:
		var current_check: Dictionary = _current_attach_geometry_v030(source, target)
		if not bool(current_check.get("valid", false)):
			attach_mode = previous_attach_mode
			_status("Connection blocked — both points belong to the same rigid assembly but do not already line up")
			return false
	else:
		var snap: Dictionary = _snap_source_component_v030(source, target, source_component)
		if not bool(snap.get("valid", false)):
			attach_mode = previous_attach_mode
			_status("Connection blocked — %s" % str(snap.get("reason", "the selected side cannot move to that target")))
			return false
		transforms = snap.get("transforms", {}) as Dictionary
		var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
		if not bool(validation.get("valid", false)):
			attach_mode = previous_attach_mode
			_status("Connection blocked — %s" % str(validation.get("reason", "moving the selected side would break another connection")))
			return false

	# Everything validates before topology changes. Reconnection therefore behaves
	# as one atomic operation: an invalid target leaves the old edge untouched.
	if not old_record.is_empty():
		_detach_record_raw_v032(old_record)
	_apply_transforms_raw_v030(transforms)
	_create_explicit_connection_v030(source, target)
	manual_detach_blocks_v030.erase(_pair_key_v030(source_body, target_body))
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	attach_mode = previous_attach_mode
	_refresh_selection_highlight()
	_update_ui()
	var mode_name: String = ["SOCKET", "AXLE", "CROSS"][inferred_mode]
	_status("%s connection %s" % [mode_name, "reconnected" if not old_record.is_empty() else "attached"])
	return true


func _detach_record_raw_v032(record: Dictionary) -> void:
	var a: RigidBody3D = record.get("a") as RigidBody3D
	var b: RigidBody3D = record.get("b") as RigidBody3D
	if is_instance_valid(a) and is_instance_valid(b):
		manual_detach_blocks_v030[_pair_key_v030(a, b)] = true
	var connector: RigidBody3D = record.get("connector") as RigidBody3D
	var ring: RigidBody3D = record.get("ring") as RigidBody3D
	var uid: int = int(record.get("uid", -1))
	var kind: String = str(record.get("kind", ""))
	if is_instance_valid(connector) and int(connector.get_meta("primary_connection_uid_v020", -1)) == uid:
		connector.set_meta("primary_connection_uid_v020", -1)
	if is_instance_valid(connector) and kind == "cross":
		connector.set_meta("cross_mount", false)
		connector.set_meta("cross_host_rod", null)
	if is_instance_valid(connector) and kind == "axle":
		connector.set_meta("axle_occupied", false)
		connector.set_meta("axle_host_rod", null)
	if is_instance_valid(ring) and kind == "o_ring":
		ring.set_meta("host_rod", null)
	var joint: Joint3D = record.get("joint") as Joint3D
	if is_instance_valid(joint):
		joints.erase(joint)
		joint.queue_free()
	_rebuild_connection_graph_v020()


# -----------------------------------------------------------------------------
# State integration: transient point selection never leaks through destructive
# edits, simulation or history restore.
# -----------------------------------------------------------------------------

func _set_selected(body: RigidBody3D) -> void:
	_deselect_attach_point_v032(false)
	super._set_selected(body)
	_refresh_attach_points_v032()


func _restore_state(snapshot: Dictionary) -> void:
	_deselect_attach_point_v032(false)
	super._restore_state(snapshot)
	_refresh_attach_points_v032()


func _restart_build() -> void:
	_deselect_attach_point_v032(false)
	super._restart_build()
	_set_editor_mode_v032(EDITOR_CREATE_032, false)


func _delete_selected() -> void:
	_deselect_attach_point_v032(false)
	super._delete_selected()
	_refresh_attach_points_v032()


func _toggle_simulation() -> void:
	_deselect_attach_point_v032(false)
	super._toggle_simulation()
	if simulating:
		_update_mode_ui_v032()
	else:
		_refresh_attach_points_v032()


func _change_connector_type(delta: int) -> void:
	_deselect_attach_point_v032(false)
	super._change_connector_type(delta)
	_refresh_attach_points_v032()


func _change_rod_type(delta: int) -> void:
	_deselect_attach_point_v032(false)
	super._change_rod_type(delta)
	_refresh_attach_points_v032()


# -----------------------------------------------------------------------------
# Help + updater version awareness.
# -----------------------------------------------------------------------------

func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCREATE: normal taps build rods/connectors using the bottom palette. No rotation gizmo or attachment handles are shown.\n\nROTATE: the selected piece keeps the fixed-world red X, green Y and blue Z 45° gizmo plus real-mount Roll. Camera angle never changes the physical axes. Use Select once if you need a different piece; ordinary world taps do not create anything in Rotate mode.\n\nATTACH: all rod ends, rod-body mount points, connector sockets, axle hubs and O-Rings are visible. Tap one point to select it (yellow). Tap it again or Deselect Point to clear it. Tap another incompatible point to move the point selection. Tap a compatible free counterpart to attach. If the first point is already connected, Connex validates the replacement first and only then swaps that one connection, as a single Undo action.\n\nPoint colors: cyan rod ends, blue rod-body points, green connector sockets, purple hubs/O-Rings, orange occupied, yellow selected. SOCKET/CROSS/AXLE topology is inferred from the two point types.\n\nLEFT: large Create / Rotate / Attach mode buttons and Delete Selected. RIGHT: Rotate and Move utility panels, collapsed by default.\n\nCamera: one finger orbits, two fingers pan/zoom. Options and updater settings persist between launches." % VERSION_032


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
	if _compare_versions_v021(latest, VERSION_032) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_032)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_032, latest])
