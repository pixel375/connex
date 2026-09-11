extends "res://scripts/main_v076.gd"

const VERSION_077 := "0.5.21"
const CAMERA_JOYSTICK_SIZE_077 := 132.0
const CAMERA_JOYSTICK_KNOB_077 := 46.0
const CAMERA_JOYSTICK_DEADZONE_077 := 0.08
const CAMERA_MOVE_MIN_SPEED_077 := 3.5
const CAMERA_MOVE_DISTANCE_SCALE_077 := 0.48
const CAMERA_VERTICAL_SPEED_SCALE_077 := 0.82
const MENU_SCROLL_DEADZONE_077 := 14
const CENTER_LONG_PRESS_MS_077 := 650

var camera_layer_v077: CanvasLayer
var camera_joystick_v077: PanelContainer
var camera_joystick_knob_v077: PanelContainer
var camera_up_button_v077: Button
var camera_down_button_v077: Button
var camera_joystick_value_v077: Vector2 = Vector2.ZERO
var camera_joystick_touch_v077: int = -999
var camera_joystick_mouse_v077: bool = false
var camera_vertical_v077: float = 0.0
var camera_controls_visible_v077: bool = true

var transform_panel_v077: PanelContainer
var transform_body_v077: VBoxContainer
var transform_toggle_v077: Button
var transform_roll_minus_v077: Button
var transform_roll_plus_v077: Button
var transform_reset_v077: Button
var transform_slide_minus_v077: Button
var transform_slide_plus_v077: Button
var transform_hint_v077: Label
var transform_panel_open_v077: bool = false

var center_press_started_v077: int = 0
var center_long_suppress_v077: bool = false


