extends "res://scripts/main_v017.gd"

const VERSION_020 := "0.2.0"
const ROT_STEP_V020 := PI / 4.0
const SOCKET_CAPTURE_V020 := 0.68
const SOCKET_ALIGN_V020 := 0.955
const CROSS_CAPTURE_V020 := 0.30
const CROSS_PERP_V020 := 0.24
const VALIDATION_EPS_V020 := 0.08

var select_armed_v020: bool = false
var next_piece_uid_v020: int = 1
var next_connection_uid_v020: int = 1
var connections_v020: Array = []
var committing_v020: bool = false
var rebuilding_graph_v020: bool = false
var restoring_v020: bool = false

var select_button_v020: Button
var selected_label_v020: Label
var rot_up_v020: Button
var rot_down_v020: Button
var rot_left_v020: Button
var rot_right_v020: Button
var roll_left_v020: Button
var roll_right_v020: Button
var reset_rotation_v020: Button


# -----------------------------------------------------------------------------
# Startup / IDs
# -----------------------------------------------------------------------------

func _ready() -> void:
	# Keep the legacy edit flag internally true so inherited movement/highlight
	# helpers remain usable, but v0.2 exposes no CREATE/EDIT mode to the user.
	edit_mode = true
	super._ready()
	edit_mode = true
	_ensure_all_piece_uids_v020()
	_rebuild_connection_graph_v020()
	if not is_instance_valid(selected_piece) and not bodies.is_empty():
		_set_selected(bodies[0] as RigidBody3D)
	_refresh_selection_highlight()
	_update_ui()
	_status("Build normally. The newest piece stays selected; press Select once to choose an older piece.")


func _ensure_piece_uid_v020(body: RigidBody3D) -> int:
	if not is_instance_valid(body):
		return -1
	if not body.has_meta("piece_uid_v020"):
		body.set_meta("piece_uid_v020", next_piece_uid_v020)
		next_piece_uid_v020 += 1
	return int(body.get_meta("piece_uid_v020"))


func _ensure_all_piece_uids_v020() -> void:
	var max_uid: int = 0
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var uid: int = _ensure_piece_uid_v020(body)
		max_uid = maxi(max_uid, uid)
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		var ring_uid: int = _ensure_piece_uid_v020(ring)
		max_uid = maxi(max_uid, ring_uid)
	next_piece_uid_v020 = maxi(next_piece_uid_v020, max_uid + 1)


func _make_connector(def_index: int, xform: Transform3D) -> RigidBody3D:
	var body: RigidBody3D = super._make_connector(def_index, xform)
	_ensure_piece_uid_v020(body)
	if not body.has_meta("primary_connection_uid_v020"):
		body.set_meta("primary_connection_uid_v020", -1)
	body.set_meta("rotation_home_basis_v020", body.global_transform.basis)
	return body


func _make_rod(def_index: int, start: Vector3, finish: Vector3) -> RigidBody3D:
	var body: RigidBody3D = super._make_rod(def_index, start, finish)
	_ensure_piece_uid_v020(body)
	return body


func _make_o_ring_body(transform: Transform3D) -> RigidBody3D:
	var ring: RigidBody3D = super._make_o_ring_body(transform)
	_ensure_piece_uid_v020(ring)
	return ring


func _create_fresh_seed() -> void:
	super._create_fresh_seed()
	edit_mode = true
	if is_instance_valid(selected_piece):
		_ensure_piece_uid_v020(selected_piece)
		selected_piece.set_meta("root_piece_v020", true)
		selected_piece.set_meta("primary_connection_uid_v020", -1)
		if str(selected_piece.get_meta("kind", "")) == "connector":
			selected_piece.set_meta("rotation_home_basis_v020", selected_piece.global_transform.basis)
	_refresh_selection_highlight()


# -----------------------------------------------------------------------------
# UI — no CREATE / EDIT mode. Selection is a one-shot explicit action.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	var top: PanelContainer = PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 8.0
	top.offset_right = -8.0
	top.offset_top = 8.0
	top.offset_bottom = 62.0
	top.add_theme_stylebox_override("panel", _panel_style(0.97, 11))
	layer.add_child(top)
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 5)
	top.add_child(top_row)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	top_row.add_child(status_label)

	select_button_v020 = _ui_button("Select", _toggle_select_v020, true)
	select_button_v020.custom_minimum_size.x = 92.0
	top_row.add_child(select_button_v020)
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
	help_button.custom_minimum_size.x = 48.0
	top_row.add_child(help_button)

	# Bottom palette remains always visible. Its arrows are context-sensitive:
	# when the matching kind is selected they edit it; otherwise they choose the
	# next part to place.
	bottom_panel = PanelContainer.new()
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 8.0
	bottom_panel.offset_right = -8.0
	bottom_panel.offset_top = -112.0
	bottom_panel.offset_bottom = -8.0
	bottom_panel.add_theme_stylebox_override("panel", _panel_style(0.97, 12))
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
	mode_button.custom_minimum_size.x = 125.0
	bottom_row.add_child(mode_button)

	var palette_hint: Label = Label.new()
	palette_hint.text = "Newest piece is selected automatically • Select is one-shot • normal taps keep building • O-Ring Stop is in Conn"
	palette_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	palette_hint.add_theme_font_size_override("font_size", 12)
	palette_hint.add_theme_color_override("font_color", Color(0.64, 0.72, 0.80))
	bottom_box.add_child(palette_hint)

	# Right rotation panel: camera-relative arrows for a free/root assembly and
	# explicit roll around the real mount axis for mounted connectors.
	rotation_panel = PanelContainer.new()
	rotation_panel.anchor_left = 1.0
	rotation_panel.anchor_right = 1.0
	rotation_panel.offset_left = -226.0
	rotation_panel.offset_right = -8.0
	rotation_panel.offset_top = 76.0
	rotation_panel.offset_bottom = 470.0
	rotation_panel.add_theme_stylebox_override("panel", _panel_style(0.96, 12))
	layer.add_child(rotation_panel)
	var rotation_outer: VBoxContainer = VBoxContainer.new()
	rotation_outer.add_theme_constant_override("separation", 5)
	rotation_panel.add_child(rotation_outer)
	rotation_collapse_button = _ui_button("ROTATE ▾", _toggle_rotation_panel, true)
	rotation_outer.add_child(rotation_collapse_button)
	rotation_body = VBoxContainer.new()
	rotation_body.add_theme_constant_override("separation", 5)
	rotation_outer.add_child(rotation_body)
	selected_label_v020 = _section_label("Selected: —")
	rotation_body.add_child(selected_label_v020)
	rotation_body.add_child(_section_label("CAMERA-RELATIVE • 45°"))
	rot_up_v020 = _ui_button("↑", func() -> void: _apply_rotation_action_v020("up", 1))
	rotation_body.add_child(rot_up_v020)
	var arrow_row: HBoxContainer = HBoxContainer.new()
	arrow_row.add_theme_constant_override("separation", 4)
	rotation_body.add_child(arrow_row)
	rot_left_v020 = _ui_button("←", func() -> void: _apply_rotation_action_v020("left", 1))
	rot_right_v020 = _ui_button("→", func() -> void: _apply_rotation_action_v020("right", 1))
	arrow_row.add_child(rot_left_v020)
	arrow_row.add_child(rot_right_v020)
	rot_down_v020 = _ui_button("↓", func() -> void: _apply_rotation_action_v020("down", 1))
	rotation_body.add_child(rot_down_v020)
	rotation_body.add_child(_section_label("AROUND REAL MOUNT AXIS"))
	var roll_row: HBoxContainer = HBoxContainer.new()
	roll_row.add_theme_constant_override("separation", 4)
	rotation_body.add_child(roll_row)
	roll_left_v020 = _ui_button("Roll ⟲", func() -> void: _apply_rotation_action_v020("roll", -1))
	roll_right_v020 = _ui_button("Roll ⟳", func() -> void: _apply_rotation_action_v020("roll", 1))
	roll_row.add_child(roll_left_v020)
	roll_row.add_child(roll_right_v020)
	reset_rotation_v020 = _ui_button("Reset Rotation", _reset_rotation_v020)
	rotation_body.add_child(reset_rotation_v020)
	var delete_button_local: Button = _ui_button("Delete Selected", _delete_selected)
	delete_button = delete_button_local
	rotation_body.add_child(delete_button_local)

	# Left move panel remains available to the persistent selected piece.
	move_panel = PanelContainer.new()
	move_panel.offset_left = 8.0
	move_panel.offset_right = 226.0
	move_panel.offset_top = 76.0
	move_panel.offset_bottom = 438.0
	move_panel.add_theme_stylebox_override("panel", _panel_style(0.96, 12))
	layer.add_child(move_panel)
	var move_outer: VBoxContainer = VBoxContainer.new()
	move_outer.add_theme_constant_override("separation", 5)
	move_panel.add_child(move_outer)
	move_collapse_button = _ui_button("MOVE ▾", _toggle_move_panel, true)
	move_outer.add_child(move_collapse_button)
	move_body = VBoxContainer.new()
	move_body.add_theme_constant_override("separation", 5)
	move_outer.add_child(move_body)
	move_body.add_child(_section_label("MOVE SELECTED FIXED COMPONENT"))
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

	# Persistent options modal.
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
	help_panel.anchor_left = 0.14
	help_panel.anchor_right = 0.86
	help_panel.anchor_top = 0.09
	help_panel.anchor_bottom = 0.82
	help_panel.add_theme_stylebox_override("panel", _panel_style(0.988, 14, 0.55))
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
	help.add_theme_font_size_override("font_size", 15)
	help.text = "CONNEX LAB v0.2.0\n\nSELECTION: there is no CREATE/EDIT mode. The newest rod, connector, or O-Ring becomes selected automatically and stays selected. Press Select once, then tap an older piece to change selection. Normal taps keep building and never silently change selection.\n\nCONNECTION GRAPH: every socket, cross, axle, and O-Ring mount is stored as an explicit connection with the exact connector slot and rod endpoint/position. Auto-fused overlaps become the same kind of connection as manually placed ones.\n\nROTATION: mounted connectors rotate from their real mount frame, not their previous local X/Y/Z axes. Roll rotates the selected fixed branch around its incoming rod/cross/axle axis. Camera arrows rotate a free/root assembly. Buttons that would violate a real connection are disabled before you press them. Invalid attempts are true no-ops.\n\nSOCKET: tap a free connector socket to add one rod, or a free rod end to add a connector. AXLE: tap a connector hub to insert a rod or tap any rod to add a sliding connector. CROSS: tap a rod body. O-Ring Stop is selected from Conn and placed on an axle rod.\n\nMOVE and OPTIONS work on the persistent selection; camera reversal and sensitivity still save permanently."
	help_box.add_child(help)
	help_box.add_child(_ui_button("Close", _toggle_help, true))

	_refresh_options_controls()
	_refresh_side_panels()
	_update_ui()


