extends SceneTree

var app: Node
var failed := false

func _fail(message: String) -> void:
	failed = true
	push_error("UI_POLISH_082_SMOKE_FAIL: %s" % message)

func _initialize() -> void:
	call_deferred("_run")

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

	if app.get_script() == null or not str(app.get_script().resource_path).ends_with("main_v082.gd"):
		_fail("v0.5.23 runtime is not active")

	# Menu X controls must live in a fixed overlay CanvasLayer rather than inside
	# scrollable menu VBox/ScrollContainer content.
	if app.menu_close_layer_v082 == null:
		_fail("fixed menu-close overlay layer is missing")
	if app.menu_close_entries_v082.size() < 5:
		_fail("not all primary menus received fixed close controls")
	for entry_value in app.menu_close_entries_v082:
		var entry: Dictionary = entry_value as Dictionary
		var button := entry.get("button") as Button
		if button == null or button.get_parent() != app.menu_close_layer_v082:
			_fail("menu close control is not fixed to the overlay layer")
			break
		if button.size.x > 40.0 or button.size.y > 40.0:
			_fail("menu close control is still oversized")
			break

	# Transform must not be dismissible.
	app._set_editor_mode_v032(app.EDITOR_ROTATE_032, false)
	await process_frame
	if app.transform_panel_v077 == null or not app.transform_panel_v077.visible:
		_fail("Transform card is not visible in Transform mode")
	if app.transform_close_button_v081 != null:
		_fail("Transform card still has a close button")
	app._close_transform_panel_v081()
	if not app.transform_panel_v077.visible:
		_fail("Transform card can still be hidden")

	# Dedicated Deselect Point must remain retired even after attachment overlay
	# refresh, and the one Deselect button must clear an active point first.
	app._set_editor_mode_v032(app.EDITOR_ATTACH_032, false)
	var points: Array = app._all_attach_points_v032()
	if points.is_empty():
		_fail("no attachment points available for deselect test")
	else:
		app.attach_point_selected_v032 = (points[0] as Dictionary).duplicate(true)
		app._refresh_attach_points_v032()
		if app.deselect_point_button_v032 != null and app.deselect_point_button_v032.visible:
			_fail("legacy Deselect Point button reappeared after ATTACH refresh")
		app._update_ui()
		if app.deselect_piece_button_v039 == null or app.deselect_piece_button_v039.disabled:
			_fail("context Deselect is disabled while an ATTACH point is selected")
		app._deselect_context_v082(false)
		if not app.attach_point_selected_v032.is_empty():
			_fail("context Deselect did not clear the ATTACH point")

		app.attach_point_selected_v032 = (points[0] as Dictionary).duplicate(true)
		app._refresh_attach_points_v032()
		app._handle_tap(Vector2(-500.0, -500.0))
		if not app.attach_point_selected_v032.is_empty():
			_fail("empty-background tap did not clear the ATTACH point")

	# Neutral icon state: inactive Select/Simulate/Delete must all be grey, while
	# Select becomes active only when armed.
	app.select_armed_v020 = false
	app.simulating = false
	app._refresh_top_toolbar_v081()
	if bool(app.select_button_v020.get_meta("v082_active", true)):
		_fail("Select is active while not armed")
	if bool(app.top_simulate_button.get_meta("v082_active", true)):
		_fail("Simulate is active while BUILD is active")
	if bool(app.top_delete_button_v081.get_meta("v082_active", true)):
		_fail("Delete is using the active blue state")
	app.select_armed_v020 = true
	app._refresh_top_toolbar_v081()
	if not bool(app.select_button_v020.get_meta("v082_active", false)):
		_fail("Select did not enter the active highlight state")
	app.select_armed_v020 = false
	app._refresh_top_toolbar_v081()

	if app.camera_joystick_v077 == null:
		_fail("camera joystick is missing")
	elif app.mode_panel_v032 != null and app.mode_panel_v032.visible:
		var required_x: float = app.mode_panel_v032.get_global_rect().end.x + 48.0
		if app.camera_joystick_v077.get_global_rect().position.x < required_x:
			_fail("joystick is still too close to/overlapping the left menu")

	if app.status_label != null and app.status_label.visible:
		_fail("status text is still visible")
	var status_panel := app._nearest_panel_ancestor_v082(app.status_label)
	var toolbar_panel := app._nearest_panel_ancestor_v082(app.select_button_v020)
	if status_panel != null and status_panel != toolbar_panel and status_panel.visible:
		_fail("obsolete status frame is still visible")

	if failed:
		quit(1)
		return
	print("UI_POLISH_082_SMOKE_OK: fixed menu X controls, permanent Transform, ATTACH deselection, neutral toolbar states, status-frame removal and joystick clearance verified")
	quit(0)