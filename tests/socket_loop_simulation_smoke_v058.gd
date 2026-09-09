extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_058_SMOKE_FAIL: %s" % message)
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


func _socket_record_between(main: Node, rod: RigidBody3D, connector: RigidBody3D) -> Dictionary:
	var records: Array = main.call("_connections_for_piece_v020", rod) as Array
	for value in records:
		var record: Dictionary = value as Dictionary
		if str(record.get("kind", "")) == "socket" and record.get("connector") == connector:
			return record
	return {}


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v063.gd"):
		_fail("Main is not using v0.5.8 runtime")
		return

	# Reproduce a rigid rectangular frame. Three sides already exist; the fourth
	# side is created through the real SOCKET placement path so its far end must
	# auto-attach and close the loop without ATTACH mode.
	var rod_len: float = 5.5 # Blue 54 actual 55 mm / 10
	var connector_d: float = 1.01
	var spacing: float = rod_len + connector_d * 2.0
	var y: float = 16.0
	var origin: Vector3 = Vector3(36.0, y, 24.0)
	var a: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin)) as RigidBody3D
	var b: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(spacing, 0.0, 0.0))) as RigidBody3D
	var c: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(spacing, 0.0, -spacing))) as RigidBody3D
	var d: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(0.0, 0.0, -spacing))) as RigidBody3D
	await process_frame

	_add_exact_socket_rod(main, a, 0, b, 180)
	_add_exact_socket_rod(main, b, 90, c, 270)
	_add_exact_socket_rod(main, c, 180, d, 0)
	main.call("_rebuild_connection_graph_v020")

	# D slot 270 points +Z toward A. v0.5.7 already creates the far-end SOCKET;
	# v0.5.8 must ensure simulation never suppresses that real loop-closing socket.
	main.call("_extend_socket", d, 270)
	await process_frame
	var bodies: Array = main.get("bodies") as Array
	var closing_rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(closing_rod) or str(closing_rod.get_meta("kind", "")) != "rod":
		_fail("production SOCKET placement did not create closing rod")
		return
	main.call("_rebuild_connection_graph_v020")
	var closing_records: Array = main.call("_connections_for_piece_v020", closing_rod) as Array
	var socket_count: int = 0
	for value in closing_records:
		if str((value as Dictionary).get("kind", "")) == "socket":
			socket_count += 1
	if socket_count != 2:
		_fail("closing rod was not attached at both ends before simulation; socket records=%d" % socket_count)
		return
	var far_record: Dictionary = _socket_record_between(main, closing_rod, a)
	if far_record.is_empty():
		_fail("closing rod far end did not auto-attach to the opposite connector")
		return

	# This is the v0.5.7 device failure: legacy preflight marks one fixed edge in
	# the loop sim_disabled and clears its node paths. v0.5.8 must restore every
	# SOCKET edge while still leaving inherited duplicate-axle filtering intact.
	main.call("_prepare_stable_simulation_graph")
	var restored_count: int = int(main.get("restored_socket_loop_constraints_v063"))
	if restored_count < 1:
		_fail("closed loop did not exercise the legacy redundant-socket suppression path")
		return
	var joints: Array = main.get("joints") as Array
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if is_instance_valid(joint) and str(joint.get_meta("connection_kind_v020", "")) == "socket" and bool(joint.get_meta("sim_disabled", false)):
			_fail("a real SOCKET joint is still suppressed before simulation")
			return

	# Start the actual simulation and let gravity/constraint solving run long enough
	# for the old missing closure to visibly open. The opposite end must stay in
	# the recorded socket throughout physics, not merely remain in the graph.
	main.call("_toggle_simulation")
	for _i in range(60):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if is_instance_valid(joint) and str(joint.get_meta("connection_kind_v020", "")) == "socket" and bool(joint.get_meta("sim_disabled", false)):
			_fail("SIMULATE suppressed a SOCKET loop connection")
			return

	var far_slot: int = int(far_record.get("slot", -1))
	var far_sign: int = int(far_record.get("rod_end", 0))
	var socket_after: Dictionary = main.call("_socket_world_v020", a, far_slot) as Dictionary
	var rod_after: Vector3 = main.call("_rod_end_v020", closing_rod, far_sign) as Vector3
	var gap_after: float = rod_after.distance_to(socket_after.get("point", a.global_position) as Vector3)
	if gap_after > 0.35:
		_fail("loop-closing rod end opened during simulation; gap=%.3f" % gap_after)
		return

	print("EDITOR_058_SMOKE_OK: far-end SOCKET auto-attachment closes a rigid loop and every socket remains solver-active through SIMULATE (gap %.3f)" % gap_after)
	main.queue_free()
	await process_frame
	quit(0)