func _ready() -> void:
	super._ready()
	_configure_scroll_touch_v077(self, false)
	_layout_camera_controls_v077()
	_update_transform_ui_v077()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_077)
	_status("v0.5.21 ready — analog camera navigation, unified TRANSFORM mode and safer touch scrolling are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_077, text]


# -----------------------------------------------------------------------------
# UI layout: CREATE / TRANSFORM / ATTACH on the left. World translation arrows
# and rotation rings coexist in TRANSFORM, so the old separate MOVE mode and the
# duplicated XYZ step-button panels are retired. The only right-side controls
# left are mount-relative Roll / Reset and axle Slide helpers.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()

	if move_mode_button_v042 != null:
		move_mode_button_v042.visible = false
		move_mode_button_v042.mouse_filter = Control.MOUSE_FILTER_IGNORE
		move_mode_button_v042.custom_minimum_size = Vector2.ZERO
	if rotate_button_v032 != null:
		rotate_button_v032.text = "TRANSFORM"

	for button_value in [create_button_v032, rotate_button_v032, attach_button_v032]:
		var button := button_value as Button
		if button != null:
			button.custom_minimum_size = Vector2(174.0, 48.0)
			button.add_theme_font_size_override("font_size", 16)
	for compact_value in [disconnect_button_v042, delete_button_v032, deselect_piece_button_v039, deselect_point_button_v032]:
		var compact := compact_value as Button
		if compact != null:
			compact.custom_minimum_size.y = 40.0
			compact.add_theme_font_size_override("font_size", 14)

	if mode_panel_v032 != null:
		mode_panel_v032.offset_right = 202.0
		mode_panel_v032.offset_bottom = 440.0

	# The legacy right accordions contained duplicate X/Y/Z buttons. Keep their
	# nodes alive for compatibility with old code/tests, but remove them from the
	# interactive layout completely.
	right_panel_state_v037 = ""
	if rotation_panel != null:
		rotation_panel.visible = false
		rotation_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if move_panel != null:
		move_panel.visible = false
		move_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_transform_panel_v077()
	_build_camera_controls_v077()

	if top_center_button != null:
		top_center_button.tooltip_text = "Center selected piece (or whole build). Hold for a full camera reset."
		top_center_button.button_down.connect(_center_button_down_v077)
		top_center_button.button_up.connect(_center_button_up_v077)


func _build_transform_panel_v077() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)

	transform_panel_v077 = PanelContainer.new()
	transform_panel_v077.anchor_left = 1.0
	transform_panel_v077.anchor_right = 1.0
	transform_panel_v077.offset_left = -214.0
	transform_panel_v077.offset_right = -8.0
	transform_panel_v077.offset_top = 76.0
	transform_panel_v077.offset_bottom = 124.0
	transform_panel_v077.add_theme_stylebox_override("panel", _panel_style(0.94, 11))
	layer.add_child(transform_panel_v077)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	transform_panel_v077.add_child(outer)
	transform_toggle_v077 = _ui_button("TRANSFORM ▸", _toggle_transform_panel_v077, true)
	transform_toggle_v077.custom_minimum_size.y = 40.0
	outer.add_child(transform_toggle_v077)

	transform_body_v077 = VBoxContainer.new()
	transform_body_v077.add_theme_constant_override("separation", 5)
	transform_body_v077.visible = false
	outer.add_child(transform_body_v077)

	transform_hint_v077 = Label.new()
	transform_hint_v077.text = "Drag arrows to move • drag rings to rotate"
	transform_hint_v077.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transform_hint_v077.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transform_hint_v077.add_theme_font_size_override("font_size", 11)
	transform_hint_v077.add_theme_color_override("font_color", Color(0.66, 0.78, 0.88))
	transform_body_v077.add_child(transform_hint_v077)

	transform_body_v077.add_child(_section_label("MOUNT ROLL • 45°"))
	var roll_row := HBoxContainer.new()
	roll_row.add_theme_constant_override("separation", 4)
	transform_body_v077.add_child(roll_row)
	transform_roll_minus_v077 = _ui_button("Roll −", func() -> void: _apply_roll_v030(-1))
	transform_roll_plus_v077 = _ui_button("Roll +", func() -> void: _apply_roll_v030(1))
	roll_row.add_child(transform_roll_minus_v077)
	roll_row.add_child(transform_roll_plus_v077)
	transform_reset_v077 = _ui_button("Reset Placement Rotation", _reset_rotation_v020)
	transform_reset_v077.custom_minimum_size.y = 38.0
	transform_body_v077.add_child(transform_reset_v077)

	transform_body_v077.add_child(_section_label("AXLE SLIDE"))
	var slide_row := HBoxContainer.new()
	slide_row.add_theme_constant_override("separation", 4)
	transform_body_v077.add_child(slide_row)
	transform_slide_minus_v077 = _ui_button("Slide −", func() -> void: _slide_selected_on_axle(-EDIT_AXLE_STEP))
	transform_slide_plus_v077 = _ui_button("Slide +", func() -> void: _slide_selected_on_axle(EDIT_AXLE_STEP))
	slide_row.add_child(transform_slide_minus_v077)
	slide_row.add_child(transform_slide_plus_v077)


func _toggle_transform_panel_v077() -> void:
	transform_panel_open_v077 = not transform_panel_open_v077
	_update_transform_panel_layout_v077()


func _update_transform_panel_layout_v077() -> void:
	if transform_panel_v077 == null or transform_body_v077 == null:
		return
	transform_body_v077.visible = transform_panel_open_v077
	if transform_toggle_v077 != null:
		transform_toggle_v077.text = "TRANSFORM ▾" if transform_panel_open_v077 else "TRANSFORM ▸"
	transform_panel_v077.offset_bottom = 306.0 if transform_panel_open_v077 else 124.0


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	# Old callers/tests may still request MOVE. It is now the same TRANSFORM mode.
	var requested: int = EDITOR_ROTATE_032 if mode_value == EDITOR_MOVE_042 else mode_value
	super._set_editor_mode_v032(requested, false)
	right_panel_state_v037 = ""
	if rotation_panel != null:
		rotation_panel.visible = false
	if move_panel != null:
		move_panel.visible = false
	_update_mode_ui_v032()
	_update_transform_ui_v077()
	if not report:
		return
	match editor_mode_v032:
		EDITOR_CREATE_032:
			_status("CREATE mode — build normally. Camera joystick and look gestures stay available.")
		EDITOR_ROTATE_032:
			_status("TRANSFORM mode — drag arrows to move, rings to rotate, or use the compact mount/slide panel.")
		EDITOR_ATTACH_032:
			_status("ATTACH mode — select connection points while camera navigation remains available around the viewport edges.")


