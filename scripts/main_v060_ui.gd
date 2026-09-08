extends "res://scripts/main_v050_hotfix.gd"

const TRANSFORM_ITEM_060 := 0
const TRANSFORM_WORLD_060 := 1

var rotate_space_v060: int = TRANSFORM_ITEM_060
var move_space_v060: int = TRANSFORM_ITEM_060
var rotate_space_button_v060: Button
var move_space_button_v060: Button
var options_scroll_v060: ScrollContainer
var rotation_scroll_v060: ScrollContainer
var move_scroll_v060: ScrollContainer
var capsule_mesh_cache_v060: Dictionary = {}


func _ready() -> void:
	super._ready()
	_restore_hybrid_palette_v060()
	_make_options_scrollable_v060()
	_make_right_panels_scrollable_v060()
	_add_transform_space_controls_v060()
	_refresh_all_connector_visuals_v060()
	attach_overlay_dirty_v050 = true
	attach_spatial_dirty_v050 = true
	_refresh_attach_points_v032()
	_update_ui()


func _load_settings() -> void:
	super._load_settings()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	rotate_space_v060 = clampi(int(cfg.get_value("editor", "rotate_space", TRANSFORM_ITEM_060)), TRANSFORM_ITEM_060, TRANSFORM_WORLD_060)
	move_space_v060 = clampi(int(cfg.get_value("editor", "move_space", TRANSFORM_ITEM_060)), TRANSFORM_ITEM_060, TRANSFORM_WORLD_060)


func _save_settings() -> void:
	super._save_settings()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("editor", "rotate_space", rotate_space_v060)
	cfg.set_value("editor", "move_space", move_space_v060)
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		_status("Could not save editor transform settings (%s)" % error_string(err))


# Correct the inherited enum/index mismatch: ATTACH=2 while MOVE=3.
func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	var entries: Array = [
		[create_button_v032, EDITOR_CREATE_032, "CREATE"],
		[rotate_button_v032, EDITOR_ROTATE_032, "ROTATE"],
		[move_mode_button_v042, EDITOR_MOVE_042, "MOVE"],
		[attach_button_v032, EDITOR_ATTACH_032, "ATTACH"],
	]
	for entry_value in entries:
		var entry: Array = entry_value as Array
		var button: Button = entry[0] as Button
		if button == null:
			continue
		var active: bool = editor_mode_v032 == int(entry[1])
		button.text = ("● " if active else "") + str(entry[2])
		button.self_modulate = Color(0.68, 0.94, 1.0) if active else Color.WHITE
	if mode_hint_v032 != null:
		if editor_mode_v032 == EDITOR_MOVE_042:
			mode_hint_v032.text = "ITEM mechanical move" if move_space_v060 == TRANSFORM_ITEM_060 else "WORLD whole-build move"
		elif editor_mode_v032 == EDITOR_ROTATE_032:
			mode_hint_v032.text = "ITEM mechanical rotation" if rotate_space_v060 == TRANSFORM_ITEM_060 else "WORLD whole-build rotation"


func _restore_hybrid_palette_v060() -> void:
	if bottom_panel == null:
		return
	_restore_palette_buttons_recursive_v060(bottom_panel)
	if parts_button_v050 != null:
		parts_button_v050.text = "PARTS…"
		parts_button_v050.custom_minimum_size.x = 112.0


func _restore_palette_buttons_recursive_v060(node: Node) -> void:
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child is Button:
			var button: Button = child as Button
			if button.text in ["◀ Rod", "Rod ▶", "◀ Conn", "Conn ▶"]:
				button.visible = true
		_restore_palette_buttons_recursive_v060(child)


# The quick arrows and PARTS browser both choose the NEXT part. They never mutate
# an already selected construction piece.
func _change_rod_type(delta: int) -> void:
	if simulating:
		return
	selected_rod_type = wrapi(selected_rod_type + delta, 0, rod_defs.size())
	_update_ui()
	_refresh_parts_browser_v050()
	_status("Next rod: %s" % str((rod_defs[selected_rod_type] as Dictionary).get("name", "Rod")))


