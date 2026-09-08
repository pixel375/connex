extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CONSTRAINT_SMOKE_FAIL: %s" % message)
	quit(1)


func _find_visible_button(node: Node, text_value: String) -> bool:
	if node is Button:
		var button := node as Button
		if button.text == text_value and button.visible:
			return true
	for child_value in node.get_children():
		if _find_visible_button(child_value as Node, text_value):
			return true
	return false


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v051.gd"):
		_fail("Main scene is not using v0.5.1")
		return
	if int(main.get("transform_space_v051")) != 0:
		_fail("ITEM transform space is not the default")
		return

	# MOVE/ATTACH are enum 3/2, so explicit mapping must highlight the right one.
	main.call("_set_editor_mode_v032", 3, false)
	var move_button := main.get("move_mode_button_v042") as Button
	var attach_button := main.get("attach_button_v032") as Button
	if move_button == null or attach_button == null or not move_button.text.begins_with("● ") or attach_button.text.begins_with("● "):
		_fail("MOVE highlights the wrong editor mode")
		return
	main.call("_set_editor_mode_v032", 2, false)
	if not attach_button.text.begins_with("● ") or move_button.text.begins_with("● "):
		_fail("ATTACH highlights the wrong editor mode")
		return

	# The buggy ATTACH line is intentionally gone.
	if main.get("attach_preview_line_v042") != null:
		_fail("ATTACH line preview still exists")
		return

	# Options must contain a ScrollContainer so appended Saves/Physics are reachable.
	var options := main.get("options_panel") as PanelContainer
	if options == null or options.find_child("OptionsScrollV051", true, false) == null:
		_fail("Options was not made scrollable")
		return

	# Quick arrows and PARTS coexist in the hybrid selector.
	var bottom := main.get("bottom_panel") as PanelContainer
	if bottom == null or not _find_visible_button(bottom, "◀ Rod") or not _find_visible_button(bottom, "Rod ▶") or not _find_visible_button(bottom, "◀ Conn") or not _find_visible_button(bottom, "Conn ▶"):
		_fail("hybrid quick part arrows are not visible")
		return
	if main.get("parts_button_v050") == null:
		_fail("PARTS browser button disappeared")
		return

	var bodies: Array = main.get("bodies") as Array
	var seed := bodies[0] as RigidBody3D
	main.call("_extend_socket", seed, 0)
	await process_frame
	bodies = main.get("bodies") as Array
	var attached_rod := bodies[bodies.size() - 1] as RigidBody3D
	var occupied_socket := {"type": "socket", "body": seed, "slot": 0, "point": main.call("_socket_world_v020", seed, 0)["point"]}
	var counterpart := main.call("_counterpart_for_occupied_source_v051", occupied_socket) as Dictionary
	if str(counterpart.get("type", "")) != "rod_end" or counterpart.get("body") != attached_rod:
		_fail("occupied socket was not converted to the moving rod endpoint")
		return

	# CROSS markers are bold + labels instead of ambiguous dots.
	main.set("attach_mode", 2)
	main.set("attach_overlay_dirty_v050", true)
	main.call("_refresh_attach_points_v032")
	var attach_root := main.get("attach_points_root_v032") as Node3D
	var found_plus := false
	for child_value in attach_root.get_children():
		var label := child_value as Label3D
		if label != null and label.text == "+":
			found_plus = true
			break
	if not found_plus:
		_fail("CROSS overlay has no + markers")
		return

	# Spatial 11/14 point ports must survive full 3D nearest-slot picking.
	var connector_defs: Array = main.get("connector_defs") as Array
	var spatial_index := -1
	var spatial_slot := -1
	for i in range(connector_defs.size()):
		var definition: Dictionary = connector_defs[i] as Dictionary
		if bool(definition.get("spatial_3d", false)):
			spatial_index = i
			for slot_value in definition.get("slots", []):
				if int(slot_value) >= 1000:
					spatial_slot = int(slot_value)
					break
			break
	if spatial_index < 0 or spatial_slot < 0:
		_fail("no spatial connector definition found")
		return
	var spatial_connector := main.call("_make_connector", spatial_index, Transform3D(Basis.IDENTITY, Vector3(20.0, 8.0, 0.0))) as RigidBody3D
	var spatial_dir := main.call("_slot_dir", spatial_slot) as Vector3
	var anchor := spatial_connector.global_position + spatial_dir * float(main.get("CONNECTOR_D"))
	if int(main.call("_nearest_slot_v020", spatial_connector, anchor)) != spatial_slot:
		_fail("3D spatial socket collapses back to a planar slot")
		return

	# Visual fork mouths must remain open; no wide bridge is allowed at the tip.
	var fork_root: Node3D = null
	for child_value in seed.get_children():
		var child := child_value as Node3D
		if child != null and str(child.name).begins_with("SocketV051_"):
			fork_root = child
			break
	if fork_root == null:
		_fail("new connector fork geometry missing")
		return
	for child_value in fork_root.get_children():
		var mesh_instance := child_value as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh is BoxMesh:
			var box := mesh_instance.mesh as BoxMesh
			if mesh_instance.position.x > 1.25 and box.size.z > 0.40:
				_fail("connector fork mouth is closed by a bridge")
				return

	# Build an exact CROSS mount and prove ITEM rotation/movement use only its rod axis.
	var host_rod := main.call("_make_rod", 2, Vector3(0.0, 10.0, 0.0), Vector3(0.0, 20.0, 0.0)) as RigidBody3D
	var cross_anchor := Vector3(0.0, 15.0, 0.0)
	var cross_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, cross_anchor - Vector3.RIGHT * float(main.get("CONNECTOR_D")))) as RigidBody3D
	var cross_joint := main.call("_make_fixed_joint", cross_connector, host_rod, cross_anchor) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", cross_joint, "cross", cross_connector, host_rod, 0, 0, 0.0, null, true)
	main.call("_rebuild_connection_graph_v020")
	main.call("_set_selected", cross_connector)
	main.set("transform_space_v051", 0)
	var context := main.call("_item_context_v051", cross_connector) as Dictionary
	if not bool(context.get("constrained", false)) or str(context.get("mount_kind", "")) != "cross":
		_fail("cross-mounted connector did not resolve to constrained ITEM context")
		return
	var host_axis := main.call("_rod_axis_v020", host_rod) as Vector3
	if absf((context.get("axis", Vector3.ZERO) as Vector3).dot(host_axis)) < 0.99:
		_fail("cross ITEM axis does not follow host rod")
		return
	var rotate_preview := main.call("_rotation_candidate_v030", host_axis, 1) as Dictionary
	if not bool(rotate_preview.get("valid", false)):
		_fail("cross connector cannot rotate around host rod")
		return
	var before_position := cross_connector.global_position
	var move_preview := main.call("_item_move_candidate_v051", host_axis, 1) as Dictionary
	if not bool(move_preview.get("valid", false)) or str(move_preview.get("special", "")) != "cross":
		_fail("cross connector cannot slide along host rod")
		return
	if not bool(main.call("_apply_move_candidate_v051", move_preview, "smoke cross slide")):
		_fail("cross slide could not be applied")
		return
	if absf((cross_connector.global_position - before_position).dot(host_axis)) < 0.45:
		_fail("cross slide did not move along host rod")
		return

	print("CONSTRAINT_SMOKE_OK: mode mapping + attach retarget + plus markers + spatial ports + open forks + constrained cross transforms")
	main.queue_free()
	await process_frame
	quit(0)
