extends "res://scripts/main_v041.gd"

const VERSION_042 := "0.4.0"
const EDITOR_MOVE_042 := 3
const MOVE_STEP_042 := 0.50
const MOVE_GIZMO_LENGTH_042 := 2.45
const MOVE_GIZMO_PICK_PX_042 := 38.0
const MOVE_GIZMO_STEP_PX_042 := 52.0

var move_mode_button_v042: Button
var disconnect_button_v042: Button

var rot_x_minus_v042: Button
var rot_x_plus_v042: Button
var rot_y_minus_v042: Button
var rot_y_plus_v042: Button
var rot_z_minus_v042: Button
var rot_z_plus_v042: Button

var move_x_minus_v042: Button
var move_x_plus_v042: Button
var move_y_minus_v042: Button
var move_y_plus_v042: Button
var move_z_minus_v042: Button
var move_z_plus_v042: Button

var move_gizmo_root_v042: Node3D
var move_gizmo_axes_v042: Dictionary = {}
var move_drag_active_v042: bool = false
var move_drag_axis_v042: Vector3 = Vector3.ZERO
var move_drag_axis_name_v042: String = ""
var move_drag_start_screen_v042: Vector2 = Vector2.ZERO
var move_drag_screen_dir_v042: Vector2 = Vector2.RIGHT
var move_drag_steps_v042: int = 0
var move_drag_component_v042: Array = []
var move_drag_preview_v042: Dictionary = {}

