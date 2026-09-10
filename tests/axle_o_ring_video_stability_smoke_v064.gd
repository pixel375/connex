extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("AXLE_ORING_VIDEO_064_SMOKE_FAIL: %s" % message)
	quit(1)


func _add_exact_socket_rod(main: Node, a: RigidBody3D, slot_a: int, b: RigidBody3D, slot_b: int) -> RigidBody3D:
	var socket_a: Dictionary = main.call("_socket_world_v020", a, slot_a) as Dictionary
	var socket_b: Dictionary = main.call("_socket_world_v020", b, slot_b) as Dictionary
	var point_a: Vector3 = socket_a.get("point", a.global_position) as Vector3
	var point_b: Vector3 = socket_b.get("point", b.global_position) as Vector3
	var rod := main.call("_make_rod", 2, point_a, point_b) as RigidBody3D
	var joint_a := main.call("_make_fixed_joint", a, rod, point_a) as Generic6DOFJoint3D
	var joint_b := main.call("_make_fixed_joint", b, rod, point_b) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint_a, "socket", a, rod, slot_a, -1, 0.0, null, false)
	main.call("_tag_connection_v020", joint_b, "socket", b, rod, slot_b, 1, 0.0, null, false)
	main.call("_set_connector_occupied", a, slot_a, true)
	main.call("_set_connector_occupied", b, slot_b, true)
	main.call("_set_rod_end_occupied", rod, -1, true)
	main.call("_set_rod_end_occupied", rod, 1, true)
	rod.set_meta("build_transform", rod.global_transform)
	return rod


