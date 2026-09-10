extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ORING_PHYSICAL_083_FAIL: %s" % message)
	quit(1)


func _along(main: Node, body: Node3D, rod: RigidBody3D) -> float:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	return (body.global_position - rod.global_position).dot(axis)


func _add_axle(main: Node, connector: RigidBody3D, rod: RigidBody3D) -> Generic6DOFJoint3D:
	var joint := main.call("_make_axle_joint", connector, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", connector, rod, -1, 0, 0.0, null, false)
	connector.set_meta("axle_occupied", true)
	return joint


func _add_ring(main: Node, rod: RigidBody3D, along: float) -> Dictionary:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var center := rod.global_position + axis * along
	var basis := Basis(Quaternion(Vector3.UP, axis))
	var ring := main.call("_make_o_ring_body", Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, ring, center) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	return {"ring": ring, "joint": joint}


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	if not str(main.get_script().resource_path).ends_with("main_v083.gd"):
		_fail("Main is not using main_v083.gd")
		return

	var rod := main.call("_make_rod", 4, Vector3(0, 8, 0), Vector3(0, 24, 0)) as RigidBody3D
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var hub := main.call("_make_connector", 6, Transform3D(main.call("_basis_for_axle_v020", axis), Vector3(0, 19.5, 0))) as RigidBody3D
	var axle_joint := _add_axle(main, hub, rod)
	var ring_info := _add_ring(main, rod, -2.0)
	var ring := ring_info.get("ring") as RigidBody3D
	var ring_joint := ring_info.get("joint") as Generic6DOFJoint3D
	main.call("_rebuild_connection_graph_v020")
	var initial_ring_along := _along(main, ring, rod)

	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	if ring_joint.node_a.is_empty() or ring_joint.node_b.is_empty():
		_fail("O-Ring fixed mount was detached during SIMULATE")
		return
	if ring.freeze:
		_fail("O-Ring remained frozen instead of participating as a rod-pinned physical body")
		return
	if ring.collision_layer != 8 or ring.collision_mask != 16:
		_fail("O-Ring does not use connector-only simulation collision layers")
		return
	if (hub.collision_layer & 16) == 0 or (hub.collision_mask & 8) == 0:
		_fail("AXLE connector cannot see the O-Ring collision layer")
		return
	if not (main.get("axle_stop_ranges_v070") as Array).is_empty():
		_fail("scripted axle stop ranges are still active")
		return
	var hitbox_count := 0
	for child_value in ring.get_children():
		var child := child_value as CollisionShape3D
		if child != null and bool(child.get_meta("o_ring_sim_hitbox_v083", false)):
			hitbox_count += 1
	if hitbox_count != 1:
		_fail("expected exactly one dedicated O-Ring simulation hitbox")
		return
	if bool(axle_joint.get("linear_limit_y/enabled")) or bool(axle_joint.get("angular_limit_y/enabled")):
		_fail("normal AXLE slide/rotation was modified")
		return

	# Give only the hub a hard downward relative impact toward the ring. Collision,
	# not a scripted stop, must keep the hub on the original side.
	hub.linear_velocity = axis * -18.0
	hub.angular_velocity = Vector3.ZERO
	var min_gap := INF
	var max_ring_drift := 0.0
	var vmax := 0.0
	var wmax := 0.0
	for _frame in range(300):
		await physics_frame
		var ring_along := _along(main, ring, rod)
		var hub_along := _along(main, hub, rod)
		min_gap = minf(min_gap, hub_along - ring_along)
		max_ring_drift = maxf(max_ring_drift, absf(ring_along - initial_ring_along))
		vmax = maxf(vmax, hub.linear_velocity.length(), rod.linear_velocity.length(), ring.linear_velocity.length())
		wmax = maxf(wmax, hub.angular_velocity.length(), rod.angular_velocity.length(), ring.angular_velocity.length())
		if hub_along < ring_along + 0.24:
			_fail("AXLE connector phased through physical O-Ring: gap=%.3f" % (hub_along - ring_along))
			return
		if vmax > 70.0 or wmax > 120.0:
			_fail("physical O-Ring contact became unstable: vmax=%.2f wmax=%.2f" % [vmax, wmax])
			return

	if max_ring_drift > 0.08:
		_fail("O-Ring fixed mount drifted too far along rod: %.4f" % max_ring_drift)
		return

	main.call("_toggle_simulation")
	for _i in range(4):
		await physics_frame
	if ring.collision_layer != 2 or ring.collision_mask != 3:
		_fail("BUILD O-Ring collision policy was not restored")
		return
	if not ring.freeze:
		_fail("O-Ring did not return to editable frozen BUILD state")
		return

	print("ORING_PHYSICAL_083_OK: fixed rod mount + independent connector collider stopped AXLE physically; min_gap=%.3f drift=%.4f vmax=%.2f wmax=%.2f" % [min_gap, max_ring_drift, vmax, wmax])
	main.queue_free()
	await process_frame
	quit(0)