var attach_preview_layer_v042: CanvasLayer
var attach_preview_line_v042: Line2D
var attach_target_mat_v042: StandardMaterial3D
var attach_dim_mat_v042: StandardMaterial3D
var last_pointer_screen_v042: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	_build_move_gizmo_v042()
	_build_attach_preview_v042()
	attach_target_mat_v042 = _overlay_material_v030(Color(0.24, 1.0, 0.52))
	attach_dim_mat_v042 = _overlay_material_v030(Color(0.30, 0.34, 0.40), 0.52)
	last_pointer_screen_v042 = get_viewport().get_visible_rect().size * 0.5
	right_panel_state_v037 = ""
	_apply_right_panel_state_v037()
	_refresh_attach_points_v032()
	_refresh_gizmo_validity_v030()
	_update_ui()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_042)
	_status("v0.4 editor refresh: CREATE / ROTATE / MOVE / ATTACH, world move gizmo, Disconnect, cleaner attachment guidance, and improved lighting.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_042, text]


# -----------------------------------------------------------------------------
# Presentation — no engine splash, polished plastic materials and three-point
# lighting. The project setting disables the Godot boot image; these functions
# improve the scene itself after launch.
# -----------------------------------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = "v042:%s" % color.to_html(true)
	if material_cache.has(key):
		return material_cache[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.76 if color.get_luminance() < 0.12 else 0.34
	material_cache[key] = material
	return material


func _build_world() -> void:
	super._build_world()
	var key_light_found: bool = false
	for child_value in get_children():
		var child: Node = child_value as Node
		if child is WorldEnvironment:
			var world_environment: WorldEnvironment = child as WorldEnvironment
			if world_environment.environment != null:
				world_environment.environment.ambient_light_color = Color(0.55, 0.62, 0.72)
				world_environment.environment.ambient_light_energy = 0.78
		elif child is DirectionalLight3D and not key_light_found:
			var key_light: DirectionalLight3D = child as DirectionalLight3D
			key_light.light_energy = 1.35
			key_light.light_color = Color(1.0, 0.965, 0.90)
			key_light.shadow_enabled = true
			key_light_found = true

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "FillLightV042"
	fill.rotation_degrees = Vector3(-28.0, 132.0, 18.0)
	fill.light_color = Color(0.66, 0.79, 1.0)
	fill.light_energy = 0.48
	fill.shadow_enabled = false
	add_child(fill)

	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.name = "RimLightV042"
	rim.rotation_degrees = Vector3(-12.0, -145.0, 0.0)
	rim.light_color = Color(1.0, 0.73, 0.49)
	rim.light_energy = 0.26
	rim.shadow_enabled = false
	add_child(rim)


# -----------------------------------------------------------------------------
# UI — four clear editor modes. Move is a true mode directly beneath Rotate.
# The right side is optional detail/fallback UI and starts collapsed.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	if mode_panel_v032 != null and mode_panel_v032.get_child_count() > 0:
		var mode_box: VBoxContainer = mode_panel_v032.get_child(0) as VBoxContainer
		if mode_box != null:
			move_mode_button_v042 = _ui_button("MOVE", func() -> void: _set_editor_mode_v032(EDITOR_MOVE_042), true)
			move_mode_button_v042.custom_minimum_size = Vector2(194.0, 52.0)
			move_mode_button_v042.add_theme_font_size_override("font_size", 17)
			mode_box.add_child(move_mode_button_v042)
			if rotate_button_v032 != null:
				mode_box.move_child(move_mode_button_v042, rotate_button_v032.get_index() + 1)

			disconnect_button_v042 = _ui_button("Disconnect Selected", _disconnect_selected_v042, true)
			disconnect_button_v042.custom_minimum_size.y = 46.0
			mode_box.add_child(disconnect_button_v042)
			if delete_button_v032 != null:
				mode_box.move_child(disconnect_button_v042, delete_button_v032.get_index())

			for button_value in [create_button_v032, rotate_button_v032, move_mode_button_v042, attach_button_v032]:
				var button: Button = button_value as Button
				if button != null:
					button.custom_minimum_size.y = 52.0
					button.add_theme_font_size_override("font_size", 17)

		mode_panel_v032.offset_right = 220.0
		mode_panel_v032.offset_bottom = 548.0

	_rebuild_rotation_fallback_v042()
	_rebuild_move_menu_v042()
	_compact_palette_v042()
	right_panel_state_v037 = ""
	_apply_right_panel_state_v037()


func _compact_palette_v042() -> void:
	if bottom_panel == null:
		return
	bottom_panel.offset_top = -100.0
	_hide_palette_hint_v042(bottom_panel)


func _hide_palette_hint_v042(node: Node) -> void:
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child is Label:
			var label: Label = child as Label
			if label.text.begins_with("Newest piece"):
				label.visible = false
		if child != null:
			_hide_palette_hint_v042(child)


func _rebuild_rotation_fallback_v042() -> void:
	if rotation_body == null:
		return
	rotation_body.add_child(_section_label("WORLD 45° STEP BUTTONS"))
	var x_row: HBoxContainer = HBoxContainer.new()
	var y_row: HBoxContainer = HBoxContainer.new()
	var z_row: HBoxContainer = HBoxContainer.new()
	for row_value in [x_row, y_row, z_row]:
		(row_value as HBoxContainer).add_theme_constant_override("separation", 4)
		rotation_body.add_child(row_value as HBoxContainer)
	rot_x_minus_v042 = _ui_button("X −", func() -> void: _apply_world_rotation_step_v042("X", -1))
	rot_x_plus_v042 = _ui_button("X +", func() -> void: _apply_world_rotation_step_v042("X", 1))
	rot_y_minus_v042 = _ui_button("Y −", func() -> void: _apply_world_rotation_step_v042("Y", -1))
	rot_y_plus_v042 = _ui_button("Y +", func() -> void: _apply_world_rotation_step_v042("Y", 1))
	rot_z_minus_v042 = _ui_button("Z −", func() -> void: _apply_world_rotation_step_v042("Z", -1))
	rot_z_plus_v042 = _ui_button("Z +", func() -> void: _apply_world_rotation_step_v042("Z", 1))
	x_row.add_child(rot_x_minus_v042)
	x_row.add_child(rot_x_plus_v042)
	y_row.add_child(rot_y_minus_v042)
	y_row.add_child(rot_y_plus_v042)
	z_row.add_child(rot_z_minus_v042)
	z_row.add_child(rot_z_plus_v042)
	if rotation_hint_v035 != null:
		rotation_hint_v035.text = "Drag the world rings on the piece, or use the exact ±45° buttons below. Roll remains mount-relative."


func _rebuild_move_menu_v042() -> void:
	if move_body == null:
		return
	for child_value in move_body.get_children():
		var old_child: CanvasItem = child_value as CanvasItem
		if old_child != null:
			old_child.visible = false

	move_body.add_child(_section_label("WORLD MOVE • 0.5 UNIT SNAP"))
	var hint: Label = Label.new()
	hint.text = "Drag an X/Y/Z arrow on the selected piece. These buttons are the exact-step fallback."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.66, 0.76, 0.84))
	move_body.add_child(hint)

	var x_row: HBoxContainer = HBoxContainer.new()
	var y_row: HBoxContainer = HBoxContainer.new()
	var z_row: HBoxContainer = HBoxContainer.new()
	for row_value in [x_row, y_row, z_row]:
		(row_value as HBoxContainer).add_theme_constant_override("separation", 4)
		move_body.add_child(row_value as HBoxContainer)
	move_x_minus_v042 = _ui_button("X −", func() -> void: _apply_world_move_step_v042(Vector3.RIGHT, -1))
	move_x_plus_v042 = _ui_button("X +", func() -> void: _apply_world_move_step_v042(Vector3.RIGHT, 1))
	move_y_minus_v042 = _ui_button("Y −", func() -> void: _apply_world_move_step_v042(Vector3.UP, -1))
	move_y_plus_v042 = _ui_button("Y +", func() -> void: _apply_world_move_step_v042(Vector3.UP, 1))
	move_z_minus_v042 = _ui_button("Z −", func() -> void: _apply_world_move_step_v042(Vector3.BACK, -1))
	move_z_plus_v042 = _ui_button("Z +", func() -> void: _apply_world_move_step_v042(Vector3.BACK, 1))
	x_row.add_child(move_x_minus_v042)
	x_row.add_child(move_x_plus_v042)
	y_row.add_child(move_y_minus_v042)
	y_row.add_child(move_y_plus_v042)
	z_row.add_child(move_z_minus_v042)
	z_row.add_child(move_z_plus_v042)

	move_body.add_child(_section_label("AXLE SLIDE"))
	var axle_row: HBoxContainer = HBoxContainer.new()
	axle_row.add_theme_constant_override("separation", 4)
	move_body.add_child(axle_row)
	axle_row.add_child(_ui_button("Axle −", func() -> void: _slide_selected_on_axle(-EDIT_AXLE_STEP)))
	axle_row.add_child(_ui_button("Axle +", func() -> void: _slide_selected_on_axle(EDIT_AXLE_STEP)))


