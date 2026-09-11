extends SceneTree

const MAIN := preload("res://scripts/main_v079.gd")

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

	if app.get_script() == null or not str(app.get_script().resource_path).ends_with("main_v079.gd"):
		_fail("final v0.5.21 runtime is not active")
	if app.rotate_button_v032 == null or "TRANSFORM" not in app.rotate_button_v032.text:
		_fail("ROTATE button was not replaced by TRANSFORM")
	if app.move_mode_button_v042 == null or app.move_mode_button_v042.visible:
		_fail("legacy MOVE editor button is still visible")
	if app.rotation_panel == null or app.rotation_panel.visible:
		_fail("legacy rotation XYZ panel is still visible")
	if app.move_panel == null or app.move_panel.visible:
		_fail("legacy move XYZ panel is still visible")
	if app.transform_panel_v077 == null or app.transform_toggle_v077 == null or app.transform_space_button_v078 == null:
		_fail("compact transform panel/space control was not created")

	app._set_editor_mode_v032(app.EDITOR_MOVE_042, false)
	if app.editor_mode_v032 != app.EDITOR_ROTATE_032:
		_fail("legacy MOVE request did not remap to unified TRANSFORM")
	await process_frame
	if app.gizmo_root_v030 == null or not app.gizmo_root_v030.visible:
		_fail("rotation rings are not visible in TRANSFORM")
	if app.move_gizmo_root_v042 == null or not app.move_gizmo_root_v042.visible:
		_fail("translation arrows are not visible in TRANSFORM")
	if app.rotation_panel.visible or app.move_panel.visible:
		_fail("inherited refresh re-opened a retired XYZ side panel")

	app.transform_space_v051 = app.SPACE_WORLD_051
	app._update_transform_ui_v077()
	if "WORLD" not in app.transform_space_button_v078.text:
		_fail("ITEM/WORLD transform-space control did not update")
	app.transform_space_v051 = app.SPACE_ITEM_051

	if app.camera_joystick_v077 == null or app.camera_up_button_v077 == null or app.camera_down_button_v077 == null:
		_fail("camera joystick/elevation controls were not created")
	else:
		if app.camera_joystick_knob_v077.get_parent() == app.camera_joystick_v077:
			_fail("joystick knob is still a direct PanelContainer child and cannot move freely")
		var joy_rect: Rect2 = app.camera_joystick_v077.get_global_rect()
		if joy_rect.position.x < 202.0:
			_fail("camera joystick overlaps the condensed editor sidebar")
		var viewport_size: Vector2 = app.get_viewport().get_visible_rect().size
		if joy_rect.end.y > viewport_size.y - 88.0:
			_fail("camera joystick overlaps the bottom parts bar")

	var old_target: Vector3 = app.camera_target
	app.camera_joystick_value_v077 = Vector2(0.75, -0.55)
	app._apply_camera_navigation_v077(0.5)
	if app.camera_target.distance_to(old_target) < 0.05:
		_fail("analog joystick did not translate camera target")
	var elevated: Vector3 = app.camera_target
	app.camera_joystick_value_v077 = Vector2.ZERO
	app.camera_vertical_v077 = 1.0
	app._apply_camera_navigation_v077(0.5)
	if app.camera_target.y <= elevated.y:
		_fail("UP control did not raise camera target")

	var keep_y: float = app.camera_target.y
	app._pan_camera(Vector2(20.0, 12.0))
	if absf(app.camera_target.y - keep_y) > 0.001:
		_fail("two-finger pan erased camera elevation")

	if is_instance_valid(app.selected_piece):
		var focus: Vector3 = app.selected_piece.global_position
		app.camera_target += Vector3(5, 3, -4)
		app._center_view()
		if app.camera_target.distance_to(focus) > 0.001:
			_fail("Center did not focus selected piece")

	app._refresh_parts_browser_v050()
	await process_frame
	var scroll := _find_scroll(app.parts_panel_v050)
	if scroll == null:
		_fail("parts browser scroll container not found")
	else:
		if scroll.scroll_deadzone < app.MENU_SCROLL_DEADZONE_077:
			_fail("menu scroll deadzone was not applied")
		var scroll_button := _find_button(scroll)
		if scroll_button == null:
			_fail("parts browser has no scrollable card button")
		elif scroll_button.mouse_filter != Control.MOUSE_FILTER_PASS:
			_fail("scrollable card still blocks parent drag gestures")

	if failed:
		quit(1)
		return
	print("CAMERA_TRANSFORM_078_SMOKE_OK: unified transform, ITEM/WORLD compact controls, analog camera navigation, Center focus and scroll-safe menus verified")
	quit(0)

func _find_scroll(node: Node) -> ScrollContainer:
	if node == null:
		return null
	if node is ScrollContainer:
		return node as ScrollContainer
	for child in node.get_children():
		var found := _find_scroll(child as Node)
		if found != null:
			return found
	return null

func _find_button(node: Node) -> BaseButton:
	if node == null:
		return null
	if node is BaseButton:
		return node as BaseButton
	for child in node.get_children():
		var found := _find_button(child as Node)
		if found != null:
			return found
	return null