func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
	_update_ui()
	_refresh_parts_browser_v050()
	_status("Next connector: %s" % str((connector_defs[selected_connector_type] as Dictionary).get("name", "Connector")))


func _set_selected(body: RigidBody3D) -> void:
	var keep_rod: int = selected_rod_type
	var keep_connector: int = selected_connector_type
	super._set_selected(body)
	selected_rod_type = keep_rod
	selected_connector_type = keep_connector
	attach_overlay_dirty_v050 = true


func _find_first_margin_v060(node: Node) -> MarginContainer:
	if node is MarginContainer:
		return node as MarginContainer
	for child_value in node.get_children():
		var found: MarginContainer = _find_first_margin_v060(child_value as Node)
		if found != null:
			return found
	return null


func _make_options_scrollable_v060() -> void:
	if options_panel == null:
		return
	options_panel.anchor_left = 0.20
	options_panel.anchor_right = 0.80
	options_panel.anchor_top = 0.08
	options_panel.anchor_bottom = 0.90
	var margin: MarginContainer = _find_first_margin_v060(options_panel)
	if margin == null:
		return
	var body: VBoxContainer = _find_first_vbox_v050(margin)
	if body == null or body.get_parent() is ScrollContainer:
		return
	var parent: Node = body.get_parent()
	if parent == null:
		return
	var index: int = body.get_index()
	parent.remove_child(body)
	options_scroll_v060 = ScrollContainer.new()
	options_scroll_v060.name = "OptionsScrollV060"
	options_scroll_v060.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll_v060.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(options_scroll_v060)
	parent.move_child(options_scroll_v060, index)
	options_scroll_v060.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _wrap_right_body_v060(body: VBoxContainer, name_value: String) -> ScrollContainer:
	if body == null:
		return null
	if body.get_parent() is ScrollContainer:
		return body.get_parent() as ScrollContainer
	var parent: Node = body.get_parent()
	if parent == null:
		return null
	var index: int = body.get_index()
	parent.remove_child(body)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = name_value
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	parent.move_child(scroll, index)
	scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return scroll


func _make_right_panels_scrollable_v060() -> void:
	rotation_scroll_v060 = _wrap_right_body_v060(rotation_body, "RotationScrollV060")
	move_scroll_v060 = _wrap_right_body_v060(move_body, "MoveScrollV060")
	_layout_right_panels_v032()


func _add_transform_space_controls_v060() -> void:
	if rotation_body != null and rotate_space_button_v060 == null:
		rotate_space_button_v060 = _ui_button("ITEM • MECHANICAL", _toggle_rotate_space_v060, true)
		rotation_body.add_child(rotate_space_button_v060)
		rotation_body.move_child(rotate_space_button_v060, mini(1, rotation_body.get_child_count() - 1))
	if move_body != null and move_space_button_v060 == null:
		move_space_button_v060 = _ui_button("ITEM • MECHANICAL", _toggle_move_space_v060, true)
		move_body.add_child(move_space_button_v060)
		move_body.move_child(move_space_button_v060, 0)


func _toggle_rotate_space_v060() -> void:
	rotate_space_v060 = TRANSFORM_WORLD_060 if rotate_space_v060 == TRANSFORM_ITEM_060 else TRANSFORM_ITEM_060
	_save_settings()
	_update_ui()
	_status("Rotate space: %s" % ("ITEM — valid mechanical freedom" if rotate_space_v060 == TRANSFORM_ITEM_060 else "WORLD — whole connected construction"))


func _toggle_move_space_v060() -> void:
	move_space_v060 = TRANSFORM_WORLD_060 if move_space_v060 == TRANSFORM_ITEM_060 else TRANSFORM_ITEM_060
	_save_settings()
	_update_ui()
	_status("Move space: %s" % ("ITEM — valid mechanical freedom" if move_space_v060 == TRANSFORM_ITEM_060 else "WORLD — whole connected construction"))