func _layout_right_panels_v032() -> void:
	if rotation_panel == null or move_panel == null:
		return
	rotation_panel.anchor_left = 1.0
	rotation_panel.anchor_right = 1.0
	move_panel.anchor_left = 1.0
	move_panel.anchor_right = 1.0
	rotation_panel.offset_left = -236.0
	rotation_panel.offset_right = -8.0
	move_panel.offset_left = -236.0
	move_panel.offset_right = -8.0
	rotation_panel.clip_contents = true
	move_panel.clip_contents = true

	var top_value: float = 112.0
	var collapsed: float = 48.0
	var gap: float = 6.0
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var bottom_limit: float = maxf(top_value + 220.0, viewport_height - 108.0)
	var rotate_open: bool = right_panel_state_v037 == "rotate"
	var move_open: bool = right_panel_state_v037 == "move"
	if rotate_open:
		var rotate_bottom: float = minf(top_value + 410.0, bottom_limit - collapsed - gap)
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = rotate_bottom
		move_panel.offset_top = rotate_bottom + gap
		move_panel.offset_bottom = rotate_bottom + gap + collapsed
	elif move_open:
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = minf(top_value + collapsed + gap + 330.0, bottom_limit)
	else:
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = top_value + collapsed * 2.0 + gap


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	if simulating:
		if report:
			_status("Return to BUILD before changing editor mode")
		return
	if mode_value == EDITOR_MOVE_042:
		editor_mode_v032 = EDITOR_MOVE_042
		select_armed_v020 = false
		_cancel_editor_tools_v030(false)
		_deselect_attach_point_v032(false)
		right_panel_state_v037 = ""
		_apply_right_panel_state_v037()
		_update_mode_ui_v032()
		_refresh_editor_overlay_v030()
		_refresh_attach_points_v032()
		if report:
			_status("MOVE mode — drag the world X/Y/Z arrows on the selected piece; movement snaps to 0.5 units.")
		return

	super._set_editor_mode_v032(mode_value, report)
	# Mode entry itself stays visually uncluttered. Utility panels are optional and
	# open only when their small right-side headers are tapped.
	right_panel_state_v037 = ""
	_apply_right_panel_state_v037()
	_refresh_gizmo_validity_v030()
	_refresh_attach_points_v032()


