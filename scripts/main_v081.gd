extends "res://scripts/main_v080.gd"

const VERSION_081 := "0.5.22"
const CAMERA_JOYSTICK_SIZE_081 := 148.0
const CAMERA_JOYSTICK_KNOB_081 := 52.0
const CAMERA_VERTICAL_BUTTON_SIZE_081 := 148.0
const CAMERA_VERTICAL_BUTTON_GAP_081 := 12.0
const MOVE_GIZMO_SCALE_BOOST_081 := 1.65

var camera_vertical_touch_v081: int = -999
var transform_close_button_v081: Button
var transform_panel_hidden_v081: bool = false

var top_delete_button_v081: Button
var restart_confirm_v081: ConfirmationDialog
var delete_confirm_v081: ConfirmationDialog
var delete_pending_piece_v081: RigidBody3D
var options_help_button_v081: Button

var bottom_rod_preview_v081: SubViewportContainer
var bottom_rod_viewport_v081: SubViewport
var bottom_rod_root_v081: Node3D
var bottom_rod_camera_v081: Camera3D
var bottom_connector_preview_v081: SubViewportContainer
var bottom_connector_viewport_v081: SubViewport
var bottom_connector_root_v081: Node3D
var bottom_connector_camera_v081: Camera3D
var bottom_last_rod_v081: int = -999
var bottom_last_connector_v081: int = -999


func _ready() -> void:
	super._ready()
	_install_confirmation_dialogs_v081()
	_rebuild_top_toolbar_v081()
	_rebuild_left_toolbar_v081()
	_rebuild_bottom_toolbar_v081()
	_reorganize_options_v081()
	_move_rigidity_into_physics_v081()
	_retitle_submenus_v081()
	_install_menu_close_buttons_v081()
	_refresh_bottom_previews_v081(true)
	_update_ui()
	_layout_camera_controls_v077()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_081)
	_status("v0.5.22 ready — simultaneous camera movement/elevation, orbit-only touch, icon toolbars and compact transform controls are active.")


func _status(text: String) -> void:
	# Status remains available to inherited code/debugging, but v0.5.22 deliberately
	# removes it from the always-visible top toolbar.
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_081, text]


# -----------------------------------------------------------------------------
# TRANSFORM side card — always-open compact controls, no duplicate axle slide.
# -----------------------------------------------------------------------------

func _build_transform_panel_v077() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)

	transform_panel_v077 = PanelContainer.new()
	transform_panel_v077.anchor_left = 1.0
	transform_panel_v077.anchor_right = 1.0
	transform_panel_v077.offset_left = -190.0
	transform_panel_v077.offset_right = -8.0
	transform_panel_v077.offset_top = 82.0
	transform_panel_v077.offset_bottom = 244.0
	transform_panel_v077.add_theme_stylebox_override("panel", _panel_style(0.94, 11))
	layer.add_child(transform_panel_v077)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	transform_panel_v077.add_child(outer)

	var close_row := HBoxContainer.new()
	close_row.add_theme_constant_override("separation", 2)
	outer.add_child(close_row)
	var close_spacer := Control.new()
	close_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(close_spacer)
	transform_close_button_v081 = _ui_button("✕", _close_transform_panel_v081, true)
	transform_close_button_v081.custom_minimum_size = Vector2(36.0, 32.0)
	transform_close_button_v081.tooltip_text = "Close transform controls"
	close_row.add_child(transform_close_button_v081)

	transform_body_v077 = VBoxContainer.new()
	transform_body_v077.add_theme_constant_override("separation", 4)
	transform_body_v077.visible = true
	outer.add_child(transform_body_v077)

	# Preserve ITEM/WORLD as a useful transform-space feature, but remove its old
	# descriptive sentence and the redundant "Space:" wording.
	transform_space_button_v078 = _ui_button("ITEM", _toggle_transform_space_v051, true)
	transform_space_button_v078.custom_minimum_size.y = 34.0
	transform_space_button_v078.tooltip_text = "Toggle ITEM / WORLD transform space"
	transform_body_v077.add_child(transform_space_button_v078)

	var roll_row := HBoxContainer.new()
	roll_row.add_theme_constant_override("separation", 4)
	transform_body_v077.add_child(roll_row)
	transform_roll_minus_v077 = _ui_button("Roll −", func() -> void: _apply_roll_v030(-1))
	transform_roll_plus_v077 = _ui_button("Roll +", func() -> void: _apply_roll_v030(1))
	transform_roll_minus_v077.custom_minimum_size.y = 34.0
	transform_roll_plus_v077.custom_minimum_size.y = 34.0
	roll_row.add_child(transform_roll_minus_v077)
	roll_row.add_child(transform_roll_plus_v077)

	transform_reset_v077 = _ui_button("Reset Rotation", _reset_rotation_v020)
	transform_reset_v077.custom_minimum_size.y = 34.0
	transform_body_v077.add_child(transform_reset_v077)

	# Retired UI nodes stay null. Axle/CROSS/O-Ring sliding is performed by the
	# translation gizmo, so the old Slide ± row is intentionally not recreated.
	transform_toggle_v077 = null
	transform_hint_v077 = null
	transform_slide_minus_v077 = null
	transform_slide_plus_v077 = null
	transform_panel_open_v077 = true