func _toggle_select_v020() -> void:
	if simulating:
		_status("Return to BUILD before selecting")
		return
	select_armed_v020 = not select_armed_v020
	if select_armed_v020:
		_status("Select armed — tap one piece. This is a one-time action.")
	else:
		_status("Select cancelled — current selection unchanged")
	_update_ui()


func _clear_selection_for_create() -> void:
	# Legacy helper intentionally becomes a no-op. v0.2 always keeps selection.
	_update_ui()


func _set_selected(body: RigidBody3D) -> void:
	edit_mode = true
	super._set_selected(body)
	select_armed_v020 = false
	_update_ui()


# -----------------------------------------------------------------------------
# Connection graph
# -----------------------------------------------------------------------------

func _rod_axis_v020(rod: RigidBody3D, transform_override: Transform3D = Transform3D.IDENTITY, use_override: bool = false) -> Vector3:
	var transform_value: Transform3D = transform_override if use_override else rod.global_transform
	var axis: Vector3 = transform_value.basis * Vector3.UP
	if axis.length_squared() < 0.25:
		axis = rod.get_meta("axis", Vector3.UP) as Vector3
	return axis.normalized()


func _rod_end_v020(rod: RigidBody3D, sign_value: int, transform_override: Transform3D = Transform3D.IDENTITY, use_override: bool = false) -> Vector3:
	var transform_value: Transform3D = transform_override if use_override else rod.global_transform
	var length: float = float(rod.get_meta("visual_length", 0.0))
	return transform_value.origin + _rod_axis_v020(rod, transform_value, true) * (length * 0.5 * float(sign_value))


func _socket_world_v020(connector: RigidBody3D, slot: int, transform_override: Transform3D = Transform3D.IDENTITY, use_override: bool = false) -> Dictionary:
	var transform_value: Transform3D = transform_override if use_override else connector.global_transform
	var direction: Vector3 = (transform_value.basis * _slot_dir(slot)).normalized()
	return {"dir": direction, "point": transform_value.origin + direction * CONNECTOR_D}


func _nearest_slot_v020(connector: RigidBody3D, anchor: Vector3) -> int:
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return -1
	var local_point: Vector3 = connector.global_transform.affine_inverse() * anchor
	local_point.y = 0.0
	if local_point.length_squared() < 0.01:
		return -1
	var direction: Vector3 = local_point.normalized()
	var best_slot: int = -1
	var best_dot: float = -2.0
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		var score: float = direction.dot(_slot_dir(slot))
		if score > best_dot:
			best_dot = score
			best_slot = slot
	return best_slot


func _nearest_rod_end_v020(rod: RigidBody3D, anchor: Vector3) -> int:
	var neg_distance: float = _rod_end_v020(rod, -1).distance_to(anchor)
	var pos_distance: float = _rod_end_v020(rod, 1).distance_to(anchor)
	return -1 if neg_distance <= pos_distance else 1


func _joint_connection_kind_v020(joint: Joint3D, body_a: RigidBody3D, body_b: RigidBody3D) -> String:
	if joint.has_meta("connection_kind_v020"):
		return str(joint.get_meta("connection_kind_v020"))
	if str(joint.name).begins_with("AxleJoint"):
		return "axle"
	var kind_a: String = str(body_a.get_meta("kind", ""))
	var kind_b: String = str(body_b.get_meta("kind", ""))
	if kind_a == "o_ring" or kind_b == "o_ring":
		return "o_ring"
	if bool(joint.get_meta("cross_mount", false)):
		return "cross"
	return "socket"


func _connection_pair_v020(body_a: RigidBody3D, body_b: RigidBody3D) -> Dictionary:
	var kind_a: String = str(body_a.get_meta("kind", ""))
	var kind_b: String = str(body_b.get_meta("kind", ""))
	var connector: RigidBody3D = null
	var rod: RigidBody3D = null
	var ring: RigidBody3D = null
	if kind_a == "connector":
		connector = body_a
	elif kind_b == "connector":
		connector = body_b
	if kind_a == "rod":
		rod = body_a
	elif kind_b == "rod":
		rod = body_b
	if kind_a == "o_ring":
		ring = body_a
	elif kind_b == "o_ring":
		ring = body_b
	return {"connector": connector, "rod": rod, "ring": ring}


func _tag_connection_v020(joint: Joint3D, kind: String, connector: RigidBody3D, rod: RigidBody3D, slot: int = -1, rod_end: int = 0, host_along: float = 0.0, ring: RigidBody3D = null, primary: bool = false) -> int:
	var uid: int
	if joint.has_meta("connection_uid_v020"):
		uid = int(joint.get_meta("connection_uid_v020"))
	else:
		uid = next_connection_uid_v020
		next_connection_uid_v020 += 1
		joint.set_meta("connection_uid_v020", uid)
	joint.set_meta("connection_kind_v020", kind)
	if is_instance_valid(connector):
		joint.set_meta("connector_uid_v020", _ensure_piece_uid_v020(connector))
	if is_instance_valid(rod):
		joint.set_meta("rod_uid_v020", _ensure_piece_uid_v020(rod))
	if is_instance_valid(ring):
		joint.set_meta("ring_uid_v020", _ensure_piece_uid_v020(ring))
	joint.set_meta("connector_slot_v020", slot)
	joint.set_meta("rod_end_v020", rod_end)
	joint.set_meta("host_along_v020", host_along)
	if kind == "cross":
		joint.set_meta("cross_mount", true)
	if primary and is_instance_valid(connector):
		connector.set_meta("primary_connection_uid_v020", uid)
	_measure_connection_rest_v020(joint, kind, connector, rod, slot, rod_end, host_along, ring)
	return uid


