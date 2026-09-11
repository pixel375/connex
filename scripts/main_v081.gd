extends "res://scripts/main_v080.gd"

const VERSION_081 := "0.5.22"
const CAMERA_JOYSTICK_SIZE_081 := 150.0
const CAMERA_JOYSTICK_KNOB_081 := 52.0
const CAMERA_ELEVATION_SIZE_081 := 148.0
const MOVE_GIZMO_LENGTH_081 := 4.65
const MOVE_GIZMO_PICK_PX_081 := 44.0

var camera_vertical_touch_v081: int = -999
var camera_multitouch_v081: Dictionary = {}
var transform_panel_hidden_v081: bool = false
var transform_close_v081: Button

var top_select_v081: Button
var top_center_v081: Button
var top_undo_v081: Button
var top_redo_v081: Button
var top_simulate_v081: Button
var top_restore_v081: Button
var top_restart_v081: Button
var top_delete_v081: Button
var top_options_v081: Button
var restart_confirm_v081: ConfirmationDialog
var delete_confirm_v081: ConfirmationDialog

var options_help_v081: Button
var bottom_rod_preview_v081: SubViewportContainer
var bottom_rod_viewport_v081: SubViewport
var bottom_rod_root_v081: Node3D
var bottom_rod_camera_v081: Camera3D
var bottom_connector_preview_v081: SubViewportContainer
var bottom_connector_viewport_v081: SubViewport
var bottom_connector_root_v081: Node3D
var bottom_connector_camera_v081: Camera3D
var bottom_preview_rod_index_v081: int = -999
var bottom_preview_connector_index_v081: int = -999


func _ready() -> void:
	super._ready()
	_install_top_bar_v081()
	_install_left_menu_v081()
	_install_options_order_v081()
	_relocate_structure_rigidity_v081()
	_install_menu_close_buttons_v081()
	_install_bottom_palette_v081()
	_configure_scroll_touch_v077(self, false)
	_layout_camera_controls_v077()
	_refresh_bottom_previews_v081(true)
	_update_ui()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_081)
	_status("v0.5.22 ready — simultaneous camera movement, touch-orbit-only navigation and the compact icon UI are active.")


func _status(text: String) -> void:
	# v0.5.22 intentionally removes the always-visible status strip. Keep status
	# writes alive for diagnostics and accessibility, but the Label stays hidden.
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_081, text]


# -----------------------------------------------------------------------------
# Camera controls: joystick and elevation are independent touch regions.
# -----------------------------------------------------------------------------

func _build_camera_controls_v077() -> void:
	super._build_camera_controls_v077()
	if camera_joystick_v077 != null:
		camera_joystick_v077.custom_minimum_size = Vector2.ONE * CAMERA_JOYSTICK_SIZE_081
	if camera_joystick_pad_v078 != null:
		camera_joystick_pad_v078.custom_minimum_size = Vector2.ONE * CAMERA_JOYSTICK_SIZE_081
	if camera_joystick_knob_v077 != null:
		camera_joystick_knob_v077.custom_minimum_size = Vector2.ONE * CAMERA_JOYSTICK_KNOB_081
	for value in [camera_up_button_v077, camera_down_button_v077]:
		var button := value as Button
		if button != null:
			button.custom_minimum_size = Vector2.ONE * CAMERA_ELEVATION_SIZE_081
			button.add_theme_font_size_override("font_size", 20)
	_reset_joystick_knob_v077()


