extends SceneTree

const CONNECTOR_TYPE := 6
const ROD_TYPE := 2

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("CROSS_SOCKET_SLIDE_074_SMOKE_FAIL: %s" % message)
	quit(1)

func _cross_record(main: Node, connector: RigidBody3D, rod: RigidBody3D) -> Dictionary:
	main.call("_rebuild_connection_graph_v020")
	for value in (main.get("connections_v020") as Array):
		var rec := value as Dictionary
		if rec.get("connector") == connector and rec.get("rod") == rod:
			return rec
	return {}

func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	if not str(main.get_script().resource_path).ends_with("main_v074.gd"):
		_fail("Main is not using v0.5.18 candidate runtime")
		return

	main.set("selected_rod_type", ROD_TYPE)
	var connector := main.call("_make_connector", CONNECTOR_TYPE, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))) as RigidBody3D
	connector.set_meta("build_transform", connector.global_transform)
	var slot := 0
	var socket := main.call("_socket_world_v020", connector, slot) as Dictionary
	var socket_point := socket.get("point", connector.global_position) as Vector3
	var connector_before := connector.global_transform
	var rod := main.call("_place_cross_rod_in_socket_v074", connector, slot) as RigidBody3D
	if not is_instance_valid(rod):
		_fail("CROSS socket did not create a rod")
		return

	if rod.global_position.distance_to(socket_point) > 0.05:
		_fail("new CROSS rod was not centered at the clicked socket; midpoint gap %.3f" % rod.global_position.distance_to(socket_point))
		return
	var rod_axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var socket_dir := (connector.global_transform.basis * (main.call("_slot_dir", slot) as Vector3)).normalized()
	if absf(rod_axis.dot(socket_dir)) > 0.08:
		_fail("CROSS rod axis is not perpendicular to the socket direction")
		return
	var record := _cross_record(main, connector, rod)
	if record.is_empty() or str(record.get("kind", "")) != "cross":
		_fail("midpoint rod was not stored as a CROSS connection")
		return
	if int(record.get("slot", -1)) != slot:
		_fail("CROSS connection lost the exact clicked socket")
		return
	if absf(float(record.get("host_along", 999.0))) > 0.05:
		_fail("new CROSS rod did not start at its midpoint")
		return
	var occupied := connector.get_meta("occupied", {}) as Dictionary
	if not occupied.has(slot):
		_fail("clicked socket was not marked occupied")
		return

	main.call("_set_selected", rod)
	main.call("_set_editor_mode_v032", int(main.get("EDITOR_MOVE_042")) if main.get("EDITOR_MOVE_042") != null else 3, false)
	await process_frame
	var special := main.call("_cross_slide_record_v074", rod) as Dictionary
	if special.is_empty():
		_fail("new CROSS rod did not expose its slide-only MOVE topology")
		return
	var gizmo := main.get("move_gizmo_root_v042") as Node3D
	if not is_instance_valid(gizmo) or not gizmo.visible:
		_fail("MOVE gizmo was not shown for the CROSS rod")
		return
	if gizmo.global_position.distance_to(rod.global_position) < 0.20:
		_fail("CROSS slide gizmo was not offset beside the rod")
		return

	var camera := main.get("camera") as Camera3D
	var screen_center := camera.unproject_position(gizmo.global_position)
	if not bool(main.call("_begin_move_drag_v042", screen_center)):
		_fail("slide gizmo could not begin a drag")
		return
	var screen_dir := main.get("move_drag_screen_dir_v042") as Vector2
	main.call("_update_move_drag_v042", screen_center + screen_dir * 110.0)
	main.call("_finish_move_drag_v042")
	await process_frame

	var travel := (rod.global_position - socket_point).dot(rod_axis)
	if absf(travel) < 0.45:
		_fail("dragging the slide gizmo did not move the rod through the socket")
		return
	if connector.global_transform.origin.distance_to(connector_before.origin) > 0.01:
		_fail("sliding the CROSS rod moved the connector instead of only the rod")
		return
	record = _cross_record(main, connector, rod)
	if record.is_empty() or str(record.get("kind", "")) != "cross":
		_fail("CROSS record disappeared after sliding")
		return
	var expected_host := -travel
	if absf(float(record.get("host_along", 0.0)) - expected_host) > 0.10:
		_fail("CROSS host_along did not track rod slide")
		return

	var bundle := main.call("_save_bundle_v050", "CrossSlide074") as Dictionary
	if not bool(main.call("_restore_bundle_v050", bundle, "CrossSlide074")):
		_fail("CROSS rod save/load failed")
		return
	await process_frame
	var restored_rod: RigidBody3D = null
	var restored_connector: RigidBody3D = null
	for value in (main.get("bodies") as Array):
		var body := value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if int(body.get_meta("piece_uid_v020", -1)) == int(rod.get_meta("piece_uid_v020", -2)):
			restored_rod = body
		elif int(body.get_meta("piece_uid_v020", -1)) == int(connector.get_meta("piece_uid_v020", -3)):
			restored_connector = body
	if not is_instance_valid(restored_rod) or not is_instance_valid(restored_connector):
		_fail("CROSS rod or connector was lost after save/load")
		return
	var restored_record := _cross_record(main, restored_connector, restored_rod)
	if restored_record.is_empty() or str(restored_record.get("kind", "")) != "cross":
		_fail("CROSS midpoint topology did not survive save/load")
		return
	if (main.call("_cross_slide_record_v074", restored_rod) as Dictionary).is_empty():
		_fail("loaded CROSS rod lost its slide-only MOVE behavior")
		return

	print("CROSS_SOCKET_SLIDE_074_SMOKE_OK: CROSS socket created a midpoint rod, MOVE showed a rod-axis gizmo beside it, sliding moved only the rod and updated host_along, and save/load preserved the topology")
	quit(0)
