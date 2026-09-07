extends "res://scripts/main_v014.gd"

const VERSION_015 = "0.1.5"
const SETTINGS_PATH = "user://connex_settings.cfg"
const O_RING_OUTER_RADIUS = 0.47
const O_RING_INNER_RADIUS = 0.285
const O_RING_HEIGHT = 0.20
const EDIT_MOVE_STEP = 0.55
const EDIT_AXLE_STEP = 0.50
const ROT_STEP = PI / 4.0

var o_ring_index: int = -1
var o_ring_stops: Array = []
var edit_mode: bool = false

var top_mode_button: Button
var options_button: Button
var top_undo_button: Button
var top_redo_button: Button
var top_simulate_button: Button
var top_restore_button: Button
var top_restart_button: Button
var top_center_button: Button

var rotation_panel: PanelContainer
var rotation_body: VBoxContainer
var rotation_collapse_button: Button
var rot_x_minus: Button
var rot_x_plus: Button
var rot_y_minus: Button
var rot_y_plus: Button
var rot_z_minus: Button
var rot_z_plus: Button
var rot_mount_minus: Button
var rot_mount_plus: Button
var rot_reset: Button

var move_panel: PanelContainer
var move_body: VBoxContainer
var move_collapse_button: Button
var move_left_button: Button
var move_right_button: Button
var move_forward_button: Button
var move_back_button: Button
var move_up_button: Button
var move_down_button: Button
var axle_minus_button: Button
var axle_plus_button: Button

var options_panel: PanelContainer
var options_sensitivity_label: Label
var reverse_orbit_x_check: CheckButton
var reverse_orbit_y_check: CheckButton
var reverse_pan_x_check: CheckButton
var reverse_pan_y_check: CheckButton
var show_grid_check: CheckButton
var sensitivity_slider: HSlider

var reverse_orbit_x: bool = false
var reverse_orbit_y: bool = false
var reverse_pan_x: bool = false
var reverse_pan_y: bool = false
var show_grid: bool = true
var camera_sensitivity: float = 1.0
var rotation_collapsed: bool = false
var move_collapsed: bool = true

var vivid_selection_material: StandardMaterial3D


func _ready() -> void:
	if not _has_o_ring_definition():
		connector_defs.append({
			"name": "O-Ring Stop",
			"slots": [],
			"color": Color("343b44"),
			"mass": 0.035,
			"special": "o_ring"
		})
	o_ring_index = connector_defs.size() - 1
	_load_settings()
	super._ready()
	_apply_saved_view_settings()
	_status("CREATE mode — choose a rod/connector below, then tap valid connection points. Switch to EDIT to select and manipulate pieces.")


func _has_o_ring_definition() -> bool:
	for def_value in connector_defs:
		var definition: Dictionary = def_value as Dictionary
		if str(definition.get("special", "")) == "o_ring":
			return true
	return false


# -----------------------------------------------------------------------------
# Persistent options
# -----------------------------------------------------------------------------

func _load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	reverse_orbit_x = bool(cfg.get_value("controls", "reverse_orbit_x", false))
	reverse_orbit_y = bool(cfg.get_value("controls", "reverse_orbit_y", false))
	reverse_pan_x = bool(cfg.get_value("controls", "reverse_pan_x", false))
	reverse_pan_y = bool(cfg.get_value("controls", "reverse_pan_y", false))
	camera_sensitivity = clampf(float(cfg.get_value("controls", "camera_sensitivity", 1.0)), 0.45, 2.0)
	show_grid = bool(cfg.get_value("view", "show_grid", true))
	rotation_collapsed = bool(cfg.get_value("ui", "rotation_collapsed", false))
	move_collapsed = bool(cfg.get_value("ui", "move_collapsed", true))


func _save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "reverse_orbit_x", reverse_orbit_x)
	cfg.set_value("controls", "reverse_orbit_y", reverse_orbit_y)
	cfg.set_value("controls", "reverse_pan_x", reverse_pan_x)
	cfg.set_value("controls", "reverse_pan_y", reverse_pan_y)
	cfg.set_value("controls", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("view", "show_grid", show_grid)
	cfg.set_value("ui", "rotation_collapsed", rotation_collapsed)
	cfg.set_value("ui", "move_collapsed", move_collapsed)
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		_status("Could not save options (%s)" % error_string(err))


func _apply_saved_view_settings() -> void:
	var grid: Node = get_node_or_null("HugeGrid")
	if grid != null:
		grid.visible = show_grid
	_refresh_options_controls()
	_refresh_side_panels()


func _on_reverse_orbit_x(value: bool) -> void:
	reverse_orbit_x = value
	_save_settings()


func _on_reverse_orbit_y(value: bool) -> void:
	reverse_orbit_y = value
	_save_settings()


func _on_reverse_pan_x(value: bool) -> void:
	reverse_pan_x = value
	_save_settings()


func _on_reverse_pan_y(value: bool) -> void:
	reverse_pan_y = value
	_save_settings()


func _on_show_grid(value: bool) -> void:
	show_grid = value
	var grid: Node = get_node_or_null("HugeGrid")
	if grid != null:
		grid.visible = show_grid
	_save_settings()


func _on_sensitivity_changed(value: float) -> void:
	camera_sensitivity = clampf(value, 0.45, 2.0)
	if options_sensitivity_label != null:
		options_sensitivity_label.text = "Camera sensitivity: %.1fx" % camera_sensitivity
	_save_settings()


# -----------------------------------------------------------------------------
# Polished UI
# -----------------------------------------------------------------------------

func _panel_style(alpha: float = 0.94, radius: int = 12, border_alpha: float = 0.28) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.085, alpha)
	style.border_color = Color(0.24, 0.55, 0.78, border_alpha)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _button_style(color: Color, radius: int = 8) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = Color(0.35, 0.63, 0.85, 0.20)
	style.set_border_width_all(1)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _polish_button(button: Button, accent: bool = false) -> Button:
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(72, 44)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.095, 0.115, 0.145, 0.96)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.20, 0.27, 0.98)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.34, 0.53, 0.98)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.07, 0.075, 0.085, 0.72)))
	if accent:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.30, 0.48, 0.98)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.38, 0.60, 1.0)))
	return button


func _ui_button(text: String, callback: Callable, accent: bool = false) -> Button:
	return _polish_button(_make_ui_button(text, callback), accent)


