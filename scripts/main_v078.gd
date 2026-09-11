extends "res://scripts/main_v077.gd"

const VERSION_078 := "0.5.21"

var transform_space_button_v078: Button
var camera_joystick_pad_v078: Control


func _ready() -> void:
	super._ready()
	_apply_right_panel_state_v037()
	_update_transform_ui_v077()
	_layout_camera_controls_v077()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_078)
	_status("v0.5.21 ready — analog camera navigation, unified TRANSFORM and touch-safe scrolling are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_078, text]


# The v0.5.2 lineage made the old ROTATE/MOVE side panels mode-owned and can
# re-show them from inherited refresh paths. v0.5.21 retires those panels for
# good: the world/item gizmos are on the piece and the compact TRANSFORM panel
# contains only controls that cannot be expressed by the gizmos.
func _apply_right_panel_state_v037() -> void:
	right_panel_state_v037 = ""
	if rotation_panel != null:
		rotation_panel.visible = false
		rotation_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rotation_body != null:
		rotation_body.visible = false
	if move_panel != null:
		move_panel.visible = false
		move_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if move_body != null:
		move_body.visible = false
	if rotation_collapse_button != null:
		rotation_collapse_button.visible = false
	if move_collapse_button != null:
		move_collapse_button.visible = false


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

	transform_space_button_v078 = _ui_button("Space: ITEM", _toggle_transform_space_v051, true)
	transform_space_button_v078.custom_minimum_size.y = 38.0
	transform_body_v077.add_child(transform_space_button_v078)

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


func _update_transform_panel_layout_v077() -> void:
	if transform_panel_v077 == null or transform_body_v077 == null:
		return
	transform_body_v077.visible = transform_panel_open_v077
	if transform_toggle_v077 != null:
		transform_toggle_v077.text = "TRANSFORM ▾" if transform_panel_open_v077 else "TRANSFORM ▸"
	transform_panel_v077.offset_bottom = 348.0 if transform_panel_open_v077 else 124.0


func _update_transform_ui_v077() -> void:
	var transform_mode: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating
	if transform_panel_v077 != null:
		transform_panel_v077.visible = transform_mode and not _camera_controls_blocked_v077()
	if transform_space_button_v078 != null:
		transform_space_button_v078.text = "Space: %s" % ("ITEM" if transform_space_v051 == SPACE_ITEM_051 else "WORLD")
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
		var space_name: String = "ITEM" if transform_space_v051 == SPACE_ITEM_051 else "WORLD"
		if cross_slide:
			transform_hint_v077.text = "%s • drag SLIDE along this CROSS rod • rings rotate" % space_name
		elif axle_slide:
			transform_hint_v077.text = "%s • arrows move • rings rotate • Slide ± follows axle" % space_name
		else:
			transform_hint_v077.text = "%s • drag arrows to move • drag rings to rotate" % space_name
	_update_transform_panel_layout_v077()


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	super._set_editor_mode_v032(mode_value, report)
	_apply_right_panel_state_v037()


# Keep v0.5.2's useful direct-selection behavior in TRANSFORM. A tap on a piece
# selects it immediately; gizmo drags are intercepted before this path.
func _handle_tap(screen_pos: Vector2) -> void:
	if _any_modal_open_v054():
		return
	if editor_mode_v032 == EDITOR_ROTATE_032:
		var hit: Dictionary = _raycast_piece(screen_pos)
		var body: RigidBody3D = hit.get("collider") as RigidBody3D if not hit.is_empty() else null
		if is_instance_valid(body):
			_set_selected(body)
			_refresh_editor_overlay_v030()
			_refresh_gizmo_validity_v030()
			_status("Selected %s for TRANSFORM" % _piece_display_name(body))
		return
	super._handle_tap(screen_pos)


# Mirror the existing ITEM/WORLD transform-space rules onto the move arrows now
# that MOVE and ROTATE share one mode. Rotation rings are already updated by the
# inherited ITEM/WORLD process because TRANSFORM keeps the old ROTATE mode id.
func _refresh_transform_gizmos_v077() -> void:
	if move_gizmo_root_v042 == null:
		return
	var show: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and not _camera_controls_blocked_v077()
	move_gizmo_root_v042.visible = show
	if not show:
		return
	move_gizmo_root_v042.global_position = selected_piece.global_position
	var scale_value: float = clampf(camera_distance / 19.0, 0.62, 2.10)
	move_gizmo_root_v042.scale = Vector3.ONE * scale_value

	var special: Dictionary = _cross_slide_record_v074(selected_piece as RigidBody3D)
	var x_data := move_gizmo_axes_v042.get("X", {}) as Dictionary
	var y_data := move_gizmo_axes_v042.get("Y", {}) as Dictionary
	var z_data := move_gizmo_axes_v042.get("Z", {}) as Dictionary
	var x_root := x_data.get("root") as Node3D
	var y_root := y_data.get("root") as Node3D
	var z_root := z_data.get("root") as Node3D
	if not special.is_empty():
		var rod := special.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			return
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		move_gizmo_root_v042.global_basis = Basis.IDENTITY
		y_data["axis"] = axis
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
		return

	var mobility: Dictionary = _mobility_v051()
	var kind: String = str(mobility.get("kind", "none"))
	var constrained: bool = transform_space_v051 == SPACE_ITEM_051 and kind in ["cross", "axle", "o_ring"]
	var free_item: bool = transform_space_v051 == SPACE_ITEM_051 and kind == "free"
	var basis_value: Basis = Basis.IDENTITY
	if free_item:
		basis_value = selected_piece.global_transform.basis.orthonormalized()
	elif constrained:
		basis_value = _item_basis_for_axis_v051(mobility.get("axis", Vector3.UP) as Vector3)
	move_gizmo_root_v042.global_basis = basis_value if transform_space_v051 == SPACE_ITEM_051 else Basis.IDENTITY
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = move_gizmo_axes_v042.get(name_value, {}) as Dictionary
		if data.is_empty():
			continue
		var local_axis: Vector3 = Vector3.RIGHT if name_value == "X" else (Vector3.UP if name_value == "Y" else Vector3.BACK)
		data["axis"] = ((basis_value * local_axis).normalized() if transform_space_v051 == SPACE_ITEM_051 else local_axis)
		var root_value := data.get("root") as Node3D
		if is_instance_valid(root_value):
			root_value.visible = not constrained or name_value == "Y"
		if name_value == "Y" and is_instance_valid(root_value):
			_set_move_axis_label_v074(root_value, "Y")


# A PanelContainer owns its direct child's rect, so the first candidate could not
# actually slide its joystick knob. Put one free-position Control inside the
# styled container and move the knob inside that Control instead.
func _camera_noop_v078() -> void:
	pass


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

	camera_joystick_pad_v078 = Control.new()
	camera_joystick_pad_v078.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_joystick_pad_v078.custom_minimum_size = Vector2(CAMERA_JOYSTICK_SIZE_077, CAMERA_JOYSTICK_SIZE_077)
	camera_joystick_v077.add_child(camera_joystick_pad_v078)

	camera_joystick_knob_v077 = PanelContainer.new()
	camera_joystick_knob_v077.custom_minimum_size = Vector2(CAMERA_JOYSTICK_KNOB_077, CAMERA_JOYSTICK_KNOB_077)
	camera_joystick_knob_v077.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_joystick_knob_v077.add_theme_stylebox_override("panel", _round_panel_style_v077(Color(0.16, 0.55, 0.78, 0.78), 24))
	camera_joystick_pad_v078.add_child(camera_joystick_knob_v077)

	camera_up_button_v077 = _ui_button("▲\nUP", _camera_noop_v078, true)
	camera_down_button_v077 = _ui_button("▼\nDOWN", _camera_noop_v078, true)
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


# Keep elevation buttons below the optional transform card, never under it. The
# joystick sits immediately right of the condensed left toolbar and immediately
# above the bottom Parts/Mode strip.
func _layout_camera_controls_v077() -> void:
	if camera_joystick_v077 == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var left_edge: float = 210.0 if mode_panel_v032 != null and mode_panel_v032.visible else 18.0
	var bottom_reserved: float = 108.0
	if bottom_panel != null and bottom_panel.visible:
		bottom_reserved = maxf(100.0, -bottom_panel.offset_top + 8.0)
	var joystick_y: float = maxf(82.0, viewport_size.y - bottom_reserved - CAMERA_JOYSTICK_SIZE_077 - 16.0)
	camera_joystick_v077.position = Vector2(left_edge + 10.0, joystick_y)
	camera_joystick_v077.size = Vector2(CAMERA_JOYSTICK_SIZE_077, CAMERA_JOYSTICK_SIZE_077)
	if camera_joystick_pad_v078 != null:
		camera_joystick_pad_v078.size = Vector2(CAMERA_JOYSTICK_SIZE_077, CAMERA_JOYSTICK_SIZE_077)
	_reset_joystick_knob_v077(false)

	if camera_up_button_v077 != null and camera_down_button_v077 != null:
		var x_value: float = viewport_size.x - 76.0
		var bottom_limit: float = viewport_size.y - bottom_reserved - 10.0
		var top_limit: float = 366.0 if transform_panel_open_v077 and editor_mode_v032 == EDITOR_ROTATE_032 else 188.0
		var pair_height: float = 128.0
		var desired_top: float = (top_limit + bottom_limit - pair_height) * 0.5
		var pair_top: float = clampf(desired_top, top_limit, maxf(top_limit, bottom_limit - pair_height))
		camera_up_button_v077.position = Vector2(x_value, pair_top)
		camera_up_button_v077.size = Vector2(62.0, 62.0)
		camera_down_button_v077.position = Vector2(x_value, pair_top + 68.0)
		camera_down_button_v077.size = Vector2(62.0, 62.0)


func _reset_joystick_knob_v077(clear_value: bool = true) -> void:
	if clear_value:
		camera_joystick_value_v077 = Vector2.ZERO
	if camera_joystick_knob_v077 == null:
		return
	var center := Vector2(CAMERA_JOYSTICK_SIZE_077, CAMERA_JOYSTICK_SIZE_077) * 0.5
	camera_joystick_knob_v077.position = center - Vector2.ONE * (CAMERA_JOYSTICK_KNOB_077 * 0.5)
	camera_joystick_knob_v077.size = Vector2(CAMERA_JOYSTICK_KNOB_077, CAMERA_JOYSTICK_KNOB_077)


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCAMERA: use the translucent left joystick for full analog forward/back/left/right movement relative to the current view. Hold UP/DOWN at the right edge for elevation. Drag open 3D space to look/orbit; pinch zoom and two-finger pan remain available. Movement translates the orbit target with the camera, so the camera never starts orbiting an old point behind you.\n\nCENTER: tap Center to focus the selected piece; with nothing selected it frames the whole build. Hold Center for a full camera heading/pitch/distance reset.\n\nEDITOR: CREATE builds, TRANSFORM combines translation arrows and 45° rotation rings, and ATTACH exposes connection points. MOVE is no longer a separate mode.\n\nTRANSFORM PANEL: switch ITEM/WORLD space here, plus use mount Roll/Reset and axle Slide. Duplicate X/Y/Z right-panel buttons are removed because the on-piece gizmos already provide them.\n\nTOUCH MENUS: scrollable menus use a larger drag deadzone and pass button gestures to their ScrollContainer so releasing after a scroll no longer activates the card under your finger.\n\nAll SOCKET, AXLE, CROSS, O-Ring, save/load and simulation behavior is retained." % VERSION_078
