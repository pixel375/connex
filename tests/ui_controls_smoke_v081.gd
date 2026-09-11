extends SceneTree

const MAIN := preload("res://scripts/main_v081.gd")

var app: Node
var failed := false

func _fail(message: String) -> void:
	failed = true
	push_error("UI_CONTROLS_081_SMOKE_FAIL: %s" % message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app = MAIN.new()
	root.add_child(app)
	await process_frame
	await process_frame

	if app.get_script() == null or not str(app.get_script().resource_path).ends_with("main_v081.gd"):
		_fail("v0.5.22 runtime is not active")
	if app.status_label == null or app.status_label.visible:
		_fail("legacy top status bar is still visible")
	for value in [app.top_select_v081, app.top_center_v081, app.top_undo_v081, app.top_redo_v081, app.top_simulate_v081, app.top_restore_v081, app.top_restart_v081, app.top_delete_v081, app.top_options_v081]:
		if value == null:
			_fail("one or more top icon buttons are missing")
			break
	if app.restart_confirm_v081 == null or app.delete_confirm_v081 == null:
		_fail("Restart/Delete confirmations were not created")
	if app.disconnect_button_v042 == null or app.disconnect_button_v042.text != "Disconnect":
		_fail("Disconnect label was not shortened")
	if app.deselect_piece_button_v039 == null or app.deselect_piece_button_v039.text != "Deselect":
		_fail("Deselect label was not shortened")
	if app.delete_button_v032 != null and app.delete_button_v032.visible:
		_fail("Delete still appears in the left editor menu")

	app._set_editor_mode_v032(app.EDITOR_ROTATE_032, false)
	await process_frame
	if app.transform_panel_v077 == null or not app.transform_panel_v077.visible:
		_fail("compact Transform panel is not visible in Transform mode")
	if app.transform_toggle_v077 != null:
		_fail("Transform accordion header still exists")
	if app.transform_space_button_v078 == null or app.transform_space_button_v078.text not in ["ITEM", "WORLD"]:
		_fail("compact ITEM/WORLD button is missing")
	if app.transform_slide_minus_v077 != null or app.transform_slide_plus_v077 != null:
		_fail("obsolete axle Slide controls still exist")
	if app.move_gizmo_root_v042 == null or not app.move_gizmo_root_v042.visible:
		_fail("translation gizmo is not visible in Transform")
	else:
		var x_data := app.move_gizmo_axes_v042.get("X", {}) as Dictionary
		var x_root := x_data.get("root") as Node3D
		var shaft: MeshInstance3D = null
		if x_root != null:
			for child in x_root.get_children():
				if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh:
					var cylinder := (child as MeshInstance3D).mesh as CylinderMesh
					if absf(cylinder.top_radius - cylinder.bottom_radius) < 0.001:
						shaft = child as MeshInstance3D
						break
		if shaft == null or (shaft.mesh as CylinderMesh).height < 8.0:
			_fail("move gizmos were not lengthened away from rotation rings")

	if app.camera_joystick_v077 == null or app.camera_up_button_v077 == null or app.camera_down_button_v077 == null:
		_fail("camera controls are missing")
	else:
		if app.camera_joystick_v077.size.x < 145.0:
			_fail("joystick was not enlarged")
		if app.camera_up_button_v077.size.x < 140.0 or app.camera_down_button_v077.size.x < 140.0:
			_fail("UP/DOWN controls were not enlarged")
		if app.mode_panel_v032 != null and app.camera_joystick_v077.get_global_rect().position.x <= app.mode_panel_v032.get_global_rect().end.x + 10.0:
			_fail("joystick still crowds the left editor menu")

	# Independent touch ids must be able to drive horizontal movement and elevation
	# in the same frame.
	var joy_rect: Rect2 = app.camera_joystick_v077.get_global_rect()
	var joy_press := InputEventScreenTouch.new()
	joy_press.index = 2
	joy_press.position = joy_rect.position + Vector2(joy_rect.size.x * 0.78, joy_rect.size.y * 0.25)
	joy_press.pressed = true
	app._input(joy_press)
	var up_rect: Rect2 = app.camera_up_button_v077.get_global_rect()
	var up_press := InputEventScreenTouch.new()
	up_press.index = 7
	up_press.position = up_rect.get_center()
	up_press.pressed = true
	app._input(up_press)
	if app.camera_joystick_value_v077.length() < 0.1 or app.camera_vertical_v077 < 0.9:
		_fail("joystick and UP cannot be active simultaneously")
	var before_nav: Vector3 = app.camera_target
	app._apply_camera_navigation_v077(0.25)
	var delta: Vector3 = app.camera_target - before_nav
	if absf(delta.y) < 0.05 or Vector2(delta.x, delta.z).length() < 0.05:
		_fail("simultaneous navigation did not move horizontally and vertically")
	var up_release := InputEventScreenTouch.new()
	up_release.index = 7
	up_release.position = up_rect.get_center()
	up_release.pressed = false
	app._input(up_release)
	var joy_release := InputEventScreenTouch.new()
	joy_release.index = 2
	joy_release.position = joy_press.position
	joy_release.pressed = false
	app._input(joy_release)

	# Multi-touch viewport drag must not zoom or pan.
	app.touches.clear()
	app.touch_start.clear()
	app.touch_moved.clear()
	app.touches[10] = Vector2(420, 300)
	app.touches[11] = Vector2(620, 300)
	var distance_before: float = app.camera_distance
	var target_before: Vector3 = app.camera_target
	var two_drag := InputEventScreenDrag.new()
	two_drag.index = 10
	two_drag.position = Vector2(450, 330)
	two_drag.relative = Vector2(30, 30)
	app._unhandled_input(two_drag)
	if absf(app.camera_distance - distance_before) > 0.001:
		_fail("two-finger touch still changes zoom")
	if app.camera_target.distance_to(target_before) > 0.001:
		_fail("two-finger touch still pans the camera")
	app.touches.clear()
	app.touch_start.clear()
	app.touch_moved.clear()
	app.camera_multitouch_v081.clear()

	if app.bottom_rod_preview_v081 == null or app.bottom_connector_preview_v081 == null:
		_fail("bottom live rod/connector previews are missing")
	if app.parts_button_v050 == null or app.parts_button_v050.text == "PARTS":
		_fail("Parts control was not converted to an icon")

	var physics_children := app.physics_box_v051.get_children() if app.physics_box_v051 != null else []
	var rigidity_index := -1
	var gravity_index := -1
	for i in range(physics_children.size()):
		var child := physics_children[i] as Node
		if child is Label:
			var text := (child as Label).text
			if text.begins_with("Structure rigidity"):
				rigidity_index = i
			elif text.begins_with("Gravity"):
				gravity_index = i
	if rigidity_index < 0 or gravity_index < 0 or rigidity_index >= gravity_index:
		_fail("Structure Rigidity is not at the top of Physics")

	if failed:
		quit(1)
		return
	print("UI_CONTROLS_081_SMOKE_OK: simultaneous joystick/elevation, touch-orbit-only navigation, compact menus, long move gizmos, confirmations and live bottom previews verified")
	app.queue_free()
	await process_frame
	quit(0)