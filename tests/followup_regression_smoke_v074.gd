extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FOLLOWUP_074_SMOKE_FAIL: %s" % message)
	quit(1)


func _find_record(main: Node, kind: String, connector: RigidBody3D, rod: RigidBody3D) -> Dictionary:
	main.call("_rebuild_connection_graph_v020")
	for value in (main.get("connections_v020") as Array):
		var record := value as Dictionary
		if str(record.get("kind", "")) == kind and record.get("connector") == connector and record.get("rod") == rod:
			return record
	return {}


func _add_socket_rod(main: Node, connector: RigidBody3D, slot: int, length: float = 5.5) -> RigidBody3D:
	var socket := main.call("_socket_world_v020", connector, slot) as Dictionary
	var start: Vector3 = socket.get("point", connector.global_position) as Vector3
	var direction: Vector3 = (socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var rod := main.call("_make_rod", 2, start, start + direction * length) as RigidBody3D
	var joint := main.call("_make_fixed_joint", connector, rod, start) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "socket", connector, rod, slot, -1, 0.0, null, false)
	main.call("_set_connector_occupied", connector, slot, true)
	main.call("_set_rod_end_occupied", rod, -1, true)
	return rod


func _add_far_connector(main: Node, rod: RigidBody3D) -> RigidBody3D:
	var sign_value := 1
	var end_pos := main.call("_rod_end_v020", rod, sign_value) as Vector3
	var outward := (main.call("_rod_axis_v020", rod) as Vector3).normalized() * float(sign_value)
	var basis := main.call("_basis_align_direction_v020", main.call("_slot_dir", 0), -outward, Vector3.UP) as Basis
	var center := end_pos + outward * 1.01
	var connector := main.call("_make_connector", 0, Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, connector, end_pos) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "socket", connector, rod, 0, sign_value, 0.0, null, false)
	main.call("_set_connector_occupied", connector, 0, true)
	main.call("_set_rod_end_occupied", rod, sign_value, true)
	return connector