func _layout_camera_controls_v077() -> void:
	if camera_joystick_v077 == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var left_edge: float = 198.0 if mode_panel_v032 != null and mode_panel_v032.visible else 18.0
	var bottom_reserved: float = 142.0
	if bottom_panel != null and bottom_panel.visible:
		bottom_reserved = maxf(bottom_reserved, -bottom_panel.offset_top + 10.0)
	# Deliberately leave a visible gap after the left editor panel.
	var joystick_y: float = maxf(86.0, viewport_size.y - bottom_reserved - CAMERA_JOYSTICK_SIZE_081 - 18.0)
	camera_joystick_v077.position = Vector2(left_edge + 28.0, joystick_y)
	camera_joystick_v077.size = Vector2.ONE * CAMERA_JOYSTICK_SIZE_081
	if camera_joystick_pad_v078 != null:
		camera_joystick_pad_v078.size = Vector2.ONE * CAMERA_JOYSTICK_SIZE_081
	_reset_joystick_knob_v077(false)

	if camera_up_button_v077 != null and camera_down_button_v077 != null:
		var x_value: float = viewport_size.x - CAMERA_ELEVATION_SIZE_081 - 12.0
		var bottom_limit: float = viewport_size.y - bottom_reserved - 10.0
		var pair_height: float = CAMERA_ELEVATION_SIZE_081 * 2.0 + 12.0
		var top_limit: float = 92.0
		var desired_top: float = (top_limit + bottom_limit - pair_height) * 0.5
		var pair_top: float = clampf(desired_top, top_limit, maxf(top_limit, bottom_limit - pair_height))
		camera_up_button_v077.position = Vector2(x_value, pair_top)
		camera_up_button_v077.size = Vector2.ONE * CAMERA_ELEVATION_SIZE_081
		camera_down_button_v077.position = Vector2(x_value, pair_top + CAMERA_ELEVATION_SIZE_081 + 12.0)
		camera_down_button_v077.size = Vector2.ONE * CAMERA_ELEVATION_SIZE_081


func _set_joystick_from_screen_v077(screen_pos: Vector2) -> void:
	var rect: Rect2 = _joystick_rect_v077()
	if rect.size.x <= 0.0:
		return
	var center: Vector2 = rect.position + rect.size * 0.5
	var radius: float = rect.size.x * 0.5 - CAMERA_JOYSTICK_KNOB_081 * 0.5 - 8.0
	var delta: Vector2 = screen_pos - center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	camera_joystick_value_v077 = delta / maxf(1.0, radius)
	if camera_joystick_value_v077.length() < CAMERA_JOYSTICK_DEADZONE_077:
		camera_joystick_value_v077 = Vector2.ZERO
	if camera_joystick_knob_v077 != null:
		camera_joystick_knob_v077.position = rect.size * 0.5 + delta - Vector2.ONE * (CAMERA_JOYSTICK_KNOB_081 * 0.5)
		camera_joystick_knob_v077.size = Vector2.ONE * CAMERA_JOYSTICK_KNOB_081


func _reset_joystick_knob_v077(clear_value: bool = true) -> void:
	if clear_value:
		camera_joystick_value_v077 = Vector2.ZERO
	if camera_joystick_knob_v077 == null:
		return
	var center := Vector2.ONE * (CAMERA_JOYSTICK_SIZE_081 * 0.5)
	camera_joystick_knob_v077.position = center - Vector2.ONE * (CAMERA_JOYSTICK_KNOB_081 * 0.5)
	camera_joystick_knob_v077.size = Vector2.ONE * CAMERA_JOYSTICK_KNOB_081


func _elevation_direction_at_v081(screen_pos: Vector2) -> float:
	if camera_up_button_v077 != null and camera_up_button_v077.visible and camera_up_button_v077.get_global_rect().has_point(screen_pos):
		return 1.0
	if camera_down_button_v077 != null and camera_down_button_v077.visible and camera_down_button_v077.get_global_rect().has_point(screen_pos):
		return -1.0
	return 0.0


