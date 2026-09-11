extends "res://scripts/main_v074.gd"

const VERSION_075 := "0.5.19"
const ATTACH_PICK_RADIUS_V075 := 22.0
const ATTACH_BODY_PORT_RADIUS_V075 := 30.0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_075)
	_status("v0.5.19 ready — precise ATTACH picking, undo/redo point refresh, and spatial CROSS orientation fixes are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_075, text]


# -----------------------------------------------------------------------------
# ATTACH picking
#
# v0.3.10/v0.5.15 intentionally enlarged connector-port hit regions so crowded
# sockets were easy to hit. On dense constructions this became too aggressive:
# a nearby socket could win even when the user was clearly tapping a rod. Keep
# the visible markers, but make the click target tight and body-aware.
# -----------------------------------------------------------------------------

func _rod_body_from_hit_v075(hit: Dictionary) -> Dictionary:
	if hit.is_empty():
		return {}
	var rod := hit.get("collider") as RigidBody3D
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		return {}
	var axis: Vector3 = _rod_axis_v020(rod)
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.38)
	var hit_point: Vector3 = hit.get("position", rod.global_position) as Vector3
	var along: float = clampf((hit_point - rod.global_position).dot(axis), -half_len, half_len)
	return {"type": "rod_body", "body": rod, "along": along, "point": rod.global_position + axis * along}


func _attach_points_on_body_v075(body: RigidBody3D, allowed_types: Array = []) -> Array:
	var result: Array = []
	if not is_instance_valid(body):
		return result
	for point_value in _all_attach_points_v032():
		var point := point_value as Dictionary
		if point.get("body") != body:
			continue
		if not allowed_types.is_empty() and not (str(point.get("type", "")) in allowed_types):
			continue
		result.append(point)
	return result


func _selected_point_hit_v035(screen_pos: Vector2) -> bool:
	if attach_point_selected_v032.is_empty():
		return false
	var point: Vector3 = attach_point_selected_v032.get("point", Vector3.ZERO) as Vector3
	if camera.is_position_behind(point):
		return false
	return camera.unproject_position(point).distance_to(screen_pos) <= ATTACH_PICK_RADIUS_V075


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	var hit: Dictionary = _raycast_piece(screen_pos)
	if not hit.is_empty():
		var hit_body := hit.get("collider") as RigidBody3D
		if is_instance_valid(hit_body):
			var hit_kind: String = str(hit_body.get_meta("kind", ""))
			# In AXLE/CROSS, an actual rod hit always wins over nearby projected
			# connector markers. This is the key crowded-build behavior change.
			if hit_kind == "rod" and attach_mode in [1, 2]:
				return _rod_body_from_hit_v075(hit)
			var body_points: Array = _attach_points_on_body_v075(hit_body)
			var on_body: Dictionary = _nearest_projected_candidate_v030(body_points, screen_pos, ATTACH_PICK_RADIUS_V075)
			if not on_body.is_empty() and _allowed_initial_point_v035(on_body):
				return on_body

	# Marker-only fallback remains available, but no longer has the old 72/108 px
	# connector capture radius.
	var discrete: Dictionary = _nearest_projected_candidate_v030(_all_attach_points_v032(), screen_pos, ATTACH_PICK_RADIUS_V075)
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
		# Exact shaft picking already walks past connector colliders and returns the
		# actual point touched on the rod.
		return _rod_body_from_screen_v035(screen_pos, source.get("body") as RigidBody3D)

	var candidates: Array = _eligible_discrete_targets_v040(source)
	if candidates.is_empty():
		return {}

	# If a physical counterpart body was tapped, only consider ports on that body.
	# This prevents a neighboring connector from stealing the target.
	var hit: Dictionary = _raycast_piece(screen_pos)
	if not hit.is_empty():
		var hit_body := hit.get("collider") as RigidBody3D
		if is_instance_valid(hit_body) and hit_body != source.get("body"):
			var body_candidates: Array = []
			for candidate_value in candidates:
				var candidate := candidate_value as Dictionary
				if candidate.get("body") == hit_body:
					body_candidates.append(candidate)
			var physical: Dictionary = _nearest_projected_candidate_v030(body_candidates, screen_pos, ATTACH_BODY_PORT_RADIUS_V075)
			if not physical.is_empty():
				return physical

	return _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PICK_RADIUS_V075)


