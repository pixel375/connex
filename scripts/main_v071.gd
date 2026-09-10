extends "res://scripts/main_v070.gd"

const VERSION_071 := "0.5.16"
const SOCKET_PICK_TIE_PX_V071 := 0.50


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_071)
	_status("v0.5.16 ready — O-Ring Stops are simple hard-coded CROSS mounts with real collision.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_071, text]


# Keep v0.5.15's depth-aware socket picker. The O-Ring simplification must not
# regress the 11/14-point connector workflow fixes released alongside it.
func _pick_socket_on_connector_v070(connector: RigidBody3D, screen_pos: Vector2, max_distance: float = SOCKET_JAW_PICK_RADIUS_V070, free_only: bool = false, source: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(connector):
		return {}
	_rebuild_connection_graph_v020()
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return {}
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	var best: Dictionary = {}
	var best_distance: float = max_distance + 0.001
	var best_depth: float = INF
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		if free_only and occupied.has(slot):
			continue
		var world_dir: Vector3 = (connector.global_transform.basis * _slot_dir(slot)).normalized()
		var world_a: Vector3 = connector.global_position + world_dir * SOCKET_JAW_INNER_V070
		var world_b: Vector3 = connector.global_position + world_dir * SOCKET_JAW_OUTER_V070
		var distance: float = _screen_segment_distance_v070(screen_pos, world_a, world_b)
		if distance > max_distance:
			continue
		var socket: Dictionary = _socket_world_v020(connector, slot)
		var candidate := {"type": "socket", "body": connector, "slot": slot, "point": socket.get("point", connector.global_position)}
		if not source.is_empty() and not _attach_target_is_available_v040(source, candidate):
			continue
		var jaw_midpoint: Vector3 = (world_a + world_b) * 0.5
		var depth: float = camera.global_position.distance_to(jaw_midpoint)
		var better_screen: bool = distance < best_distance - SOCKET_PICK_TIE_PX_V071
		var screen_tie: bool = absf(distance - best_distance) <= SOCKET_PICK_TIE_PX_V071
		if not better_screen and not (screen_tie and depth < best_depth):
			continue
		best_distance = distance
		best_depth = depth
		best = candidate
		best["pick_distance_v070"] = distance
		best["pick_depth_v071"] = depth
	return best


# -----------------------------------------------------------------------------
# v0.5.16 O-Ring model
#
# An O-Ring is intentionally boring: it is a small round CROSS-only connector.
# It has no AXLE/socket topology of its own. It is fixed to the host rod using
# the same fixed-joint mechanism as a CROSS connector, keeps its real collider,
# and can be repositioned along that rod in BUILD. AXLE hubs remain ordinary
# free-slide/free-rotation AXLE joints and stop because they hit the O-Ring.
# -----------------------------------------------------------------------------

func _make_o_ring_body(transform: Transform3D) -> RigidBody3D:
	var ring := super._make_o_ring_body(transform) as RigidBody3D
	if not is_instance_valid(ring):
		return ring
	# Same construction collision policy used by normal connectors. The ring's
	# solid collision cylinder is the physical stopper; never replace it with a
	# rod-owned proxy or a coordinate clamp.
	ring.collision_layer = 2
	ring.collision_mask = 3
	ring.set_meta("o_ring_cross_only_v071", true)
	return ring


func _place_o_ring_on_rod(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		_status("O-Ring Stop — tap any rod")
		return

	var axis: Vector3 = _rod_axis_v020(rod)
	if axis.length_squared() < 0.5:
		axis = (rod.global_transform.basis * Vector3.UP).normalized()
	else:
		axis = axis.normalized()
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.40)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = _basis_for_axle_v020(axis)
	var ring: RigidBody3D = _make_o_ring_body(Transform3D(basis, center))
	if not is_instance_valid(ring):
		return

	# Same mechanical mount used by CROSS connectors: a real fixed joint between
	# two physical bodies. Keep kind=o_ring so the round part remains slotless and
	# cannot become an AXLE/socket connector itself.
	var joint := _make_fixed_joint(rod, ring, center) as Generic6DOFJoint3D
	_tag_connection_v020(joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	joint.set_meta("o_ring_cross_mount_v071", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("cross_mount", true)
	ring.set_meta("cross_host_rod", rod)
	ring.set_meta("o_ring_cross_only_v071", true)
	ring.set_meta("build_transform", ring.global_transform)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_set_selected(ring)
	_commit_state()
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_update_ui()
	_status("O-Ring Stop placed as a fixed CROSS mount — current SOCKET / AXLE / CROSS selection was ignored")


func _slide_selected_on_axle(amount: float) -> void:
	if not is_instance_valid(selected_piece) or str(selected_piece.get_meta("kind", "")) != "o_ring":
		super._slide_selected_on_axle(amount)
		return
	if simulating:
		_status("Return to BUILD before moving an O-Ring Stop")
		return
	var ring := selected_piece as RigidBody3D
	var rod := _find_o_ring_host(ring) as RigidBody3D
	if not is_instance_valid(rod):
		_status("O-Ring Stop has no host rod")
		return
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.40)
	var current_along: float = (ring.global_position - rod.global_position).dot(axis)
	var target_along: float = clampf(current_along + amount, -half_len, half_len)
	var delta: Vector3 = axis * (target_along - current_along)
	if delta.length_squared() < 0.0000001:
		_status("O-Ring Stop is already at the end of the rod")
		return

	var ring_tf: Transform3D = ring.global_transform
	ring_tf.origin += delta
	ring.global_transform = ring_tf
	ring.set_meta("build_transform", ring.global_transform)
	for joint_value in joints:
		var mount_joint := joint_value as Joint3D
		if not is_instance_valid(mount_joint):
			continue
		var nodes: Array = _joint_nodes(mount_joint)
		if nodes[0] == ring or nodes[1] == ring:
			var joint_tf: Transform3D = mount_joint.global_transform
			joint_tf.origin += delta
			mount_joint.global_transform = joint_tf
			if bool(mount_joint.get_meta("o_ring_mount", false)) or str(mount_joint.get_meta("connection_kind_v020", "")) == "o_ring":
				mount_joint.set_meta("host_along_v020", target_along)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_status("Moved O-Ring Stop along its CROSS-mounted rod")


# All follower/proxy/coordinate-stop machinery from v0.5.13-v0.5.15 is retired.
# These virtual overrides are deliberately no-ops so inherited preparation code
# cannot detach the O-Ring fixed joint or rewrite AXLE travel.
func _prepare_o_ring_followers_v068() -> int:
	_restore_o_ring_connector_collision_state_v069()
	o_ring_followers_v068.clear()
	o_ring_proxy_shapes_v068.clear()
	o_ring_stop_proxies_v069.clear()
	o_ring_axle_replacements_v069.clear()
	o_ring_stop_pair_count_v069 = 0
	axle_stop_ranges_v070.clear()
	return 0


func _build_axle_stop_ranges_v070() -> void:
	axle_stop_ranges_v070.clear()


func _enforce_axle_stops_v070() -> void:
	pass


func _sync_o_ring_followers_v068() -> void:
	pass


func _restore_o_ring_followers_v068(_restore_build_pose: bool = true) -> void:
	_restore_o_ring_connector_collision_state_v069()
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var follower_joint := follower.get("joint") as Joint3D
		if is_instance_valid(follower_joint):
			_restore_o_ring_joint_v068(follower_joint)
	for proxy_shape_value in o_ring_proxy_shapes_v068:
		var proxy_shape := proxy_shape_value as CollisionShape3D
		if is_instance_valid(proxy_shape):
			proxy_shape.queue_free()
	for stop_proxy_value in o_ring_stop_proxies_v069:
		var stop_proxy := stop_proxy_value as Node
		if is_instance_valid(stop_proxy):
			stop_proxy.queue_free()
	o_ring_followers_v068.clear()
	o_ring_proxy_shapes_v068.clear()
	o_ring_stop_proxies_v069.clear()
	o_ring_axle_replacements_v069.clear()
	o_ring_stop_pair_count_v069 = 0
	axle_stop_ranges_v070.clear()
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.collision_layer = 2
			ring.collision_mask = 3


func _set_simulation_ccd_v068(enabled: bool) -> void:
	super._set_simulation_ccd_v068(enabled)
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.continuous_cd = enabled


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.collision_layer = 2
		ring.collision_mask = 3
		ring.continuous_cd = true
		ring.freeze = false
		ring.sleeping = false
	_status("Physics running — O-Rings stay fixed to their rods by normal CROSS-style joints; AXLE hubs stop on the real O-Ring collider")


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_071) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_071)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