func _input(event: InputEvent) -> void:
	# Consume an elevation finger ourselves instead of relying on Button's emulated
	# mouse stream. A separate touch can therefore remain on the analog joystick.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and camera_vertical_touch_v081 == -999:
			var vertical: float = _elevation_direction_at_v081(touch.position)
			if absf(vertical) > 0.01:
				camera_vertical_touch_v081 = touch.index
				camera_vertical_v077 = vertical
				get_viewport().set_input_as_handled()
				return
		elif not touch.pressed and touch.index == camera_vertical_touch_v081:
			camera_vertical_touch_v081 = -999
			camera_vertical_v077 = 0.0
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == camera_vertical_touch_v081:
			var vertical: float = _elevation_direction_at_v081(drag.position)
			if absf(vertical) > 0.01:
				camera_vertical_v077 = vertical
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _unhandled_input(event: InputEvent) -> void:
	# Touch navigation now has one simple viewport gesture: one-finger orbit.
	# Pinch zoom and two-finger pan are deliberately swallowed. Mouse wheel zoom
	# remains available on desktop and dedicated joystick/elevation controls remain
	# independent because their touches are handled earlier in _input().
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touches.size() >= 1:
				camera_multitouch_v081[touch.index] = true
				for key in touches.keys():
					camera_multitouch_v081[int(key)] = true
		else:
			if camera_multitouch_v081.has(touch.index):
				camera_multitouch_v081.erase(touch.index)
				touches.erase(touch.index)
				touch_start.erase(touch.index)
				touch_moved.erase(touch.index)
				pinch_last = -1.0
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touches.size() >= 2 or camera_multitouch_v081.has(drag.index):
			touches[drag.index] = drag.position
			for key in touches.keys():
				touch_moved[key] = true
				camera_multitouch_v081[int(key)] = true
			pinch_last = -1.0
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


# -----------------------------------------------------------------------------
# Compact right TRANSFORM menu. No accordion, heading, hint or axle buttons.
# -----------------------------------------------------------------------------