func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	if move_mode_button_v042 != null:
		move_mode_button_v042.visible = false
	if rotate_button_v032 != null:
		var active: bool = editor_mode_v032 == EDITOR_ROTATE_032
		rotate_button_v032.text = ("● " if active else "") + "TRANSFORM"
		rotate_button_v032.self_modulate = Color(0.68, 0.94, 1.0) if active else Color.WHITE
	if mode_hint_v032 != null and editor_mode_v032 == EDITOR_ROTATE_032:
		mode_hint_v032.text = "Move arrows + rotation rings"


func _selected_has_axle_slide_v077() -> bool:
	if not is_instance_valid(selected_piece):
		return false
	if str(selected_piece.get_meta("kind", "")) == "o_ring":
		return is_instance_valid(_find_o_ring_host(selected_piece))
	return _find_axle_joint_for_body(selected_piece) != null


func _update_transform_ui_v077() -> void:
	var transform_mode: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating
	if transform_panel_v077 != null:
		transform_panel_v077.visible = transform_mode and not _camera_controls_blocked_v077()
	if not transform_mode:
		return
	var connector_selected: bool = is_instance_valid(selected_piece) and str(selected_piece.get_meta("kind", "")) == "connector"
	if transform_roll_minus_v077 != null:
		transform_roll_minus_v077.disabled = not connector_selected
	if transform_roll_plus_v077 != null:
		transform_roll_plus_v077.disabled = not connector_selected
	if transform_reset_v077 != null:
		transform_reset_v077.disabled = not connector_selected
	var cross_slide: bool = not _cross_slide_record_v074(selected_piece as RigidBody3D).is_empty() if is_instance_valid(selected_piece) else false
	var axle_slide: bool = _selected_has_axle_slide_v077()
	if transform_slide_minus_v077 != null:
		transform_slide_minus_v077.disabled = not axle_slide
	if transform_slide_plus_v077 != null:
		transform_slide_plus_v077.disabled = not axle_slide
	if transform_hint_v077 != null:
		if cross_slide:
			transform_hint_v077.text = "Drag the SLIDE arrow along this CROSS rod • rotation rings rotate the island"
		elif axle_slide:
			transform_hint_v077.text = "Arrows move • rings rotate • Slide ± moves along the axle"
		else:
			transform_hint_v077.text = "Drag arrows to move • drag rings to rotate"
	_update_transform_panel_layout_v077()


func _update_ui() -> void:
	super._update_ui()
	right_panel_state_v037 = ""
	if rotation_panel != null:
		rotation_panel.visible = false
	if move_panel != null:
		move_panel.visible = false
	_update_transform_ui_v077()


# Move input is inherited from the old MOVE mode. Temporarily present TRANSFORM
# as MOVE only while that picker runs; v0.5.18's special CROSS SLIDE path is then
# reused unchanged. If no move arrow is hit, input falls through to the existing
# rotation-ring picker and finally to camera look.
func _handle_move_input_v042(event: InputEvent) -> bool:
	if editor_mode_v032 != EDITOR_ROTATE_032:
		return super._handle_move_input_v042(event)
	if _camera_controls_blocked_v077():
		return false
	var keep_mode: int = editor_mode_v032
	editor_mode_v032 = EDITOR_MOVE_042
	var handled: bool = super._handle_move_input_v042(event)
	editor_mode_v032 = keep_mode
	return handled


func _handle_tap(screen_pos: Vector2) -> void:
	if editor_mode_v032 == EDITOR_ROTATE_032 and not select_armed_v020:
		_status("TRANSFORM mode — drag an arrow/ring, or press Select before choosing a different piece.")
		return
	super._handle_tap(screen_pos)


