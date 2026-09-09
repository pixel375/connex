extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PHYSICS_059_SMOKE_FAIL: %s" % message)
	quit(1)


func _add_exact_socket_rod(main: Node, a: RigidBody3D, slot_a: int, b: RigidBody3D, slot_b: int) -> RigidBody3D:
	var socket_a: Dictionary = main.call("_socket_world_v020", a, slot_a) as Dictionary
	var socket_b: Dictionary = main.call("_socket_world_v020", b, slot_b) as Dictionary
	var point_a: Vector3 = socket_a.get("point", a.global_position) as Vector3
	var point_b: Vector3 = socket_b.get("point", b.global_position) as Vector3
	var rod: RigidBody3D = main.call("_make_rod", 2, point_a, point_b) as RigidBody3D
	var joint_a: Generic6DOFJoint3D = main.call("_make_fixed_joint", a, rod, point_a) as Generic6DOFJoint3D
	var joint_b: Generic6DOFJoint3D = main.call("_make_fixed_joint", b, rod, point_b) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint_a, "socket", a, rod, slot_a, -1, 0.0, null, false)
	main.call("_tag_connection_v020", joint_b, "socket", b, rod, slot_b, 1, 0.0, null, false)
	main.call("_set_connector_occupied", a, slot_a, true)
	main.call("_set_connector_occupied", b, slot_b, true)
	main.call("_set_rod_end_occupied", rod, -1, true)
	main.call("_set_rod_end_occupied", rod, 1, true)
	rod.set_meta("build_transform", rod.global_transform)
	return rod


func _square_socket_records(main: Node, square_ids: Dictionary) -> Array:
	var result: Array = []
	main.call("_rebuild_connection_graph_v020")
	for value in (main.get("connections_v020") as Array):
		var record := value as Dictionary
		if str(record.get("kind", "")) != "socket":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if is_instance_valid(connector) and is_instance_valid(rod) and square_ids.has(connector.get_instance_id()) and square_ids.has(rod.get_instance_id()):
			result.append(record)
	return result


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v064.gd"):
		_fail("Main is not using v0.5.9 runtime")
		return

	# Closed flat frame: this is the exact class of construction that used to
	# develop waves and then explode after a few seconds.
	var spacing := 5.5 + 1.01 * 2.0
	var origin := Vector3(26.0, 16.0, 18.0)
	var a := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin)) as RigidBody3D
	var b := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(spacing, 0, 0))) as RigidBody3D
	var c := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(spacing, 0, -spacing))) as RigidBody3D
	var d := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(0, 0, -spacing))) as RigidBody3D
	var ab := _add_exact_socket_rod(main, a, 0, b, 180)
	var bc := _add_exact_socket_rod(main, b, 90, c, 270)
	var cd := _add_exact_socket_rod(main, c, 180, d, 0)
	main.call("_rebuild_connection_graph_v020")
	main.call("_extend_socket", d, 270)
	await process_frame
	var all_bodies := main.get("bodies") as Array
	var da := all_bodies[all_bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(da) or str(da.get_meta("kind", "")) != "rod":
		_fail("closing rod was not created")
		return

	var square_ids: Dictionary = {}
	for body in [a, b, c, d, ab, bc, cd, da]:
		square_ids[(body as RigidBody3D).get_instance_id()] = true
	var square_records := _square_socket_records(main, square_ids)
	if square_records.size() != 8:
		_fail("closed frame should contain 8 socket records, got %d" % square_records.size())
		return

	# Separate horizontal axle assembly. Gravity is perpendicular to the axle, so
	# it may rotate but should not acquire a large radial hub error or fly apart.
	var axle_basis := Basis(Quaternion(Vector3.UP, Vector3.RIGHT)).orthonormalized()
	var axle_connector := main.call("_make_connector", 6, Transform3D(axle_basis, Vector3(52.0, 13.0, 18.0))) as RigidBody3D
	main.call("_insert_axle", axle_connector)
	await process_frame
	all_bodies = main.get("bodies") as Array
	var axle_rod := all_bodies[all_bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(axle_rod) or str(axle_rod.get_meta("kind", "")) != "rod":
		_fail("axle fixture did not create a rod")
		return

	# Preflight must still exercise the v0.5.8 closed-loop path, but v0.5.9 should
	# convert at least one redundant SOCKET from a full 6DOF weld to positional
	# closure rather than leaving the over-constrained hard loop in the solver.
	main.call("_prepare_stable_simulation_graph")
	if int(main.get("restored_socket_loop_constraints_v063")) < 1:
		_fail("fixture did not exercise v0.5.8 restored socket-loop path")
		return
	if int(main.get("softened_socket_loop_count_v064")) < 1:
		_fail("v0.5.9 did not soften any redundant socket cycle edge")
		return
	var softened_found := false
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		if str(joint.get_meta("connection_kind_v020", "")) == "socket" and bool(joint.get_meta("sim_soft_socket_cycle_v064", false)):
			softened_found = true
			if bool((joint as Generic6DOFJoint3D).get("angular_limit_x/enabled")):
				_fail("soft socket cycle still has hard angular X lock")
				return
		if str(joint.get_meta("connection_kind_v020", "")) == "socket" and bool(joint.get_meta("sim_disabled", false)):
			_fail("a real SOCKET was physically removed instead of stabilized")
			return
	if not softened_found:
		_fail("softened SOCKET marker not found")
		return

	main.call("_toggle_simulation")
	var max_linear := 0.0
	var max_angular := 0.0
	var max_socket_gap := 0.0
	var max_axle_radial := 0.0
	for _frame in range(420):
		await physics_frame
		for body_value in (main.get("bodies") as Array):
			var body := body_value as RigidBody3D
			if not is_instance_valid(body):
				continue
			max_linear = maxf(max_linear, body.linear_velocity.length())
			max_angular = maxf(max_angular, body.angular_velocity.length())
		for record_value in square_records:
			max_socket_gap = maxf(max_socket_gap, float(main.call("_connection_gap_v059", record_value as Dictionary)))
		var axis: Vector3 = (axle_connector.global_transform.basis * Vector3.UP).normalized()
		var axle_delta: Vector3 = axle_rod.global_position - axle_connector.global_position
		var radial: Vector3 = axle_delta - axis * axle_delta.dot(axis)
		max_axle_radial = maxf(max_axle_radial, radial.length())

	if not bool(main.get("simulating")):
		_fail("simulation stopped unexpectedly")
		return
	if max_socket_gap > 0.70:
		_fail("closed frame developed excessive socket/wave separation: %.3f" % max_socket_gap)
		return
	if max_axle_radial > 0.75:
		_fail("axle rod jumped radially out of its hub: %.3f" % max_axle_radial)
		return
	if max_linear > 45.0:
		_fail("runaway linear velocity indicates solver explosion: %.2f" % max_linear)
		return
	if max_angular > 70.0:
		_fail("runaway angular velocity indicates solver explosion: %.2f" % max_angular)
		return

	print("PHYSICS_059_SMOKE_OK: 420-frame closed-loop + axle run stable; gap=%.3f radial=%.3f vmax=%.2f wmax=%.2f" % [max_socket_gap, max_axle_radial, max_linear, max_angular])
	main.queue_free()
	await process_frame
	quit(0)