func _close_transform_panel_v081() -> void:
	transform_panel_hidden_v081 = true
	if transform_panel_v077 != null:
		transform_panel_v077.visible = false


func _update_transform_panel_layout_v077() -> void:
	if transform_panel_v077 == null:
		return
	if transform_body_v077 != null:
		transform_body_v077.visible = true
	transform_panel_v077.offset_left = -190.0
	transform_panel_v077.offset_right = -8.0
	transform_panel_v077.offset_top = 82.0
	transform_panel_v077.offset_bottom = 244.0


func _update_transform_ui_v077() -> void:
	var transform_mode: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating
	if transform_panel_v077 != null:
		transform_panel_v077.visible = transform_mode and not transform_panel_hidden_v081 and not _camera_controls_blocked_v077()
	if transform_space_button_v078 != null:
		transform_space_button_v078.text = "ITEM" if transform_space_v051 == SPACE_ITEM_051 else "WORLD"
	var connector_selected: bool = is_instance_valid(selected_piece) and str(selected_piece.get_meta("kind", "")) == "connector"
	if transform_roll_minus_v077 != null:
		transform_roll_minus_v077.disabled = not connector_selected
	if transform_roll_plus_v077 != null:
		transform_roll_plus_v077.disabled = not connector_selected
	if transform_reset_v077 != null:
		transform_reset_v077.disabled = not connector_selected
	_update_transform_panel_layout_v077()


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	var requested: int = EDITOR_ROTATE_032 if mode_value == EDITOR_MOVE_042 else mode_value
	if requested == EDITOR_ROTATE_032:
		# Pressing TRANSFORM again is also the way to bring its tiny side card back
		# after the user closes it with X.
		transform_panel_hidden_v081 = false
	super._set_editor_mode_v032(mode_value, report)


# Make translation unmistakably different from rotation. The move root is scaled
# after the inherited ITEM/WORLD/CROSS placement logic, so hit-testing expands with
# the visible arrows while the rotation rings keep their original radius.
func _refresh_transform_gizmos_v077() -> void:
	super._refresh_transform_gizmos_v077()
	if move_gizmo_root_v042 != null and move_gizmo_root_v042.visible:
		var base_scale: float = clampf(camera_distance / 19.0, 0.62, 2.10)
		move_gizmo_root_v042.scale = Vector3.ONE * base_scale * MOVE_GIZMO_SCALE_BOOST_081


# -----------------------------------------------------------------------------
# Camera controls — bigger joystick, much larger elevation buttons, true two-touch
# joystick + elevation ownership, and no pinch/pan camera gesture.
# -----------------------------------------------------------------------------

func _build_camera_controls_v077() -> void:
	camera_layer_v077 = CanvasLayer.new()
	camera_layer_v077.layer = 5
	add_child(camera_layer_v077)

	camera_joystick_v077 = PanelContainer.new()
	camera_joystick_v077.name = "CameraMoveJoystickV081"
	camera_joystick_v077.custom_minimum_size = Vector2(CAMERA_JOYSTICK_SIZE_081, CAMERA_JOYSTICK_SIZE_081)
	camera_joystick_v077.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_joystick_v077.add_theme_stylebox_override("panel", _round_panel_style_v077(Color(0.05, 0.08, 0.11, 0.50), 74))
	camera_layer_v077.add_child(camera_joystick_v077)

	camera_joystick_pad_v078 = Control.new()
	camera_joystick_pad_v078.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_joystick_pad_v078.custom_minimum_size = Vector2(CAMERA_JOYSTICK_SIZE_081, CAMERA_JOYSTICK_SIZE_081)
	camera_joystick_v077.add_child(camera_joystick_pad_v078)

	camera_joystick_knob_v077 = PanelContainer.new()
	camera_joystick_knob_v077.custom_minimum_size = Vector2(CAMERA_JOYSTICK_KNOB_081, CAMERA_JOYSTICK_KNOB_081)
	camera_joystick_knob_v077.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_joystick_knob_v077.add_theme_stylebox_override("panel", _round_panel_style_v077(Color(0.16, 0.55, 0.78, 0.82), 28))
	camera_joystick_pad_v078.add_child(camera_joystick_knob_v077)

	camera_up_button_v077 = _ui_button("▲\nUP", _camera_noop_v078, true)
	camera_down_button_v077 = _ui_button("▼\nDOWN", _camera_noop_v078, true)
	for value in [camera_up_button_v077, camera_down_button_v077]:
		var button := value as Button
		button.custom_minimum_size = Vector2(CAMERA_VERTICAL_BUTTON_SIZE_081, CAMERA_VERTICAL_BUTTON_SIZE_081)
		button.add_theme_font_size_override("font_size", 19)
		button.self_modulate = Color(1, 1, 1, 0.74)
		camera_layer_v077.add_child(button)
	# Mouse/desktop hold behavior remains native. Touch uses a dedicated touch id
	# below, preventing the joystick finger from starving the elevation finger.
	camera_up_button_v077.button_down.connect(func() -> void: camera_vertical_v077 = 1.0)
	camera_up_button_v077.button_up.connect(func() -> void: camera_vertical_v077 = 0.0)
	camera_down_button_v077.button_down.connect(func() -> void: camera_vertical_v077 = -1.0)
	camera_down_button_v077.button_up.connect(func() -> void: camera_vertical_v077 = 0.0)
	_reset_joystick_knob_v077()