func _section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.62, 0.76, 0.88))
	return label


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	# Top utility bar — always visible.
	var top: PanelContainer = PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 8.0
	top.offset_right = -8.0
	top.offset_top = 8.0
	top.offset_bottom = 62.0
	top.add_theme_stylebox_override("panel", _panel_style(0.96, 11))
	layer.add_child(top)
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 5)
	top.add_child(top_row)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	top_row.add_child(status_label)

	top_mode_button = _ui_button("CREATE", _toggle_create_edit, true)
	top_mode_button.custom_minimum_size.x = 105
	top_row.add_child(top_mode_button)
	top_undo_button = _ui_button("Undo", _undo)
	top_row.add_child(top_undo_button)
	top_redo_button = _ui_button("Redo", _redo)
	redo_button = top_redo_button
	top_row.add_child(top_redo_button)
	top_simulate_button = _ui_button("SIMULATE", _toggle_simulation, true)
	simulate_button = top_simulate_button
	top_row.add_child(top_simulate_button)
	top_restore_button = _ui_button("Restore", _reset_pose)
	top_row.add_child(top_restore_button)
	top_restart_button = _ui_button("Restart", _restart_build)
	top_row.add_child(top_restart_button)
	top_center_button = _ui_button("Center", _center_view)
	top_row.add_child(top_center_button)
	options_button = _ui_button("Options", _toggle_options)
	top_row.add_child(options_button)
	var help_button: Button = _ui_button("?", _toggle_help)
	help_button.custom_minimum_size.x = 48
	top_row.add_child(help_button)

	# Bottom part palette — non-collapsible.
	bottom_panel = PanelContainer.new()
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 8.0
	bottom_panel.offset_right = -8.0
	bottom_panel.offset_top = -108.0
	bottom_panel.offset_bottom = -8.0
	bottom_panel.add_theme_stylebox_override("panel", _panel_style(0.96, 12))
	bottom_panel.visible = true
	layer.add_child(bottom_panel)
	var bottom_box: VBoxContainer = VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 4)
	bottom_panel.add_child(bottom_box)
	var palette_title: Label = _section_label("PARTS / CONNECTION MODE")
	bottom_box.add_child(palette_title)
	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 5)
	bottom_box.add_child(bottom_row)

	bottom_row.add_child(_ui_button("◀ Rod", _prev_rod))
	rod_label = _make_ui_label()
	rod_label.custom_minimum_size = Vector2(150, 44)
	rod_label.add_theme_font_size_override("font_size", 16)
	bottom_row.add_child(rod_label)
	bottom_row.add_child(_ui_button("Rod ▶", _next_rod))
	bottom_row.add_child(_ui_button("◀ Conn", _prev_connector))
	connector_label = _make_ui_label()
	connector_label.custom_minimum_size = Vector2(175, 44)
	connector_label.add_theme_font_size_override("font_size", 16)
	bottom_row.add_child(connector_label)
	bottom_row.add_child(_ui_button("Conn ▶", _next_connector))
	mode_button = _ui_button("SOCKET", _cycle_mode, true)
	mode_button.custom_minimum_size.x = 125
	bottom_row.add_child(mode_button)

	var palette_hint: Label = Label.new()
	palette_hint.text = "CREATE places parts • EDIT selects/manipulates • O-Ring Stop is in the connector list and is placed directly on axle rods"
	palette_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	palette_hint.add_theme_font_size_override("font_size", 12)
	palette_hint.add_theme_color_override("font_color", Color(0.64, 0.70, 0.78))
	bottom_box.add_child(palette_hint)

	# Right rotation panel — collapsible.
	rotation_panel = PanelContainer.new()
	rotation_panel.anchor_left = 1.0
	rotation_panel.anchor_right = 1.0
	rotation_panel.offset_left = -226.0
	rotation_panel.offset_right = -8.0
	rotation_panel.offset_top = 76.0
	rotation_panel.offset_bottom = 438.0
	rotation_panel.add_theme_stylebox_override("panel", _panel_style(0.95, 12))
	layer.add_child(rotation_panel)
	var rotation_outer: VBoxContainer = VBoxContainer.new()
	rotation_outer.add_theme_constant_override("separation", 5)
	rotation_panel.add_child(rotation_outer)
	rotation_collapse_button = _ui_button("ROTATE ▾", _toggle_rotation_panel, true)
	rotation_outer.add_child(rotation_collapse_button)
	rotation_body = VBoxContainer.new()
	rotation_body.add_theme_constant_override("separation", 5)
	rotation_outer.add_child(rotation_body)
	rotation_body.add_child(_section_label("45° STEPS • SELECT CONNECTOR"))
	var rx: HBoxContainer = HBoxContainer.new()
	rx.add_theme_constant_override("separation", 4)
	rotation_body.add_child(rx)
	rot_x_minus = _ui_button("X −", func() -> void: _rotate_selected_axis(Vector3.RIGHT, -1, "X−"))
	rot_x_plus = _ui_button("X +", func() -> void: _rotate_selected_axis(Vector3.RIGHT, 1, "X+"))
	rx.add_child(rot_x_minus)
	rx.add_child(rot_x_plus)
	var ry: HBoxContainer = HBoxContainer.new()
	ry.add_theme_constant_override("separation", 4)
	rotation_body.add_child(ry)
	rot_y_minus = _ui_button("Y −", func() -> void: _rotate_selected_axis(Vector3.UP, -1, "Y−"))
	rot_y_plus = _ui_button("Y +", func() -> void: _rotate_selected_axis(Vector3.UP, 1, "Y+"))
	ry.add_child(rot_y_minus)
	ry.add_child(rot_y_plus)
	var rz: HBoxContainer = HBoxContainer.new()
	rz.add_theme_constant_override("separation", 4)
	rotation_body.add_child(rz)
	rot_z_minus = _ui_button("Z −", func() -> void: _rotate_selected_axis(Vector3.BACK, -1, "Z−"))
	rot_z_plus = _ui_button("Z +", func() -> void: _rotate_selected_axis(Vector3.BACK, 1, "Z+"))
	rz.add_child(rot_z_minus)
	rz.add_child(rot_z_plus)
	rotation_body.add_child(_section_label("AROUND REAL MOUNT AXIS"))
	var rm: HBoxContainer = HBoxContainer.new()
	rm.add_theme_constant_override("separation", 4)
	rotation_body.add_child(rm)
	rot_mount_minus = _ui_button("Mount ⟲", func() -> void: _rotate_selected_mount(-1))
	rot_mount_plus = _ui_button("Mount ⟳", func() -> void: _rotate_selected_mount(1))
	rm.add_child(rot_mount_minus)
	rm.add_child(rot_mount_plus)
	rot_reset = _ui_button("Reset Rotation", _reset_selected_rotation_v015)
	rotation_body.add_child(rot_reset)
	var delete_button_local: Button = _ui_button("Delete Selected", _delete_selected)
	delete_button = delete_button_local
	rotation_body.add_child(delete_button_local)

	# Left move panel — available in EDIT; collapsed by default.
	move_panel = PanelContainer.new()
	move_panel.offset_left = 8.0
	move_panel.offset_right = 226.0
	move_panel.offset_top = 76.0
	move_panel.offset_bottom = 438.0
	move_panel.add_theme_stylebox_override("panel", _panel_style(0.95, 12))
	layer.add_child(move_panel)
	var move_outer: VBoxContainer = VBoxContainer.new()
	move_outer.add_theme_constant_override("separation", 5)
	move_panel.add_child(move_outer)
	move_collapse_button = _ui_button("MOVE ▾", _toggle_move_panel, true)
	move_outer.add_child(move_collapse_button)
	move_body = VBoxContainer.new()
	move_body.add_theme_constant_override("separation", 5)
	move_outer.add_child(move_body)
	move_body.add_child(_section_label("MOVE FIXED COMPONENT"))
	move_forward_button = _ui_button("↑ Forward", func() -> void: _move_screen_direction(0, 1))
	move_body.add_child(move_forward_button)
	var move_lr: HBoxContainer = HBoxContainer.new()
	move_lr.add_theme_constant_override("separation", 4)
	move_body.add_child(move_lr)
	move_left_button = _ui_button("←", func() -> void: _move_screen_direction(-1, 0))
	move_right_button = _ui_button("→", func() -> void: _move_screen_direction(1, 0))
	move_lr.add_child(move_left_button)
	move_lr.add_child(move_right_button)
	move_back_button = _ui_button("↓ Back", func() -> void: _move_screen_direction(0, -1))
	move_body.add_child(move_back_button)
	var move_y: HBoxContainer = HBoxContainer.new()
	move_y.add_theme_constant_override("separation", 4)
	move_body.add_child(move_y)
	move_down_button = _ui_button("Y −", func() -> void: _move_vertical(-1))
	move_up_button = _ui_button("Y +", func() -> void: _move_vertical(1))
	move_y.add_child(move_down_button)
	move_y.add_child(move_up_button)
	move_body.add_child(_section_label("SLIDE THROUGH AXLE"))
	var axle_row: HBoxContainer = HBoxContainer.new()
	axle_row.add_theme_constant_override("separation", 4)
	move_body.add_child(axle_row)
	axle_minus_button = _ui_button("Axle −", func() -> void: _slide_selected_on_axle(-EDIT_AXLE_STEP))
	axle_plus_button = _ui_button("Axle +", func() -> void: _slide_selected_on_axle(EDIT_AXLE_STEP))
	axle_row.add_child(axle_minus_button)
	axle_row.add_child(axle_plus_button)

	# Options modal.
	options_panel = PanelContainer.new()
	options_panel.anchor_left = 0.26
	options_panel.anchor_right = 0.74
	options_panel.anchor_top = 0.16
	options_panel.anchor_bottom = 0.78
	options_panel.add_theme_stylebox_override("panel", _panel_style(0.985, 14, 0.55))
	options_panel.visible = false
	layer.add_child(options_panel)
	var options_margin: MarginContainer = MarginContainer.new()
	options_margin.add_theme_constant_override("margin_left", 22)
	options_margin.add_theme_constant_override("margin_right", 22)
	options_margin.add_theme_constant_override("margin_top", 18)
	options_margin.add_theme_constant_override("margin_bottom", 18)
	options_panel.add_child(options_margin)
	var options_box: VBoxContainer = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 9)
	options_margin.add_child(options_box)
	var options_title: Label = Label.new()
	options_title.text = "OPTIONS"
	options_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_title.add_theme_font_size_override("font_size", 23)
	options_box.add_child(options_title)
	var options_note: Label = Label.new()
	options_note.text = "Changes save immediately and persist between launches."
	options_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_note.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	options_box.add_child(options_note)

	reverse_orbit_x_check = CheckButton.new()
	reverse_orbit_x_check.text = "Reverse orbit horizontal"
	reverse_orbit_x_check.toggled.connect(_on_reverse_orbit_x)
	options_box.add_child(reverse_orbit_x_check)
	reverse_orbit_y_check = CheckButton.new()
	reverse_orbit_y_check.text = "Reverse orbit vertical"
	reverse_orbit_y_check.toggled.connect(_on_reverse_orbit_y)
	options_box.add_child(reverse_orbit_y_check)
	reverse_pan_x_check = CheckButton.new()
	reverse_pan_x_check.text = "Reverse pan horizontal"
	reverse_pan_x_check.toggled.connect(_on_reverse_pan_x)
	options_box.add_child(reverse_pan_x_check)
	reverse_pan_y_check = CheckButton.new()
	reverse_pan_y_check.text = "Reverse pan vertical"
	reverse_pan_y_check.toggled.connect(_on_reverse_pan_y)
	options_box.add_child(reverse_pan_y_check)
	show_grid_check = CheckButton.new()
	show_grid_check.text = "Show build grid"
	show_grid_check.toggled.connect(_on_show_grid)
	options_box.add_child(show_grid_check)

	options_sensitivity_label = Label.new()
	options_sensitivity_label.text = "Camera sensitivity: 1.0x"
	options_box.add_child(options_sensitivity_label)
	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.45
	sensitivity_slider.max_value = 2.0
	sensitivity_slider.step = 0.05
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	options_box.add_child(sensitivity_slider)
	options_box.add_child(_ui_button("Close", _toggle_options, true))

	# Help modal.
	help_panel = PanelContainer.new()
	help_panel.anchor_left = 0.16
	help_panel.anchor_right = 0.84
	help_panel.anchor_top = 0.12
	help_panel.anchor_bottom = 0.80
	help_panel.add_theme_stylebox_override("panel", _panel_style(0.985, 14, 0.55))
	help_panel.visible = false
	layer.add_child(help_panel)
	var help_margin: MarginContainer = MarginContainer.new()
	help_margin.add_theme_constant_override("margin_left", 24)
	help_margin.add_theme_constant_override("margin_right", 24)
	help_margin.add_theme_constant_override("margin_top", 18)
	help_margin.add_theme_constant_override("margin_bottom", 18)
	help_panel.add_child(help_margin)
	var help_box: VBoxContainer = VBoxContainer.new()
	help_box.add_theme_constant_override("separation", 8)
	help_margin.add_child(help_box)
	var help: Label = Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 16)
	help.text = "CONNEX LAB v0.1.5\n\nCREATE: the bottom palette chooses the rod, connector, and connection mode. SOCKET adds rods to free connector sockets and connectors to free rod ends. AXLE can either insert the chosen rod through a connector hub OR place the chosen connector onto an existing rod as a sliding axle connector. CROSS snaps the chosen connector onto a rod body. Selecting O-Ring Stop in the connector palette lets you tap an axle rod to place a small physical stop.\n\nEDIT: taps only select; they never create. A vivid cyan outline shows the selected piece. Use the right panel for X/Y/Z rotation, Mount rotation, Reset Rotation, and Delete. Cross-mounted connectors rotate around the actual cross rod axis; the connector center moves around the snap point so the connection stays physically valid.\n\nMOVE: the left panel moves the selected fixed component in the camera plane or vertically. Axle ± slides a rod/connector through an axle while preserving alignment.\n\nOPTIONS: orbit/pan directions and camera sensitivity persist permanently.\n\nInvalid rotations are transactional: if a move would disconnect a rod/socket, cross mount, or axle, nothing is changed."
	help_box.add_child(help)
	help_box.add_child(_ui_button("Close", _toggle_help, true))

	_refresh_options_controls()
	_refresh_side_panels()
	_update_ui()


