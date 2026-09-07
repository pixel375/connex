extends "res://scripts/main_v035.gd"

const VERSION_036 := "0.3.6"
const ATTACH_PICK_RADIUS_036 := 54.0
const ATTACH_PHYSICAL_FALLBACK_RADIUS_036 := 72.0
const CROSS_NORMAL_ALIGN_036 := 0.94
const CROSS_SOCKET_PERP_036 := 0.26
const GIZMO_SAMPLES_036 := 96
const GIZMO_UPDATE_RADIUS_036 := 110.0

var gizmo_drag_last_param_v036: float = 0.0
var gizmo_drag_accum_angle_v036: float = 0.0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_036)
	_enforce_right_panel_exclusive_v036(editor_mode_v032 == EDITOR_ROTATE_032)
	_refresh_attach_points_v032()
	_refresh_gizmo_validity_v030()
	_status("CREATE mode — v0.3.6 stabilizes attachment picking, world-gizmo dragging, placement reset, and true perpendicular CROSS geometry.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_036, text]


# -----------------------------------------------------------------------------
# Right-side accordion. The two utility bodies are now mutually exclusive even
# when ROTATE opens its panel automatically through an inherited mode switch.
# -----------------------------------------------------------------------------

func _enforce_right_panel_exclusive_v036(prefer_rotation: bool) -> void:
	if rotation_body == null or move_body == null:
		return
	if rotation_body.visible and move_body.visible:
		if prefer_rotation:
			move_body.visible = false
		else:
			rotation_body.visible = false
	if rotation_collapse_button != null:
		rotation_collapse_button.text = "ROTATE ▾" if rotation_body.visible else "ROTATE ▸"
	if move_collapse_button != null:
		move_collapse_button.text = "MOVE ▾" if move_body.visible else "MOVE ▸"
	_layout_right_panels_v032()


func _toggle_rotation_panel() -> void:
	if rotation_body == null:
		return
	var opening: bool = not rotation_body.visible
	rotation_body.visible = opening
	if opening and move_body != null:
		move_body.visible = false
	_enforce_right_panel_exclusive_v036(true)


func _toggle_move_panel() -> void:
	if move_body == null:
		return
	var opening: bool = not move_body.visible
	move_body.visible = opening
	if opening and rotation_body != null:
		rotation_body.visible = false
	_enforce_right_panel_exclusive_v036(false)


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
	rotation_panel.clip_contents = true
	move_panel.clip_contents = true

	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var top_value: float = RIGHT_PANEL_TOP_035
	var bottom_limit: float = maxf(top_value + 250.0, viewport_height - 122.0)
	var collapsed_height: float = 52.0
	var gap: float = 6.0

	var rotate_open: bool = rotation_body != null and rotation_body.visible
	var move_open: bool = move_body != null and move_body.visible
	if rotate_open and move_open:
		# This is a last-line invariant, not normal UI behavior.
		move_body.visible = false
		move_open = false

	if rotate_open:
		var rotate_bottom: float = minf(top_value + 324.0, bottom_limit - collapsed_height - gap)
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = rotate_bottom
		move_panel.offset_top = rotate_bottom + gap
		move_panel.offset_bottom = rotate_bottom + gap + collapsed_height
	elif move_open:
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed_height
		move_panel.offset_top = top_value + collapsed_height + gap
		move_panel.offset_bottom = bottom_limit
	else:
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed_height
		move_panel.offset_top = top_value + collapsed_height + gap
		move_panel.offset_bottom = top_value + collapsed_height * 2.0 + gap


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	super._set_editor_mode_v032(mode_value, report)
	if editor_mode_v032 == EDITOR_ROTATE_032:
		if move_body != null:
			move_body.visible = false
		if rotation_body != null:
			rotation_body.visible = true
		_enforce_right_panel_exclusive_v036(true)
	else:
		if rotation_body != null:
			rotation_body.visible = false
		_enforce_right_panel_exclusive_v036(false)
	_refresh_gizmo_validity_v030()
	_refresh_attach_points_v032()


# -----------------------------------------------------------------------------
# CROSS geometry. A CROSS rod is parallel to the connector normal just like an
# axle rod, but it passes through a side socket/clamp instead of the center hub.
# -----------------------------------------------------------------------------

func _basis_for_cross_v020(local_slot: Vector3, host_axis: Vector3, radial: Vector3) -> Basis:
	var host_n: Vector3 = host_axis.normalized()
	var radial_n: Vector3 = radial - host_n * radial.dot(host_n)
	if radial_n.length_squared() < 0.02:
		radial_n = _world_perpendicular_v035(host_n)
	radial_n = radial_n.normalized()
	var base: Basis = Basis(Quaternion(local_slot.normalized(), radial_n))
	var current_normal: Vector3 = (base * Vector3.UP).normalized()
	var angle: float = current_normal.signed_angle_to(host_n, radial_n)
	return (Basis(radial_n, angle) * base).orthonormalized()


func _snap_source_component_v030(source: Dictionary, target: Dictionary, component: Array) -> Dictionary:
	var source_type: String = str(source.get("type", ""))
	var target_type: String = str(target.get("type", ""))
	if attach_mode == 2 and source_type == "rod_body" and target_type == "socket":
		var cross_rod: RigidBody3D = source.get("body") as RigidBody3D
		var target_connector: RigidBody3D = target.get("body") as RigidBody3D
		if not is_instance_valid(cross_rod) or not is_instance_valid(target_connector):
			return {"valid": false, "reason": "missing CROSS piece"}
		var desired_rod_axis: Vector3 = (target_connector.global_transform.basis * Vector3.UP).normalized()
		var current_rod_axis: Vector3 = _rod_axis_v020(cross_rod)
		if desired_rod_axis.dot(current_rod_axis) < 0.0:
			desired_rod_axis = -desired_rod_axis
		var rod_rotate: Basis = Basis(Quaternion(current_rod_axis, desired_rod_axis))
		var rod_basis: Basis = (rod_rotate * cross_rod.global_transform.basis).orthonormalized()
		var target_socket: Dictionary = _socket_world_v020(target_connector, int(target.get("slot", -1)))
		var rod_origin: Vector3 = (target_socket.get("point", cross_rod.global_position) as Vector3) - desired_rod_axis * float(source.get("along", 0.0))
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, cross_rod.global_transform, Transform3D(rod_basis, rod_origin))}
	return super._snap_source_component_v030(source, target, component)


