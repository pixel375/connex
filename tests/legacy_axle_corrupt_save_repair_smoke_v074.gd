extends SceneTree

const HUB_TYPE := 6
const STOP_TYPE := 0
const HOST_ROD_TYPE := 5
const CONNECTOR_D_TEST := 1.01

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("LEGACY_AXLE_REPAIR_074_SMOKE_FAIL: %s" % message)
	quit(1)

func _uid(body: RigidBody3D) -> int:
	return int(body.get_meta("piece_uid_v020", -1)) if is_instance_valid(body) else -1

func _find_uid(main: Node, uid_value: int) -> RigidBody3D:
	for value in (main.get("bodies") as Array):
		var body := value as RigidBody3D
		if is_instance_valid(body) and _uid(body) == uid_value:
			return body
	return null

func _along(main: Node, body: RigidBody3D, rod: RigidBody3D) -> float:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	return (body.global_position - rod.global_position).dot(axis)

func _add_cross_stop(main: Node, rod: RigidBody3D, y_value: float) -> RigidBody3D:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var local_slot := main.call("_slot_dir", 0) as Vector3
	var radial := Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	if radial.length_squared() < 0.1:
		radial = Vector3.BACK
	radial = radial.normalized()
	var basis := main.call("_basis_for_cross_v020", local_slot, axis, radial) as Basis
	var actual_radial := (basis * local_slot).normalized()
	var along := (Vector3(rod.global_position.x, y_value, rod.global_position.z) - rod.global_position).dot(axis)
	var snap := rod.global_position + axis * along
	var stop := main.call("_make_connector", STOP_TYPE, Transform3D(basis, snap - actual_radial * CONNECTOR_D_TEST)) as RigidBody3D
	var joint := main.call("_make_fixed_joint", rod, stop, snap) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "cross", stop, rod, 0, 0, along, null, true)
	joint.set_meta("cross_mount", true)
	stop.set_meta("cross_mount", true)
	stop.set_meta("cross_host_rod", rod)
	main.call("_set_connector_occupied", stop, 0, true)
	stop.set_meta("build_transform", stop.global_transform)
	return stop

func _add_axle_pair(main: Node, x_value: float) -> Dictionary:
	var hub := main.call("_make_connector", HUB_TYPE, Transform3D(Basis.IDENTITY, Vector3(x_value, 14.0, 0.0))) as RigidBody3D
	hub.set_meta("build_transform", hub.global_transform)
	var rod := main.call("_make_rod", HOST_ROD_TYPE, Vector3(x_value, 0.55, 0.0), Vector3(x_value, 19.75, 0.0)) as RigidBody3D
	rod.set_meta("build_transform", rod.global_transform)
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var along := (hub.global_position - rod.global_position).dot(axis)
	var joint := main.call("_make_axle_joint", hub, rod) as Generic6DOFJoint3D
	var uid := int(main.call("_tag_connection_v020", joint, "axle", hub, rod, -1, 0, along, null, true))
	hub.set_meta("axle_occupied", true)
	hub.set_meta("axle_host_rod", rod)
	hub.set_meta("primary_connection_uid_v020", uid)
	var stop := _add_cross_stop(main, rod, 9.25)
	return {"hub": hub, "rod": rod, "stop": stop}

func _corrupt_legacy_snapshot(main: Node, bundle: Dictionary, pairs: Array) -> void:
	var snapshot := bundle.get("snapshot", {}) as Dictionary
	snapshot.erase("v072_axles")
	var bodies := main.get("bodies") as Array
	var target_pairs: Array = []
	for pair_value in pairs:
		var pair := pair_value as Dictionary
		target_pairs.append(Vector2i(bodies.find(pair.get("hub")), bodies.find(pair.get("rod"))))

	var kept_connections: Array = []
	for value in (snapshot.get("v020_connections", []) as Array):
		var rec := value as Dictionary
		var key := Vector2i(int(rec.get("connector_index", -1)), int(rec.get("rod_index", -1)))
		if str(rec.get("kind", "")) == "axle" and key in target_pairs:
			continue
		kept_connections.append(rec)
	snapshot["v020_connections"] = kept_connections

	for value in (snapshot.get("joints", []) as Array):
		var state := value as Dictionary
		var a := int(state.get("a", -1))
		var b := int(state.get("b", -1))
		for pair_value in target_pairs:
			var key := pair_value as Vector2i
			if (a == key.x and b == key.y) or (a == key.y and b == key.x):
				state["type"] = "fixed"
	bundle["snapshot"] = snapshot

