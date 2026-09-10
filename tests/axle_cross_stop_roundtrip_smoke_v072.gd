extends SceneTree

const HUB_TYPE := 6 # White 8-way
const STOP_TYPE := 0 # Gray 1-way
const FRAME_ROD_TYPE := 2 # Blue 54 / 5.5 world units
const HOST_ROD_TYPE := 5 # Long host shaft
const CONNECTOR_D_TEST := 1.01
const FRAME_SPACING := 5.5 + CONNECTOR_D_TEST * 2.0
const FRAME_Y := 14.0
const STOP_Y := 9.25


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("AXLE_CROSS_ROUNDTRIP_072_SMOKE_FAIL: %s" % message)
	quit(1)


func _uid(body: RigidBody3D) -> int:
	return int(body.get_meta("piece_uid_v020", -1)) if is_instance_valid(body) else -1


func _find_uid(main: Node, uid_value: int) -> RigidBody3D:
	for body_value in (main.get("bodies") as Array):
		var body := body_value as RigidBody3D
		if is_instance_valid(body) and int(body.get_meta("piece_uid_v020", -1)) == uid_value:
			return body
	return null


func _along(main: Node, body: Node3D, rod: RigidBody3D) -> float:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	return (body.global_position - rod.global_position).dot(axis)


func _add_exact_socket_rod(main: Node, a: RigidBody3D, slot_a: int, b: RigidBody3D, slot_b: int) -> RigidBody3D:
	var socket_a := main.call("_socket_world_v020", a, slot_a) as Dictionary
	var socket_b := main.call("_socket_world_v020", b, slot_b) as Dictionary
	var point_a := socket_a.get("point", a.global_position) as Vector3
	var point_b := socket_b.get("point", b.global_position) as Vector3
	var rod := main.call("_make_rod", FRAME_ROD_TYPE, point_a, point_b) as RigidBody3D
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


func _add_cross_stop(main: Node, rod: RigidBody3D, world_y: float, radial_hint: Vector3) -> RigidBody3D:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var slot: int = 0
	var local_slot := main.call("_slot_dir", slot) as Vector3
	var radial := radial_hint - axis * radial_hint.dot(axis)
	if radial.length_squared() < 0.1:
		radial = Vector3.RIGHT
	radial = radial.normalized()
	var basis := main.call("_basis_for_cross_v020", local_slot, axis, radial) as Basis
	var actual_radial := (basis * local_slot).normalized()
	var along := (Vector3(rod.global_position.x, world_y, rod.global_position.z) - rod.global_position).dot(axis)
	var snap_point := rod.global_position + axis * along
	var center := snap_point - actual_radial * CONNECTOR_D_TEST
	var stop := main.call("_make_connector", STOP_TYPE, Transform3D(basis, center)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, stop, snap_point) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "cross", stop, rod, slot, 0, along, null, true)
	joint.set_meta("cross_mount", true)
	stop.set_meta("cross_mount", true)
	stop.set_meta("cross_host_rod", rod)
	stop.set_meta("primary_connection_uid_v020", int(joint.get_meta("connection_uid_v020", -1)))
	main.call("_set_connector_occupied", stop, slot, true)
	stop.set_meta("build_transform", stop.global_transform)
	return stop


