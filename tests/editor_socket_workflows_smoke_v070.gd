extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_SOCKET_070_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index_named(main: Node, wanted: String) -> int:
	var defs := main.get("connector_defs") as Array
	for i in range(defs.size()):
		var definition := defs[i] as Dictionary
		if str(definition.get("name", "")) == wanted:
			return i
	return -1


func _aim_camera_at_socket(main: Node, connector: RigidBody3D, slot: int) -> Vector2:
	var camera := main.get("camera") as Camera3D
	var local_dir: Vector3 = main.call("_slot_dir", slot) as Vector3
	var world_dir: Vector3 = (connector.global_transform.basis * local_dir).normalized()
	var normal: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
	var camera_side: Vector3 = world_dir
	if absf(camera_side.dot(normal)) > 0.94:
		camera_side = (connector.global_transform.basis * Vector3.BACK).normalized()
	var target: Vector3 = connector.global_position + world_dir * 1.18
	camera.global_position = target + camera_side * 5.5 + normal * 1.4
	camera.look_at(target, Vector3.UP if absf(Vector3.UP.dot((target - camera.global_position).normalized())) < 0.96 else Vector3.BACK)
	return camera.unproject_position(target)


func _assert_all_spatial_sockets_pick(main: Node, def_index: int, expected_count: int) -> bool:
	var connector := main.call("_make_connector", def_index, Transform3D(Basis.IDENTITY, Vector3(24.0 + def_index * 6.0, 7.0, 12.0))) as RigidBody3D
	await physics_frame
	var slots := (main.get("connector_defs") as Array)[def_index]["slots"] as Array
	if slots.size() != expected_count:
		_fail("unexpected socket count for %s: %d" % [str((main.get("connector_defs") as Array)[def_index]["name"]), slots.size()])
		return false
	for slot_value in slots:
		var slot := int(slot_value)
		var screen_pos: Vector2 = _aim_camera_at_socket(main, connector, slot)
		await process_frame
		var picked := main.call("_pick_socket_on_connector_v070", connector, screen_pos, 108.0, false, {}) as Dictionary
		if picked.is_empty() or int(picked.get("slot", -9999)) != slot:
			_fail("%s socket %s was not selectable from its visible jaw" % [str((main.get("connector_defs") as Array)[def_index]["name"]), str(slot)])
			return false
	return true


