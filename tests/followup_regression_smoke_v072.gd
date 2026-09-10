extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FOLLOWUP_072_SMOKE_FAIL: %s" % message)
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


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return

	# ------------------------------------------------------------------
	# O-Ring durability: three hubs share one segment. The nearest hubs own the
	# actual ring/rod-end boundaries, while a topology guard prevents an interior
	# hub from tunnelling through its neighbor and thereby bypassing the O-Ring.
	# ------------------------------------------------------------------
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	if not str(main.get_script().resource_path).ends_with("main_v072.gd"):
		_fail("Main is not using v0.5.16 runtime")
		return

	var axle := main.call("_make_rod", 5, Vector3(0, 1, 0), Vector3(0, 20.2, 0)) as RigidBody3D
	var axle_axis := (main.call("_rod_axis_v020", axle) as Vector3).normalized()
	var axle_basis := main.call("_basis_for_axle_v020", axle_axis) as Basis
	var hubs: Array = []
	for y_value in [9.0, 10.0, 11.0]:
		var hub := main.call("_make_connector", 6, Transform3D(axle_basis, Vector3(0, float(y_value), 0))) as RigidBody3D
		var axle_joint := main.call("_make_axle_joint", hub, axle) as Generic6DOFJoint3D
		main.call("_tag_connection_v020", axle_joint, "axle", hub, axle, -1, 0, 0.0, null, false)
		hub.set_meta("axle_occupied", true)
		hubs.append(hub)

	var ring_center := Vector3(0, 7.5, 0)
	var ring := main.call("_make_o_ring_body", Transform3D(axle_basis, ring_center)) as RigidBody3D
	var ring_joint := main.call("_make_fixed_joint", axle, ring, ring_center) as Generic6DOFJoint3D
	var ring_along: float = (ring_center - axle.global_position).dot(axle_axis)
	main.call("_tag_connection_v020", ring_joint, "o_ring", null, axle, -1, 0, ring_along, ring, false)
	ring_joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", axle)
	main.call("_rebuild_connection_graph_v020")

	main.call("_toggle_simulation")
	for _wait in range(8):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start for multi-hub O-Ring fixture")
		return
	var stops := main.get("axle_stop_ranges_v070") as Array
	var hub_stops: Array = []
	for value in stops:
		var stop := value as Dictionary
		if stop.get("rod") == axle and stop.get("connector") in hubs:
			hub_stops.append(stop)
	if hub_stops.size() != 3:
		_fail("multi-hub axle did not produce three tracked stop records")
		return
	if (main.get("axle_order_groups_v073") as Array).is_empty():
		_fail("multi-hub segment did not create an axle order guard")
		return
	var lower_owners := 0
	var upper_owners := 0
	for stop_value in hub_stops:
		var stop := stop_value as Dictionary
		if float(stop.get("lower", -INF)) > -INF:
			lower_owners += 1
		if float(stop.get("upper", INF)) < INF:
			upper_owners += 1
		var component := main.call("_stop_component_v071", stop) as Array
		if axle in component:
			_fail("connector-side O-Ring correction component illegally contains its host axle rod")
			return
	if lower_owners != 1 or upper_owners != 1:
		_fail("three-hub segment should have exactly one physical owner per boundary; lower=%d upper=%d" % [lower_owners, upper_owners])
		return

	# Emulate a missed/tunnelled hub-vs-hub collision directly. The middle hub is
	# placed just below the lower hub while remaining above the O-Ring. Post-step
	# correction must restore its original order instead of letting it become a
	# non-owner below the stop owner.
	var lower_hub := hubs[0] as RigidBody3D
	var middle_hub := hubs[1] as RigidBody3D
	var current_axis := (main.call("_rod_axis_v020", axle) as Vector3).normalized()
	var lower_along_before: float = (lower_hub.global_position - axle.global_position).dot(current_axis)
	var middle_tf := middle_hub.global_transform
	middle_tf.origin = axle.global_position + current_axis * (lower_along_before - 0.18)
	middle_hub.global_transform = middle_tf
	main.call("_correct_axle_stop_positions_v071")
	var lower_after: float = (lower_hub.global_position - axle.global_position).dot(current_axis)
	var middle_after: float = (middle_hub.global_position - axle.global_position).dot(current_axis)
	if middle_after <= lower_after:
		_fail("hub-order guard did not restore an interior hub after simulated tunnelling")
		return
	if int(main.get("axle_order_guard_events_v073")) < 1:
		_fail("hub-order tunnelling correction did not register")
		return

	for hub_value in hubs:
		var hub := hub_value as RigidBody3D
		hub.linear_velocity = Vector3(0, -18.0, 0)
	var min_ring_gap := INF
	for _frame in range(420):
		await physics_frame
		main.call("_sync_o_ring_followers_v068")
		for hub_value in hubs:
			var hub := hub_value as RigidBody3D
			var axis_now := (main.call("_rod_axis_v020", axle) as Vector3).normalized()
			var along: float = (hub.global_position - axle.global_position).dot(axis_now)
			var current_ring_along: float = (ring.global_position - axle.global_position).dot(axis_now)
			min_ring_gap = minf(min_ring_gap, along - current_ring_along)
			if along < current_ring_along + 0.31:
				_fail("an axle hub crossed the O-Ring in the three-hub fixture: gap=%.3f" % (along - current_ring_along))
				return

	main.call("_toggle_simulation")
	for _wait in range(4):
		await physics_frame

	# Larger screen-space O-Ring touch target.
	var camera := main.get("camera") as Camera3D
	camera.global_position = ring.global_position + Vector3(6.0, 4.0, 7.0)
	camera.look_at(ring.global_position, Vector3.UP)
	var ring_screen := camera.unproject_position(ring.global_position)
	var picked_ring := main.call("_pick_o_ring_touch_v072", ring_screen + Vector2(64.0, 0.0)) as RigidBody3D
	if picked_ring != ring:
		_fail("O-Ring enlarged touch target did not accept a 64px-offset tap")
		return

	main.queue_free()
	await process_frame

	# ------------------------------------------------------------------
	# Explicit reconnect of one socket re-enables another aligned rod from the
	# same Disconnect operation.
	# ------------------------------------------------------------------
	main = packed.instantiate()
	root.add_child(main)
	await process_frame
	var reconnect_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(30, 8, 24))) as RigidBody3D
	var reconnect_rod_a := _add_socket_rod(main, reconnect_connector, 0)
	var reconnect_rod_b := _add_socket_rod(main, reconnect_connector, 90)
	main.call("_rebuild_connection_graph_v020")
	main.set("selected_piece", reconnect_connector)
	main.call("_disconnect_selected_v042")
	main.call("_rebuild_connection_graph_v020")
	if not _find_record(main, "socket", reconnect_connector, reconnect_rod_a).is_empty() or not _find_record(main, "socket", reconnect_connector, reconnect_rod_b).is_empty():
		_fail("Disconnect fixture did not detach both connector rods")
		return
	var source_socket := {"type": "socket", "body": reconnect_connector, "slot": 0, "point": (main.call("_socket_world_v020", reconnect_connector, 0) as Dictionary).get("point", Vector3.ZERO)}
	var target_end := {"type": "rod_end", "body": reconnect_rod_a, "sign": -1, "point": main.call("_rod_end_v020", reconnect_rod_a, -1)}
	if not bool(main.call("_connect_points_v032", source_socket, target_end, 0)):
		_fail("explicit first socket reconnect failed")
		return
	main.call("_rebuild_connection_graph_v020")
	if _find_record(main, "socket", reconnect_connector, reconnect_rod_a).is_empty():
		_fail("first explicitly reconnected rod is missing")
		return
	if _find_record(main, "socket", reconnect_connector, reconnect_rod_b).is_empty():
		_fail("second aligned detached rod did not auto-snap back after first reconnect")
		return

	# ------------------------------------------------------------------
	# Multi-rod re-seat: rotate only the connector and permute socket assignments
	# while rods and their far-end structures stay fixed.
	# ------------------------------------------------------------------
	var center_connector := main.call("_make_connector", 4, Transform3D(Basis.IDENTITY, Vector3(70, 10, 36))) as RigidBody3D
	var rod_a := _add_socket_rod(main, center_connector, 45)
	var rod_b := _add_socket_rod(main, center_connector, 90)
	var far_a := _add_far_connector(main, rod_a)
	var far_b := _add_far_connector(main, rod_b)
	main.call("_rebuild_connection_graph_v020")
	var rec_a := _find_record(main, "socket", center_connector, rod_a)
	var rec_b := _find_record(main, "socket", center_connector, rod_b)
	if rec_a.is_empty() or rec_b.is_empty():
		_fail("multi-rod re-seat fixture did not build both central mounts")
		return
	var rod_a_before := rod_a.global_transform
	var rod_b_before := rod_b.global_transform
	var far_a_before := far_a.global_transform
	var far_b_before := far_b.global_transform
	var center_before := center_connector.global_transform
	var preview := main.call("_reseat_record_preview_v070", center_connector, rec_a, 0) as Dictionary
	if not bool(preview.get("valid", false)):
		_fail("anchored two-rod socket rotation was rejected: %s" % str(preview.get("reason", "unknown")))
		return
	if not bool(main.call("_apply_reseat_record_v070", center_connector, rec_a, 0)):
		_fail("anchored two-rod socket rotation did not apply")
		return
	main.call("_rebuild_connection_graph_v020")
	if rod_a.global_transform.origin.distance_to(rod_a_before.origin) > 0.0005 or not rod_a.global_transform.basis.is_equal_approx(rod_a_before.basis):
		_fail("multi-rod re-seat moved rod A")
		return
	if rod_b.global_transform.origin.distance_to(rod_b_before.origin) > 0.0005 or not rod_b.global_transform.basis.is_equal_approx(rod_b_before.basis):
		_fail("multi-rod re-seat moved rod B")
		return
	if far_a.global_transform.origin.distance_to(far_a_before.origin) > 0.0005 or far_b.global_transform.origin.distance_to(far_b_before.origin) > 0.0005:
		_fail("multi-rod re-seat moved the far-end structures")
		return
	if center_connector.global_transform.basis.is_equal_approx(center_before.basis):
		_fail("multi-rod re-seat did not rotate the connector")
		return
	var rec_a_after := _find_record(main, "socket", center_connector, rod_a)
	var rec_b_after := _find_record(main, "socket", center_connector, rod_b)
	if int(rec_a_after.get("slot", -1)) != 0:
		_fail("target rod did not move from socket 45 to socket 0")
		return
	if int(rec_b_after.get("slot", -1)) != 45:
		_fail("second rod did not remap from socket 90 to socket 45")
		return

	print("FOLLOWUP_072_SMOKE_OK: multi-hub O-Ring tunnelling guard + large ring touch target + reconnect auto-resnap + fixed-rod multi-socket re-seat")
	main.queue_free()
	await process_frame
	quit(0)