func _layout_right_panels_v032() -> void:
	if rotation_panel == null or move_panel == null:
		return
	var top_value: float = 112.0
	var collapsed: float = 50.0
	var gap: float = 6.0
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var bottom_limit: float = maxf(top_value + 260.0, viewport_height - 108.0)
	for panel_value in [rotation_panel, move_panel]:
		var panel: PanelContainer = panel_value as PanelContainer
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.offset_left = -274.0
		panel.offset_right = -8.0
		panel.clip_contents = true
		panel.visible = true
	if right_panel_state_v037 == "rotate":
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = bottom_limit - collapsed - gap
		move_panel.offset_top = bottom_limit - collapsed
		move_panel.offset_bottom = bottom_limit
	elif right_panel_state_v037 == "move":
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = bottom_limit
	else:
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = top_value + collapsed * 2.0 + gap


# Rounded original procedural connector geometry. Fork mouths remain open; there
# is no old box ridge spanning the jaw gap.
func _capsule_mesh_v060(radius: float, height: float) -> CapsuleMesh:
	var safe_height: float = maxf(height, radius * 2.02)
	var key: String = "capsule:%.4f:%.4f" % [radius, safe_height]
	if capsule_mesh_cache_v060.has(key):
		return capsule_mesh_cache_v060[key] as CapsuleMesh
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = safe_height
	mesh.radial_segments = 12
	capsule_mesh_cache_v060[key] = mesh
	return mesh


func _add_capsule_segment_v060(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var delta: Vector3 = b - a
	var length: float = delta.length()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = _capsule_mesh_v060(radius, length + radius * 2.0)
	instance.material_override = material
	parent.add_child(instance)
	instance.position = (a + b) * 0.5
	if length > 0.0001:
		instance.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
	return instance


func _socket_frame_v060(direction_value: Vector3, normal_hint: Vector3) -> Basis:
	var x_axis: Vector3 = direction_value.normalized()
	var y_axis: Vector3 = normal_hint - x_axis * normal_hint.dot(x_axis)
	if y_axis.length_squared() < 0.04:
		y_axis = Vector3.UP - x_axis * Vector3.UP.dot(x_axis)
	if y_axis.length_squared() < 0.04:
		y_axis = Vector3.BACK - x_axis * Vector3.BACK.dot(x_axis)
	y_axis = y_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _add_open_fork_local_v060(parent: Node3D, color: Color) -> void:
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.055))
	_add_capsule_segment_v060(parent, Vector3(0.42, 0.0, 0.0), Vector3(0.91, 0.0, 0.0), 0.145, main_mat)
	_add_capsule_segment_v060(parent, Vector3(0.55, 0.0, -0.055), Vector3(0.92, 0.0, -0.19), 0.085, main_mat)
	_add_capsule_segment_v060(parent, Vector3(0.55, 0.0, 0.055), Vector3(0.92, 0.0, 0.19), 0.085, main_mat)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		_add_capsule_segment_v060(parent, Vector3(0.84, 0.0, 0.22 * side), Vector3(1.48, 0.0, 0.22 * side), 0.105, main_mat)
		_add_capsule_segment_v060(parent, Vector3(1.18, 0.0, 0.18 * side), Vector3(1.31, 0.0, 0.145 * side), 0.070, edge_mat)


func _add_rounded_socket_v060(parent: Node3D, slot: int, color: Color) -> void:
	var direction: Vector3 = _slot_dir(slot)
	var normal_hint: Vector3 = Vector3.BACK if slot >= 1000 else Vector3.UP
	var root_node: Node3D = Node3D.new()
	if slot >= 1000:
		root_node.name = "SpatialSocket_%d" % slot
	root_node.basis = _socket_frame_v060(direction, normal_hint)
	parent.add_child(root_node)
	_add_open_fork_local_v060(root_node, color)