func _refresh_transform_gizmos_v077() -> void:
	if move_gizmo_root_v042 == null:
		return
	var show: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and not _camera_controls_blocked_v077()
	move_gizmo_root_v042.visible = show
	if not show:
		return
	move_gizmo_root_v042.global_basis = Basis.IDENTITY
	move_gizmo_root_v042.global_position = selected_piece.global_position
	var scale_value: float = clampf(camera_distance / 19.0, 0.62, 2.10)
	move_gizmo_root_v042.scale = Vector3.ONE * scale_value

	var x_data := move_gizmo_axes_v042.get("X", {}) as Dictionary
	var y_data := move_gizmo_axes_v042.get("Y", {}) as Dictionary
	var z_data := move_gizmo_axes_v042.get("Z", {}) as Dictionary
	var x_root := x_data.get("root") as Node3D
	var y_root := y_data.get("root") as Node3D
	var z_root := z_data.get("root") as Node3D
	var special: Dictionary = _cross_slide_record_v074(selected_piece as RigidBody3D)
	if special.is_empty():
		if x_root != null:
			x_root.visible = true
			x_root.basis = Basis.IDENTITY
		if y_root != null:
			y_root.visible = true
			y_root.basis = Basis.IDENTITY
			_set_move_axis_label_v074(y_root, "Y")
		if z_root != null:
			z_root.visible = true
			z_root.basis = Basis.IDENTITY
		return

	var rod := special.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	if x_root != null:
		x_root.visible = false
	if z_root != null:
		z_root.visible = false
	if y_root != null:
		y_root.visible = true
		y_root.basis = Basis(Quaternion(Vector3.UP, axis))
		_set_move_axis_label_v074(y_root, "SLIDE")
	var view: Vector3 = camera.global_position - rod.global_position
	var side: Vector3 = axis.cross(view)
	if side.length_squared() < 0.02:
		side = _stable_perpendicular_v030(axis)
	else:
		side = side.normalized()
	move_gizmo_root_v042.global_position = rod.global_position + side * CROSS_SLIDE_GIZMO_OFFSET_V074 * scale_value


# -----------------------------------------------------------------------------
# Camera navigation.
# Left analog stick translates the camera target relative to current view heading;
# the camera follows because camera + orbit target move together. Right-side
# buttons move that target vertically. Empty-world drag remains the look/orbit pad.
# -----------------------------------------------------------------------------

func _round_panel_style_v077(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.40, 0.72, 0.92, 0.38)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _build_camera_controls_v077() -> void:
	camera_layer_v077 = CanvasLayer.new()
	camera_layer_v077.layer = 5
	add_child(camera_layer_v077)

	camera_joystick_v077 = PanelContainer.new()
	camera_joystick_v077.name = "CameraMoveJoystickV077"
	camera_joystick_v077.custom_minimum_size = Vector2(CAMERA_JOYSTICK_SIZE_077, CAMERA_JOYSTICK_SIZE_077)
	camera_joystick_v077.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_joystick_v077.add_theme_stylebox_override("panel", _round_panel_style_v077(Color(0.05, 0.08, 0.11, 0.50), 66))
	camera_layer_v077.add_child(camera_joystick_v077)

	camera_joystick_knob_v077 = PanelContainer.new()
	camera_joystick_knob_v077.custom_minimum_size = Vector2(CAMERA_JOYSTICK_KNOB_077, CAMERA_JOYSTICK_KNOB_077)
	camera_joystick_knob_v077.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_joystick_knob_v077.add_theme_stylebox_override("panel", _round_panel_style_v077(Color(0.16, 0.55, 0.78, 0.78), 24))
	camera_joystick_v077.add_child(camera_joystick_knob_v077)

	camera_up_button_v077 = _ui_button("▲\nUP", func() -> void: pass, true)
	camera_down_button_v077 = _ui_button("▼\nDOWN", func() -> void: pass, true)
	for value in [camera_up_button_v077, camera_down_button_v077]:
		var button := value as Button
		button.custom_minimum_size = Vector2(62.0, 62.0)
		button.add_theme_font_size_override("font_size", 13)
		button.self_modulate = Color(1, 1, 1, 0.68)
		camera_layer_v077.add_child(button)
	camera_up_button_v077.button_down.connect(func() -> void: camera_vertical_v077 = 1.0)
	camera_up_button_v077.button_up.connect(func() -> void: camera_vertical_v077 = 0.0)
	camera_down_button_v077.button_down.connect(func() -> void: camera_vertical_v077 = -1.0)
	camera_down_button_v077.button_up.connect(func() -> void: camera_vertical_v077 = 0.0)

	_reset_joystick_knob_v077()