func _refresh_options_controls() -> void:
	if reverse_orbit_x_check != null:
		reverse_orbit_x_check.set_pressed_no_signal(reverse_orbit_x)
	if reverse_orbit_y_check != null:
		reverse_orbit_y_check.set_pressed_no_signal(reverse_orbit_y)
	if reverse_pan_x_check != null:
		reverse_pan_x_check.set_pressed_no_signal(reverse_pan_x)
	if reverse_pan_y_check != null:
		reverse_pan_y_check.set_pressed_no_signal(reverse_pan_y)
	if show_grid_check != null:
		show_grid_check.set_pressed_no_signal(show_grid)
	if sensitivity_slider != null:
		sensitivity_slider.set_value_no_signal(camera_sensitivity)
	if options_sensitivity_label != null:
		options_sensitivity_label.text = "Camera sensitivity: %.1fx" % camera_sensitivity


func _toggle_options() -> void:
	if options_panel == null:
		return
	options_panel.visible = not options_panel.visible
	if options_panel.visible and help_panel != null:
		help_panel.visible = false


func _toggle_create_edit() -> void:
	if simulating:
		_status("Return to BUILD before switching CREATE / EDIT")
		return
	edit_mode = not edit_mode
	_clear_selection_for_create() if not edit_mode else _status("EDIT mode — tap a piece to select it")
	_update_ui()


func _toggle_rotation_panel() -> void:
	rotation_collapsed = not rotation_collapsed
	_refresh_side_panels()
	_save_settings()


func _toggle_move_panel() -> void:
	move_collapsed = not move_collapsed
	_refresh_side_panels()
	_save_settings()


func _refresh_side_panels() -> void:
	if rotation_body != null:
		rotation_body.visible = not rotation_collapsed
	if rotation_collapse_button != null:
		rotation_collapse_button.text = "ROTATE ▸" if rotation_collapsed else "ROTATE ▾"
	if rotation_panel != null:
		rotation_panel.offset_bottom = 126.0 if rotation_collapsed else 438.0
	if move_body != null:
		move_body.visible = not move_collapsed
	if move_collapse_button != null:
		move_collapse_button.text = "MOVE ▸" if move_collapsed else "MOVE ▾"
	if move_panel != null:
		move_panel.offset_bottom = 126.0 if move_collapsed else 438.0


# -----------------------------------------------------------------------------
# More faithful procedural piece visuals
# -----------------------------------------------------------------------------

