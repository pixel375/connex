extends SceneTree

var main: Node
var failed: bool = false


func _fail(message: String) -> void:
	failed = true
	push_error("LATENCY_090_SMOKE_FAIL: %s" % message)


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

	if main.get_script() == null or not str(main.get_script().resource_path).ends_with("main_v090.gd"):
		_fail("v0.5.27 runtime is not active")
		quit(1)
		return

	# Build a deliberately large disconnected scene without history commits so the
	# measured operation below reflects one real edit against an already-large
	# construction rather than the cost of constructing the benchmark itself.
	var spacing := 8.0
	for i in range(60):
		var x := 60.0 + float(i % 10) * spacing
		var z := 60.0 + float(i / 10) * spacing
		if i % 2 == 0:
			main.call("_make_connector", i % maxi(1, main.connector_defs.size() - 1), Transform3D(Basis.IDENTITY, Vector3(x, 8.0, z)))
		else:
			main.call("_make_rod", i % main.rod_defs.size(), Vector3(x - 2.0, 8.0, z), Vector3(x + 2.0, 8.0, z))

	main.call("_rebuild_connection_graph_v020")
	main.call("_snapshot_autofuse_bodies_v086")

	# Add one isolated 8-way connector as the actual user interaction target.
	var connector_index: int = mini(6, main.connector_defs.size() - 1)
	var anchor := main.call("_make_connector", connector_index, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))) as RigidBody3D
	main.call("_set_selected", anchor)
	main.call("_snapshot_autofuse_bodies_v086")

	var slots: Array = (main.connector_defs[connector_index] as Dictionary).get("slots", []) as Array
	if slots.is_empty():
		_fail("latency benchmark connector has no socket")
		quit(1)
		return

	var before_bodies: int = main.bodies.size()
	var bypass_before: int = int(main.legacy_commit_autofuse_bypasses_v090)
	var started: int = Time.get_ticks_usec()
	main.call("_extend_socket", anchor, int(slots[0]))
	var elapsed: int = Time.get_ticks_usec() - started
	var bypass_after: int = int(main.legacy_commit_autofuse_bypasses_v090)
	print("LATENCY_090_LARGE_BUILD_MS=%.2f bodies=%d" % [float(elapsed) / 1000.0, before_bodies])

	if main.bodies.size() != before_bodies + 1:
		_fail("large-build create click did not create exactly one rod")
	if bypass_after <= bypass_before:
		_fail("v0.1.7 duplicate whole-build auto-fuse was not bypassed during commit")
	# Generous shared-runner ceiling; this specifically prevents a return to the
	# multi-second behavior reported on Android while allowing noisy CI hosts.
	if elapsed > 650000:
		_fail("large-build create click exceeded 650 ms in headless CI")

	# Modern connection correctness must remain intact: the new rod is connected
	# through the authoritative v0.2+ graph despite the legacy matcher being gone.
	main.call("_rebuild_connection_graph_v020")
	var newest := main.bodies.back() as RigidBody3D
	if not is_instance_valid(newest) or str(newest.get_meta("kind", "")) != "rod":
		_fail("newly created large-build piece is not a rod")
	else:
		var occupied: Dictionary = newest.get_meta("end_occupied", {}) as Dictionary
		if occupied.is_empty():
			_fail("modern targeted matcher did not preserve the created rod connection")

	if failed:
		quit(1)
		return
	print("LATENCY_090_SMOKE_OK: obsolete v0.1.7 whole-build commit scan retired; large-build create path remains connected")
	quit(0)