func _measure_connection_rest_v020(joint: Joint3D, kind: String, connector: RigidBody3D, rod: RigidBody3D, slot: int, rod_end: int, host_along: float, ring: RigidBody3D) -> void:
	if joint.has_meta("rest_gap_v020"):
		return
	var gap: float = 0.0
	var align_value: float = 1.0
	var perp_value: float = 0.0
	var plane_value: float = 0.0
	if kind == "socket" and is_instance_valid(connector) and is_instance_valid(rod) and slot >= 0 and rod_end != 0:
		var socket: Dictionary = _socket_world_v020(connector, slot)
		var mouth: Vector3 = socket["point"] as Vector3
		var end_point: Vector3 = _rod_end_v020(rod, rod_end)
		var outward: Vector3 = _rod_axis_v020(rod) * float(rod_end)
		gap = mouth.distance_to(end_point)
		align_value = (socket["dir"] as Vector3).dot(-outward)
	elif kind == "cross" and is_instance_valid(connector) and is_instance_valid(rod) and slot >= 0:
		var cross_socket: Dictionary = _socket_world_v020(connector, slot)
		var host_axis: Vector3 = _rod_axis_v020(rod)
		var host_point: Vector3 = rod.global_position + host_axis * host_along
		gap = (cross_socket["point"] as Vector3).distance_to(host_point)
		perp_value = absf((cross_socket["dir"] as Vector3).dot(host_axis))
		plane_value = absf((connector.global_transform.basis * Vector3.UP).normalized().dot(host_axis))
	elif kind == "axle" and is_instance_valid(connector) and is_instance_valid(rod):
		var axle_axis: Vector3 = _rod_axis_v020(rod)
		var connector_to_line: Vector3 = connector.global_position - rod.global_position
		var projected: Vector3 = axle_axis * connector_to_line.dot(axle_axis)
		gap = (connector_to_line - projected).length()
		align_value = absf((connector.global_transform.basis * Vector3.UP).normalized().dot(axle_axis))
	elif kind == "o_ring" and is_instance_valid(ring) and is_instance_valid(rod):
		var ring_axis: Vector3 = _rod_axis_v020(rod)
		var ring_delta: Vector3 = ring.global_position - rod.global_position
		var ring_projected: Vector3 = ring_axis * ring_delta.dot(ring_axis)
		gap = (ring_delta - ring_projected).length()
		align_value = absf((ring.global_transform.basis * Vector3.UP).normalized().dot(ring_axis))
	joint.set_meta("rest_gap_v020", gap)
	joint.set_meta("rest_align_v020", align_value)
	joint.set_meta("rest_perp_v020", perp_value)
	joint.set_meta("rest_plane_v020", plane_value)


func _rebuild_connection_graph_v020(sync_occupancy: bool = true) -> void:
	if rebuilding_graph_v020:
		return
	rebuilding_graph_v020 = true
	connections_v020.clear()
	_ensure_all_piece_uids_v020()
	var max_connection_uid: int = 0

	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		var nodes: Array = _joint_nodes(joint)
		var body_a: RigidBody3D = nodes[0] as RigidBody3D
		var body_b: RigidBody3D = nodes[1] as RigidBody3D
		if not is_instance_valid(body_a) or not is_instance_valid(body_b):
			continue
		var pair: Dictionary = _connection_pair_v020(body_a, body_b)
		var connector: RigidBody3D = pair["connector"] as RigidBody3D
		var rod: RigidBody3D = pair["rod"] as RigidBody3D
		var ring: RigidBody3D = pair["ring"] as RigidBody3D
		var kind: String = _joint_connection_kind_v020(joint, body_a, body_b)
		var slot: int = int(joint.get_meta("connector_slot_v020", -1))
		var rod_end: int = int(joint.get_meta("rod_end_v020", 0))
		var host_along: float = float(joint.get_meta("host_along_v020", 0.0))

		if (kind == "socket" or kind == "cross" or kind == "axle") and (not is_instance_valid(connector) or not is_instance_valid(rod)):
			continue
		if kind == "o_ring" and (not is_instance_valid(ring) or not is_instance_valid(rod)):
			continue
		if slot < 0 and is_instance_valid(connector) and (kind == "socket" or kind == "cross"):
			slot = _nearest_slot_v020(connector, joint.global_position)
		if rod_end == 0 and is_instance_valid(rod) and kind == "socket":
			rod_end = _nearest_rod_end_v020(rod, joint.global_position)
		if is_instance_valid(rod) and (kind == "cross" or kind == "o_ring") and not joint.has_meta("host_along_v020"):
			host_along = (joint.global_position - rod.global_position).dot(_rod_axis_v020(rod))

		var uid: int = _tag_connection_v020(joint, kind, connector, rod, slot, rod_end, host_along, ring, false)
		max_connection_uid = maxi(max_connection_uid, uid)
		connections_v020.append({
			"uid": uid,
			"kind": kind,
			"joint": joint,
			"a": body_a,
			"b": body_b,
			"connector": connector,
			"rod": rod,
			"ring": ring,
			"slot": slot,
			"rod_end": rod_end,
			"host_along": host_along,
			"rest_gap": float(joint.get_meta("rest_gap_v020", 0.0)),
			"rest_align": float(joint.get_meta("rest_align_v020", 1.0)),
			"rest_perp": float(joint.get_meta("rest_perp_v020", 0.0)),
			"rest_plane": float(joint.get_meta("rest_plane_v020", 0.0)),
		})

	next_connection_uid_v020 = maxi(next_connection_uid_v020, max_connection_uid + 1)
	if sync_occupancy:
		_sync_occupancy_from_graph_v020()
	rebuilding_graph_v020 = false


func _sync_occupancy_from_graph_v020() -> void:
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var kind: String = str(body.get_meta("kind", ""))
		if kind == "connector":
			body.set_meta("occupied", {})
			body.set_meta("axle_occupied", false)
		elif kind == "rod":
			body.set_meta("end_occupied", {})
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var kind_record: String = str(record["kind"])
		var connector: RigidBody3D = record["connector"] as RigidBody3D
		var rod: RigidBody3D = record["rod"] as RigidBody3D
		if kind_record == "socket":
			if is_instance_valid(connector) and int(record["slot"]) >= 0:
				_set_connector_occupied(connector, int(record["slot"]), true)
			if is_instance_valid(rod) and int(record["rod_end"]) != 0:
				_set_rod_end_occupied(rod, int(record["rod_end"]), true)
		elif kind_record == "cross":
			if is_instance_valid(connector) and int(record["slot"]) >= 0:
				_set_connector_occupied(connector, int(record["slot"]), true)
		elif kind_record == "axle":
			if is_instance_valid(connector):
				connector.set_meta("axle_occupied", true)


func _connections_for_piece_v020(piece: RigidBody3D) -> Array:
	var result: Array = []
	if not is_instance_valid(piece):
		return result
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		if record["a"] == piece or record["b"] == piece:
			result.append(record)
	return result


func _record_by_uid_v020(uid: int) -> Dictionary:
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		if int(record["uid"]) == uid:
			return record
	return {}


func _other_body_v020(record: Dictionary, piece: RigidBody3D) -> RigidBody3D:
	var a: RigidBody3D = record["a"] as RigidBody3D
	var b: RigidBody3D = record["b"] as RigidBody3D
	return b if a == piece else a


func _primary_record_for_connector_v020(connector: RigidBody3D) -> Dictionary:
	if not is_instance_valid(connector):
		return {}
	var primary_uid: int = int(connector.get_meta("primary_connection_uid_v020", -1))
	if primary_uid >= 0:
		var primary: Dictionary = _record_by_uid_v020(primary_uid)
		if not primary.is_empty() and (primary["a"] == connector or primary["b"] == connector):
			return primary
	if bool(connector.get_meta("root_piece_v020", false)):
		return {}
	var attached: Array = _connections_for_piece_v020(connector)
	if attached.size() == 1:
		var only: Dictionary = attached[0] as Dictionary
		connector.set_meta("primary_connection_uid_v020", int(only["uid"]))
		return only
	return {}


func _fixed_connection_kind_v020(kind: String) -> bool:
	return kind == "socket" or kind == "cross" or kind == "o_ring"


func _fixed_component_v020(seed: RigidBody3D, excluded_connection_uid: int = -1) -> Array:
	var result: Array = []
	if not is_instance_valid(seed):
		return result
	var queue: Array = [seed]
	var seen: Dictionary = {seed.get_instance_id(): true}
	while not queue.is_empty():
		var current: RigidBody3D = queue.pop_front() as RigidBody3D
		result.append(current)
		for record_value in connections_v020:
			var record: Dictionary = record_value as Dictionary
			if int(record["uid"]) == excluded_connection_uid:
				continue
			if not _fixed_connection_kind_v020(str(record["kind"])):
				continue
			if record["a"] != current and record["b"] != current:
				continue
			var other: RigidBody3D = _other_body_v020(record, current)
			if not is_instance_valid(other):
				continue
			if not seen.has(other.get_instance_id()):
				seen[other.get_instance_id()] = true
				queue.append(other)
	return result


func _component_has_piece_v020(component: Array, piece: RigidBody3D) -> bool:
	for body_value in component:
		if body_value == piece:
			return true
	return false


# -----------------------------------------------------------------------------
# Placement — all creation paths produce exact connection records and select the
# newly-created piece automatically.
# -----------------------------------------------------------------------------

func _preferred_camera_perpendicular_v020(axis: Vector3) -> Vector3:
	var preferred: Vector3 = camera.global_transform.basis.x
	preferred -= axis * preferred.dot(axis)
	if preferred.length_squared() < 0.02:
		preferred = camera.global_transform.basis.y
		preferred -= axis * preferred.dot(axis)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.UP)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.RIGHT)
	return preferred.normalized()