func _add_box_visual(parent: Node3D, size: Vector3, position: Vector3, rotation_y: float, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder_visual(parent: Node3D, radius: float, height: float, position: Vector3, material: Material, segments: int = 14) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _rebuild_rod(body: RigidBody3D, def_index: int, length: float) -> void:
	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()
	var definition: Dictionary = rod_defs[def_index]
	body.mass = float(definition["mass"])
	body.set_meta("rod_type", def_index)
	body.set_meta("visual_length", length)
	var color: Color = definition["color"]
	var main_mat: Material = _mat(color)
	var light_mat: Material = _mat(color.lightened(0.07))
	var shaft_length: float = maxf(0.24, length - 0.80)

	# K'NEX rods have a narrow fluted/cross-like shaft rather than a round dowel.
	_add_cylinder_visual(body, 0.115, shaft_length, Vector3.ZERO, main_mat, 8)
	for angle_deg in [0.0, 45.0, 90.0, 135.0]:
		_add_box_visual(body, Vector3(0.31, shaft_length, 0.075), Vector3.ZERO, deg_to_rad(float(angle_deg)), main_mat)

	for sign_value in [-1.0, 1.0]:
		var signf: float = float(sign_value)
		var neck_y: float = signf * (length * 0.5 - 0.31)
		_add_cylinder_visual(body, 0.205, 0.39, Vector3(0, neck_y, 0), main_mat, 12)
		var shoulder_y: float = signf * (length * 0.5 - 0.115)
		_add_cylinder_visual(body, 0.315, 0.12, Vector3(0, shoulder_y, 0), light_mat, 12)
		# Flattened locking tongue at the very end gives the familiar keyed end silhouette.
		var tongue_y: float = signf * (length * 0.5 - 0.035)
		_add_box_visual(body, Vector3(0.43, 0.12, 0.18), Vector3(0, tongue_y, 0), 0.0, main_mat)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = ROD_RADIUS
	capsule.height = maxf(length, ROD_RADIUS * 2.0)
	collision.shape = capsule
	body.add_child(collision)


func _add_real_socket_visual(parent: Node3D, angle_deg: int, color: Color) -> void:
	var direction: Vector3 = _slot_dir(angle_deg)
	var tangent: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var angle: float = deg_to_rad(float(angle_deg))
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.055))
	# Narrow web from the hub.
	_add_box_visual(parent, Vector3(0.66, 0.28, 0.34), direction * 0.77, angle, main_mat)
	# Two open jaws with a real gap between them.
	for side in [-1.0, 1.0]:
		var sidef: float = float(side)
		_add_box_visual(parent, Vector3(0.78, 0.34, 0.14), direction * 1.10 + tangent * (0.235 * sidef), angle, main_mat)
		var tip: MeshInstance3D = _add_cylinder_visual(parent, 0.12, 0.34, direction * 1.47 + tangent * (0.235 * sidef), edge_mat, 10)
		tip.rotation.y = angle
	# Inner stop ridge visible at the mouth.
	_add_box_visual(parent, Vector3(0.14, 0.36, 0.56), direction * 1.33, angle, edge_mat)


func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if def_index < 0 or def_index >= connector_defs.size() or def_index == o_ring_index:
		return
	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()
	var definition: Dictionary = connector_defs[def_index]
	body.mass = float(definition["mass"])
	body.set_meta("connector_type", def_index)
	var color: Color = definition["color"]
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.06))

	# Thin open centre hub, closer to the stamped/plastic K'NEX connector profile.
	var hub: MeshInstance3D = MeshInstance3D.new()
	var hub_mesh: TorusMesh = TorusMesh.new()
	hub_mesh.inner_radius = 0.30
	hub_mesh.outer_radius = 0.61
	hub_mesh.rings = 20
	hub_mesh.ring_segments = 12
	hub.mesh = hub_mesh
	hub.material_override = main_mat
	body.add_child(hub)
	# Raised collar around the axle opening without filling the hole.
	var collar: MeshInstance3D = MeshInstance3D.new()
	var collar_mesh: TorusMesh = TorusMesh.new()
	collar_mesh.inner_radius = 0.285
	collar_mesh.outer_radius = 0.43
	collar_mesh.rings = 16
	collar_mesh.ring_segments = 10
	collar.mesh = collar_mesh
	collar.scale.y = 0.72
	collar.material_override = edge_mat
	body.add_child(collar)

	for slot_value in definition["slots"]:
		_add_real_socket_visual(body, int(slot_value), color)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.46
	shape.height = 0.52
	collision.shape = shape
	body.add_child(collision)


func _make_connector(def_index: int, xform: Transform3D) -> RigidBody3D:
	var body: RigidBody3D = super._make_connector(def_index, xform)
	body.set_meta("rotation_home_basis", body.global_transform.basis)
	body.set_meta("rotation_home_transform", body.global_transform)
	return body


# -----------------------------------------------------------------------------
# Strong selection highlight
# -----------------------------------------------------------------------------

func _selection_mat() -> StandardMaterial3D:
	if vivid_selection_material != null:
		return vivid_selection_material
	vivid_selection_material = StandardMaterial3D.new()
	vivid_selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vivid_selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vivid_selection_material.albedo_color = Color(0.0, 0.82, 1.0, 0.72)
	vivid_selection_material.emission_enabled = true
	vivid_selection_material.emission = Color(0.0, 0.92, 1.0)
	vivid_selection_material.emission_energy_multiplier = 3.2
	vivid_selection_material.cull_mode = BaseMaterial3D.CULL_FRONT
	return vivid_selection_material


func _refresh_selection_highlight() -> void:
	_clear_selection_highlight()
	if not edit_mode or not is_instance_valid(selected_piece):
		return
	var body: RigidBody3D = selected_piece
	var highlight: Node3D = Node3D.new()
	highlight.name = "SelectionHighlight"
	highlighted_body = body
	body.add_child(highlight)
	for child_value in body.get_children():
		var source: MeshInstance3D = child_value as MeshInstance3D
		if source == null or source.mesh == null or source.name == "SelectionHighlight":
			continue
		var outline: MeshInstance3D = MeshInstance3D.new()
		outline.mesh = source.mesh
		outline.transform = source.transform
		outline.scale = source.scale * 1.16
		outline.material_override = _selection_mat()
		highlight.add_child(outline)


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(highlighted_body):
		var highlight: Node3D = highlighted_body.get_node_or_null("SelectionHighlight") as Node3D
		if highlight != null:
			var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.025
			highlight.scale = Vector3.ONE * pulse


func _set_selected(body: RigidBody3D) -> void:
	_clear_selection_highlight()
	super._set_selected(body)
	if is_instance_valid(body) and str(body.get_meta("kind", "")) == "o_ring":
		selected_connector_type = o_ring_index
	_refresh_selection_highlight()
	_update_ui()


func _clear_selection_for_create() -> void:
	_clear_selection_highlight()
	selected_piece = null
	_update_ui()
	_status("CREATE mode — taps place parts only")


# -----------------------------------------------------------------------------
# O-Ring Stop integrated into connector palette
# -----------------------------------------------------------------------------

func _rod_is_axle(rod: RigidBody3D) -> bool:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] == rod or nodes[1] == rod:
			return true
	return false


func _make_o_ring_body(transform: Transform3D) -> RigidBody3D:
	var ring: RigidBody3D = RigidBody3D.new()
	ring.name = "O_Ring_Stop_%d" % piece_counter
	piece_counter += 1
	_configure_piece_body(ring)
	ring.mass = 0.035
	ring.linear_damp = 0.20
	ring.angular_damp = 0.34
	ring.collision_layer = 4
	ring.collision_mask = 1 | 2 | 4
	add_child(ring)
	ring.global_transform = transform
	ring.set_meta("kind", "o_ring")

	var visual: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = O_RING_INNER_RADIUS
	torus.outer_radius = O_RING_OUTER_RADIUS
	torus.rings = 20
	torus.ring_segments = 12
	visual.mesh = torus
	visual.scale.y = 0.72
	visual.material_override = _mat(Color("3b424b"))
	ring.add_child(visual)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = O_RING_OUTER_RADIUS
	cylinder.height = O_RING_HEIGHT
	collision.shape = cylinder
	ring.add_child(collision)

	ring.set_meta("build_transform", ring.global_transform)
	o_ring_stops.append(ring)
	return ring


func _find_o_ring_host(ring: RigidBody3D) -> RigidBody3D:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] != ring and nodes[1] != ring:
			continue
		var other: RigidBody3D = (nodes[1] if nodes[0] == ring else nodes[0]) as RigidBody3D
		if is_instance_valid(other) and str(other.get_meta("kind", "")) == "rod":
			return other
	return null


func _place_o_ring_on_rod(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if not _rod_is_axle(rod):
		_status("O-Ring Stop can only be placed on a rod already used as an axle")
		return
	var axis: Vector3 = (rod.global_transform.basis * Vector3.UP).normalized()
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length")) * 0.5 - 0.40)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = Basis(Quaternion(Vector3.UP, axis))
	var ring: RigidBody3D = _make_o_ring_body(Transform3D(basis, center))
	var ring_joint: Generic6DOFJoint3D = _make_fixed_joint(rod, ring, center)
	ring_joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	_commit_state()
	_status("O-Ring Stop placed on axle")


# -----------------------------------------------------------------------------
# CREATE / EDIT tap behavior and axle-on-existing-rod placement
# -----------------------------------------------------------------------------

func _raycast_piece(screen_pos: Vector2) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 900.0)
	query.collision_mask = 2 | 4
	return get_world_3d().direct_space_state.intersect_ray(query)