func _layout_camera_controls_v077() -> void:
	if camera_joystick_v077 == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var left_edge: float = 214.0 if mode_panel_v032 != null and mode_panel_v032.visible else 18.0
	var bottom_reserved: float = 108.0
	if bottom_panel != null and bottom_panel.visible:
		bottom_reserved = maxf(100.0, -bottom_panel.offset_top + 8.0)
	var joy_pos := Vector2(left_edge + 10.0, maxf(82.0, viewport_size.y - bottom_reserved - CAMERA_JOYSTICK_SIZE_077 - 16.0))
	camera_joystick_v077.position = joy_pos
	camera_joystick_v077.size = Vector2(CAMERA_JOYSTICK_SIZE_077, CAMERA_JOYSTICK_SIZE_077)
	_reset_joystick_knob_v077(false)

	if camera_up_button_v077 != null and camera_down_button_v077 != null:
		var x_value: float = viewport_size.x - 76.0
		var middle: float = clampf(viewport_size.y * 0.50, 260.0, viewport_size.y - bottom_reserved - 140.0)
		camera_up_button_v077.position = Vector2(x_value, middle - 68.0)
		camera_up_button_v077.size = Vector2(62.0, 62.0)
		camera_down_button_v077.position = Vector2(x_value, middle + 4.0)
		camera_down_button_v077.size = Vector2(62.0, 62.0)


func _camera_controls_blocked_v077() -> bool:
	return _any_modal_open_v054()


func _update_camera_controls_visibility_v077() -> void:
	var visible_now: bool = not _camera_controls_blocked_v077()
	camera_controls_visible_v077 = visible_now
	if camera_joystick_v077 != null:
		camera_joystick_v077.visible = visible_now
	if camera_up_button_v077 != null:
		camera_up_button_v077.visible = visible_now
	if camera_down_button_v077 != null:
		camera_down_button_v077.visible = visible_now
	if not visible_now:
		camera_joystick_value_v077 = Vector2.ZERO
		camera_vertical_v077 = 0.0
		camera_joystick_touch_v077 = -999
		camera_joystick_mouse_v077 = false
		_reset_joystick_knob_v077()


func _joystick_rect_v077() -> Rect2:
	if camera_joystick_v077 == null:
		return Rect2()
	return camera_joystick_v077.get_global_rect()


func _set_joystick_from_screen_v077(screen_pos: Vector2) -> void:
	var rect: Rect2 = _joystick_rect_v077()
	if rect.size.x <= 0.0:
		return
	var center: Vector2 = rect.position + rect.size * 0.5
	var radius: float = rect.size.x * 0.5 - CAMERA_JOYSTICK_KNOB_077 * 0.5 - 7.0
	var delta: Vector2 = screen_pos - center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	camera_joystick_value_v077 = delta / maxf(1.0, radius)
	if camera_joystick_value_v077.length() < CAMERA_JOYSTICK_DEADZONE_077:
		camera_joystick_value_v077 = Vector2.ZERO
	if camera_joystick_knob_v077 != null:
		var local_center: Vector2 = rect.size * 0.5
		camera_joystick_knob_v077.position = local_center + delta - Vector2.ONE * (CAMERA_JOYSTICK_KNOB_077 * 0.5)
		camera_joystick_knob_v077.size = Vector2(CAMERA_JOYSTICK_KNOB_077, CAMERA_JOYSTICK_KNOB_077)