func _current_attach_geometry_v030(source: Dictionary, target: Dictionary) -> Dictionary:
	var source_type: String = str(source.get("type", ""))
	var target_type: String = str(target.get("type", ""))
	if (source_type == "socket" and target_type == "rod_body") or (source_type == "rod_body" and target_type == "socket"):
		var socket_point: Dictionary = source if source_type == "socket" else target
		var rod_point: Dictionary = target if source_type == "socket" else source
		var connector: RigidBody3D = socket_point.get("body") as RigidBody3D
		var rod: RigidBody3D = rod_point.get("body") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			return {"valid": false}
		var socket: Dictionary = _socket_world_v020(connector, int(socket_point.get("slot", -1)))
		var rod_axis: Vector3 = _rod_axis_v020(rod)
		var connector_normal: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
		return {
			"valid": (socket.get("point", connector.global_position) as Vector3).distance_to(rod_point.get("point", rod.global_position) as Vector3) <= ATTACH_CROSS_GAP_030 \
				and absf((socket.get("dir", Vector3.RIGHT) as Vector3).dot(rod_axis)) <= CROSS_SOCKET_PERP_036 \
				and absf(connector_normal.dot(rod_axis)) >= CROSS_NORMAL_ALIGN_036
		}
	return super._current_attach_geometry_v030(source, target)