func _handle_tap(screen_pos: Vector2) -> void:
	if simulating or help_panel.visible or options_panel.visible:
		return
	var now: int = Time.get_ticks_msec()
	if now - last_world_tap_ms < WORLD_TAP_DEBOUNCE_MS and last_world_tap_pos.distance_to(screen_pos) < 36.0:
		return
	last_world_tap_ms = now
	last_world_tap_pos = screen_pos
	var hit: Dictionary = _raycast_piece(screen_pos)
	if hit.is_empty():
		return
	var body: RigidBody3D = hit.get("collider") as RigidBody3D
	if not is_instance_valid(body):
		return
	var kind: String = str(body.get_meta("kind", ""))

	if edit_mode:
		_set_selected(body)
		_status("Selected %s" % _piece_display_name(body))
		return

	# CREATE mode: no selection or rotation side effects.
	if selected_connector_type == o_ring_index:
		if kind == "rod":
			_place_o_ring_on_rod(body, hit["position"])
		else:
			_status("O-Ring Stop selected — tap an axle rod")
		_clear_selection_for_create()
		return

	if attach_mode == 0: # SOCKET
		if kind == "connector":
			var slot: int = _select_slot_strict(body, hit["position"])
			if slot >= 0:
				_extend_socket(body, slot)
			elif slot == -3:
				_status("That socket is already occupied")
			else:
				_status("CREATE: tap an actual free outer socket")
		elif kind == "rod":
			var end_sign: int = _rod_end_hit(body, hit["position"])
			if end_sign != 0:
				_attach_connector_to_rod_end(body, end_sign)
			else:
				_status("CREATE / SOCKET: tap a free rod end")
		_clear_selection_for_create()
		return

	if attach_mode == 1: # AXLE
		if kind == "connector":
			_insert_axle(body)
		elif kind == "rod":
			_place_connector_on_rod_as_axle(body, hit["position"])
		else:
			_status("AXLE: tap a connector hub or an existing rod")
		_clear_selection_for_create()
		return

	if attach_mode == 2: # CROSS
		if kind == "rod":
			_cross_snap_v015(body, hit["position"])
		else:
			_status("CROSS: tap a rod body")
		_clear_selection_for_create()


func _piece_display_name(body: RigidBody3D) -> String:
	var kind: String = str(body.get_meta("kind", ""))
	if kind == "rod":
		return str(rod_defs[int(body.get_meta("rod_type"))]["name"])
	if kind == "connector":
		return str(connector_defs[int(body.get_meta("connector_type"))]["name"])
	if kind == "o_ring":
		return "O-Ring Stop"
	return kind


func _place_connector_on_rod_as_axle(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if selected_connector_type == o_ring_index:
		_place_o_ring_on_rod(rod, hit_pos)
		return
	var axis: Vector3 = (rod.global_transform.basis * Vector3.UP).normalized()
	var half_len: float = maxf(0.1, float(rod.get_meta("visual_length")) * 0.5 - 0.45)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = Basis(Quaternion(Vector3.UP, axis))
	var connector: RigidBody3D = _make_connector(selected_connector_type, Transform3D(basis, center))
	var axle_joint: Generic6DOFJoint3D = _make_axle_joint(connector, rod)
	axle_joint.set_meta("axle_on_existing_rod", true)
	connector.set_meta("axle_occupied", true)
	connector.set_meta("axle_host_rod", rod)
	connector.set_meta("rotation_home_basis", connector.global_transform.basis)
	connector.set_meta("rotation_home_transform", connector.global_transform)
	connector.set_meta("build_transform", connector.global_transform)
	_commit_state()
	_status("%s placed as a sliding axle connector" % connector_defs[selected_connector_type]["name"])


func _cross_snap_v015(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if selected_connector_type == o_ring_index:
		_status("O-Ring Stop is an axle stop, not a cross connector")
		return
	var axis: Vector3 = (rod.global_transform.basis * Vector3.UP).normalized()
	var slot: int = int(connector_defs[selected_connector_type]["slots"][0])
	var local_slot: Vector3 = _slot_dir(slot)
	var base: Basis = Basis(Quaternion(Vector3.UP, axis))
	var radial_now: Vector3 = (base * local_slot).normalized()
	var preferred: Vector3 = camera.global_transform.basis.x
	preferred -= axis * preferred.dot(axis)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.UP)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.RIGHT)
	preferred = preferred.normalized()
	var angle: float = radial_now.signed_angle_to(preferred, axis)
	var basis: Basis = Basis(axis, angle) * base
	var radial: Vector3 = (basis * local_slot).normalized()
	var half_len: float = float(rod.get_meta("visual_length")) * 0.5 - 0.42
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var snap_point: Vector3 = rod.global_position + axis * along
	var connector: RigidBody3D = _make_connector(selected_connector_type, Transform3D(basis, snap_point - radial * CONNECTOR_D))
	_set_connector_occupied(connector, slot, true)
	var cross_joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, snap_point)
	cross_joint.set_meta("cross_mount", true)
	connector.set_meta("cross_mount", true)
	connector.set_meta("cross_host_rod", rod)
	connector.set_meta("cross_home_offset", connector.global_position - snap_point)
	connector.set_meta("cross_home_basis", connector.global_transform.basis)
	connector.set_meta("rotation_home_basis", connector.global_transform.basis)
	connector.set_meta("rotation_home_transform", connector.global_transform)
	last_placed_connector = connector
	_auto_fuse_connector(connector)
	_commit_state()
	_status("Cross connector placed — EDIT rotation now respects the actual cross rod axis")


# -----------------------------------------------------------------------------
# Connector picker behavior: create choice vs edit selected piece
# -----------------------------------------------------------------------------

func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	if not edit_mode:
		selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
		_update_ui()
		_status("Create connector: %s" % connector_defs[selected_connector_type]["name"])
		return
	if not is_instance_valid(selected_piece):
		_status("EDIT: select a connector first")
		return
	var kind: String = str(selected_piece.get_meta("kind", ""))
	if kind == "o_ring":
		_status("O-Ring Stop is a special axle part and cannot be converted to a radial connector")
		return
	if kind != "connector":
		_status("EDIT: connector arrows change a selected connector")
		return
	var connector: RigidBody3D = selected_piece
	var current: int = int(connector.get_meta("connector_type"))
	var candidate: int = current
	for _i in range(connector_defs.size() - 1):
		candidate = wrapi(candidate + delta, 0, connector_defs.size())
		if candidate == o_ring_index:
			continue
		var attachments: Array = _connector_socket_attachments_v015(connector)
		var mapping: Dictionary = _map_attachments_to_slots(connector.global_transform.basis, candidate, attachments)
		if bool(mapping.get("valid", false)):
			_clear_selection_highlight()
			_rebuild_connector(connector, candidate)
			connector.set_meta("occupied", mapping.get("occupied", {}))
			_add_cross_mount_occupancy(connector, connector.global_transform, connector.get_meta("occupied") as Dictionary)
			connector.set_meta("build_transform", connector.global_transform)
			selected_connector_type = candidate
			_rebind_all_joints()
			_commit_state()
			_refresh_selection_highlight()
			_update_ui()
			_status("Connector changed to %s" % connector_defs[candidate]["name"])
			return
	_status("No other connector type fits every current attachment")


func _change_rod_type(delta: int) -> void:
	if simulating:
		return
	if not edit_mode:
		selected_rod_type = wrapi(selected_rod_type + delta, 0, rod_defs.size())
		_update_ui()
		_status("Create rod: %s" % rod_defs[selected_rod_type]["name"])
		return
	if _selected_kind() != "rod":
		_status("EDIT: rod arrows change a selected rod")
		return
	super._change_rod_type(delta)
	_refresh_selection_highlight()


# -----------------------------------------------------------------------------
# Transactional connector rotation, including real cross-axis rotation
# -----------------------------------------------------------------------------

