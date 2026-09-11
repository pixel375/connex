extends SceneTree

const EDITOR_ATTACH := 2
const MODE_CROSS := 2
const ROD_TYPE := 2

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("ATTACH_UNDO_SPATIAL_CROSS_075_SMOKE_FAIL: %s" % message)
	quit(1)

func _connector_index_named(main: Node, name_value: String) -> int:
	var defs := main.get("connector_defs") as Array
	for i in range(defs.size()):
		var definition := defs[i] as Dictionary
		if str(definition.get("name", "")) == name_value:
			return i
	return -1

func _cross_record(main: Node, connector: RigidBody3D, rod: RigidBody3D) -> Dictionary:
	main.call("_rebuild_connection_graph_v020")
	for value in (main.get("connections_v020") as Array):
		var rec := value as Dictionary
		if str(rec.get("kind", "")) == "cross" and rec.get("connector") == connector and rec.get("rod") == rod:
			return rec
	return {}

func _has_marker_near(root_node: Node3D, point: Vector3, tolerance: float = 0.08) -> bool:
	if not is_instance_valid(root_node):
		return false
	for child_value in root_node.get_children():
		var child := child_value as Node3D
		if child != null and not child.is_queued_for_deletion() and child.visible and child.global_position.distance_to(point) <= tolerance:
			return true
	return false

func _assert_cross_axis(main: Node, connector_index: int, slot: int, expected_axis: Vector3, label: String) -> bool:
	var connector := main.call("_make_connector", connector_index, Transform3D(Basis.IDENTITY, Vector3(30.0 + float(slot % 10) * 4.0, 10.0, 20.0))) as RigidBody3D
	connector.set_meta("build_transform", connector.global_transform)
	main.set("selected_rod_type", ROD_TYPE)
	var rod := main.call("_place_cross_rod_in_socket_v074", connector, slot) as RigidBody3D
	if not is_instance_valid(rod):
		_fail("%s did not create a CROSS rod" % label)
		return false
	var rod_axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	if absf(rod_axis.dot(expected_axis.normalized())) < 0.985:
		_fail("%s CROSS axis was %s instead of %s" % [label, str(rod_axis), str(expected_axis.normalized())])
		return false
	var record := _cross_record(main, connector, rod)
	if record.is_empty():
		_fail("%s did not produce a CROSS record" % label)
		return false
	var validation := main.call("_validate_record_v020", record, {}) as Dictionary
	if not bool(validation.get("valid", false)):
		_fail("%s CROSS record rejected its own placement: %s" % [label, str(validation.get("reason", "unknown"))])
		return false
	return true

