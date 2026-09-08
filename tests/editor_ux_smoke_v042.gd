extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_UX_SMOKE_FAIL: %s" % message)
	quit(1)


func _run() -> void:
	if bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)):
		_fail("Godot boot splash image is still enabled")
		return

	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var bodies: Array = main.get("bodies") as Array
	if bodies.is_empty():
		_fail("runtime did not create seed")
		return
	var seed: RigidBody3D = bodies[0] as RigidBody3D
	main.call("_extend_socket", seed, 0)
	await process_frame
	bodies = main.get("bodies") as Array
	var rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		_fail("could not create connected rod")
		return

	main.call("_set_selected", seed)
	var seed_start: Vector3 = seed.global_position
	var rod_start: Vector3 = rod.global_position
	main.call("_set_editor_mode_v032", 3, false)
	if int(main.get("editor_mode_v032")) != 3:
		_fail("MOVE editor mode did not activate")
		return
	main.call("_apply_world_move_step_v042", Vector3.RIGHT, 1)
	await process_frame
	if absf(seed.global_position.x - (seed_start.x + 0.5)) > 0.01:
		_fail("selected piece did not move exactly +0.5 on world X")
		return
	if absf(rod.global_position.x - (rod_start.x + 0.5)) > 0.01:
		_fail("connected island did not move rigidly with selected piece")
		return

	var move_gizmo: Node3D = main.get("move_gizmo_root_v042") as Node3D
	if not is_instance_valid(move_gizmo):
		_fail("move gizmo was not created")
		return

	var before_disconnect: Array = main.call("_connections_for_piece_v020", seed) as Array
	if before_disconnect.is_empty():
		_fail("seed unexpectedly had no connection before Disconnect")
		return
	main.call("_disconnect_selected_v042")
	await process_frame
	var after_disconnect: Array = main.call("_connections_for_piece_v020", seed) as Array
	if not after_disconnect.is_empty():
		_fail("Disconnect Selected left graph edges on selected piece")
		return
	if main.get("selected_piece") != seed:
		_fail("Disconnect Selected cleared the selected piece")
		return

	main.call("_set_editor_mode_v032", 1, false)
	var basis_before: Basis = seed.global_transform.basis
	main.call("_apply_world_rotation_step_v042", "Y", 1)
	await process_frame
	if seed.global_transform.basis.is_equal_approx(basis_before):
		_fail("exact-step world rotation fallback did not rotate selected piece")
		return

	print("EDITOR_UX_SMOKE_OK: no splash + world move gizmo + rigid island move + disconnect + rotation fallback")
	main.queue_free()
	await process_frame
	quit(0)