func _add_o_ring(main: Node, rod: RigidBody3D, along: float) -> Dictionary:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var center := rod.global_position + axis * along
	var basis := main.call("_basis_for_axle_v020", axis) as Basis
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
	if not str(main.get_script().resource_path).ends_with("main_v074.gd"):
		_fail("Main is not using final v0.5.16 runtime")
		return

	# O-Ring selection and final SIMULATE collision architecture.
	var axle := main.call("_make_rod", 5, Vector3(0, 2, 0), Vector3(0, 21.2, 0)) as RigidBody3D
	var axis := (main.call("_rod_axis_v020", axle) as Vector3).normalized()
	var axle_basis := main.call("_basis_for_axle_v020", axis) as Basis
	var hub := main.call("_make_connector", 6, Transform3D(axle_basis, Vector3(0, 12, 0))) as RigidBody3D
	var axle_joint := main.call("_make_axle_joint", hub, axle) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", axle_joint, "axle", hub, axle, -1, 0, 0.0, null, false)
	hub.set_meta("axle_occupied", true)
	var ring_info := _add_o_ring(main, axle, -2.0)
	var ring := ring_info.get("ring") as RigidBody3D
	main.call("_rebuild_connection_graph_v020")

	var camera := main.get("camera") as Camera3D
	camera.global_position = ring.global_position + Vector3(6.0, 4.0, 7.0)
	camera.look_at(ring.global_position, Vector3.UP)
	var ring_screen := camera.unproject_position(ring.global_position)
	if main.call("_pick_o_ring_touch_v072", ring_screen + Vector2(64.0, 0.0)) != ring:
		_fail("O-Ring enlarged touch target did not accept a 64px-offset tap")
		return

	main.call("_toggle_simulation")
	for _i in range(8):
		await physics_frame
	if ring.collision_layer != 8 or ring.collision_mask != 16:
		_fail("O-Ring is not using the connector-only simulation collision policy")
		return
	var collars := main.get("o_ring_sim_colliders_v074") as Array
	if collars.size() != 1:
		_fail("expected exactly one temporary O-Ring simulation collar")
		return
	var collar := collars[0] as CollisionShape3D
	if not is_instance_valid(collar) or not (collar.shape is CylinderShape3D):
		_fail("O-Ring simulation collar is missing its cylinder shape")
		return
	if float((collar.shape as CylinderShape3D).height) < 0.49:
		_fail("O-Ring simulation collar is not thick enough to absorb solver contact slop")
		return
	if bool(axle_joint.get("linear_limit_y/enabled")) or bool(axle_joint.get("angular_limit_y/enabled")):
		_fail("normal AXLE joint was modified by the O-Ring stop")
		return
	if not (main.get("o_ring_axle_stop_joints_v074") as Array).is_empty():
		_fail("abandoned extra AXLE stop joints still exist")
		return
	main.call("_toggle_simulation")
	for _i in range(4):
		await physics_frame
	if not (main.get("o_ring_sim_colliders_v074") as Array).is_empty():
		_fail("temporary O-Ring collar leaked back into BUILD")
		return
	if ring.collision_layer != 2 or ring.collision_mask != 3:
		_fail("O-Ring BUILD collision policy was not restored")
		return

	# CROSS from a socket must clip to the rod side/midpoint, not insert a rod end.
	var cross_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(30, 8, 20))) as RigidBody3D
	main.set("selected_rod_type", 2)
	if not bool(main.call("_create_cross_rod_from_socket_v072", cross_connector, 0)):
		_fail("CROSS socket-to-rod creation failed")
		return
	var cross_rod := main.get("selected_piece") as RigidBody3D
	if not is_instance_valid(cross_rod) or str(cross_rod.get_meta("kind", "")) != "rod":
		_fail("CROSS did not create/select a rod")
		return
	var cross_socket := main.call("_socket_world_v020", cross_connector, 0) as Dictionary
	var cross_anchor := cross_socket.get("point", Vector3.ZERO) as Vector3
	if cross_rod.global_position.distance_to(cross_anchor) > 0.03:
		_fail("CROSS rod midpoint is not located at the connector socket")
		return
	var cross_axis := (main.call("_rod_axis_v020", cross_rod) as Vector3).normalized()
	var socket_dir := (cross_socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	if absf(cross_axis.dot(socket_dir)) > 0.08:
		_fail("CROSS rod is not perpendicular/side-mounted to the socket")
		return
	var cross_record := _find_record(main, "cross", cross_connector, cross_rod)
	if cross_record.is_empty():
		_fail("CROSS rod did not create a CROSS connection record")
		return
	var ends := cross_rod.get_meta("end_occupied", {}) as Dictionary
	if ends.has(-1) or ends.has(1):
		_fail("CROSS side-middle mount incorrectly consumed a rod end")
		return

	# Reconnecting one socket should release and re-snap another aligned rod from
	# the same explicit Disconnect operation.
	var reconnect_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(50, 8, 24))) as RigidBody3D
	var reconnect_rod_a := _add_socket_rod(main, reconnect_connector, 0)
	var reconnect_rod_b := _add_socket_rod(main, reconnect_connector, 90)
	main.call("_rebuild_connection_graph_v020")
	main.set("selected_piece", reconnect_connector)
	main.call("_disconnect_selected_v042")
	main.call("_rebuild_connection_graph_v020")
	var source_socket := {"type": "socket", "body": reconnect_connector, "slot": 0, "point": (main.call("_socket_world_v020", reconnect_connector, 0) as Dictionary).get("point", Vector3.ZERO)}
	var target_end := {"type": "rod_end", "body": reconnect_rod_a, "sign": -1, "point": main.call("_rod_end_v020", reconnect_rod_a, -1)}
	if not bool(main.call("_connect_points_v032", source_socket, target_end, 0)):
		_fail("explicit first socket reconnect failed")
		return
	if _find_record(main, "socket", reconnect_connector, reconnect_rod_b).is_empty():
		_fail("second aligned detached rod did not auto-snap after first reconnect")
		return

	# A connector with two rods anchored at their far ends must still be able to
	# rotate/re-seat by one socket while rods and remote structures stay fixed.
	var center_connector := main.call("_make_connector", 4, Transform3D(Basis.IDENTITY, Vector3(75, 10, 36))) as RigidBody3D
	var rod_a := _add_socket_rod(main, center_connector, 45)
	var rod_b := _add_socket_rod(main, center_connector, 90)
	var far_a := _add_far_connector(main, rod_a)
	var far_b := _add_far_connector(main, rod_b)
	main.call("_rebuild_connection_graph_v020")
	var rec_a := _find_record(main, "socket", center_connector, rod_a)
	if rec_a.is_empty():
		_fail("multi-rod re-seat fixture did not create its primary mount")
		return
	var rod_a_before := rod_a.global_transform
	var rod_b_before := rod_b.global_transform
	var far_a_before := far_a.global_transform
	var far_b_before := far_b.global_transform
	var center_before := center_connector.global_transform
	var preview := main.call("_reseat_record_preview_v070", center_connector, rec_a, 0) as Dictionary
	if not bool(preview.get("valid", false)):
		_fail("two-rod anchored connector re-seat was rejected: %s" % str(preview.get("reason", "unknown")))
		return
	if not bool(main.call("_apply_reseat_record_v070", center_connector, rec_a, 0)):
		_fail("two-rod anchored connector re-seat did not apply")
		return
	if center_connector.global_transform.origin.distance_to(center_before.origin) < 0.0001 and center_connector.global_transform.basis.is_equal_approx(center_before.basis):
		_fail("connector did not rotate/re-seat")
		return
	for pair in [[rod_a, rod_a_before], [rod_b, rod_b_before], [far_a, far_a_before], [far_b, far_b_before]]:
		var body := pair[0] as RigidBody3D
		var before := pair[1] as Transform3D
		if body.global_transform.origin.distance_to(before.origin) > 0.0005 or not body.global_transform.basis.is_equal_approx(before.basis):
			_fail("multi-rod re-seat moved an anchored rod/remote structure")
			return

	print("FOLLOWUP_074_SMOKE_OK: O-Ring touch/collar + side-middle CROSS + reconnect auto-resnap + anchored multi-rod re-seat")
	main.queue_free()
	await process_frame
	quit(0)
