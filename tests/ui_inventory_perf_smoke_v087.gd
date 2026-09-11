extends SceneTree

var app: Node
var failed := false

func _fail(message: String) -> void:
	failed = true
	push_error("UI_PERF_087_SMOKE_FAIL: %s" % message)

func _initialize() -> void:
	call_deferred("_run")

func _sum_counts(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total

func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		quit(1)
		return
	app = packed.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	if app.get_script() == null or not str(app.get_script().resource_path).ends_with("main_v087.gd"):
		_fail("v0.5.24 runtime is not active")

	if app.save_confirmation_v086 == null:
		_fail("save confirmation dialog is missing")
	else:
		if app.save_confirmation_v086.dialog_text != "Build has been saved.":
			_fail("save confirmation text is incorrect")
		var close_button := app.save_confirmation_v086.get_ok_button() as Button
		if close_button == null or close_button.text != "Close":
			_fail("save confirmation Close button is missing")

	var baseline: Dictionary = app._parts_usage_counts_v086()
	var baseline_total: int = int(baseline.get("total", -1))
	var baseline_rods: Array = baseline.get("rods", []) as Array
	var baseline_connectors: Array = baseline.get("connectors", []) as Array
	if baseline_total < 1:
		_fail("initial build inventory is empty")
	if _sum_counts(baseline_rods) + _sum_counts(baseline_connectors) != baseline_total:
		_fail("inventory per-type counts do not add up to total")

	app._refresh_parts_browser_v050()
	if app.part_card_buttons_v050.is_empty():
		_fail("Parts browser created no cards")
	else:
		var first_card := app.part_card_buttons_v050[0] as Button
		if first_card == null or "Used:" not in first_card.text:
			_fail("Parts cards do not display live Used counts")

	# A far-away free rod gives us an isolated committed edit. Inventory must rise,
	# and Undo must restore both construction count and selection state.
	var rod := app._make_rod(0, Vector3(22.0, 4.0, 22.0), Vector3(23.75, 4.0, 22.0)) as RigidBody3D
	if not is_instance_valid(rod):
		_fail("could not create isolated rod for inventory/Undo test")
	else:
		app._set_selected(rod)
		app._commit_state()
		await process_frame
		var after_add: Dictionary = app._parts_usage_counts_v086()
		if int(after_add.get("total", -1)) != baseline_total + 1:
			_fail("inventory did not increment after adding a rod")
		var rods_after: Array = after_add.get("rods", []) as Array
		if rods_after.is_empty() or int(rods_after[0]) != int(baseline_rods[0]) + 1:
			_fail("correct rod type count did not increment")

		app._undo()
		await process_frame
		await process_frame
		if is_instance_valid(app.selected_piece):
			_fail("Undo left a piece selected")
		if not app.attach_point_selected_v032.is_empty():
			_fail("Undo left an ATTACH point selected")
		var after_undo: Dictionary = app._parts_usage_counts_v086()
		if int(after_undo.get("total", -1)) != baseline_total:
			_fail("inventory did not return to baseline after Undo")

	# Hidden legacy transform controls must not remain on the expensive validity
	# preview path. The modern gizmo validates only when actually dragged.
	if app.roll_minus_v035 != null or app.roll_plus_v035 != null or app.reset_rotation_v035 != null:
		_fail("retired legacy rotation controls are still attached to the hot UI path")

	# ATTACH pose polling is intentionally throttled; explicit edits still dirty the
	# overlay immediately, but a second passive check inside the throttle window is skipped.
	app.next_attach_pose_check_ms_v086 = Time.get_ticks_msec() + 10000
	if app._sync_attach_overlay_pose_v076(false):
		_fail("ATTACH pose polling ignored the v0.5.24 throttle")

	app._snapshot_autofuse_bodies_v086()
	var change_info: Dictionary = app._changed_autofuse_bodies_v086()
	if not (change_info.get("changed", []) as Array).is_empty() or bool(change_info.get("removed", false)):
		_fail("local auto-connect cache is dirty immediately after snapshot")

	if failed:
		quit(1)
		return
	print("UI_PERF_087_SMOKE_OK: save confirmation, live Parts inventory, Undo deselection and optimized build-mode paths verified")
	quit(0)