func _cross_mount_info(connector: RigidBody3D) -> Dictionary:
	if not bool(connector.get_meta("cross_mount", false)):
		return {}
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		if not bool(joint.get_meta("cross_mount", false)):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] != connector and nodes[1] != connector:
			continue
		var host: RigidBody3D = (nodes[1] if nodes[0] == connector else nodes[0]) as RigidBody3D
		if is_instance_valid(host) and str(host.get_meta("kind", "")) == "rod":
			var axis: Vector3 = (host.global_transform.basis * Vector3.UP).normalized()
			return {"joint": joint, "host": host, "anchor": joint.global_position, "axis": axis}
	return {}


func _connector_socket_attachments_v015(connector: RigidBody3D) -> Array:
	var result: Array = []
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] != connector and nodes[1] != connector:
			continue
		if bool(joint.get_meta("cross_mount", false)):
			continue
		var delta: Vector3 = joint.global_position - connector.global_position
		if delta.length_squared() >= 0.15:
			result.append({"joint": joint, "dir": delta.normalized()})
	return result


func _slot_for_world_direction(transform: Transform3D, def_index: int, world_dir: Vector3) -> int:
	var best_slot: int = -1
	var best_dot: float = ROTATION_ALIGN_DOT
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		var candidate_dir: Vector3 = (transform.basis * _slot_dir(slot)).normalized()
		var score: float = candidate_dir.dot(world_dir.normalized())
		if score > best_dot:
			best_dot = score
			best_slot = slot
	return best_slot


func _add_cross_mount_occupancy(connector: RigidBody3D, transform: Transform3D, occupied: Dictionary) -> bool:
	var cross: Dictionary = _cross_mount_info(connector)
	if cross.is_empty():
		return true
	var anchor: Vector3 = cross["anchor"]
	var radial: Vector3 = anchor - transform.origin
	if radial.length_squared() < 0.20:
		return false
	var slot: int = _slot_for_world_direction(transform, int(connector.get_meta("connector_type")), radial.normalized())
	if slot < 0 or occupied.has(slot):
		return false
	occupied[slot] = true
	return true


func _try_connector_transform_v015(connector: RigidBody3D, candidate: Transform3D, label: String) -> bool:
	if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
		return false
	var def_index: int = int(connector.get_meta("connector_type"))
	var attachments: Array = _connector_socket_attachments_v015(connector)
	var mapping: Dictionary = _map_attachments_to_slots(candidate.basis, def_index, attachments)
	if not bool(mapping.get("valid", false)):
		_status("%s blocked — an attached rod would no longer align to a real socket" % label)
		return false
	if not _axle_basis_valid(connector, candidate.basis):
		_status("%s blocked — it would misalign an axle" % label)
		return false
	var occupied: Dictionary = (mapping.get("occupied", {}) as Dictionary).duplicate(true)
	if not _add_cross_mount_occupancy(connector, candidate, occupied):
		_status("%s blocked — cross snap geometry would be lost" % label)
		return false

	# Mutation starts only after every validation passed. Failed rotations leave no state behind.
	connector.global_transform = Transform3D(candidate.basis.orthonormalized(), candidate.origin)
	connector.set_meta("occupied", occupied)
	connector.set_meta("build_transform", connector.global_transform)
	_update_axle_frames(connector)
	_rebind_all_joints()
	_commit_state()
	_refresh_selection_highlight()
	_status("%s" % label)
	return true


func _rotate_selected_axis(local_axis: Vector3, direction_sign: int, label: String) -> void:
	if simulating or not edit_mode or _selected_kind() != "connector":
		_status("EDIT: select a connector to rotate")
		return
	var connector: RigidBody3D = selected_piece
	var cross: Dictionary = _cross_mount_info(connector)
	var world_axis: Vector3 = (connector.global_transform.basis * local_axis).normalized()
	if not cross.is_empty():
		var mount_axis: Vector3 = cross["axis"]
		var alignment: float = world_axis.dot(mount_axis)
		if absf(alignment) < 0.92:
			_status("%s blocked by cross mount — use the X/Y/Z axis aligned with the rod, or Mount rotation" % label)
			return
		_rotate_cross_around_mount(connector, direction_sign if alignment >= 0.0 else -direction_sign, label)
		return
	var rotation: Basis = Basis(world_axis, ROT_STEP * float(direction_sign))
	var candidate: Transform3D = Transform3D(rotation * connector.global_transform.basis, connector.global_position)
	_try_connector_transform_v015(connector, candidate, "Rotate %s 45°" % label)


func _rotate_cross_around_mount(connector: RigidBody3D, direction_sign: int, label: String) -> void:
	var cross: Dictionary = _cross_mount_info(connector)
	if cross.is_empty():
		return
	var axis: Vector3 = cross["axis"]
	var anchor: Vector3 = cross["anchor"]
	var rotation: Basis = Basis(axis, ROT_STEP * float(direction_sign))
	var offset: Vector3 = connector.global_position - anchor
	var candidate: Transform3D = Transform3D(rotation * connector.global_transform.basis, anchor + rotation * offset)
	_try_connector_transform_v015(connector, candidate, "Cross mount %s 45°" % label)


func _rotate_selected_mount(direction_sign: int) -> void:
	if simulating or not edit_mode or _selected_kind() != "connector":
		_status("EDIT: select a connector first")
		return
	var connector: RigidBody3D = selected_piece
	var cross: Dictionary = _cross_mount_info(connector)
	if not cross.is_empty():
		_rotate_cross_around_mount(connector, direction_sign, "rotation")
		return
	var mount_axis: Vector3 = Vector3.ZERO
	var attachments: Array = _connector_socket_attachments_v015(connector)
	if attachments.size() == 1:
		var attachment: Dictionary = attachments[0] as Dictionary
		mount_axis = (attachment["dir"] as Vector3).normalized()
	else:
		for joint_value in joints:
			var joint: Joint3D = joint_value as Joint3D
			if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
				continue
			var nodes: Array = _joint_nodes(joint)
			if nodes[0] == connector or nodes[1] == connector:
				var other: RigidBody3D = (nodes[1] if nodes[0] == connector else nodes[0]) as RigidBody3D
				if is_instance_valid(other):
					mount_axis = (other.global_transform.basis * Vector3.UP).normalized()
					break
	if mount_axis.length_squared() < 0.5:
		_status("Mount rotation needs exactly one socket mount, a cross mount, or an axle")
		return
	var rotation: Basis = Basis(mount_axis, ROT_STEP * float(direction_sign))
	var candidate: Transform3D = Transform3D(rotation * connector.global_transform.basis, connector.global_position)
	_try_connector_transform_v015(connector, candidate, "Rotate around mount 45°")


func _reset_selected_rotation_v015() -> void:
	if simulating or not edit_mode or _selected_kind() != "connector":
		_status("EDIT: select a connector first")
		return
	var connector: RigidBody3D = selected_piece
	var cross: Dictionary = _cross_mount_info(connector)
	if not cross.is_empty():
		var anchor: Vector3 = cross["anchor"]
		var home_offset: Vector3 = connector.get_meta("cross_home_offset", connector.global_position - anchor)
		var home_basis: Basis = connector.get_meta("cross_home_basis", connector.global_transform.basis)
		var candidate_cross: Transform3D = Transform3D(home_basis, anchor + home_offset)
		_try_connector_transform_v015(connector, candidate_cross, "Reset cross rotation")
		return
	var home_basis_normal: Basis = connector.get_meta("rotation_home_basis", connector.global_transform.basis)
	var candidate: Transform3D = Transform3D(home_basis_normal, connector.global_position)
	_try_connector_transform_v015(connector, candidate, "Reset rotation")


# -----------------------------------------------------------------------------
# EDIT movement / axle sliding
# -----------------------------------------------------------------------------

func _fixed_component(seed: RigidBody3D) -> Array:
	var result: Array = []
	if not is_instance_valid(seed):
		return result
	var queue: Array = [seed]
	var seen: Dictionary = {seed.get_instance_id(): true}
	while not queue.is_empty():
		var current: RigidBody3D = queue.pop_front() as RigidBody3D
		result.append(current)
		for joint_value in joints:
			var joint: Joint3D = joint_value as Joint3D
			if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
				continue
			var nodes: Array = _joint_nodes(joint)
			if nodes[0] != current and nodes[1] != current:
				continue
			var other: RigidBody3D = (nodes[1] if nodes[0] == current else nodes[0]) as RigidBody3D
			if not is_instance_valid(other):
				continue
			if not seen.has(other.get_instance_id()):
				seen[other.get_instance_id()] = true
				queue.append(other)
	return result