func _reset_joystick_knob_v077(clear_value: bool = true) -> void:
	if clear_value:
		camera_joystick_value_v077 = Vector2.ZERO
	if camera_joystick_v077 == null or camera_joystick_knob_v077 == null:
		return
	var center := Vector2(CAMERA_JOYSTICK_SIZE_077, CAMERA_JOYSTICK_SIZE_077) * 0.5
	camera_joystick_knob_v077.position = center - Vector2.ONE * (CAMERA_JOYSTICK_KNOB_077 * 0.5)
	camera_joystick_knob_v077.size = Vector2(CAMERA_JOYSTICK_KNOB_077, CAMERA_JOYSTICK_KNOB_077)


func _input(event: InputEvent) -> void:
	if not camera_controls_visible_v077 or camera_joystick_v077 == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and camera_joystick_touch_v077 == -999 and _joystick_rect_v077().has_point(touch.position):
			camera_joystick_touch_v077 = touch.index
			_set_joystick_from_screen_v077(touch.position)
			get_viewport().set_input_as_handled()
			return
		if not touch.pressed and touch.index == camera_joystick_touch_v077:
			camera_joystick_touch_v077 = -999
			_reset_joystick_knob_v077()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == camera_joystick_touch_v077:
			_set_joystick_from_screen_v077(drag.position)
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and _joystick_rect_v077().has_point(mouse_button.position):
				camera_joystick_mouse_v077 = true
				_set_joystick_from_screen_v077(mouse_button.position)
				get_viewport().set_input_as_handled()
				return
			if not mouse_button.pressed and camera_joystick_mouse_v077:
				camera_joystick_mouse_v077 = false
				_reset_joystick_knob_v077()
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventMouseMotion and camera_joystick_mouse_v077:
		_set_joystick_from_screen_v077((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _apply_camera_navigation_v077(delta: float) -> void:
	if camera == null or _camera_controls_blocked_v077():
		return
	var speed: float = maxf(CAMERA_MOVE_MIN_SPEED_077, camera_distance * CAMERA_MOVE_DISTANCE_SCALE_077) * camera_sensitivity
	if camera_joystick_value_v077.length() >= CAMERA_JOYSTICK_DEADZONE_077:
		var right: Vector3 = camera.global_transform.basis.x
		right.y = 0.0
		if right.length_squared() > 0.001:
			right = right.normalized()
		var forward: Vector3 = -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.001:
			forward = forward.normalized()
		camera_target += (right * camera_joystick_value_v077.x + forward * -camera_joystick_value_v077.y) * speed * delta
	if absf(camera_vertical_v077) > 0.01:
		camera_target.y += camera_vertical_v077 * speed * CAMERA_VERTICAL_SPEED_SCALE_077 * delta
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 2.0, PLATFORM_HALF - 2.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 2.0, PLATFORM_HALF - 2.0)
	camera_target.y = clampf(camera_target.y, -12.0, 90.0)


# Two-finger pan remains available, but unlike the historical implementation it
# must not erase elevation chosen with the new UP/DOWN controls.
func _pan_camera(screen_delta: Vector2) -> void:
	if camera == null:
		return
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.001:
		right = right.normalized()
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()
	var x_factor: float = -1.0 if reverse_pan_x else 1.0
	var y_factor: float = -1.0 if reverse_pan_y else 1.0
	var move_scale: float = camera_distance * 0.0027 * camera_sensitivity
	camera_target += (-right * screen_delta.x * x_factor + forward * screen_delta.y * y_factor) * move_scale
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 2.0, PLATFORM_HALF - 2.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 2.0, PLATFORM_HALF - 2.0)


func _construction_frame_v077() -> Dictionary:
	var has_any: bool = false
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		has_any = true
		var margin: float = maxf(1.5, float(body.get_meta("visual_length", 0.0)) * 0.5)
		minimum = minimum.min(body.global_position - Vector3.ONE * margin)
		maximum = maximum.max(body.global_position + Vector3.ONE * margin)
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		has_any = true
		minimum = minimum.min(ring.global_position - Vector3.ONE)
		maximum = maximum.max(ring.global_position + Vector3.ONE)
	if not has_any:
		return {"center": Vector3(0, 4, 0), "span": 8.0}
	var size: Vector3 = maximum - minimum
	return {"center": (minimum + maximum) * 0.5, "span": maxf(size.x, maxf(size.y, size.z))}


