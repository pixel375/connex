extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("EDITOR_057_SMOKE_FAIL: %s" % message)
	quit(1)

func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	if not str(main.get_script().resource_path).ends_with("main_v062.gd"):
		_fail("Main is not using the v0.5.7 runtime")
		return

	# Exact reproduction of the requested rule: connector A already exists,
	# connector B already exists, then a rod is created from A. Its far end lands
	# exactly in a free socket on B. No ATTACH mode is used anywhere in this test.
	var defs: Array = main.get("connector_defs") as Array
	var rods: Array = main.get("rod_defs") as Array
	var connector_type: int = 6 # White 8-way
	var rod_type: int = 2 # Blue 54
	if connector_type >= defs.size() or rod_type >= rods.size():
		_fail("required 8-way connector / Blue 54 rod definitions missing")
		return
	main.set("selected_rod_type", rod_type)

	var a: RigidBody3D = main.call("_make_connector", connector_type, Transform3D(Basis.IDENTITY, Vector3(40.0, 9.0, 0.0))) as RigidBody3D
	var a_socket: Dictionary = main.call("_socket_world_v020", a, 0) as Dictionary
	var direction: Vector3 = (a_socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var rod_len: float = float((rods[rod_type] as Dictionary).get("actual_mm", 55.0)) / 10.0
	var far_end: Vector3 = (a_socket.get("point", a.global_position) as Vector3) + direction * rod_len

	# Build B so its 180-degree socket point is exactly at the future rod end.
	var b: RigidBody3D = main.call("_make_connector", connector_type, Transform3D(Basis.IDENTITY, far_end + direction * 1.01)) as RigidBody3D
	await process_frame
	var target_before: Dictionary = main.call("_socket_world_v020", b, 180) as Dictionary
	if (target_before.get("point", Vector3.ZERO) as Vector3).distance_to(far_end) > 0.02:
		_fail("test setup failed to align the far rod end with connector B")
		return

	var bodies_before: int = (main.get("bodies") as Array).size()
	main.call("_extend_socket", a, 0)
	await process_frame
	var bodies_after: Array = main.get("bodies") as Array
	if bodies_after.size() != bodies_before + 1:
		_fail("rod placement did not create exactly one rod")
		return
	var rod: RigidBody3D = main.get("selected_piece") as RigidBody3D
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		_fail("newly placed rod is not selected")
		return

	main.call("_rebuild_connection_graph_v020")
	var records: Array = main.call("_connections_for_piece_v020", rod) as Array
	var source_found: bool = false
	var far_found: bool = false
	var far_joint: Joint3D = null
	for value in records:
		var record: Dictionary = value as Dictionary
		if str(record.get("kind", "")) != "socket":
			continue
		if record.get("connector") == a and int(record.get("slot", -1)) == 0 and int(record.get("rod_end", 0)) == -1:
			source_found = true
		if record.get("connector") == b and int(record.get("slot", -1)) == 180 and int(record.get("rod_end", 0)) == 1:
			far_found = true
			far_joint = record.get("joint") as Joint3D
	if not source_found:
		_fail("source rod end was not recorded as a SOCKET connection")
		return
	if not far_found or not is_instance_valid(far_joint):
		_fail("aligned far rod end did not automatically become a SOCKET connection before simulation")
		return

	var rod_occ: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	var b_occ: Dictionary = b.get_meta("occupied", {}) as Dictionary
	if not rod_occ.has(-1) or not rod_occ.has(1):
		_fail("new rod does not report both endpoints occupied immediately after placement")
		return
	if not b_occ.has(180):
		_fail("target connector socket was not marked occupied immediately after placement")
		return

	var pre_gap: float = (main.call("_rod_end_v020", rod, 1) as Vector3).distance_to((main.call("_socket_world_v020", b, 180) as Dictionary).get("point", b.global_position) as Vector3)
	if pre_gap > 0.06:
		_fail("far endpoint/socket graph connection exists but geometry is not closed: %.4f" % pre_gap)
		return

	# Press SIMULATE and verify the second end stays physically attached.
	main.call("_toggle_simulation")
	for _i in range(8):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	if not is_instance_valid(far_joint):
		_fail("far-end SOCKET joint disappeared when simulation started")
		return
	var joint_nodes: Array = main.call("_joint_nodes", far_joint) as Array
	if joint_nodes.size() < 2 or not is_instance_valid(joint_nodes[0]) or not is_instance_valid(joint_nodes[1]):
		_fail("far-end SOCKET joint was detached/suppressed when simulation started")
		return
	var sim_gap: float = (main.call("_rod_end_v020", rod, 1) as Vector3).distance_to((main.call("_socket_world_v020", b, 180) as Dictionary).get("point", b.global_position) as Vector3)
	if sim_gap > 0.16:
		_fail("far rod end separated from its socket in simulation: %.4f" % sim_gap)
		return

	print("EDITOR_057_SMOKE_OK: rod created from connector A immediately attaches aligned far end to connector B without ATTACH mode and stays attached in SIMULATE")
	main.queue_free()
	await process_frame
	quit(0)
