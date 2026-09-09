extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_053_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index(defs: Array, wanted: String) -> int:
	for i in range(defs.size()):
		if str((defs[i] as Dictionary).get("name", "")) == wanted:
			return i
	return -1


func _count_source_meshes(node: Node) -> int:
	var count: int = 0
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null or str(child.name) == "SelectionHighlight":
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			count += 1
		count += _count_source_meshes(child)
	return count


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v056.gd"):
		_fail("Main is not using the v0.5.3 development runtime")
		return

	# Every user-facing long surface must be registered for full-panel pull scrolling.
	var scroll_map: Dictionary = main.get("panel_scrolls_v056") as Dictionary
	for property_name in ["options_panel", "parts_panel_v050", "builds_panel_v050", "help_panel", "physics_panel_v051", "rotation_panel", "move_panel"]:
		var panel: Control = main.get(property_name) as Control
		if panel == null or not scroll_map.has(panel.get_instance_id()):
			_fail("%s is not registered for pull-to-scroll" % property_name)
			return

	# Prove a swipe on the Options panel itself changes scroll_vertical; no scrollbar
	# grabbing is involved in this test.
	var options: Control = main.get("options_panel") as Control
	var options_scroll: ScrollContainer = scroll_map.get(options.get_instance_id()) as ScrollContainer
	if options_scroll == null or options_scroll.get_child_count() == 0:
		_fail("Options pull-scroll target is missing")
		return
	options.visible = true
	var options_content: Control = options_scroll.get_child(0) as Control
	if options_content != null:
		options_content.custom_minimum_size.y = maxf(options_content.custom_minimum_size.y, 1600.0)
	await process_frame
	options_scroll.scroll_vertical = 0
	var options_center: Vector2 = options.get_global_rect().get_center()
	if not bool(main.call("_begin_panel_scroll_v056", options_center, 4)):
		_fail("touch press on Options did not arm pull scrolling")
		return
	if not bool(main.call("_drag_panel_scroll_v056", options_center + Vector2(0.0, -180.0), 4)):
		_fail("vertical Options pull was not recognized as scrolling")
		return
	await process_frame
	if options_scroll.scroll_vertical < 80:
		_fail("pulling Options upward did not advance its scroll position")
		return
	main.call("_end_panel_scroll_v056")

	# Modal ownership must be resolvable independently of CanvasLayer ordering.
	if main.call("_active_modal_v056") != options:
		_fail("visible Options modal is not the active input owner")
		return
	if bool(main.call("_control_contains_v056", options, Vector2(1.0, 1.0))):
		_fail("outside point was incorrectly classified as inside Options")
		return
	options.visible = false
	await process_frame

	# Select must preempt every CREATE path. The guarded create picker may not place
	# anything while the one-shot Select action is armed.
	main.call("_set_editor_mode_v032", 0, false)
	main.set("select_armed_v020", true)
	var bodies: Array = main.get("bodies") as Array
	if bodies.is_empty():
		_fail("seed connector missing")
		return
	var seed: RigidBody3D = bodies[0] as RigidBody3D
	var camera: Camera3D = main.get("camera") as Camera3D
	var seed_screen: Vector2 = camera.unproject_position(seed.global_position)
	var before_select_count: int = bodies.size()
	if bool(main.call("_try_socket_create_tap_v054", seed_screen)):
		_fail("CREATE socket placement was allowed while Select was armed")
		return
	main.call("_handle_tap", seed_screen)
	await process_frame
	if bool(main.get("select_armed_v020")):
		_fail("Select did not complete after tapping the connector")
		return
	if (main.get("bodies") as Array).size() != before_select_count:
		_fail("Select tap placed a part")
		return

	# Build one ordinary socket connection for transform and occupied-source tests.
	main.call("_extend_socket", seed, 0)
	await process_frame
	bodies = main.get("bodies") as Array
	var rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if rod == null or str(rod.get_meta("kind", "")) != "rod":
		_fail("socket rod creation failed")
		return

	# User-facing WORLD terminology is replaced by STRUCTURE, and reset in that mode
	# zeros the selected connector while preserving the rigid island.
	main.call("_set_selected", seed)
	main.set("transform_space_v051", 1)
	main.call("_update_transform_ui_v051")
	var rotate_space: Button = main.get("rotate_space_button_v051") as Button
	var move_space: Button = main.get("move_space_button_v051") as Button
	if rotate_space == null or "STRUCTURE" not in rotate_space.text or "WORLD" in rotate_space.text:
		_fail("Rotate transform control was not renamed to STRUCTURE")
		return
	if move_space == null or "STRUCTURE" not in move_space.text:
		_fail("shared transform-space control is not synchronized to STRUCTURE")
		return
	var island: Array = main.call("_connected_island_v037", seed) as Array
	var turn: Dictionary = main.call("_rotation_delta_map_v020", island, Vector3.UP, deg_to_rad(45.0), seed.global_position) as Dictionary
	main.call("_apply_transform_map_v020", turn, "v0.5.3 reset setup")
	await process_frame
	var rigid_distance: float = seed.global_position.distance_to(rod.global_position)
	if seed.global_transform.basis.is_equal_approx(Basis.IDENTITY):
		_fail("structure reset setup did not rotate the connector")
		return
	main.call("_reset_rotation_v020")
	await process_frame
	if not seed.global_transform.basis.is_equal_approx(Basis.IDENTITY):
		_fail("STRUCTURE Reset Placement Rotation did not zero selected connector world rotation")
		return
	if absf(seed.global_position.distance_to(rod.global_position) - rigid_distance) > 0.03:
		_fail("STRUCTURE rotation reset changed rigid island geometry")
		return

	# Occupied SOCKET selection must resolve to the connected rod end rather than the
	# overlapping connector socket, preventing the 'no free compatible rod end' trap.
	var records: Array = main.call("_connections_for_piece_v020", seed) as Array
	var socket_record: Dictionary = {}
	for record_value in records:
		var record: Dictionary = record_value as Dictionary
		if str(record.get("kind", "")) == "socket":
			socket_record = record
			break
	if socket_record.is_empty():
		_fail("socket connection record missing")
		return
	var occupied_socket: Dictionary = {
		"type": "socket",
		"body": seed,
		"slot": int(socket_record.get("slot", -1)),
		"point": (main.call("_socket_world_v020", seed, int(socket_record.get("slot", -1))) as Dictionary).get("point", seed.global_position),
	}
	main.set("attach_mode", 0)
	var canonical_source: Dictionary = main.call("_occupied_socket_as_rod_end_v056", occupied_socket) as Dictionary
	if str(canonical_source.get("type", "")) != "rod_end" or canonical_source.get("body") != rod:
		_fail("occupied connector socket did not canonicalize to its attached rod end")
		return

	# ITEM socket ring validity must be synchronized immediately on selection. The
	# only physical Y ring must start enabled instead of gray until first rotation.
	main.set("transform_space_v051", 0)
	main.call("_set_selected", seed)
	main.call("_set_editor_mode_v032", 1, false)
	main.call("_refresh_gizmo_validity_v030")
	var axes: Dictionary = main.get("gizmo_axes_v030") as Dictionary
	var y_data: Dictionary = axes.get("Y", {}) as Dictionary
	var y_ring: MeshInstance3D = y_data.get("ring") as MeshInstance3D
	if y_ring == null or not y_ring.visible:
		_fail("valid socket ITEM rotation ring is not visible")
		return
	if y_ring.material_override == main.get("gizmo_disabled_mat_v030"):
		_fail("valid socket ITEM rotation ring starts gray")
		return

	# Recursive selection highlight must include nested spatial jaws and top/bottom
	# arc geometry on the 11-point connector.
	var defs: Array = main.get("connector_defs") as Array
	var index_11: int = _connector_index(defs, "11-point 3D")
	if index_11 < 0:
		_fail("11-point connector definition missing")
		return
	var spatial: RigidBody3D = main.call("_make_connector", index_11, Transform3D(Basis.IDENTITY, Vector3(18.0, 7.0, 12.0))) as RigidBody3D
	await process_frame
	var original_mesh_count: int = _count_source_meshes(spatial)
	main.call("_set_selected", spatial)
	main.call("_refresh_selection_highlight")
	var highlight: Node3D = spatial.get_node_or_null("SelectionHighlight") as Node3D
	if highlight == null or highlight.get_child_count() != original_mesh_count:
		_fail("selection glow did not recursively cover all 11-point spatial meshes")
		return

	# Auto-connect/explicit attach may close an exactly aligned free socket even if a
	# different fixed edge already exists between the same two physical pieces.
	var loop_rod: RigidBody3D = main.call("_make_rod", 2, Vector3(30.0, 7.0, 0.0), Vector3(36.0, 7.0, 0.0)) as RigidBody3D
	var loop_sign: int = 1
	var loop_end: Vector3 = main.call("_rod_end_v020", loop_rod, loop_sign) as Vector3
	var loop_outward: Vector3 = (main.call("_rod_axis_v020", loop_rod) as Vector3) * float(loop_sign)
	var loop_basis: Basis = main.call("_basis_align_direction_v020", main.call("_slot_dir", 0), -loop_outward, Vector3.UP) as Basis
	var loop_connector: RigidBody3D = main.call("_make_connector", 6, Transform3D(loop_basis, loop_end)) as RigidBody3D
	var initial_socket: Dictionary = main.call("_socket_world_v020", loop_connector, 0) as Dictionary
	loop_connector.global_position += loop_end - (initial_socket.get("point", loop_connector.global_position) as Vector3)
	await process_frame
	var fake_joint: Generic6DOFJoint3D = main.call("_make_fixed_joint", loop_rod, loop_connector, loop_rod.global_position) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", fake_joint, "cross", loop_connector, loop_rod, 45, 0, 0.0, null, true)
	main.call("_set_connector_occupied", loop_connector, 45, true)
	main.call("_rebuild_connection_graph_v020")
	var auto_target: Dictionary = main.call("_best_socket_for_end_v020", loop_rod, loop_sign) as Dictionary
	if auto_target.is_empty() or auto_target.get("connector") != loop_connector or int(auto_target.get("slot", -1)) != 0:
		_fail("auto-connect still skips an exactly aligned free socket when the pair has another rigid edge")
		return
	var loop_source: Dictionary = {"type": "rod_end", "body": loop_rod, "sign": loop_sign, "point": loop_end}
	var loop_target: Dictionary = {"type": "socket", "body": loop_connector, "slot": 0, "point": (main.call("_socket_world_v020", loop_connector, 0) as Dictionary).get("point", loop_end)}
	if not bool(main.call("_connect_points_v035", loop_source, loop_target)):
		_fail("aligned rigid-loop attachment was still rejected")
		return

	print("EDITOR_053_SMOKE_OK: pull scrolling + modal ownership + Select precedence + STRUCTURE reset + occupied-end source + immediate gizmo validity + recursive spatial glow + aligned rigid-loop attach")
	main.queue_free()
	await process_frame
	quit(0)