func _layout_camera_controls_v077() -> void:
	if camera_joystick_v077 == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var left_edge: float = 202.0 if mode_panel_v032 != null and mode_panel_v032.visible else 18.0
	var bottom_reserved: float = 126.0
	if bottom_panel != null and bottom_panel.visible:
		bottom_reserved = maxf(118.0, -bottom_panel.offset_top + 8.0)
	var joystick_y: float = maxf(84.0, viewport_size.y - bottom_reserved - CAMERA_JOYSTICK_SIZE_081 - 12.0)
	# Deliberately farther right than v0.5.21 so the translucent ring no longer
	# grazes the editor toolbar.
	camera_joystick_v077.position = Vector2(left_edge + 30.0, joystick_y)
	camera_joystick_v077.size = Vector2(CAMERA_JOYSTICK_SIZE_081, CAMERA_JOYSTICK_SIZE_081)
	if camera_joystick_pad_v078 != null:
		camera_joystick_pad_v078.size = Vector2(CAMERA_JOYSTICK_SIZE_081, CAMERA_JOYSTICK_SIZE_081)
	_reset_joystick_knob_v077(false)

	if camera_up_button_v077 != null and camera_down_button_v077 != null:
		var button_size: float = CAMERA_VERTICAL_BUTTON_SIZE_081
		var x_value: float = viewport_size.x - button_size - 8.0
		var bottom_limit: float = viewport_size.y - bottom_reserved - 8.0
		var top_limit: float = 252.0 if transform_panel_v077 != null and transform_panel_v077.visible else 84.0
		var pair_height: float = button_size * 2.0 + CAMERA_VERTICAL_BUTTON_GAP_081
		var max_top: float = maxf(top_limit, bottom_limit - pair_height)
		var desired_top: float = (top_limit + bottom_limit - pair_height) * 0.5
		var pair_top: float = clampf(desired_top, top_limit, max_top)
		camera_up_button_v077.position = Vector2(x_value, pair_top)
		camera_up_button_v077.size = Vector2(button_size, button_size)
		camera_down_button_v077.position = Vector2(x_value, pair_top + button_size + CAMERA_VERTICAL_BUTTON_GAP_081)
		camera_down_button_v077.size = Vector2(button_size, button_size)


func _set_joystick_from_screen_v077(screen_pos: Vector2) -> void:
	var rect: Rect2 = _joystick_rect_v077()
	if rect.size.x <= 0.0:
		return
	var center: Vector2 = rect.position + rect.size * 0.5
	var radius: float = rect.size.x * 0.5 - CAMERA_JOYSTICK_KNOB_081 * 0.5 - 7.0
	var delta: Vector2 = screen_pos - center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	camera_joystick_value_v077 = delta / maxf(1.0, radius)
	if camera_joystick_value_v077.length() < CAMERA_JOYSTICK_DEADZONE_077:
		camera_joystick_value_v077 = Vector2.ZERO
	if camera_joystick_knob_v077 != null:
		var local_center: Vector2 = rect.size * 0.5
		camera_joystick_knob_v077.position = local_center + delta - Vector2.ONE * (CAMERA_JOYSTICK_KNOB_081 * 0.5)
		camera_joystick_knob_v077.size = Vector2(CAMERA_JOYSTICK_KNOB_081, CAMERA_JOYSTICK_KNOB_081)


func _reset_joystick_knob_v077(clear_value: bool = true) -> void:
	if clear_value:
		camera_joystick_value_v077 = Vector2.ZERO
	if camera_joystick_knob_v077 == null:
		return
	var center := Vector2(CAMERA_JOYSTICK_SIZE_081, CAMERA_JOYSTICK_SIZE_081) * 0.5
	camera_joystick_knob_v077.position = center - Vector2.ONE * (CAMERA_JOYSTICK_KNOB_081 * 0.5)
	camera_joystick_knob_v077.size = Vector2(CAMERA_JOYSTICK_KNOB_081, CAMERA_JOYSTICK_KNOB_081)


func _camera_vertical_button_at_v081(screen_pos: Vector2) -> float:
	if camera_up_button_v077 != null and camera_up_button_v077.visible and camera_up_button_v077.get_global_rect().has_point(screen_pos):
		return 1.0
	if camera_down_button_v077 != null and camera_down_button_v077.visible and camera_down_button_v077.get_global_rect().has_point(screen_pos):
		return -1.0
	return 0.0


