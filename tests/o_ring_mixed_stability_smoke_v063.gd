extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ORING_STABILITY_063_SMOKE_FAIL: %s" % message)
	quit(1)


func _add_axle_connection(main: Node, connector: RigidBody3D, rod: RigidBody3D, along: float) -> void:
	var joint := main.call("_make_axle_joint", connector, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", connector, rod, -1, 0, along, null, false)
	connector.set_meta("axle_occupied", true)


func _add_o_ring(main: Node, rod: RigidBody3D, along: float) -> RigidBody3D:
	var axis: Vector3 = (rod.global_transform.basis * Vector3.UP).normalized()
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = Basis(Quaternion(Vector3.UP, axis))
	var ring := main.call("_make_o_ring_body", Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, ring, center) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	return ring


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


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v068.gd"):
		_fail("Main is not using v0.5.13 runtime")
		return

	# Build a deliberately awkward mixed assembly like the device video: one long
	# vertical axle, two sliding connector hubs with offset spokes, and two O-Ring
	# Stops fixed to the axle rod. In v0.5.12 the rings remained frozen in world
	# space while their fixed joints pulled on the falling rod, eventually injecting
	# enough solver energy to fling the model out of view.
	var axle := main.call("_make_rod", 4, Vector3(0, 13, 0), Vector3(0, 29, 0)) as RigidBody3D
	var hub_a := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0, 19, 0))) as RigidBody3D
	var hub_b := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0, 23, 0))) as RigidBody3D
	_add_axle_connection(main, hub_a, axle, 0.0)
	_add_axle_connection(main, hub_b, axle, 4.0)
	_add_spoke(main, hub_a, 0, 5.5)
	_add_spoke(main, hub_a, 90, 5.5)
	_add_spoke(main, hub_a, 180, 5.5)
	_add_spoke(main, hub_b, 45, 5.5)
	_add_spoke(main, hub_b, 135, 5.5)
	var ring_low := _add_o_ring(main, axle, -3.0)
	var ring_high := _add_o_ring(main, axle, 6.0)
	main.call("_rebuild_connection_graph_v020")

	var ring_low_start_y := ring_low.global_position.y
	var ring_high_start_y := ring_high.global_position.y
	var low_local_before: Vector3 = axle.global_transform.affine_inverse() * ring_low.global_position
	var high_local_before: Vector3 = axle.global_transform.affine_inverse() * ring_high.global_position

	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame

	if ring_low.freeze or ring_high.freeze:
		_fail("O-Ring Stop remained frozen after SIMULATE release")
		return
	if ring_low.can_sleep or ring_high.can_sleep:
		_fail("O-Ring Stop was allowed to sleep independently during active simulation")
		return

	for _i in range(72):
		await physics_frame
	if ring_low.global_position.y > ring_low_start_y - 0.30 or ring_high.global_position.y > ring_high_start_y - 0.30:
		_fail("O-Ring Stops did not fall with their host construction under gravity")
		return

	var max_linear := 0.0
	var max_angular := 0.0
	for _frame in range(420):
		await physics_frame
		for body_value in (main.get("bodies") as Array):
			var body := body_value as RigidBody3D
			if is_instance_valid(body):
				max_linear = maxf(max_linear, body.linear_velocity.length())
				max_angular = maxf(max_angular, body.angular_velocity.length())
		for ring_value in (main.get("o_ring_stops") as Array):
			var ring := ring_value as RigidBody3D
			if is_instance_valid(ring):
				max_linear = maxf(max_linear, ring.linear_velocity.length())
				max_angular = maxf(max_angular, ring.angular_velocity.length())

	if max_linear > 41.9:
		_fail("mixed O-Ring/axle build developed runaway linear speed: %.2f" % max_linear)
		return
	if max_angular > 54.9:
		_fail("mixed O-Ring/axle build developed runaway angular speed: %.2f" % max_angular)
		return
	if int(main.get("runaway_guard_events_v068")) != 0:
		_fail("ordinary mixed fixture needed the emergency stability guard")
		return

	# Rings remain fixed stops on their host rod; only the whole construction is
	# dynamic. Their host-relative positions should therefore remain stable.
	var low_local_after: Vector3 = axle.global_transform.affine_inverse() * ring_low.global_position
	var high_local_after: Vector3 = axle.global_transform.affine_inverse() * ring_high.global_position
	if low_local_after.distance_to(low_local_before) > 0.35 or high_local_after.distance_to(high_local_before) > 0.35:
		_fail("O-Ring Stop drifted away from its fixed host position")
		return

	# Explicitly verify the last-resort energy limiter without relying on a real
	# solver failure to occur in CI.
	var guard_probe := main.call("_make_rod", 0, Vector3(40, 10, 0), Vector3(40, 15, 0)) as RigidBody3D
	guard_probe.freeze = false
	guard_probe.linear_velocity = Vector3(100, 0, 0)
	guard_probe.angular_velocity = Vector3(0, 90, 0)
	if not bool(main.call("_guard_body_energy_v068", guard_probe)):
		_fail("runaway stability guard did not recognize extreme solver energy")
		return
	if guard_probe.linear_velocity.length() > 18.01 or guard_probe.angular_velocity.length() > 24.01:
		_fail("runaway stability guard did not dissipate the extreme velocity spike")
		return

	print("ORING_STABILITY_063_SMOKE_OK: O-Rings dynamic + host-relative fixed + mixed axle/spoke fixture stable; vmax=%.2f wmax=%.2f" % [max_linear, max_angular])
	main.queue_free()
	await process_frame
	quit(0)
