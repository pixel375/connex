extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("RIGIDITY_AXLE_062_SMOKE_FAIL: %s" % message)
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


func _find_soft_socket(main: Node) -> Generic6DOFJoint3D:
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Generic6DOFJoint3D
		if is_instance_valid(joint) and bool(joint.get_meta("sim_soft_socket_cycle_v064", false)):
			return joint
	return null


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v067.gd"):
		_fail("Main is not using expected runtime")
		return

	# Closed square: gives the simulation one cycle-closing SOCKET whose angular
	# limits are controlled by Structure Rigidity.
	var spacing := 5.5 + 1.01 * 2.0
	var origin := Vector3(32.0, 18.0, 20.0)
	var a := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin)) as RigidBody3D
	var b := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(spacing, 0, 0))) as RigidBody3D
	var c := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(spacing, 0, -spacing))) as RigidBody3D
	var d := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, origin + Vector3(0, 0, -spacing))) as RigidBody3D
	_add_exact_socket_rod(main, a, 0, b, 180)
	_add_exact_socket_rod(main, b, 90, c, 270)
	_add_exact_socket_rod(main, c, 180, d, 0)
	_add_exact_socket_rod(main, d, 270, a, 90)
	main.call("_rebuild_connection_graph_v020")

	main.call("_toggle_simulation")
	for _i in range(8):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	var soft_before := _find_soft_socket(main)
	if soft_before == null:
		_fail("closed square produced no stabilized cycle socket")
		return
	var active_before: float = float(soft_before.get("angular_limit_x/upper_angle"))
	if active_before < -0.000001:
		_fail("default active rigidity limit is invalid")
		return

	# Slider changes while SIMULATE is active are next-run settings only. This is
	# true whether the current high-end setting is exact-rigid (0°) or compliant.
	main.call("_on_structure_rigidity_v066", 20.0)
	var active_after_slider: float = float(soft_before.get("angular_limit_x/upper_angle"))
	if absf(active_after_slider - active_before) > 0.000001:
		_fail("rigidity slider mutated an active simulation joint")
		return
	if not bool(main.get("rigidity_pending_for_next_run_v067")):
		_fail("rigidity change during simulation was not marked next-run pending")
		return
	if absf(float(main.get("physics_structure_rigidity_v066")) - 20.0) > 0.01:
		_fail("new rigidity value was not saved")
		return

	# Return to BUILD and start again: only now should 20% visible flex apply.
	main.call("_toggle_simulation")
	await process_frame
	if bool(main.get("simulating")):
		_fail("BUILD did not restore after first simulation")
		return
	main.call("_toggle_simulation")
	for _i in range(8):
		await physics_frame
	var soft_next := _find_soft_socket(main)
	if soft_next == null:
		_fail("second simulation produced no stabilized cycle socket")
		return
	var next_limit: float = float(soft_next.get("angular_limit_x/upper_angle"))
	if next_limit <= maxf(active_before + 0.01, deg_to_rad(1.0)):
		_fail("next simulation did not apply the new lower-rigidity flex range")
		return
	if absf(float(main.get("active_structure_rigidity_v067")) - 20.0) > 0.01:
		_fail("active rigidity snapshot is not the value chosen for this run")
		return
	main.call("_toggle_simulation")
	await process_frame

	# Separate axle fixture. Support the connector as if the surrounding build is
	# resting on the ground, then verify the axle's free slide DOF actually responds
	# to gravity rather than sleeping in place.
	var axle_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(70.0, 16.0, 0.0))) as RigidBody3D
	main.call("_set_selected", axle_connector)
	main.call("_insert_axle", axle_connector)
	await process_frame
	var all_bodies := main.get("bodies") as Array
	var axle_rod := all_bodies[all_bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(axle_rod) or not bool(main.call("_is_axle_rod_v067", axle_rod)):
		_fail("axle rod fixture was not recognized")
		return
	if int(main.call("_wake_axle_rods_v067")) < 1:
		_fail("axle wake pass found no axle rod")
		return
	if axle_rod.can_sleep:
		_fail("axle rod can still sleep during simulation")
		return

	# The connector represents a supported structure. The axle remains dynamic and
	# must slide downward along connector-local Y under gravity.
	axle_connector.freeze = true
	axle_connector.sleeping = false
	axle_rod.freeze = false
	axle_rod.sleeping = false
	axle_rod.can_sleep = false
	var axis: Vector3 = (axle_connector.global_transform.basis * Vector3.UP).normalized()
	var along_start: float = (axle_rod.global_position - axle_connector.global_position).dot(axis)
	for _i in range(50):
		await physics_frame
	var along_end: float = (axle_rod.global_position - axle_connector.global_position).dot(axis)
	if along_end > along_start - 0.35:
		_fail("supported vertical axle did not slide downward under gravity: start=%.3f end=%.3f" % [along_start, along_end])
		return

	print("RIGIDITY_AXLE_062_SMOKE_OK: high-end rigid live setting stays unchanged; lower rigidity applies next run + supported axle slides under gravity")
	main.queue_free()
	await process_frame
	quit(0)
