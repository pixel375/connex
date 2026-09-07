extends "res://scripts/main_v034.gd"

const VERSION_035 := "0.3.5"
const WORLD_GIZMO_PICK_PX_035 := 32.0
const WORLD_GIZMO_STEP_PIXELS_035 := 52.0
const WORLD_GIZMO_SAMPLES_035 := 72
const RIGHT_PANEL_TOP_035 := 112.0

var gizmo_drag_last_screen_v035: Vector2 = Vector2.ZERO
var gizmo_drag_accum_px_v035: float = 0.0
var gizmo_drag_tangent_v035: Vector2 = Vector2.RIGHT

var rotation_selected_v035: Label
var rotation_hint_v035: Label
var roll_minus_v035: Button
var roll_plus_v035: Button
var reset_rotation_v035: Button


func _ready() -> void:
	super._ready()
	if screen_gizmo_v034 != null:
		screen_gizmo_v034.visible = false
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_035)
	_refresh_attach_points_v032()
	_refresh_gizmo_validity_v030()
	_status("CREATE mode — placement orientation is world-defined. ROTATE uses the gizmo on the selected piece; ATTACH obeys the current SOCKET / AXLE / CROSS mode.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_035, text]


# -----------------------------------------------------------------------------
# Placement orientation: construction geometry may never depend on the camera.
# -----------------------------------------------------------------------------

func _world_perpendicular_v035(axis_value: Vector3) -> Vector3:
	var axis: Vector3 = axis_value.normalized()
	var result: Vector3 = Vector3.UP - axis * Vector3.UP.dot(axis)
	if result.length_squared() < 0.02:
		result = Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	if result.length_squared() < 0.02:
		result = Vector3.BACK - axis * Vector3.BACK.dot(axis)
	return result.normalized()


func _preferred_camera_perpendicular_v020(axis: Vector3) -> Vector3:
	# Kept under the inherited name because older placement code calls it, but the
	# result is now deliberately world-based and contains no camera reference.
	return _world_perpendicular_v035(axis)


func _basis_align_direction_v020(local_direction: Vector3, world_direction: Vector3, _ignored_preferred_up: Vector3) -> Basis:
	# Map a connector socket direction to the requested world direction while
	# choosing connector roll from fixed world axes. v0.2 passed camera-up here;
	# v0.3.5 intentionally ignores it.
	var local_radial: Vector3 = local_direction.normalized()
	var local_normal: Vector3 = Vector3.UP
	var local_tangent: Vector3 = local_radial.cross(local_normal).normalized()
	var world_radial: Vector3 = world_direction.normalized()
	var world_normal: Vector3 = _world_perpendicular_v035(world_radial)
	var world_tangent: Vector3 = world_radial.cross(world_normal).normalized()
	var local_frame: Basis = Basis(local_radial, local_normal, local_tangent)
	var world_frame: Basis = Basis(world_radial, world_normal, world_tangent)
	return (world_frame * local_frame.inverse()).orthonormalized()


func _basis_for_axle_v020(axis_value: Vector3) -> Basis:
	var world_y: Vector3 = axis_value.normalized()
	var world_x: Vector3 = _world_perpendicular_v035(world_y)
	var world_z: Vector3 = world_x.cross(world_y).normalized()
	return Basis(world_x, world_y, world_z).orthonormalized()


# -----------------------------------------------------------------------------
# Rotation UI: the manipulator belongs on the selected object, not in a menu.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	_rebuild_rotation_menu_v035()
	_layout_right_panels_v032()


func _rebuild_rotation_menu_v035() -> void:
	if rotation_body == null:
		return
	for child_value in rotation_body.get_children():
		var child: CanvasItem = child_value as CanvasItem
		if child != null:
			child.visible = false

	rotation_selected_v035 = _section_label("Selected: —")
	rotation_body.add_child(rotation_selected_v035)
	var world_label: Label = _section_label("WORLD XYZ • 45° SNAP")
	rotation_body.add_child(world_label)
	rotation_hint_v035 = Label.new()
	rotation_hint_v035.text = "Drag the colored X/Y/Z rings around the selected piece. The rings are world axes; the camera only changes what you see."
	rotation_hint_v035.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotation_hint_v035.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotation_hint_v035.add_theme_font_size_override("font_size", 11)
	rotation_hint_v035.add_theme_color_override("font_color", Color(0.65, 0.75, 0.84))
	rotation_body.add_child(rotation_hint_v035)
	rotation_body.add_child(_section_label("REAL MOUNT AXIS"))
	var roll_row: HBoxContainer = HBoxContainer.new()
	roll_row.add_theme_constant_override("separation", 4)
	rotation_body.add_child(roll_row)
	roll_minus_v035 = _ui_button("Roll −45°", func() -> void: _apply_roll_v030(-1))
	roll_plus_v035 = _ui_button("Roll +45°", func() -> void: _apply_roll_v030(1))
	roll_row.add_child(roll_minus_v035)
	roll_row.add_child(roll_plus_v035)
	reset_rotation_v035 = _ui_button("Reset Placement Rotation", _reset_rotation_v020, true)
	rotation_body.add_child(reset_rotation_v035)

	# v0.3.4 created a HUD dial inside the menu. Its parent is hidden as well so it
	# consumes no layout space and cannot overlap Move.
	if screen_gizmo_v034 != null:
		screen_gizmo_v034.visible = false
		var dial_parent: CanvasItem = screen_gizmo_v034.get_parent() as CanvasItem
		if dial_parent != null:
			dial_parent.visible = false


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
		rotation_panel.offset_top = RIGHT_PANEL_TOP_035
		rotation_panel.offset_bottom = 402.0
		move_panel.offset_top = 408.0
		move_panel.offset_bottom = 460.0
	elif move_open:
		rotation_panel.offset_top = RIGHT_PANEL_TOP_035
		rotation_panel.offset_bottom = 164.0
		move_panel.offset_top = 170.0
		move_panel.offset_bottom = 576.0
	else:
		rotation_panel.offset_top = RIGHT_PANEL_TOP_035
		rotation_panel.offset_bottom = 164.0
		move_panel.offset_top = 170.0
		move_panel.offset_bottom = 222.0


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	super._set_editor_mode_v032(mode_value, report)
	if editor_mode_v032 != EDITOR_ROTATE_032 and rotation_body != null and rotation_body.visible:
		rotation_body.visible = false
		if rotation_collapse_button != null:
			rotation_collapse_button.text = "ROTATE ▸"
		_layout_right_panels_v032()
	_refresh_gizmo_validity_v030()
	_refresh_attach_points_v032()


func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	if mode_hint_v032 == null:
		return
	match editor_mode_v032:
		EDITOR_CREATE_032:
			mode_hint_v032.text = "Build with world-defined placement orientation"
		EDITOR_ROTATE_032:
			mode_hint_v032.text = "World XYZ gizmo on selected piece • 45° snap"
		EDITOR_ATTACH_032:
			match attach_mode:
				0:
					mode_hint_v032.text = "SOCKET: rod end ↔ connector socket"
				1:
					mode_hint_v032.text = "AXLE: connector hub ↔ exact rod shaft point"
				2:
					mode_hint_v032.text = "CROSS: connector socket ↔ exact rod shaft point"


func _update_ui() -> void:
	super._update_ui()
	if screen_gizmo_v034 != null:
		screen_gizmo_v034.visible = false
	if rotation_selected_v035 != null:
		rotation_selected_v035.text = "Selected: %s" % (_piece_display_name(selected_piece) if is_instance_valid(selected_piece) else "—")
	var connector_selected: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and _selected_kind() == "connector"
	if roll_minus_v035 != null:
		roll_minus_v035.disabled = not connector_selected or not bool(_roll_candidate_v030(-1).get("valid", false))
	if roll_plus_v035 != null:
		roll_plus_v035.disabled = not connector_selected or not bool(_roll_candidate_v030(1).get("valid", false))
	if reset_rotation_v035 != null:
		reset_rotation_v035.disabled = editor_mode_v032 != EDITOR_ROTATE_032 or simulating or _selected_kind() != "connector"
	_refresh_gizmo_validity_v030()


func _process(delta: float) -> void:
	super._process(delta)
	if screen_gizmo_v034 != null:
		screen_gizmo_v034.visible = false
	if gizmo_root_v030 == null:
		return
	var show_world_gizmo: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and not help_panel.visible and not options_panel.visible
	gizmo_root_v030.visible = show_world_gizmo
	if show_world_gizmo:
		# Identity is intentional: X/Y/Z are always WORLD axes, never selected-piece
		# local axes and never camera axes.
		gizmo_root_v030.global_basis = Basis.IDENTITY
		gizmo_root_v030.global_position = _gizmo_anchor_v030()
		var scale_value: float = clampf(camera_distance / 19.0, 0.62, 2.25)
		gizmo_root_v030.scale = Vector3.ONE * scale_value


func _world_axis_v035(axis_name: String) -> Vector3:
	match axis_name:
		"X":
			return Vector3.RIGHT
		"Y":
			return Vector3.UP
		"Z":
			return Vector3.BACK
	return Vector3.ZERO


# Keep v0.3.4 callers correct even though its menu dial is no longer visible.
func _rotation_candidate_v034(axis_name: String, steps: int) -> Dictionary:
	var axis_value: Vector3 = _world_axis_v035(axis_name)
	if axis_value.length_squared() < 0.5:
		return {"valid": false, "reason": "invalid world axis"}
	return _rotation_candidate_v030(axis_value, steps)


func _update_screen_gizmo_v034() -> void:
	# Retired in v0.3.5. The selected-piece world gizmo is authoritative.
	if screen_gizmo_v034 != null:
		screen_gizmo_v034.visible = false


func _refresh_gizmo_validity_v030() -> void:
	if gizmo_root_v030 == null:
		return
	var enabled: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and tool_mode_v030.is_empty()
	for name_value in ["X", "Y", "Z"]:
		if not gizmo_axes_v030.has(name_value):
			continue
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var ring: MeshInstance3D = data["ring"] as MeshInstance3D
		var plus_label: Label3D = data["plus"] as Label3D
		var minus_label: Label3D = data["minus"] as Label3D
		var axis: Vector3 = data["axis"] as Vector3
		var base_material: StandardMaterial3D = data["material"] as StandardMaterial3D
		var plus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		ring.material_override = base_material if plus_valid or minus_valid else gizmo_disabled_mat_v030
		plus_label.modulate = base_material.albedo_color if plus_valid else gizmo_disabled_mat_v030.albedo_color
		minus_label.modulate = base_material.albedo_color if minus_valid else gizmo_disabled_mat_v030.albedo_color


# -----------------------------------------------------------------------------
# Rotation picking/dragging. Projection chooses which visible ring the finger is
# on; the actual transform is always an exact world-axis 45° multiple.
# -----------------------------------------------------------------------------

func _point_segment_pick_v035(point: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var ab: Vector2 = b - a
	var length_sq: float = ab.length_squared()
	if length_sq < 0.0001:
		return {"distance": point.distance_to(a), "tangent": Vector2.RIGHT}
	var t: float = clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return {"distance": point.distance_to(closest), "tangent": ab.normalized()}


func _ring_pick_v035(axis_value: Vector3, screen_pos: Vector2, max_distance: float) -> Dictionary:
	if gizmo_root_v030 == null or camera == null:
		return {}
	var axis: Vector3 = axis_value.normalized()
	var center: Vector3 = _gizmo_anchor_v030()
	var radius: float = GIZMO_RADIUS_030 * gizmo_root_v030.scale.x
	var u: Vector3 = _world_perpendicular_v035(axis)
	var v: Vector3 = axis.cross(u).normalized()
	var best_distance: float = max_distance
	var best: Dictionary = {}

	for i in range(WORLD_GIZMO_SAMPLES_035):
		var a_angle: float = TAU * float(i) / float(WORLD_GIZMO_SAMPLES_035)
		var b_angle: float = TAU * float(i + 1) / float(WORLD_GIZMO_SAMPLES_035)
		var world_a: Vector3 = center + (u * cos(a_angle) + v * sin(a_angle)) * radius
		var world_b: Vector3 = center + (u * cos(b_angle) + v * sin(b_angle)) * radius
		if camera.is_position_behind(world_a) or camera.is_position_behind(world_b):
			continue
		var screen_a: Vector2 = camera.unproject_position(world_a)
		var screen_b: Vector2 = camera.unproject_position(world_b)
		var pick: Dictionary = _point_segment_pick_v035(screen_pos, screen_a, screen_b)
		var distance: float = float(pick["distance"])
		if distance < best_distance:
			best_distance = distance
			best = {"distance": distance, "tangent": pick["tangent"], "center": center, "axis": axis}
	return best


func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var best: Dictionary = {}
	var best_distance: float = WORLD_GIZMO_PICK_PX_035
	for name_value in ["X", "Y", "Z"]:
		if not gizmo_axes_v030.has(name_value):
			continue
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var axis: Vector3 = data["axis"] as Vector3
		var plus_valid: bool = bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid: bool = bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		if not plus_valid and not minus_valid:
			continue
		var pick: Dictionary = _ring_pick_v035(axis, screen_pos, best_distance)
		if pick.is_empty():
			continue
		var distance: float = float(pick["distance"])
		if distance <= best_distance:
			best_distance = distance
			best = {"name": name_value, "axis": axis, "center": pick["center"], "tangent": pick["tangent"]}
	return best


func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not tool_mode_v030.is_empty():
		return false
	var picked: Dictionary = _pick_gizmo_axis_v030(screen_pos)
	if picked.is_empty():
		return false
	var context: Dictionary = _rotation_context_v030(selected_piece)
	if not bool(context.get("valid", false)):
		_status("Rotation blocked — %s" % str(context.get("reason", "invalid connection context")))
		return false
	gizmo_drag_active_v030 = true
	gizmo_drag_axis_v030 = picked["axis"] as Vector3
	gizmo_drag_axis_name_v030 = str(picked["name"])
	gizmo_drag_center_v030 = picked["center"] as Vector3
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = context["component"] as Array
	gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
	gizmo_drag_last_screen_v035 = screen_pos
	gizmo_drag_accum_px_v035 = 0.0
	gizmo_drag_tangent_v035 = (picked["tangent"] as Vector2).normalized()
	_build_rotation_ghost_v030(gizmo_drag_component_v030)
	_status("WORLD %s selected — drag the ring; every 52 px snaps one exact 45° step" % gizmo_drag_axis_name_v030)
	return true


func _update_gizmo_drag_v030(screen_pos: Vector2) -> void:
	if not gizmo_drag_active_v030:
		return
	var tangent_pick: Dictionary = _ring_pick_v035(gizmo_drag_axis_v030, screen_pos, 110.0)
	var tangent: Vector2 = gizmo_drag_tangent_v035
	if not tangent_pick.is_empty():
		tangent = (tangent_pick["tangent"] as Vector2).normalized()
		gizmo_drag_tangent_v035 = tangent
	var delta: Vector2 = screen_pos - gizmo_drag_last_screen_v035
	gizmo_drag_last_screen_v035 = screen_pos
	gizmo_drag_accum_px_v035 += delta.dot(tangent)
	var steps: int = clampi(int(round(gizmo_drag_accum_px_v035 / WORLD_GIZMO_STEP_PIXELS_035)), -7, 7)
	if steps == gizmo_drag_steps_v030:
		return
	gizmo_drag_steps_v030 = steps
	if steps == 0:
		gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
		_update_rotation_ghost_v030({}, true)
		_status("WORLD %s preview: 0°" % gizmo_drag_axis_name_v030)
		return
	var preview: Dictionary = _rotation_candidate_v030(gizmo_drag_axis_v030, steps)
	gizmo_drag_preview_v030 = preview
	_update_rotation_ghost_v030(preview.get("transforms", {}) as Dictionary, bool(preview.get("valid", false)))
	_status("WORLD %s preview: %d°%s" % [gizmo_drag_axis_name_v030, steps * 45, "" if bool(preview.get("valid", false)) else " — BLOCKED"])


func _finish_gizmo_drag_v030() -> void:
	if not gizmo_drag_active_v030:
		return
	var steps: int = gizmo_drag_steps_v030
	var preview: Dictionary = gizmo_drag_preview_v030
	gizmo_drag_active_v030 = false
	gizmo_drag_steps_v030 = 0
	gizmo_drag_accum_px_v035 = 0.0
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Rotation unchanged")
		return
	if not bool(preview.get("valid", false)):
		_status("Rotation blocked — %s" % str(preview.get("reason", "connections prevent that world-axis state")))
		_refresh_gizmo_validity_v030()
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated WORLD %s by %d°" % [gizmo_drag_axis_name_v030, steps * 45])
	_refresh_gizmo_validity_v030()


# -----------------------------------------------------------------------------
# ATTACH: strict mode-specific two-step state machine.
# -----------------------------------------------------------------------------

func _all_attach_points_v032() -> Array:
	var result: Array = []
	_rebuild_connection_graph_v020()
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var kind: String = str(body.get_meta("kind", ""))
		if kind == "rod" and attach_mode == 0:
			for sign_value in [-1, 1]:
				result.append({"type": "rod_end", "body": body, "sign": sign_value, "point": _rod_end_v020(body, sign_value)})
		elif kind == "connector":
			if attach_mode in [0, 2]:
				var def_index: int = int(body.get_meta("connector_type", -1))
				if def_index >= 0 and def_index < connector_defs.size():
					for slot_value in connector_defs[def_index]["slots"]:
						var slot: int = int(slot_value)
						result.append({"type": "socket", "body": body, "slot": slot, "point": _socket_world_v020(body, slot)["point"]})
			elif attach_mode == 1:
				result.append({"type": "connector_hub", "body": body, "point": body.global_position})
	if attach_mode == 1:
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
	var found_selected: bool = current_key.is_empty() or str(attach_point_selected_v032.get("type", "")) == "rod_body"
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		var selected: bool = not current_key.is_empty() and _point_key_v032(point) == current_key
		if selected:
			found_selected = true
			attach_point_selected_v032 = point.duplicate(true)
		var occupied: bool = not _connection_record_for_point_v032(point).is_empty()
		var type_value: String = str(point.get("type", ""))
		var scale_value: float = 0.18 if selected else (0.105 if type_value in ["connector_hub", "o_ring"] else 0.085)
		if occupied and not selected:
			scale_value = 0.075
		_make_handle_v030(attach_points_root_v032, point["point"] as Vector3, _point_material_v032(point, selected), scale_value)

	if not attach_point_selected_v032.is_empty() and str(attach_point_selected_v032.get("type", "")) == "rod_body":
		var selected_rod: RigidBody3D = attach_point_selected_v032.get("body") as RigidBody3D
		if is_instance_valid(selected_rod) and attach_mode in [1, 2]:
			_make_handle_v030(attach_points_root_v032, attach_point_selected_v032["point"] as Vector3, point_selected_mat_v032, 0.18)
		else:
			found_selected = false

	if not found_selected:
		attach_point_selected_v032 = {}

	if not attach_point_selected_v032.is_empty():
		var label: Label3D = Label3D.new()
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


func _rod_body_from_screen_v035(screen_pos: Vector2, exclude_body: RigidBody3D = null) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var excluded: Array = []
	if is_instance_valid(exclude_body):
		excluded.append(exclude_body.get_rid())
	for _pass in range(8):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 900.0)
		query.collision_mask = 2 | 4
		query.exclude = excluded
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var body: RigidBody3D = hit.get("collider") as RigidBody3D
		if is_instance_valid(body) and str(body.get_meta("kind", "")) == "rod":
			var axis: Vector3 = _rod_axis_v020(body)
			var half_len: float = maxf(0.10, float(body.get_meta("visual_length", 0.0)) * 0.5 - 0.38)
			var hit_point: Vector3 = hit.get("position", body.global_position) as Vector3
			var along: float = clampf((hit_point - body.global_position).dot(axis), -half_len, half_len)
			return {"type": "rod_body", "body": body, "along": along, "point": body.global_position + axis * along}
		if is_instance_valid(body):
			excluded.append(body.get_rid())
		else:
			return {}
	return {}


func _selected_point_hit_v035(screen_pos: Vector2) -> bool:
	if attach_point_selected_v032.is_empty():
		return false
	var point: Vector3 = attach_point_selected_v032.get("point", Vector3.ZERO) as Vector3
	if camera.is_position_behind(point):
		return false
	return camera.unproject_position(point).distance_to(screen_pos) <= ATTACH_PICK_RADIUS_034


func _allowed_initial_point_v035(point: Dictionary) -> bool:
	var type_value: String = str(point.get("type", ""))
	match attach_mode:
		0:
			return type_value in ["rod_end", "socket"]
		1:
			return type_value in ["rod_body", "connector_hub", "o_ring"]
		2:
			return type_value in ["rod_body", "socket"]
	return false


func _expected_target_types_v035(source_type: String) -> Array:
	match attach_mode:
		0:
			return ["socket"] if source_type == "rod_end" else (["rod_end"] if source_type == "socket" else [])
		1:
			if source_type in ["connector_hub", "o_ring"]:
				return ["rod_body"]
			if source_type == "rod_body":
				return ["connector_hub", "o_ring"]
		2:
			return ["rod_body"] if source_type == "socket" else (["socket"] if source_type == "rod_body" else [])
	return []


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	var discrete: Dictionary = _nearest_projected_candidate_v030(_all_attach_points_v032(), screen_pos, ATTACH_PICK_RADIUS_034)
	if not discrete.is_empty() and _allowed_initial_point_v035(discrete):
		return discrete
	if attach_mode in [1, 2]:
		return _rod_body_from_screen_v035(screen_pos)
	return {}


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	var source_type: String = str(source.get("type", ""))
	var expected: Array = _expected_target_types_v035(source_type)
	if expected.is_empty():
		return {}
	if "rod_body" in expected:
		return _rod_body_from_screen_v035(screen_pos, source.get("body") as RigidBody3D)
	var candidates: Array = []
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		if str(point.get("type", "")) in expected and point.get("body") != source.get("body"):
			candidates.append(point)
	return _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PICK_RADIUS_034)