func _basis_align_direction_v020(local_direction: Vector3, world_direction: Vector3, preferred_local_up_world: Vector3) -> Basis:
	var target: Vector3 = world_direction.normalized()
	var base: Basis = Basis(Quaternion(local_direction.normalized(), target))
	var current_up: Vector3 = (base * Vector3.UP).normalized()
	var preferred: Vector3 = preferred_local_up_world - target * preferred_local_up_world.dot(target)
	if preferred.length_squared() < 0.02:
		preferred = _preferred_camera_perpendicular_v020(target)
	preferred = preferred.normalized()
	var angle: float = current_up.signed_angle_to(preferred, target)
	return (Basis(target, angle) * base).orthonormalized()


func _basis_for_axle_v020(axis: Vector3) -> Basis:
	var target_axis: Vector3 = axis.normalized()
	var base: Basis = Basis(Quaternion(Vector3.UP, target_axis))
	var current_right: Vector3 = (base * Vector3.RIGHT).normalized()
	var preferred_right: Vector3 = _preferred_camera_perpendicular_v020(target_axis)
	var angle: float = current_right.signed_angle_to(preferred_right, target_axis)
	return (Basis(target_axis, angle) * base).orthonormalized()


func _basis_for_cross_v020(local_slot: Vector3, host_axis: Vector3, radial: Vector3) -> Basis:
	var radial_n: Vector3 = radial.normalized()
	var host_n: Vector3 = host_axis.normalized()
	var base: Basis = Basis(Quaternion(local_slot.normalized(), radial_n))
	var local_tangent: Vector3 = Vector3.UP.cross(local_slot).normalized()
	var current_tangent: Vector3 = (base * local_tangent).normalized()
	var target_tangent: Vector3 = host_n if current_tangent.dot(host_n) >= current_tangent.dot(-host_n) else -host_n
	var angle: float = current_tangent.signed_angle_to(target_tangent, radial_n)
	return (Basis(radial_n, angle) * base).orthonormalized()


func _extend_socket(connector: RigidBody3D, slot: int) -> void:
	if simulating or slot < 0:
		return
	_rebuild_connection_graph_v020()
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	if occupied.has(slot):
		_status("That connector socket already has a rod")
		return
	var rod_len: float = float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var socket: Dictionary = _socket_world_v020(connector, slot)
	var start: Vector3 = socket["point"] as Vector3
	var direction: Vector3 = socket["dir"] as Vector3
	var finish: Vector3 = start + direction * rod_len
	var rod: RigidBody3D = _make_rod(selected_rod_type, start, finish)
	var joint: Generic6DOFJoint3D = _make_fixed_joint(connector, rod, start)
	_tag_connection_v020(joint, "socket", connector, rod, slot, -1, 0.0, null, false)
	_set_connector_occupied(connector, slot, true)
	_set_rod_end_occupied(rod, -1, true)
	rod.set_meta("build_transform", rod.global_transform)
	_set_selected(rod)
	_commit_state()
	_status("Rod added and selected. A compatible overlapping free end/socket will fuse automatically.")


func _attach_connector_to_rod_end(rod: RigidBody3D, sign_value: int) -> void:
	_rebuild_connection_graph_v020()
	var end_occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	if end_occupied.has(sign_value):
		_status("That rod end is already connected")
		return
	if selected_connector_type == o_ring_index:
		_status("O-Ring Stop belongs on an axle rod, not a rod end")
		return
	var def_index: int = selected_connector_type
	var slots: Array = connector_defs[def_index]["slots"] as Array
	if slots.is_empty():
		return
	var slot: int = int(slots[0])
	var outward: Vector3 = _rod_axis_v020(rod) * float(sign_value)
	var end_pos: Vector3 = _rod_end_v020(rod, sign_value)
	var world_socket_dir: Vector3 = -outward
	var basis: Basis = _basis_align_direction_v020(_slot_dir(slot), world_socket_dir, camera.global_transform.basis.y)
	var center: Vector3 = end_pos - world_socket_dir * CONNECTOR_D
	var connector: RigidBody3D = _make_connector(def_index, Transform3D(basis, center))
	connector.set_meta("rotation_home_basis_v020", basis)
	connector.set_meta("rotation_home_transform", connector.global_transform)
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, end_pos)
	var primary_uid: int = _tag_connection_v020(joint, "socket", connector, rod, slot, sign_value, 0.0, null, true)
	connector.set_meta("primary_connection_uid_v020", primary_uid)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	connector.set_meta("build_transform", connector.global_transform)
	last_placed_connector = connector
	_set_selected(connector)
	_commit_state()
	_status("Connector placed and selected. Roll now uses the incoming rod as its real pivot axis.")


func _insert_axle(connector: RigidBody3D) -> void:
	_rebuild_connection_graph_v020()
	for record_value in _connections_for_piece_v020(connector):
		var record: Dictionary = record_value as Dictionary
		if str(record["kind"]) == "axle":
			_status("That connector hub already contains an axle")
			return
	var rod_len: float = float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var axis: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
	var rod: RigidBody3D = _make_rod(selected_rod_type, connector.global_position - axis * rod_len * 0.5, connector.global_position + axis * rod_len * 0.5)
	var joint: Generic6DOFJoint3D = _make_axle_joint(connector, rod)
	_tag_connection_v020(joint, "axle", connector, rod, -1, 0, 0.0, null, false)
	connector.set_meta("axle_occupied", true)
	rod.set_meta("build_transform", rod.global_transform)
	_set_selected(rod)
	_commit_state()
	_status("Axle rod inserted and selected")