func _input(event: InputEvent) -> void:
	# Elevation owns a different touch id from the analog joystick. This is the
	# actual v0.5.22 fix for simultaneous joystick + UP/DOWN on Android.
	if camera_controls_visible_v077 and event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and camera_vertical_touch_v081 == -999:
			var vertical: float = _camera_vertical_button_at_v081(touch.position)
			if absf(vertical) > 0.01:
				camera_vertical_touch_v081 = touch.index
				camera_vertical_v077 = vertical
				get_viewport().set_input_as_handled()
				return
		if not touch.pressed and touch.index == camera_vertical_touch_v081:
			camera_vertical_touch_v081 = -999
			camera_vertical_v077 = 0.0
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenDrag and camera_vertical_touch_v081 != -999:
		var drag := event as InputEventScreenDrag
		if drag.index == camera_vertical_touch_v081:
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _update_camera_controls_visibility_v077() -> void:
	super._update_camera_controls_visibility_v077()
	if not camera_controls_visible_v077:
		camera_vertical_touch_v081 = -999


# v0.5.22 touch policy: one viewport finger orbits. A second viewport finger does
# NOT pan or zoom; both touches are consumed and marked moved until fully lifted.
# Mouse wheel/right/middle camera controls remain available for desktop testing.
func _unhandled_input(event: InputEvent) -> void:
	if _any_modal_open_v054() or _confirmation_open_v081():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		last_pointer_screen_v042 = touch.position
		if touch.pressed:
			super._unhandled_input(event)
			if _camera_tool_drag_active_v064():
				return
			if touches.size() >= 2:
				camera_multitouch_active_v064 = true
				camera_block_single_touch_v064 = true
				_mark_all_camera_touches_moved_v061()
				camera_multitouch_center_v064 = _camera_touch_center_v064()
				camera_multitouch_span_v064 = _camera_touch_span_v064()
				get_viewport().set_input_as_handled()
			return

		if camera_multitouch_active_v064 or camera_block_single_touch_v064:
			touch_moved[touch.index] = true
			super._unhandled_input(event)
			_mark_all_camera_touches_moved_v061()
			if touches.is_empty():
				_reset_camera_touch_state_v064()
			else:
				camera_multitouch_active_v064 = touches.size() >= 2
				camera_block_single_touch_v064 = true
				camera_multitouch_center_v064 = _camera_touch_center_v064()
				camera_multitouch_span_v064 = _camera_touch_span_v064()
			get_viewport().set_input_as_handled()
			return

		super._unhandled_input(event)
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		last_pointer_screen_v042 = drag.position
		if _camera_tool_drag_active_v064():
			super._unhandled_input(event)
			return
		if camera_multitouch_active_v064 or touches.size() >= 2:
			touches[drag.index] = drag.position
			camera_multitouch_active_v064 = true
			camera_block_single_touch_v064 = true
			_mark_all_camera_touches_moved_v061()
			camera_multitouch_center_v064 = _camera_touch_center_v064()
			camera_multitouch_span_v064 = _camera_touch_span_v064()
			get_viewport().set_input_as_handled()
			return
		if camera_block_single_touch_v064:
			touches[drag.index] = drag.position
			touch_moved[drag.index] = true
			get_viewport().set_input_as_handled()
			return
		touches[drag.index] = drag.position
		if drag.relative.length() > 1.0:
			touch_moved[drag.index] = true
			_orbit_camera_v064(drag.relative)
		get_viewport().set_input_as_handled()
		return

	super._unhandled_input(event)


# -----------------------------------------------------------------------------
# Top toolbar — icon-only, grouped exactly as requested.
# -----------------------------------------------------------------------------

func _replace_pressed_callback_v081(button: Button, callback: Callable) -> void:
	if button == null:
		return
	for connection_value in button.pressed.get_connections():
		var connection: Dictionary = connection_value as Dictionary
		var old_callable: Callable = connection.get("callable", Callable())
		if old_callable.is_valid():
			button.pressed.disconnect(old_callable)
	button.pressed.connect(callback)


func _toolbar_separator_v081() -> VSeparator:
	var separator := VSeparator.new()
	separator.custom_minimum_size = Vector2(11.0, 50.0)
	return separator


func _style_top_icon_v081(button: Button, glyph: String, tooltip: String) -> void:
	if button == null:
		return
	button.text = glyph
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(54.0, 54.0)
	button.add_theme_font_size_override("font_size", 26)


