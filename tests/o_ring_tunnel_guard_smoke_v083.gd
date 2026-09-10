extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ORING_TUNNEL_083_SMOKE_FAIL: %s" % message)
	quit(1)


func _add_axle(main: Node, connector: RigidBody3D, rod: RigidBody3D) -> void:
	var joint := main.call("_make_axle_joint", connector, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", connector, rod, -1, 0, 0.0, null, false)
	connector.set_meta("axle_occupied", true)


func _add_ring(main: Node, rod: RigidBody3D, along: float) -> RigidBody3D:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var center := rod.global_position + axis * along
	var basis := main.call("_basis_for_axle_v020", axis) as Basis
	var ring := main.call("_make_o_ring_body", Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, ring, center) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	return ring


func _stop_for(main: Node, connector: RigidBody3D, rod: RigidBody3D) -> Dictionary:
	for value in main.get("axle_stop_ranges_v070") as Array:
		var stop := value as Dictionary
		if stop.get("connector") == connector and stop.get("rod") == rod:
			return stop
	return {}


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	if not str(main.get_script().resource_path).ends_with("main_v083.gd"):
		_fail("Main is not using v083 diagnostic runtime")
		return

	var axle := main.call("_make_rod", 5, Vector3(0, 4, 0), Vector3(0, 23.2, 0)) as RigidBody3D
	var axis := (main.call("_rod_axis_v020", axle) as Vector3).normalized()
	var basis := main.call("_basis_for_axle_v020", axis) as Basis
	var lower_hub := main.call("_make_connector", 6, Transform3D(basis, axle.global_position + axis * -1.0)) as RigidBody3D
	var upper_hub := main.call("_make_connector", 6, Transform3D(basis, axle.global_position + axis * 1.0)) as RigidBody3D
	_add_axle(main, lower_hub, axle)
	_add_axle(main, upper_hub, axle)
	_add_ring(main, axle, -3.0)
	main.call("_rebuild_connection_graph_v020")
	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame

	var lower_stop := _stop_for(main, lower_hub, axle)
	var upper_stop := _stop_for(main, upper_hub, axle)
	if lower_stop.is_empty() or upper_stop.is_empty():
		_fail("two-hub O-Ring group did not build stop records")
		return

	# Free interior would-cross probe. The guard must change velocity only and
	# conserve pair axial momentum when no finite stop is supporting either hub.
	var lower_tf := lower_hub.global_transform
	var upper_tf := upper_hub.global_transform
	lower_tf.origin = axle.global_position + axis * -0.09
	upper_tf.origin = axle.global_position + axis * 0.09
	lower_hub.global_transform = lower_tf
	upper_hub.global_transform = upper_tf
	lower_hub.linear_velocity = axis * 8.0
	upper_hub.linear_velocity = axis * -8.0
	lower_hub.angular_velocity = Vector3.ZERO
	upper_hub.angular_velocity = Vector3.ZERO
	var lower_pos_before := lower_hub.global_position
	var upper_pos_before := upper_hub.global_position
	var momentum_before := lower_hub.mass * lower_hub.linear_velocity.dot(axis) + upper_hub.mass * upper_hub.linear_velocity.dot(axis)
	var guard_before := int(main.get("axle_pair_guard_events_v083"))
	main.call("_predict_axle_order_v073", 1.0 / 60.0)
	var momentum_after := lower_hub.mass * lower_hub.linear_velocity.dot(axis) + upper_hub.mass * upper_hub.linear_velocity.dot(axis)
	var relative_after := (upper_hub.linear_velocity - lower_hub.linear_velocity).dot(axis)
	if int(main.get("axle_pair_guard_events_v083")) <= guard_before:
		_fail("true next-step order crossing did not activate the sparse guard")
		return
	if lower_hub.global_position.distance_to(lower_pos_before) > 0.000001 or upper_hub.global_position.distance_to(upper_pos_before) > 0.000001:
		_fail("pre-step tunnel guard moved body transforms")
		return
	if relative_after < -0.001:
		_fail("pre-step tunnel guard left the pair closing: %.4f" % relative_after)
		return
	if absf(momentum_after - momentum_before) > 0.0001:
		_fail("free pair guard did not conserve axial momentum")
		return

	# Supported probe. Put the lower owner on its finite O-Ring stop and send the
	# upper hub through it. The stop is allowed to absorb momentum, but the guard
	# must never re-add outward velocity to the O-Ring-supported lower component.
	var lower_bound := float(lower_stop.get("lower", -INF))
	if lower_bound <= -INF:
		_fail("lower hub did not own a finite O-Ring boundary")
		return
	lower_tf = lower_hub.global_transform
	upper_tf = upper_hub.global_transform
	lower_tf.origin = axle.global_position + axis * lower_bound
	upper_tf.origin = axle.global_position + axis * (lower_bound + 0.18)
	lower_hub.global_transform = lower_tf
	upper_hub.global_transform = upper_tf
	lower_hub.linear_velocity = axle.linear_velocity
	upper_hub.linear_velocity = axle.linear_velocity - axis * 12.0
	var supported_before := int(main.get("axle_pair_supported_events_v083"))
	main.call("_predict_axle_order_v073", 1.0 / 60.0)
	var lower_relative := (lower_hub.linear_velocity - axle.linear_velocity).dot(axis)
	var upper_relative := (upper_hub.linear_velocity - axle.linear_velocity).dot(axis)
	if int(main.get("axle_pair_supported_events_v083")) <= supported_before:
		_fail("supported O-Ring case did not use stop-aware dissipation")
		return
	if lower_relative < -0.001:
		_fail("pair guard pushed the supported lower hub back through its O-Ring: %.4f" % lower_relative)
		return
	if upper_relative < lower_relative - 0.001:
		_fail("incoming upper hub remained closing through the supported hub")
		return

	print("ORING_TUNNEL_083_SMOKE_OK: sparse would-cross guard is velocity-only, conserves free-pair momentum, and never pushes an O-Ring-supported hub through its stop")
	main.queue_free()
	await process_frame
	quit(0)