func _build_transform_panel_v077() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	transform_panel_v077 = PanelContainer.new()
	transform_panel_v077.anchor_left = 1.0
	transform_panel_v077.anchor_right = 1.0
	transform_panel_v077.offset_left = -178.0
	transform_panel_v077.offset_right = -8.0
	transform_panel_v077.offset_top = 82.0
	transform_panel_v077.offset_bottom = 236.0
	transform_panel_v077.add_theme_stylebox_override("panel", _panel_style(0.94, 11))
	layer.add_child(transform_panel_v077)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	transform_panel_v077.add_child(outer)
	var close_row := HBoxContainer.new()
	outer.add_child(close_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(spacer)
	transform_close_v081 = _ui_button("×", _close_transform_panel_v081, true)
	transform_close_v081.custom_minimum_size = Vector2(38.0, 34.0)
	transform_close_v081.size_flags_horizontal = Control.SIZE_SHRINK_END
	transform_close_v081.tooltip_text = "Close Transform controls"
	close_row.add_child(transform_close_v081)

	transform_body_v077 = VBoxContainer.new()
	transform_body_v077.add_theme_constant_override("separation", 5)
	transform_body_v077.visible = true
	outer.add_child(transform_body_v077)
	transform_space_button_v078 = _ui_button("ITEM", _toggle_transform_space_v051, true)
	transform_space_button_v078.custom_minimum_size.y = 38.0
	transform_body_v077.add_child(transform_space_button_v078)
	var roll_row := HBoxContainer.new()
	roll_row.add_theme_constant_override("separation", 4)
	transform_body_v077.add_child(roll_row)
	transform_roll_minus_v077 = _ui_button("Roll −", func() -> void: _apply_roll_v030(-1))
	transform_roll_plus_v077 = _ui_button("Roll +", func() -> void: _apply_roll_v030(1))
	roll_row.add_child(transform_roll_minus_v077)
	roll_row.add_child(transform_roll_plus_v077)
	transform_reset_v077 = _ui_button("Reset Rotation", _reset_rotation_v020)
	transform_reset_v077.custom_minimum_size.y = 36.0
	transform_body_v077.add_child(transform_reset_v077)
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
	if transform_panel_v077 == null or transform_body_v077 == null:
		return
	transform_body_v077.visible = true
	transform_panel_v077.offset_left = -178.0
	transform_panel_v077.offset_right = -8.0
	transform_panel_v077.offset_top = 82.0
	transform_panel_v077.offset_bottom = 236.0


func _update_transform_ui_v077() -> void:
	var transform_mode: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating
	if transform_panel_v077 != null:
		transform_panel_v077.visible = transform_mode and not transform_panel_hidden_v081 and not _camera_controls_blocked_v077()
	if transform_space_button_v078 != null:
		transform_space_button_v078.text = "ITEM" if transform_space_v051 == SPACE_ITEM_051 else "WORLD"
	if not transform_mode:
		return
	var connector_selected: bool = is_instance_valid(selected_piece) and str(selected_piece.get_meta("kind", "")) == "connector"
	if transform_roll_minus_v077 != null:
		transform_roll_minus_v077.disabled = not connector_selected
	if transform_roll_plus_v077 != null:
		transform_roll_plus_v077.disabled = not connector_selected
	if transform_reset_v077 != null:
		transform_reset_v077.disabled = not connector_selected
	_update_transform_panel_layout_v077()


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	var was_transform: bool = editor_mode_v032 == EDITOR_ROTATE_032
	super._set_editor_mode_v032(mode_value, report)
	if editor_mode_v032 == EDITOR_ROTATE_032 and not was_transform:
		transform_panel_hidden_v081 = false
	_update_transform_ui_v077()


# -----------------------------------------------------------------------------
# Translation gizmos are intentionally much longer than the rotation rings.
# -----------------------------------------------------------------------------

func _build_move_gizmo_v042() -> void:
	move_gizmo_root_v042 = Node3D.new()
	move_gizmo_root_v042.name = "MoveGizmoV081"
	add_child(move_gizmo_root_v042)
	move_gizmo_axes_v042.clear()
	_add_move_axis_v081("X", Vector3.RIGHT, Color(1.0, 0.20, 0.22))
	_add_move_axis_v081("Y", Vector3.UP, Color(0.20, 0.96, 0.36))
	_add_move_axis_v081("Z", Vector3.BACK, Color(0.20, 0.50, 1.0))
	move_gizmo_root_v042.visible = false


func _add_move_axis_v081(name_value: String, axis: Vector3, color: Color) -> void:
	var material: StandardMaterial3D = _overlay_material_v030(color)
	var axis_root := Node3D.new()
	axis_root.name = "MoveAxis%s" % name_value
	axis_root.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	move_gizmo_root_v042.add_child(axis_root)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.055
	shaft_mesh.bottom_radius = 0.055
	shaft_mesh.height = MOVE_GIZMO_LENGTH_081 * 2.0
	shaft_mesh.radial_segments = 10
	shaft.mesh = shaft_mesh
	shaft.material_override = material
	axis_root.add_child(shaft)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0 if side > 0.0 else 0.24
		cone.bottom_radius = 0.24 if side > 0.0 else 0.0
		cone.height = 0.62
		cone.radial_segments = 12
		tip.mesh = cone
		tip.material_override = material
		tip.position.y = side * (MOVE_GIZMO_LENGTH_081 + 0.28)
		axis_root.add_child(tip)
	var label := Label3D.new()
	label.text = name_value
	label.font_size = 30
	label.modulate = color
	label.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = MOVE_GIZMO_LENGTH_081 + 0.92
	axis_root.add_child(label)
	move_gizmo_axes_v042[name_value] = {"axis": axis.normalized(), "material": material, "root": axis_root}


func _pick_move_axis_v042(screen_pos: Vector2) -> Dictionary:
	if move_gizmo_root_v042 == null or not move_gizmo_root_v042.visible or camera == null or not is_instance_valid(selected_piece):
		return {}
	var special: Dictionary = _cross_slide_record_v074(selected_piece as RigidBody3D)
	var center: Vector3 = move_gizmo_root_v042.global_position
	var scale_value: float = move_gizmo_root_v042.scale.x
	var best: Dictionary = {}
	var best_distance: float = MOVE_GIZMO_PICK_PX_081
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = move_gizmo_axes_v042.get(name_value, {}) as Dictionary
		if data.is_empty():
			continue
		var root_value := data.get("root") as Node3D
		if root_value == null or not root_value.visible:
			continue
		var axis: Vector3 = data.get("axis", Vector3.ZERO) as Vector3
		if not special.is_empty() and name_value == "Y":
			var rod := special.get("rod") as RigidBody3D
			if is_instance_valid(rod):
				axis = _rod_axis_v020(rod).normalized()
		var positive: Vector3 = center + axis * MOVE_GIZMO_LENGTH_081 * scale_value
		var negative: Vector3 = center - axis * MOVE_GIZMO_LENGTH_081 * scale_value
		if camera.is_position_behind(positive) or camera.is_position_behind(negative):
			continue
		var screen_positive: Vector2 = camera.unproject_position(positive)
		var screen_negative: Vector2 = camera.unproject_position(negative)
		var screen_axis: Vector2 = screen_positive - screen_negative
		if screen_axis.length() < 32.0:
			continue
		var pick: Dictionary = _point_segment_pick_v035(screen_pos, screen_negative, screen_positive)
		var distance: float = float(pick.get("distance", 9999.0))
		if distance <= best_distance:
			best_distance = distance
			best = {"name": "SLIDE" if not special.is_empty() else name_value, "axis": axis, "screen_dir": screen_axis.normalized()}
	return best


# -----------------------------------------------------------------------------
# Top icon bar and confirmation dialogs.
# -----------------------------------------------------------------------------

func _icon_button_v081(glyph: String, tooltip: String, callback: Callable) -> Button:
	var button := _ui_button(glyph, callback, true)
	button.custom_minimum_size = Vector2(52.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 25)
	button.tooltip_text = tooltip
	return button


func _top_separator_v081() -> Label:
	var label := Label.new()
	label.text = "│"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 16.0
	label.add_theme_color_override("font_color", Color(0.46, 0.56, 0.66, 0.75))
	return label


func _install_top_bar_v081() -> void:
	if status_label == null:
		return
	var top_row := status_label.get_parent() as HBoxContainer
	if top_row == null:
		return
	var top_panel := top_row.get_parent() as PanelContainer
	if top_panel != null:
		top_panel.offset_bottom = 74.0
	status_label.visible = false
	for child_value in top_row.get_children():
		var child := child_value as Control
		if child != null:
			child.visible = false

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(left_spacer)
	top_select_v081 = _icon_button_v081("⌾", "Select one piece", _toggle_select_v020)
	top_center_v081 = _icon_button_v081("⌖", "Center selected piece / build", _center_view)
	top_undo_v081 = _icon_button_v081("↶", "Undo", _undo)
	top_redo_v081 = _icon_button_v081("↷", "Redo", _redo)
	top_simulate_v081 = _icon_button_v081("▶", "Simulate physics", _toggle_simulation)
	top_restore_v081 = _icon_button_v081("⟳", "Restore build pose", _reset_pose)
	top_restart_v081 = _icon_button_v081("⊘", "Restart project", _request_restart_v081)
	top_delete_v081 = _icon_button_v081("🗑", "Delete selected piece", _request_delete_v081)
	top_options_v081 = _icon_button_v081("⚙", "Options", _toggle_options)
	for value in [top_select_v081, top_center_v081]:
		top_row.add_child(value as Button)
	top_row.add_child(_top_separator_v081())
	for value in [top_undo_v081, top_redo_v081]:
		top_row.add_child(value as Button)
	top_row.add_child(_top_separator_v081())
	for value in [top_simulate_v081, top_restore_v081]:
		top_row.add_child(value as Button)
	top_row.add_child(_top_separator_v081())
	for value in [top_restart_v081, top_delete_v081]:
		top_row.add_child(value as Button)
	top_row.add_child(_top_separator_v081())
	top_row.add_child(top_options_v081)
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(right_spacer)

	restart_confirm_v081 = ConfirmationDialog.new()
	restart_confirm_v081.title = "Restart project?"
	restart_confirm_v081.dialog_text = "Restart the current project and clear this build?"
	add_child(restart_confirm_v081)
	restart_confirm_v081.get_ok_button().text = "Restart"
	restart_confirm_v081.get_cancel_button().text = "Cancel"
	restart_confirm_v081.confirmed.connect(_restart_build)
	delete_confirm_v081 = ConfirmationDialog.new()
	delete_confirm_v081.title = "Delete selected piece?"
	delete_confirm_v081.dialog_text = "Delete the currently selected piece?"
	add_child(delete_confirm_v081)
	delete_confirm_v081.get_ok_button().text = "Delete"
	delete_confirm_v081.get_cancel_button().text = "Cancel"
	delete_confirm_v081.confirmed.connect(_delete_selected)


func _request_restart_v081() -> void:
	if restart_confirm_v081 != null:
		restart_confirm_v081.popup_centered(Vector2i(430, 190))


func _request_delete_v081() -> void:
	if not is_instance_valid(selected_piece):
		_status("Select a piece before deleting")
		return
	if delete_confirm_v081 != null:
		delete_confirm_v081.popup_centered(Vector2i(430, 190))


# -----------------------------------------------------------------------------
# Left menu, Options order, Physics relocation and X buttons.
# -----------------------------------------------------------------------------

func _install_left_menu_v081() -> void:
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
		deselect_point_button_v032.visible = false
		deselect_point_button_v032.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode_panel_v032 != null:
		mode_panel_v032.offset_right = 194.0
		mode_panel_v032.offset_bottom = 390.0
	for value in [create_button_v032, rotate_button_v032, attach_button_v032]:
		var button := value as Button
		if button != null:
			button.custom_minimum_size = Vector2(166.0, 46.0)


func _open_help_from_options_v081() -> void:
	if options_panel != null:
		options_panel.visible = false
	if help_panel != null:
		help_panel.visible = true
	_sync_modal_blockers_v054()


func _install_options_order_v081() -> void:
	if options_panel == null:
		return
	var box: VBoxContainer = _find_first_vbox_v050(options_panel)
	if box == null:
		return
	if physics_button_v051 != null:
		physics_button_v051.text = "Physics"
	if builds_button_v050 != null:
		builds_button_v050.text = "Save & Load"
	options_help_v081 = _ui_button("Help", _open_help_from_options_v081, true)
	box.add_child(options_help_v081)
	if physics_button_v051 != null:
		box.move_child(physics_button_v051, mini(2, box.get_child_count() - 1))
	if builds_button_v050 != null:
		box.move_child(builds_button_v050, mini(3, box.get_child_count() - 1))
	box.move_child(options_help_v081, mini(4, box.get_child_count() - 1))
	if builds_panel_v050 != null:
		var build_title := _find_label_with_text_v081(builds_panel_v050, "SAVES & RECOVERY")
		if build_title != null:
			build_title.text = "SAVE & LOAD"


func _relocate_structure_rigidity_v081() -> void:
	if physics_box_v051 == null:
		return
	# Hide the legacy copy appended to Options by v0.5.11.
	var old_label: Label = physics_structure_rigidity_label_v066
	var old_slider: HSlider = physics_sliders_v054.get("Structure rigidity") as HSlider
	if old_label != null:
		old_label.visible = false
	if old_slider != null:
		old_slider.visible = false
	var options_box := _find_first_vbox_v050(options_panel)
	if options_box != null:
		for child_value in options_box.get_children():
			var child := child_value as Control
			if child is Label:
				var text_value: String = (child as Label).text
				if text_value == "STRUCTURE RIGIDITY" or "closed-loop SOCKET flex" in text_value:
					child.visible = false
	physics_sliders_v054.erase("Structure rigidity")

	var section := _section_label("STRUCTURE RIGIDITY")
	physics_box_v051.add_child(section)
	physics_structure_rigidity_label_v066 = _physics_slider_row_v050(
		physics_box_v051,
		"Structure rigidity",
		0.0,
		100.0,
		1.0,
		physics_structure_rigidity_v066,
		_on_structure_rigidity_v066
	)
	var slider: HSlider = physics_sliders_v054.get("Structure rigidity") as HSlider
	var explanation := Label.new()
	explanation.text = "Closed-loop SOCKET rigidity during SIMULATE. 100% is nearly rigid; 0% is loose."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 12)
	physics_box_v051.add_child(explanation)
	physics_box_v051.move_child(section, mini(1, physics_box_v051.get_child_count() - 1))
	physics_box_v051.move_child(physics_structure_rigidity_label_v066, mini(2, physics_box_v051.get_child_count() - 1))
	if slider != null:
		physics_box_v051.move_child(slider, mini(3, physics_box_v051.get_child_count() - 1))
	physics_box_v051.move_child(explanation, mini(4, physics_box_v051.get_child_count() - 1))
	_refresh_physics_labels_v050()