func _rebuild_top_toolbar_v081() -> void:
	if status_label == null or status_label.get_parent() == null:
		return
	var top_row := status_label.get_parent() as HBoxContainer
	if top_row == null:
		return
	status_label.visible = false
	var top_panel := top_row.get_parent() as PanelContainer
	if top_panel != null:
		top_panel.offset_bottom = 76.0
		top_panel.add_theme_stylebox_override("panel", _panel_style(0.97, 11))
	top_row.add_theme_constant_override("separation", 4)

	# The old top-level ? is retired; Help now lives inside Options.
	for child_value in top_row.get_children():
		var old_help := child_value as Button
		if old_help != null and old_help.text == "?":
			old_help.visible = false

	top_delete_button_v081 = _ui_button("🗑", _request_delete_v081, true)
	top_row.add_child(top_delete_button_v081)

	_style_top_icon_v081(select_button_v020, "◎", "Select a piece")
	_style_top_icon_v081(top_center_button, "⊕", "Center selected piece / construction")
	_style_top_icon_v081(top_undo_button, "↶", "Undo")
	_style_top_icon_v081(top_redo_button, "↷", "Redo")
	_style_top_icon_v081(top_simulate_button, "▶", "Simulate")
	_style_top_icon_v081(top_restore_button, "⟳", "Restore build pose")
	_style_top_icon_v081(top_restart_button, "⊘", "Restart project")
	_style_top_icon_v081(top_delete_button_v081, "🗑", "Delete selected piece")
	_style_top_icon_v081(options_button, "⚙", "Options")

	_replace_pressed_callback_v081(top_restart_button, _request_restart_v081)

	var separators: Array = [
		_toolbar_separator_v081(),
		_toolbar_separator_v081(),
		_toolbar_separator_v081(),
		_toolbar_separator_v081(),
	]
	for separator_value in separators:
		top_row.add_child(separator_value as VSeparator)

	var ordered: Array = [
		select_button_v020, top_center_button, separators[0],
		top_undo_button, top_redo_button, separators[1],
		top_simulate_button, top_restore_button, separators[2],
		top_restart_button, top_delete_button_v081, separators[3],
		options_button,
	]
	for i in range(ordered.size()):
		var node := ordered[i] as Node
		if node != null and node.get_parent() == top_row:
			top_row.move_child(node, i)


func _refresh_top_toolbar_v081() -> void:
	if select_button_v020 != null:
		select_button_v020.text = "◎"
		select_button_v020.self_modulate = Color(0.66, 0.94, 1.0) if select_armed_v020 else Color.WHITE
	if top_center_button != null:
		top_center_button.text = "⊕"
	if top_undo_button != null:
		top_undo_button.text = "↶"
	if top_redo_button != null:
		top_redo_button.text = "↷"
	if top_simulate_button != null:
		top_simulate_button.text = "▶"
		top_simulate_button.self_modulate = Color(0.66, 0.94, 1.0) if simulating else Color.WHITE
	if top_restore_button != null:
		top_restore_button.text = "⟳"
	if top_restart_button != null:
		top_restart_button.text = "⊘"
	if top_delete_button_v081 != null:
		top_delete_button_v081.text = "🗑"
		top_delete_button_v081.disabled = simulating or not is_instance_valid(selected_piece)
	if options_button != null:
		options_button.text = "⚙"


# -----------------------------------------------------------------------------
# Confirm destructive top-toolbar actions.
# -----------------------------------------------------------------------------

func _install_confirmation_dialogs_v081() -> void:
	if restart_confirm_v081 == null:
		restart_confirm_v081 = ConfirmationDialog.new()
		restart_confirm_v081.title = "Restart Project"
		restart_confirm_v081.dialog_text = "Restart this project and clear the current construction?"
		restart_confirm_v081.ok_button_text = "Restart"
		restart_confirm_v081.cancel_button_text = "Cancel"
		restart_confirm_v081.confirmed.connect(_confirm_restart_v081)
		add_child(restart_confirm_v081)
	if delete_confirm_v081 == null:
		delete_confirm_v081 = ConfirmationDialog.new()
		delete_confirm_v081.title = "Delete Piece"
		delete_confirm_v081.ok_button_text = "Delete"
		delete_confirm_v081.cancel_button_text = "Cancel"
		delete_confirm_v081.confirmed.connect(_confirm_delete_v081)
		add_child(delete_confirm_v081)


func _confirmation_open_v081() -> bool:
	return (restart_confirm_v081 != null and restart_confirm_v081.visible) or (delete_confirm_v081 != null and delete_confirm_v081.visible)


func _request_restart_v081() -> void:
	if restart_confirm_v081 == null:
		_restart_build()
		return
	restart_confirm_v081.dialog_text = "Restart this project and clear the current construction?"
	restart_confirm_v081.popup_centered(Vector2i(470, 180))


func _confirm_restart_v081() -> void:
	_restart_build()


func _request_delete_v081() -> void:
	if simulating or not is_instance_valid(selected_piece):
		return
	delete_pending_piece_v081 = selected_piece
	if delete_confirm_v081 == null:
		_confirm_delete_v081()
		return
	delete_confirm_v081.dialog_text = "Delete %s from this project?" % _piece_display_name(selected_piece)
	delete_confirm_v081.popup_centered(Vector2i(470, 180))


func _confirm_delete_v081() -> void:
	if not is_instance_valid(delete_pending_piece_v081):
		return
	if selected_piece != delete_pending_piece_v081:
		_set_selected(delete_pending_piece_v081)
	_delete_selected()
	delete_pending_piece_v081 = null


func _camera_controls_blocked_v077() -> bool:
	return super._camera_controls_blocked_v077() or _confirmation_open_v081()


# -----------------------------------------------------------------------------
# Left toolbar — two concise utility actions; Delete moves to the top toolbar.
# -----------------------------------------------------------------------------