func _find_socket_record(main: Node, connector: RigidBody3D, rod: RigidBody3D) -> Dictionary:
	main.call("_rebuild_connection_graph_v020")
	for value in (main.get("connections_v020") as Array):
		var record := value as Dictionary
		if str(record.get("kind", "")) == "socket" and record.get("connector") == connector and record.get("rod") == rod:
			return record
	return {}


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	if not str(main.get_script().resource_path).ends_with("main_v070.gd"):
		_fail("Main is not using v0.5.15 runtime")
		return

	var eleven_index := _connector_index_named(main, "11-point 3D")
	var fourteen_index := _connector_index_named(main, "14-point 3D")
	if eleven_index < 0 or fourteen_index < 0:
		_fail("11-point or 14-point connector definition is missing")
		return
	if not await _assert_all_spatial_sockets_pick(main, eleven_index, 11):
		return
	if not await _assert_all_spatial_sockets_pick(main, fourteen_index, 14):
		return

	# CROSS mode must still let a connector socket grow a normal socket rod.
	var cross_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(58.0, 8.0, 18.0))) as RigidBody3D
	main.set("selected_rod_type", 2)
	main.set("attach_mode", 2)
	main.call("_set_editor_mode_v032", 0, false)
	await physics_frame
	var cross_screen: Vector2 = _aim_camera_at_socket(main, cross_connector, 0)
	await process_frame
	var body_count_before := (main.get("bodies") as Array).size()
	if not bool(main.call("_try_socket_create_tap_v054", cross_screen)):
		_fail("CROSS mode did not accept a connector socket create tap")
		return
	await process_frame
	var body_count_after := (main.get("bodies") as Array).size()
	if body_count_after != body_count_before + 1:
		_fail("CROSS socket tap did not create exactly one rod")
		return
	var created_cross_rod := (main.get("bodies") as Array)[body_count_after - 1] as RigidBody3D
	if str(created_cross_rod.get_meta("kind", "")) != "rod" or _find_socket_record(main, cross_connector, created_cross_rod).is_empty():
		_fail("CROSS socket-created rod is not socket-attached to its source connector")
		return

	# Explicit free placement must create truly new parts in empty workspace.
	main.call("_set_editor_mode_v032", 0, false)
	main.set("selected_rod_type", 2)
	main.set("camera_target", Vector3(82.0, 8.0, 62.0))
	var camera := main.get("camera") as Camera3D
	camera.global_position = Vector3(90.0, 15.0, 70.0)
	camera.look_at(Vector3(82.0, 8.0, 62.0), Vector3.UP)
	var center_screen := main.get_viewport().get_visible_rect().size * 0.5
	var before_free_rod := (main.get("bodies") as Array).size()
	main.call("_arm_free_create_v070", "rod")
	if not bool(main.call("_place_free_part_v070", center_screen)):
		_fail("New Rod free placement did not consume the empty-space tap")
		return
	if (main.get("bodies") as Array).size() != before_free_rod + 1 or str((main.get("selected_piece") as RigidBody3D).get_meta("kind", "")) != "rod":
		_fail("New Rod did not create/select exactly one free rod")
		return

	main.set("selected_connector_type", 6)
	main.set("camera_target", Vector3(96.0, 8.0, 72.0))
	camera.global_position = Vector3(104.0, 15.0, 80.0)
	camera.look_at(Vector3(96.0, 8.0, 72.0), Vector3.UP)
	var before_free_connector := (main.get("bodies") as Array).size()
	main.call("_arm_free_create_v070", "connector")
	if not bool(main.call("_place_free_part_v070", center_screen)):
		_fail("New Connector free placement did not consume the empty-space tap")
		return
	if (main.get("bodies") as Array).size() != before_free_connector + 1 or str((main.get("selected_piece") as RigidBody3D).get_meta("kind", "")) != "connector":
		_fail("New Connector did not create/select exactly one free connector")
		return

	# Re-seat a current rod from socket 0 to socket 45. The rod is the anchor and
	# must not move; the connector side rotates only if every remaining connection
	# validates under the new socket assignment.
	var reseat_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(120.0, 9.0, 30.0))) as RigidBody3D
	var socket0 := main.call("_socket_world_v020", reseat_connector, 0) as Dictionary
	var start: Vector3 = socket0.get("point", reseat_connector.global_position) as Vector3
	var direction: Vector3 = (socket0.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var reseat_rod := main.call("_make_rod", 2, start, start + direction * 5.5) as RigidBody3D
	var mount := main.call("_make_fixed_joint", reseat_connector, reseat_rod, start) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", mount, "socket", reseat_connector, reseat_rod, 0, -1, 0.0, null, true)
	main.call("_set_connector_occupied", reseat_connector, 0, true)
	main.call("_set_rod_end_occupied", reseat_rod, -1, true)
	main.call("_rebuild_connection_graph_v020")
	var record := _find_socket_record(main, reseat_connector, reseat_rod)
	if record.is_empty():
		_fail("re-seat fixture did not create its socket record")
		return
	var rod_transform_before := reseat_rod.global_transform
	var preview := main.call("_reseat_record_preview_v070", reseat_connector, record, 45) as Dictionary
	if not bool(preview.get("valid", false)):
		_fail("valid one-socket re-seat was rejected: %s" % str(preview.get("reason", "unknown")))
		return
	if not bool(main.call("_apply_reseat_record_v070", reseat_connector, record, 45)):
		_fail("valid one-socket re-seat did not apply")
		return
	if reseat_rod.global_transform.origin.distance_to(rod_transform_before.origin) > 0.0005 or not reseat_rod.global_transform.basis.is_equal_approx(rod_transform_before.basis):
		_fail("socket re-seat moved the target rod instead of rotating the connector side")
		return
	var reseated_record := _find_socket_record(main, reseat_connector, reseat_rod)
	if reseated_record.is_empty() or int(reseated_record.get("slot", -1)) != 45:
		_fail("socket re-seat did not persist the new socket assignment")
		return
	var socket45 := main.call("_socket_world_v020", reseat_connector, 45) as Dictionary
	var rod_end := main.call("_rod_end_v020", reseat_rod, -1) as Vector3
	if (socket45.get("point", Vector3.ZERO) as Vector3).distance_to(rod_end) > 0.10:
		_fail("re-seated socket no longer lands on the unchanged rod end")
		return

	print("EDITOR_SOCKET_070_SMOKE_OK: all 11/14-point sockets pickable + CROSS socket rod creation + free rod/connector placement + validated socket-to-rod re-seat")
	main.queue_free()
	await process_frame
	quit(0)