func _build_connector_visuals_v060(parent: Node3D, def_index: int) -> void:
	var definition: Dictionary = connector_defs[def_index] as Dictionary
	var color: Color = definition.get("color", Color(0.8, 0.8, 0.8)) as Color
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.055))
	var hub: MeshInstance3D = MeshInstance3D.new()
	var hub_mesh: TorusMesh = TorusMesh.new()
	hub_mesh.inner_radius = 0.31
	hub_mesh.outer_radius = 0.61
	hub_mesh.rings = 24
	hub_mesh.ring_segments = 14
	hub.mesh = hub_mesh
	hub.scale.y = 0.82
	hub.material_override = main_mat
	parent.add_child(hub)
	var collar: MeshInstance3D = MeshInstance3D.new()
	var collar_mesh: TorusMesh = TorusMesh.new()
	collar_mesh.inner_radius = 0.285
	collar_mesh.outer_radius = 0.42
	collar_mesh.rings = 20
	collar_mesh.ring_segments = 12
	collar.mesh = collar_mesh
	collar.scale.y = 0.58
	collar.material_override = edge_mat
	parent.add_child(collar)
	var slots: Array = definition.get("slots", []) as Array
	for slot_value in slots:
		_add_rounded_socket_v060(parent, int(slot_value), color)


func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if def_index < 0 or def_index >= connector_defs.size() or def_index == o_ring_index:
		return
	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child is MeshInstance3D or child is CollisionShape3D or str(child.name).begins_with("SpatialSocket_"):
			body.remove_child(child)
			child.queue_free()
	var definition: Dictionary = connector_defs[def_index] as Dictionary
	body.mass = float(definition.get("mass", 0.12))
	body.set_meta("connector_type", def_index)
	_build_connector_visuals_v060(body, def_index)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.54
	shape.height = 0.50
	collision.shape = shape
	body.add_child(collision)
	var slots: Array = definition.get("slots", []) as Array
	for slot_value in slots:
		var slot: int = int(slot_value)
		if slot >= 1000:
			_add_spatial_collision_v041(body, slot)


func _refresh_all_connector_visuals_v060() -> void:
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body) and str(body.get_meta("kind", "")) == "connector":
			_rebuild_connector(body, int(body.get_meta("connector_type", -1)))


func _collect_meshes_v060(node: Node, result: Array) -> void:
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child.name == "SelectionHighlight":
			continue
		if child is MeshInstance3D:
			result.append(child)
		_collect_meshes_v060(child, result)


func _refresh_selection_highlight() -> void:
	_clear_selection_highlight()
	if not is_instance_valid(selected_piece):
		return
	var body: RigidBody3D = selected_piece
	var highlight: Node3D = Node3D.new()
	highlight.name = "SelectionHighlight"
	highlighted_body = body
	body.add_child(highlight)
	var meshes: Array = []
	_collect_meshes_v060(body, meshes)
	for mesh_value in meshes:
		var source: MeshInstance3D = mesh_value as MeshInstance3D
		if source == null or source.mesh == null:
			continue
		var clone: MeshInstance3D = MeshInstance3D.new()
		clone.mesh = source.mesh
		clone.transform = body.global_transform.affine_inverse() * source.global_transform
		clone.scale *= 1.075
		clone.material_override = _selection_mat()
		highlight.add_child(clone)


