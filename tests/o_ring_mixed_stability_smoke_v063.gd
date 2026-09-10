extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ORING_STABILITY_063_SMOKE_FAIL: %s" % message)
	quit(1)


func _add_axle_connection(main: Node, connector: RigidBody3D, rod: RigidBody3D, along: float) -> Generic6DOFJoint3D:
	var joint := main.call("_make_axle_joint", connector, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", connector, rod, -1, 0, along, null, false)
	connector.set_meta("axle_occupied", true)
	return joint


func _add_o_ring(main: Node, rod: RigidBody3D, along: float) -> Dictionary:
	var axis: Vector3 = (rod.global_transform.basis * Vector3.UP).normalized()
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = Basis(Quaternion(Vector3.UP, axis))
	var ring := main.call("_make_o_ring_body", Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, ring, center) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	return {"ring": ring, "joint": joint}


func _add_spoke(main: Node, connector: RigidBody3D, slot: int, length: float) -> RigidBody3D:
	var socket: Dictionary = main.call("_socket_world_v020", connector, slot) as Dictionary
	var start: Vector3 = socket.get("point", connector.global_position) as Vector3
	var direction: Vector3 = (socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var finish: Vector3 = start + direction * length
	var rod := main.call("_make_rod", 2, start, finish) as RigidBody3D
	var joint := main.call("_make_fixed_joint", connector, rod, start) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "socket", connector, rod, slot, -1, 0.0, null, false)
	main.call("_set_connector_occupied", connector, slot, true)
	main.call("_set_rod_end_occupied", rod, -1, true)
	rod.set_meta("build_transform", rod.global_transform)
	return rod


func _along(main: Node, body: Node3D, rod: RigidBody3D) -> float:
	var axis: Vector3 = (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	return (body.global_position - rod.global_position).dot(axis)


func _assert_mount_state(mount: Generic6DOFJoint3D, attached: bool, phase: String) -> bool:
	if not is_instance_valid(mount):
		_fail("O-Ring mount missing during %s" % phase)
		return false
	if attached:
		if mount.node_a.is_empty() or mount.node_b.is_empty():
			_fail("O-Ring BUILD mount was not restored during %s" % phase)
			return false
	else:
		if not mount.node_a.is_empty() or not mount.node_b.is_empty():
			_fail("O-Ring SIMULATE weld is still solver-active during %s" % phase)
			return false
	return true


func _sync_follower_for_measurement(main: Node) -> void:
	main.call("_sync_o_ring_followers_v068")


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v070.gd"):
		_fail("Main is not using v0.5.15 runtime")
		return

	var axle := main.call("_make_rod", 4, Vector3(0, 13, 0), Vector3(0, 29, 0)) as RigidBody3D
	var hub_a := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0, 19, 0))) as RigidBody3D
	var hub_b := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0, 23, 0))) as RigidBody3D
	var axle_joint_a := _add_axle_connection(main, hub_a, axle, -2.0)
	var axle_joint_b := _add_axle_connection(main, hub_b, axle, 2.0)
	_add_spoke(main, hub_a, 0, 5.5)
	_add_spoke(main, hub_a, 90, 5.5)
	_add_spoke(main, hub_a, 180, 5.5)
	_add_spoke(main, hub_b, 45, 5.5)
	_add_spoke(main, hub_b, 135, 5.5)
	var low_info := _add_o_ring(main, axle, -3.0)
	var high_info := _add_o_ring(main, axle, 6.0)
	var ring_low := low_info.get("ring") as RigidBody3D
	var ring_high := high_info.get("ring") as RigidBody3D
	var mount_low := low_info.get("joint") as Generic6DOFJoint3D
	var mount_high := high_info.get("joint") as Generic6DOFJoint3D
	main.call("_rebuild_connection_graph_v020")

	var ring_low_start_y := ring_low.global_position.y
	var ring_high_start_y := ring_high.global_position.y
	var low_parent_before := ring_low.get_parent()
	var high_parent_before := ring_high.get_parent()
	var low_local_before: Transform3D = axle.global_transform.affine_inverse() * ring_low.global_transform
	var high_local_before: Transform3D = axle.global_transform.affine_inverse() * ring_high.global_transform

	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	_sync_follower_for_measurement(main)

	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	var followers := main.get("o_ring_followers_v068") as Array
	if followers.size() != 2:
		_fail("expected two exact rod-relative O-Ring followers, got %d" % followers.size())
		return
	if not (main.get("o_ring_proxy_shapes_v068") as Array).is_empty() or not (main.get("o_ring_stop_proxies_v069") as Array).is_empty():
		_fail("an obsolete O-Ring proxy collider exists")
		return
	if not (main.get("o_ring_axle_replacements_v069") as Array).is_empty():
		_fail("AXLE joint was replaced instead of keeping the normal free AXLE")
		return
	if int(main.get("o_ring_stop_pair_count_v069")) != 2:
		_fail("expected exactly two rod-relative O-Ring stops")
		return
	if (main.get("axle_stop_ranges_v070") as Array).size() != 2:
		_fail("expected two deterministic AXLE travel ranges")
		return

	for ring in [ring_low, ring_high]:
		if not ring.freeze or ring.freeze_mode != RigidBody3D.FREEZE_MODE_KINEMATIC:
			_fail("rod-relative O-Ring is not frozen/kinematic")
			return
		if ring.get_parent() == axle:
			_fail("O-Ring was nested under a physics-body host")
			return
		if ring.collision_layer != 0 or ring.collision_mask != 0:
			_fail("O-Ring is still independently collision-solved during SIMULATE")
			return
	if ring_low.get_parent() != low_parent_before or ring_high.get_parent() != high_parent_before:
		_fail("O-Ring parent changed during world-space follower setup")
		return
	if not _assert_mount_state(mount_low, false, "SIMULATE") or not _assert_mount_state(mount_high, false, "SIMULATE"):
		return

	for axle_joint in [axle_joint_a, axle_joint_b]:
		if axle_joint.node_a.is_empty() or axle_joint.node_b.is_empty():
			_fail("normal AXLE joint was detached")
			return
		if bool(axle_joint.get("linear_limit_y/enabled")):
			_fail("normal AXLE slide was rewritten with an artificial Y joint limit")
			return
		if bool(axle_joint.get("angular_limit_y/enabled")):
			_fail("normal AXLE rotation was accidentally locked")
			return

	for _i in range(72):
		await physics_frame
		_sync_follower_for_measurement(main)
	if ring_low.global_position.y > ring_low_start_y - 0.30 or ring_high.global_position.y > ring_high_start_y - 0.30:
		_fail("O-Rings did not fall with their host rod")
		return

	var max_linear := 0.0
	var max_angular := 0.0
	var min_a_clearance := INF
	var min_b_clearance := INF
	var max_ring_drift := 0.0
	const EXPECTED_CLEARANCE := 0.43
	for frame_index in range(420):
		await physics_frame
		_sync_follower_for_measurement(main)
		for body_value in (main.get("bodies") as Array):
			var body := body_value as RigidBody3D
			if not is_instance_valid(body):
				continue
			if not body.global_position.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite():
				_fail("non-finite body state in mixed O-Ring fixture")
				return
			max_linear = maxf(max_linear, body.linear_velocity.length())
			max_angular = maxf(max_angular, body.angular_velocity.length())

		var low_expected: Transform3D = axle.global_transform * low_local_before
		var high_expected: Transform3D = axle.global_transform * high_local_before
		var frame_drift := maxf(ring_low.global_position.distance_to(low_expected.origin), ring_high.global_position.distance_to(high_expected.origin))
		max_ring_drift = maxf(max_ring_drift, frame_drift)
		if frame_drift > 0.015:
			_fail("rod-relative O-Ring drifted from host at frame %d: %.4f" % [frame_index, frame_drift])
			return

		var low_along := _along(main, ring_low, axle)
		var high_along := _along(main, ring_high, axle)
		var hub_a_along := _along(main, hub_a, axle)
		var hub_b_along := _along(main, hub_b, axle)
		var a_low_gap := hub_a_along - low_along
		var a_high_gap := high_along - hub_a_along
		var b_low_gap := hub_b_along - low_along
		var b_high_gap := high_along - hub_b_along
		min_a_clearance = minf(min_a_clearance, minf(a_low_gap, a_high_gap))
		min_b_clearance = minf(min_b_clearance, minf(b_low_gap, b_high_gap))
		if a_low_gap < EXPECTED_CLEARANCE - 0.12 or a_high_gap < EXPECTED_CLEARANCE - 0.12:
			_fail("hub A crossed an O-Ring at frame %d: gaps=[%.3f, %.3f]" % [frame_index, a_low_gap, a_high_gap])
			return
		if b_low_gap < EXPECTED_CLEARANCE - 0.12 or b_high_gap < EXPECTED_CLEARANCE - 0.12:
			_fail("hub B crossed an O-Ring at frame %d: gaps=[%.3f, %.3f]" % [frame_index, b_low_gap, b_high_gap])
			return

	if max_linear > 41.9 or max_angular > 54.9:
		_fail("mixed build became unstable: vmax=%.2f wmax=%.2f" % [max_linear, max_angular])
		return
	if int(main.get("runaway_guard_events_v068")) != 0:
		_fail("ordinary mixed fixture needed the emergency stability guard (%d events)" % int(main.get("runaway_guard_events_v068")))
		return

	main.call("_toggle_simulation")
	for _i in range(4):
		await physics_frame
	if axle_joint_a.node_a.is_empty() or axle_joint_a.node_b.is_empty() or axle_joint_b.node_a.is_empty() or axle_joint_b.node_b.is_empty():
		_fail("normal AXLE joint did not survive return to BUILD")
		return
	if bool(axle_joint_a.get("linear_limit_y/enabled")) or bool(axle_joint_b.get("linear_limit_y/enabled")):
		_fail("BUILD axle Y slide is not free")
		return
	if not _assert_mount_state(mount_low, true, "BUILD") or not _assert_mount_state(mount_high, true, "BUILD"):
		return
	if not (main.get("o_ring_followers_v068") as Array).is_empty() or not (main.get("axle_stop_ranges_v070") as Array).is_empty():
		_fail("O-Ring/AXLE stop simulation state leaked into BUILD")
		return
	if ring_low.get_parent() != low_parent_before or ring_high.get_parent() != high_parent_before:
		_fail("O-Ring BUILD parent was not preserved")
		return
	for ring in [ring_low, ring_high]:
		if not ring.freeze or ring.collision_layer != 2 or ring.collision_mask != 3:
			_fail("O-Ring did not return to editable BUILD state")
			return

	print("ORING_STABILITY_063_SMOKE_OK: deterministic rod-relative O-Ring/rod-end stops keep free AXLE hubs inside their travel segments; clearances=[%.3f,%.3f] max_drift=%.4f vmax=%.2f wmax=%.2f" % [min_a_clearance, min_b_clearance, max_ring_drift, max_linear, max_angular])
	main.queue_free()
	await process_frame
	quit(0)
