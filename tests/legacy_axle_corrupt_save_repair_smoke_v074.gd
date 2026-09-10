extends SceneTree

const HUB_TYPE := 6
const STOP_TYPE := 0
const FRAME_ROD_TYPE := 2
const HOST_ROD_TYPE := 5
const CONNECTOR_D_TEST := 1.01
const FRAME_SPACING := 5.5 + CONNECTOR_D_TEST * 2.0
const FRAME_Y := 14.0
const STOP_Y := 9.25


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("LEGACY_AXLE_REPAIR_074_SMOKE_FAIL: %s" % message)
	quit(1)


func _uid(body: RigidBody3D) -> int:
	return int(body.get_meta("piece_uid_v020", -1)) if is_instance_valid(body) else -1


func _find_uid(main: Node, uid_value: int) -> RigidBody3D:
	for body_value in (main.get("bodies") as Array):
		var body := body_value as RigidBody3D
		if is_instance_valid(body) and _uid(body) == uid_value:
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
	var local_slot := main.call("_slot_dir", 0) as Vector3
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
	main.call("_tag_connection_v020", joint, "cross", stop, rod, 0, 0, along, null, true)
	joint.set_meta("cross_mount", true)
	stop.set_meta("cross_mount", true)
	stop.set_meta("cross_host_rod", rod)
	stop.set_meta("primary_connection_uid_v020", int(joint.get_meta("connection_uid_v020", -1)))
	main.call("_set_connector_occupied", stop, 0, true)
	stop.set_meta("build_transform", stop.global_transform)
	return stop


func _add_axle(main: Node, hub: RigidBody3D, rod: RigidBody3D) -> void:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var along := (hub.global_position - rod.global_position).dot(axis)
	var joint := main.call("_make_axle_joint", hub, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "axle", hub, rod, -1, 0, along, null, true)
	hub.set_meta("axle_occupied", true)
	hub.set_meta("axle_host_rod", rod)
	hub.set_meta("primary_connection_uid_v020", int(joint.get_meta("connection_uid_v020", -1)))


func _build_fixture(main: Node) -> Dictionary:
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
	_add_exact_socket_rod(main, hubs[0], 0, hubs[1], 180)
	_add_exact_socket_rod(main, hubs[1], 270, hubs[2], 90)
	_add_exact_socket_rod(main, hubs[2], 180, hubs[3], 0)
	_add_exact_socket_rod(main, hubs[3], 90, hubs[0], 270)

	var rods: Array = []
	var stops: Array = []
	var radial_hints := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
	for i in range(4):
		var p := positions[i] as Vector3
		var rod := main.call("_make_rod", HOST_ROD_TYPE, Vector3(p.x, 0.55, p.z), Vector3(p.x, 19.75, p.z)) as RigidBody3D
		rod.set_meta("build_transform", rod.global_transform)
		var stop := _add_cross_stop(main, rod, STOP_Y, radial_hints[i])
		_add_axle(main, hubs[i], rod)
		rods.append(rod)
		stops.append(stop)
	main.call("_rebuild_connection_graph_v020")
	main.call("_refresh_joint_frames_v020")
	main.call("_rebuild_connection_graph_v020")
	return {"hubs": hubs, "rods": rods, "stops": stops}


func _corrupt_two_axles_like_legacy_save(bundle: Dictionary, main: Node, hubs: Array, rods: Array) -> void:
	var snapshot := bundle.get("snapshot", {}) as Dictionary
	# Remove the v0.5.17 canonical table to emulate an actual v0.5.16-or-earlier save.
	snapshot.erase("v072_axles")

	var body_indices: Dictionary = {}
	for i in range((main.get("bodies") as Array).size()):
		var body := (main.get("bodies") as Array)[i] as RigidBody3D
		body_indices[_uid(body)] = i

	var target_pairs: Array = []
	for i in [0, 2]:
		target_pairs.append(Vector2i(int(body_indices[_uid(hubs[i])]), int(body_indices[_uid(rods[i])])))

	# The broken legacy signature: authoritative AXLE connection records are gone,
	# while the generic joint serializer reconstructs those same hub/shaft pairs as
	# fixed joints. Rebuilding the graph then labels them as SOCKET constraints.
	var saved_connections := snapshot.get("v020_connections", []) as Array
	var kept_connections: Array = []
	for value in saved_connections:
		var rec := value as Dictionary
		var pair := Vector2i(int(rec.get("connector_index", -1)), int(rec.get("rod_index", -1)))
		if str(rec.get("kind", "")) == "axle" and pair in target_pairs:
			continue
		kept_connections.append(rec)
	snapshot["v020_connections"] = kept_connections

	var saved_joints := snapshot.get("joints", []) as Array
	for value in saved_joints:
		var state := value as Dictionary
		var a := int(state.get("a", -1))
		var b := int(state.get("b", -1))
		for pair_value in target_pairs:
			var pair := pair_value as Vector2i
			if (a == pair.x and b == pair.y) or (a == pair.y and b == pair.x):
				state["type"] = "fixed"
	snapshot["joints"] = saved_joints
	bundle["snapshot"] = snapshot