func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	var buttons: Array = [create_button_v032, rotate_button_v032, move_mode_button_v042, attach_button_v032]
	var names: Array = ["CREATE", "ROTATE", "MOVE", "ATTACH"]
	for i in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		var active: bool = i == editor_mode_v032
		button.text = ("● " if active else "") + str(names[i])
		button.self_modulate = Color(0.68, 0.94, 1.0) if active else Color.WHITE
	if mode_hint_v032 != null and editor_mode_v032 == EDITOR_MOVE_042:
		mode_hint_v032.text = "World XYZ move gizmo • 0.5 snap"


func _update_ui() -> void:
	super._update_ui()
	var has_selection: bool = not simulating and is_instance_valid(selected_piece)
	if disconnect_button_v042 != null:
		disconnect_button_v042.disabled = not has_selection or _connections_for_piece_v020(selected_piece).is_empty()
	if move_mode_button_v042 != null:
		move_mode_button_v042.disabled = simulating

	var rotate_ready: bool = has_selection and editor_mode_v032 == EDITOR_ROTATE_032
	_update_rotation_fallback_buttons_v042(rotate_ready)
	var move_ready: bool = has_selection and editor_mode_v032 == EDITOR_MOVE_042
	for button_value in [move_x_minus_v042, move_x_plus_v042, move_y_minus_v042, move_y_plus_v042, move_z_minus_v042, move_z_plus_v042]:
		var button: Button = button_value as Button
		if button != null:
			button.disabled = not move_ready

	_apply_right_panel_state_v037()


func _update_rotation_fallback_buttons_v042(enabled: bool) -> void:
	var entries: Array = [
		[rot_x_minus_v042, "X", -1], [rot_x_plus_v042, "X", 1],
		[rot_y_minus_v042, "Y", -1], [rot_y_plus_v042, "Y", 1],
		[rot_z_minus_v042, "Z", -1], [rot_z_plus_v042, "Z", 1]
	]
	for entry_value in entries:
		var entry: Array = entry_value as Array
		var button: Button = entry[0] as Button
		if button == null:
			continue
		var valid: bool = false
		if enabled:
			var axis: Vector3 = _world_axis_v035(str(entry[1]))
			valid = bool(_rotation_candidate_v030(axis, int(entry[2])).get("valid", false))
		button.disabled = not valid


func _handle_tap(screen_pos: Vector2) -> void:
	if editor_mode_v032 == EDITOR_MOVE_042:
		if select_armed_v020:
			super._handle_tap(screen_pos)
		else:
			_status("MOVE mode — selection kept. Drag a move arrow, or press Select to choose another piece.")
		return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# Disconnect Selected — frees the selected physical part from all of its current
# graph edges in one history transaction, without moving anything.
# -----------------------------------------------------------------------------

func _disconnect_selected_v042() -> void:
	if simulating or not is_instance_valid(selected_piece):
		_status("Select a piece in BUILD before disconnecting")
		return
	_rebuild_connection_graph_v020()
	var attached: Array = _connections_for_piece_v020(selected_piece).duplicate()
	if attached.is_empty():
		_status("Selected piece is already disconnected")
		return

	for record_value in attached:
		var record: Dictionary = record_value as Dictionary
		var a: RigidBody3D = record.get("a") as RigidBody3D
		var b: RigidBody3D = record.get("b") as RigidBody3D
		if is_instance_valid(a) and is_instance_valid(b):
			manual_detach_blocks_v030[_pair_key_v030(a, b)] = true
		var connector: RigidBody3D = record.get("connector") as RigidBody3D
		if is_instance_valid(connector) and int(connector.get_meta("primary_connection_uid_v020", -1)) == int(record.get("uid", -2)):
			connector.set_meta("primary_connection_uid_v020", -1)
		if str(record.get("kind", "")) == "cross" and is_instance_valid(connector):
			connector.set_meta("cross_mount", false)
			connector.set_meta("cross_host_rod", null)
		var ring: RigidBody3D = record.get("ring") as RigidBody3D
		if is_instance_valid(ring):
			ring.set_meta("host_rod", null)
		var joint: Joint3D = record.get("joint") as Joint3D
		if is_instance_valid(joint):
			joints.erase(joint)
			joint.queue_free()

	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_refresh_editor_overlay_v030()
	_refresh_attach_points_v032()
	_update_ui()
	_status("Disconnected selected piece from %d connection%s; geometry stayed in place." % [attached.size(), "" if attached.size() == 1 else "s"])


