extends SceneTree

var main: Node
var failed: bool = false


func _fail(message: String) -> void:
	failed = true
	push_error("HISTORY_093_SMOKE_FAIL: %s" % message)


func _initialize() -> void:
	call_deferred("_run")


func _body_ids_by_uid() -> Dictionary:
	var result: Dictionary = {}
	for body_value in main.bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			result[int(body.get_meta("piece_uid_v020", -1))] = body.get_instance_id()
	return result


func _count_preserved_ids(before: Dictionary) -> int:
	var after: Dictionary = _body_ids_by_uid()
	var preserved: int = 0
	for uid_value in before.keys():
		if after.has(uid_value) and int(after[uid_value]) == int(before[uid_value]):
			preserved += 1
	return preserved


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

	if main.get_script() == null or not str(main.get_script().resource_path).ends_with("main_v093.gd"):
		_fail("v0.5.29 history runtime is not active")
		quit(1)
		return

	# Large isolated fixture: history performance must scale with lightweight state
	# application, not destruction/recreation of every MeshInstance/CollisionShape.
	var spacing := 7.5
	for i in range(160):
		var x := 80.0 + float(i % 16) * spacing
		var z := 80.0 + float(i / 16) * spacing
		if i % 2 == 0:
			main.call("_make_connector", i % maxi(1, main.connector_defs.size() - 1), Transform3D(Basis.IDENTITY, Vector3(x, 8.0, z)))
		else:
			main.call("_make_rod", i % main.rod_defs.size(), Vector3(x - 2.0, 8.0, z), Vector3(x + 2.0, 8.0, z))

	var connector_index: int = mini(6, main.connector_defs.size() - 1)
	var anchor := main.call("_make_connector", connector_index, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))) as RigidBody3D
	main.call("_set_selected", anchor)
	main.call("_rebuild_connection_graph_v020")
	main.call("_snapshot_autofuse_bodies_v086")

	# Make this constructed fixture the sole baseline state. The following real
	# placement creates exactly one adjacent history state to Undo/Redo.
	main.state_history.clear()
	main.state_history.append(main.call("_capture_state"))
	main.state_index = 0
	var baseline_count: int = main.bodies.size()
	var baseline_ids: Dictionary = _body_ids_by_uid()

	var slots: Array = (main.connector_defs[connector_index] as Dictionary).get("slots", []) as Array
	if slots.is_empty():
		_fail("benchmark connector has no socket")
		quit(1)
		return
	main.call("_extend_socket", anchor, int(slots[0]))
	for _i in range(3):
		await process_frame
	if main.bodies.size() != baseline_count + 1 or int(main.state_index) != 1:
		_fail("visible-first placement did not create one committed history state")
		quit(1)
		return

	var started: int = Time.get_ticks_usec()
	main.call("_undo")
	var undo_usec: int = Time.get_ticks_usec() - started
	var undo_ms: float = float(undo_usec) / 1000.0
	var preserved_after_undo: int = _count_preserved_ids(baseline_ids)
	print("HISTORY_093_UNDO_MS=%.2f core=%.2f fast=%s preserved=%d/%d removed=%d created=%d" % [
		undo_ms, float(main.last_history_restore_ms_v093), str(main.history_fast_used_v093),
		preserved_after_undo, baseline_ids.size(), int(main.history_removed_bodies_v093), int(main.history_created_bodies_v093)
	])
	if not bool(main.history_fast_used_v093):
		_fail("large-build placement Undo fell back to full scene reconstruction")
	if main.bodies.size() != baseline_count or int(main.state_index) != 0:
		_fail("Undo did not restore baseline body/history count")
	if preserved_after_undo < baseline_ids.size() - 1:
		_fail("Undo recreated unchanged bodies instead of preserving their node identity")
	if undo_usec > 250000:
		_fail("160-piece Undo exceeded 250 ms on hosted CI")

	started = Time.get_ticks_usec()
	main.call("_redo")
	var redo_usec: int = Time.get_ticks_usec() - started
	var redo_ms: float = float(redo_usec) / 1000.0
	var preserved_after_redo: int = _count_preserved_ids(baseline_ids)
	print("HISTORY_093_REDO_MS=%.2f core=%.2f fast=%s preserved=%d/%d removed=%d created=%d" % [
		redo_ms, float(main.last_history_restore_ms_v093), str(main.history_fast_used_v093),
		preserved_after_redo, baseline_ids.size(), int(main.history_removed_bodies_v093), int(main.history_created_bodies_v093)
	])
	if not bool(main.history_fast_used_v093):
		_fail("large-build placement Redo fell back to full scene reconstruction")
	if main.bodies.size() != baseline_count + 1 or int(main.state_index) != 1:
		_fail("Redo did not restore placed body/history count")
	if preserved_after_redo < baseline_ids.size() - 1:
		_fail("Redo recreated unchanged bodies instead of preserving their node identity")
	if redo_usec > 250000:
		_fail("160-piece Redo exceeded 250 ms on hosted CI")

	main.call("_rebuild_connection_graph_v020")
	var newest := main.bodies.back() as RigidBody3D
	if not is_instance_valid(newest) or str(newest.get_meta("kind", "")) != "rod":
		_fail("Redo did not restore the added rod")
	else:
		var occupied: Dictionary = newest.get_meta("end_occupied", {}) as Dictionary
		if occupied.is_empty():
			_fail("Redo restored the rod but lost its socket connection")

	if failed:
		quit(1)
		return
	print("HISTORY_093_SMOKE_OK: 160-piece Undo/Redo preserves unchanged body nodes and avoids whole-build mesh recreation")
	quit(0)
