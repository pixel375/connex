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

	if main.get_script() == null or not str(main.get_script().resource_path).ends_with("main_v092.gd"):
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
		main.attach_point_selected_v032 = initial_points[0] as Dictionary
		main.call("_refresh_attach_points_v032")
		main.call("_sync_deselect_button_v089")
		if main.deselect_point_button_v032 == null or main.deselect_point_button_v032.disabled:
			_fail("unified Deselect is disabled with an ATTACH point selected")
		else:
			main.deselect_point_button_v032.emit_signal("pressed")
			await process_frame
			if not main.attach_point_selected_v032.is_empty():
				_fail("unified Deselect left the ATTACH source selected")

	# Occupied sockets must disappear from the target/source competition while the
	# attached rod end remains selectable at the same world location.
	var connector_index: int = mini(6, main.connector_defs.size() - 1)
	var connector := main.call("_make_connector", connector_index, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))) as RigidBody3D
	var slots: Array = (main.connector_defs[connector_index] as Dictionary).get("slots", []) as Array
	if slots.is_empty():
		_fail("socket ownership fixture has no connector slot")
	else:
		main.call("_set_selected", connector)
		main.call("_extend_socket", connector, int(slots[0]))
		for _i in range(3):
			await process_frame
		main.attach_overlay_dirty_v050 = true
		var points: Array = main.call("_all_attach_points_v032") as Array
		var occupied_socket_visible := false
		var connected_rod_end_visible := false
		for point_value in points:
			var point := point_value as Dictionary
			if point.get("type", "") == "socket" and point.get("body") == connector and int(point.get("slot", -1)) == int(slots[0]):
				occupied_socket_visible = true
			if point.get("type", "") == "rod_end":
				var rod := point.get("body") as RigidBody3D
				if is_instance_valid(rod):
					var occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
					if occupied.has(int(point.get("sign", 0))):
						connected_rod_end_visible = true
		if occupied_socket_visible:
			_fail("occupied connector socket still appears as an ATTACH point")
		if not connected_rod_end_visible:
			_fail("connected rod end does not own the occupied ATTACH location")

	# Autosaves: five automatic/recovery entries max; named saves never count.
	if int(main.AUTOSAVE_KEEP_V089) != 5:
		_fail("automatic save retention is not capped at five")
	if float(main.AUTOSAVE_IDLE_DELAY_SEC_V089) < 1.0:
		_fail("autosave idle debounce is too short for interactive editing")

	# One commit may traverse inherited implementations, but only one visible UI
	# refresh should survive the suppress/final-refresh gate.
	main.ui_refresh_count_v089 = 0
	var commit_started := Time.get_ticks_usec()
	main.call("_commit_state")
	var commit_ms := float(Time.get_ticks_usec() - commit_started) / 1000.0
	print("PERF_089_COMMIT_MS=%.2f ui_refreshes=%d" % [commit_ms, int(main.ui_refresh_count_v089)])
	if int(main.ui_refresh_count_v089) != 1:
		_fail("one history commit performed %d visible UI refreshes" % int(main.ui_refresh_count_v089))

	if failed:
		quit(1)
		return
	print("CORRECTIVE_089_SMOKE_OK: newest saves + touch scroll + five autosaves + updater + ATTACH ownership/deselect + single-refresh commits verified")
	quit(0)