func _rebuild_left_toolbar_v081() -> void:
	if disconnect_button_v042 != null:
		disconnect_button_v042.text = "Disconnect"
		disconnect_button_v042.custom_minimum_size.y = 38.0
	if deselect_piece_button_v039 != null:
		deselect_piece_button_v039.text = "Deselect"
		deselect_piece_button_v039.custom_minimum_size.y = 38.0
	if delete_button_v032 != null:
		delete_button_v032.visible = false
		delete_button_v032.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if deselect_point_button_v032 != null:
		# Deselect Piece already clears any selected ATTACH point first, so the
		# separate Deselect Point button is redundant in the condensed toolbar.
		deselect_point_button_v032.visible = false
		deselect_point_button_v032.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode_panel_v032 != null:
		mode_panel_v032.offset_right = 198.0
		mode_panel_v032.offset_bottom = 398.0


# -----------------------------------------------------------------------------
# Bottom palette — icon-first controls and live rendered rod/connector previews.
# -----------------------------------------------------------------------------

func _make_bottom_preview_v081() -> Dictionary:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(112.0, 72.0)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(224, 144)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var root3d := Node3D.new()
	viewport.add_child(root3d)
	var preview_camera := Camera3D.new()
	preview_camera.fov = 34.0
	root3d.add_child(preview_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	key.light_energy = 1.45
	root3d.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28.0, 145.0, 0.0)
	fill.light_energy = 0.70
	root3d.add_child(fill)
	return {"container": container, "viewport": viewport, "root": root3d, "camera": preview_camera}


func _clear_bottom_preview_v081(root3d: Node3D, preview_camera: Camera3D) -> void:
	if root3d == null:
		return
	for child_value in root3d.get_children():
		var child := child_value as Node
		if child == preview_camera or child is Light3D:
			continue
		root3d.remove_child(child)
		child.queue_free()


func _install_bottom_previews_v081(row: HBoxContainer) -> void:
	if row == null or rod_label == null or connector_label == null:
		return
	if bottom_rod_preview_v081 == null:
		var rod_setup: Dictionary = _make_bottom_preview_v081()
		bottom_rod_preview_v081 = rod_setup.get("container") as SubViewportContainer
		bottom_rod_viewport_v081 = rod_setup.get("viewport") as SubViewport
		bottom_rod_root_v081 = rod_setup.get("root") as Node3D
		bottom_rod_camera_v081 = rod_setup.get("camera") as Camera3D
		row.add_child(bottom_rod_preview_v081)
		row.move_child(bottom_rod_preview_v081, rod_label.get_index())
	if bottom_connector_preview_v081 == null:
		var connector_setup: Dictionary = _make_bottom_preview_v081()
		bottom_connector_preview_v081 = connector_setup.get("container") as SubViewportContainer
		bottom_connector_viewport_v081 = connector_setup.get("viewport") as SubViewport
		bottom_connector_root_v081 = connector_setup.get("root") as Node3D
		bottom_connector_camera_v081 = connector_setup.get("camera") as Camera3D
		row.add_child(bottom_connector_preview_v081)
		row.move_child(bottom_connector_preview_v081, connector_label.get_index())
	rod_label.visible = false
	connector_label.visible = false


func _rebuild_bottom_toolbar_v081() -> void:
	if bottom_panel == null or rod_label == null:
		return
	bottom_panel.offset_top = -122.0
	bottom_panel.add_theme_stylebox_override("panel", _panel_style(0.97, 12))
	var row := rod_label.get_parent() as HBoxContainer
	if row == null:
		return
	row.add_theme_constant_override("separation", 6)
	_hide_bottom_title_v081(bottom_panel)
	if parts_button_v050 != null:
		parts_button_v050.text = "⚒"
		parts_button_v050.tooltip_text = "Parts"
		parts_button_v050.custom_minimum_size = Vector2(64.0, 64.0)
		parts_button_v050.add_theme_font_size_override("font_size", 25)

	for child_value in row.get_children():
		var button := child_value as Button
		if button == null or button == parts_button_v050 or button == mode_button:
			continue
		match button.text:
			"◀R", "◀ Rod":
				button.text = "←"
				button.tooltip_text = "Previous rod"
				button.custom_minimum_size = Vector2(58.0, 58.0)
				button.add_theme_font_size_override("font_size", 24)
			"R▶", "Rod ▶":
				button.text = "→"
				button.tooltip_text = "Next rod"
				button.custom_minimum_size = Vector2(58.0, 58.0)
				button.add_theme_font_size_override("font_size", 24)
			"◀C", "◀ Conn":
				button.text = "←"
				button.tooltip_text = "Previous connector"
				button.custom_minimum_size = Vector2(58.0, 58.0)
				button.add_theme_font_size_override("font_size", 24)
			"C▶", "Conn ▶":
				button.text = "→"
				button.tooltip_text = "Next connector"
				button.custom_minimum_size = Vector2(58.0, 58.0)
				button.add_theme_font_size_override("font_size", 24)
	if mode_button != null:
		mode_button.custom_minimum_size = Vector2(72.0, 72.0)
		mode_button.add_theme_font_size_override("font_size", 11)
		mode_button.tooltip_text = "Connection mode"
	_install_bottom_previews_v081(row)


