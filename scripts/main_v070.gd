extends "res://scripts/main_v069.gd"

const VERSION_070 := "0.5.15"
const SOCKET_JAW_PICK_RADIUS_V070 := 108.0
const SOCKET_JAW_INNER_V070 := 0.68
const SOCKET_JAW_OUTER_V070 := 1.58
const FREE_CREATE_GRID_V070 := 0.50
const FREE_CREATE_MIN_Y_V070 := 0.72
const AXLE_CONNECTOR_HALF_V070 := 0.28
const O_RING_AXLE_CLEARANCE_V070 := 0.38
const AXLE_STOP_EPS_V070 := 0.002

var new_free_rod_button_v070: Button
var new_free_connector_button_v070: Button
var free_create_kind_v070: String = ""
var axle_stop_ranges_v070: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_070)
	_status("v0.5.15 ready — deterministic O-Ring/rod-end axle stops, full 11/14-point picking, CROSS socket creation, free-part placement and socket re-seat.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_070, text]


# -----------------------------------------------------------------------------
# CREATE: explicit free-part placement.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	if mode_panel_v032 == null:
		return
	var mode_box: VBoxContainer = _find_first_vbox_v050(mode_panel_v032)
	if mode_box == null:
		return
	var free_row := HBoxContainer.new()
	free_row.name = "FreeCreateRowV070"
	free_row.add_theme_constant_override("separation", 5)
	new_free_rod_button_v070 = _ui_button("New Rod", func() -> void: _arm_free_create_v070("rod"), true)
	new_free_connector_button_v070 = _ui_button("New Connector", func() -> void: _arm_free_create_v070("connector"), true)
	new_free_rod_button_v070.custom_minimum_size = Vector2(94.0, 43.0)
	new_free_connector_button_v070.custom_minimum_size = Vector2(94.0, 43.0)
	new_free_rod_button_v070.add_theme_font_size_override("font_size", 13)
	new_free_connector_button_v070.add_theme_font_size_override("font_size", 13)
	free_row.add_child(new_free_rod_button_v070)
	free_row.add_child(new_free_connector_button_v070)
	mode_box.add_child(free_row)
	if disconnect_button_v042 != null:
		mode_box.move_child(free_row, disconnect_button_v042.get_index())
	mode_panel_v032.offset_bottom = maxf(mode_panel_v032.offset_bottom, 604.0)


func _arm_free_create_v070(kind_value: String) -> void:
	if simulating or editor_mode_v032 != EDITOR_CREATE_032:
		_status("New free parts are placed from CREATE mode")
		return
	if kind_value == "connector" and selected_connector_type == o_ring_index:
		_status("O-Ring Stop must be placed on a rod; choose a normal connector for free placement")
		return
	free_create_kind_v070 = "" if free_create_kind_v070 == kind_value else kind_value
	_deselect_attach_point_v032(false)
	_cancel_editor_tools_v030(false)
	if not free_create_kind_v070.is_empty():
		_set_selected(null)
		_refresh_selection_highlight()
	_update_ui()
	if free_create_kind_v070 == "rod":
		_status("New Rod armed — tap empty workspace to place the selected rod as a free part")
	elif free_create_kind_v070 == "connector":
		_status("New Connector armed — tap empty workspace to place the selected connector as a free part")
	else:
		_status("Free-part placement cancelled")


func _free_create_world_point_v070(screen_pos: Vector2) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var plane_y: float = maxf(FREE_CREATE_MIN_Y_V070, camera_target.y)
	if absf(direction.y) < 0.0005:
		return {}
	var distance: float = (plane_y - origin.y) / direction.y
	if distance <= 0.0:
		return {}
	var point: Vector3 = origin + direction * distance
	point.x = roundf(point.x / FREE_CREATE_GRID_V070) * FREE_CREATE_GRID_V070
	point.z = roundf(point.z / FREE_CREATE_GRID_V070) * FREE_CREATE_GRID_V070
	point.y = plane_y
	return {"point": point, "distance": distance}


func _finish_new_free_piece_v070(piece: RigidBody3D) -> void:
	if not is_instance_valid(piece):
		return
	_ensure_piece_uid_v020(piece)
	piece.set_meta("build_transform", piece.global_transform)
	if str(piece.get_meta("kind", "")) == "connector":
		piece.set_meta("root_piece_v020", true)
		piece.set_meta("primary_connection_uid_v020", -1)
		piece.set_meta("rotation_home_basis_v020", piece.global_transform.basis)
		piece.set_meta("rotation_home_basis", piece.global_transform.basis)
		piece.set_meta("rotation_home_transform", piece.global_transform)
	_set_selected(piece)
	free_create_kind_v070 = ""
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_refresh_parts_browser_v050()
	_update_ui()


func _place_free_part_v070(screen_pos: Vector2) -> bool:
	if free_create_kind_v070.is_empty() or editor_mode_v032 != EDITOR_CREATE_032 or simulating:
		return false
	if not _raycast_piece(screen_pos).is_empty():
		_status("Free-part placement is armed — tap empty workspace, not an existing piece")
		return true
	var hit: Dictionary = _free_create_world_point_v070(screen_pos)
	if hit.is_empty():
		_status("Could not place there — tap empty workspace inside the build plane")
		return true
	var point: Vector3 = hit.get("point", camera_target) as Vector3
	if free_create_kind_v070 == "connector":
		if selected_connector_type == o_ring_index:
			free_create_kind_v070 = ""
			_update_ui()
			_status("O-Ring Stop must be placed on a rod")
			return true
		var connector := _make_connector(selected_connector_type, Transform3D(Basis.IDENTITY, point)) as RigidBody3D
		_finish_new_free_piece_v070(connector)
		_status("Created free %s" % _piece_display_name(connector))
		return true
	if free_create_kind_v070 == "rod":
		var length: float = float(rod_defs[selected_rod_type].get("actual_mm", 55.0)) / 10.0
		var half: Vector3 = Vector3.RIGHT * (length * 0.5)
		var rod := _make_rod(selected_rod_type, point - half, point + half) as RigidBody3D
		_finish_new_free_piece_v070(rod)
		_status("Created free %s" % _piece_display_name(rod))
		return true
	free_create_kind_v070 = ""
	return false


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	if mode_value != EDITOR_CREATE_032:
		free_create_kind_v070 = ""
	super._set_editor_mode_v032(mode_value, report)
	_update_free_create_ui_v070()


func _update_free_create_ui_v070() -> void:
	var enabled: bool = not simulating and editor_mode_v032 == EDITOR_CREATE_032
	if new_free_rod_button_v070 != null:
		new_free_rod_button_v070.disabled = not enabled
		new_free_rod_button_v070.text = "● New Rod" if free_create_kind_v070 == "rod" else "New Rod"
	if new_free_connector_button_v070 != null:
		new_free_connector_button_v070.disabled = not enabled or selected_connector_type == o_ring_index
		new_free_connector_button_v070.text = "● New Connector" if free_create_kind_v070 == "connector" else "New Connector"


func _update_ui() -> void:
	super._update_ui()
	_update_free_create_ui_v070()


# -----------------------------------------------------------------------------
# Socket picking: use the whole visible jaw, not one projected mouth point.
# This is especially important for the eight planar sockets on 11/14-point parts.
# -----------------------------------------------------------------------------

func _screen_segment_distance_v070(screen_pos: Vector2, world_a: Vector3, world_b: Vector3) -> float:
	if camera.is_position_behind(world_a) and camera.is_position_behind(world_b):
		return INF
	var a: Vector2 = camera.unproject_position(world_a)
	var b: Vector2 = camera.unproject_position(world_b)
	var ab: Vector2 = b - a
	if ab.length_squared() < 0.001:
		return screen_pos.distance_to(a)
	var t: float = clampf((screen_pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return screen_pos.distance_to(a + ab * t)


func _pick_socket_on_connector_v070(connector: RigidBody3D, screen_pos: Vector2, max_distance: float = SOCKET_JAW_PICK_RADIUS_V070, free_only: bool = false, source: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(connector):
		return {}
	_rebuild_connection_graph_v020()
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return {}
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	var best: Dictionary = {}
	var best_distance: float = max_distance
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		if free_only and occupied.has(slot):
			continue
		var world_dir: Vector3 = (connector.global_transform.basis * _slot_dir(slot)).normalized()
		var world_a: Vector3 = connector.global_position + world_dir * SOCKET_JAW_INNER_V070
		var world_b: Vector3 = connector.global_position + world_dir * SOCKET_JAW_OUTER_V070
		var distance: float = _screen_segment_distance_v070(screen_pos, world_a, world_b)
		if distance > best_distance:
			continue
		var socket: Dictionary = _socket_world_v020(connector, slot)
		var candidate := {"type": "socket", "body": connector, "slot": slot, "point": socket.get("point", connector.global_position)}
		if not source.is_empty() and not _attach_target_is_available_v040(source, candidate):
			continue
		best_distance = distance
		best = candidate
		best["pick_distance_v070"] = distance
	return best


func _raycast_connector_v070(screen_pos: Vector2, exclude_body: RigidBody3D = null) -> RigidBody3D:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var excluded: Array = []
	if is_instance_valid(exclude_body):
		excluded.append(exclude_body.get_rid())
	for _pass in range(10):
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 900.0)
		query.collision_mask = 2 | 4
		query.exclude = excluded
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return null
		var body := hit.get("collider") as RigidBody3D
		if not is_instance_valid(body):
			return null
		if str(body.get_meta("kind", "")) == "connector":
			return body
		excluded.append(body.get_rid())
	return null


func _nearest_free_socket_on_body_v054(connector: RigidBody3D, screen_pos: Vector2, max_distance: float) -> Dictionary:
	return _pick_socket_on_connector_v070(connector, screen_pos, maxf(max_distance, SOCKET_JAW_PICK_RADIUS_V070), true)


func _physical_discrete_point_v036(screen_pos: Vector2, expected_types: Array, exclude_body: RigidBody3D = null) -> Dictionary:
	if "socket" in expected_types:
		var connector: RigidBody3D = _raycast_connector_v070(screen_pos, exclude_body)
		if is_instance_valid(connector):
			var source: Dictionary = attach_point_selected_v032 if not attach_point_selected_v032.is_empty() else {}
			var socket: Dictionary = _pick_socket_on_connector_v070(connector, screen_pos, SOCKET_JAW_PICK_RADIUS_V070, false, source)
			if not socket.is_empty():
				return socket
	return super._physical_discrete_point_v036(screen_pos, expected_types, exclude_body)


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	if attach_mode in [0, 2]:
		var connector: RigidBody3D = _raycast_connector_v070(screen_pos)
		if is_instance_valid(connector):
			var socket: Dictionary = _pick_socket_on_connector_v070(connector, screen_pos)
			if not socket.is_empty():
				return socket
	return super._pick_initial_attach_point_v035(screen_pos)


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	var expected: Array = _expected_target_types_v035(str(source.get("type", "")))
	if "socket" in expected:
		var source_body := source.get("body") as RigidBody3D
		var connector: RigidBody3D = _raycast_connector_v070(screen_pos, source_body)
		if is_instance_valid(connector):
			var socket: Dictionary = _pick_socket_on_connector_v070(connector, screen_pos, SOCKET_JAW_PICK_RADIUS_V070, false, source)
			if not socket.is_empty():
				return socket
	return super._pick_attach_target_v035(screen_pos, source)


# -----------------------------------------------------------------------------
# CREATE + CROSS: a connector socket can still grow a rod directly. Tapping a
# rod body retains normal CROSS connector placement.
# -----------------------------------------------------------------------------

func _try_socket_create_tap_v054(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_CREATE_032 or simulating:
		return false
	if attach_mode == 0:
		return super._try_socket_create_tap_v054(screen_pos)
	if attach_mode != 2:
		return false
	var connector: RigidBody3D = _raycast_connector_v070(screen_pos)
	if not is_instance_valid(connector):
		return false
	var candidate: Dictionary = _pick_socket_on_connector_v070(connector, screen_pos, SOCKET_JAW_PICK_RADIUS_V070, true)
	if candidate.is_empty():
		return false
	_extend_socket(connector, int(candidate.get("slot", -1)))
	_status("CROSS mode — rod created from connector socket; tap a rod body to place a cross connector")
	return true


# -----------------------------------------------------------------------------
# ATTACH: selecting a connector socket and then one of its currently attached
# rods means "move this mount to the selected socket". The connector side is
# rotated/re-seated around the existing rod anchor; the target rod is not dragged.
# -----------------------------------------------------------------------------

func _slot_label_v070(slot: int) -> String:
	match slot:
		1001: return "upper-right"
		1002: return "top"
		1003: return "upper-left"
		2001: return "lower-right"
		2002: return "bottom"
		2003: return "lower-left"
	return "%d°" % slot


func _reseat_record_preview_v070(connector: RigidBody3D, record: Dictionary, new_slot: int) -> Dictionary:
	if not is_instance_valid(connector) or record.is_empty():
		return {"valid": false, "reason": "missing connector mount"}
	var kind: String = str(record.get("kind", ""))
	if kind not in ["socket", "cross"] or record.get("connector") != connector:
		return {"valid": false, "reason": "that rod is not socket/cross-mounted to this connector"}
	var old_slot: int = int(record.get("slot", -1))
	if new_slot == old_slot:
		return {"valid": false, "reason": "that socket is already on this rod"}
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size() or not (new_slot in (connector_defs[def_index]["slots"] as Array)):
		return {"valid": false, "reason": "socket does not exist on this connector"}
	for other_value in _connections_for_piece_v020(connector):
		var other := other_value as Dictionary
		if int(other.get("uid", -1)) != int(record.get("uid", -2)) and int(other.get("slot", -1)) == new_slot:
			return {"valid": false, "reason": "selected socket is already occupied"}
	var rod := record.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return {"valid": false, "reason": "attached rod is missing"}
	var uid: int = int(record.get("uid", -1))
	var component: Array = _fixed_component_v020(connector, uid)
	if _component_has_piece_v020(component, rod):
		return {"valid": false, "reason": "another rigid path locks the connector to that rod"}
	var anchor: Vector3 = _record_anchor_v020(record)
	var desired_dir: Vector3
	if kind == "socket":
		desired_dir = -_rod_axis_v020(rod) * float(int(record.get("rod_end", 0)))
	else:
		desired_dir = (anchor - connector.global_position).normalized()
		if desired_dir.length_squared() < 0.5:
			desired_dir = (_socket_world_v020(connector, old_slot).get("dir", Vector3.RIGHT) as Vector3).normalized()
	if desired_dir.length_squared() < 0.5:
		return {"valid": false, "reason": "mount direction is undefined"}
	var current_new_dir: Vector3 = (_socket_world_v020(connector, new_slot).get("dir", Vector3.RIGHT) as Vector3).normalized()
	var rotate_basis: Basis = Basis(Quaternion(current_new_dir, desired_dir.normalized()))
	var target_basis: Basis = (rotate_basis * connector.global_transform.basis).orthonormalized()
	var target_origin: Vector3 = anchor - desired_dir.normalized() * CONNECTOR_D
	var target_tf := Transform3D(target_basis, target_origin)
	var transforms: Dictionary = _rigid_delta_map_v020(component, connector.global_transform, target_tf)
	var validation: Dictionary = _validate_transforms_with_slot_override_v030(transforms, uid, new_slot)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "other connections block this socket change"))}
	return {"valid": true, "transforms": transforms, "record": record, "old_slot": old_slot, "new_slot": new_slot}


func _apply_reseat_record_v070(connector: RigidBody3D, record: Dictionary, new_slot: int) -> bool:
	var preview: Dictionary = _reseat_record_preview_v070(connector, record, new_slot)
	if not bool(preview.get("valid", false)):
		_status("Socket re-seat blocked — %s" % str(preview.get("reason", "not valid")))
		return false
	var old_slot: int = int(preview.get("old_slot", -1))
	_apply_transforms_raw_v030(preview.get("transforms", {}) as Dictionary)
	var joint := record.get("joint") as Joint3D
	if is_instance_valid(joint):
		joint.set_meta("connector_slot_v020", new_slot)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_set_selected(connector)
	attach_point_selected_v032 = {}
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_update_ui()
	_status("Socket re-seated %s → %s without moving the target rod" % [_slot_label_v070(old_slot), _slot_label_v070(new_slot)])
	return true


func _pick_rod_body_for_reseat_v070(screen_pos: Vector2, connector: RigidBody3D) -> Dictionary:
	return _rod_body_from_screen_v035(screen_pos, connector)


func _try_socket_reseat_tap_v070(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_ATTACH_032 or attach_point_selected_v032.is_empty():
		return false
	if str(attach_point_selected_v032.get("type", "")) != "socket":
		return false
	var connector := attach_point_selected_v032.get("body") as RigidBody3D
	if not is_instance_valid(connector):
		return false
	var rod_hit: Dictionary = _pick_rod_body_for_reseat_v070(screen_pos, connector)
	if rod_hit.is_empty():
		return false
	var rod := rod_hit.get("body") as RigidBody3D
	if not is_instance_valid(rod):
		return false
	_rebuild_connection_graph_v020()
	var matches: Array = []
	for value in _records_between_bodies_v035(connector, rod):
		var record := value as Dictionary
		if str(record.get("kind", "")) in ["socket", "cross"]:
			matches.append(record)
	if matches.is_empty():
		return false
	var chosen: Dictionary = matches[0] as Dictionary
	if matches.size() > 1:
		var hit_point: Vector3 = rod_hit.get("point", rod.global_position) as Vector3
		var best_distance := INF
		for value in matches:
			var record := value as Dictionary
			var distance: float = _record_anchor_v020(record).distance_to(hit_point)
			if distance < best_distance:
				best_distance = distance
				chosen = record
	var new_slot: int = int(attach_point_selected_v032.get("slot", -1))
	var preview: Dictionary = _reseat_record_preview_v070(connector, chosen, new_slot)
	if not bool(preview.get("valid", false)):
		_status("Socket re-seat blocked — %s" % str(preview.get("reason", "not valid")))
		_refresh_attach_points_v032()
		return true
	_apply_reseat_record_v070(connector, chosen, new_slot)
	return true


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	if _try_socket_reseat_tap_v070(screen_pos):
		return
	super._handle_attach_point_tap_v032(screen_pos)


func _handle_tap(screen_pos: Vector2) -> void:
	if _place_free_part_v070(screen_pos):
		return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# SIMULATE: O-Rings are exact rod-local coordinates, not separately solved
# colliders. AXLE joints remain free. We enforce only the relative axial degree
# of freedom at O-Rings and physical rod ends, with mass-weighted correction of
# the two fixed components. This works whether the connector falls on the ring
# or the axle rod moves through the connector.
# -----------------------------------------------------------------------------

func _prepare_o_ring_followers_v068() -> int:
	_restore_o_ring_followers_v068(false)
	_restore_o_ring_connector_collision_state_v069()
	o_ring_proxy_shapes_v068.clear()
	o_ring_stop_proxies_v069.clear()
	o_ring_axle_replacements_v069.clear()
	o_ring_stop_pair_count_v069 = 0
	_rebuild_connection_graph_v020()
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "o_ring":
			continue
		var joint := record.get("joint") as Joint3D
		var ring := record.get("ring") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(joint) or not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		var local_transform: Transform3D = rod.global_transform.affine_inverse() * ring.global_transform
		o_ring_followers_v068.append({
			"ring": ring,
			"rod": rod,
			"joint": joint,
			"local_transform": local_transform,
			"collision_layer": ring.collision_layer,
			"collision_mask": ring.collision_mask,
			"continuous_cd": ring.continuous_cd,
			"freeze_mode": ring.freeze_mode,
			"can_sleep": ring.can_sleep,
			"original_parent": ring.get_parent(),
			"original_index": ring.get_index(),
		})
		_disable_o_ring_joint_v068(joint)
		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		ring.continuous_cd = false
		ring.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		ring.freeze = true
		ring.sleeping = false
		ring.can_sleep = false
		ring.collision_layer = 0
		ring.collision_mask = 0
		ring.global_transform = rod.global_transform * local_transform
		o_ring_stop_pair_count_v069 += 1
	if o_ring_stop_pair_count_v069 > 0:
		_rebind_all_joints()
	return o_ring_stop_pair_count_v069


func _rod_local_along_v070(body: Node3D, rod: RigidBody3D) -> float:
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	return (body.global_position - rod.global_position).dot(axis)


func _build_axle_stop_ranges_v070() -> void:
	axle_stop_ranges_v070.clear()
	_rebuild_connection_graph_v020()
	var rings_by_rod: Dictionary = {}
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		var key: int = rod.get_instance_id()
		var values: Array = rings_by_rod.get(key, []) as Array
		values.append(_rod_local_along_v070(ring, rod))
		rings_by_rod[key] = values
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var half_length: float = maxf(AXLE_CONNECTOR_HALF_V070, float(rod.get_meta("visual_length", 0.0)) * 0.5)
		var initial_along: float = _rod_local_along_v070(connector, rod)
		var lower: float = -half_length + AXLE_CONNECTOR_HALF_V070
		var upper: float = half_length - AXLE_CONNECTOR_HALF_V070
		var ring_values: Array = rings_by_rod.get(rod.get_instance_id(), []) as Array
		for value in ring_values:
			var ring_along: float = float(value)
			if ring_along < initial_along:
				lower = maxf(lower, ring_along + O_RING_AXLE_CLEARANCE_V070)
			elif ring_along > initial_along:
				upper = minf(upper, ring_along - O_RING_AXLE_CLEARANCE_V070)
			else:
				lower = maxf(lower, ring_along + O_RING_AXLE_CLEARANCE_V070)
		if lower > upper:
			var safe: float = clampf(initial_along, upper, lower)
			lower = safe
			upper = safe
		axle_stop_ranges_v070.append({
			"connector": connector,
			"rod": rod,
			"uid": int(record.get("uid", -1)),
			"lower": lower,
			"upper": upper,
			"ring_count": ring_values.size(),
		})


func _component_inverse_mass_v070(component: Array) -> float:
	var total_mass := 0.0
	var count := 0
	for body_value in component:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if body.freeze:
			return 0.0
		total_mass += maxf(0.001, body.mass)
		count += 1
	if count == 0 or total_mass <= 0.0:
		return 0.0
	return 1.0 / total_mass


func _components_overlap_v070(a: Array, b: Array) -> bool:
	var ids: Dictionary = {}
	for value in a:
		var body := value as RigidBody3D
		if is_instance_valid(body):
			ids[body.get_instance_id()] = true
	for value in b:
		var body := value as RigidBody3D
		if is_instance_valid(body) and ids.has(body.get_instance_id()):
			return true
	return false


func _translate_component_v070(component: Array, delta: Vector3) -> void:
	if delta.length_squared() < 0.0000001:
		return
	for value in component:
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		var transform := body.global_transform
		transform.origin += delta
		body.global_transform = transform
		body.sleeping = false


func _velocity_shift_component_v070(component: Array, delta_v: Vector3) -> void:
	if delta_v.length_squared() < 0.0000001:
		return
	for value in component:
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		body.linear_velocity += delta_v
		body.sleeping = false


func _apply_axle_stop_correction_v070(stop: Dictionary, target_along: float, current_along: float, lower_hit: bool) -> void:
	var connector := stop.get("connector") as RigidBody3D
	var rod := stop.get("rod") as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return
	var uid: int = int(stop.get("uid", -1))
	var connector_component: Array = _fixed_component_v020(connector, uid)
	var rod_component: Array = _fixed_component_v020(rod, uid)
	if connector_component.is_empty():
		connector_component = [connector]
	if rod_component.is_empty():
		rod_component = [rod]
	if _components_overlap_v070(connector_component, rod_component):
		return
	var inv_connector: float = _component_inverse_mass_v070(connector_component)
	var inv_rod: float = _component_inverse_mass_v070(rod_component)
	var total_inv: float = inv_connector + inv_rod
	if total_inv <= 0.000001:
		return
	var connector_weight: float = inv_connector / total_inv
	var rod_weight: float = inv_rod / total_inv
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var correction: float = target_along - current_along
	_translate_component_v070(connector_component, axis * correction * connector_weight)
	_translate_component_v070(rod_component, -axis * correction * rod_weight)

	var relative_speed: float = (connector.linear_velocity - rod.linear_velocity).dot(axis)
	var moving_through_stop: bool = relative_speed < 0.0 if lower_hit else relative_speed > 0.0
	if moving_through_stop:
		var cancel_relative: float = -relative_speed
		_velocity_shift_component_v070(connector_component, axis * cancel_relative * connector_weight)
		_velocity_shift_component_v070(rod_component, -axis * cancel_relative * rod_weight)


func _enforce_axle_stops_v070() -> void:
	if not simulating or axle_stop_ranges_v070.is_empty():
		return
	for _pass in range(3):
		var changed := false
		for value in axle_stop_ranges_v070:
			var stop := value as Dictionary
			var connector := stop.get("connector") as RigidBody3D
			var rod := stop.get("rod") as RigidBody3D
			if not is_instance_valid(connector) or not is_instance_valid(rod):
				continue
			var along: float = _rod_local_along_v070(connector, rod)
			var lower: float = float(stop.get("lower", -INF))
			var upper: float = float(stop.get("upper", INF))
			if along < lower - AXLE_STOP_EPS_V070:
				_apply_axle_stop_correction_v070(stop, lower, along, true)
				changed = true
			elif along > upper + AXLE_STOP_EPS_V070:
				_apply_axle_stop_correction_v070(stop, upper, along, false)
				changed = true
		if not changed:
			break


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	_build_axle_stop_ranges_v070()


func _sync_o_ring_followers_v068() -> void:
	super._sync_o_ring_followers_v068()
	_enforce_axle_stops_v070()
	# A correction can move the axle-side rigid component. Re-sync the visible
	# O-Ring immediately so it remains exact in the corrected rod-local pose.
	super._sync_o_ring_followers_v068()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_stop_ranges_v070.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_enforce_axle_stops_v070()
	_status("Physics running — %d O-Ring Stop%s follow host rod coordinates; %d AXLE pair%s have rod-end/O-Ring travel stops" % [
		o_ring_stop_pair_count_v069,
		"" if o_ring_stop_pair_count_v069 == 1 else "s",
		axle_stop_ranges_v070.size(),
		"" if axle_stop_ranges_v070.size() == 1 else "s"
	])


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.15 EDITOR / O-RING: O-Ring Stops are exact rod-local stops during SIMULATE, not independent solver bodies. Their BUILD weld is detached, the ring follows its rod exactly, and only the AXLE's relative slide is stopped at O-Rings and physical rod ends; axle rotation remains free. The correction is mass-weighted between the two rigid sides, so it also works when the rod moves through the connector. In CREATE, CROSS can grow a rod directly from a tapped connector socket. New Rod / New Connector arm one-tap placement in empty workspace. ATTACH uses the full visible socket jaws for touch picking, including all eight surrounding ports on 11/14-point 3D connectors. Selecting a connector socket and then a rod already attached to that connector re-seats the mount onto that socket when every other connection remains valid, without dragging the target rod."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_070) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_070)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
