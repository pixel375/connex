extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ORING_PAIR_DIAG_074_FAIL: %s" % message)
	quit(1)


func _add_axle(main: Node, connector: RigidBody3D, rod: RigidBody3D, along: float) -> void:
	var joint := main.call("_make_axle_joint", connector, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", connector, rod, -1, 0, along, null, false)
	connector.set_meta("axle_occupied", true)


func _add_spoke(main: Node, connector: RigidBody3D, slot: int) -> void:
	var socket := main.call("_socket_world_v020", connector, slot) as Dictionary
	var start: Vector3 = socket.get("point", connector.global_position) as Vector3
	var direction: Vector3 = (socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var rod := main.call("_make_rod", 2, start, start + direction * 5.5) as RigidBody3D
	var joint := main.call("_make_fixed_joint", connector, rod, start) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "socket", connector, rod, slot, -1, 0.0, null, false)
	main.call("_set_connector_occupied", connector, slot, true)
	main.call("_set_rod_end_occupied", rod, -1, true)


func _add_ring(main: Node, rod: RigidBody3D, along: float) -> RigidBody3D:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var center := rod.global_position + axis * along
	var basis := Basis(Quaternion(Vector3.UP, axis))
	var ring := main.call("_make_o_ring_body", Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, ring, center) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	return ring


func _along(main: Node, body: Node3D, rod: RigidBody3D) -> float:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	return (body.global_position - rod.global_position).dot(axis)


func _stop_summary(main: Node, hub_a: RigidBody3D, hub_b: RigidBody3D) -> String:
	var parts: Array[String] = []
	for value in main.get("axle_stop_ranges_v070") as Array:
		var stop := value as Dictionary
		var connector := stop.get("connector") as RigidBody3D
		var label := "A" if connector == hub_a else ("B" if connector == hub_b else "?")
		parts.append("%s:[%.3f,%.3f] seg=%s" % [label, float(stop.get("lower", -INF)), float(stop.get("upper", INF)), str(stop.get("segment", "?"))])
	return "; ".join(parts)


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	var requested_rigidity := OS.get_environment("ORING_PAIR_RIGIDITY").strip_edges()
	if not requested_rigidity.is_empty():
		main.set("physics_structure_rigidity_v066", float(requested_rigidity))
	print("ORING_PAIR_DIAG_CONFIG rigidity=%.1f requested=%s" % [float(main.get("physics_structure_rigidity_v066")), requested_rigidity if not requested_rigidity.is_empty() else "persisted/default"])

	var axle := main.call("_make_rod", 4, Vector3(0, 13, 0), Vector3(0, 29, 0)) as RigidBody3D
	var hub_a := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0, 19, 0))) as RigidBody3D
	var hub_b := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0, 23, 0))) as RigidBody3D
	_add_axle(main, hub_a, axle, -2.0)
	_add_axle(main, hub_b, axle, 2.0)
	for slot in [0, 90, 180]:
		_add_spoke(main, hub_a, slot)
	for slot in [45, 135]:
		_add_spoke(main, hub_b, slot)
	var ring_low := _add_ring(main, axle, -3.0)
	_add_ring(main, axle, 6.0)
	main.call("_rebuild_connection_graph_v020")

	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	for _i in range(72):
		await physics_frame
		main.call("_sync_o_ring_followers_v068")

	var previous_pair_gap := INF
	var previous_a_rel := 0.0
	var previous_b_rel := 0.0
	var previous_guard := int(main.get("axle_pair_guard_events_v074"))
	for frame_index in range(360):
		await physics_frame
		main.call("_sync_o_ring_followers_v068")
		var axis := (main.call("_rod_axis_v020", axle) as Vector3).normalized()
		var low := _along(main, ring_low, axle)
		var a := _along(main, hub_a, axle)
		var b := _along(main, hub_b, axle)
		var pair_gap := b - a
		var a_rel := (hub_a.linear_velocity - axle.linear_velocity).dot(axis)
		var b_rel := (hub_b.linear_velocity - axle.linear_velocity).dot(axis)
		var guard := int(main.get("axle_pair_guard_events_v074"))
		if pair_gap < 0.75 or b - low < 0.45:
			print("ORING_PAIR_DIAG_SAMPLE frame=%d a=%.4f b=%.4f low=%.4f a_low=%.4f b_low=%.4f pair=%.4f a_rel=%.4f b_rel=%.4f rel=%.4f guard=%d prev_pair=%.4f prev_a_rel=%.4f prev_b_rel=%.4f prev_guard=%d stops=%s" % [frame_index, a, b, low, a-low, b-low, pair_gap, a_rel, b_rel, b_rel-a_rel, guard, previous_pair_gap, previous_a_rel, previous_b_rel, previous_guard, _stop_summary(main, hub_a, hub_b)])
		if pair_gap < 0.0 or b - low < 0.31:
			print("ORING_PAIR_DIAG_074_OK: captured first missed pair/boundary event at frame %d" % frame_index)
			main.queue_free()
			await process_frame
			quit(0)
			return
		previous_pair_gap = pair_gap
		previous_a_rel = a_rel
		previous_b_rel = b_rel
		previous_guard = guard

	print("ORING_PAIR_DIAG_074_OK: no inversion/boundary event in 360 frames; guard=%d min pair remained nonnegative" % int(main.get("axle_pair_guard_events_v074")))
	main.queue_free()
	await process_frame
	quit(0)
