extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MECHANICAL_SMOKE_FAIL: %s" % message)
	quit(1)


func _find_button_text(node: Node, text_value: String) -> Button:
	if node is Button and (node as Button).text == text_value:
		return node as Button
	for child_value in node.get_children():
		var found := _find_button_text(child_value as Node, text_value)
		if found != null:
			return found
	return null


func _count_plus_labels(node: Node) -> int:
	var count := 0
	if node is Label3D and (node as Label3D).text == "+":
		count += 1
	for child_value in node.get_children():
		count += _count_plus_labels(child_value as Node)
	return count


func _contains_subviewport_container(node: Node) -> bool:
	if node is SubViewportContainer:
		return true
	for child_value in node.get_children():
		if _contains_subviewport_container(child_value as Node):
			return true
	return false


func _contains_box_mesh(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
		return true
	for child_value in node.get_children():
		if child_value.name == "SelectionHighlight":
			continue
		if _contains_box_mesh(child_value as Node):
			return true
	return false


func _transform_close(a: Transform3D, b: Transform3D, tolerance: float = 0.001) -> bool:
	return a.origin.distance_to(b.origin) <= tolerance and a.basis.x.distance_to(b.basis.x) <= tolerance and a.basis.y.distance_to(b.basis.y) <= tolerance and a.basis.z.distance_to(b.basis.z) <= tolerance


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v060.gd"):
		_fail("Main scene is not using v0.6.0")
		return
	if int(main.get("rotate_space_v060")) != 0 or int(main.get("move_space_v060")) != 0:
		_fail("ITEM transform space is not the default")
		return

	# MOVE and ATTACH used to highlight each other because array indexes did not
	# match the editor-mode enum. Verify each button now reflects its own mode.
	main.call("_set_editor_mode_v032", 3, false)
	var move_button := main.get("move_mode_button_v042") as Button
	var attach_button := main.get("attach_button_v032") as Button
	if move_button == null or not move_button.text.begins_with("●") or (attach_button != null and attach_button.text.begins_with("●")):
		_fail("MOVE/ATTACH active highlight is still swapped")
		return
	main.call("_set_editor_mode_v032", 2, false)
	if attach_button == null or not attach_button.text.begins_with("●") or move_button.text.begins_with("●"):
		_fail("ATTACH/MOVE active highlight is still swapped")
		return

	if main.get("attach_preview_line_v042") != null:
		_fail("legacy ATTACH tether line still exists")
		return

	# Options must scroll so the v0.5 Saves/Recovery and Physics sections can be
	# reached on a phone-sized viewport.
	if main.get("options_scroll_v060") == null or main.get("builds_button_v050") == null or main.get("physics_gravity_label_v050") == null:
		_fail("Options scrolling or lower Saves/Physics controls missing")
		return

	# Hybrid palette: quick Rod/Conn arrows remain available alongside PARTS.
	var bottom := main.get("bottom_panel") as Control
	if bottom == null or _find_button_text(bottom, "◀ Rod") == null or _find_button_text(bottom, "Rod ▶") == null or _find_button_text(bottom, "◀ Conn") == null or _find_button_text(bottom, "Conn ▶") == null:
		_fail("hybrid quick part arrows are not visible/present")
		return
	main.call("_set_parts_tab_v050", 0)
	var grid := main.get("parts_grid_v050") as GridContainer
	if grid == null or grid.get_child_count() == 0 or not _contains_subviewport_container(grid.get_child(0)):
		_fail("Parts browser does not contain runtime 3D previews")
		return

	# CROSS uses bold + targets rather than generic dots.
	main.set("attach_mode", 2)
	main.set("attach_overlay_dirty_v050", true)
	main.call("_refresh_attach_points_v032")
	var point_root := main.get("attach_points_root_v032") as Node3D
	if point_root == null or _count_plus_labels(point_root) == 0:
		_fail("CROSS attachment points are not rendered as + markers")
		return

	# Every functional 14-point spatial socket, including the six out-of-plane IDs,
	# must be present in the attachment-point model.
	var connector_defs := main.get("connector_defs") as Array
	var spatial_index := -1
	for i in range(connector_defs.size()):
		if str((connector_defs[i] as Dictionary).get("name", "")) == "14-point 3D":
			spatial_index = i
			break
	if spatial_index < 0:
		_fail("14-point 3D definition missing")
		return
	var spatial := main.call("_make_connector", spatial_index, Transform3D(Basis.IDENTITY, Vector3(8.0, 5.0, 0.0))) as RigidBody3D
	var slots: Dictionary = {}
	for point_value in main.call("_all_attach_points_v032") as Array:
		var point := point_value as Dictionary
		if point.get("body") == spatial and str(point.get("type", "")) == "socket":
			slots[int(point.get("slot", -1))] = true
	for required_slot in [0, 45, 90, 135, 180, 225, 270, 315, 1001, 1002, 1003, 2001, 2002, 2003]:
		if not slots.has(required_slot):
			_fail("14-point attachment model is missing socket %s" % str(required_slot))
			return
	if _contains_box_mesh(spatial):
		_fail("new rounded connector still contains old box-based jaw geometry")
		return

	# Build a rod from the seed, then a CROSS connector on that rod. ITEM rotation
	# must rotate the cross connector branch around the rod while the host stays put.
	var bodies := main.get("bodies") as Array
	var seed := bodies[0] as RigidBody3D
	main.set("selected_rod_type", 2)
	main.call("_extend_socket", seed, 0)
	await process_frame
	var host_rod := main.get("selected_piece") as RigidBody3D
	if host_rod == null or str(host_rod.get_meta("kind", "")) != "rod":
		_fail("could not create host rod for mechanical tests")
		return
	main.set("selected_connector_type", 6)
	main.call("_cross_snap_v015", host_rod, host_rod.global_position)
	await process_frame
	var cross_connector := main.get("selected_piece") as RigidBody3D
	if cross_connector == null or str(cross_connector.get_meta("kind", "")) != "connector":
		_fail("could not create cross connector")
		return
	main.set("rotate_space_v060", 0)
	main.call("_set_editor_mode_v032", 1, false)
	var rot_context := main.call("_item_rotation_context_v060", cross_connector) as Dictionary
	if str(rot_context.get("kind", "")) != "cross" or (rot_context.get("names", []) as Array) != ["Y"]:
		_fail("cross connector did not expose exactly one rotation axis")
		return
	var host_before := host_rod.global_transform
	var cross_before := cross_connector.global_transform
	var cross_axis := rot_context.get("axis", Vector3.ZERO) as Vector3
	var preview := main.call("_item_rotation_candidate_v060", cross_axis, 1) as Dictionary
	if not bool(preview.get("valid", false)):
		_fail("cross connector mount-axis rotation candidate is invalid: %s" % str(preview.get("reason", "")))
		return
	main.call("_apply_world_rotation_step_v042", "Y", 1)
	await process_frame
	if not _transform_close(host_before, host_rod.global_transform):
		_fail("ITEM cross rotation moved the host rod / whole build")
		return
	if _transform_close(cross_before, cross_connector.global_transform):
		_fail("ITEM cross rotation did not rotate the connector")
		return

	# ITEM move on the same cross must change only host_along and keep the rod still.
	main.set("move_space_v060", 0)
	main.call("_set_editor_mode_v032", 3, false)
	var cross_record_before := main.call("_record_for_kind_v060", cross_connector, "cross") as Dictionary
	var along_before := float(cross_record_before.get("host_along", 0.0))
	host_before = host_rod.global_transform
	main.call("_apply_item_move_step_v060", "Y", 1)
	await process_frame
	var cross_record_after := main.call("_record_for_kind_v060", cross_connector, "cross") as Dictionary
	if absf(float(cross_record_after.get("host_along", along_before)) - along_before) < 0.1:
		_fail("cross connector did not slide along its host rod")
		return
	if not _transform_close(host_before, host_rod.global_transform):
		_fail("cross slide moved the host rod / construction")
		return

	# An axle rod gets the same single-axis ITEM move semantics and must move
	# through the connector hub without dragging that connector with it.
	main.call("_set_selected", seed)
	main.call("_insert_axle", seed)
	await process_frame
	var axle_rod := main.get("selected_piece") as RigidBody3D
	main.set("move_space_v060", 0)
	main.call("_set_editor_mode_v032", 3, false)
	var axle_context := main.call("_item_move_context_v060", axle_rod) as Dictionary
	if str(axle_context.get("kind", "")) != "axle" or (axle_context.get("names", []) as Array) != ["Y"]:
		_fail("axle rod did not expose exactly one slide axis")
		return
	var seed_before := seed.global_transform
	var axle_before := axle_rod.global_transform
	main.call("_apply_item_move_step_v060", "Y", 1)
	await process_frame
	if not _transform_close(seed_before, seed.global_transform):
		_fail("axle ITEM slide dragged the connector")
		return
	if _transform_close(axle_before, axle_rod.global_transform):
		_fail("axle rod did not slide through the hub")
		return

	# Two-finger pan path must move camera_target, independently of pinch zoom.
	var touch0 := InputEventScreenTouch.new()
	touch0.index = 0
	touch0.pressed = true
	touch0.position = Vector2(300, 300)
	main.call("_track_two_finger_pan_v060", touch0)
	var touch1 := InputEventScreenTouch.new()
	touch1.index = 1
	touch1.pressed = true
	touch1.position = Vector2(500, 300)
	main.call("_track_two_finger_pan_v060", touch1)
	var target_before := main.get("camera_target") as Vector3
	var drag0 := InputEventScreenDrag.new()
	drag0.index = 0
	drag0.position = Vector2(340, 330)
	main.call("_track_two_finger_pan_v060", drag0)
	if (main.get("camera_target") as Vector3).distance_to(target_before) < 0.001:
		_fail("two-finger pan did not move camera_target")
		return

	print("MECHANICAL_SMOKE_OK: mode highlight + no tether + hybrid/3D parts + scrollable options + 14 ports + cross/axle ITEM DOFs + camera pan")
	main.queue_free()
	await process_frame
	quit(0)