func _assert_one_axle_no_false_fixed(main: Node, hub: RigidBody3D, rod: RigidBody3D, label: String) -> bool:
	main.call("_rebuild_connection_graph_v020")
	var axle_count := 0
	var false_count := 0
	for value in (main.get("connections_v020") as Array):
		var rec := value as Dictionary
		if rec.get("connector") != hub or rec.get("rod") != rod:
			continue
		var kind := str(rec.get("kind", ""))
		if kind == "axle":
			axle_count += 1
		elif kind == "socket" or kind == "cross":
			false_count += 1
	if axle_count != 1 or false_count != 0:
		_fail("%s restored with axle=%d false_fixed=%d" % [label, axle_count, false_count])
		return false
	return true

func _assert_editor_slide(main: Node, hub: RigidBody3D, rod: RigidBody3D, label: String) -> bool:
	main.call("_set_selected", hub)
	var before := _along(main, hub, rod)
	main.call("_slide_selected_on_axle", -0.50)
	var after := _along(main, hub, rod)
	if absf(after - before) < 0.30:
		_fail("%s is still locked in BUILD after legacy repair" % label)
		return false
	var status := main.get("status_label") as Label
	if is_instance_valid(status) and status.text.contains("rod end would leave its exact socket"):
		_fail("%s still triggers false exact-socket validation" % label)
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
	if not str(main.get_script().resource_path).ends_with("main_v074.gd"):
		_fail("Main is not using v0.5.18 candidate runtime")
		return

	var pair_a := _add_axle_pair(main, -4.0)
	var pair_b := _add_axle_pair(main, 4.0)
	main.call("_rebuild_connection_graph_v020")
	main.call("_refresh_joint_frames_v020")
	main.call("_rebuild_connection_graph_v020")
	var pairs := [pair_a, pair_b]
	var hub_uids := [_uid(pair_a.hub), _uid(pair_b.hub)]
	var rod_uids := [_uid(pair_a.rod), _uid(pair_b.rod)]

	var bundle := main.call("_save_bundle_v050", "LegacyBroken074") as Dictionary
	_corrupt_legacy_snapshot(main, bundle, pairs)
	if not bool(main.call("_restore_bundle_v050", bundle, "LegacyBroken074")):
		_fail("corrupted v0.5.16-style bundle did not load")
		return
	await process_frame

	var hub_a := _find_uid(main, hub_uids[0])
	var hub_b := _find_uid(main, hub_uids[1])
	var rod_a := _find_uid(main, rod_uids[0])
	var rod_b := _find_uid(main, rod_uids[1])
	if not is_instance_valid(hub_a) or not is_instance_valid(hub_b) or not is_instance_valid(rod_a) or not is_instance_valid(rod_b):
		_fail("legacy restore lost a repaired hub or shaft")
		return
	if int(main.get("legacy_axle_geometry_repairs_v074")) != 2:
		_fail("expected two legacy geometry repairs, got %d" % int(main.get("legacy_axle_geometry_repairs_v074")))
		return
	if not _assert_one_axle_no_false_fixed(main, hub_a, rod_a, "hub A"):
		return
	if not _assert_one_axle_no_false_fixed(main, hub_b, rod_b, "hub B"):
		return
	if not _assert_editor_slide(main, hub_a, rod_a, "hub A"):
		return

	# A new save after migration must contain explicit v0.5.17+ AXLE identities so
	# geometry inference is no longer needed on subsequent loads.
	var healed := main.call("_save_bundle_v050", "Healed074") as Dictionary
	var healed_snapshot := healed.get("snapshot", {}) as Dictionary
	var saved_axles := healed_snapshot.get("v072_axles", []) as Array
	if saved_axles.size() < 2:
		_fail("healed save did not persist recovered AXLE identities")
		return

	print("LEGACY_AXLE_REPAIR_074_SMOKE_OK: two AXLEs intentionally corrupted into legacy fixed/socket state were recovered, false socket constraints removed, BUILD slide unlocked, and healed save persisted explicit AXLE identity")
	quit(0)