func _place_connector_on_rod_as_axle(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if selected_connector_type == o_ring_index:
		_place_o_ring_on_rod(rod, hit_pos)
		return
	var axis: Vector3 = _rod_axis_v020(rod)
	var half_len: float = maxf(0.1, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.45)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = _basis_for_axle_v020(axis)
	var connector: RigidBody3D = _make_connector(selected_connector_type, Transform3D(basis, center))
	connector.set_meta("rotation_home_basis_v020", basis)
	connector.set_meta("rotation_home_transform", connector.global_transform)
	var joint: Generic6DOFJoint3D = _make_axle_joint(connector, rod)
	var primary_uid: int = _tag_connection_v020(joint, "axle", connector, rod, -1, 0, along, null, true)
	connector.set_meta("primary_connection_uid_v020", primary_uid)
	connector.set_meta("axle_occupied", true)
	connector.set_meta("axle_host_rod", rod)
	connector.set_meta("build_transform", connector.global_transform)
	last_placed_connector = connector
	_set_selected(connector)
	_commit_state()
	_status("Sliding axle connector placed and selected")


func _cross_snap_v015(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if selected_connector_type == o_ring_index:
		_status("O-Ring Stop is an axle stop, not a cross connector")
		return
	var slots: Array = connector_defs[selected_connector_type]["slots"] as Array
	if slots.is_empty():
		return
	var slot: int = int(slots[0])
	var axis: Vector3 = _rod_axis_v020(rod)
	var radial: Vector3 = _preferred_camera_perpendicular_v020(axis)
	var basis: Basis = _basis_for_cross_v020(_slot_dir(slot), axis, radial)
	var actual_radial: Vector3 = (basis * _slot_dir(slot)).normalized()
	var half_len: float = maxf(0.1, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.42)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var snap_point: Vector3 = rod.global_position + axis * along
	var center: Vector3 = snap_point - actual_radial * CONNECTOR_D
	var connector: RigidBody3D = _make_connector(selected_connector_type, Transform3D(basis, center))
	connector.set_meta("rotation_home_basis_v020", basis)
	connector.set_meta("rotation_home_transform", connector.global_transform)
	connector.set_meta("cross_mount", true)
	connector.set_meta("cross_host_rod", rod)
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, snap_point)
	var primary_uid: int = _tag_connection_v020(joint, "cross", connector, rod, slot, 0, along, null, true)
	connector.set_meta("primary_connection_uid_v020", primary_uid)
	_set_connector_occupied(connector, slot, true)
	connector.set_meta("build_transform", connector.global_transform)
	last_placed_connector = connector
	_set_selected(connector)
	_commit_state()
	_status("Cross connector placed and selected. Roll follows the actual cross rod axis.")


func _place_o_ring_on_rod(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if not _rod_is_axle(rod):
		_status("O-Ring Stop can only be placed on a rod already used as an axle")
		return
	var axis: Vector3 = _rod_axis_v020(rod)
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.40)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = _basis_for_axle_v020(axis)
	var ring: RigidBody3D = _make_o_ring_body(Transform3D(basis, center))
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, ring, center)
	_tag_connection_v020(joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	_set_selected(ring)
	_commit_state()
	_status("O-Ring Stop placed and selected")


# -----------------------------------------------------------------------------
# Normal taps build. Only the one-shot Select action changes selection by tapping.
# -----------------------------------------------------------------------------

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

	if select_armed_v020:
		_set_selected(body)
		_status("Selected %s" % _piece_display_name(body))
		return

	var kind: String = str(body.get_meta("kind", ""))
	if selected_connector_type == o_ring_index:
		if kind == "rod":
			_place_o_ring_on_rod(body, hit["position"] as Vector3)
		else:
			_status("O-Ring Stop selected — tap an axle rod")
		return

	if attach_mode == 0:
		if kind == "connector":
			var slot: int = _select_slot_strict(body, hit["position"] as Vector3)
			if slot >= 0:
				_extend_socket(body, slot)
			elif slot == -3:
				_status("That socket is already occupied")
			else:
				_status("SOCKET: tap a free outer socket, or press Select to choose this connector")
		elif kind == "rod":
			var end_sign: int = _rod_end_hit(body, hit["position"] as Vector3)
			if end_sign != 0:
				_attach_connector_to_rod_end(body, end_sign)
			else:
				_status("SOCKET: tap a free rod end, or press Select to choose this rod")
		return

	if attach_mode == 1:
		if kind == "connector":
			_insert_axle(body)
		elif kind == "rod":
			_place_connector_on_rod_as_axle(body, hit["position"] as Vector3)
		else:
			_status("AXLE: tap a connector hub or an existing rod")
		return

	if attach_mode == 2:
		if kind == "rod":
			_cross_snap_v015(body, hit["position"] as Vector3)
		else:
			_status("CROSS: tap a rod body")


# -----------------------------------------------------------------------------
# Auto-connect. Manual and automatic matches use the exact same connection type
# and metadata. Rod-end/socket matches have priority over body cross matches.
# -----------------------------------------------------------------------------

func _fixed_pair_exists_v020(a: RigidBody3D, b: RigidBody3D) -> bool:
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		if not _fixed_connection_kind_v020(str(record["kind"])):
			continue
		if (record["a"] == a and record["b"] == b) or (record["a"] == b and record["b"] == a):
			return true
	return false


func _best_socket_for_end_v020(rod: RigidBody3D, sign_value: int) -> Dictionary:
	var rod_occ: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	if rod_occ.has(sign_value):
		return {}
	var end_point: Vector3 = _rod_end_v020(rod, sign_value)
	var outward: Vector3 = _rod_axis_v020(rod) * float(sign_value)
	var best: Dictionary = {}
	var best_distance: float = SOCKET_CAPTURE_V020
	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		if _fixed_pair_exists_v020(rod, connector):
			continue
		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size():
			continue
		var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			if occupied.has(slot):
				continue
			var socket: Dictionary = _socket_world_v020(connector, slot)
			var socket_dir: Vector3 = socket["dir"] as Vector3
			if socket_dir.dot(-outward) < SOCKET_ALIGN_V020:
				continue
			var distance: float = (socket["point"] as Vector3).distance_to(end_point)
			if distance <= best_distance:
				best_distance = distance
				best = {"connector": connector, "slot": slot, "distance": distance, "point": socket["point"], "rod_point": end_point}
	return best


func _auto_connect_end_v020(rod: RigidBody3D, sign_value: int) -> bool:
	var target: Dictionary = _best_socket_for_end_v020(rod, sign_value)
	if target.is_empty():
		return false
	var connector: RigidBody3D = target["connector"] as RigidBody3D
	var slot: int = int(target["slot"])
	var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
	var anchor: Vector3 = ((target["point"] as Vector3) + (target["rod_point"] as Vector3)) * 0.5
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
	_tag_connection_v020(joint, "socket", connector, rod, slot, sign_value, 0.0, null, primary)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	return true


func _auto_connect_crosses_v020() -> int:
	var count: int = 0
	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size():
			continue
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
			if occupied.has(slot):
				continue
			var socket: Dictionary = _socket_world_v020(connector, slot)
			var mouth: Vector3 = socket["point"] as Vector3
			var slot_dir: Vector3 = socket["dir"] as Vector3
			var best_rod: RigidBody3D = null
			var best_along: float = 0.0
			var best_distance: float = CROSS_CAPTURE_V020
			for rod_value in bodies:
				var rod: RigidBody3D = rod_value as RigidBody3D
				if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
					continue
				if _fixed_pair_exists_v020(rod, connector):
					continue
				var axis: Vector3 = _rod_axis_v020(rod)
				if absf(axis.dot(slot_dir)) > CROSS_PERP_V020:
					continue
				var half_len: float = maxf(0.0, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.50)
				var along: float = clampf((mouth - rod.global_position).dot(axis), -half_len, half_len)
				var closest: Vector3 = rod.global_position + axis * along
				var distance: float = closest.distance_to(mouth)
				if distance <= best_distance:
					best_distance = distance
					best_rod = rod
					best_along = along
			if is_instance_valid(best_rod):
				var host_point: Vector3 = best_rod.global_position + _rod_axis_v020(best_rod) * best_along
				var anchor: Vector3 = (mouth + host_point) * 0.5
				var joint: Generic6DOFJoint3D = _make_fixed_joint(best_rod, connector, anchor)
				var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
				var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
				_tag_connection_v020(joint, "cross", connector, best_rod, slot, 0, best_along, null, primary)
				_set_connector_occupied(connector, slot, true)
				count += 1
	return count


func _auto_connect_all_v020() -> int:
	if restoring_v020 or restoring_state:
		return 0
	_rebuild_connection_graph_v020()
	var total: int = 0
	for _pass in range(5):
		var pass_count: int = 0
		for body_value in bodies:
			var rod: RigidBody3D = body_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			if _auto_connect_end_v020(rod, -1):
				pass_count += 1
			if _auto_connect_end_v020(rod, 1):
				pass_count += 1
		if pass_count > 0:
			_rebuild_connection_graph_v020()
		var cross_count: int = _auto_connect_crosses_v020()
		pass_count += cross_count
		if cross_count > 0:
			_rebuild_connection_graph_v020()
		total += pass_count
		if pass_count == 0:
			break
	return total


# v0.1.7 calls this from its commit path. Route it to the v0.2 graph matcher.
func _auto_fuse_all_v017() -> int:
	if committing_v020:
		return 0
	return _auto_connect_all_v020()


func _auto_fuse_all() -> bool:
	return _auto_connect_all_v020() > 0


# -----------------------------------------------------------------------------
# Connection-first rotation solver
# -----------------------------------------------------------------------------

func _transform_for_v020(body: RigidBody3D, transforms: Dictionary) -> Transform3D:
	var key: int = body.get_instance_id()
	if transforms.has(key):
		return transforms[key] as Transform3D
	return body.global_transform


func _record_anchor_v020(record: Dictionary, transforms: Dictionary = {}) -> Vector3:
	var kind: String = str(record["kind"])
	var connector: RigidBody3D = record["connector"] as RigidBody3D
	var rod: RigidBody3D = record["rod"] as RigidBody3D
	if kind == "socket" and is_instance_valid(rod):
		var rod_tf: Transform3D = _transform_for_v020(rod, transforms)
		return _rod_end_v020(rod, int(record["rod_end"]), rod_tf, true)
	if kind == "cross" and is_instance_valid(rod):
		var cross_tf: Transform3D = _transform_for_v020(rod, transforms)
		var axis: Vector3 = _rod_axis_v020(rod, cross_tf, true)
		return cross_tf.origin + axis * float(record["host_along"])
	if kind == "axle" and is_instance_valid(connector):
		return _transform_for_v020(connector, transforms).origin
	if kind == "o_ring":
		var ring: RigidBody3D = record["ring"] as RigidBody3D
		if is_instance_valid(ring):
			return _transform_for_v020(ring, transforms).origin
	var joint: Joint3D = record["joint"] as Joint3D
	return joint.global_position if is_instance_valid(joint) else Vector3.ZERO


func _record_axis_v020(record: Dictionary, transforms: Dictionary = {}) -> Vector3:
	var rod: RigidBody3D = record["rod"] as RigidBody3D
	if is_instance_valid(rod):
		var rod_tf: Transform3D = _transform_for_v020(rod, transforms)
		return _rod_axis_v020(rod, rod_tf, true)
	return Vector3.UP


func _validate_record_v020(record: Dictionary, transforms: Dictionary) -> Dictionary:
	var kind: String = str(record["kind"])
	var connector: RigidBody3D = record["connector"] as RigidBody3D
	var rod: RigidBody3D = record["rod"] as RigidBody3D
	var ring: RigidBody3D = record["ring"] as RigidBody3D
	var rest_gap: float = float(record.get("rest_gap", 0.0))
	var gap_limit: float = maxf(0.14, rest_gap + VALIDATION_EPS_V020)
	var rest_align: float = float(record.get("rest_align", 1.0))
	var align_limit: float = minf(0.99, maxf(0.94, rest_align - 0.01))

	if kind == "socket":
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			return {"valid": false, "reason": "missing socket body"}
		var slot: int = int(record["slot"])
		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size() or not (slot in (connector_defs[def_index]["slots"] as Array)):
			return {"valid": false, "reason": "the recorded socket no longer exists"}
		var connector_tf: Transform3D = _transform_for_v020(connector, transforms)
		var rod_tf: Transform3D = _transform_for_v020(rod, transforms)
		var socket: Dictionary = _socket_world_v020(connector, slot, connector_tf, true)
		var end_point: Vector3 = _rod_end_v020(rod, int(record["rod_end"]), rod_tf, true)
		var outward: Vector3 = _rod_axis_v020(rod, rod_tf, true) * float(int(record["rod_end"]))
		if (socket["point"] as Vector3).distance_to(end_point) > gap_limit:
			return {"valid": false, "reason": "a rod end would leave its exact socket"}
		if (socket["dir"] as Vector3).dot(-outward) < align_limit:
			return {"valid": false, "reason": "a rod would no longer point into its exact socket"}
		return {"valid": true}

	if kind == "cross":
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			return {"valid": false, "reason": "missing cross body"}
		var cross_slot: int = int(record["slot"])
		var cross_tf: Transform3D = _transform_for_v020(connector, transforms)
		var host_tf: Transform3D = _transform_for_v020(rod, transforms)
		var cross_socket: Dictionary = _socket_world_v020(connector, cross_slot, cross_tf, true)
		var host_axis: Vector3 = _rod_axis_v020(rod, host_tf, true)
		var host_point: Vector3 = host_tf.origin + host_axis * float(record["host_along"])
		if (cross_socket["point"] as Vector3).distance_to(host_point) > gap_limit:
			return {"valid": false, "reason": "the cross snap point would separate"}
		var perp_limit: float = maxf(0.10, float(record.get("rest_perp", 0.0)) + 0.035)
		if absf((cross_socket["dir"] as Vector3).dot(host_axis)) > perp_limit:
			return {"valid": false, "reason": "the socket would stop crossing the rod at 90°"}
		var plane_limit: float = maxf(0.10, float(record.get("rest_plane", 0.0)) + 0.035)
		var normal: Vector3 = (cross_tf.basis * Vector3.UP).normalized()
		if absf(normal.dot(host_axis)) > plane_limit:
			return {"valid": false, "reason": "the cross rod would leave the connector plane"}
		return {"valid": true}

	if kind == "axle":
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			return {"valid": false, "reason": "missing axle body"}
		var axle_connector_tf: Transform3D = _transform_for_v020(connector, transforms)
		var axle_rod_tf: Transform3D = _transform_for_v020(rod, transforms)
		var axle_axis: Vector3 = _rod_axis_v020(rod, axle_rod_tf, true)
		var hub_axis: Vector3 = (axle_connector_tf.basis * Vector3.UP).normalized()
		if absf(hub_axis.dot(axle_axis)) < align_limit:
			return {"valid": false, "reason": "the hub would no longer align with the axle"}
		var delta: Vector3 = axle_connector_tf.origin - axle_rod_tf.origin
		var radial: Vector3 = delta - axle_axis * delta.dot(axle_axis)
		if radial.length() > gap_limit:
			return {"valid": false, "reason": "the hub would move sideways off the axle"}
		return {"valid": true}

	if kind == "o_ring":
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			return {"valid": false, "reason": "missing O-Ring host"}
		var ring_tf: Transform3D = _transform_for_v020(ring, transforms)
		var ring_rod_tf: Transform3D = _transform_for_v020(rod, transforms)
		var ring_axis: Vector3 = _rod_axis_v020(rod, ring_rod_tf, true)
		var ring_normal: Vector3 = (ring_tf.basis * Vector3.UP).normalized()
		if absf(ring_normal.dot(ring_axis)) < align_limit:
			return {"valid": false, "reason": "the O-Ring would tilt off its axle"}
		var ring_delta: Vector3 = ring_tf.origin - ring_rod_tf.origin
		var ring_radial: Vector3 = ring_delta - ring_axis * ring_delta.dot(ring_axis)
		if ring_radial.length() > gap_limit:
			return {"valid": false, "reason": "the O-Ring would leave its axle"}
		return {"valid": true}

	return {"valid": true}


func _validate_transforms_v020(transforms: Dictionary) -> Dictionary:
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var result: Dictionary = _validate_record_v020(record, transforms)
		if not bool(result.get("valid", false)):
			return result
	return {"valid": true}


func _rotation_delta_map_v020(component: Array, axis: Vector3, angle: float, anchor: Vector3) -> Dictionary:
	var transforms: Dictionary = {}
	var rotation: Basis = Basis(axis.normalized(), angle)
	for body_value in component:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var old_tf: Transform3D = body.global_transform
		var new_origin: Vector3 = anchor + rotation * (old_tf.origin - anchor)
		var new_basis: Basis = (rotation * old_tf.basis).orthonormalized()
		transforms[body.get_instance_id()] = Transform3D(new_basis, new_origin)
	return transforms


func _rigid_delta_map_v020(component: Array, selected_current: Transform3D, selected_target: Transform3D) -> Dictionary:
	var transforms: Dictionary = {}
	var delta: Transform3D = selected_target * selected_current.affine_inverse()
	for body_value in component:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			transforms[body.get_instance_id()] = delta * body.global_transform
	return transforms


func _rotation_preview_v020(action: String, direction_sign: int = 1) -> Dictionary:
	if simulating or _selected_kind() != "connector" or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a connector"}
	_rebuild_connection_graph_v020()
	var connector: RigidBody3D = selected_piece
	var pivot: Dictionary = _primary_record_for_connector_v020(connector)
	var excluded_uid: int = int(pivot["uid"]) if not pivot.is_empty() and _fixed_connection_kind_v020(str(pivot["kind"])) else -1
	var component: Array = _fixed_component_v020(connector, excluded_uid)

	if not pivot.is_empty() and excluded_uid >= 0:
		var pivot_other: RigidBody3D = _other_body_v020(pivot, connector)
		if _component_has_piece_v020(component, pivot_other):
			return {"valid": false, "reason": "this mount is part of a closed rigid loop"}

	var anchor: Vector3 = connector.global_position
	var axis: Vector3 = Vector3.UP
	var angle: float = ROT_STEP_V020 * float(direction_sign)

	if not pivot.is_empty():
		if action != "roll":
			return {"valid": false, "reason": "mounted connector — use Roll around its real mount axis"}
		anchor = _record_anchor_v020(pivot)
		axis = _record_axis_v020(pivot)
	else:
		if action == "up":
			axis = camera.global_transform.basis.x.normalized()
			angle = -ROT_STEP_V020
		elif action == "down":
			axis = camera.global_transform.basis.x.normalized()
			angle = ROT_STEP_V020
		elif action == "left":
			axis = camera.global_transform.basis.y.normalized()
			angle = ROT_STEP_V020
		elif action == "right":
			axis = camera.global_transform.basis.y.normalized()
			angle = -ROT_STEP_V020
		elif action == "roll":
			axis = (connector.global_transform.basis * Vector3.UP).normalized()
			angle = ROT_STEP_V020 * float(direction_sign)
		else:
			return {"valid": false, "reason": "unknown rotation"}

	var transforms: Dictionary = _rotation_delta_map_v020(component, axis, angle, anchor)
	var validation: Dictionary = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return validation
	return {"valid": true, "transforms": transforms, "component": component, "pivot": pivot, "action": action}


func _reset_preview_v020() -> Dictionary:
	if simulating or _selected_kind() != "connector" or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a connector"}
	_rebuild_connection_graph_v020()
	var connector: RigidBody3D = selected_piece
	var current: Transform3D = connector.global_transform
	var home_basis: Basis = connector.get_meta("rotation_home_basis_v020", connector.get_meta("rotation_home_basis", current.basis)) as Basis
	var pivot: Dictionary = _primary_record_for_connector_v020(connector)
	var excluded_uid: int = int(pivot["uid"]) if not pivot.is_empty() and _fixed_connection_kind_v020(str(pivot["kind"])) else -1
	var component: Array = _fixed_component_v020(connector, excluded_uid)
	if not pivot.is_empty() and excluded_uid >= 0:
		var pivot_other: RigidBody3D = _other_body_v020(pivot, connector)
		if _component_has_piece_v020(component, pivot_other):
			return {"valid": false, "reason": "this mount is part of a closed rigid loop"}

	var target_origin: Vector3 = current.origin
	if not pivot.is_empty():
		var kind: String = str(pivot["kind"])
		if kind == "socket" or kind == "cross":
			var slot: int = int(pivot["slot"])
			var anchor: Vector3 = _record_anchor_v020(pivot)
			var home_dir: Vector3 = (home_basis * _slot_dir(slot)).normalized()
			target_origin = anchor - home_dir * CONNECTOR_D
		elif kind == "axle":
			target_origin = current.origin
	var target: Transform3D = Transform3D(home_basis.orthonormalized(), target_origin)
	var transforms: Dictionary = _rigid_delta_map_v020(component, current, target)
	var validation: Dictionary = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return validation
	return {"valid": true, "transforms": transforms, "component": component, "pivot": pivot}


func _apply_transform_map_v020(transforms: Dictionary, status_text: String) -> void:
	# Mutation starts here only after the preview has validated every connection.
	# This makes rejected rotations literal no-ops and fixes issue #9.
	for key_value in transforms.keys():
		var key: int = int(key_value)
		for body_value in bodies:
			var body: RigidBody3D = body_value as RigidBody3D
			if is_instance_valid(body) and body.get_instance_id() == key:
				body.global_transform = transforms[key] as Transform3D
				body.set_meta("build_transform", body.global_transform)
				break
		for ring_value in o_ring_stops:
			var ring: RigidBody3D = ring_value as RigidBody3D
			if is_instance_valid(ring) and ring.get_instance_id() == key:
				ring.global_transform = transforms[key] as Transform3D
				ring.set_meta("build_transform", ring.global_transform)
				break
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	_status(status_text)


func _apply_rotation_action_v020(action: String, direction_sign: int) -> void:
	var preview: Dictionary = _rotation_preview_v020(action, direction_sign)
	if not bool(preview.get("valid", false)):
		_status("Rotation blocked — %s" % str(preview.get("reason", "not valid for this mount")))
		_update_ui()
		return
	var label: String
	if action == "roll":
		label = "Rolled 45° around the real mount axis"
	else:
		label = "Rotated 45° %s relative to the camera" % action
	_apply_transform_map_v020(preview["transforms"] as Dictionary, label)


func _reset_rotation_v020() -> void:
	var preview: Dictionary = _reset_preview_v020()
	if not bool(preview.get("valid", false)):
		_status("Reset blocked — %s" % str(preview.get("reason", "current connections prevent it")))
		_update_ui()
		return
	_apply_transform_map_v020(preview["transforms"] as Dictionary, "Rotation reset to this connector's placement orientation")


func _refresh_joint_frames_v020() -> void:
	_rebuild_connection_graph_v020(false)
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var joint: Joint3D = record["joint"] as Joint3D
		if not is_instance_valid(joint):
			continue
		var kind: String = str(record["kind"])
		var connector: RigidBody3D = record["connector"] as RigidBody3D
		var rod: RigidBody3D = record["rod"] as RigidBody3D
		var ring: RigidBody3D = record["ring"] as RigidBody3D
		if kind == "socket" and is_instance_valid(connector) and is_instance_valid(rod):
			var socket: Dictionary = _socket_world_v020(connector, int(record["slot"]))
			var end_point: Vector3 = _rod_end_v020(rod, int(record["rod_end"]))
			joint.global_transform = Transform3D(connector.global_transform.basis, ((socket["point"] as Vector3) + end_point) * 0.5)
		elif kind == "cross" and is_instance_valid(connector) and is_instance_valid(rod):
			var mouth: Vector3 = (_socket_world_v020(connector, int(record["slot"]))["point"] as Vector3)
			var host_point: Vector3 = rod.global_position + _rod_axis_v020(rod) * float(record["host_along"])
			joint.global_transform = Transform3D(connector.global_transform.basis, (mouth + host_point) * 0.5)
		elif kind == "axle" and is_instance_valid(connector):
			joint.global_transform = connector.global_transform
		elif kind == "o_ring" and is_instance_valid(ring):
			joint.global_transform = ring.global_transform
	_rebind_all_joints()


# -----------------------------------------------------------------------------
# Connector/rod palette behavior without CREATE/EDIT modes
# -----------------------------------------------------------------------------

func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	_rebuild_connection_graph_v020()
	if _selected_kind() != "connector":
		selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
		_update_ui()
		_status("Next connector: %s" % connector_defs[selected_connector_type]["name"])
		return
	var connector: RigidBody3D = selected_piece
	var current: int = int(connector.get_meta("connector_type", -1))
	var attached: Array = _connections_for_piece_v020(connector)
	var candidate: int = current
	for _i in range(connector_defs.size() - 1):
		candidate = wrapi(candidate + delta, 0, connector_defs.size())
		if candidate == o_ring_index:
			continue
		var candidate_slots: Array = connector_defs[candidate]["slots"] as Array
		var used: Dictionary = {}
		var remap: Dictionary = {}
		var valid: bool = true
		for record_value in attached:
			var record: Dictionary = record_value as Dictionary
			var kind: String = str(record["kind"])
			if kind != "socket" and kind != "cross":
				continue
			var old_slot: int = int(record["slot"])
			var old_dir: Vector3 = (connector.global_transform.basis * _slot_dir(old_slot)).normalized()
			var best_slot: int = -1
			var best_dot: float = 0.995
			for slot_value in candidate_slots:
				var new_slot: int = int(slot_value)
				if used.has(new_slot):
					continue
				var new_dir: Vector3 = (connector.global_transform.basis * _slot_dir(new_slot)).normalized()
				var score: float = new_dir.dot(old_dir)
				if score > best_dot:
					best_dot = score
					best_slot = new_slot
			if best_slot < 0:
				valid = false
				break
			used[best_slot] = true
			remap[int(record["uid"])] = best_slot
		if not valid:
			continue

		# Validate first; mutate only after every existing exact connection has a slot.
		_clear_selection_highlight()
		_rebuild_connector(connector, candidate)
		for record_value in attached:
			var record: Dictionary = record_value as Dictionary
			var uid: int = int(record["uid"])
			if remap.has(uid):
				var joint: Joint3D = record["joint"] as Joint3D
				if is_instance_valid(joint):
					joint.set_meta("connector_slot_v020", int(remap[uid]))
		connector.set_meta("occupied", used.duplicate(true))
		connector.set_meta("build_transform", connector.global_transform)
		selected_connector_type = candidate
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
		_commit_state()
		_refresh_selection_highlight()
		_update_ui()
		_status("Selected connector changed to %s" % connector_defs[candidate]["name"])
		return
	_status("No other connector type preserves every exact current connection")


func _change_rod_type(delta: int) -> void:
	if simulating:
		return
	if _selected_kind() != "rod":
		selected_rod_type = wrapi(selected_rod_type + delta, 0, rod_defs.size())
		_update_ui()
		_status("Next rod: %s" % rod_defs[selected_rod_type]["name"])
		return
	# Parent logic already preserves the occupied end and blocks rods locked at
	# both ends. v0.2's commit override rebuilds the graph afterwards.
	super._change_rod_type(delta)
	_rebuild_connection_graph_v020()
	_refresh_selection_highlight()
	_update_ui()


# -----------------------------------------------------------------------------
# Undo/Redo persistence for exact connection metadata and primary mount identity
# -----------------------------------------------------------------------------

func _capture_state() -> Dictionary:
	_rebuild_connection_graph_v020()
	var snapshot: Dictionary = super._capture_state()
	var body_meta: Array = []
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		body_meta.append({
			"uid": _ensure_piece_uid_v020(body),
			"root": bool(body.get_meta("root_piece_v020", false)),
			"primary": int(body.get_meta("primary_connection_uid_v020", -1)),
			"home_basis": body.get_meta("rotation_home_basis_v020", body.global_transform.basis),
		})
	snapshot["v020_body_meta"] = body_meta

	var connection_meta: Array = []
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var connector: RigidBody3D = record["connector"] as RigidBody3D
		var rod: RigidBody3D = record["rod"] as RigidBody3D
		var ring: RigidBody3D = record["ring"] as RigidBody3D
		connection_meta.append({
			"uid": int(record["uid"]),
			"kind": str(record["kind"]),
			"connector_index": bodies.find(connector),
			"rod_index": bodies.find(rod),
			"ring_index": o_ring_stops.find(ring),
			"slot": int(record["slot"]),
			"rod_end": int(record["rod_end"]),
			"host_along": float(record["host_along"]),
			"rest_gap": float(record["rest_gap"]),
			"rest_align": float(record["rest_align"]),
			"rest_perp": float(record["rest_perp"]),
			"rest_plane": float(record["rest_plane"]),
		})
	snapshot["v020_connections"] = connection_meta
	snapshot["v020_next_piece_uid"] = next_piece_uid_v020
	snapshot["v020_next_connection_uid"] = next_connection_uid_v020
	return snapshot


func _find_joint_between_v020(a: RigidBody3D, b: RigidBody3D, axle: bool, used: Dictionary) -> Joint3D:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or used.has(joint.get_instance_id()):
			continue
		var is_axle: bool = str(joint.name).begins_with("AxleJoint")
		if is_axle != axle:
			continue
		var nodes: Array = _joint_nodes(joint)
		if (nodes[0] == a and nodes[1] == b) or (nodes[0] == b and nodes[1] == a):
			return joint
	return null


func _restore_state(snapshot: Dictionary) -> void:
	select_armed_v020 = false
	restoring_v020 = true
	super._restore_state(snapshot)
	edit_mode = true

	var body_meta: Array = snapshot.get("v020_body_meta", []) as Array
	for i in range(mini(body_meta.size(), bodies.size())):
		var body: RigidBody3D = bodies[i] as RigidBody3D
		if not is_instance_valid(body):
			continue
		var meta: Dictionary = body_meta[i] as Dictionary
		body.set_meta("piece_uid_v020", int(meta.get("uid", i + 1)))
		body.set_meta("root_piece_v020", bool(meta.get("root", false)))
		body.set_meta("primary_connection_uid_v020", int(meta.get("primary", -1)))
		body.set_meta("rotation_home_basis_v020", meta.get("home_basis", body.global_transform.basis))

	var used_joints: Dictionary = {}
	var saved_connections: Array = snapshot.get("v020_connections", []) as Array
	for connection_value in saved_connections:
		var saved: Dictionary = connection_value as Dictionary
		var kind: String = str(saved.get("kind", "socket"))
		var connector_index: int = int(saved.get("connector_index", -1))
		var rod_index: int = int(saved.get("rod_index", -1))
		var ring_index: int = int(saved.get("ring_index", -1))
		var connector: RigidBody3D = bodies[connector_index] as RigidBody3D if connector_index >= 0 and connector_index < bodies.size() else null
		var rod: RigidBody3D = bodies[rod_index] as RigidBody3D if rod_index >= 0 and rod_index < bodies.size() else null
		var ring: RigidBody3D = o_ring_stops[ring_index] as RigidBody3D if ring_index >= 0 and ring_index < o_ring_stops.size() else null
		var joint: Joint3D = null
		if kind == "o_ring" and is_instance_valid(ring) and is_instance_valid(rod):
			joint = _find_joint_between_v020(ring, rod, false, used_joints)
		elif is_instance_valid(connector) and is_instance_valid(rod):
			joint = _find_joint_between_v020(connector, rod, kind == "axle", used_joints)
		if not is_instance_valid(joint):
			continue
		used_joints[joint.get_instance_id()] = true
		joint.set_meta("connection_uid_v020", int(saved.get("uid", next_connection_uid_v020)))
		joint.set_meta("connection_kind_v020", kind)
		joint.set_meta("connector_slot_v020", int(saved.get("slot", -1)))
		joint.set_meta("rod_end_v020", int(saved.get("rod_end", 0)))
		joint.set_meta("host_along_v020", float(saved.get("host_along", 0.0)))
		joint.set_meta("rest_gap_v020", float(saved.get("rest_gap", 0.0)))
		joint.set_meta("rest_align_v020", float(saved.get("rest_align", 1.0)))
		joint.set_meta("rest_perp_v020", float(saved.get("rest_perp", 0.0)))
		joint.set_meta("rest_plane_v020", float(saved.get("rest_plane", 0.0)))
		if kind == "cross":
			joint.set_meta("cross_mount", true)

	next_piece_uid_v020 = int(snapshot.get("v020_next_piece_uid", next_piece_uid_v020))
	next_connection_uid_v020 = int(snapshot.get("v020_next_connection_uid", next_connection_uid_v020))
	_ensure_all_piece_uids_v020()
	_rebuild_connection_graph_v020()
	restoring_v020 = false
	_refresh_selection_highlight()
	_update_ui()


func _commit_state() -> void:
	if restoring_state or restoring_v020 or simulating:
		return
	if committing_v020:
		return
	committing_v020 = true
	_auto_connect_all_v020()
	_rebuild_connection_graph_v020()
	super._commit_state()
	committing_v020 = false
	_update_ui()


# -----------------------------------------------------------------------------
# Simulation preflight uses the same authoritative graph and refreshed frames.
# The inherited v0.1.4 stable graph still suppresses redundant closed-loop
# solver constraints and rigid-component self-collision.
# -----------------------------------------------------------------------------

func _toggle_simulation() -> void:
	if not simulating:
		var fused: int = _auto_connect_all_v020()
		_rebuild_connection_graph_v020()
		_refresh_joint_frames_v020()
		if fused > 0:
			_commit_state()
	super._toggle_simulation()


func _reset_pose() -> void:
	super._reset_pose()
	edit_mode = true
	_rebuild_connection_graph_v020()
	_refresh_selection_highlight()
	_update_ui()


func _restart_build() -> void:
	select_armed_v020 = false
	super._restart_build()
	edit_mode = true
	_rebuild_connection_graph_v020()
	if is_instance_valid(selected_piece):
		selected_piece.set_meta("root_piece_v020", true)
		selected_piece.set_meta("primary_connection_uid_v020", -1)
	_refresh_selection_highlight()
	_update_ui()
	_status("Restarted at one selected starting connector")


func _delete_selected() -> void:
	edit_mode = true
	super._delete_selected()
	_rebuild_connection_graph_v020()
	_refresh_selection_highlight()
	_update_ui()


# -----------------------------------------------------------------------------
# UI state / valid-rotation previews
# -----------------------------------------------------------------------------

func _update_rotation_buttons_v020() -> void:
	var connector_selected: bool = not simulating and _selected_kind() == "connector"
	var button_actions: Array = [
		[rot_up_v020, "up", 1],
		[rot_down_v020, "down", 1],
		[rot_left_v020, "left", 1],
		[rot_right_v020, "right", 1],
		[roll_left_v020, "roll", -1],
		[roll_right_v020, "roll", 1],
	]
	for item_value in button_actions:
		var item: Array = item_value as Array
		var button: Button = item[0] as Button
		if button == null:
			continue
		if not connector_selected:
			button.disabled = true
		else:
			var preview: Dictionary = _rotation_preview_v020(str(item[1]), int(item[2]))
			button.disabled = not bool(preview.get("valid", false))
	if reset_rotation_v020 != null:
		reset_rotation_v020.disabled = not connector_selected or not bool(_reset_preview_v020().get("valid", false))


func _update_ui() -> void:
	edit_mode = true
	if rod_label != null:
		var rod_prefix: String = "Selected: " if _selected_kind() == "rod" else "Next: "
		rod_label.text = rod_prefix + str(rod_defs[selected_rod_type]["name"])
	if connector_label != null and selected_connector_type >= 0 and selected_connector_type < connector_defs.size():
		var connector_prefix: String = "Selected: " if _selected_kind() == "connector" or _selected_kind() == "o_ring" else "Next: "
		connector_label.text = connector_prefix + str(connector_defs[selected_connector_type]["name"])
	if mode_button != null:
		mode_button.text = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	if select_button_v020 != null:
		select_button_v020.text = "SELECT…" if select_armed_v020 else "Select"
		select_button_v020.disabled = simulating
		var select_color: Color = Color(0.03, 0.47, 0.70, 1.0) if select_armed_v020 else Color(0.07, 0.30, 0.48, 0.98)
		select_button_v020.add_theme_stylebox_override("normal", _button_style(select_color))
	if top_simulate_button != null:
		top_simulate_button.text = "BUILD" if simulating else "SIMULATE"
	if top_redo_button != null:
		top_redo_button.disabled = simulating or state_index < 0 or state_index >= state_history.size() - 1
	if top_undo_button != null:
		top_undo_button.disabled = simulating or state_index <= 0
	if selected_label_v020 != null:
		selected_label_v020.text = "Selected: %s" % (_piece_display_name(selected_piece) if is_instance_valid(selected_piece) else "—")
	if delete_button != null:
		delete_button.disabled = simulating or not is_instance_valid(selected_piece)
	var move_enabled: bool = not simulating and is_instance_valid(selected_piece)
	for button_value in [move_left_button, move_right_button, move_forward_button, move_back_button, move_up_button, move_down_button, axle_minus_button, axle_plus_button]:
		var button: Button = button_value as Button
		if button != null:
			button.disabled = not move_enabled
	_refresh_side_panels()
	_update_rotation_buttons_v020()


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_020, text]
