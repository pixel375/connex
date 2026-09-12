extends SceneTree

var main: Node
var failed: bool = false


func _fail(message: String) -> void:
	failed = true
	push_error("CORRECTIVE_089_SMOKE_FAIL: %s" % message)


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
	for _i in range(5):
		await process_frame

	if main.get_script() == null or not str(main.get_script().resource_path).ends_with("main_v094.gd"):
		_fail("v0.5.26 corrective behavior is not running through the current descendant runtime")

	# Updater must compare against the current descendant version, not old v0.5.0.
	main.update_available_version_v021 = "0.5.26"
	main.update_available_url_v021 = "https://example.invalid/Connex.apk"
	main.update_available_filename_v021 = "Connex.apk"
	main.call("_reconcile_update_version_v089", "v0.5.26")
	if not main.update_available_version_v021.is_empty() or not main.update_available_url_v021.is_empty():
		_fail("current release still remains installable as an update")
	if main.update_button_v021 != null and str(main.update_button_v021.text).begins_with("Update"):
		_fail("updater button still advertises the currently installed version")

	# Unified Deselect must really clear an ATTACH source despite marker caching.
	main.call("_set_editor_mode_v032", 2, false)
	main.attach_overlay_dirty_v050 = true
	var initial_points: Array = main.call("_all_attach_points_v032") as Array
	if initial_points.is_empty():
		_fail("no ATTACH points were available for deselect test")
	else:
		main.attach_point_selected_v032 = (initial_points[0] as Dictionary).duplicate(true)
		main.attach_overlay_dirty_v050 = true
		main.call("_refresh_attach_points_v032")
		main.call("_deselect_context_v082", false)
		if not main.attach_point_selected_v032.is_empty():
			_fail("Deselect did not clear the ATTACH point")
		if main.deselect_piece_button_v039 != null and not main.deselect_piece_button_v039.disabled and not is_instance_valid(main.selected_piece):
			_fail("Deselect button state did not resync after clearing the point")

	# Build one normal SOCKET connection. The occupied connector socket marker must
	# disappear while the connected rod-end marker remains at that ownership point.
	main.call("_set_editor_mode_v032", 0, false)
	var connector := main.bodies[0] as RigidBody3D if not main.bodies.is_empty() else null
	if not is_instance_valid(connector):
		_fail("could not find seed connector")
	else:
		var def_index: int = int(connector.get_meta("connector_type", -1))
		var slots: Array = (main.connector_defs[def_index] as Dictionary).get("slots", []) as Array
		if slots.is_empty():
			_fail("seed connector has no sockets")
		else:
			main.call("_extend_socket", connector, int(slots[0]))
			await process_frame
			var record: Dictionary = {}
			for record_value in main.connections_v020:
				var candidate := record_value as Dictionary
				if str(candidate.get("kind", "")) == "socket" and candidate.get("connector") == connector:
					record = candidate
					break
			if record.is_empty():
				_fail("could not create socket connection for marker ownership test")
			else:
				var rod := record.get("rod") as RigidBody3D
				var slot: int = int(record.get("slot", -1))
				var rod_end: int = int(record.get("rod_end", 0))
				var found_socket: bool = false
				var found_rod_end: bool = false
				for point_value in main.call("_all_attach_points_v032") as Array:
					var point := point_value as Dictionary
					if point.get("body") == connector and str(point.get("type", "")) == "socket" and int(point.get("slot", -2)) == slot:
						found_socket = true
					if point.get("body") == rod and str(point.get("type", "")) == "rod_end" and int(point.get("sign", 0)) == rod_end:
						found_rod_end = true
				if found_socket:
					_fail("occupied connector socket still exposes an ATTACH marker")
				if not found_rod_end:
					_fail("connected rod end did not take ownership of occupied socket location")

	# One commit should produce one visible UI refresh, not the inherited stack of
	# repeated full refreshes that previously multiplied Android edit latency.
	var ui_before: int = main.ui_refresh_count_v089
	var commit_started: int = Time.get_ticks_usec()
	main.call("_commit_state")
	var commit_usec: int = Time.get_ticks_usec() - commit_started
	var ui_delta: int = main.ui_refresh_count_v089 - ui_before
	print("PERF_089_COMMIT_MS=%.2f ui_refreshes=%d" % [float(commit_usec) / 1000.0, ui_delta])
	if ui_delta != 1:
		_fail("one commit performed %d visible UI refreshes instead of one" % ui_delta)
	if commit_usec > 650000:
		_fail("small-build commit exceeded 650 ms in headless CI")

	# Create deterministic save fixtures and verify newest-first ordering.
	main.call("_ensure_builds_dir_v050")
	for fixture in [
		{"file": "V089_Old.connex", "name": "V089 Old", "saved": 100.0},
		{"file": "V089_Mid.connex", "name": "V089 Mid", "saved": 200.0},
		{"file": "V089_New.connex", "name": "V089 New", "saved": 300.0},
	]:
		var path: String = "%s/%s" % [main.BUILDS_DIR_V050, str(fixture["file"])]
		var bundle: Dictionary = main.call("_save_bundle_v050", str(fixture["name"])) as Dictionary
		bundle["saved_unix"] = float(fixture["saved"])
		main.call("_write_variant_file_v050", path, bundle)
	main.call("_refresh_build_list_v050")
	var old_i: int = main.build_paths_v050.find("%s/V089_Old.connex" % main.BUILDS_DIR_V050)
	var mid_i: int = main.build_paths_v050.find("%s/V089_Mid.connex" % main.BUILDS_DIR_V050)
	var new_i: int = main.build_paths_v050.find("%s/V089_New.connex" % main.BUILDS_DIR_V050)
	if old_i < 0 or mid_i < 0 or new_i < 0 or not (new_i < mid_i and mid_i < old_i):
		_fail("save list is not sorted newest first")

	# Seven automatic snapshots must be pruned to exactly the five newest files.
	var builds_dir := DirAccess.open(main.BUILDS_DIR_V050)
	if builds_dir == null:
		_fail("could not open saves directory for autosave cap test")
	else:
		for i in range(7):
			var auto_bundle: Dictionary = main.call("_save_bundle_v050", "Autosave Test %d" % i) as Dictionary
			auto_bundle["saved_unix"] = 1000 + i
			main.call("_write_variant_file_v050", "%s/Autosave_%d.connex" % [main.BUILDS_DIR_V050, 2000000000000 + i], auto_bundle)
		main.call("_prune_auto_saves_worker_v089")
		builds_dir = DirAccess.open(main.BUILDS_DIR_V050)
		var auto_count: int = 0
		for file_name_value in builds_dir.get_files():
			if main.call("_automatic_save_filename_v089", str(file_name_value)):
				auto_count += 1
		if auto_count != 5:
			_fail("automatic save cap is %d instead of 5" % auto_count)

	# Touch-drag handler must actually move the ItemList's internal scrollbar.
	if main.builds_list_v050 == null:
		_fail("saves ItemList is missing")
	else:
		main.builds_list_v050.clear()
		for i in range(80):
			main.builds_list_v050.add_item("Scroll row %02d" % i)
		await process_frame
		await process_frame
		var bar: VScrollBar = main.builds_list_v050.get_v_scroll_bar()
		if bar == null or bar.max_value <= bar.page:
			_fail("save list did not create a usable scroll range")
		else:
			bar.value = 0.0
			var touch := InputEventScreenTouch.new()
			touch.index = 9
			touch.pressed = true
			main.call("_on_build_list_gui_input_v089", touch)
			var drag := InputEventScreenDrag.new()
			drag.index = 9
			drag.relative = Vector2(0.0, -120.0)
			main.call("_on_build_list_gui_input_v089", drag)
			if bar.value <= 0.0:
				_fail("touch drag did not move saves scrollbar")

	# The Android-specific lag path is intentionally idle/deferred: synchronous
	# disk serialization must not be scheduled 350 ms after every commit anymore.
	if main.AUTOSAVE_IDLE_MS_089 < 2000:
		_fail("autosave debounce is still too close to interactive edits")

	if failed:
		quit(1)
		return
	print("CORRECTIVE_089_SMOKE_OK: newest saves + touch scroll + five autosaves + updater + ATTACH ownership/deselect + single-refresh commits verified")
	quit(0)