func _pair_mode_v032(a: Dictionary, b: Dictionary) -> int:
	var at: String = str(a.get("type", ""))
	var bt: String = str(b.get("type", ""))
	match attach_mode:
		0:
			return 0 if ((at == "rod_end" and bt == "socket") or (at == "socket" and bt == "rod_end")) else -1
		1:
			return 1 if (((at in ["connector_hub", "o_ring"]) and bt == "rod_body") or (at == "rod_body" and (bt in ["connector_hub", "o_ring"]))) else -1
		2:
			return 2 if ((at == "socket" and bt == "rod_body") or (at == "rod_body" and bt == "socket")) else -1
	return -1


func _records_between_bodies_v035(a: RigidBody3D, b: RigidBody3D) -> Array:
	var result: Array = []
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		if (record.get("a") == a and record.get("b") == b) or (record.get("a") == b and record.get("b") == a):
			result.append(record)
	return result


func _same_record_v035(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() and int(a.get("uid", -1)) == int(b.get("uid", -2))


func _connect_points_v035(source: Dictionary, target: Dictionary) -> bool:
	var source_body: RigidBody3D = source.get("body") as RigidBody3D
	var target_body: RigidBody3D = target.get("body") as RigidBody3D
	if not is_instance_valid(source_body) or not is_instance_valid(target_body) or source_body == target_body:
		_status("Connection blocked — choose two different pieces")
		return false

	_rebuild_connection_graph_v020()
	var source_record: Dictionary = _connection_record_for_point_v032(source)
	var target_record: Dictionary = _connection_record_for_point_v032(target)
	var old_record: Dictionary = source_record

	# Changing SOCKET -> CROSS/AXLE (or the reverse) between the same two physical
	# pieces must first release their old edge. v0.3.4 missed this when the chosen
	# rod-body/hub point itself was not the occupied endpoint.
	if old_record.is_empty():
		var pair_records: Array = _records_between_bodies_v035(source_body, target_body)
		if pair_records.size() == 1:
			old_record = pair_records[0] as Dictionary
		elif pair_records.size() > 1:
			_status("Connection blocked — these pieces have multiple existing links. Start from the occupied port you want to move.")
			return false

	if not target_record.is_empty() and not _same_record_v035(target_record, old_record):
		_status("Target is already occupied by another connection")
		return false

	if not source_record.is_empty() and _same_record_v035(source_record, target_record):
		var desired_kind: String = "socket" if attach_mode == 0 else ("cross" if attach_mode == 2 else ("o_ring" if str(source.get("type", "")) == "o_ring" or str(target.get("type", "")) == "o_ring" else "axle"))
		if str(source_record.get("kind", "")) == desired_kind:
			_status("Those two attachment points are already connected")
			return false

	var excluded_uid: int = int(old_record.get("uid", -1)) if not old_record.is_empty() else -1
	var source_component: Array = _fixed_component_v020(source_body, excluded_uid)
	if _component_has_piece_v020(source_component, target_body):
		_status("Connection blocked — another rigid path still locks these two pieces together")
		return false

	var snap: Dictionary = _snap_source_component_v030(source, target, source_component)
	if not bool(snap.get("valid", false)):
		_status("Connection blocked — %s" % str(snap.get("reason", "cannot align those points")))
		return false
	var transforms: Dictionary = snap.get("transforms", {}) as Dictionary
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		_status("Connection blocked — %s" % str(validation.get("reason", "moving that side would break another connection")))
		return false

	if not old_record.is_empty():
		_detach_record_raw_v032(old_record)
	_apply_transforms_raw_v030(transforms)
	_create_explicit_connection_v030(source, target)
	manual_detach_blocks_v030.erase(_pair_key_v030(source_body, target_body))
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	var mode_name: String = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	_status("%s %s" % [mode_name, "re-attached" if not old_record.is_empty() else "attached"])
	return true


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	if simulating:
		return

	if not attach_point_selected_v032.is_empty() and _selected_point_hit_v035(screen_pos):
		_deselect_attach_point_v032(false)
		_status("Attachment source deselected")
		return

	if attach_point_selected_v032.is_empty():
		var source: Dictionary = _pick_initial_attach_point_v035(screen_pos)
		if source.is_empty():
			match attach_mode:
				0:
					_status("SOCKET: tap a rod END or connector SOCKET. Rod shafts are not attachment points in SOCKET mode.")
				1:
					_status("AXLE: tap a connector HUB / O-Ring or tap the exact place on a rod shaft")
				2:
					_status("CROSS: tap a connector SOCKET or tap the exact place on a rod shaft")
			return
		attach_point_selected_v032 = source.duplicate(true)
		_refresh_attach_points_v032()
		_status("Source selected: %s. Now tap its compatible target." % _point_display_v032(source))
		return

	var source_selected: Dictionary = attach_point_selected_v032
	var target: Dictionary = _pick_attach_target_v035(screen_pos, source_selected)
	if target.is_empty():
		var expected: Array = _expected_target_types_v035(str(source_selected.get("type", "")))
		_status("Source stays selected — tap %s" % ", ".join(expected))
		return

	var source: Dictionary = source_selected
	# O-Ring connection creation expects the O-Ring as the moving source.
	if str(source.get("type", "")) == "rod_body" and str(target.get("type", "")) == "o_ring":
		var swap_value: Dictionary = source
		source = target
		target = swap_value

	if _pair_mode_v032(source, target) < 0:
		_status("Those points are not compatible in %s mode" % ["SOCKET", "AXLE", "CROSS"][attach_mode])
		return
	if _connect_points_v035(source, target):
		attach_point_selected_v032 = {}
		_refresh_attach_points_v032()


func _cycle_mode() -> void:
	_deselect_attach_point_v032(false)
	super._cycle_mode()
	_refresh_attach_points_v032()
	_update_mode_ui_v032()
	if editor_mode_v032 == EDITOR_ATTACH_032:
		_status("ATTACH now uses %s — only compatible point types are active" % ["SOCKET", "AXLE", "CROSS"][attach_mode])


# -----------------------------------------------------------------------------
# Version/help/updater awareness.
# -----------------------------------------------------------------------------

func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCREATE: placement orientation is deterministic in world space. No creation path is allowed to use camera up/right to choose connector roll.\n\nROTATE: the red X, green Y and blue Z rings are drawn around the selected piece like a normal 3D editor gizmo. They are WORLD axes. Dragging selects an integer number of exact 45° world-axis steps; the camera only projects the visible ring and never enters the transform. Invalid directions are gray. Roll remains the separate real connection-axis control.\n\nATTACH obeys the bottom connection mode. SOCKET shows only rod ends + connector sockets. AXLE shows hubs/O-Rings and lets you tap an exact rod-shaft position. CROSS shows connector sockets and lets you tap an exact rod-shaft position. After the first tap, only the compatible target is accepted; unrelated taps no longer silently change selection. Deselect Point clears the source.\n\nChanging connection type between the same rod and connector explicitly removes the old SOCKET/CROSS/AXLE edge only after the new geometry validates.\n\nCamera: one finger orbit, two fingers pan/zoom. Options and update settings persist." % VERSION_035


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
	if _compare_versions_v021(latest, VERSION_035) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_035)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_035, latest])