func _center_view() -> void:
	if center_long_suppress_v077:
		center_long_suppress_v077 = false
		return
	if is_instance_valid(selected_piece):
		camera_target = selected_piece.global_position
		camera_distance = clampf(camera_distance, 6.0, 36.0)
		_status("Camera centered on selected %s" % _piece_display_name(selected_piece))
		return
	var frame: Dictionary = _construction_frame_v077()
	camera_target = frame.get("center", Vector3(0, 4, 0)) as Vector3
	camera_distance = clampf(maxf(12.0, float(frame.get("span", 8.0)) * 1.65), 7.0, 160.0)
	_status("Camera centered on the whole construction")


func _center_button_down_v077() -> void:
	center_press_started_v077 = Time.get_ticks_msec()
	center_long_suppress_v077 = false


func _center_button_up_v077() -> void:
	if center_press_started_v077 <= 0:
		return
	var held: int = Time.get_ticks_msec() - center_press_started_v077
	center_press_started_v077 = 0
	if held < CENTER_LONG_PRESS_MS_077:
		return
	center_long_suppress_v077 = true
	_reset_camera_home_v077()


func _reset_camera_home_v077() -> void:
	var frame: Dictionary = _construction_frame_v077()
	camera_target = frame.get("center", Vector3(0, 4, 0)) as Vector3
	camera_yaw = deg_to_rad(35.0)
	camera_pitch = deg_to_rad(28.0)
	camera_distance = clampf(maxf(19.0, float(frame.get("span", 8.0)) * 1.75), 8.0, 160.0)
	_status("Camera view fully reset")


# -----------------------------------------------------------------------------
# Touch scrolling. ScrollContainer children historically used STOP mouse filters,
# which let a card/button keep its press while the parent was being dragged and
# then fire on finger release. PASS lets the ScrollContainer own the gesture once
# its 14px deadzone is crossed; taps below the threshold still activate normally.
# -----------------------------------------------------------------------------

func _configure_scroll_touch_v077(node: Node, inside_scroll: bool) -> void:
	if node == null:
		return
	var now_inside: bool = inside_scroll or node is ScrollContainer
	if node is ScrollContainer:
		var scroll := node as ScrollContainer
		scroll.scroll_deadzone = MENU_SCROLL_DEADZONE_077
		scroll.follow_focus = false
	if now_inside and node is BaseButton:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child_value in node.get_children():
		_configure_scroll_touch_v077(child_value as Node, now_inside)


func _refresh_parts_browser_v050() -> void:
	super._refresh_parts_browser_v050()
	if parts_panel_v050 != null:
		_configure_scroll_touch_v077(parts_panel_v050, false)


func _process(delta: float) -> void:
	super._process(delta)
	_layout_camera_controls_v077()
	_update_camera_controls_visibility_v077()
	_apply_camera_navigation_v077(delta)
	_refresh_transform_gizmos_v077()
	_update_transform_ui_v077()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCAMERA: the translucent left joystick moves forward/back/left/right relative to the current view. Hold UP/DOWN on the right edge for elevation. Drag the open 3D viewport to look/orbit; pinch still zooms and two-finger pan remains available. Camera movement translates the orbit target with the camera, so look/orbit never starts circling an old point behind you.\n\nCENTER: tap Center to focus the selected piece. With nothing selected it frames the whole construction. Hold Center for a full heading/pitch/distance reset.\n\nEDITOR: CREATE builds, TRANSFORM combines world move arrows and 45° rotation rings on the selected construction, and ATTACH exposes connection points. The old separate MOVE mode and duplicate X/Y/Z right-panel buttons are gone.\n\nTRANSFORM PANEL: the small right header contains only mount-relative Roll/Reset and axle Slide helpers. CROSS rods that can slide show their dedicated SLIDE arrow beside the rod.\n\nATTACH / PHYSICS: all existing SOCKET, AXLE, CROSS, O-Ring, save/load and simulation behavior is retained.\n\nTOUCH MENUS: scroll gestures claim control after a small deadzone, preventing a card/button underneath the finger from activating when a scroll ends." % VERSION_077