func _find_label_with_text_v081(node: Node, wanted: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text == wanted:
		return node as Label
	for child_value in node.get_children():
		var found := _find_label_with_text_v081(child_value as Node, wanted)
		if found != null:
			return found
	return null


func _add_menu_close_v081(panel: Control, callback: Callable) -> void:
	if panel == null:
		return
	var box: VBoxContainer = _find_first_vbox_v050(panel)
	if box == null:
		return
	var row := HBoxContainer.new()
	row.name = "CloseRowV081"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close := _ui_button("×", callback, true)
	close.custom_minimum_size = Vector2(42.0, 36.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.tooltip_text = "Close"
	row.add_child(close)
	box.add_child(row)
	box.move_child(row, 0)


func _install_menu_close_buttons_v081() -> void:
	_add_menu_close_v081(options_panel, _toggle_options)
	_add_menu_close_v081(help_panel, _toggle_help)
	_add_menu_close_v081(parts_panel_v050, _toggle_parts_panel_v050)
	_add_menu_close_v081(builds_panel_v050, _close_builds_panel_v050)
	_add_menu_close_v081(physics_panel_v051, _hide_physics_panel_v051)


# -----------------------------------------------------------------------------
# Bottom palette: compact icon navigation and live rod/connector rendering.
# -----------------------------------------------------------------------------

func _hide_palette_titles_v081(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		var child := child_value as Node
		if child is Label:
			var label := child as Label
			if label.text in ["PARTS / MODE", "PARTS / CONNECTION MODE"] or label.text.begins_with("Newest piece"):
				label.visible = false
		_hide_palette_titles_v081(child)


func _preview_shell_v081(is_rod: bool) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(128.0, 82.0)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 150)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var root3d := Node3D.new()
	viewport.add_child(root3d)
	var preview_camera := Camera3D.new()
	preview_camera.fov = 38.0
	root3d.add_child(preview_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	key.light_energy = 1.45
	root3d.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28.0, 145.0, 0.0)
	fill.light_energy = 0.72
	root3d.add_child(fill)
	if is_rod:
		bottom_rod_viewport_v081 = viewport
		bottom_rod_root_v081 = root3d
		bottom_rod_camera_v081 = preview_camera
	else:
		bottom_connector_viewport_v081 = viewport
		bottom_connector_root_v081 = root3d
		bottom_connector_camera_v081 = preview_camera
	return container


func _install_bottom_palette_v081() -> void:
	if bottom_panel == null or rod_label == null or connector_label == null:
		return
	bottom_panel.offset_top = -138.0
	_hide_palette_titles_v081(bottom_panel)
	var row := rod_label.get_parent() as HBoxContainer
	if row == null:
		return
	row.add_theme_constant_override("separation", 6)
	rod_label.visible = false
	connector_label.visible = false
	var rod_index: int = rod_label.get_index()
	bottom_rod_preview_v081 = _preview_shell_v081(true)
	row.add_child(bottom_rod_preview_v081)
	row.move_child(bottom_rod_preview_v081, rod_index)
	var connector_index: int = connector_label.get_index()
	bottom_connector_preview_v081 = _preview_shell_v081(false)
	row.add_child(bottom_connector_preview_v081)
	row.move_child(bottom_connector_preview_v081, connector_index)

	for child_value in row.get_children():
		var button := child_value as Button
		if button == null:
			continue
		match button.text:
			"◀R", "◀ Rod", "◀C", "◀ Conn":
				button.text = "◀"
				button.custom_minimum_size = Vector2(54.0, 54.0)
				button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			"R▶", "Rod ▶", "C▶", "Conn ▶":
				button.text = "▶"
				button.custom_minimum_size = Vector2(54.0, 54.0)
				button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if parts_button_v050 != null:
		parts_button_v050.text = "⚒"
		parts_button_v050.tooltip_text = "Parts"
		parts_button_v050.custom_minimum_size = Vector2(64.0, 64.0)
		parts_button_v050.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		parts_button_v050.add_theme_font_size_override("font_size", 25)
	if mode_button != null:
		mode_button.custom_minimum_size = Vector2(116.0, 64.0)
		mode_button.add_theme_font_size_override("font_size", 15)


func _clear_preview_root_v081(root3d: Node3D, keep_camera: Camera3D) -> void:
	if root3d == null:
		return
	for child_value in root3d.get_children():
		var child := child_value as Node
		if child == keep_camera or child is Light3D:
			continue
		root3d.remove_child(child)
		child.queue_free()


func _refresh_bottom_previews_v081(force: bool = false) -> void:
	if bottom_rod_root_v081 != null and (force or bottom_preview_rod_index_v081 != selected_rod_type):
		bottom_preview_rod_index_v081 = selected_rod_type
		_clear_preview_root_v081(bottom_rod_root_v081, bottom_rod_camera_v081)
		var index: int = clampi(selected_rod_type, 0, rod_defs.size() - 1)
		var definition := rod_defs[index] as Dictionary
		var rod := RigidBody3D.new()
		rod.freeze = true
		bottom_rod_root_v081.add_child(rod)
		var length_world: float = float(definition.get("actual_mm", 55.0)) / 10.0
		_rebuild_rod(rod, index, length_world)
		rod.rotation_degrees = Vector3(68.0, 0.0, 90.0)
		bottom_rod_camera_v081.position = Vector3(0.0, maxf(3.0, length_world * 0.22), maxf(6.8, length_world * 0.62))
		bottom_rod_camera_v081.look_at_from_position(bottom_rod_camera_v081.position, Vector3.ZERO, Vector3.UP)
	if bottom_connector_root_v081 != null and (force or bottom_preview_connector_index_v081 != selected_connector_type):
		bottom_preview_connector_index_v081 = selected_connector_type
		_clear_preview_root_v081(bottom_connector_root_v081, bottom_connector_camera_v081)
		var index: int = clampi(selected_connector_type, 0, connector_defs.size() - 1)
		var definition := connector_defs[index] as Dictionary
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
		bottom_connector_camera_v081.position = Vector3(0.0, 3.8, 7.0)
		bottom_connector_camera_v081.look_at_from_position(bottom_connector_camera_v081.position, Vector3.ZERO, Vector3.UP)


func _update_ui() -> void:
	super._update_ui()
	if status_label != null:
		status_label.visible = false
	if delete_button_v032 != null:
		delete_button_v032.visible = false
	if deselect_point_button_v032 != null:
		deselect_point_button_v032.visible = false
	if top_select_v081 != null:
		top_select_v081.disabled = simulating
		top_select_v081.self_modulate = Color(0.60, 0.94, 1.0) if select_armed_v020 else Color.WHITE
	if top_simulate_v081 != null:
		top_simulate_v081.self_modulate = Color(0.48, 1.0, 0.62) if simulating else Color.WHITE
	if top_delete_v081 != null:
		top_delete_v081.disabled = simulating or not is_instance_valid(selected_piece)
	if top_undo_v081 != null and top_undo_button != null:
		top_undo_v081.disabled = top_undo_button.disabled
	if top_redo_v081 != null and top_redo_button != null:
		top_redo_v081.disabled = top_redo_button.disabled
	_refresh_bottom_previews_v081(false)


func _process(delta: float) -> void:
	super._process(delta)
	_refresh_bottom_previews_v081(false)


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCAMERA: use the larger left joystick for forward/back/left/right and the larger UP/DOWN pads for elevation. Joystick and elevation can be held at the same time. One-finger open-space drag rotates/orbits the view. Touch pinch zoom and two-finger pan are disabled; desktop mouse-wheel zoom remains available.\n\nTOP BAR: ⌾ Select, ⌖ Center | ↶ Undo, ↷ Redo | ▶ Simulate, ⟳ Restore | ⊘ Restart, 🗑 Delete | ⚙ Options. Restart and Delete require confirmation. Select and Simulate highlight only while active.\n\nEDITOR: CREATE builds, TRANSFORM shows long translation arrows plus the compact rotation rings, and ATTACH exposes connection points. The small right Transform card is always open and contains only ITEM/WORLD, Roll and Reset Rotation.\n\nOPTIONS: Physics, Save & Load and Help are the first actions. Structure Rigidity is at the top of Physics and Reset Physics resets it together with the other physics values.\n\nBOTTOM BAR: Parts uses a tool icon, R/C cycling uses arrow-only buttons, the active rod and connector are shown as live procedural previews, and SOCKET / AXLE / CROSS remain named for clarity.\n\nAll SOCKET, AXLE, CROSS, O-Ring, save/load and simulation mechanics are retained." % VERSION_081


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