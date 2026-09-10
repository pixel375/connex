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


func _assert_all_structure_flex(main: Node, expected: float, label: String) -> bool:
	var count := 0
	var ordinary_count := 0
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or str(joint.get_meta("connection_kind_v020", "")) not in ["socket", "cross"]:
			continue
		count += 1
		if not bool(joint.get_meta("sim_soft_socket_cycle_v064", false)):
			ordinary_count += 1
		if not bool(joint.get_meta("sim_rigidity_all_v072", false)):
			_fail("%s did not mark every SOCKET/CROSS structure joint" % label)
			return false
		for axis_name in ["x", "y", "z"]:
			if not bool(joint.get("angular_limit_%s/enabled" % axis_name)):
				_fail("%s disabled an angular limit instead of using bounded flex" % label)
				return false
			var lower: float = float(joint.get("angular_limit_%s/lower_angle" % axis_name))
			var upper: float = float(joint.get("angular_limit_%s/upper_angle" % axis_name))
			if absf(lower + expected) > 0.0006 or absf(upper - expected) > 0.0006:
				_fail("%s flex mismatch on %s: [%.5f, %.5f] expected ±%.5f" % [label, axis_name, lower, upper, expected])
				return false
	if count < 1 or ordinary_count < 1:
		_fail("%s did not include an ordinary non-cycle socket joint" % label)
		return false
	return true


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v072.gd"):
		_fail("Main is not using v0.5.16 runtime")
		return
	if absf(float(main.get("physics_structure_rigidity_v066")) - 92.0) > 0.01:
		_fail("default Structure Rigidity is not 92%")
		return
	var sliders: Dictionary = main.get("physics_sliders_v054") as Dictionary
	if not sliders.has("Structure rigidity"):
		_fail("Structure Rigidity slider was not added to Physics UI")
		return

	# Closed square guarantees cycle stabilization while also containing ordinary
	# non-cycle SOCKET joints. v0.5.16 must apply the slider to BOTH kinds.
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
	if rad_to_deg(expected_default) < 0.70 or rad_to_deg(expected_default) > 1.20:
		_fail("default rigidity flex should remain around one degree: %.3f°" % rad_to_deg(expected_default))
		return
	if not _assert_all_structure_flex(main, expected_default, "92% rigidity"):
		return

	# 0% is now visibly flexible but still bounded; it is never a free hinge.
	main.set("physics_structure_rigidity_v066", 0.0)
	var zero_expected: float = float(main.call("_structure_flex_angle_rad_v066"))
	if absf(rad_to_deg(zero_expected) - 12.0) > 0.05:
		_fail("0% rigidity is not the intended bounded ±12° flex")
		return
	main.call("_apply_structure_flex_all_v072")
	if not _assert_all_structure_flex(main, zero_expected, "0% rigidity"):
		return

	# User-facing maximum means rigid. Keep limits enabled at exactly 0° rather
	# than using an unconstrained or hidden-compliance state.
	main.set("physics_structure_rigidity_v066", 100.0)
	var rigid_expected: float = float(main.call("_structure_flex_angle_rad_v066"))
	if absf(rigid_expected) > 0.000001:
		_fail("100% rigidity is not exactly rigid")
		return
	main.call("_apply_structure_flex_all_v072")
	if not _assert_all_structure_flex(main, 0.0, "100% rigidity"):
		return

	# Default remains the shipping physics setting and must survive a long closed
	# loop run without returning to the old delayed energy explosion.
	main.set("physics_structure_rigidity_v066", 92.0)
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
		_fail("runaway linear velocity after whole-structure rigidity: %.2f" % max_linear)
		return
	if max_angular > 75.0:
		_fail("runaway angular velocity after whole-structure rigidity: %.2f" % max_angular)
		return

	print("RIGIDITY_061_SMOKE_OK: whole-structure bounded flex works from 0%%=±12° through 92%%=±%.2f° to 100%%=rigid; 600-frame stability retained" % rad_to_deg(float(main.call("_structure_flex_angle_rad_v066"))))
	main.queue_free()
	await process_frame
	quit(0)
