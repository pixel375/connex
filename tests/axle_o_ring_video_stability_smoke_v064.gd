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


func _add_o_ring(main: Node, rod: RigidBody3D, along: float) -> RigidBody3D:
	var axis: Vector3 = (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = main.call("_basis_for_axle_v020", axis) as Basis
	var ring := main.call("_make_o_ring_body", Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, ring, center) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	return ring


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

	# Device-video topology: closed rectangular frame riding one vertical axle,
	# with an O-Ring immediately below its axle hub. The axle/floor impact loads the
	# hub directly onto the stop while the rectangular frame lands asymmetrically.
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
	var ring := _add_o_ring(main, axle, hub_start_along - 0.92)
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
	if int((main.get("o_ring_proxy_shapes_v068") as Array).size()) != 0:
		_fail("v0.5.13 host-rod O-Ring proxy collision was recreated")
		return
	var stop_proxies := main.get("o_ring_stop_proxies_v069") as Array
	if stop_proxies.size() != 1:
		_fail("video fixture expected one root-level O-Ring stopper proxy, got %d" % stop_proxies.size())
		return
	if int(main.get("o_ring_stop_pair_count_v069")) < 1:
		_fail("video fixture did not configure an O-Ring/axle-hub stop pair")
		return
	if not ring.freeze or ring.collision_layer != 0 or ring.collision_mask != 0:
		_fail("visible video-fixture O-Ring was left active in collision physics")
		return
	var proxy_state := stop_proxies[0] as Dictionary
	var proxy := proxy_state.get("proxy") as AnimatableBody3D
	if not is_instance_valid(proxy) or proxy.get_parent() != main:
		_fail("video fixture O-Ring stopper is not a root-level AnimatableBody3D")
		return
	if proxy.collision_layer != int(main.get("O_RING_STOP_LAYER_V069")) or proxy.collision_mask != int(main.get("AXLE_STOP_TARGET_LAYER_V069")):
		_fail("video fixture O-Ring stopper collision channels are wrong")
		return
	if (a.collision_layer & int(main.get("AXLE_STOP_TARGET_LAYER_V069"))) == 0 or (a.collision_mask & int(main.get("O_RING_STOP_LAYER_V069"))) == 0:
		_fail("video fixture axle hub is not paired to O-Ring collision channel")
		return
	if bool(axle_joint.get("linear_limit_y/enabled")):
		_fail("video fixture axle slide was converted into a hard Y joint limit")
		return

	var max_linear := 0.0
	var max_angular := 0.0
	var min_stop_clearance := INF
	var max_gap := 0.0
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

		var hub_along := _along(main, a, axle)
		var ring_along := _along(main, ring, axle)
		var stop_clearance := hub_along - ring_along
		min_stop_clearance = minf(min_stop_clearance, stop_clearance)
		if stop_clearance < CLEARANCE - 0.12:
			_fail("axle hub crossed through O-Ring at frame %d: clearance=%.3f required≈%.3f" % [frame_index, stop_clearance, CLEARANCE])
			return

		var ring_expected: Transform3D = axle.global_transform * ring_local_before
		if ring.global_position.distance_to(ring_expected.origin) > 0.03:
			_fail("visible O-Ring follower drifted off its axle rod")
			return
		var proxy_expected: Transform3D = axle.global_transform * (proxy_state.get("local_transform", Transform3D.IDENTITY) as Transform3D)
		if proxy.global_position.distance_to(proxy_expected.origin) > 0.08:
			_fail("O-Ring stopper proxy drifted off axle at frame %d" % frame_index)
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

	print("AXLE_ORING_VIDEO_064_SMOKE_OK: moving O-Ring stopper blocks loaded axle hub and frame settles; min_clearance=%.3f vmax=%.2f wmax=%.2f gap=%.3f" % [min_stop_clearance, max_linear, max_angular, max_gap])
	main.queue_free()
	await process_frame
	quit(0)