func _validate_record_v020(record: Dictionary, transforms: Dictionary) -> Dictionary:
	if str(record.get("kind", "")) != "cross":
		return super._validate_record_v020(record, transforms)
	var connector: RigidBody3D = record.get("connector") as RigidBody3D
	var rod: RigidBody3D = record.get("rod") as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return {"valid": false, "reason": "missing cross body"}
	var slot: int = int(record.get("slot", -1))
	var connector_tf: Transform3D = _transform_for_v020(connector, transforms)
	var rod_tf: Transform3D = _transform_for_v020(rod, transforms)
	var socket: Dictionary = _socket_world_v020(connector, slot, connector_tf, true)
	var rod_axis: Vector3 = _rod_axis_v020(rod, rod_tf, true)
	var host_point: Vector3 = rod_tf.origin + rod_axis * float(record.get("host_along", 0.0))
	var rest_gap: float = float(record.get("rest_gap", 0.0))
	var gap_limit: float = maxf(0.14, rest_gap + VALIDATION_EPS_V020)
	if (socket.get("point", connector_tf.origin) as Vector3).distance_to(host_point) > gap_limit:
		return {"valid": false, "reason": "the cross snap point would separate"}
	var perp_limit: float = maxf(0.10, float(record.get("rest_perp", 0.0)) + 0.035)
	if absf((socket.get("dir", Vector3.RIGHT) as Vector3).dot(rod_axis)) > perp_limit:
		return {"valid": false, "reason": "the side socket would stop crossing the rod at 90°"}
	var connector_normal: Vector3 = (connector_tf.basis * Vector3.UP).normalized()
	var rest_normal_align: float = float(record.get("rest_plane", 1.0))
	var normal_limit: float = minf(0.99, maxf(CROSS_NORMAL_ALIGN_036, rest_normal_align - 0.01))
	if absf(connector_normal.dot(rod_axis)) < normal_limit:
		return {"valid": false, "reason": "the CROSS rod must stay perpendicular to the connector face"}
	return {"valid": true}


func _auto_connect_crosses_v020() -> int:
	var count: int = 0
	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size():
			continue
		var connector_normal: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
			if occupied.has(slot):
				continue
			var socket: Dictionary = _socket_world_v020(connector, slot)
			var mouth: Vector3 = socket.get("point", connector.global_position) as Vector3
			var slot_dir: Vector3 = socket.get("dir", Vector3.RIGHT) as Vector3
			var best_rod: RigidBody3D = null
			var best_along: float = 0.0
			var best_distance: float = CROSS_CAPTURE_V020
			for rod_value in bodies:
				var rod: RigidBody3D = rod_value as RigidBody3D
				if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
					continue
				if _fixed_pair_exists_v020(rod, connector):
					continue
				var rod_axis: Vector3 = _rod_axis_v020(rod)
				if absf(slot_dir.dot(rod_axis)) > CROSS_SOCKET_PERP_036:
					continue
				if absf(connector_normal.dot(rod_axis)) < CROSS_NORMAL_ALIGN_036:
					continue
				var half_len: float = maxf(0.0, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.50)
				var along: float = clampf((mouth - rod.global_position).dot(rod_axis), -half_len, half_len)
				var closest: Vector3 = rod.global_position + rod_axis * along
				var distance: float = closest.distance_to(mouth)
				if distance <= best_distance:
					best_distance = distance
					best_rod = rod
					best_along = along
			if is_instance_valid(best_rod):
				var host_point: Vector3 = best_rod.global_position + _rod_axis_v020(best_rod) * best_along
				var anchor: Vector3 = (mouth + host_point) * 0.5
				var joint: Generic6DOFJoint3D = _make_fixed_joint(best_rod, connector, anchor)
				var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
				var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
				_tag_connection_v020(joint, "cross", connector, best_rod, slot, 0, best_along, null, primary)
				_set_connector_occupied(connector, slot, true)
				count += 1
	return count


# -----------------------------------------------------------------------------
# Attachment selection. Selected points are live references to piece topology,
# not frozen world coordinates. Picking gets a larger projected target plus a
# physical raycast fallback for points that are visually crowded.
# -----------------------------------------------------------------------------

func _refresh_selected_attach_geometry_v036() -> void:
	if attach_point_selected_v032.is_empty():
		return
	var body: RigidBody3D = attach_point_selected_v032.get("body") as RigidBody3D
	if not is_instance_valid(body):
		attach_point_selected_v032 = {}
		return
	match str(attach_point_selected_v032.get("type", "")):
		"rod_end":
			attach_point_selected_v032["point"] = _rod_end_v020(body, int(attach_point_selected_v032.get("sign", 0)))
		"rod_body":
			var axis: Vector3 = _rod_axis_v020(body)
			var half_len: float = maxf(0.10, float(body.get_meta("visual_length", 0.0)) * 0.5 - 0.38)
			var along: float = clampf(float(attach_point_selected_v032.get("along", 0.0)), -half_len, half_len)
			attach_point_selected_v032["along"] = along
			attach_point_selected_v032["point"] = body.global_position + axis * along
		"socket":
			attach_point_selected_v032["point"] = _socket_world_v020(body, int(attach_point_selected_v032.get("slot", -1)))["point"]
		"connector_hub", "o_ring":
			attach_point_selected_v032["point"] = body.global_position


