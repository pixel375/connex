extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("RIGIDITY_061_SMOKE_FAIL: %s" % message)
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


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v066.gd"):
		_fail("Main is not using v0.5.11 runtime")
		return

	if absf(float(main.get("physics_structure_rigidity_v066")) - 92.0) > 0.01:
		_fail("default Structure Rigidity is not 92%")
		return
	var sliders: Dictionary = main.get("physics_sliders_v054") as Dictionary
	if not sliders.has("Structure rigidity"):
		_fail("Structure Rigidity slider was not added to Physics UI")
		return

	# Closed square gives the graph one redundant SOCKET cycle edge.
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

	main.call("_prepare_stable_simulation_graph")
	if int(main.get("softened_socket_loop_count_v064")) < 1:
		_fail("closed square did not produce a stabilized redundant SOCKET")
		return

	var expected_default: float = float(main.call("_structure_flex_angle_rad_v066"))
	if expected_default <= 0.0 or rad_to_deg(expected_default) > 2.0:
		_fail("default rigidity flex is not in the intended near-rigid range: %.3f deg" % rad_to_deg(expected_default))
		return
	var marked := 0
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("sim_soft_socket_cycle_v064", false)):
			continue
		marked += 1
		if bool(joint.get_meta("sim_disabled", false)):
			_fail("real SOCKET was disabled from simulation")
			return
		for axis_name in ["x", "y", "z"]:
			if not bool(joint.get("angular_limit_%s/enabled" % axis_name)):
				_fail("default rigidity left a cycle SOCKET as a free angular hinge")
				return
			var lower := float(joint.get("angular_limit_%s/lower_angle" % axis_name))
			var upper := float(joint.get("angular_limit_%s/upper_angle" % axis_name))
			if absf(lower + expected_default) > 0.0005 or absf(upper - expected_default) > 0.0005:
				_fail("cycle SOCKET angular flex does not match rigidity setting")
				return
	if marked < 1:
		_fail("no marked cycle SOCKET found")
		return

	# 0% intentionally restores the old loose-cycle behavior, while 100% remains
	# slightly compliant rather than returning to a zero-slack redundant weld.
	main.set("physics_structure_rigidity_v066", 0.0)
	main.call("_apply_structure_rigidity_to_softened_v066")
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Generic6DOFJoint3D
		if is_instance_valid(joint) and bool(joint.get_meta("sim_soft_socket_cycle_v064", false)) and bool(joint.get("angular_limit_x/enabled")):
			_fail("0% rigidity did not restore loose cycle behavior")
			return

	main.set("physics_structure_rigidity_v066", 100.0)
	main.call("_apply_structure_rigidity_to_softened_v066")
	var max_rigid_flex := deg_to_rad(0.36)
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("sim_soft_socket_cycle_v064", false)):
			continue
		if not bool(joint.get("angular_limit_x/enabled")):
			_fail("100% rigidity unexpectedly disabled angular limit")
			return
		if float(joint.get("angular_limit_x/upper_angle")) > max_rigid_flex:
			_fail("100% rigidity is too loose")
			return
		if float(joint.get("angular_limit_x/upper_angle")) <= 0.0:
			_fail("100% rigidity returned to dangerous zero-slack weld")
			return

	# Restore the default and run long enough to catch the old delayed energy
	# buildup while verifying every real SOCKET stays physically active.
	main.set("physics_structure_rigidity_v066", 92.0)
	main.call("_apply_structure_rigidity_to_softened_v066")
	main.call("_restore_simulation_joint_graph")
	main.call("_toggle_simulation")
	var max_linear := 0.0
	var max_angular := 0.0
	for _frame in range(600):
		await physics_frame
		for body_value in (main.get("bodies") as Array):
			var body := body_value as RigidBody3D
			if is_instance_valid(body):
				max_linear = maxf(max_linear, body.linear_velocity.length())
				max_angular = maxf(max_angular, body.angular_velocity.length())
	if max_linear > 50.0:
		_fail("runaway linear velocity after rigidity limits: %.2f" % max_linear)
		return
	if max_angular > 75.0:
		_fail("runaway angular velocity after rigidity limits: %.2f" % max_angular)
		return
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Joint3D
		if is_instance_valid(joint) and str(joint.get_meta("connection_kind_v020", "")) == "socket" and bool(joint.get_meta("sim_disabled", false)):
			_fail("a real SOCKET became disabled during long simulation")
			return

	print("RIGIDITY_061_SMOKE_OK: 92%% default ±%.2f° cycle flex + 0/100%% endpoints + 600-frame stability" % rad_to_deg(float(main.call("_structure_flex_angle_rad_v066"))))
	main.queue_free()
	await process_frame
	quit(0)
