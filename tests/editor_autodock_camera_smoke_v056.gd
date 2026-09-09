extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_056_SMOKE_FAIL: %s" % message)
	quit(1)


func _socket_records_between(main: Node, connector: RigidBody3D, rods: Array) -> Array:
	var result: Array = []
	var wanted: Dictionary = {}
	for rod_value in rods:
		var rod: RigidBody3D = rod_value as RigidBody3D
		if is_instance_valid(rod):
			wanted[rod.get_instance_id()] = true
	for value in main.get("connections_v020") as Array:
		var record: Dictionary = value as Dictionary
		if str(record.get("kind", "")) != "socket" or record.get("connector") != connector:
			continue
		var rod: RigidBody3D = record.get("rod") as RigidBody3D
		if is_instance_valid(rod) and wanted.has(rod.get_instance_id()):
			result.append(record)
	return result


func _make_surrounding_rods(main: Node, center: Vector3, directions: Array, gap: float = 0.58) -> Array:
	var rods: Array = []
	var connector_d: float = float(main.get("CONNECTOR_D")) if main.get("CONNECTOR_D") != null else 1.35
	for direction_value in directions:
		var direction: Vector3 = (direction_value as Vector3).normalized()
		var inner: Vector3 = center + direction * (connector_d + gap)
		var outer: Vector3 = inner + direction * 10.0
		var rod: RigidBody3D = main.call("_make_rod", 2, inner, outer) as RigidBody3D
		rod.set_meta("build_transform", rod.global_transform)
		rods.append(rod)
	return rods


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v061.gd"):
		_fail("Main is not using v0.5.6 runtime")
		return

	# ------------------------------------------------------------------
	# Exact device scenario: a vertical axle rod already sits inside a group of
	# three inward-facing free horizontal rod ends. Placing the 8-port connector
	# on that axle must roll it to the surrounding rods and create three SOCKET
	# graph records immediately, not merely look close.
	# ------------------------------------------------------------------
	var center := Vector3(55.0, 12.0, 18.0)
	var host: RigidBody3D = main.call("_make_rod", 2, center - Vector3.UP * 8.0, center + Vector3.UP * 8.0) as RigidBody3D
	host.set_meta("build_transform", host.global_transform)
	var directions: Array = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	var side_rods: Array = _make_surrounding_rods(main, center, directions, 0.62)
	main.set("selected_connector_type", 6)
	main.call("_place_connector_on_rod_as_axle", host, center)
	await process_frame
	main.call("_rebuild_connection_graph_v020")
	var placed: RigidBody3D = main.get("last_placed_connector") as RigidBody3D
	if not is_instance_valid(placed):
		_fail("8-port axle connector was not placed")
		return
	var axle_record: Dictionary = main.call("_axle_record_for_connector_v061", placed) as Dictionary
	if axle_record.is_empty() or axle_record.get("rod") != host:
		_fail("placed connector is not recorded on the central axle")
		return
	var immediate_records: Array = _socket_records_between(main, placed, side_rods)
	if immediate_records.size() < 3:
		_fail("axle placement created only %d/3 surrounding SOCKET joints" % immediate_records.size())
		return
	for record_value in immediate_records:
		var gap: float = float(main.call("_connection_gap_v059", record_value as Dictionary))
		if gap > 0.10:
			_fail("immediate auto-dock left a visible socket gap %.3f" % gap)
			return

	# ------------------------------------------------------------------
	# Simulation must repair an unrecorded visually-close socket too. Create a
	# fourth rod after placement, aligned with an unused 8-port direction. Before
	# preflight it has no socket record; after preflight it must be fused.
	# ------------------------------------------------------------------
	var fourth_rods: Array = _make_surrounding_rods(main, center, [Vector3.FORWARD], 0.54)
	var fourth: RigidBody3D = fourth_rods[0] as RigidBody3D
	main.call("_rebuild_connection_graph_v020")
	if not _socket_records_between(main, placed, [fourth]).is_empty():
		_fail("fourth rod unexpectedly started connected; fixture invalid")
		return
	main.call("_prepare_stable_simulation_graph")
	main.call("_rebuild_connection_graph_v020")
	var preflight_records: Array = _socket_records_between(main, placed, [fourth])
	if preflight_records.is_empty():
		_fail("simulation preflight did not create the missing nearby SOCKET joint")
		return
	if float(main.call("_connection_gap_v059", preflight_records[0] as Dictionary)) > 0.10:
		_fail("simulation preflight created a joint but did not snap its geometry closed")
		return

	# ------------------------------------------------------------------
	# Camera regression: high-distance pan must stay bounded and pinch must be
	# ratio based, monotonic, and honor the 3..420 range.
	# ------------------------------------------------------------------
	main.set("camera_distance", 400.0)
	var target_before: Vector3 = main.get("camera_target") as Vector3
	main.call("_pan_camera", Vector2(100.0, 100.0))
	var target_after: Vector3 = main.get("camera_target") as Vector3
	var pan_distance: float = target_before.distance_to(target_after)
	if pan_distance <= 0.01 or pan_distance > 55.0:
		_fail("high-zoom camera pan is unstable/bounded incorrectly: %.3f" % pan_distance)
		return

	main.set("camera_distance", 100.0)
	var zoom_in: float = float(main.call("_apply_pinch_zoom_v061", 200.0, 300.0))
	if zoom_in >= 100.0:
		_fail("spreading fingers did not zoom in")
		return
	main.set("camera_distance", 100.0)
	var zoom_out: float = float(main.call("_apply_pinch_zoom_v061", 300.0, 200.0))
	if zoom_out <= 100.0:
		_fail("pinching fingers did not zoom out")
		return
	main.set("camera_distance", 3.1)
	var min_zoom: float = float(main.call("_apply_pinch_zoom_v061", 100.0, 1000.0))
	if min_zoom < 3.0 - 0.001:
		_fail("camera zoom crossed minimum distance")
		return
	main.set("camera_distance", 419.0)
	var max_zoom: float = float(main.call("_apply_pinch_zoom_v061", 1000.0, 100.0))
	if max_zoom > 420.0 + 0.001:
		_fail("camera zoom crossed maximum distance")
		return

	print("EDITOR_056_SMOKE_OK: axle-mounted 8-port auto-roll + 3 immediate socket fusions + simulation missing-joint preflight + closed geometry + bounded pan + ratio pinch zoom")
	main.queue_free()
	await process_frame
	quit(0)