func _refresh_attach_points_v032() -> void:
	_refresh_selected_attach_geometry_v036()
	super._refresh_attach_points_v032()


func _selected_point_hit_v035(screen_pos: Vector2) -> bool:
	_refresh_selected_attach_geometry_v036()
	if attach_point_selected_v032.is_empty():
		return false
	var point: Vector3 = attach_point_selected_v032.get("point", Vector3.ZERO) as Vector3
	if camera.is_position_behind(point):
		return false
	return camera.unproject_position(point).distance_to(screen_pos) <= ATTACH_PICK_RADIUS_036


func _physical_discrete_point_v036(screen_pos: Vector2, expected_types: Array, exclude_body: RigidBody3D = null) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var excluded: Array = []
	if is_instance_valid(exclude_body):
		excluded.append(exclude_body.get_rid())
	for _pass in range(10):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 900.0)
		query.collision_mask = 2 | 4
		query.exclude = excluded
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var body: RigidBody3D = hit.get("collider") as RigidBody3D
		if not is_instance_valid(body):
			return {}
		var kind: String = str(body.get_meta("kind", ""))
		var candidates: Array = []
		if kind == "rod" and "rod_end" in expected_types:
			for sign_value in [-1, 1]:
				candidates.append({"type": "rod_end", "body": body, "sign": sign_value, "point": _rod_end_v020(body, sign_value)})
		elif kind == "connector" and "socket" in expected_types:
			var def_index: int = int(body.get_meta("connector_type", -1))
			if def_index >= 0 and def_index < connector_defs.size():
				for slot_value in connector_defs[def_index]["slots"]:
					var slot: int = int(slot_value)
					candidates.append({"type": "socket", "body": body, "slot": slot, "point": _socket_world_v020(body, slot)["point"]})
		elif kind == "connector" and "connector_hub" in expected_types:
			candidates.append({"type": "connector_hub", "body": body, "point": body.global_position})
		if not candidates.is_empty():
			var nearest: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PHYSICAL_FALLBACK_RADIUS_036)
			if not nearest.is_empty():
				return nearest
		excluded.append(body.get_rid())
	return {}


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	var discrete: Dictionary = _nearest_projected_candidate_v030(_all_attach_points_v032(), screen_pos, ATTACH_PICK_RADIUS_036)
	if not discrete.is_empty() and _allowed_initial_point_v035(discrete):
		return discrete
	if attach_mode in [1, 2]:
		var body_point: Dictionary = _rod_body_from_screen_v035(screen_pos)
		if not body_point.is_empty():
			return body_point
	var expected: Array = []
	match attach_mode:
		0:
			expected = ["rod_end", "socket"]
		1:
			expected = ["connector_hub"]
		2:
			expected = ["socket"]
	return _physical_discrete_point_v036(screen_pos, expected)


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	_refresh_selected_attach_geometry_v036()
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
	var projected: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PICK_RADIUS_036)
	if not projected.is_empty():
		return projected
	return _physical_discrete_point_v036(screen_pos, expected, source.get("body") as RigidBody3D)


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	_refresh_selected_attach_geometry_v036()
	super._handle_attach_point_tap_v032(screen_pos)


# Keep the newly created/replaced mount as the connector's primary pivot if the
# edge being replaced was primary, or if the connector itself was the moving
# source. This prevents gizmo context from becoming ambiguous after reattachment.
func _desired_connection_kind_v036(source: Dictionary, target: Dictionary) -> String:
	if attach_mode == 0:
		return "socket"
	if attach_mode == 2:
		return "cross"
	if str(source.get("type", "")) == "o_ring" or str(target.get("type", "")) == "o_ring":
		return "o_ring"
	return "axle"


func _matching_connection_v036(a: RigidBody3D, b: RigidBody3D, kind: String, source: Dictionary, target: Dictionary) -> Dictionary:
	var wanted_slot: int = -1
	if str(source.get("type", "")) == "socket":
		wanted_slot = int(source.get("slot", -1))
	elif str(target.get("type", "")) == "socket":
		wanted_slot = int(target.get("slot", -1))
	for record_value in _records_between_bodies_v035(a, b):
		var record: Dictionary = record_value as Dictionary
		if str(record.get("kind", "")) != kind:
			continue
		if wanted_slot >= 0 and int(record.get("slot", -2)) != wanted_slot:
			continue
		return record
	return {}


