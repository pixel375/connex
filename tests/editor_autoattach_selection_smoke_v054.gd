extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_054_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index(defs: Array, wanted: String) -> int:
	for i in range(defs.size()):
		if str((defs[i] as Dictionary).get("name", "")) == wanted:
			return i
	return -1


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v058.gd"):
		_fail("Main is not using v0.5.4 runtime")
		return

	var bodies: Array = main.get("bodies") as Array
	if bodies.is_empty():
		_fail("seed connector missing")
		return
	var seed: RigidBody3D = bodies[0] as RigidBody3D

	# Android transform releases are not direct-selection taps.
	main.call("_set_editor_mode_v032", 1, false)
	main.call("_set_selected", seed)
	main.call("_arm_transform_release_suppression_v058")
	if not bool(main.call("_transform_release_tap_suppressed_v058")):
		_fail("transform release suppression did not arm")
		return
	main.call("_handle_tap", Vector2(12.0, 12.0))
	if main.get("selected_piece") != seed:
		_fail("suppressed transform release changed selection")
		return

	# A selected spatial connector must get a newly generated highlight after type change.
	var defs: Array = main.get("connector_defs") as Array
	var index_14: int = _connector_index(defs, "14-point 3D")
	if index_14 < 0:
		_fail("14-point connector definition missing")
		return
	var spatial: RigidBody3D = main.call("_make_connector", index_14, Transform3D(Basis.IDENTITY, Vector3(28.0, 7.0, 0.0))) as RigidBody3D
	await process_frame
	main.call("_set_selected", spatial)
	main.call("_refresh_selection_highlight")
	var old_highlight: Node = spatial.get_node_or_null("SelectionHighlight")
	if old_highlight == null:
		_fail("spatial selection highlight was not created")
		return
	var old_id: int = old_highlight.get_instance_id()
	main.call("_rebuild_connector", spatial, 6)
	var new_highlight: Node = spatial.get_node_or_null("SelectionHighlight")
	if new_highlight == null:
		_fail("highlight was not rebuilt after connector type change")
		return
	if new_highlight.get_instance_id() == old_id:
		_fail("stale spatial highlight survived connector type change")
		return

	# Use an isolated anchor far from the starter construction so the nearest-socket
	# assertion cannot be affected by any other connector created by earlier tests.
	var anchor: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(70.0, 12.0, 0.0))) as RigidBody3D
	await process_frame
	main.call("_set_selected", anchor)
	main.call("_extend_socket", anchor, 0)
	await process_frame
	bodies = main.get("bodies") as Array
	var rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if rod == null or str(rod.get_meta("kind", "")) != "rod":
		_fail("could not create rod for proximity auto-attach test")
		return
	var rod_records: Array = main.call("_connections_for_piece_v020", rod) as Array
	if rod_records.is_empty():
		_fail("new rod had no initial socket connection")
		return
	var record: Dictionary = rod_records[0] as Dictionary
	var sign_value: int = int(record.get("rod_end", 0))
	var slot: int = int(record.get("slot", -1))
	if sign_value == 0 or slot < 0:
		_fail("initial socket connection metadata incomplete")
		return
	main.call("_detach_record_raw_v032", record)
	main.call("_rebuild_connection_graph_v020")
	var socket: Dictionary = main.call("_socket_world_v020", anchor, slot) as Dictionary
	var socket_dir: Vector3 = (socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	rod.global_position += socket_dir * 1.55
	main.call("_refresh_joint_frames_v020")
	main.call("_rebuild_connection_graph_v020")

	var before_gap: float = (main.call("_rod_end_v020", rod, sign_value) as Vector3).distance_to((main.call("_socket_world_v020", anchor, slot) as Dictionary).get("point", anchor.global_position) as Vector3)
	if before_gap <= 1.10 or before_gap > 2.00:
		_fail("test did not create the intended v0.5.4-only capture gap: %.3f" % before_gap)
		return
	var best: Dictionary = main.call("_best_socket_for_end_v020", rod, sign_value) as Dictionary
	if best.is_empty() or best.get("connector") != anchor:
		_fail("proximity matcher did not find the intended close free socket")
		return
	var fused: int = int(main.call("_auto_connect_all_v020"))
	if fused < 1:
		_fail("close free rod/socket did not auto-attach")
		return
	main.call("_rebuild_connection_graph_v020")
	var endpoint: Dictionary = {"type": "rod_end", "body": rod, "sign": sign_value, "point": main.call("_rod_end_v020", rod, sign_value)}
	if (main.call("_connection_record_for_point_v032", endpoint) as Dictionary).is_empty():
		_fail("auto-attach did not record the rod-end connection")
		return
	var after_gap: float = (main.call("_rod_end_v020", rod, sign_value) as Vector3).distance_to((main.call("_socket_world_v020", anchor, slot) as Dictionary).get("point", anchor.global_position) as Vector3)
	if after_gap > 0.08:
		_fail("separate-island auto-snap did not visibly close the gap: %.3f" % after_gap)
		return

	print("EDITOR_054_SMOKE_OK: transform-release selection suppression + fresh spatial highlight rebuild + wider proximity auto-attach + visible separate-island snap")
	main.queue_free()
	await process_frame
	quit(0)