# -----------------------------------------------------------------------------
# True world-space move gizmo.
# -----------------------------------------------------------------------------

func _build_move_gizmo_v042() -> void:
	move_gizmo_root_v042 = Node3D.new()
	move_gizmo_root_v042.name = "MoveGizmoV042"
	add_child(move_gizmo_root_v042)
	move_gizmo_axes_v042.clear()
	_add_move_axis_v042("X", Vector3.RIGHT, Color(1.0, 0.20, 0.22))
	_add_move_axis_v042("Y", Vector3.UP, Color(0.20, 0.96, 0.36))
	_add_move_axis_v042("Z", Vector3.BACK, Color(0.20, 0.50, 1.0))
	move_gizmo_root_v042.visible = false


func _add_move_axis_v042(name_value: String, axis: Vector3, color: Color) -> void:
	var material: StandardMaterial3D = _overlay_material_v030(color)
	var axis_root: Node3D = Node3D.new()
	axis_root.name = "MoveAxis%s" % name_value
	axis_root.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	move_gizmo_root_v042.add_child(axis_root)

	var shaft_instance: MeshInstance3D = MeshInstance3D.new()
	var shaft_mesh: CylinderMesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.045
	shaft_mesh.bottom_radius = 0.045
	shaft_mesh.height = MOVE_GIZMO_LENGTH_042 * 2.0
	shaft_mesh.radial_segments = 10
	shaft_instance.mesh = shaft_mesh
	shaft_instance.material_override = material
	axis_root.add_child(shaft_instance)

	var plus: MeshInstance3D = MeshInstance3D.new()
	var plus_mesh: CylinderMesh = CylinderMesh.new()
	plus_mesh.top_radius = 0.0
	plus_mesh.bottom_radius = 0.19
	plus_mesh.height = 0.48
	plus_mesh.radial_segments = 12
	plus.mesh = plus_mesh
	plus.material_override = material
	plus.position.y = MOVE_GIZMO_LENGTH_042 + 0.22
	axis_root.add_child(plus)

	var minus: MeshInstance3D = MeshInstance3D.new()
	var minus_mesh: CylinderMesh = CylinderMesh.new()
	minus_mesh.top_radius = 0.19
	minus_mesh.bottom_radius = 0.0
	minus_mesh.height = 0.48
	minus_mesh.radial_segments = 12
	minus.mesh = minus_mesh
	minus.material_override = material
	minus.position.y = -MOVE_GIZMO_LENGTH_042 - 0.22
	axis_root.add_child(minus)

	var label: Label3D = Label3D.new()
	label.text = name_value
	label.font_size = 28
	label.modulate = color
	label.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = MOVE_GIZMO_LENGTH_042 + 0.72
	axis_root.add_child(label)
	move_gizmo_axes_v042[name_value] = {"axis": axis.normalized(), "material": material, "root": axis_root}


func _translation_map_v042(component: Array, delta: Vector3) -> Dictionary:
	var transforms: Dictionary = {}
	for body_value in component:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var transform_value: Transform3D = body.global_transform
		transform_value.origin += delta
		transforms[body.get_instance_id()] = transform_value
	return transforms


func _apply_world_move_step_v042(axis: Vector3, steps: int) -> void:
	if simulating or editor_mode_v032 != EDITOR_MOVE_042 or not is_instance_valid(selected_piece):
		return
	var component: Array = _connected_island_v037(selected_piece)
	if component.is_empty():
		_status("Move blocked — selected piece is unavailable")
		return
	var delta: Vector3 = axis.normalized() * MOVE_STEP_042 * float(steps)
	var transforms: Dictionary = _translation_map_v042(component, delta)
	_apply_transform_map_v020(transforms, "Moved WORLD %s by %.2f" % [_axis_name_v042(axis), MOVE_STEP_042 * float(steps)])


