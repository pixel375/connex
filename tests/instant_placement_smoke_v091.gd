extends SceneTree

var main: Node
var failed: bool = false


func _fail(message: String) -> void:
	failed = true
	push_error("INSTANT_091_SMOKE_FAIL: %s" % message)


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

	if main.get_script() == null or not str(main.get_script().resource_path).ends_with("main_v091.gd"):
		_fail("v0.5.28 runtime is not active")
		quit(1)
		return

	# Build a much larger background than normal unit tests. Nothing is committed
	# while constructing the fixture so the measured operation is a single user tap.
	var spacing := 7.5
	for i in range(160):
		var x := 80.0 + float(i % 16) * spacing
		var z := 80.0 + float(i / 16) * spacing
		if i % 2 == 0:
			main.call("_make_connector", i % maxi(1, main.connector_defs.size() - 1), Transform3D(Basis.IDENTITY, Vector3(x, 8.0, z)))
		else:
			main.call("_make_rod", i % main.rod_defs.size(), Vector3(x - 2.0, 8.0, z), Vector3(x + 2.0, 8.0, z))

	main.call("_rebuild_connection_graph_v020")
	main.call("_snapshot_autofuse_bodies_v086")

	var connector_index: int = mini(6, main.connector_defs.size() - 1)
	var anchor := main.call("_make_connector", connector_index, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))) as RigidBody3D
	main.call("_set_selected", anchor)
	main.call("_rebuild_connection_graph_v020")
	main.call("_snapshot_autofuse_bodies_v086")

	var slots: Array = (main.connector_defs[connector_index] as Dictionary).get("slots", []) as Array
	if slots.is_empty():
		_fail("benchmark connector has no socket")
		quit(1)
		return

	var before_bodies: int = main.bodies.size()
	var before_state_index: int = int(main.state_index)
	var started: int = Time.get_ticks_usec()
	main.call("_extend_socket", anchor, int(slots[0]))
	var dispatch_usec: int = Time.get_ticks_usec() - started
	var dispatch_ms: float = float(dispatch_usec) / 1000.0
	print("INSTANT_091_VISIBLE_MS=%.2f bodies=%d queued=%s" % [dispatch_ms, before_bodies, str(main.placement_commit_queued_v091)])

	# The real body must exist synchronously, while expensive history work must not.
	if main.bodies.size() != before_bodies + 1:
		_fail("visible-first create did not synchronously add exactly one real rod")
	if not bool(main.placement_commit_queued_v091):
		_fail("placement history/finalize was not deferred past the visible mutation")
	if int(main.state_index) != before_state_index:
		_fail("history advanced before the visible-first function returned")
	# Shared runners are noisy; the important regression is that this no longer
	# scales with the 160-piece fixture. 120 ms is deliberately strict enough to
	# catch a returned whole-build scan but loose enough for hosted CI variance.
	if dispatch_usec > 120000:
		_fail("tap-to-real-piece path exceeded 120 ms on a 162-body construction")

	# Headless flushes on the next deferred turn; Android waits for frame_post_draw.
	for _i in range(3):
		await process_frame

	if bool(main.placement_commit_queued_v091) or bool(main.placement_commit_pending_v091):
		_fail("deferred placement commit did not finish")
	if int(main.state_index) <= before_state_index:
		_fail("deferred finalize did not create an Undo history state")

	var newest := main.bodies.back() as RigidBody3D
	if not is_instance_valid(newest) or str(newest.get_meta("kind", "")) != "rod":
		_fail("newly visible piece is not a rod")
	else:
		var occupied: Dictionary = newest.get_meta("end_occupied", {}) as Dictionary
		if occupied.is_empty():
			_fail("deferred modern connection finalize lost the rod connection")

	if int(main.profile_graph_skips_v091) < 2:
		_fail("placement did not bypass the redundant create-time graph rebuilds")

	print("INSTANT_091_FINALIZE_MS=%.2f capture=%.2f auto=%.2f graph=%.2f ui=%.2f graph_skips=%d" % [
		float(main.last_deferred_commit_ms_v091),
		float(main.profile_capture_ms_v091),
		float(main.profile_autoconnect_ms_v091),
		float(main.profile_graph_ms_v091),
		float(main.profile_ui_ms_v091),
		int(main.profile_graph_skips_v091),
	])

	if failed:
		quit(1)
		return
	print("INSTANT_091_SMOKE_OK: 160-piece construction creates the real part before deferred history/auto-connect bookkeeping")
	quit(0)
