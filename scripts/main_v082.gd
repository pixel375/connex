extends "res://scripts/main_v081.gd"

const VERSION_082 := "0.5.23"
const JOYSTICK_EXTRA_RIGHT_082 := 42.0
const TOP_ICON_FONT_SIZE_082 := 32
const BOTTOM_ICON_FONT_SIZE_082 := 30
const TOP_BG_INACTIVE_V082 := Color(0.20, 0.23, 0.27, 0.98)
const TOP_BG_HOVER_V082 := Color(0.27, 0.30, 0.35, 0.98)
const TOP_BG_PRESSED_V082 := Color(0.14, 0.17, 0.20, 0.98)
const TOP_BG_ACTIVE_V082 := Color(0.12, 0.47, 0.72, 0.98)
const TOP_BG_ACTIVE_HOVER_V082 := Color(0.16, 0.56, 0.82, 0.98)

var menu_close_layer_v082: CanvasLayer
var menu_close_entries_v082: Array = []


func _ready() -> void:
	super._ready()
	transform_panel_hidden_v081 = false
	_install_fixed_menu_close_buttons_v082()
	_fix_left_deselect_v082()
	_bump_bottom_icon_sizes_v082()
	call_deferred("_finalize_v082_ui")
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_082)
	_status("v0.5.23 ready — fixed menu close buttons, neutral toolbar icons, permanent Transform card and reliable ATTACH deselection are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_082, text]


func _finalize_v082_ui() -> void:
	_remove_status_frame_v082()
	_hide_inline_menu_close_rows_v082(self)
	_fix_left_deselect_v082()
	_refresh_top_toolbar_v081()
	_bump_bottom_icon_sizes_v082()
	_sync_menu_close_buttons_v082()
	_layout_camera_controls_v077()


# -----------------------------------------------------------------------------
# Transform card: permanent while TRANSFORM mode is active; no X/hide affordance.
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
	transform_panel_v077.offset_bottom = 228.0
	transform_panel_v077.add_theme_stylebox_override("panel", _panel_style(0.94, 11))
	layer.add_child(transform_panel_v077)

	transform_body_v077 = VBoxContainer.new()
	transform_body_v077.add_theme_constant_override("separation", 4)
	transform_body_v077.visible = true
	transform_panel_v077.add_child(transform_body_v077)

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

	transform_toggle_v077 = null
	transform_hint_v077 = null
	transform_slide_minus_v077 = null
	transform_slide_plus_v077 = null
	transform_close_button_v081 = null
	transform_panel_hidden_v081 = false
	transform_panel_open_v077 = true


func _close_transform_panel_v081() -> void:
	# v0.5.23 intentionally makes this card non-hideable.
	transform_panel_hidden_v081 = false
	if transform_panel_v077 != null:
		transform_panel_v077.visible = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and not _camera_controls_blocked_v077()


func _update_transform_panel_layout_v077() -> void:
	if transform_panel_v077 == null:
		return
	if transform_body_v077 != null:
		transform_body_v077.visible = true
	transform_panel_v077.offset_left = -190.0
	transform_panel_v077.offset_right = -8.0
	transform_panel_v077.offset_top = 82.0
	transform_panel_v077.offset_bottom = 228.0


func _update_transform_ui_v077() -> void:
	var transform_mode: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating
	transform_panel_hidden_v081 = false
	if transform_panel_v077 != null:
		transform_panel_v077.visible = transform_mode and not _camera_controls_blocked_v077()
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


# -----------------------------------------------------------------------------
# Camera placement: keep v0.5.22 sizing but move the joystick farther right.
# -----------------------------------------------------------------------------

func _layout_camera_controls_v077() -> void:
	super._layout_camera_controls_v077()
	if camera_joystick_v077 == null:
		return
	var desired_x: float = camera_joystick_v077.position.x + JOYSTICK_EXTRA_RIGHT_082
	if mode_panel_v032 != null and mode_panel_v032.visible:
		desired_x = maxf(desired_x, mode_panel_v032.get_global_rect().end.x + 54.0)
	camera_joystick_v077.position.x = desired_x


# -----------------------------------------------------------------------------
# Top toolbar: larger glyphs and neutral grey buttons unless Select/Play is active.
# -----------------------------------------------------------------------------

func _top_button_style_v082(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _style_top_icon_v081(button: Button, glyph: String, tooltip: String) -> void:
	super._style_top_icon_v081(button, glyph, tooltip)
	if button == null:
		return
	button.custom_minimum_size = Vector2(56.0, 56.0)
	button.add_theme_font_size_override("font_size", TOP_ICON_FONT_SIZE_082)
	button.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _set_top_button_state_v082(button: Button, active: bool = false) -> void:
	if button == null:
		return
	button.self_modulate = Color.WHITE
	button.add_theme_stylebox_override("normal", _top_button_style_v082(TOP_BG_ACTIVE_V082 if active else TOP_BG_INACTIVE_V082))
	button.add_theme_stylebox_override("hover", _top_button_style_v082(TOP_BG_ACTIVE_HOVER_V082 if active else TOP_BG_HOVER_V082))
	button.add_theme_stylebox_override("pressed", _top_button_style_v082(TOP_BG_ACTIVE_V082 if active else TOP_BG_PRESSED_V082))
	button.add_theme_stylebox_override("focus", _top_button_style_v082(TOP_BG_ACTIVE_V082 if active else TOP_BG_INACTIVE_V082))
	var disabled_color := Color(TOP_BG_INACTIVE_V082.r, TOP_BG_INACTIVE_V082.g, TOP_BG_INACTIVE_V082.b, 0.46)
	button.add_theme_stylebox_override("disabled", _top_button_style_v082(disabled_color))
	button.set_meta("v082_active", active)


func _refresh_top_toolbar_v081() -> void:
	super._refresh_top_toolbar_v081()
	_set_top_button_state_v082(select_button_v020, select_armed_v020)
	_set_top_button_state_v082(top_center_button, false)
	_set_top_button_state_v082(top_undo_button, false)
	_set_top_button_state_v082(top_redo_button, false)
	_set_top_button_state_v082(top_simulate_button, simulating)
	_set_top_button_state_v082(top_restore_button, false)
	_set_top_button_state_v082(top_restart_button, false)
	_set_top_button_state_v082(top_delete_button_v081, false)
	_set_top_button_state_v082(options_button, false)


func _nearest_panel_ancestor_v082(node: Node) -> PanelContainer:
	if node == null:
		return null
	var current := node.get_parent()
	while current != null and current != self:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null


func _remove_status_frame_v082() -> void:
	if status_label == null:
		return
	status_label.hide()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status_panel := _nearest_panel_ancestor_v082(status_label)
	var toolbar_panel := _nearest_panel_ancestor_v082(select_button_v020)
	if status_panel != null and status_panel != toolbar_panel:
		status_panel.hide()
		status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif status_panel != null:
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color(0, 0, 0, 0)
		status_panel.add_theme_stylebox_override("panel", transparent)


# -----------------------------------------------------------------------------
# Menu close controls: fixed overlay buttons anchored to the frame, not scroll body.
# -----------------------------------------------------------------------------

func _menu_close_style_v082(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _hide_inline_menu_close_rows_v082(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		var child := child_value as Node
		if child is Button:
			var button := child as Button
			if button.text in ["✕", "×"] and button.tooltip_text == "Close":
				var row := button.get_parent()
				if row is HBoxContainer:
					(row as HBoxContainer).hide()
					(row as HBoxContainer).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hide_inline_menu_close_rows_v082(child)


func _register_menu_close_v082(panel: Control, callback: Callable) -> void:
	if panel == null or menu_close_layer_v082 == null:
		return
	var button := Button.new()
	button.text = "×"
	button.tooltip_text = "Close"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(34.0, 34.0)
	button.size = Vector2(34.0, 34.0)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _menu_close_style_v082(Color(0.20, 0.23, 0.27, 0.98)))
	button.add_theme_stylebox_override("hover", _menu_close_style_v082(Color(0.34, 0.37, 0.42, 0.98)))
	button.add_theme_stylebox_override("pressed", _menu_close_style_v082(Color(0.13, 0.15, 0.18, 0.98)))
	button.pressed.connect(callback)
	menu_close_layer_v082.add_child(button)
	menu_close_entries_v082.append({"panel": panel, "button": button})


func _install_fixed_menu_close_buttons_v082() -> void:
	_hide_inline_menu_close_rows_v082(self)
	if menu_close_layer_v082 == null:
		menu_close_layer_v082 = CanvasLayer.new()
		menu_close_layer_v082.layer = 40
		add_child(menu_close_layer_v082)
	menu_close_entries_v082.clear()
	_register_menu_close_v082(options_panel, _toggle_options)
	_register_menu_close_v082(help_panel, _toggle_help)
	_register_menu_close_v082(parts_panel_v050, _toggle_parts_panel_v050)
	_register_menu_close_v082(builds_panel_v050, _close_builds_panel_v050)
	_register_menu_close_v082(physics_panel_v051, _hide_physics_panel_v051)
	_sync_menu_close_buttons_v082()


func _sync_menu_close_buttons_v082() -> void:
	for entry_value in menu_close_entries_v082:
		var entry: Dictionary = entry_value as Dictionary
		var panel := entry.get("panel") as Control
		var button := entry.get("button") as Button
		if panel == null or button == null:
			continue
		button.visible = panel.visible
		if not panel.visible:
			continue
		var rect: Rect2 = panel.get_global_rect()
		button.position = rect.position + Vector2(maxf(0.0, rect.size.x - button.size.x - 7.0), 7.0)


# -----------------------------------------------------------------------------
# ATTACH selection: one Deselect button, point-first semantics, background clears point.
# -----------------------------------------------------------------------------

func _fix_left_deselect_v082() -> void:
	if deselect_piece_button_v039 != null:
		deselect_piece_button_v039.text = "Deselect"
		_replace_pressed_callback_v081(deselect_piece_button_v039, _deselect_context_v082)
	if deselect_point_button_v032 != null:
		deselect_point_button_v032.hide()
		deselect_point_button_v032.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _deselect_context_v082(report: bool = true) -> void:
	if simulating:
		if report:
			_status("Return to BUILD before changing selection")
		return
	if not attach_point_selected_v032.is_empty():
		_deselect_attach_point_v032(report)
		_update_ui()
		return
	_deselect_piece_v039(report)


func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	if deselect_point_button_v032 != null:
		deselect_point_button_v032.hide()
		deselect_point_button_v032.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _handle_tap(screen_pos: Vector2) -> void:
	if not simulating and not _any_modal_open_v054() and editor_mode_v032 == EDITOR_ATTACH_032 and not select_armed_v020 and not attach_point_selected_v032.is_empty():
		if not _tap_has_world_target_v039(screen_pos):
			_deselect_attach_point_v032(true)
			_update_ui()
			return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# Final UI refresh and icon sizing.
# -----------------------------------------------------------------------------

func _bump_bottom_icon_sizes_v082() -> void:
	if parts_button_v050 != null:
		parts_button_v050.add_theme_font_size_override("font_size", 32)
	if rod_label == null or rod_label.get_parent() == null:
		return
	var row := rod_label.get_parent() as HBoxContainer
	if row == null:
		return
	for child_value in row.get_children():
		var button := child_value as Button
		if button != null and button.text in ["←", "→"]:
			button.add_theme_font_size_override("font_size", BOTTOM_ICON_FONT_SIZE_082)


func _update_ui() -> void:
	super._update_ui()
	_fix_left_deselect_v082()
	if deselect_piece_button_v039 != null:
		var nothing_to_clear: bool = not is_instance_valid(selected_piece) and attach_point_selected_v032.is_empty()
		deselect_piece_button_v039.disabled = simulating or nothing_to_clear
	_refresh_top_toolbar_v081()
	_bump_bottom_icon_sizes_v082()
	_remove_status_frame_v082()
	_sync_menu_close_buttons_v082()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_menu_close_buttons_v082()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCAMERA: use the lower-left joystick for horizontal movement and hold UP/DOWN with another finger for elevation. The joystick is shifted farther right to clear the left editor menu. One-finger open-space drag orbits; touch pinch zoom and two-finger pan remain disabled.\n\nATTACH: the left Deselect button now clears an active attachment point first, otherwise it clears the selected piece. The obsolete separate Deselect Point control stays hidden. Tapping empty background while an attachment point is selected clears that point without clearing the piece.\n\nTRANSFORM: translation arrows remain larger than rotation rings. The right Transform card is permanently available while Transform mode is active and no longer has an X/hide button.\n\nTOP BAR: icon buttons are larger. Select and Simulate are grey while inactive and blue only while active; Delete and all ordinary actions stay grey. The old status strip/frame is removed.\n\nMENUS: Options, Help, Parts, Save & Load and Physics use compact fixed X buttons in the upper-right frame, outside scrolling content.\n\nSOCKET, AXLE, CROSS, O-Ring, save/load and simulation mechanics are otherwise unchanged." % VERSION_082


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
	if _compare_versions_v021(latest, VERSION_082) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_082)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_082, latest])
