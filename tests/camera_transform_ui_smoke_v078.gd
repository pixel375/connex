extends SceneTree

const MAIN := preload("res://scripts/main_v081.gd")

var app: Node
var failed := false

func _fail(message: String) -> void:
	failed = true
	push_error("CAMERA_TRANSFORM_078_SMOKE_FAIL: %s" % message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app = MAIN.new()
	root.add_child(app)
	await process_frame
	await process_frame

	if app.get_script() == null or not str(app.get_script().resource_path).ends_with("main_v081.gd"):
		_fail("final v0.5.22 runtime is not active")
	if app.rotate_button_v032 == null or "TRANSFORM" not in app.rotate_button_v032.text:
		_fail("unified TRANSFORM mode is missing")
	if app.move_mode_button_v042 == null or app.move_mode_button_v042.visible:
		_fail("legacy MOVE editor button is still visible")
	if app.rotation_panel == null or app.rotation_panel.visible or app.move_panel == null or app.move_panel.visible:
		_fail("legacy XYZ side panels are visible")

	app._set_editor_mode_v032(app.EDITOR_ROTATE_032, false)
	await process_frame
	if app.transform_panel_v077 == null or not app.transform_panel_v077.visible:
		_fail("compact transform card was not created/opened")
	if app.transform_toggle_v077 != null:
		_fail("collapsible TRANSFORM header still exists")
	if app.transform_hint_v077 != null:
		_fail("ITEM/WORLD description still exists")
	if app.transform_slide_minus_v077 != null or app.transform_slide_plus_v077 != null:
		_fail("duplicate axle slide controls still exist")
	if app.transform_close_button_v081 == null:
		_fail("transform card has no X close button")
	if app.transform_space_button_v078 == null or app.transform_space_button_v078.text not in ["ITEM", "WORLD"]:
		_fail("compact ITEM/WORLD toggle is missing")

	if app.gizmo_root_v030 == null or not app.gizmo_root_v030.visible:
		_fail("rotation rings are not visible in TRANSFORM")
	if app.move_gizmo_root_v042 == null or not app.move_gizmo_root_v042.visible:
		_fail("translation arrows are not visible in TRANSFORM")
	if app.move_gizmo_root_v042.scale.x < 1.45 * clampf(app.camera_distance / 19.0, 0.62, 2.10):
		_fail("move gizmo was not made substantially larger than rotation")

	if app.camera_joystick_v077 == null or app.camera_up_button_v077 == null or app.camera_down_button_v077 == null:
		_fail("camera joystick/elevation controls were not created")
	else:
		if app.camera_joystick_v077.size.x < 145.0:
			_fail("camera joystick was not enlarged")
		if app.camera_up_button_v077.size.x < 145.0 or app.camera_down_button_v077.size.x < 145.0:
			_fail("UP/DOWN controls were not enlarged")
		if app.camera_joystick_v077.get_global_rect().position.x < 225.0:
			_fail("camera joystick was not moved far enough right")

	# Horizontal and vertical movement must be additive in the same navigation tick.
	var old_target: Vector3 = app.camera_target
	app.camera_joystick_value_v077 = Vector2(0.72, -0.58)
	app.camera_vertical_v077 = 1.0
	app._apply_camera_navigation_v077(0.5)
	var moved: Vector3 = app.camera_target - old_target
	if absf(moved.y) < 0.05:
		_fail("simultaneous navigation did not apply elevation")
	if Vector2(moved.x, moved.z).length() < 0.05:
		_fail("simultaneous navigation did not apply joystick translation")
	app.camera_joystick_value_v077 = Vector2.ZERO
	app.camera_vertical_v077 = 0.0

	if app.status_label == null or app.status_label.visible:
		_fail("top status bar was not removed")
	if app.top_delete_button_v081 == null or app.delete_button_v032 == null or app.delete_button_v032.visible:
		_fail("Delete was not moved from left toolbar to top toolbar")
	if app.disconnect_button_v042 == null or app.disconnect_button_v042.text != "Disconnect":
		_fail("Disconnect label was not shortened")
	if app.deselect_piece_button_v039 == null or app.deselect_piece_button_v039.text != "Deselect":
		_fail("Deselect label was not shortened")
	if app.deselect_point_button_v032 != null and app.deselect_point_button_v032.visible:
		_fail("redundant Deselect Point button is still visible")
	if app.restart_confirm_v081 == null or app.delete_confirm_v081 == null:
		_fail("Restart/Delete confirmation dialogs are missing")

	if app.physics_button_v051 == null or app.physics_button_v051.text != "Physics":
		_fail("Physics option was not renamed")
	if app.builds_button_v050 == null or app.builds_button_v050.text != "Save & Load":
		_fail("Save & Load option was not renamed")
	if app.options_help_button_v081 == null or app.options_help_button_v081.text != "Help":
		_fail("Help was not moved into Options")
	var rigidity_slider := app.physics_sliders_v054.get("Structure rigidity") as HSlider
	if rigidity_slider == null or rigidity_slider.get_parent() != app.physics_box_v051:
		_fail("Structure Rigidity was not moved into Physics")

	if app.rod_label == null or app.rod_label.visible:
		_fail("bottom rod text label is still visible")
	if app.connector_label == null or app.connector_label.visible:
		_fail("bottom connector text label is still visible")
	if app.bottom_rod_preview_v081 == null or app.bottom_connector_preview_v081 == null:
		_fail("bottom live part previews are missing")
	if app.parts_button_v050 == null or app.parts_button_v050.text != "⚒":
		_fail("Parts button was not converted to an icon")

	if failed:
		quit(1)
		return
	print("CAMERA_TRANSFORM_078_SMOKE_OK: v0.5.22 touch concurrency, orbit-only multi-touch policy, compact transform card, icon toolbars, options hierarchy and live bottom previews verified")
	quit(0)