func _assert_repaired_graph(main: Node, hubs: Array, rods: Array) -> void:
	main.call("_rebuild_connection_graph_v020")
	for i in range(4):
		var hub := hubs[i] as RigidBody3D
		var rod := rods[i] as RigidBody3D
		var axle_count := 0
		var wrong_fixed_count := 0
		for record_value in (main.get("connections_v020") as Array):
			var record := record_value as Dictionary
			if record.get("connector") != hub or record.get("rod") != rod:
				continue
			if str(record.get("kind", "")) == "axle":
				axle_count += 1
			elif str(record.get("kind", "")) in ["socket", "cross"]:
				wrong_fixed_count += 1
		if axle_count != 1:
			_fail("hub %d did not restore to exactly one AXLE record (found %d)" % [i, axle_count])
			return
		if wrong_fixed_count != 0:
			_fail("hub %d still has a false SOCKET/CROSS record to its AXLE shaft" % i)
			return
	if int(main.get("legacy_axle_geometry_repairs_v074")) != 2:
		_fail("expected exactly two geometric legacy repairs, got %d" % int(main.get("legacy_axle_geometry_repairs_v074")))


func _assert_build_slide_is_unlocked(main: Node, hub: RigidBody3D, rod: RigidBody3D) -> void:
	main.call("_set_selected", hub)
	var before := _along(main, hub, rod)
	main.call("_slide_selected_on_axle", -0.50)
	var after := _along(main, hub, rod)
	if absf(after - before) < 0.30:
		_fail("repaired legacy hub is still editor-locked; AXLE slide was rejected")
		return
	var status_label := main.get("status_label") as Label
	if is_instance_valid(status_label) and "rod end would leave its exact socket" in status_label.text:
		_fail("legacy false SOCKET validator still blocks AXLE movement")


func _run_physics(main: Node, hubs: Array, rods: Array, stops: Array) -> void:
	var start_gaps: Array = []
	for i in range(4):
		start_gaps.append(_along(main, hubs[i], rods[i]) - _along(main, stops[i], rods[i]))
	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start after legacy repair")
		return
	for i in range(4):
		var rod := rods[i] as RigidBody3D
		rod.freeze = true
		rod.linear_velocity = Vector3.ZERO
		rod.angular_velocity = Vector3.ZERO
		(hubs[i] as RigidBody3D).sleeping = false

	for frame_index in range(240):
		await physics_frame
		for i in range(4):
			var gap := _along(main, hubs[i], rods[i]) - _along(main, stops[i], rods[i])
			if gap < 0.05:
				_fail("repaired AXLE hub %d passed through CROSS stop at frame %d" % [i, frame_index])
				return
	for i in range(4):
		var end_gap := _along(main, hubs[i], rods[i]) - _along(main, stops[i], rods[i])
		if float(start_gaps[i]) - end_gap < 0.8:
			_fail("repaired AXLE hub %d remained stuck in simulation" % i)
			return


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	if not str(main.get_script().resource_path).ends_with("main_v074.gd"):
		_fail("Main is not using v0.5.18 candidate runtime")
		return

	var fixture := _build_fixture(main)
	var hubs := fixture.get("hubs") as Array
	var rods := fixture.get("rods") as Array
	var stops := fixture.get("stops") as Array
	var hub_uids: Array = []
	var rod_uids: Array = []
	var stop_uids: Array = []
	for i in range(4):
		hub_uids.append(_uid(hubs[i]))
		rod_uids.append(_uid(rods[i]))
		stop_uids.append(_uid(stops[i]))

	var bundle := main.call("_save_bundle_v050", "LegacyBroken074") as Dictionary
	_corrupt_two_axles_like_legacy_save(bundle, main, hubs, rods)
	if not bool(main.call("_restore_bundle_v050", bundle, "LegacyBroken074")):
		_fail("corrupted legacy bundle failed to load")
		return
	await process_frame

	var restored_hubs: Array = []
	var restored_rods: Array = []
	var restored_stops: Array = []
	for i in range(4):
		restored_hubs.append(_find_uid(main, hub_uids[i]))
		restored_rods.append(_find_uid(main, rod_uids[i]))
		restored_stops.append(_find_uid(main, stop_uids[i]))
		if not is_instance_valid(restored_hubs[i]) or not is_instance_valid(restored_rods[i]) or not is_instance_valid(restored_stops[i]):
			_fail("legacy restore lost fixture body %d" % i)
			return

	_assert_repaired_graph(main, restored_hubs, restored_rods)
	_assert_build_slide_is_unlocked(main, restored_hubs[0], restored_rods[0])
	if get_exit_code() != 0:
		return
	await _run_physics(main, restored_hubs, restored_rods, restored_stops)
	if get_exit_code() != 0:
		return

	print("LEGACY_AXLE_REPAIR_074_SMOKE_OK: two corrupted legacy AXLEs were recovered from exact hub/shaft geometry, false SOCKET records were removed, editor slide unlocked, and all four hubs slid/stopped physically")
	quit(0)