# -----------------------------------------------------------------------------
# Attachment-point overlay refresh after state restoration.
#
# Undo/Redo restores body transforms from a snapshot. The v0.5 spatial overlay
# cache could remain clean for one more frame, leaving the green/orange markers
# at the pre-Undo coordinates until another UI action dirtied the cache.
# -----------------------------------------------------------------------------

func _invalidate_attach_overlay_v075() -> void:
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	last_overlay_visibility_signature_v050 = ""
	if attach_points_root_v032 != null:
		_refresh_attach_points_v032()


func _restore_state(snapshot: Dictionary) -> void:
	super._restore_state(snapshot)
	_invalidate_attach_overlay_v075()
	call_deferred("_invalidate_attach_overlay_v075")


func _undo() -> void:
	super._undo()
	_invalidate_attach_overlay_v075()
	call_deferred("_invalidate_attach_overlay_v075")


func _redo() -> void:
	super._redo()
	_invalidate_attach_overlay_v075()
	call_deferred("_invalidate_attach_overlay_v075")


# -----------------------------------------------------------------------------
# CROSS orientation for 11/14-point spatial sockets.
#
# The ordinary ring is in connector-local X/Z, so a CROSS rod runs on local Y
# (normal to that ring). The added upper/lower half-rings are in local X/Y, so
# their CROSS rod must run on local Z — horizontal relative to those half-rings.
# Treat every socket according to the plane that socket actually belongs to.
# -----------------------------------------------------------------------------

func _cross_socket_local_normal_v075(slot: int) -> Vector3:
	return Vector3.BACK if _is_spatial_slot_v041(slot) else Vector3.UP


func _cross_socket_world_normal_v075(connector: RigidBody3D, slot: int, transform_override: Transform3D = Transform3D.IDENTITY, use_override: bool = false) -> Vector3:
	if not is_instance_valid(connector):
		return Vector3.UP
	var tf: Transform3D = transform_override if use_override else connector.global_transform
	return (tf.basis * _cross_socket_local_normal_v075(slot)).normalized()


func _cross_rod_axis_for_socket_v074(connector: RigidBody3D, slot: int) -> Vector3:
	return _cross_socket_world_normal_v075(connector, slot)


func _basis_for_cross_v020(local_slot: Vector3, host_axis: Vector3, radial: Vector3) -> Basis:
	var host_n: Vector3 = host_axis.normalized()
	var local_slot_n: Vector3 = local_slot.normalized()
	var local_normal: Vector3 = Vector3.BACK if absf(local_slot_n.y) > 0.01 else Vector3.UP
	var radial_n: Vector3 = radial - host_n * radial.dot(host_n)
	if radial_n.length_squared() < 0.02:
		radial_n = _world_perpendicular_v035(host_n)
	radial_n = radial_n.normalized()
	var base: Basis = Basis(Quaternion(local_slot_n, radial_n))
	var current_normal: Vector3 = (base * local_normal).normalized()
	var angle: float = current_normal.signed_angle_to(host_n, radial_n)
	return (Basis(radial_n, angle) * base).orthonormalized()


func _measure_connection_rest_v020(joint: Joint3D, kind: String, connector: RigidBody3D, rod: RigidBody3D, slot: int, rod_end: int, host_along: float, ring: RigidBody3D) -> void:
	var had_rest: bool = joint.has_meta("rest_gap_v020") if is_instance_valid(joint) else true
	super._measure_connection_rest_v020(joint, kind, connector, rod, slot, rod_end, host_along, ring)
	if had_rest or kind != "cross" or not is_instance_valid(joint) or not is_instance_valid(connector) or not is_instance_valid(rod) or slot < 0:
		return
	var cross_normal: Vector3 = _cross_socket_world_normal_v075(connector, slot)
	joint.set_meta("rest_plane_v020", absf(cross_normal.dot(_rod_axis_v020(rod))))


func _validate_record_v020(record: Dictionary, transforms: Dictionary) -> Dictionary:
	if str(record.get("kind", "")) != "cross":
		return super._validate_record_v020(record, transforms)
	var connector := record.get("connector") as RigidBody3D
	var rod := record.get("rod") as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return {"valid": false, "reason": "missing cross body"}
	var slot: int = int(record.get("slot", -1))
	if slot < 0:
		return {"valid": false, "reason": "missing cross socket"}
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
	var socket_normal: Vector3 = _cross_socket_world_normal_v075(connector, slot, connector_tf, true)
	var rest_normal_align: float = float(record.get("rest_plane", 1.0))
	var normal_limit: float = minf(0.99, maxf(CROSS_NORMAL_ALIGN_036, rest_normal_align - 0.01))
	if absf(socket_normal.dot(rod_axis)) < normal_limit:
		return {"valid": false, "reason": "the CROSS rod must stay perpendicular to that socket's connector plane"}
	return {"valid": true}