func _component_ids(component: Array) -> Dictionary:
	var ids: Dictionary = {}
	for body_value in component:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			ids[body.get_instance_id()] = true
	return ids


func _external_axle_axes(component: Array) -> Array:
	var ids: Dictionary = _component_ids(component)
	var axes: Array = []
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		var a: RigidBody3D = nodes[0] as RigidBody3D
		var b: RigidBody3D = nodes[1] as RigidBody3D
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		var a_in: bool = ids.has(a.get_instance_id())
		var b_in: bool = ids.has(b.get_instance_id())
		if a_in == b_in:
			continue
		var connector: RigidBody3D = a if str(a.get_meta("kind", "")) == "connector" else b
		axes.append((connector.global_transform.basis * Vector3.UP).normalized())
	return axes


func _translate_component(component: Array, delta: Vector3, allow_axle_aligned: bool = false) -> bool:
	if delta.length_squared() < 0.0001:
		return false
	var axle_axes: Array = _external_axle_axes(component)
	if not axle_axes.is_empty():
		if not allow_axle_aligned:
			_status("This component is constrained by an axle — use Axle − / Axle +")
			return false
		for axis_value in axle_axes:
			var axis: Vector3 = axis_value as Vector3
			if absf(axis.dot(delta.normalized())) < 0.985:
				_status("Move blocked — it would pull the component sideways out of an axle")
				return false
	var ids: Dictionary = _component_ids(component)
	for body_value in component:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.global_position += delta
		body.set_meta("build_transform", body.global_transform)
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		var a: RigidBody3D = nodes[0] as RigidBody3D
		var b: RigidBody3D = nodes[1] as RigidBody3D
		if is_instance_valid(a) and is_instance_valid(b) and ids.has(a.get_instance_id()) and ids.has(b.get_instance_id()):
			joint.global_position += delta
	_rebind_all_joints()
	_commit_state()
	_refresh_selection_highlight()
	return true


func _move_screen_direction(horizontal: int, forward_value: int) -> void:
	if simulating or not edit_mode or not is_instance_valid(selected_piece):
		_status("EDIT: select a piece to move")
		return
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var delta: Vector3 = (right * float(horizontal) + forward * float(forward_value)) * EDIT_MOVE_STEP
	if _translate_component(_fixed_component(selected_piece), delta):
		_status("Moved selected component")


func _move_vertical(direction_sign: int) -> void:
	if simulating or not edit_mode or not is_instance_valid(selected_piece):
		_status("EDIT: select a piece to move")
		return
	if _translate_component(_fixed_component(selected_piece), Vector3.UP * EDIT_MOVE_STEP * float(direction_sign)):
		_status("Moved selected component vertically")


func _find_axle_joint_for_body(body: RigidBody3D) -> Joint3D:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] == body or nodes[1] == body:
			return joint
	return null


func _slide_selected_on_axle(amount: float) -> void:
	if simulating or not edit_mode or not is_instance_valid(selected_piece):
		_status("EDIT: select an axle rod, axle connector, or O-Ring Stop")
		return
	var kind: String = str(selected_piece.get_meta("kind", ""))
	if kind == "o_ring":
		_slide_o_ring(selected_piece, amount)
		return
	var axle_joint: Joint3D = _find_axle_joint_for_body(selected_piece)
	if axle_joint == null:
		_status("Selected piece is not part of an axle connection")
		return
	var nodes: Array = _joint_nodes(axle_joint)
	var connector: RigidBody3D = nodes[0] as RigidBody3D
	var other: RigidBody3D = nodes[1] as RigidBody3D
	if str(connector.get_meta("kind", "")) != "connector":
		var swap: RigidBody3D = connector
		connector = other
		other = swap
	var axis: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
	var component: Array = _fixed_component(selected_piece)
	if _translate_component(component, axis * amount, true):
		_status("Slid selected component along axle")


func _slide_o_ring(ring: RigidBody3D, amount: float) -> void:
	var host: RigidBody3D = _find_o_ring_host(ring)
	if not is_instance_valid(host):
		_status("O-Ring host axle not found")
		return
	var axis: Vector3 = (host.global_transform.basis * Vector3.UP).normalized()
	var half_len: float = maxf(0.1, float(host.get_meta("visual_length")) * 0.5 - 0.42)
	var current_along: float = (ring.global_position - host.global_position).dot(axis)
	var new_along: float = clampf(current_along + amount, -half_len, half_len)
	var new_position: Vector3 = host.global_position + axis * new_along
	var delta: Vector3 = new_position - ring.global_position
	ring.global_position = new_position
	ring.set_meta("build_transform", ring.global_transform)
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] == ring or nodes[1] == ring:
			joint.global_position += delta
	_rebind_all_joints()
	_commit_state()
	_refresh_selection_highlight()
	_status("Moved O-Ring Stop along axle")