func _add_axle(main: Node, hub: RigidBody3D, rod: RigidBody3D) -> Generic6DOFJoint3D:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var along := (hub.global_position - rod.global_position).dot(axis)
	var joint := main.call("_make_axle_joint", hub, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", hub, rod, -1, 0, along, null, true)
	hub.set_meta("axle_occupied", true)
	hub.set_meta("axle_host_rod", rod)
	hub.set_meta("primary_connection_uid_v020", int(joint.get_meta("connection_uid_v020", -1)))
	return joint


func _build_four_post_fixture(main: Node) -> Dictionary:
	var half := FRAME_SPACING * 0.5
	var positions := [
		Vector3(-half, FRAME_Y, -half),
		Vector3(half, FRAME_Y, -half),
		Vector3(half, FRAME_Y, half),
		Vector3(-half, FRAME_Y, half),
	]
	var hubs: Array = []
	for position_value in positions:
		var hub := main.call("_make_connector", HUB_TYPE, Transform3D(Basis.IDENTITY, position_value as Vector3)) as RigidBody3D
		hub.set_meta("build_transform", hub.global_transform)
		hubs.append(hub)

	# One rigid square frame, matching the user's four AXLE hubs joined by rods.
	_add_exact_socket_rod(main, hubs[0] as RigidBody3D, 0, hubs[1] as RigidBody3D, 180)
	_add_exact_socket_rod(main, hubs[1] as RigidBody3D, 270, hubs[2] as RigidBody3D, 90)
	_add_exact_socket_rod(main, hubs[2] as RigidBody3D, 180, hubs[3] as RigidBody3D, 0)
	_add_exact_socket_rod(main, hubs[3] as RigidBody3D, 90, hubs[0] as RigidBody3D, 270)

	var rods: Array = []
	var stops: Array = []
	var host_bottom := 0.55
	var host_top := host_bottom + 19.2
	for i in range(4):
		var position := positions[i] as Vector3
		var rod := main.call("_make_rod", HOST_ROD_TYPE, Vector3(position.x, host_bottom, position.z), Vector3(position.x, host_top, position.z)) as RigidBody3D
		rod.set_meta("build_transform", rod.global_transform)
		var radial_hints := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
		var stop := _add_cross_stop(main, rod, STOP_Y, radial_hints[i] as Vector3)
		_add_axle(main, hubs[i] as RigidBody3D, rod)
		rods.append(rod)
		stops.append(stop)

	main.call("_rebuild_connection_graph_v020")
	main.call("_refresh_joint_frames_v020")
	main.call("_rebuild_connection_graph_v020")
	return {"hubs": hubs, "rods": rods, "stops": stops}


func _assert_axle_graph(main: Node, hub_uids: Array, rod_uids: Array, label: String) -> void:
	main.call("_rebuild_connection_graph_v020")
	var found := 0
	for record_value in (main.get("connections_v020") as Array):
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var hub := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(hub) or not is_instance_valid(rod):
			continue
		if _uid(hub) not in hub_uids or _uid(rod) not in rod_uids:
			continue
		var joint := record.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			_fail("%s: restored AXLE has no live joint" % label)
			return
		if bool(joint.get("linear_limit_y/enabled")) or bool(joint.get("angular_limit_y/enabled")):
			_fail("%s: AXLE free Y slide/rotation was lost" % label)
			return
		if not bool(joint.get("linear_limit_x/enabled")) or not bool(joint.get("linear_limit_z/enabled")):
			_fail("%s: AXLE lateral centering constraint was lost" % label)
			return
		found += 1
	if found != 4:
		_fail("%s: expected 4 authoritative AXLE connections, found %d" % [label, found])


func _resolve_fixture(main: Node, hub_uids: Array, rod_uids: Array, stop_uids: Array) -> Dictionary:
	var hubs: Array = []
	var rods: Array = []
	var stops: Array = []
	for uid_value in hub_uids:
		hubs.append(_find_uid(main, int(uid_value)))
	for uid_value in rod_uids:
		rods.append(_find_uid(main, int(uid_value)))
	for uid_value in stop_uids:
		stops.append(_find_uid(main, int(uid_value)))
	for i in range(4):
		if not is_instance_valid(hubs[i] as RigidBody3D) or not is_instance_valid(rods[i] as RigidBody3D) or not is_instance_valid(stops[i] as RigidBody3D):
			_fail("save/load did not restore fixture UID %d" % i)
			return {}
	return {"hubs": hubs, "rods": rods, "stops": stops}


func _run_fixture(main: Node, fixture: Dictionary, label: String) -> Array:
	var hubs := fixture.get("hubs") as Array
	var rods := fixture.get("rods") as Array
	var stops := fixture.get("stops") as Array
	var start_gaps: Array = []
	for i in range(4):
		start_gaps.append(_along(main, hubs[i] as RigidBody3D, rods[i] as RigidBody3D) - _along(main, stops[i] as RigidBody3D, rods[i] as RigidBody3D))

	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("%s: simulation did not start" % label)
		return []

	# Model the four vertical shafts having reached/supported themselves on the
	# floor. The joined white frame is still dynamic and must slide on all 4 AXLEs.
	for i in range(4):
		var rod := rods[i] as RigidBody3D
		rod.freeze = true
		rod.linear_velocity = Vector3.ZERO
		rod.angular_velocity = Vector3.ZERO
		var hub := hubs[i] as RigidBody3D
		hub.sleeping = false
		if hub.can_sleep:
			_fail("%s: AXLE hub/fixed frame can still sleep" % label)
			return []
		var stop := stops[i] as RigidBody3D
		if stop in hub.get_collision_exceptions():
			_fail("%s: AXLE hub is collision-excluded from its ordinary CROSS stop" % label)
			return []

	var min_gaps: Array = [INF, INF, INF, INF]
	for frame_index in range(240):
		await physics_frame
		for i in range(4):
			var hub := hubs[i] as RigidBody3D
			var rod := rods[i] as RigidBody3D
			var stop := stops[i] as RigidBody3D
			var gap := _along(main, hub, rod) - _along(main, stop, rod)
			min_gaps[i] = minf(float(min_gaps[i]), gap)
			if gap < 0.05:
				_fail("%s: AXLE hub %d passed through Gray 1-way CROSS stop at frame %d (gap %.3f)" % [label, i, frame_index, gap])
				return []

	var end_gaps: Array = []
	for i in range(4):
		var end_gap := _along(main, hubs[i] as RigidBody3D, rods[i] as RigidBody3D) - _along(main, stops[i] as RigidBody3D, rods[i] as RigidBody3D)
		end_gaps.append(end_gap)
		var travel := float(start_gaps[i]) - end_gap
		if travel < 1.0:
			_fail("%s: AXLE hub %d remained stuck instead of sliding (travel %.3f)" % [label, i, travel])
			return []

	main.call("_toggle_simulation")
	for _i in range(5):
		await physics_frame
	if bool(main.get("simulating")):
		_fail("%s: failed to return to BUILD" % label)
		return []
	return end_gaps


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v072.gd"):
		_fail("Main is not using v0.5.17 candidate runtime")
		return

	var fixture := _build_four_post_fixture(main)
	var hubs := fixture.get("hubs") as Array
	var rods := fixture.get("rods") as Array
	var stops := fixture.get("stops") as Array
	var hub_uids: Array = []
	var rod_uids: Array = []
	var stop_uids: Array = []
	for i in range(4):
		hub_uids.append(_uid(hubs[i] as RigidBody3D))
		rod_uids.append(_uid(rods[i] as RigidBody3D))
		stop_uids.append(_uid(stops[i] as RigidBody3D))

	_assert_axle_graph(main, hub_uids, rod_uids, "fresh build")
	var first_end := await _run_fixture(main, fixture, "fresh build")
	if first_end.is_empty():
		return

	# Exercise the exact named-save bundle restore path used by the app. The same
	# stable UIDs must come back as the same 4 AXLE hubs, shafts and CROSS stops.
	var bundle := main.call("_save_bundle_v050", "RoundTrip072") as Dictionary
	if bundle.is_empty():
		_fail("could not capture named-save bundle")
		return
	if not bool(main.call("_restore_bundle_v050", bundle, "RoundTrip072")):
		_fail("named-save bundle restore failed")
		return
	await process_frame
	var restored := _resolve_fixture(main, hub_uids, rod_uids, stop_uids)
	if restored.is_empty():
		return
	_assert_axle_graph(main, hub_uids, rod_uids, "after save/load")
	var second_end := await _run_fixture(main, restored, "after save/load")
	if second_end.is_empty():
		return

	# Contact height may vary slightly with solver ordering, but save/load must not
	# turn the same mechanism into a frozen slider or ghost collision.
	for i in range(4):
		if absf(float(first_end[i]) - float(second_end[i])) > 0.45:
			_fail("save/load changed AXLE stop result for hub %d: fresh %.3f restored %.3f" % [i, float(first_end[i]), float(second_end[i])])
			return

	print("AXLE_CROSS_ROUNDTRIP_072_SMOKE_OK: four-hub frame slid on 4 AXLEs, stopped on ordinary Gray 1-way CROSS connectors, and repeated after named save/load")
	main.queue_free()
	await process_frame
	quit(0)