func _axis_name_v042(axis: Vector3) -> String:
	var n: Vector3 = axis.normalized()
	if absf(n.dot(Vector3.RIGHT)) > 0.99:
		return "X"
	if absf(n.dot(Vector3.UP)) > 0.99:
		return "Y"
	return "Z"


func _pick_move_axis_v042(screen_pos: Vector2) -> Dictionary:
	if move_gizmo_root_v042 == null or not move_gizmo_root_v042.visible or camera == null or not is_instance_valid(selected_piece):
		return {}
	var center: Vector3 = selected_piece.global_position
	if camera.is_position_behind(center):
		return {}
	var scale_value: float = move_gizmo_root_v042.scale.x
	var best: Dictionary = {}
	var best_distance: float = MOVE_GIZMO_PICK_PX_042
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = move_gizmo_axes_v042.get(name_value, {}) as Dictionary
		if data.is_empty():
			continue
		var axis: Vector3 = data.get("axis", Vector3.ZERO) as Vector3
		var positive: Vector3 = center + axis * MOVE_GIZMO_LENGTH_042 * scale_value
		var negative: Vector3 = center - axis * MOVE_GIZMO_LENGTH_042 * scale_value
		if camera.is_position_behind(positive) or camera.is_position_behind(negative):
			continue
		var screen_positive: Vector2 = camera.unproject_position(positive)
		var screen_negative: Vector2 = camera.unproject_position(negative)
		var screen_axis: Vector2 = screen_positive - screen_negative
		if screen_axis.length() < 28.0:
			continue
		var pick: Dictionary = _point_segment_pick_v035(screen_pos, screen_negative, screen_positive)
		var distance: float = float(pick.get("distance", 9999.0))
		if distance <= best_distance:
			best_distance = distance
			best = {"name": name_value, "axis": axis, "screen_dir": screen_axis.normalized()}
	return best