func _connect_points_v035(source: Dictionary, target: Dictionary) -> bool:
	_refresh_selected_attach_geometry_v036()
	var source_body: RigidBody3D = source.get("body") as RigidBody3D
	var target_body: RigidBody3D = target.get("body") as RigidBody3D
	if not is_instance_valid(source_body) or not is_instance_valid(target_body) or source_body == target_body:
		_status("Connection blocked — choose two different pieces")
		return false

	_rebuild_connection_graph_v020()
	var source_record: Dictionary = _connection_record_for_point_v032(source)
	var target_record: Dictionary = _connection_record_for_point_v032(target)
	var old_record: Dictionary = source_record
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

	var desired_kind: String = _desired_connection_kind_v036(source, target)
	if not source_record.is_empty() and _same_record_v035(source_record, target_record) and str(source_record.get("kind", "")) == desired_kind:
		_status("Those two attachment points are already connected")
		return false

	var old_connector: RigidBody3D = old_record.get("connector") as RigidBody3D
	var old_uid: int = int(old_record.get("uid", -1))
	var old_was_primary: bool = is_instance_valid(old_connector) and int(old_connector.get_meta("primary_connection_uid_v020", -1)) == old_uid
	var excluded_uid: int = old_uid if not old_record.is_empty() else -1
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

	var new_record: Dictionary = _matching_connection_v036(source_body, target_body, desired_kind, source, target)
	if not new_record.is_empty():
		var new_connector: RigidBody3D = new_record.get("connector") as RigidBody3D
		if old_was_primary and is_instance_valid(old_connector) and old_connector == new_connector:
			new_connector.set_meta("primary_connection_uid_v020", int(new_record.get("uid", -1)))
		elif is_instance_valid(new_connector) and source_body == new_connector and not bool(new_connector.get_meta("root_piece_v020", false)):
			new_connector.set_meta("primary_connection_uid_v020", int(new_record.get("uid", -1)))

	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	var mode_name: String = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	_status("%s %s" % [mode_name, "re-attached" if not old_record.is_empty() else "attached"])
	return true


# -----------------------------------------------------------------------------
# World-gizmo drag. The old implementation integrated screen tangent pixels;
# after moved/rotated assemblies that tangent could flip and cancel itself. We
# now follow the actual projected ring parameter continuously and unwrap angle.
# -----------------------------------------------------------------------------

func _ring_param_pick_v036(axis_value: Vector3, screen_pos: Vector2, max_distance: float, preferred_param: float = 0.0, use_preferred: bool = false) -> Dictionary:
	if gizmo_root_v030 == null or camera == null:
		return {}
	var axis: Vector3 = axis_value.normalized()
	var center: Vector3 = _gizmo_anchor_v030()
	var radius: float = GIZMO_RADIUS_030 * gizmo_root_v030.scale.x
	var u: Vector3 = _world_perpendicular_v035(axis)
	var v: Vector3 = axis.cross(u).normalized()
	var best: Dictionary = {}
	var best_score: float = 1000000.0
	for i in range(GIZMO_SAMPLES_036):
		var a_angle: float = TAU * float(i) / float(GIZMO_SAMPLES_036)
		var b_angle: float = TAU * float(i + 1) / float(GIZMO_SAMPLES_036)
		var world_a: Vector3 = center + (u * cos(a_angle) + v * sin(a_angle)) * radius
		var world_b: Vector3 = center + (u * cos(b_angle) + v * sin(b_angle)) * radius
		if camera.is_position_behind(world_a) or camera.is_position_behind(world_b):
			continue
		var screen_a: Vector2 = camera.unproject_position(world_a)
		var screen_b: Vector2 = camera.unproject_position(world_b)
		var segment: Vector2 = screen_b - screen_a
		var length_sq: float = segment.length_squared()
		if length_sq < 0.0001:
			continue
		var t: float = clampf((screen_pos - screen_a).dot(segment) / length_sq, 0.0, 1.0)
		var closest: Vector2 = screen_a + segment * t
		var distance: float = screen_pos.distance_to(closest)
		if distance > max_distance:
			continue
		var param: float = fposmod(lerpf(a_angle, b_angle, t), TAU)
		var score: float = distance
		if use_preferred:
			score += absf(wrapf(param - preferred_param, -PI, PI)) * 12.0
		if score < best_score:
			best_score = score
			best = {"distance": distance, "param": param, "center": center, "axis": axis}
	return best


