extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("STRICT_510_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index(defs: Array, wanted: String) -> int:
	for i in range(defs.size()):
		if str((defs[i] as Dictionary).get("name", "")) == wanted:
			return i
	return -1


func _same_transform(a: Transform3D, b: Transform3D, eps: float = 0.0001) -> bool:
	return a.origin.distance_to(b.origin) <= eps \
		and a.basis.x.distance_to(b.basis.x) <= eps \
		and a.basis.y.distance_to(b.basis.y) <= eps \
		and a.basis.z.distance_to(b.basis.z) <= eps


func _place_socket_at(main: Node, connector: RigidBody3D, slot: int, target_point: Vector3) -> void:
	var before: Dictionary = main.call("_socket_world_v020", connector, slot) as Dictionary
	connector.global_position += target_point - (before.get("point", connector.global_position) as Vector3)
	connector.set_meta("build_transform", connector.global_transform)


func _newest_rod(main: Node) -> RigidBody3D:
	var list: Array = main.get("bodies") as Array
	for i in range(list.size() - 1, -1, -1):
		var body: RigidBody3D = list[i] as RigidBody3D
		if is_instance_valid(body) and str(body.get_meta("kind", "")) == "rod":
			return body
	return null


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v065.gd"):
		_fail("Main is not using v0.5.10 runtime")
		return

	var defs: Array = main.get("connector_defs") as Array
	var connector_type: int = _connector_index(defs, "White 8-way")
	if connector_type < 0:
		_fail("White 8-way connector definition missing")
		return

	main.set("selected_rod_type", 2)
	var rod_defs: Array = main.get("rod_defs") as Array
	var rod_len: float = float((rod_defs[2] as Dictionary).get("actual_mm", 54.0)) / 10.0

	# ------------------------------------------------------------------
	# 1) Visible gap must stay a gap. This reproduces the v0.5.9 failure:
	# source rod points exactly at the target socket, but its end is still 1.0
	# world unit outside it. The old 3.50 capture shell attached it anyway and
	# then bent the construction to close the difference.
	# ------------------------------------------------------------------
	var base1 := Vector3(70.0, 14.0, 0.0)
	var source1: RigidBody3D = main.call("_make_connector", connector_type, Transform3D(Basis.IDENTITY, base1)) as RigidBody3D
	var source_socket1: Dictionary = main.call("_socket_world_v020", source1, 0) as Dictionary
	var start1: Vector3 = source_socket1.get("point", source1.global_position) as Vector3
	var dir1: Vector3 = (source_socket1.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var expected_far1: Vector3 = start1 + dir1 * rod_len
	var target1: RigidBody3D = main.call("_make_connector", connector_type, Transform3D(Basis.IDENTITY, base1 + dir1 * (rod_len + 5.0))) as RigidBody3D
	_place_socket_at(main, target1, 180, expected_far1 + dir1 * 1.0)
	var source1_tf: Transform3D = source1.global_transform
	var target1_tf: Transform3D = target1.global_transform

	main.call("_extend_socket", source1, 0)
	main.call("_rebuild_connection_graph_v020")
	var rod1: RigidBody3D = _newest_rod(main)
	if not is_instance_valid(rod1):
		_fail("gap fixture did not create a rod")
		return
	var far_occ1: Dictionary = rod1.get_meta("end_occupied", {}) as Dictionary
	if far_occ1.has(1):
		_fail("rod with a visible 1.0-unit gap auto-connected")
		return
	var target_occ1: Dictionary = target1.get_meta("occupied", {}) as Dictionary
	if target_occ1.has(180):
		_fail("target socket with a visible gap was marked occupied")
		return
	if not _same_transform(source1_tf, source1.global_transform) or not _same_transform(target1_tf, target1.global_transform):
		_fail("failed auto-connect moved an existing connector")
		return
	var gap_after: float = (main.call("_rod_end_v020", rod1, 1) as Vector3).distance_to((main.call("_socket_world_v020", target1, 180) as Dictionary).get("point") as Vector3)
	if absf(gap_after - 1.0) > 0.02:
		_fail("failed auto-connect changed the visible gap: %.3f" % gap_after)
		return

	# ------------------------------------------------------------------
	# 2) Genuine overlap attaches, but still does not move either component.
	# ------------------------------------------------------------------
	var base2 := Vector3(70.0, 14.0, 30.0)
	var source2: RigidBody3D = main.call("_make_connector", connector_type, Transform3D(Basis.IDENTITY, base2)) as RigidBody3D
	var source_socket2: Dictionary = main.call("_socket_world_v020", source2, 0) as Dictionary
	var start2: Vector3 = source_socket2.get("point", source2.global_position) as Vector3
	var dir2: Vector3 = (source_socket2.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var expected_far2: Vector3 = start2 + dir2 * rod_len
	var target2: RigidBody3D = main.call("_make_connector", connector_type, Transform3D(Basis.IDENTITY, base2 + dir2 * (rod_len + 5.0))) as RigidBody3D
	_place_socket_at(main, target2, 180, expected_far2 + dir2 * 0.10)
	var source2_tf: Transform3D = source2.global_transform
	var target2_tf: Transform3D = target2.global_transform

	main.call("_extend_socket", source2, 0)
	main.call("_rebuild_connection_graph_v020")
	var rod2: RigidBody3D = _newest_rod(main)
	if not is_instance_valid(rod2):
		_fail("overlap fixture did not create a rod")
		return
	var far_occ2: Dictionary = rod2.get_meta("end_occupied", {}) as Dictionary
	if not far_occ2.has(1):
		_fail("rod end already inside the socket did not auto-connect")
		return
	var target_occ2: Dictionary = target2.get_meta("occupied", {}) as Dictionary
	if not target_occ2.has(180):
		_fail("overlapping target socket was not marked occupied")
		return
	if not _same_transform(source2_tf, source2.global_transform) or not _same_transform(target2_tf, target2.global_transform):
		_fail("successful overlap auto-connect moved an existing connector")
		return
	var overlap_gap: float = (main.call("_rod_end_v020", rod2, 1) as Vector3).distance_to((main.call("_socket_world_v020", target2, 180) as Dictionary).get("point") as Vector3)
	if absf(overlap_gap - 0.10) > 0.02:
		_fail("successful auto-connect reshaped the overlap instead of preserving it: %.3f" % overlap_gap)
		return

	# ------------------------------------------------------------------
	# 3) SIMULATE preflight is graph-only. Inject one legacy-style recorded SOCKET
	# with a large current gap, then prove preflight leaves every body transform
	# exactly where BUILD had it. v0.5.5 would project this geometry here.
	# ------------------------------------------------------------------
	var legacy_anchor: Vector3 = main.call("_rod_end_v020", rod1, 1) as Vector3
	var legacy_joint: Generic6DOFJoint3D = main.call("_make_fixed_joint", rod1, target1, legacy_anchor) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", legacy_joint, "socket", target1, rod1, 180, 1, 0.0, null, false)
	main.call("_set_rod_end_occupied", rod1, 1, true)
	main.call("_set_connector_occupied", target1, 180, true)
	main.call("_rebuild_connection_graph_v020")

	var before_preflight: Dictionary = {}
	for body_value in (main.get("bodies") as Array):
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			before_preflight[body.get_instance_id()] = body.global_transform

	main.call("_prepare_stable_simulation_graph")
	for body_value in (main.get("bodies") as Array):
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body) or not before_preflight.has(body.get_instance_id()):
			continue
		if not _same_transform(before_preflight[body.get_instance_id()] as Transform3D, body.global_transform):
			_fail("SIMULATE preflight changed build transform for %s" % str(body.name))
			return
	main.call("_restore_simulation_joint_graph")

	print("STRICT_510_SMOKE_OK: 1.0 gap stays free + 0.10 overlap connects without movement + SIMULATE preflight preserves all build transforms")
	main.queue_free()
	await process_frame
	quit(0)