# -----------------------------------------------------------------------------
# Camera controls with persistent reversal settings
# -----------------------------------------------------------------------------

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
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.y = 4.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		touch_mouse_guard_until = Time.get_ticks_msec() + 350
		if touch.pressed:
			touches[touch.index] = touch.position
			touch_start[touch.index] = touch.position
			touch_moved[touch.index] = false
			if touches.size() >= 2:
				pinch_last = _pinch_distance()
				pinch_center_last = _pinch_center()
				pinch_center_valid = true
		else:
			var moved: bool = bool(touch_moved.get(touch.index, false))
			var start: Vector2 = touch_start.get(touch.index, touch.position)
			touches.erase(touch.index)
			touch_start.erase(touch.index)
			touch_moved.erase(touch.index)
			if touches.size() < 2:
				pinch_last = -1.0
				pinch_center_valid = false
			if not moved and start.distance_to(touch.position) < 18.0:
				_handle_tap(touch.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		touch_mouse_guard_until = Time.get_ticks_msec() + 350
		touches[drag.index] = drag.position
		if drag.relative.length() > 2.0:
			touch_moved[drag.index] = true
		if touches.size() >= 2:
			var distance: float = _pinch_distance()
			if pinch_last > 0.0:
				camera_distance = clampf(camera_distance - (distance - pinch_last) * 0.030 * camera_sensitivity, 5.0, 220.0)
			pinch_last = distance
			var center: Vector2 = _pinch_center()
			if pinch_center_valid:
				_pan_camera(center - pinch_center_last)
			pinch_center_last = center
			pinch_center_valid = true
		else:
			var x_factor: float = -1.0 if reverse_orbit_x else 1.0
			var y_factor: float = -1.0 if reverse_orbit_y else 1.0
			camera_yaw -= drag.relative.x * 0.006 * camera_sensitivity * x_factor
			camera_pitch = clampf(camera_pitch - drag.relative.y * 0.005 * camera_sensitivity * y_factor, deg_to_rad(8.0), deg_to_rad(82.0))
	elif event is InputEventMouseButton:
		if Time.get_ticks_msec() < touch_mouse_guard_until:
			return
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				mouse_down = true
				mouse_start = mouse_button.position
				mouse_moved = false
			else:
				if mouse_down and not mouse_moved and mouse_start.distance_to(mouse_button.position) < 10.0:
					_handle_tap(mouse_button.position)
				mouse_down = false
		elif mouse_button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			mouse_pan_down = mouse_button.pressed
			mouse_pan_last = mouse_button.position
		elif mouse_button.pressed and mouse_button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera_distance = clampf(camera_distance + (-2.0 if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0) * camera_sensitivity, 5.0, 220.0)
	elif event is InputEventMouseMotion:
		if Time.get_ticks_msec() < touch_mouse_guard_until:
			return
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if mouse_pan_down:
			_pan_camera(motion.position - mouse_pan_last)
			mouse_pan_last = motion.position
		elif mouse_down:
			if motion.relative.length() > 1.0:
				mouse_moved = true
				var x_factor_mouse: float = -1.0 if reverse_orbit_x else 1.0
				var y_factor_mouse: float = -1.0 if reverse_orbit_y else 1.0
				camera_yaw -= motion.relative.x * 0.006 * camera_sensitivity * x_factor_mouse
				camera_pitch = clampf(camera_pitch - motion.relative.y * 0.005 * camera_sensitivity * y_factor_mouse, deg_to_rad(8.0), deg_to_rad(82.0))


# -----------------------------------------------------------------------------
# State persistence for cross mount metadata and O-Rings
# -----------------------------------------------------------------------------

func _capture_state() -> Dictionary:
	var snapshot: Dictionary = super._capture_state()
	var saved_bodies: Array = snapshot["bodies"]
	var live_index: int = 0
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if live_index >= saved_bodies.size():
			break
		var state: Dictionary = saved_bodies[live_index] as Dictionary
		if str(body.get_meta("kind", "")) == "connector":
			state["rotation_home_transform"] = body.get_meta("rotation_home_transform", body.global_transform)
			state["cross_mount"] = bool(body.get_meta("cross_mount", false))
			if bool(state["cross_mount"]):
				var cross: Dictionary = _cross_mount_info(body)
				if not cross.is_empty():
					state["cross_host_index"] = bodies.find(cross["host"])
					state["cross_anchor"] = cross["anchor"]
					state["cross_home_offset"] = body.get_meta("cross_home_offset", body.global_position - (cross["anchor"] as Vector3))
					state["cross_home_basis"] = body.get_meta("cross_home_basis", body.global_transform.basis)
		live_index += 1

	var ring_states: Array = []
	var selected_ring_index: int = -1
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		var host: RigidBody3D = _find_o_ring_host(ring)
		var host_index: int = bodies.find(host)
		if host_index < 0:
			continue
		if selected_piece == ring:
			selected_ring_index = ring_states.size()
		ring_states.append({"transform": ring.get_meta("build_transform", ring.global_transform), "host": host_index, "anchor": ring.global_position})
	snapshot["o_rings"] = ring_states
	snapshot["selected_o_ring"] = selected_ring_index
	return snapshot


func _clear_o_ring_bodies() -> void:
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.collision_layer = 0
			ring.collision_mask = 0
			ring.queue_free()
	o_ring_stops.clear()


func _restore_state(snapshot: Dictionary) -> void:
	_clear_o_ring_bodies()
	_clear_selection_highlight()
	super._restore_state(snapshot)

	var saved_bodies: Array = snapshot["bodies"]
	var live_index: int = 0
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if live_index >= saved_bodies.size():
			break
		var state: Dictionary = saved_bodies[live_index] as Dictionary
		if str(body.get_meta("kind", "")) == "connector":
			body.set_meta("rotation_home_transform", state.get("rotation_home_transform", body.global_transform))
			body.set_meta("rotation_home_basis", (state.get("rotation_home_transform", body.global_transform) as Transform3D).basis)
			if bool(state.get("cross_mount", false)):
				body.set_meta("cross_mount", true)
				body.set_meta("cross_home_offset", state.get("cross_home_offset", Vector3.ZERO))
				body.set_meta("cross_home_basis", state.get("cross_home_basis", body.global_transform.basis))
				var host_index: int = int(state.get("cross_host_index", -1))
				if host_index >= 0 and host_index < bodies.size():
					var host: RigidBody3D = bodies[host_index] as RigidBody3D
					body.set_meta("cross_host_rod", host)
					for joint_value in joints:
						var joint: Joint3D = joint_value as Joint3D
						if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
							continue
						var nodes: Array = _joint_nodes(joint)
						if (nodes[0] == body and nodes[1] == host) or (nodes[0] == host and nodes[1] == body):
							var saved_anchor: Vector3 = state.get("cross_anchor", joint.global_position)
							if joint.global_position.distance_to(saved_anchor) < 0.6:
								joint.set_meta("cross_mount", true)
								break
		live_index += 1

	var saved_rings: Array = snapshot.get("o_rings", []) as Array
	for ring_state_value in saved_rings:
		var ring_state: Dictionary = ring_state_value as Dictionary
		var host_index: int = int(ring_state.get("host", -1))
		if host_index < 0 or host_index >= bodies.size():
			continue
		var host: RigidBody3D = bodies[host_index] as RigidBody3D
		if not is_instance_valid(host):
			continue
		var transform: Transform3D = ring_state["transform"]
		var anchor: Vector3 = ring_state.get("anchor", transform.origin)
		var ring: RigidBody3D = _make_o_ring_body(transform)
		var ring_joint: Generic6DOFJoint3D = _make_fixed_joint(host, ring, anchor)
		ring_joint.set_meta("o_ring_mount", true)
		ring.set_meta("host_rod", host)
		ring.set_meta("build_transform", transform)
	var selected_ring_index: int = int(snapshot.get("selected_o_ring", -1))
	if edit_mode and selected_ring_index >= 0 and selected_ring_index < o_ring_stops.size():
		_set_selected(o_ring_stops[selected_ring_index] as RigidBody3D)
	elif not edit_mode:
		_clear_selection_for_create()
	else:
		_refresh_selection_highlight()
	_update_ui()


func _restart_build() -> void:
	_clear_o_ring_bodies()
	_clear_selection_highlight()
	super._restart_build()
	if not edit_mode:
		_clear_selection_for_create()
	_status("Restarted at one editable starting connector")


func _delete_selected() -> void:
	if not edit_mode:
		_status("Switch to EDIT before deleting")
		return
	if is_instance_valid(selected_piece) and str(selected_piece.get_meta("kind", "")) == "o_ring":
		o_ring_stops.erase(selected_piece)
	super._delete_selected()
	_refresh_selection_highlight()


func _release_physics() -> void:
	_prepare_stable_simulation_graph()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not simulating:
		return
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			body.set_meta("seed", false)
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.freeze = false
			body.sleeping = false
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.linear_velocity = Vector3.ZERO
			ring.angular_velocity = Vector3.ZERO
			ring.freeze = false
			ring.sleeping = false
	_clear_selection_highlight()
	_update_ui()
	_status("Physics running — all pieces use the same gravity; %d redundant constraints suppressed" % simulation_disabled_joint_count)


func _reset_pose() -> void:
	super._reset_pose()
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.freeze = true
			ring.linear_velocity = Vector3.ZERO
			ring.angular_velocity = Vector3.ZERO
			ring.global_transform = ring.get_meta("build_transform", ring.global_transform)
	if edit_mode:
		_refresh_selection_highlight()


# -----------------------------------------------------------------------------
# UI state
# -----------------------------------------------------------------------------

func _update_ui() -> void:
	if rod_label != null:
		rod_label.text = str(rod_defs[selected_rod_type]["name"])
	if connector_label != null and selected_connector_type >= 0 and selected_connector_type < connector_defs.size():
		connector_label.text = str(connector_defs[selected_connector_type]["name"])
	if mode_button != null:
		mode_button.text = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	if top_mode_button != null:
		top_mode_button.text = "EDIT" if edit_mode else "CREATE"
	if top_simulate_button != null:
		top_simulate_button.text = "BUILD" if simulating else "SIMULATE"
	if top_redo_button != null:
		top_redo_button.disabled = simulating or state_index < 0 or state_index >= state_history.size() - 1
	if top_undo_button != null:
		top_undo_button.disabled = simulating or state_index <= 0

	var connector_selected: bool = edit_mode and _selected_kind() == "connector" and not simulating
	for button_value in [rot_x_minus, rot_x_plus, rot_y_minus, rot_y_plus, rot_z_minus, rot_z_plus, rot_mount_minus, rot_mount_plus, rot_reset]:
		var button: Button = button_value as Button
		if button != null:
			button.disabled = not connector_selected
	if delete_button != null:
		delete_button.disabled = simulating or not edit_mode or not is_instance_valid(selected_piece)
	var move_enabled: bool = edit_mode and not simulating and is_instance_valid(selected_piece)
	for button_value in [move_left_button, move_right_button, move_forward_button, move_back_button, move_up_button, move_down_button, axle_minus_button, axle_plus_button]:
		var button: Button = button_value as Button
		if button != null:
			button.disabled = not move_enabled
	_refresh_side_panels()


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_015, text]