func _add_axle_connection(main: Node, connector: RigidBody3D, rod: RigidBody3D) -> Generic6DOFJoint3D:
	var axis: Vector3 = (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var along: float = (connector.global_position - rod.global_position).dot(axis)
	var joint := main.call("_make_axle_joint", connector, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", connector, rod, -1, 0, along, null, true)
	connector.set_meta("axle_occupied", true)
	connector.set_meta("axle_host_rod", rod)
	return joint


func _add_o_ring(main: Node, rod: RigidBody3D, along: float) -> Dictionary:
	var axis: Vector3 = (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = main.call("_basis_for_axle_v020", axis) as Basis
	var ring := main.call("_make_o_ring_body", Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, ring, center) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	return {"ring": ring, "joint": joint}


func _along(main: Node, body: Node3D, rod: RigidBody3D) -> float:
	var axis: Vector3 = (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	return (body.global_position - rod.global_position).dot(axis)


func _max_socket_gap(main: Node) -> float:
	var max_gap := 0.0
	main.call("_rebuild_connection_graph_v020")
	for value in (main.get("connections_v020") as Array):
		var record := value as Dictionary
		if str(record.get("kind", "")) != "socket":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		var slot := int(record.get("slot", -1))
		var rod_end := int(record.get("rod_end", 0))
		if not is_instance_valid(connector) or not is_instance_valid(rod) or slot < 0 or rod_end == 0:
			continue
		var socket := main.call("_socket_world_v020", connector, slot) as Dictionary
		var point_a := socket.get("point", connector.global_position) as Vector3
		var point_b := main.call("_rod_end_v020", rod, rod_end) as Vector3
		max_gap = maxf(max_gap, point_a.distance_to(point_b))
	return max_gap


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v069.gd"):
		_fail("Main is not using v0.5.14 runtime")
		return

	var axle_x := 44.0
	var axle_z := 18.0
	var axle := main.call("_make_rod", 4, Vector3(axle_x, 0.42, axle_z), Vector3(axle_x, 13.42, axle_z)) as RigidBody3D
	var y := 8.20
	var spacing := 5.5 + 1.01 * 2.0
	var a := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(axle_x, y, axle_z))) as RigidBody3D
	var b := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(axle_x + spacing, y, axle_z))) as RigidBody3D
	var c := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(axle_x + spacing, y, axle_z - spacing))) as RigidBody3D
	var d := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(axle_x, y, axle_z - spacing))) as RigidBody3D
	_add_exact_socket_rod(main, a, 0, b, 180)
	_add_exact_socket_rod(main, b, 90, c, 270)
	_add_exact_socket_rod(main, c, 180, d, 0)
	_add_exact_socket_rod(main, d, 270, a, 90)
	var axle_joint := _add_axle_connection(main, a, axle)
	var hub_start_along := _along(main, a, axle)
	var ring_info := _add_o_ring(main, axle, hub_start_along - 0.92)
	var ring := ring_info.get("ring") as RigidBody3D
	var ring_mount := ring_info.get("joint") as Generic6DOFJoint3D
	main.call("_rebuild_connection_graph_v020")

	var ring_local_before: Transform3D = axle.global_transform.affine_inverse() * ring.global_transform
	var ring_start_along := _along(main, ring, axle)
	if hub_start_along <= ring_start_along:
		_fail("fixture O-Ring is not below the axle hub")
		return

	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	var followers := main.get("o_ring_followers_v068") as Array
	if followers.size() != 1:
		_fail("video fixture did not create exactly one collidable rod-relative O-Ring follower")
		return
	if not (main.get("o_ring_proxy_shapes_v068") as Array).is_empty():
		_fail("host-rod O-Ring proxy collision was recreated")
		return
	if not (main.get("o_ring_stop_proxies_v069") as Array).is_empty():
		_fail("moving O-Ring proxy body was recreated")
		return
	if not (main.get("o_ring_axle_replacements_v069") as Array).is_empty():
		_fail("AXLE joint was replaced instead of using physical O-Ring contact")
		return
	if int(main.get("o_ring_stop_pair_count_v069")) != 1:
		_fail("video fixture did not keep exactly one O-Ring stop")
		return
	if not ring.freeze or ring.freeze_mode != RigidBody3D.FREEZE_MODE_KINEMATIC:
		_fail("video O-Ring is not an exact kinematic follower")
		return
	if ring.get_parent() != axle:
		_fail("video O-Ring is not parented to its axle rod")
		return
	if ring.collision_layer != 2 or ring.collision_mask != 3:
		_fail("video O-Ring lost construction collision policy; layer=%d mask=%d" % [ring.collision_layer, ring.collision_mask])
		return
	if not ring.get_collision_exceptions().has(axle):
		_fail("video O-Ring does not exclude its host rod")
		return
	if not ring_mount.node_a.is_empty() or not ring_mount.node_b.is_empty():
		_fail("video O-Ring BUILD weld remained active during follower simulation")
		return

	if axle_joint.node_a.is_empty() or axle_joint.node_b.is_empty():
		_fail("normal AXLE joint was detached")
		return
	if bool(axle_joint.get("linear_limit_y/enabled")):
		_fail("normal AXLE slide was rewritten with an artificial Y limit")
		return
	if bool(axle_joint.get("angular_limit_y/enabled")):
		_fail("normal AXLE rotation was accidentally locked")
		return

	var max_linear := 0.0
	var max_angular := 0.0
	var min_stop_clearance := INF
	var max_gap := 0.0
	var max_ring_drift := 0.0
	const CLEARANCE := 0.43
	for frame_index in range(720):
		await physics_frame
		for body_value in (main.get("bodies") as Array):
			var body := body_value as RigidBody3D
			if not is_instance_valid(body):
				continue
			if not body.global_position.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite():
				_fail("non-finite body transform/velocity in video fixture")
				return
			max_linear = maxf(max_linear, body.linear_velocity.length())
			max_angular = maxf(max_angular, body.angular_velocity.length())

		var ring_expected: Transform3D = axle.global_transform * ring_local_before
		var ring_drift := ring.global_position.distance_to(ring_expected.origin)
		max_ring_drift = maxf(max_ring_drift, ring_drift)
		if ring_drift > 0.015:
			_fail("rod-relative O-Ring drifted off axle at frame %d: %.4f" % [frame_index, ring_drift])
			return

		var hub_along := _along(main, a, axle)
		var ring_along := _along(main, ring, axle)
		var stop_clearance := hub_along - ring_along
		min_stop_clearance = minf(min_stop_clearance, stop_clearance)
		if stop_clearance < CLEARANCE - 0.12:
			_fail("axle hub crossed through physical O-Ring at frame %d: clearance=%.3f required≈%.3f" % [frame_index, stop_clearance, CLEARANCE])
			return

		if frame_index % 30 == 0:
			max_gap = maxf(max_gap, _max_socket_gap(main))

	if int(main.get("runaway_guard_events_v068")) != 0:
		_fail("device-video topology still triggered the runaway guard (%d events)" % int(main.get("runaway_guard_events_v068")))
		return
	if max_linear > 32.0 or max_angular > 30.0:
		_fail("device-video topology still dances/runaways: vmax=%.2f wmax=%.2f" % [max_linear, max_angular])
		return
	if max_gap > 0.40:
		_fail("closed frame opened while settling on O-Ring; max socket gap=%.3f" % max_gap)
		return

	main.call("_toggle_simulation")
	for _i in range(4):
		await physics_frame
	if axle_joint.node_a.is_empty() or axle_joint.node_b.is_empty() or bool(axle_joint.get("linear_limit_y/enabled")):
		_fail("normal free AXLE did not survive return to BUILD")
		return
	if ring_mount.node_a.is_empty() or ring_mount.node_b.is_empty():
		_fail("O-Ring BUILD weld did not restore")
		return
	if not (main.get("o_ring_followers_v068") as Array).is_empty():
		_fail("O-Ring follower state leaked into BUILD")
		return
	if not ring.freeze or ring.get_parent() == axle or ring.collision_layer != 2 or ring.collision_mask != 3:
		_fail("physical O-Ring did not return to editable BUILD state")
		return
	if ring.get_collision_exceptions().has(axle):
		_fail("temporary host collision exception leaked into BUILD")
		return

	print("AXLE_ORING_VIDEO_064_SMOKE_OK: exact collidable rod-relative O-Ring blocks loaded axle hub and closed frame settles; min_clearance=%.3f max_drift=%.4f vmax=%.2f wmax=%.2f gap=%.3f" % [min_stop_clearance, max_ring_drift, max_linear, max_angular, max_gap])
	main.queue_free()
	await process_frame
	quit(0)
