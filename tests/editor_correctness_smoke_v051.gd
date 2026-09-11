extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_051_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index(defs: Array, wanted: String) -> int:
	for i in range(defs.size()):
		if str((defs[i] as Dictionary).get("name", "")) == wanted:
			return i
	return -1


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var runtime_path: String = str(main.get_script().resource_path)
	if not (runtime_path.ends_with("main_v053.gd") or runtime_path.ends_with("main_v054.gd") or runtime_path.ends_with("main_v055.gd") or runtime_path.ends_with("main_v056.gd")):
		_fail("Main is not using a validated v0.5.1+ runtime")
		return

	# Historical runtimes expose separate MOVE (3) and ROTATE (1) modes. v0.5.21
	# intentionally maps legacy MOVE requests into unified TRANSFORM (mode 1).
	var modern_transform: bool = main.get("transform_panel_v077") != null
	main.call("_set_editor_mode_v032", 3, false)
	var move_button: Button = main.get("move_mode_button_v042") as Button
	var rotate_button: Button = main.get("rotate_button_v032") as Button
	var attach_button: Button = main.get("attach_button_v032") as Button
	if modern_transform:
		if int(main.get("editor_mode_v032")) != 1 or rotate_button == null or not rotate_button.text.begins_with("● ") or (move_button != null and move_button.visible) or (attach_button != null and attach_button.text.begins_with("● ")):
			_fail("unified TRANSFORM active-state mapping is wrong")
			return
	else:
		if move_button == null or not move_button.text.begins_with("● ") or (attach_button != null and attach_button.text.begins_with("● ")):
			_fail("MOVE active-state mapping is wrong")
			return
	main.call("_set_editor_mode_v032", 2, false)
	if attach_button == null or not attach_button.text.begins_with("● "):
		_fail("ATTACH active-state mapping is wrong")
		return
	if modern_transform:
		if rotate_button != null and rotate_button.text.begins_with("● "):
			_fail("TRANSFORM remained active in ATTACH mode")
			return
	elif move_button.text.begins_with("● "):
		_fail("MOVE remained active in ATTACH mode")
		return

	# ITEM must be the default transform space. v0.5.21 condenses the two legacy
	# right-side switchers into one compact ITEM/WORLD control.
	if int(main.get("transform_space_v051")) != 0:
		_fail("ITEM is not the default transform space")
		return
	if modern_transform:
		var compact_space: Button = main.get("transform_space_button_v078") as Button
		if compact_space == null or "ITEM" not in compact_space.text:
			_fail("compact ITEM/WORLD transform-space control is missing or unsynchronized")
			return
	else:
		var rotate_space: Button = main.get("rotate_space_button_v051") as Button
		var move_space: Button = main.get("move_space_button_v051") as Button
		if rotate_space == null or move_space == null or "ITEM" not in rotate_space.text or "ITEM" not in move_space.text:
			_fail("transform-space controls are missing or unsynchronized")
			return

	# Physics and saves must be directly reachable near the top of Options.
	if main.get("builds_button_v050") == null or main.get("physics_button_v051") == null or main.get("physics_panel_v051") == null:
		_fail("Saves / Physics surfaces are not reachable")
		return

	# Parts browser must include a live procedural preview viewport.
	if main.get("parts_preview_viewport_v052") == null or main.get("parts_preview_root_v052") == null:
		_fail("rendered Parts preview is missing")
		return

	# Older camera navigation used two-finger screen-Y to change elevation. v0.5.21
	# deliberately makes two-finger pan horizontal because UP/DOWN now owns camera
	# elevation, so a later pan must preserve the chosen height.
	var before_target: Vector3 = main.get("camera_target") as Vector3
	main.call("_pan_camera", Vector2(0.0, 120.0))
	var after_target: Vector3 = main.get("camera_target") as Vector3
	if modern_transform:
		if absf(after_target.y - before_target.y) > 0.001:
			_fail("horizontal two-finger pan changed dedicated camera elevation")
			return
	else:
		if absf(after_target.y - before_target.y) < 0.01:
			_fail("two-finger vertical camera pan still cannot change target Y")
			return

	# 11/14-point definitions must expose all reserved out-of-plane socket IDs and
	# those sockets must appear in the same attachment-point source used by ATTACH.
	var defs: Array = main.get("connector_defs") as Array
	for pair_value in [["11-point 3D", 3], ["14-point 3D", 6]]:
		var pair: Array = pair_value as Array
		var index: int = _connector_index(defs, str(pair[0]))
		if index < 0:
			_fail("missing %s definition" % str(pair[0]))
			return
		var connector: RigidBody3D = main.call("_make_connector", index, Transform3D(Basis.IDENTITY, Vector3(14.0 + float(index), 5.0, 0.0))) as RigidBody3D
		if connector == null:
			_fail("could not instantiate %s" % str(pair[0]))
			return
		var spatial_count: int = 0
		for point_value in main.call("_all_attach_points_v032") as Array:
			var point: Dictionary = point_value as Dictionary
			if point.get("body") == connector and str(point.get("type", "")) == "socket" and bool(main.call("_is_spatial_slot_v041", int(point.get("slot", -1)))):
				spatial_count += 1
		if spatial_count != int(pair[1]):
			_fail("%s exposes %d spatial ATTACH sockets; expected %d" % [str(pair[0]), spatial_count, int(pair[1])])
			return

	print("EDITOR_051_SMOKE_OK: transform/attach mapping + ITEM space + accessible saves/physics + rendered parts + camera pan contract + spatial ports")
	main.queue_free()
	await process_frame
	quit(0)