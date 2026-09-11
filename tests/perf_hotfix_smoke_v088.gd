extends SceneTree

var main: Node
var failed: bool = false


func _fail(message: String) -> void:
	failed = true
	push_error("PERF_HOTFIX_088_SMOKE_FAIL: %s" % message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		quit(1)
		return
	main = packed.instantiate()
	root.add_child(main)
	for _i in range(4):
		await process_frame

	if main.get_script() == null or not str(main.get_script().resource_path).ends_with("main_v088.gd"):
		_fail("v0.5.25 runtime is not active")

	# Left controls should be back to the compact pre-v0.5.24 heights.
	for button_value in [main.create_button_v032, main.rotate_button_v032, main.move_mode_button_v042, main.attach_button_v032]:
		var button := button_value as Button
		if button == null or button.custom_minimum_size.y > 58.5:
			_fail("a primary left toolbar button is still oversized")
			break
	for button_value in [main.disconnect_button_v042, main.deselect_piece_button_v039]:
		var button := button_value as Button
		if button == null or button.custom_minimum_size.y > 38.5:
			_fail("a left utility button is still oversized")
			break
	for button_value in [main.new_free_rod_button_v070, main.new_free_connector_button_v070]:
		var button := button_value as Button
		if button == null or button.custom_minimum_size.y > 43.5:
			_fail("New Rod/New Connector height was not restored")
			break

	# The v0.5.24 nested state dictionaries were the expensive per-commit cache.
	# v0.5.25 stores only one Transform3D per live body.
	main.call("_snapshot_autofuse_bodies_v086")
	var cache: Dictionary = main.autofuse_body_cache_v086
	for state_value in cache.values():
		if typeof(state_value) != TYPE_TRANSFORM3D:
			_fail("autofuse cache still stores heavyweight per-body state dictionaries")
			break

	# Exercise the same connected placement path used by normal BUILD taps. Place
	# several rods from one connector and record commit latency. The threshold is
	# intentionally generous for shared CI, but catches multi-second regressions.
	main.call("_set_editor_mode_v032", 0, false)
	var connector_index := 6
	if connector_index >= main.connector_defs.size():
		connector_index = maxi(0, main.connector_defs.size() - 1)
	var connector := main.call("_make_connector", connector_index, Transform3D(Basis.IDENTITY, Vector3(45.0, 10.0, 45.0))) as RigidBody3D
	if not is_instance_valid(connector):
		_fail("could not create performance-test connector")
	else:
		main.call("_set_selected", connector)
		main.call("_commit_state")
		await process_frame
		var slots: Array = (main.connector_defs[connector_index] as Dictionary).get("slots", []) as Array
		var placement_count: int = mini(5, slots.size())
		if placement_count < 3:
			_fail("performance-test connector has too few sockets")
		else:
			var total_usec: int = 0
			var max_usec: int = 0
			for i in range(placement_count):
				var before_count: int = main.bodies.size()
				var started: int = Time.get_ticks_usec()
				main.call("_extend_socket", connector, int(slots[i]))
				var elapsed: int = Time.get_ticks_usec() - started
				total_usec += elapsed
				max_usec = maxi(max_usec, elapsed)
				await process_frame
				if main.bodies.size() != before_count + 1:
					_fail("connected placement did not create exactly one rod")
					break
			print("PERF_088_TIMING_MS placement_%d=%.2f" % [i + 1, float(elapsed) / 1000.0])
			print("PERF_088_TIMING_MS total=%.2f max=%.2f" % [float(total_usec) / 1000.0, float(max_usec) / 1000.0])
			if max_usec > 750000:
				_fail("a small-build placement exceeded 750 ms in headless CI")
			if total_usec > 2000000:
				_fail("small connected placement sequence exceeded 2 seconds in headless CI")

	if failed:
		quit(1)
		return
	print("PERF_HOTFIX_088_SMOKE_OK: compact left toolbar + lightweight targeted auto-connect verified")
	quit(0)