func _hide_bottom_title_v081(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		var child := child_value as Node
		if child is Label:
			var label := child as Label
			if label.text in ["PARTS / MODE", "PARTS / CONNECTION MODE"]:
				label.visible = false
		_hide_bottom_title_v081(child)


func _render_bottom_rod_v081() -> void:
	if bottom_rod_root_v081 == null or bottom_rod_camera_v081 == null or rod_defs.is_empty():
		return
	_clear_bottom_preview_v081(bottom_rod_root_v081, bottom_rod_camera_v081)
	var index: int = clampi(selected_rod_type, 0, rod_defs.size() - 1)
	var definition: Dictionary = rod_defs[index] as Dictionary
	var length_world: float = float(definition.get("actual_mm", 0.0)) / 10.0
	var rod := RigidBody3D.new()
	rod.freeze = true
	bottom_rod_root_v081.add_child(rod)
	_rebuild_rod(rod, index, length_world)
	rod.rotation_degrees = Vector3(72.0, 0.0, 90.0)
	bottom_rod_camera_v081.position = Vector3(0.0, maxf(3.3, length_world * 0.24), maxf(7.0, length_world * 0.74))
	bottom_rod_camera_v081.look_at_from_position(bottom_rod_camera_v081.position, Vector3.ZERO, Vector3.UP)


func _render_bottom_connector_v081() -> void:
	if bottom_connector_root_v081 == null or bottom_connector_camera_v081 == null or connector_defs.is_empty():
		return
	_clear_bottom_preview_v081(bottom_connector_root_v081, bottom_connector_camera_v081)
	var index: int = clampi(selected_connector_type, 0, connector_defs.size() - 1)
	var definition: Dictionary = connector_defs[index] as Dictionary
	if index == o_ring_index or str(definition.get("special", "")) == "o_ring":
		var visual := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = O_RING_INNER_RADIUS_V040
		torus.outer_radius = O_RING_OUTER_RADIUS
		torus.rings = 24
		torus.ring_segments = 16
		visual.mesh = torus
		visual.material_override = _mat(definition.get("color", Color("343b44")) as Color)
		bottom_connector_root_v081.add_child(visual)
	else:
		var connector := RigidBody3D.new()
		connector.freeze = true
		bottom_connector_root_v081.add_child(connector)
		_rebuild_connector(connector, index)
		connector.rotation_degrees = Vector3(64.0, 0.0, 22.0)
	bottom_connector_camera_v081.position = Vector3(0.0, 4.0, 7.2)
	bottom_connector_camera_v081.look_at_from_position(bottom_connector_camera_v081.position, Vector3.ZERO, Vector3.UP)


func _refresh_bottom_previews_v081(force: bool = false) -> void:
	if force or bottom_last_rod_v081 != selected_rod_type:
		bottom_last_rod_v081 = selected_rod_type
		_render_bottom_rod_v081()
	if force or bottom_last_connector_v081 != selected_connector_type:
		bottom_last_connector_v081 = selected_connector_type
		_render_bottom_connector_v081()


func _refresh_bottom_mode_v081() -> void:
	if mode_button == null:
		return
	match attach_mode:
		0:
			mode_button.text = "SOCKET"
		1:
			mode_button.text = "AXLE"
		_:
			mode_button.text = "CROSS"


# -----------------------------------------------------------------------------
# Options hierarchy and consistent X close buttons.
# -----------------------------------------------------------------------------

func _open_help_from_options_v081() -> void:
	if options_panel != null:
		options_panel.visible = false
	if help_panel != null:
		help_panel.visible = true
	_sync_modal_blockers_v054()


func _reorganize_options_v081() -> void:
	if options_panel == null:
		return
	var box := _find_first_vbox_v050(options_panel)
	if box == null:
		return
	if physics_button_v051 != null:
		physics_button_v051.text = "Physics"
	if builds_button_v050 != null:
		builds_button_v050.text = "Save & Load"
	if options_help_button_v081 == null:
		options_help_button_v081 = _ui_button("Help", _open_help_from_options_v081, true)
		box.add_child(options_help_button_v081)
	var insert_at: int = mini(2, box.get_child_count())
	for button_value in [physics_button_v051, builds_button_v050, options_help_button_v081]:
		var button := button_value as Button
		if button == null or button.get_parent() != box:
			continue
		box.move_child(button, insert_at)
		insert_at += 1


func _move_node_v081(node: Node, target: Node, index: int) -> void:
	if node == null or target == null or node.get_parent() == null:
		return
	var old_parent := node.get_parent()
	old_parent.remove_child(node)
	target.add_child(node)
	target.move_child(node, clampi(index, 0, target.get_child_count() - 1))


func _move_rigidity_into_physics_v081() -> void:
	if physics_box_v051 == null or physics_structure_rigidity_label_v066 == null:
		return
	var slider := physics_sliders_v054.get("Structure rigidity") as HSlider
	if slider == null or slider.get_parent() == null:
		return
	var source_box := slider.get_parent() as VBoxContainer
	if source_box == null:
		return
	var explanation: Label = null
	var slider_index: int = slider.get_index()
	if slider_index + 1 < source_box.get_child_count():
		var candidate := source_box.get_child(slider_index + 1) as Label
		if candidate != null and candidate.text.begins_with("Controls closed-loop SOCKET flex"):
			explanation = candidate

	# Remove the old options-only section chrome left by v0.5.11.
	for child_value in source_box.get_children():
		var child := child_value as Node
		if child is Label and (child as Label).text == "STRUCTURE RIGIDITY":
			var section_index: int = child.get_index()
			child.visible = false
			if section_index > 0:
				var previous := source_box.get_child(section_index - 1)
				if previous is HSeparator:
					(previous as HSeparator).visible = false

	_move_node_v081(physics_structure_rigidity_label_v066, physics_box_v051, 1)
	_move_node_v081(slider, physics_box_v051, 2)
	if explanation != null:
		_move_node_v081(explanation, physics_box_v051, 3)
		var separator := HSeparator.new()
		physics_box_v051.add_child(separator)
		physics_box_v051.move_child(separator, mini(4, physics_box_v051.get_child_count() - 1))


func _retitle_first_label_v081(panel: Control, old_texts: Array, new_text: String) -> void:
	if panel == null:
		return
	var box := _find_first_vbox_v050(panel)
	if box == null:
		return
	for child_value in box.get_children():
		var label := child_value as Label
		if label != null and label.text in old_texts:
			label.text = new_text
			return


func _retitle_submenus_v081() -> void:
	_retitle_first_label_v081(physics_panel_v051, ["PHYSICS SETTINGS"], "PHYSICS")
	_retitle_first_label_v081(builds_panel_v050, ["SAVES & RECOVERY"], "SAVE & LOAD")


func _hide_legacy_close_buttons_v081(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		var child := child_value as Node
		if child is Button and (child as Button).text in ["Close", "Done"]:
			(child as Button).visible = false
		_hide_legacy_close_buttons_v081(child)


func _add_menu_close_button_v081(panel: Control, callback: Callable) -> void:
	if panel == null:
		return
	var box := _find_first_vbox_v050(panel)
	if box == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close_button := _ui_button("✕", callback, true)
	close_button.custom_minimum_size = Vector2(42.0, 36.0)
	close_button.tooltip_text = "Close"
	row.add_child(close_button)
	box.add_child(row)
	box.move_child(row, 0)
	_hide_legacy_close_buttons_v081(panel)


func _install_menu_close_buttons_v081() -> void:
	_add_menu_close_button_v081(options_panel, _toggle_options)
	_add_menu_close_button_v081(help_panel, _toggle_help)
	_add_menu_close_button_v081(parts_panel_v050, _toggle_parts_panel_v050)
	_add_menu_close_button_v081(builds_panel_v050, _close_builds_panel_v050)
	_add_menu_close_button_v081(physics_panel_v051, _hide_physics_panel_v051)


# -----------------------------------------------------------------------------
# Final UI refresh layer.
# -----------------------------------------------------------------------------

func _update_ui() -> void:
	super._update_ui()
	_refresh_top_toolbar_v081()
	if disconnect_button_v042 != null:
		disconnect_button_v042.text = "Disconnect"
	if deselect_piece_button_v039 != null:
		deselect_piece_button_v039.text = "Deselect"
	if delete_button_v032 != null:
		delete_button_v032.visible = false
	if deselect_point_button_v032 != null:
		deselect_point_button_v032.visible = false
	_refresh_bottom_mode_v081()
	_refresh_bottom_previews_v081(false)


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCAMERA: the larger lower-left joystick moves forward/back/left/right. Hold the much larger UP or DOWN button at the same time with a second finger for combined horizontal + vertical movement. Drag one finger in open 3D space to orbit. Pinch zoom and two-finger camera pan are disabled on touch; after a second viewport finger appears, both remain inert until released.\n\nTRANSFORM: move arrows and rotation rings remain visible together. Translation arrows are now 65%% larger than the rings so move and rotate are easy to distinguish. The small right card is non-collapsible and contains only ITEM/WORLD, mount Roll, Reset Rotation and X; duplicate Axle Slide buttons are removed because constrained movement uses the move gizmo.\n\nTOP BAR: Select, Center | Undo, Redo | Simulate, Restore | Restart, Delete | Options are icon-only. Restart and Delete require confirmation. Help is inside Options.\n\nOPTIONS: Physics, Save & Load and Help are the first three entries. Structure Rigidity is at the top of Physics and Reset Physics also resets it.\n\nBOTTOM BAR: Parts and cycling controls are icon-first, while the current rod and connector are rendered live from the same procedural geometry used by the Parts browser.\n\nSOCKET, AXLE, CROSS, O-Ring, save/load and simulation mechanics are otherwise unchanged." % VERSION_081


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if latest.is_empty():
		return
	if _compare_versions_v021(latest, VERSION_081) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_081)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_081, latest])
