extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_076_SMOKE_FAIL: %s" % message)
	quit(1)


func _socket_records_for(main: Node, connector: RigidBody3D) -> Array:
	var result: Array = []
	main.call("_rebuild_connection_graph_v020")
	for record_value in main.call("_connections_for_piece_v020", connector) as Array:
		var record: Dictionary = record_value as Dictionary
		if str(record.get("kind", "")) == "socket":
			result.append(record)
	return result


func _has_socket_to(records: Array, rod: RigidBody3D) -> bool:
	for record_value in records:
		var record: Dictionary = record_value as Dictionary
		if record.get("rod") == rod:
			return true
	return false


func _overlay_has_marker_near(main: Node, point: Vector3, tolerance: float = 0.10) -> bool:
	var root_value: Variant = main.get("attach_points_root_v032")
	if not (root_value is Node3D):
		return false
	var overlay: Node3D = root_value as Node3D
	for child_value in overlay.get_children():
		var child: Node3D = child_value as Node3D
		if child != null and child.global_position.distance_to(point) <= tolerance:
			return true
	return false


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# 1) Select must still select a PIECE while ATTACH mode is active.
	# -------------------------------------------------------------------------
	var selectable: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(4.2, 4.0, 0.0))) as RigidBody3D
	await process_frame
	main.call("_set_editor_mode_v032", 2, false)
	main.set("attach_mode", 0)
	main.call("_toggle_select_v020")
	if not bool(main.get("select_armed_v020")):
		_fail("Select did not arm in ATTACH mode")
		return
	var camera: Camera3D = main.get("camera") as Camera3D
	if camera == null:
		_fail("camera missing")
		return
	var select_screen: Vector2 = camera.unproject_position(selectable.global_position)
	main.call("_handle_tap", select_screen)
	await process_frame
	if main.get("selected_piece") != selectable:
		_fail("ATTACH swallowed Select instead of selecting the tapped connector")
		return
	if bool(main.get("select_armed_v020")):
		_fail("ATTACH piece selection did not consume the one-shot Select action")
		return
	if not (main.get("attach_point_selected_v032") as Dictionary).is_empty():
		_fail("piece selection in ATTACH left an attachment source selected")
		return

	# -------------------------------------------------------------------------
	# 2) O-Ring palette selection must not block ordinary SOCKET rod creation.
	# -------------------------------------------------------------------------
	main.call("_set_editor_mode_v032", 0, false)
	main.set("attach_mode", 0)
	var o_ring_index: int = int(main.get("o_ring_index"))
	main.set("selected_connector_type", o_ring_index)
	var socket_host: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(-4.0, 4.0, 0.0))) as RigidBody3D
	await process_frame
	var socket0: Dictionary = main.call("_socket_world_v020", socket_host, 0) as Dictionary
	var socket_screen: Vector2 = camera.unproject_position(socket0.get("point", socket_host.global_position) as Vector3)
	var before_bodies: int = (main.get("bodies") as Array).size()
	main.call("_handle_tap", socket_screen)
	await process_frame
	var after_bodies: Array = main.get("bodies") as Array
	if after_bodies.size() != before_bodies + 1:
		_fail("O-Ring selection prevented a free SOCKET from creating a rod")
		return
	var created_rod: RigidBody3D = after_bodies[after_bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(created_rod) or str(created_rod.get_meta("kind", "")) != "rod":
		_fail("O-Ring-selected SOCKET tap did not create a rod")
		return
	if int(main.get("selected_connector_type")) != o_ring_index:
		_fail("creating a rod unexpectedly changed the selected O-Ring palette item")
		return

	# -------------------------------------------------------------------------
	# 3) ATTACH overlay must follow direct/restored transforms immediately.
	# -------------------------------------------------------------------------
	main.call("_set_editor_mode_v032", 2, false)
	main.set("attach_mode", 0)
	var overlay_host: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(11.0, 7.0, 8.0))) as RigidBody3D
	await process_frame
	main.call("_sync_attach_overlay_pose_v076", true)
	var old_socket: Vector3 = (main.call("_socket_world_v020", overlay_host, 180) as Dictionary).get("point", overlay_host.global_position) as Vector3
	if not _overlay_has_marker_near(main, old_socket):
		_fail("ATTACH overlay did not contain the original socket marker")
		return
	var move_delta := Vector3(3.4, 1.3, -2.1)
	overlay_host.global_position += move_delta
	overlay_host.set_meta("build_transform", overlay_host.global_transform)
	var new_socket: Vector3 = (main.call("_socket_world_v020", overlay_host, 180) as Dictionary).get("point", overlay_host.global_position) as Vector3
	if not bool(main.call("_sync_attach_overlay_pose_v076", false)):
		_fail("direct body movement did not dirty the ATTACH overlay")
		return
	if not _overlay_has_marker_near(main, new_socket):
		_fail("ATTACH marker did not move with the transformed connector")
		return
	if _overlay_has_marker_near(main, old_socket, 0.08):
		_fail("stale ATTACH marker remained at the connector's previous position")
		return

	# -------------------------------------------------------------------------
	# 4) Exact repeated bug: a connector with two rods is disconnected, then one
	#    rod is explicitly reattached. The other aligned rod must auto-reconnect.
	# -------------------------------------------------------------------------
	main.call("_set_editor_mode_v032", 0, false)
	main.set("attach_mode", 0)
	var connector: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(30.0, 8.0, 30.0))) as RigidBody3D
	main.call("_extend_socket", connector, 0)
	await process_frame
	var rod1: RigidBody3D = main.get("selected_piece") as RigidBody3D
	main.call("_extend_socket", connector, 90)
	await process_frame
	var rod2: RigidBody3D = main.get("selected_piece") as RigidBody3D
	if not is_instance_valid(rod1) or not is_instance_valid(rod2) or rod1 == rod2:
		_fail("could not create the two-rod reconnect fixture")
		return
	var initial_records: Array = _socket_records_for(main, connector)
	if initial_records.size() != 2 or not _has_socket_to(initial_records, rod1) or not _has_socket_to(initial_records, rod2):
		_fail("two-rod fixture did not start with two SOCKET records")
		return

	main.call("_set_selected", connector)
	main.call("_disconnect_selected_v042")
	await process_frame
	if not _socket_records_for(main, connector).is_empty():
		_fail("Disconnect Selected did not release both connector rods")
		return
	var pair1: String = str(main.call("_pair_key_v030", connector, rod1))
	var pair2: String = str(main.call("_pair_key_v030", connector, rod2))
	var detach_blocks: Dictionary = main.get("manual_detach_blocks_v030") as Dictionary
	if not detach_blocks.has(pair1) or not detach_blocks.has(pair2):
		_fail("fixture did not reproduce the two manual detach quarantine entries")
		return

	main.set("attach_mode", 0)
	var source_socket: Dictionary = {
		"type": "socket",
		"body": connector,
		"slot": 0,
		"point": (main.call("_socket_world_v020", connector, 0) as Dictionary).get("point", connector.global_position),
	}
	var target_end: Dictionary = {
		"type": "rod_end",
		"body": rod1,
		"sign": -1,
		"point": main.call("_rod_end_v020", rod1, -1),
	}
	if not bool(main.call("_connect_points_v035", source_socket, target_end)):
		_fail("explicit first-rod SOCKET reconnect was rejected")
		return
	await process_frame
	var restored_records: Array = _socket_records_for(main, connector)
	if restored_records.size() != 2:
		_fail("reconnecting one of two rods did not auto-restore the other aligned rod")
		return
	if not _has_socket_to(restored_records, rod1) or not _has_socket_to(restored_records, rod2):
		_fail("multi-rod reconnect did not restore both original rod links")
		return
	detach_blocks = main.get("manual_detach_blocks_v030") as Dictionary
	if detach_blocks.has(pair2):
		_fail("second rod stayed permanently quarantined after explicit connector reconnect")
		return

	print("EDITOR_076_SMOKE_OK: ATTACH Select, O-Ring rod creation, live markers and multi-rod reconnect")
	main.queue_free()
	await process_frame
	quit(0)
