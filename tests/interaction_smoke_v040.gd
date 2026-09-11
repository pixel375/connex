extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("INTERACTION_SMOKE_FAIL: %s" % message)
	quit(1)


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var bodies_value: Variant = main.get("bodies")
	if not (bodies_value is Array) or (bodies_value as Array).is_empty():
		_fail("runtime did not create a seed connector")
		return
	var bodies: Array = bodies_value as Array
	var seed: RigidBody3D = bodies[0] as RigidBody3D
	if not is_instance_valid(seed):
		_fail("seed connector invalid")
		return

	# Create an ordinary SOCKET rod. It is intentionally NOT an axle.
	main.call("_extend_socket", seed, 0)
	await process_frame
	bodies = main.get("bodies") as Array
	var socket_rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(socket_rod) or str(socket_rod.get_meta("kind", "")) != "rod":
		_fail("socket extension did not create a rod")
		return
	if bool(main.call("_rod_is_axle", socket_rod)):
		_fail("test rod unexpectedly counts as an axle")
		return

	# O-Ring must work on that normal rod even while CROSS is the selected mode.
	var o_ring_index: int = int(main.get("o_ring_index"))
	main.set("selected_connector_type", o_ring_index)
	main.set("attach_mode", 2)
	main.call("_place_o_ring_on_rod", socket_rod, socket_rod.global_position)
	await process_frame
	var rings: Array = main.get("o_ring_stops") as Array
	if rings.is_empty():
		_fail("O-Ring did not place on a non-axle rod")
		return
	var ring: RigidBody3D = rings[rings.size() - 1] as RigidBody3D
	if not is_instance_valid(ring) or ring.get_meta("host_rod") != socket_rod:
		_fail("O-Ring did not retain the normal rod as host")
		return
	if ring.collision_layer != 2 or ring.collision_mask != 3:
		_fail("new O-Ring did not inherit construction collision policy")
		return
	if main.get("selected_piece") != ring:
		_fail("new O-Ring was not selected after placement")
		return

	var found_tight_hole: bool = false
	for child_value in ring.get_children():
		var visual: MeshInstance3D = child_value as MeshInstance3D
		if visual != null and visual.mesh is TorusMesh:
			var torus: TorusMesh = visual.mesh as TorusMesh
			if torus.inner_radius <= 0.25:
				found_tight_hole = true
				break
	if not found_tight_hole:
		_fail("O-Ring visual hole was not tightened")
		return

	# Empty taps in ROTATE must not clear the piece selection. This catches the
	# v0.3.9 synthetic/post-gizmo tap regression.
	main.call("_set_editor_mode_v032", 1, false)
	main.call("_handle_tap", Vector2(-10000.0, -10000.0))
	await process_frame
	if main.get("selected_piece") != ring:
		_fail("ROTATE empty tap cleared selected piece")
		return

	# Build a detached rod + connector and prove the second-step SOCKET picker can
	# resolve an intentional tap on an actual free socket. v0.5.19 deliberately no
	# longer lets the whole connector body act as a giant socket hit target, because
	# that made nearby rods impossible to select in crowded constructions.
	main.call("_set_editor_mode_v032", 2, false)
	main.set("attach_mode", 0)
	var free_rod: RigidBody3D = main.call("_make_rod", 2, Vector3(-2.75, 7.0, 0.0), Vector3(2.75, 7.0, 0.0)) as RigidBody3D
	var target_connector: RigidBody3D = main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(7.5, 7.0, 0.0))) as RigidBody3D
	await process_frame
	if not is_instance_valid(free_rod) or not is_instance_valid(target_connector):
		_fail("could not create detached attach-test pieces")
		return

	var source_point: Vector3 = main.call("_rod_end_v020", free_rod, 1) as Vector3
	var source: Dictionary = {"type": "rod_end", "body": free_rod, "sign": 1, "point": source_point}
	var eligible: Array = main.call("_eligible_discrete_targets_v040", source) as Array
	var target_candidates: int = 0
	var intended_socket: Dictionary = {}
	for candidate_value in eligible:
		var candidate: Dictionary = candidate_value as Dictionary
		if candidate.get("body") == target_connector:
			target_candidates += 1
			if intended_socket.is_empty():
				intended_socket = candidate
			var record: Dictionary = main.call("_connection_record_for_point_v032", candidate) as Dictionary
			if not record.is_empty():
				_fail("eligible target list included an occupied socket")
				return
	if target_candidates < 1 or intended_socket.is_empty():
		_fail("free connector supplied no eligible socket targets")
		return

	var camera_value: Variant = main.get("camera")
	if not (camera_value is Camera3D):
		_fail("camera missing")
		return
	var camera: Camera3D = camera_value as Camera3D
	var intended_point: Vector3 = intended_socket.get("point", target_connector.global_position) as Vector3
	var target_screen: Vector2 = camera.unproject_position(intended_point)
	var picked: Dictionary = main.call("_pick_attach_target_v035", target_screen, source) as Dictionary
	if picked.is_empty() or picked.get("body") != target_connector or str(picked.get("type", "")) != "socket":
		_fail("intentional tap on a free socket did not resolve to that connector")
		return
	if not bool(main.call("_connect_points_v035", source, picked)):
		_fail("resolved free SOCKET target did not connect")
		return
	await process_frame
	var connected_record: Dictionary = main.call("_connection_record_for_point_v032", picked) as Dictionary
	if connected_record.is_empty():
		_fail("successful SOCKET attach did not create a connection record")
		return

	print("INTERACTION_SMOKE_OK: O-Ring any rod + protected selection + precise attach target")
	main.queue_free()
	await process_frame
	quit(0)
