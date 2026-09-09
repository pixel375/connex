extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_055_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index(defs: Array, wanted: String) -> int:
	for i in range(defs.size()):
		if str((defs[i] as Dictionary).get("name", "")) == wanted:
			return i
	return -1


func _count_live_meshes(node: Node, inside_highlight: bool = false) -> int:
	if node == null:
		return 0
	var total: int = 0
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null or child.is_queued_for_deletion():
			continue
		var now_highlight: bool = inside_highlight or str(child.name) == "SelectionHighlight"
		if child is MeshInstance3D and not now_highlight:
			total += 1
		total += _count_live_meshes(child, now_highlight)
	return total


func _count_highlight_meshes(node: Node, inside_highlight: bool = false) -> int:
	if node == null:
		return 0
	var total: int = 0
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null or child.is_queued_for_deletion():
			continue
		var now_highlight: bool = inside_highlight or str(child.name) == "SelectionHighlight"
		if child is MeshInstance3D and now_highlight:
			total += 1
		total += _count_highlight_meshes(child, now_highlight)
	return total


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v065.gd"):
		_fail("Main is not using current descendant runtime")
		return

	var defs: Array = main.get("connector_defs") as Array
	var index_14: int = _connector_index(defs, "14-point 3D")
	var index_2: int = _connector_index(defs, "Light gray 2-way")
	var index_8: int = _connector_index(defs, "White 8-way")
	if index_14 < 0 or index_2 < 0 or index_8 < 0:
		_fail("required connector definitions missing")
		return

	# Keep the unrelated v0.5.5 phantom-highlight regression.
	var spatial: RigidBody3D = main.call("_make_connector", index_14, Transform3D(Basis.IDENTITY, Vector3(35.0, 8.0, 0.0))) as RigidBody3D
	main.call("_set_selected", spatial)
	main.call("_refresh_selection_highlight")
	main.call("_rebuild_connector", spatial, index_2)
	var real_meshes: int = _count_live_meshes(spatial, false)
	var highlight_meshes: int = _count_highlight_meshes(spatial, false)
	if real_meshes <= 0 or highlight_meshes != real_meshes:
		_fail("phantom highlight regression failed after 14->2 rebuild")
		return
	await process_frame
	if _count_highlight_meshes(spatial, false) != _count_live_meshes(spatial, false):
		_fail("highlight diverged after queued deletions flushed")
		return

	# v0.5.10 intentionally RETIRES v0.5.5's wide proximity capture. A rod end
	# 2.6 units away may point perfectly at a socket, but it is not inside it and
	# must remain physically free.
	var far_connector: RigidBody3D = main.call("_make_connector", index_8, Transform3D(Basis.IDENTITY, Vector3(100.0, 8.0, 0.0))) as RigidBody3D
	var far_socket: Dictionary = main.call("_socket_world_v020", far_connector, 0) as Dictionary
	var socket_point: Vector3 = far_socket.get("point", far_connector.global_position) as Vector3
	var socket_dir: Vector3 = (far_socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var rod_end: Vector3 = socket_point + socket_dir * 2.6
	var far_rod: RigidBody3D = main.call("_make_rod", 2, rod_end + socket_dir * 6.0, rod_end) as RigidBody3D
	var connector_tf: Transform3D = far_connector.global_transform
	var rod_tf: Transform3D = far_rod.global_transform
	main.call("_rebuild_connection_graph_v020")
	var candidate: Dictionary = main.call("_best_socket_for_end_v020", far_rod, 1) as Dictionary
	if not candidate.is_empty():
		_fail("retired wide-capture matcher still accepts a 2.6-unit gap")
		return
	var fused: int = int(main.call("_auto_connect_all_v020"))
	if fused != 0:
		_fail("wide-gap candidate auto-connected despite strict overlap rule")
		return
	if far_connector.global_transform != connector_tf or far_rod.global_transform != rod_tf:
		_fail("rejected wide-gap candidate moved geometry")
		return

	print("EDITOR_055_SMOKE_OK: phantom-highlight fix retained + v0.5.5 wide capture/projection retired")
	main.queue_free()
	await process_frame
	quit(0)