# Runtime thumbnails are rendered by Godot itself. GitHub only stores the source;
# no external preview service or third-party mesh asset is needed.
func _part_preview_v060(definition: Dictionary, index_value: int, is_rod: bool) -> SubViewportContainer:
	var container: SubViewportContainer = SubViewportContainer.new()
	container.custom_minimum_size = Vector2(180.0, 92.0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(220, 110)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var root_3d: Node3D = Node3D.new()
	viewport.add_child(root_3d)
	var preview_camera: Camera3D = Camera3D.new()
	viewport.add_child(preview_camera)
	preview_camera.position = Vector3(0.0, 4.1, 7.6)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_energy = 1.6
	viewport.add_child(key_light)
	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(35.0, 150.0, 0.0)
	fill_light.light_energy = 0.65
	viewport.add_child(fill_light)
	var color: Color = definition.get("color", Color(0.7, 0.7, 0.7)) as Color
	if is_rod:
		var preview_length: float = clampf(1.4 + float(definition.get("actual_mm", 33.0)) / 80.0, 1.6, 4.0)
		_add_capsule_segment_v060(root_3d, Vector3(-preview_length * 0.5, 0, 0), Vector3(preview_length * 0.5, 0, 0), 0.12, _mat(color))
		_add_capsule_segment_v060(root_3d, Vector3(-preview_length * 0.52, 0, 0), Vector3(-preview_length * 0.40, 0, 0), 0.22, _mat(color.lightened(0.06)))
		_add_capsule_segment_v060(root_3d, Vector3(preview_length * 0.40, 0, 0), Vector3(preview_length * 0.52, 0, 0), 0.22, _mat(color.lightened(0.06)))
	else:
		if str(definition.get("special", "")) == "o_ring":
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = O_RING_INNER_RADIUS_V040
			torus.outer_radius = O_RING_OUTER_RADIUS
			var ring: MeshInstance3D = MeshInstance3D.new()
			ring.mesh = torus
			ring.material_override = _mat(color)
			root_3d.add_child(ring)
		else:
			_build_connector_visuals_v060(root_3d, index_value)
		root_3d.rotation_degrees = Vector3(-18.0, 18.0, 0.0)
	return container


func _refresh_parts_browser_v050() -> void:
	if parts_grid_v050 == null:
		return
	for child_value in parts_grid_v050.get_children():
		var child: Node = child_value as Node
		parts_grid_v050.remove_child(child)
		child.queue_free()
	part_card_buttons_v050.clear()
	var definitions: Array = rod_defs if parts_tab_v050 == 0 else connector_defs
	for i in range(definitions.size()):
		var definition: Dictionary = definitions[i] as Dictionary
		var card: VBoxContainer = VBoxContainer.new()
		card.custom_minimum_size = Vector2(190.0, 142.0)
		card.add_theme_constant_override("separation", 3)
		parts_grid_v050.add_child(card)
		card.add_child(_part_preview_v060(definition, i, parts_tab_v050 == 0))
		var name_value: String = str(definition.get("name", "Part"))
		var detail: String = ""
		if parts_tab_v050 == 0:
			detail = "%.1f mm" % float(definition.get("actual_mm", 0.0))
		else:
			var special: String = str(definition.get("special", ""))
			var slots: Array = definition.get("slots", []) as Array
			detail = "Axle stop" if special == "o_ring" else "%d ports" % slots.size()
		var callback: Callable = func(index_arg: int = i) -> void: _choose_part_v050(index_arg)
		var button: Button = _ui_button("%s\n%s" % [name_value, detail], callback, false)
		button.custom_minimum_size = Vector2(180.0, 48.0)
		button.add_theme_font_size_override("font_size", 13)
		var selected: bool = i == (selected_rod_type if parts_tab_v050 == 0 else selected_connector_type)
		var color: Color = definition.get("color", Color(0.4, 0.5, 0.6)) as Color
		button.add_theme_stylebox_override("normal", _part_card_style_v050(color, selected))
		button.add_theme_stylebox_override("hover", _part_card_style_v050(color.lightened(0.10), selected))
		card.add_child(button)
		part_card_buttons_v050.append(button)
	if parts_rods_button_v050 != null:
		parts_rods_button_v050.text = ("● " if parts_tab_v050 == 0 else "") + "RODS"
	if parts_connectors_button_v050 != null:
		parts_connectors_button_v050.text = ("● " if parts_tab_v050 == 1 else "") + "CONNECTORS"