func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var best: Dictionary = {}
	var best_distance: float = WORLD_GIZMO_PICK_PX_035
	for name_value in ["X", "Y", "Z"]:
		var axis: Vector3 = _world_axis_v035(name_value)
		var plus_valid: bool = bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid: bool = bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		if not plus_valid and not minus_valid:
			continue
		var pick: Dictionary = _ring_param_pick_v036(axis, screen_pos, best_distance)
		if pick.is_empty():
			continue
		var distance: float = float(pick.get("distance", best_distance))
		if distance <= best_distance:
			best_distance = distance
			best = {"name": name_value, "axis": axis, "center": pick.get("center", _gizmo_anchor_v030), "param": pick.get("param", 0.0)}
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
	gizmo_drag_axis_v030 = picked.get("axis", Vector3.ZERO) as Vector3
	gizmo_drag_axis_name_v030 = str(picked.get("name", ""))
	gizmo_drag_center_v030 = picked.get("center", _gizmo_anchor_v030()) as Vector3
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = context.get("component", []) as Array
	gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
	gizmo_drag_last_param_v036 = float(picked.get("param", 0.0))
	gizmo_drag_accum_angle_v036 = 0.0
	_build_rotation_ghost_v030(gizmo_drag_component_v030)
	_status("WORLD %s ring selected — drag around the ring; rotation snaps to exact 45° states" % gizmo_drag_axis_name_v030)
	return true


func _update_gizmo_drag_v030(screen_pos: Vector2) -> void:
	if not gizmo_drag_active_v030:
		return
	var pick: Dictionary = _ring_param_pick_v036(gizmo_drag_axis_v030, screen_pos, GIZMO_UPDATE_RADIUS_036, gizmo_drag_last_param_v036, true)
	if pick.is_empty():
		return
	var param: float = float(pick.get("param", gizmo_drag_last_param_v036))
	var delta_angle: float = wrapf(param - gizmo_drag_last_param_v036, -PI, PI)
	gizmo_drag_last_param_v036 = param
	gizmo_drag_accum_angle_v036 += delta_angle
	var steps: int = clampi(int(round(gizmo_drag_accum_angle_v036 / GIZMO_STEP_030)), -7, 7)
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
	gizmo_drag_accum_angle_v036 = 0.0
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
		var axis: Vector3 = _world_axis_v035(name_value)
		var plus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		if is_instance_valid(ring):
			ring.material_override = base_material if plus_valid or minus_valid else gizmo_disabled_mat_v030
		if is_instance_valid(plus_label):
			plus_label.modulate = base_material.albedo_color if plus_valid else gizmo_disabled_mat_v030.albedo_color
		if is_instance_valid(minus_label):
			minus_label.modulate = base_material.albedo_color if minus_valid else gizmo_disabled_mat_v030.albedo_color


# -----------------------------------------------------------------------------
# Reset Placement Rotation. The old reset stored an absolute world-space basis at
# creation time, so moving/rolling an assembly made that basis stale. Rebuild the
# canonical orientation from the CURRENT mount geometry instead.
# -----------------------------------------------------------------------------

