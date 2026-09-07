extends SceneTree

const EXPECTED_MASK := 3
const HOME_META := "mount_home_relative_basis_v036"


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("AUDIT_SMOKE_FAIL: %s" % message)
	quit(1)


func _runtime_bodies(main: Node) -> Array:
	var value: Variant = main.get("bodies")
	return value as Array if value is Array else []


func _find_piece_uid(main: Node, uid: int) -> RigidBody3D:
	for body_value in _runtime_bodies(main):
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body) and int(body.get_meta("piece_uid_v020", -1)) == uid:
			return body
	return null


func _assert_piece_collision_policy(main: Node) -> bool:
	for body_value in _runtime_bodies(main):
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if body.collision_layer != 2 or body.collision_mask != EXPECTED_MASK:
			_fail("%s has collision layer/mask %d/%d, expected 2/%d" % [body.name, body.collision_layer, body.collision_mask, EXPECTED_MASK])
			return false
	var rings_value: Variant = main.get("o_ring_stops")
	if rings_value is Array:
		for ring_value in rings_value as Array:
			var ring: RigidBody3D = ring_value as RigidBody3D
			if is_instance_valid(ring) and (ring.collision_layer != 2 or ring.collision_mask != EXPECTED_MASK):
				_fail("O-Ring has incorrect collision layer/mask")
				return false
	return true


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var bodies: Array = _runtime_bodies(main)
	if bodies.is_empty():
		_fail("runtime did not create the seed connector")
		return
	if not _assert_piece_collision_policy(main):
		return

	# Build a simple socket chain using the same production placement functions:
	# seed connector -> rod -> mounted connector.
	var seed: RigidBody3D = bodies[0] as RigidBody3D
	main.call("_extend_socket", seed, 0)
	await process_frame
	bodies = _runtime_bodies(main)
	if bodies.size() < 2:
		_fail("socket extension did not create a rod")
		return
	var rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if str(rod.get_meta("kind", "")) != "rod":
		_fail("expected newest piece to be a rod")
		return

	main.call("_attach_connector_to_rod_end", rod, 1)
	await process_frame
	bodies = _runtime_bodies(main)
	if bodies.size() < 3:
		_fail("rod-end placement did not create a mounted connector")
		return
	var mounted: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if str(mounted.get_meta("kind", "")) != "connector":
		_fail("expected newest piece to be a connector")
		return
	var mounted_uid: int = int(main.call("_ensure_piece_uid_v020", mounted))
	var original_basis: Basis = mounted.global_transform.basis.orthonormalized()

	# Confirm the v0.3.6 mount-home metadata actually exists before history is used.
	main.call("_rebuild_connection_graph_v020")
	var records_value: Variant = main.get("connections_v020")
	var found_home: bool = false
	if records_value is Array:
		for record_value in records_value as Array:
			var record: Dictionary = record_value as Dictionary
			if record.get("connector") == mounted:
				var joint: Joint3D = record.get("joint") as Joint3D
				if is_instance_valid(joint) and joint.has_meta(HOME_META):
					found_home = true
					break
	if not found_home:
		_fail("mounted connector has no mount-relative home metadata")
		return

	# Regression for the audit finding: Roll -> Undo -> Redo -> Reset must still
	# return to the original placement orientation, not learn the rolled Redo pose
	# as a new home.
	main.call("_apply_roll_v030", 1)
	await process_frame
	var rolled: RigidBody3D = _find_piece_uid(main, mounted_uid)
	if not is_instance_valid(rolled):
		_fail("mounted connector disappeared after Roll")
		return
	var rolled_angle: float = original_basis.get_rotation_quaternion().angle_to(rolled.global_transform.basis.orthonormalized().get_rotation_quaternion())
	if rolled_angle < 0.40:
		_fail("Roll did not materially change the mounted connector orientation")
		return

	main.call("_undo")
	await process_frame
	main.call("_redo")
	await process_frame
	var redone: RigidBody3D = _find_piece_uid(main, mounted_uid)
	if not is_instance_valid(redone):
		_fail("mounted connector was not restored by Redo")
		return
	main.call("_set_selected", redone)
	main.call("_reset_rotation_v020")
	await process_frame
	var reset_piece: RigidBody3D = _find_piece_uid(main, mounted_uid)
	if not is_instance_valid(reset_piece):
		_fail("mounted connector disappeared after Reset Placement Rotation")
		return
	var reset_basis: Basis = reset_piece.global_transform.basis.orthonormalized()
	var reset_error: float = original_basis.get_rotation_quaternion().angle_to(reset_basis.get_rotation_quaternion())
	if reset_error > 0.015:
		_fail("mount home was not preserved through Undo/Redo; reset angular error=%f rad" % reset_error)
		return

	if not _assert_piece_collision_policy(main):
		return

	var snapshot_value: Variant = main.call("_capture_state")
	if not (snapshot_value is Dictionary) or not (snapshot_value as Dictionary).has("v038_mount_home"):
		_fail("v0.3.8 history snapshot is missing mount-home data")
		return

	print("AUDIT_SMOKE_OK: history mount home + construction collision policy")
	main.queue_free()
	await process_frame
	quit(0)