func _begin_move_drag_v042(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_MOVE_042 or simulating or not is_instance_valid(selected_piece):
		return false
	var picked: Dictionary = _pick_move_axis_v042(screen_pos)
	if picked.is_empty():
		return false
	var component: Array = _connected_island_v037(selected_piece)
	if component.is_empty():
		return false
	move_drag_active_v042 = true
	move_drag_axis_name_v042 = str(picked.get("name", ""))
	move_drag_axis_v042 = picked.get("axis", Vector3.ZERO) as Vector3
	move_drag_screen_dir_v042 = picked.get("screen_dir", Vector2.RIGHT) as Vector2
	move_drag_start_screen_v042 = screen_pos
	move_drag_steps_v042 = 0
	move_drag_component_v042 = component
	move_drag_preview_v042 = {"valid": true, "transforms": {}}
	_build_rotation_ghost_v030(component)
	_status("WORLD %s move selected — drag along the arrow; %.2f-unit snap" % [move_drag_axis_name_v042, MOVE_STEP_042])
	return true


func _update_move_drag_v042(screen_pos: Vector2) -> void:
	if not move_drag_active_v042:
		return
	var projected: float = (screen_pos - move_drag_start_screen_v042).dot(move_drag_screen_dir_v042)
	var steps: int = clampi(int(round(projected / MOVE_GIZMO_STEP_PX_042)), -40, 40)
	if steps == move_drag_steps_v042:
		return
	move_drag_steps_v042 = steps
	var delta: Vector3 = move_drag_axis_v042 * MOVE_STEP_042 * float(steps)
	var transforms: Dictionary = _translation_map_v042(move_drag_component_v042, delta)
	move_drag_preview_v042 = {"valid": true, "transforms": transforms}
	_update_rotation_ghost_v030(transforms, true)
	_status("WORLD %s move preview: %.2f" % [move_drag_axis_name_v042, MOVE_STEP_042 * float(steps)])


func _finish_move_drag_v042() -> void:
	if not move_drag_active_v042:
		return
	var steps: int = move_drag_steps_v042
	var preview: Dictionary = move_drag_preview_v042
	move_drag_active_v042 = false
	move_drag_steps_v042 = 0
	move_drag_component_v042 = []
	move_drag_preview_v042 = {}
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Move unchanged")
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Moved WORLD %s by %.2f" % [move_drag_axis_name_v042, MOVE_STEP_042 * float(steps)])


func _handle_move_input_v042(event: InputEvent) -> bool:
	if editor_mode_v032 != EDITOR_MOVE_042 or simulating or help_panel.visible or options_panel.visible:
		return false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		last_pointer_screen_v042 = touch.position
		if touch.pressed:
			return _begin_move_drag_v042(touch.position)
		if move_drag_active_v042:
			_finish_move_drag_v042()
			return true
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		last_pointer_screen_v042 = drag.position
		if move_drag_active_v042:
			_update_move_drag_v042(drag.position)
			return true
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		last_pointer_screen_v042 = mouse_button.position
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				return _begin_move_drag_v042(mouse_button.position)
			if move_drag_active_v042:
				_finish_move_drag_v042()
				return true
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		last_pointer_screen_v042 = motion.position
		if move_drag_active_v042:
			_update_move_drag_v042(motion.position)
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		last_pointer_screen_v042 = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		last_pointer_screen_v042 = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton:
		last_pointer_screen_v042 = (event as InputEventMouseButton).position
	elif event is InputEventMouseMotion:
		last_pointer_screen_v042 = (event as InputEventMouseMotion).position
	if _handle_move_input_v042(event):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


# -----------------------------------------------------------------------------
# Attachment guidance — after source selection, impossible points dim while free
# compatible points become bright green. A live screen line previews the target.
# -----------------------------------------------------------------------------

func _build_attach_preview_v042() -> void:
	attach_preview_layer_v042 = CanvasLayer.new()
	attach_preview_layer_v042.layer = 7
	add_child(attach_preview_layer_v042)
	attach_preview_line_v042 = Line2D.new()
	attach_preview_line_v042.width = 4.0
	attach_preview_line_v042.default_color = Color(0.20, 1.0, 0.50, 0.95)
	attach_preview_line_v042.antialiased = true
	attach_preview_line_v042.visible = false
	attach_preview_layer_v042.add_child(attach_preview_line_v042)


func _point_material_v032(point: Dictionary, selected: bool) -> StandardMaterial3D:
	if attach_dim_mat_v042 == null or attach_target_mat_v042 == null or attach_point_selected_v032.is_empty():
		return super._point_material_v032(point, selected)
	if selected or _point_key_v032(point) == _point_key_v032(attach_point_selected_v032):
		return point_selected_mat_v032
	var expected: Array = _expected_target_types_v035(str(attach_point_selected_v032.get("type", "")))
	if not (str(point.get("type", "")) in expected):
		return attach_dim_mat_v042
	if not _attach_target_is_available_v040(attach_point_selected_v032, point):
		return attach_dim_mat_v042
	return attach_target_mat_v042


func _update_attach_preview_v042() -> void:
	if attach_preview_line_v042 == null:
		return
	var show: bool = editor_mode_v032 == EDITOR_ATTACH_032 and not simulating and not help_panel.visible and not options_panel.visible and not attach_point_selected_v032.is_empty() and camera != null
	attach_preview_line_v042.visible = show
	if not show:
		return
	_refresh_selected_attach_geometry_v036()
	if attach_point_selected_v032.is_empty():
		attach_preview_line_v042.visible = false
		return
	var source_point: Vector3 = attach_point_selected_v032.get("point", Vector3.ZERO) as Vector3
	if camera.is_position_behind(source_point):
		attach_preview_line_v042.visible = false
		return
	var start: Vector2 = camera.unproject_position(source_point)
	var target: Dictionary = _pick_attach_target_v035(last_pointer_screen_v042, attach_point_selected_v032)
	if not target.is_empty():
		var target_world: Vector3 = target.get("point", source_point) as Vector3
		if not camera.is_position_behind(target_world):
			var finish: Vector2 = camera.unproject_position(target_world)
			attach_preview_line_v042.points = PackedVector2Array([start, finish])
			attach_preview_line_v042.default_color = Color(0.20, 1.0, 0.50, 0.96)
			return
	attach_preview_line_v042.points = PackedVector2Array([start, last_pointer_screen_v042])
	attach_preview_line_v042.default_color = Color(1.0, 0.36, 0.25, 0.80)


# -----------------------------------------------------------------------------
# Exact-step world rotation fallback + per-direction constraint feedback.
# -----------------------------------------------------------------------------

func _apply_world_rotation_step_v042(axis_name: String, direction_sign: int) -> void:
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not is_instance_valid(selected_piece):
		return
	var axis: Vector3 = _world_axis_v035(axis_name)
	var preview: Dictionary = _rotation_candidate_v030(axis, direction_sign)
	if not bool(preview.get("valid", false)):
		_status("WORLD %s rotation blocked — %s" % [axis_name, str(preview.get("reason", "constraint"))])
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated WORLD %s by %d°" % [axis_name, direction_sign * 45])
	_refresh_gizmo_validity_v030()


func _refresh_gizmo_validity_v030() -> void:
	if gizmo_root_v030 == null:
		return
	var enabled: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and tool_mode_v030.is_empty()
	for name_value in ["X", "Y", "Z"]:
		if not gizmo_axes_v030.has(name_value):
			continue
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var ring: MeshInstance3D = data.get("ring") as MeshInstance3D
		var plus_label: Label3D = data.get("plus") as Label3D
		var minus_label: Label3D = data.get("minus") as Label3D
		var axis: Vector3 = data.get("axis", Vector3.ZERO) as Vector3
		var base_material: StandardMaterial3D = data.get("material") as StandardMaterial3D
		var plus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		if is_instance_valid(ring):
			ring.material_override = base_material if plus_valid or minus_valid else gizmo_disabled_mat_v030
		if is_instance_valid(plus_label):
			plus_label.modulate = base_material.albedo_color if plus_valid else gizmo_disabled_mat_v030.albedo_color
		if is_instance_valid(minus_label):
			minus_label.modulate = base_material.albedo_color if minus_valid else gizmo_disabled_mat_v030.albedo_color


func _process(delta: float) -> void:
	super._process(delta)
	if move_gizmo_root_v042 != null:
		var show_move: bool = editor_mode_v032 == EDITOR_MOVE_042 and not simulating and is_instance_valid(selected_piece) and not help_panel.visible and not options_panel.visible
		move_gizmo_root_v042.visible = show_move
		if show_move:
			move_gizmo_root_v042.global_basis = Basis.IDENTITY
			move_gizmo_root_v042.global_position = selected_piece.global_position
			var scale_value: float = clampf(camera_distance / 19.0, 0.62, 2.10)
			move_gizmo_root_v042.scale = Vector3.ONE * scale_value
	_update_attach_preview_v042()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nEDITOR MODES: CREATE builds. ROTATE shows the world X/Y/Z rotation gizmo. MOVE shows world X/Y/Z translation arrows. ATTACH exposes connection points.\n\nDISCONNECT SELECTED: frees the selected physical part from all current graph connections without moving it; the operation is one saved build state.\n\nROTATE: drag the world rings or open the compact Rotate panel for exact X/Y/Z ±45° buttons. Plus/minus direction indicators are disabled independently when a candidate is not valid. Roll remains the separate real mount-axis operation.\n\nMOVE: drag a world X/Y/Z arrow; movement snaps every %.2f units. The compact Move panel provides exact-step buttons plus axle sliding.\n\nATTACH: once a source is selected, compatible free discrete points glow green and impossible points dim. A live line previews the current target: green means a compatible target is under the pointer, red means not yet. SOCKET = rod end ↔ socket; AXLE = hub/O-Ring ↔ rod shaft; CROSS = socket ↔ rod shaft.\n\n3D CONNECTORS: 11-point and 14-point spatial sockets remain fully functional. O-Ring Stop remains an axle-style stop on any rod.\n\nCamera: one finger orbit; two fingers pan/zoom." % [VERSION_042, MOVE_STEP_042]


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var release: Dictionary = parsed as Dictionary
	var latest: String = str(release.get("tag_name", "")).trim_prefix("v")
	if latest.is_empty():
		return
	if _compare_versions_v021(latest, VERSION_042) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_042)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_042, latest])