func _reset_preview_v020() -> Dictionary:
	if simulating or _selected_kind() != "connector" or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a connector"}
	_rebuild_connection_graph_v020()
	var connector: RigidBody3D = selected_piece
	var current: Transform3D = connector.global_transform
	var pivot: Dictionary = _primary_record_for_connector_v020(connector)
	var excluded_uid: int = int(pivot.get("uid", -1)) if not pivot.is_empty() and _fixed_connection_kind_v020(str(pivot.get("kind", ""))) else -1
	var component: Array = _fixed_component_v020(connector, excluded_uid)
	if not pivot.is_empty() and excluded_uid >= 0:
		var pivot_other: RigidBody3D = _other_body_v020(pivot, connector)
		if _component_has_piece_v020(component, pivot_other):
			return {"valid": false, "reason": "this mount is part of a closed rigid loop"}

	var target: Transform3D = current
	if pivot.is_empty():
		var home_basis: Basis = connector.get_meta("rotation_home_basis_v020", connector.get_meta("rotation_home_basis", current.basis)) as Basis
		target = Transform3D(home_basis.orthonormalized(), current.origin)
	else:
		var kind: String = str(pivot.get("kind", ""))
		var rod: RigidBody3D = pivot.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			return {"valid": false, "reason": "mount rod is missing"}
		var rod_axis: Vector3 = _rod_axis_v020(rod)
		if kind == "socket":
			var slot: int = int(pivot.get("slot", -1))
			var rod_end: int = int(pivot.get("rod_end", 0))
			var outward: Vector3 = rod_axis * float(rod_end)
			var desired_socket_dir: Vector3 = -outward
			var socket_basis: Basis = _basis_align_direction_v020(_slot_dir(slot), desired_socket_dir, Vector3.UP)
			var socket_anchor: Vector3 = _record_anchor_v020(pivot)
			var socket_origin: Vector3 = socket_anchor - (socket_basis * _slot_dir(slot)).normalized() * CONNECTOR_D
			target = Transform3D(socket_basis, socket_origin)
		elif kind == "cross":
			var cross_slot: int = int(pivot.get("slot", -1))
			var radial: Vector3 = _world_perpendicular_v035(rod_axis)
			var cross_basis: Basis = _basis_for_cross_v020(_slot_dir(cross_slot), rod_axis, radial)
			var cross_anchor: Vector3 = _record_anchor_v020(pivot)
			var actual_radial: Vector3 = (cross_basis * _slot_dir(cross_slot)).normalized()
			target = Transform3D(cross_basis, cross_anchor - actual_radial * CONNECTOR_D)
		elif kind == "axle":
			var axle_basis: Basis = _basis_for_axle_v020(rod_axis)
			var axial: float = (current.origin - rod.global_position).dot(rod_axis)
			var axle_origin: Vector3 = rod.global_position + rod_axis * axial
			target = Transform3D(axle_basis, axle_origin)
		else:
			var fallback_home: Basis = connector.get_meta("rotation_home_basis_v020", current.basis) as Basis
			target = Transform3D(fallback_home.orthonormalized(), current.origin)

	var transforms: Dictionary = _rigid_delta_map_v020(component, current, target)
	var validation: Dictionary = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return validation
	return {"valid": true, "transforms": transforms, "component": component, "pivot": pivot}


# -----------------------------------------------------------------------------
# Version/help/updater awareness.
# -----------------------------------------------------------------------------

func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	if mode_hint_v032 == null:
		return
	match editor_mode_v032:
		EDITOR_ROTATE_032:
			mode_hint_v032.text = "World XYZ rings • continuous projected-ring drag • exact 45° snap"
		EDITOR_ATTACH_032:
			match attach_mode:
				0:
					mode_hint_v032.text = "SOCKET: rod end ↔ connector socket"
				1:
					mode_hint_v032.text = "AXLE: hub ↔ exact rod shaft point"
				2:
					mode_hint_v032.text = "CROSS: side socket ↔ rod perpendicular to connector face"


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCREATE: connector orientation is deterministic in world space.\n\nROTATE: the selected-piece X/Y/Z rings are true WORLD axes. Dragging now follows the projected ring parameter continuously instead of integrating a screen tangent, then snaps the candidate to exact 45° states. Move and Rotate are a strict one-open-at-a-time accordion. Reset Placement Rotation reconstructs the default from the connector's CURRENT socket/cross/axle mount, so previous Roll steps are actually removed.\n\nATTACH: point selection stays live as pieces move. SOCKET exposes rod ends + sockets only. AXLE uses hub ↔ exact rod-shaft point. CROSS uses side socket ↔ exact rod-shaft point. Picking uses larger projected targets plus a physical ray fallback when parts overlap. The selected source stays selected until a valid target succeeds or you explicitly deselect it.\n\nTRUE CROSS GEOMETRY: a CROSS rod is perpendicular to the connector's flat face (parallel to its axle axis), but passes through a side clamp instead of the center hub.\n\nCamera: one finger orbit, two fingers pan/zoom. Camera orientation never defines construction or rotation axes." % VERSION_036


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
	if _compare_versions_v021(latest, VERSION_036) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_036)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_036, latest])
