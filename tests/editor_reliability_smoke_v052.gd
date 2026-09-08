extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_052_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index(defs: Array, wanted: String) -> int:
	for i in range(defs.size()):
		if str((defs[i] as Dictionary).get("name", "")) == wanted:
			return i
	return -1


func _count_named_prefix(node: Node, prefix: String) -> int:
	var result: int = 0
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child != null and str(child.name).begins_with(prefix):
			result += 1
	return result


func _approx_vec(a: Vector3, b: Vector3, tolerance: float = 0.03) -> bool:
	return a.distance_to(b) <= tolerance


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v054.gd"):
		_fail("Main is not using the v0.5.2 interaction runtime")
		return

	# Every overflowing editor surface must be a real ScrollContainer.
	for property_name in ["options_scroll_v054", "rotation_scroll_v054", "move_scroll_v054", "physics_scroll_v054"]:
		if not (main.get(property_name) is ScrollContainer):
			_fail("%s is not scrollable" % property_name)
			return
	var parts_panel: Control = main.get("parts_panel_v050") as Control
	var parts_scroll: ScrollContainer = main.call("_find_first_scroll_v054", parts_panel) as ScrollContainer
	if parts_scroll == null:
		_fail("Parts browser has no working ScrollContainer")
		return
	var preview_container: SubViewportContainer = main.get("parts_preview_container_v052") as SubViewportContainer
	if preview_container == null or preview_container.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Parts preview still intercepts browser swipe gestures")
		return

	# Rotate and Move side panels are owned by their active mode only and cannot collapse.
	var rotation_panel: Control = main.get("rotation_panel") as Control
	var move_panel: Control = main.get("move_panel") as Control
	main.call("_set_editor_mode_v032", 0, false)
	if rotation_panel.visible or move_panel.visible:
		_fail("Rotate/Move panel remained visible in CREATE mode")
		return
	main.call("_set_editor_mode_v032", 1, false)
	if not rotation_panel.visible or move_panel.visible:
		_fail("ROTATE mode did not exclusively own the Rotate panel")
		return
	main.call("_set_editor_mode_v032", 3, false)
	if rotation_panel.visible or not move_panel.visible:
		_fail("MOVE mode did not exclusively own the Move panel")
		return
	var rotate_collapse: Button = main.get("rotation_collapse_button") as Button
	var move_collapse: Button = main.get("move_collapse_button") as Button
	if (rotate_collapse != null and rotate_collapse.visible) or (move_collapse != null and move_collapse.visible):
		_fail("obsolete side-panel collapse controls are still visible")
		return

	# Modal surfaces must have a click-catching blocker behind them.
	var options_panel: Control = main.get("options_panel") as Control
	var blockers: Dictionary = main.get("modal_blockers_v054") as Dictionary
	if options_panel == null or not blockers.has(options_panel.get_instance_id()):
		_fail("Options modal has no world-input blocker")
		return
	options_panel.visible = true
	main.call("_sync_modal_blockers_v054")
	var blocker: ColorRect = blockers[options_panel.get_instance_id()] as ColorRect
	if blocker == null or not blocker.visible or blocker.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Options modal blocker does not stop outside clicks")
		return
	options_panel.visible = false
	main.call("_sync_modal_blockers_v054")

	# Reset Physics must reset both backing state and the visible slider knobs.
	var sliders: Dictionary = main.get("physics_sliders_v054") as Dictionary
	var gravity_slider: HSlider = sliders.get("Gravity") as HSlider
	var friction_slider: HSlider = sliders.get("Surface friction") as HSlider
	if gravity_slider == null or friction_slider == null:
		_fail("Physics sliders were not registered for visual reset")
		return
	main.set("physics_gravity_v050", 2.5)
	main.set("physics_friction_v050", 0.11)
	gravity_slider.set_value_no_signal(2.5)
	friction_slider.set_value_no_signal(0.11)
	main.call("_reset_physics_v050")
	if absf(float(main.get("physics_gravity_v050")) - 9.81) > 0.01 or absf(gravity_slider.value - 9.81) > 0.01:
		_fail("Reset Physics did not visually restore Gravity")
		return
	if absf(float(main.get("physics_friction_v050")) - 0.72) > 0.01 or absf(friction_slider.value - 0.72) > 0.01:
		_fail("Reset Physics did not visually restore Surface friction")
		return

	# Build a normal socket-connected island.
	var bodies: Array = main.get("bodies") as Array
	if bodies.is_empty():
		_fail("seed connector missing")
		return
	var seed: RigidBody3D = bodies[0] as RigidBody3D
	main.call("_extend_socket", seed, 0)
	await process_frame
	bodies = main.get("bodies") as Array
	var rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if rod == null or str(rod.get_meta("kind", "")) != "rod":
		_fail("could not build socket rod for ITEM transform test")
		return

	# Rotate the whole island first so ITEM axes are visibly different from WORLD.
	main.call("_set_selected", seed)
	var island: Array = main.call("_connected_island_v037", seed) as Array
	var turn_map: Dictionary = main.call("_rotation_delta_map_v020", island, Vector3.UP, deg_to_rad(45.0), seed.global_position) as Dictionary
	main.call("_apply_transform_map_v020", turn_map, "smoke local-frame setup")
	await process_frame
	main.set("transform_space_v051", 0)
	main.call("_set_editor_mode_v032", 3, false)
	var local_x: Vector3 = main.call("_local_axis_v051", "X") as Vector3
	if absf(local_x.dot(Vector3.RIGHT)) > 0.98:
		_fail("ITEM local axis setup did not differ from WORLD X")
		return
	var seed_before_move: Vector3 = seed.global_position
	var rod_before_move: Vector3 = rod.global_position
	var move_preview: Dictionary = main.call("_item_move_candidate_v054", local_x, 0.50) as Dictionary
	if not bool(move_preview.get("valid", false)):
		_fail("socket-connected ITEM local move was rejected: %s" % str(move_preview.get("reason", "")))
		return
	main.call("_apply_item_move_preview_v054", move_preview, "smoke attached ITEM move")
	if not _approx_vec(seed.global_position, seed_before_move + local_x * 0.50) or not _approx_vec(rod.global_position, rod_before_move + local_x * 0.50):
		_fail("attached ITEM move did not commit the rigid island along selected local axis")
		return

	# A socket-mounted connector has exactly the mount-axis rotation requested by the user.
	main.call("_set_selected", seed)
	main.call("_set_editor_mode_v032", 1, false)
	var socket_mobility: Dictionary = main.call("_mobility_v054") as Dictionary
	if str(socket_mobility.get("kind", "")) != "socket":
		_fail("socket-mounted connector was not recognized as a connection-axis ITEM")
		return
	var socket_axis: Vector3 = socket_mobility.get("axis", Vector3.ZERO) as Vector3
	var socket_rotate: Dictionary = main.call("_rotation_candidate_v030", socket_axis, 1) as Dictionary
	if not bool(socket_rotate.get("valid", false)):
		_fail("socket-mounted ITEM rotation around attachment axis was rejected: %s" % str(socket_rotate.get("reason", "")))
		return
	var seed_basis_before: Basis = seed.global_transform.basis
	main.call("_apply_transform_map_v020", socket_rotate.get("transforms", {}) as Dictionary, "smoke socket ITEM rotate")
	if seed.global_transform.basis.is_equal_approx(seed_basis_before):
		_fail("socket-mounted ITEM rotation did not change connector orientation")
		return

	# O-Ring constrained move must commit to the real body, not only the ghost.
	main.call("_place_o_ring_on_rod", rod, rod.global_position)
	await process_frame
	var rings: Array = main.get("o_ring_stops") as Array
	if rings.is_empty():
		_fail("could not create O-Ring for constrained move test")
		return
	var ring: RigidBody3D = rings[rings.size() - 1] as RigidBody3D
	main.call("_set_selected", ring)
	var ring_mobility: Dictionary = main.call("_mobility_v054") as Dictionary
	if str(ring_mobility.get("kind", "")) != "o_ring":
		_fail("O-Ring mobility record missing")
		return
	var ring_axis: Vector3 = ring_mobility.get("axis", Vector3.ZERO) as Vector3
	var ring_before: Vector3 = ring.global_position
	var ring_move: Dictionary = main.call("_item_move_candidate_v054", ring_axis, 0.50) as Dictionary
	if not bool(ring_move.get("valid", false)):
		_fail("O-Ring ITEM slide preview was rejected")
		return
	main.call("_apply_item_move_preview_v054", ring_move, "smoke O-Ring slide")
	if ring.global_position.distance_to(ring_before) < 0.20:
		_fail("O-Ring ghost move did not commit to the actual O-Ring")
		return

	# CROSS attach, rotate and slide: one ring / one arrow axis, both physically usable.
	var cross_rod: RigidBody3D = main.call("_make_rod", 2, Vector3(-3.0, 7.0, 14.0), Vector3(3.0, 7.0, 14.0)) as RigidBody3D
	var cross_connector: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0.0, 7.0, 18.0))) as RigidBody3D
	await process_frame
	var cross_socket: Dictionary = main.call("_socket_world_v020", cross_connector, 0) as Dictionary
	var cross_source: Dictionary = {"type": "socket", "body": cross_connector, "slot": 0, "point": cross_socket.get("point", cross_connector.global_position)}
	var cross_target: Dictionary = {"type": "rod_body", "body": cross_rod, "along": 0.0, "point": cross_rod.global_position}
	if not bool(main.call("_connect_points_v032", cross_source, cross_target, 2)):
		_fail("could not create CROSS mount for ITEM DOF test")
		return
	main.call("_set_selected", cross_connector)
	var cross_mobility: Dictionary = main.call("_mobility_v054") as Dictionary
	if str(cross_mobility.get("kind", "")) != "cross":
		_fail("CROSS connector was not recognized as CROSS mobility")
		return
	var cross_axis: Vector3 = cross_mobility.get("axis", Vector3.ZERO) as Vector3
	var cross_basis_before: Basis = cross_connector.global_transform.basis
	var cross_rotate: Dictionary = main.call("_rotation_candidate_v030", cross_axis, 1) as Dictionary
	if not bool(cross_rotate.get("valid", false)):
		_fail("CROSS ITEM spin was rejected: %s" % str(cross_rotate.get("reason", "")))
		return
	main.call("_apply_transform_map_v020", cross_rotate.get("transforms", {}) as Dictionary, "smoke CROSS rotate")
	if cross_connector.global_transform.basis.is_equal_approx(cross_basis_before):
		_fail("CROSS ITEM rotation did not spin connector around host rod")
		return
	var cross_before_move: Vector3 = cross_connector.global_position
	var cross_move: Dictionary = main.call("_item_move_candidate_v054", cross_axis, 0.50) as Dictionary
	if not bool(cross_move.get("valid", false)):
		_fail("CROSS ITEM slide was rejected: %s" % str(cross_move.get("reason", "")))
		return
	main.call("_apply_item_move_preview_v054", cross_move, "smoke CROSS slide")
	if cross_connector.global_position.distance_to(cross_before_move) < 0.20:
		_fail("CROSS ghost move did not commit to the actual connector")
		return

	# AXLE slide must commit when the axle rod itself is selected.
	var axle_connector: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(18.0, 7.0, 0.0))) as RigidBody3D
	main.call("_insert_axle", axle_connector)
	await process_frame
	bodies = main.get("bodies") as Array
	var axle_rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	main.call("_set_selected", axle_rod)
	var axle_mobility: Dictionary = main.call("_mobility_v054") as Dictionary
	if str(axle_mobility.get("kind", "")) != "axle":
		_fail("selected axle rod was not recognized as AXLE mobility")
		return
	var axle_axis: Vector3 = axle_mobility.get("axis", Vector3.ZERO) as Vector3
	var axle_before: Vector3 = axle_rod.global_position
	var axle_move: Dictionary = main.call("_item_move_candidate_v054", axle_axis, 0.50) as Dictionary
	if not bool(axle_move.get("valid", false)):
		_fail("AXLE ITEM slide was rejected: %s" % str(axle_move.get("reason", "")))
		return
	main.call("_apply_item_move_preview_v054", axle_move, "smoke AXLE slide")
	if axle_rod.global_position.distance_to(axle_before) < 0.20:
		_fail("AXLE ITEM move did not commit")
		return

	# Spatial connector lifecycle: all 11 sockets exist, current spatial geometry is
	# grouped, and changing to a planar connector removes every top/arc remnant immediately.
	var defs: Array = main.get("connector_defs") as Array
	var index_11: int = _connector_index(defs, "11-point 3D")
	if index_11 < 0:
		_fail("11-point connector definition missing")
		return
	var spatial: RigidBody3D = main.call("_make_connector", index_11, Transform3D(Basis.IDENTITY, Vector3(30.0, 7.0, 0.0))) as RigidBody3D
	await process_frame
	var socket_count: int = 0
	for point_value in main.call("_all_attach_points_v032") as Array:
		var point: Dictionary = point_value as Dictionary
		if point.get("body") == spatial and str(point.get("type", "")) == "socket":
			socket_count += 1
	if socket_count != 11:
		_fail("11-point connector exposes %d usable sockets instead of 11" % socket_count)
		return
	if _count_named_prefix(spatial, "SpatialSocket_") != 3:
		_fail("11-point spatial jaw assemblies are incomplete")
		return
	main.call("_rebuild_connector", spatial, 6)
	if _count_named_prefix(spatial, "SpatialSocket_") != 0 or _count_named_prefix(spatial, "SpatialArcBridgeV054") != 0:
		_fail("changing 11-point to planar left stale top/arc geometry")
		return

	# Palette selection is transient UI state and must survive Undo/Redo unchanged.
	main.set("selected_rod_type", 0)
	main.set("selected_connector_type", 6)
	main.call("_undo")
	if int(main.get("selected_rod_type")) != 0 or int(main.get("selected_connector_type")) != 6:
		_fail("Undo changed the bottom part palette selection")
		return
	main.call("_redo")
	if int(main.get("selected_rod_type")) != 0 or int(main.get("selected_connector_type")) != 6:
		_fail("Redo changed the bottom part palette selection")
		return

	print("EDITOR_052_SMOKE_OK: scrolling + modal blocking + mode-owned panels + visual physics reset + attached local move + mount rotation + O-Ring/CROSS/AXLE commits + spatial cleanup + palette-safe history")
	main.queue_free()
	await process_frame
	quit(0)
