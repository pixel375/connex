extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("SPATIAL_SMOKE_FAIL: %s" % message)
	quit(1)


func _find_def(main: Node, name_value: String) -> int:
	var defs: Array = main.get("connector_defs") as Array
	for i in range(defs.size()):
		var definition: Dictionary = defs[i] as Dictionary
		if str(definition.get("name", "")) == name_value:
			return i
	return -1


func _count_spatial_roots(body: RigidBody3D) -> int:
	var count: int = 0
	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child != null and str(child.name).begins_with("SpatialSocket_"):
			count += 1
	return count


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var index_11: int = _find_def(main, "11-point 3D")
	var index_14: int = _find_def(main, "14-point 3D")
	if index_11 < 0 or index_14 < 0:
		_fail("11-point or 14-point definition missing from Conn list")
		return
	var defs: Array = main.get("connector_defs") as Array
	var def_11: Dictionary = defs[index_11] as Dictionary
	var def_14: Dictionary = defs[index_14] as Dictionary
	if (def_11.get("slots", []) as Array).size() != 11:
		_fail("11-point connector does not expose exactly 11 ports")
		return
	if (def_14.get("slots", []) as Array).size() != 14:
		_fail("14-point connector does not expose exactly 14 ports")
		return

	var top_dir: Vector3 = main.call("_slot_dir", 1002) as Vector3
	var bottom_dir: Vector3 = main.call("_slot_dir", 2002) as Vector3
	var top_diag: Vector3 = main.call("_slot_dir", 1001) as Vector3
	if top_dir.dot(Vector3.UP) < 0.999 or bottom_dir.dot(Vector3.DOWN) < 0.999:
		_fail("top/bottom center arc ports do not point out of the flat connector plane")
		return
	if top_diag.y < 0.69 or absf(top_diag.z) > 0.001:
		_fail("top diagonal arc port has wrong 3D direction")
		return

	var connector_11: RigidBody3D = main.call("_make_connector", index_11, Transform3D(Basis.IDENTITY, Vector3(-8.0, 7.0, 0.0))) as RigidBody3D
	var connector_14: RigidBody3D = main.call("_make_connector", index_14, Transform3D(Basis.IDENTITY, Vector3(8.0, 7.0, 0.0))) as RigidBody3D
	await process_frame
	if not is_instance_valid(connector_11) or not is_instance_valid(connector_14):
		_fail("spatial connectors could not be instantiated")
		return
	if _count_spatial_roots(connector_11) != 3:
		_fail("11-point mesh does not contain its 3 top arc socket assemblies")
		return
	if _count_spatial_roots(connector_14) != 6:
		_fail("14-point mesh does not contain top + bottom arc socket assemblies")
		return

	var top_socket: Dictionary = main.call("_socket_world_v020", connector_11, 1002) as Dictionary
	var bottom_socket: Dictionary = main.call("_socket_world_v020", connector_14, 2002) as Dictionary
	if (top_socket.get("point", connector_11.global_position) as Vector3).y <= connector_11.global_position.y:
		_fail("11-point top socket world point is not above the flat body")
		return
	if (bottom_socket.get("point", connector_14.global_position) as Vector3).y >= connector_14.global_position.y:
		_fail("14-point bottom socket world point is not below the flat body")
		return

	# Every spatial port must be a functional SOCKET source, not just a drawn arm.
	var bodies_before: int = (main.get("bodies") as Array).size()
	main.call("_extend_socket", connector_11, 1002)
	await process_frame
	var bodies_after_top: Array = main.get("bodies") as Array
	if bodies_after_top.size() != bodies_before + 1:
		_fail("top arc socket did not create a rod")
		return
	var top_rod: RigidBody3D = bodies_after_top[bodies_after_top.size() - 1] as RigidBody3D
	var top_axis: Vector3 = main.call("_rod_axis_v020", top_rod) as Vector3
	if top_axis.dot(Vector3.UP) < 0.995:
		_fail("rod from top arc socket does not extend straight up")
		return

	main.call("_extend_socket", connector_14, 2002)
	await process_frame
	var bodies_after_bottom: Array = main.get("bodies") as Array
	if bodies_after_bottom.size() != bodies_before + 2:
		_fail("bottom arc socket did not create a rod")
		return
	var bottom_rod: RigidBody3D = bodies_after_bottom[bodies_after_bottom.size() - 1] as RigidBody3D
	var bottom_axis: Vector3 = main.call("_rod_axis_v020", bottom_rod) as Vector3
	if bottom_axis.dot(Vector3.DOWN) < 0.995:
		_fail("rod from bottom arc socket does not extend straight down")
		return

	# SOCKET ATTACH overlay must advertise all of the new ports.
	main.set("attach_mode", 0)
	main.call("_set_editor_mode_v032", 2, false)
	var points: Array = main.call("_all_attach_points_v032") as Array
	var count_11: int = 0
	var count_14: int = 0
	for point_value in points:
		var point: Dictionary = point_value as Dictionary
		if str(point.get("type", "")) != "socket":
			continue
		if point.get("body") == connector_11:
			count_11 += 1
		elif point.get("body") == connector_14:
			count_14 += 1
	if count_11 != 11 or count_14 != 14:
		_fail("ATTACH overlay does not expose every spatial socket")
		return

	# Rebuilding to a normal flat connector must remove nested spatial visuals.
	main.call("_rebuild_connector", connector_11, 6)
	await process_frame
	if _count_spatial_roots(connector_11) != 0:
		_fail("converting 11-point to a planar connector left stale arc geometry")
		return

	print("SPATIAL_SMOKE_OK: 11-point + 14-point 3D connectors and functional arc ports")
	main.queue_free()
	await process_frame
	quit(0)