func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	if not str(main.get_script().resource_path).ends_with("main_v075.gd"):
		_fail("Main is not using v0.5.19 candidate runtime")
		return

	# 1) Spatial CROSS orientation: ordinary flat-ring sockets use connector-local Y;
	# top/bottom half-ring sockets use connector-local Z, so their CROSS rod is horizontal.
	var eleven_index := _connector_index_named(main, "11-point 3D")
	var fourteen_index := _connector_index_named(main, "14-point 3D")
	if eleven_index < 0 or fourteen_index < 0:
		_fail("11-point or 14-point connector definition is missing")
		return
	if not _assert_cross_axis(main, eleven_index, 0, Vector3.UP, "11-point planar socket"):
		return
	if not _assert_cross_axis(main, eleven_index, 1002, Vector3.BACK, "11-point top socket"):
		return
	if not _assert_cross_axis(main, fourteen_index, 2002, Vector3.BACK, "14-point bottom socket"):
		return

	# 2) Dense ATTACH picking: when the physical ray lands on a rod in CROSS mode,
	# that exact rod shaft must win even if connector port markers are nearby.
	var pick_connector := main.call("_make_connector", eleven_index, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))) as RigidBody3D
	pick_connector.set_meta("build_transform", pick_connector.global_transform)
	var pick_rod := main.call("_make_rod", ROD_TYPE, Vector3(1.55, 5.4, 0.0), Vector3(1.55, 10.6, 0.0)) as RigidBody3D
	pick_rod.set_meta("build_transform", pick_rod.global_transform)
	var camera := main.get("camera") as Camera3D
	main.set("camera_target", Vector3(0.75, 8.0, 0.0))
	camera.global_position = Vector3(0.75, 10.2, 15.5)
	camera.look_at(Vector3(0.75, 8.0, 0.0), Vector3.UP)
	await physics_frame
	var rod_screen := camera.unproject_position(pick_rod.global_position)
	var physical_hit := main.call("_raycast_piece", rod_screen) as Dictionary
	if physical_hit.is_empty() or physical_hit.get("collider") != pick_rod:
		_fail("ATTACH picking fixture did not physically ray-hit the nearby rod")
		return
	var nearest_socket_px := INF
	for slot_value in (main.get("connector_defs") as Array)[eleven_index]["slots"]:
		var socket := main.call("_socket_world_v020", pick_connector, int(slot_value)) as Dictionary
		var point := socket.get("point", pick_connector.global_position) as Vector3
		if not camera.is_position_behind(point):
			nearest_socket_px = minf(nearest_socket_px, camera.unproject_position(point).distance_to(rod_screen))
	if nearest_socket_px > 108.0:
		_fail("ATTACH picking fixture is not crowded enough; nearest socket is %.1f px away" % nearest_socket_px)
		return
	main.set("attach_mode", MODE_CROSS)
	main.call("_set_editor_mode_v032", EDITOR_ATTACH, false)
	var picked := main.call("_pick_initial_attach_point_v035", rod_screen) as Dictionary
	if str(picked.get("type", "")) != "rod_body" or picked.get("body") != pick_rod:
		_fail("nearby connector socket stole a CROSS ATTACH tap from the physical rod")
		return

	# 3) Undo overlay refresh: make a dedicated connector, commit pose A, rotate and
	# commit pose B, build ATTACH markers in B, then Undo. Markers must immediately
	# return to pose A without requiring another click/UI action.
	main.call("_set_editor_mode_v032", 0, false)
	var undo_connector := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(-12.0, 9.0, -4.0))) as RigidBody3D
	undo_connector.set_meta("build_transform", undo_connector.global_transform)
	var undo_uid := int(main.call("_ensure_piece_uid_v020", undo_connector))
	main.call("_commit_state")
	var before_socket := (main.call("_socket_world_v020", undo_connector, 0) as Dictionary).get("point", undo_connector.global_position) as Vector3
	var rotated := undo_connector.global_transform
	rotated.basis = (Basis(Vector3.UP, PI * 0.5) * rotated.basis).orthonormalized()
	undo_connector.global_transform = rotated
	undo_connector.set_meta("build_transform", rotated)
	main.call("_commit_state")
	var rotated_socket := (main.call("_socket_world_v020", undo_connector, 0) as Dictionary).get("point", undo_connector.global_position) as Vector3
	if before_socket.distance_to(rotated_socket) < 0.5:
		_fail("Undo overlay fixture did not rotate its socket far enough")
		return
	main.set("attach_mode", 0)
	main.call("_set_editor_mode_v032", EDITOR_ATTACH, false)
	main.call("_invalidate_attach_overlay_v075")
	var overlay := main.get("attach_points_root_v032") as Node3D
	if not _has_marker_near(overlay, rotated_socket):
		_fail("ATTACH overlay did not represent the rotated pre-Undo pose")
		return
	main.call("_undo")
	await process_frame
	var restored_connector: RigidBody3D = null
	for value in (main.get("bodies") as Array):
		var body := value as RigidBody3D
		if is_instance_valid(body) and int(body.get_meta("piece_uid_v020", -1)) == undo_uid:
			restored_connector = body
			break
	if not is_instance_valid(restored_connector):
		_fail("Undo lost the connector used by the overlay regression")
		return
	var restored_socket := (main.call("_socket_world_v020", restored_connector, 0) as Dictionary).get("point", restored_connector.global_position) as Vector3
	if restored_socket.distance_to(before_socket) > 0.08:
		_fail("Undo did not restore the connector pose")
		return
	if not _has_marker_near(overlay, restored_socket):
		_fail("ATTACH point overlay stayed at the pre-Undo rotation")
		return
	if _has_marker_near(overlay, rotated_socket, 0.12):
		_fail("stale ATTACH marker remained at the rotated position after Undo")
		return

	print("ATTACH_UNDO_SPATIAL_CROSS_075_SMOKE_OK: physical rod taps beat nearby connector markers, Undo immediately refreshes ATTACH points, and 11/14 top-bottom CROSS rods follow the local half-ring plane")
	quit(0)