func _current_attach_geometry_v030(source: Dictionary, target: Dictionary) -> Dictionary:
	var source_type: String = str(source.get("type", ""))
	var target_type: String = str(target.get("type", ""))
	if attach_mode == 2 and ((source_type == "socket" and target_type == "rod_body") or (source_type == "rod_body" and target_type == "socket")):
		var socket_point: Dictionary = source if source_type == "socket" else target
		var rod_point: Dictionary = target if source_type == "socket" else source
		var connector := socket_point.get("body") as RigidBody3D
		var rod := rod_point.get("body") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			return {"valid": false}
		var slot: int = int(socket_point.get("slot", -1))
		var socket: Dictionary = _socket_world_v020(connector, slot)
		var rod_axis: Vector3 = _rod_axis_v020(rod)
		var socket_normal: Vector3 = _cross_socket_world_normal_v075(connector, slot)
		return {
			"valid": (socket.get("point", connector.global_position) as Vector3).distance_to(rod_point.get("point", rod.global_position) as Vector3) <= ATTACH_CROSS_GAP_030 \
				and absf((socket.get("dir", Vector3.RIGHT) as Vector3).dot(rod_axis)) <= CROSS_SOCKET_PERP_036 \
				and absf(socket_normal.dot(rod_axis)) >= CROSS_NORMAL_ALIGN_036
		}
	return super._current_attach_geometry_v030(source, target)


func _snap_source_component_v030(source: Dictionary, target: Dictionary, component: Array) -> Dictionary:
	var source_type: String = str(source.get("type", ""))
	var target_type: String = str(target.get("type", ""))
	if attach_mode == 2 and source_type == "rod_body" and target_type == "socket":
		var cross_rod := source.get("body") as RigidBody3D
		var target_connector := target.get("body") as RigidBody3D
		if not is_instance_valid(cross_rod) or not is_instance_valid(target_connector):
			return {"valid": false, "reason": "missing CROSS piece"}
		var target_slot: int = int(target.get("slot", -1))
		var desired_rod_axis: Vector3 = _cross_socket_world_normal_v075(target_connector, target_slot)
		var current_rod_axis: Vector3 = _rod_axis_v020(cross_rod)
		if desired_rod_axis.dot(current_rod_axis) < 0.0:
			desired_rod_axis = -desired_rod_axis
		var rod_rotate: Basis = Basis(Quaternion(current_rod_axis, desired_rod_axis))
		var rod_basis: Basis = (rod_rotate * cross_rod.global_transform.basis).orthonormalized()
		var target_socket: Dictionary = _socket_world_v020(target_connector, target_slot)
		var rod_origin: Vector3 = (target_socket.get("point", cross_rod.global_position) as Vector3) - desired_rod_axis * float(source.get("along", 0.0))
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, cross_rod.global_transform, Transform3D(rod_basis, rod_origin))}
	return super._snap_source_component_v030(source, target, component)


func _auto_connect_crosses_v020() -> int:
	var count: int = 0
	for body_value in bodies:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size():
			continue
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
			if occupied.has(slot):
				continue
			var socket: Dictionary = _socket_world_v020(connector, slot)
			var mouth: Vector3 = socket.get("point", connector.global_position) as Vector3
			var slot_dir: Vector3 = socket.get("dir", Vector3.RIGHT) as Vector3
			var socket_normal: Vector3 = _cross_socket_world_normal_v075(connector, slot)
			var best_rod: RigidBody3D = null
			var best_along: float = 0.0
			var best_distance: float = CROSS_CAPTURE_V020
			for rod_value in bodies:
				var rod := rod_value as RigidBody3D
				if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
					continue
				if _fixed_pair_exists_v020(rod, connector):
					continue
				var rod_axis: Vector3 = _rod_axis_v020(rod)
				if absf(slot_dir.dot(rod_axis)) > CROSS_SOCKET_PERP_036:
					continue
				if absf(socket_normal.dot(rod_axis)) < CROSS_NORMAL_ALIGN_036:
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
