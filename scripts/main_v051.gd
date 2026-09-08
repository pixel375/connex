extends "res://scripts/main_v050_hotfix.gd"

const VERSION_051 := "0.5.1"
const TRANSFORM_ITEM_051 := 0
const TRANSFORM_WORLD_051 := 1
const ITEM_AXIS_EPS_051 := 0.985

var transform_space_v051: int = TRANSFORM_ITEM_051

var rotate_item_button_v051: Button
var rotate_world_button_v051: Button
var move_item_button_v051: Button
var move_world_button_v051: Button
var rotate_hint_v051: Label
var move_hint_v051: Label
var rotate_axis_rows_v051: Dictionary = {}
var rotate_axis_buttons_v051: Dictionary = {}
var move_axis_rows_v051: Dictionary = {}
var move_axis_buttons_v051: Dictionary = {}
var reset_rotation_button_v051: Button
var preview_mesh_cache_v051: Dictionary = {}


func _ready() -> void:
	super._ready()
	_remove_attach_line_v051()
	_restore_palette_arrows_v051()
	_make_options_scrollable_v051()
	_rebuild_transform_panels_v051()
	_refresh_parts_browser_v050()
	_refresh_transform_ui_v051()
	attach_overlay_dirty_v050 = true
	_refresh_attach_points_v032()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_051)
	_status("ITEM transforms are now the default. MOVE/ROTATE expose only the physical degrees of freedom allowed by the selected connection.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_051, text]


func _load_settings() -> void:
	super._load_settings()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		transform_space_v051 = clampi(int(cfg.get_value("editor", "transform_space", TRANSFORM_ITEM_051)), TRANSFORM_ITEM_051, TRANSFORM_WORLD_051)


func _save_settings() -> void:
	super._save_settings()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("editor", "transform_space", transform_space_v051)
	cfg.save(SETTINGS_PATH)


func _set_transform_space_v051(space_value: int) -> void:
	transform_space_v051 = clampi(space_value, TRANSFORM_ITEM_051, TRANSFORM_WORLD_051)
	_save_settings()
	_refresh_transform_ui_v051()
	_refresh_gizmo_validity_v030()
	var label := "ITEM / connection" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD / whole build island"
	_status("Transform space: %s" % label)


func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	var mapping: Array = [
		[create_button_v032, EDITOR_CREATE_032, "CREATE"],
		[rotate_button_v032, EDITOR_ROTATE_032, "ROTATE"],
		[move_mode_button_v042, EDITOR_MOVE_042, "MOVE"],
		[attach_button_v032, EDITOR_ATTACH_032, "ATTACH"],
	]
	for entry_value in mapping:
		var entry: Array = entry_value as Array
		var button: Button = entry[0] as Button
		if button == null:
			continue
		var active: bool = editor_mode_v032 == int(entry[1])
		button.text = ("● " if active else "") + str(entry[2])
		button.self_modulate = Color(0.68, 0.94, 1.0) if active else Color.WHITE
	if mode_hint_v032 != null:
		match editor_mode_v032:
			EDITOR_CREATE_032:
				mode_hint_v032.text = "Build pieces normally"
			EDITOR_ROTATE_032:
				mode_hint_v032.text = ("ITEM-local / constrained rotation" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD rotation of connected island")
			EDITOR_MOVE_042:
				mode_hint_v032.text = ("ITEM-local / constrained movement" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD XYZ movement")
			EDITOR_ATTACH_032:
				mode_hint_v032.text = "Tap point → tap compatible point"


func _build_attach_preview_v042() -> void:
	attach_preview_layer_v042 = null
	attach_preview_line_v042 = null


func _update_attach_preview_v042() -> void:
	if attach_preview_line_v042 != null:
		attach_preview_line_v042.visible = false


func _remove_attach_line_v051() -> void:
	if attach_preview_line_v042 != null:
		attach_preview_line_v042.visible = false
	if tether_line_v030 != null:
		tether_line_v030.visible = false


func _counterpart_for_occupied_source_v051(point: Dictionary) -> Dictionary:
	var record: Dictionary = _connection_record_for_point_v032(point)
	if record.is_empty():
		return point
	var type_value := str(point.get("type", ""))
	var kind := str(record.get("kind", ""))
	var body: RigidBody3D = point.get("body") as RigidBody3D
	if type_value == "socket" and is_instance_valid(body) and body == record.get("connector"):
		var rod: RigidBody3D = record.get("rod") as RigidBody3D
		if is_instance_valid(rod):
			if kind == "socket":
				var sign_value := int(record.get("rod_end", 0))
				if sign_value != 0:
					return {"type": "rod_end", "body": rod, "sign": sign_value, "point": _rod_end_v020(rod, sign_value)}
			elif kind == "cross":
				var along := float(record.get("host_along", 0.0))
				return {"type": "rod_body", "body": rod, "along": along, "point": rod.global_position + _rod_axis_v020(rod) * along}
	if type_value == "connector_hub" and kind == "axle" and is_instance_valid(body) and body == record.get("connector"):
		var axle_rod: RigidBody3D = record.get("rod") as RigidBody3D
		if is_instance_valid(axle_rod):
			var axis := _rod_axis_v020(axle_rod)
			var along := (body.global_position - axle_rod.global_position).dot(axis)
			return {"type": "rod_body", "body": axle_rod, "along": along, "point": axle_rod.global_position + axis * along}
	return point


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	var picked: Dictionary = super._pick_initial_attach_point_v035(screen_pos)
	if picked.is_empty():
		return picked
	return _counterpart_for_occupied_source_v051(picked)


func _make_cross_plus_v051(parent: Node3D, point: Vector3, material: StandardMaterial3D, scale_value: float) -> Label3D:
	var marker := Label3D.new()
	marker.text = "+"
	marker.font_size = maxi(34, int(round(230.0 * scale_value)))
	marker.modulate = material.albedo_color if material != null else Color.WHITE
	marker.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
	marker.outline_size = 8
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	parent.add_child(marker)
	marker.global_position = point
	return marker


func _refresh_attach_points_v032() -> void:
	if attach_points_root_v032 == null:
		return
	if not attach_overlay_dirty_v050:
		return
	attach_overlay_dirty_v050 = false
	_clear_children_v030(attach_points_root_v032)
	if editor_mode_v032 != EDITOR_ATTACH_032 or simulating or (help_panel != null and help_panel.visible) or (options_panel != null and options_panel.visible):
		return
	var current_key := _point_key_v032(attach_point_selected_v032)
	var found_selected: bool = current_key.is_empty() or str(attach_point_selected_v032.get("type", "")) == "rod_body"
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		var selected: bool = not current_key.is_empty() and _point_key_v032(point) == current_key
		if selected:
			found_selected = true
			attach_point_selected_v032 = point.duplicate(true)
		var occupied := not _connection_record_for_point_v032(point).is_empty()
		var type_value := str(point.get("type", ""))
		var scale_value: float = 0.18 if selected else (0.105 if type_value in ["connector_hub", "o_ring"] else 0.095)
		if occupied and not selected:
			scale_value = 0.082
		var material := _point_material_v032(point, selected)
		if attach_mode == 2 and type_value == "socket":
			_make_cross_plus_v051(attach_points_root_v032, point.get("point", Vector3.ZERO) as Vector3, material, scale_value)
		else:
			_make_handle_v030(attach_points_root_v032, point.get("point", Vector3.ZERO) as Vector3, material, scale_value)
	if not attach_point_selected_v032.is_empty() and str(attach_point_selected_v032.get("type", "")) == "rod_body":
		var selected_rod: RigidBody3D = attach_point_selected_v032.get("body") as RigidBody3D
		if is_instance_valid(selected_rod) and attach_mode in [1, 2]:
			if attach_mode == 2:
				_make_cross_plus_v051(attach_points_root_v032, attach_point_selected_v032.get("point", Vector3.ZERO) as Vector3, point_selected_mat_v032, 0.20)
			else:
				_make_handle_v030(attach_points_root_v032, attach_point_selected_v032.get("point", Vector3.ZERO) as Vector3, point_selected_mat_v032, 0.18)
		else:
			found_selected = false
	if not found_selected:
		attach_point_selected_v032 = {}
	if not attach_point_selected_v032.is_empty():
		var label := Label3D.new()
		label.text = _point_display_v032(attach_point_selected_v032)
		label.font_size = 23
		label.modulate = Color(1.0, 0.94, 0.22)
		label.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
		label.outline_size = 6
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		attach_points_root_v032.add_child(label)
		label.global_position = (attach_point_selected_v032.get("point", Vector3.ZERO) as Vector3) + Vector3.UP * 0.40
	_update_mode_ui_v032()


func _nearest_slot_v020(connector: RigidBody3D, anchor: Vector3) -> int:
	if not is_instance_valid(connector):
		return -1
	var def_index := int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return -1
	var definition: Dictionary = connector_defs[def_index] as Dictionary
	var local_point: Vector3 = connector.global_transform.affine_inverse() * anchor
	if not bool(definition.get("spatial_3d", false)):
		local_point.y = 0.0
	if local_point.length_squared() < 0.01:
		return -1
	var direction := local_point.normalized()
	var best_slot := -1
	var best_dot := -2.0
	for slot_value in definition.get("slots", []):
		var slot := int(slot_value)
		var score := direction.dot(_slot_dir(slot))
		if score > best_dot:
			best_dot = score
			best_slot = slot
	return best_slot


func _select_slot_strict(connector: RigidBody3D, hit_pos: Vector3) -> int:
	if not is_instance_valid(connector):
		return -1
	var def_index := int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return -1
	var definition: Dictionary = connector_defs[def_index] as Dictionary
	var local := connector.global_transform.affine_inverse() * hit_pos
	if not bool(definition.get("spatial_3d", false)):
		local.y = 0.0
	if local.length() < 0.70:
		return -2
	var direction := local.normalized()
	var best_slot := -1
	var best_dot := 0.67
	for slot_value in definition.get("slots", []):
		var slot := int(slot_value)
		var score := direction.dot(_slot_dir(slot))
		if score > best_dot:
			best_dot = score
			best_slot = slot
	if best_slot < 0:
		return -1
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	return -3 if occupied.has(best_slot) else best_slot


func _socket_basis_v051(direction_value: Vector3) -> Basis:
	var x_axis := direction_value.normalized()
	var y_axis := Vector3.UP
	if absf(x_axis.dot(y_axis)) > 0.96:
		y_axis = Vector3.BACK
	var z_axis := x_axis.cross(y_axis).normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _populate_socket_fork_v051(root: Node3D, color: Color) -> void:
	var main_mat := _mat(color)
	var edge_mat := _mat(color.lightened(0.045))
	_add_box_visual(root, Vector3(0.58, 0.26, 0.28), Vector3(0.70, 0.0, 0.0), 0.0, main_mat)
	for side in [-1.0, 1.0]:
		var sidef := float(side)
		_add_box_visual(root, Vector3(0.78, 0.38, 0.13), Vector3(1.10, 0.0, 0.235 * sidef), 0.0, main_mat)
		_add_cylinder_visual(root, 0.115, 0.38, Vector3(0.75, 0.0, 0.235 * sidef), main_mat, 12)
		_add_cylinder_visual(root, 0.135, 0.38, Vector3(1.47, 0.0, 0.235 * sidef), edge_mat, 14)


func _populate_connector_visual_v051(parent: Node3D, definition: Dictionary) -> void:
	var color: Color = definition.get("color", Color.WHITE) as Color
	var main_mat := _mat(color)
	var edge_mat := _mat(color.lightened(0.05))
	var hub := MeshInstance3D.new()
	var hub_mesh := TorusMesh.new()
	hub_mesh.inner_radius = 0.30
	hub_mesh.outer_radius = 0.60
	hub_mesh.rings = 24
	hub_mesh.ring_segments = 14
	hub.mesh = hub_mesh
	hub.material_override = main_mat
	parent.add_child(hub)
	var collar := MeshInstance3D.new()
	var collar_mesh := TorusMesh.new()
	collar_mesh.inner_radius = 0.286
	collar_mesh.outer_radius = 0.405
	collar_mesh.rings = 20
	collar_mesh.ring_segments = 12
	collar.mesh = collar_mesh
	collar.scale.y = 0.70
	collar.material_override = edge_mat
	parent.add_child(collar)
	for slot_value in definition.get("slots", []):
		var slot := int(slot_value)
		var direction := _slot_dir(slot)
		var socket_root := Node3D.new()
		socket_root.name = "SocketV051_%d" % slot
		socket_root.basis = _socket_basis_v051(direction)
		parent.add_child(socket_root)
		_populate_socket_fork_v051(socket_root, color)
	if bool(definition.get("arc_top", false)):
		_add_arc_bridge_v041(parent, TOP_ARC_SLOTS_041, color)
	if bool(definition.get("arc_bottom", false)):
		_add_arc_bridge_v041(parent, BOTTOM_ARC_SLOTS_041, color)


func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if def_index < 0 or def_index >= connector_defs.size():
		return
	var definition: Dictionary = connector_defs[def_index] as Dictionary
	if str(definition.get("special", "")) == "o_ring":
		return
	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child is MeshInstance3D or child is CollisionShape3D or str(child.name).begins_with("SpatialSocket_") or str(child.name).begins_with("SocketV051_"):
			body.remove_child(child)
			child.queue_free()
	body.mass = float(definition.get("mass", 0.2))
	body.set_meta("connector_type", def_index)
	_populate_connector_visual_v051(body, definition)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.46
	shape.height = 0.52
	collision.shape = shape
	body.add_child(collision)
	if bool(definition.get("spatial_3d", false)):
		for slot_value in definition.get("slots", []):
			var slot := int(slot_value)
			if not _is_spatial_slot_v041(slot):
				continue
			var spatial_collision := CollisionShape3D.new()
			var spatial_shape := BoxShape3D.new()
			spatial_shape.size = Vector3(1.10, 0.52, 0.70)
			spatial_collision.shape = spatial_shape
			spatial_collision.transform = Transform3D(_socket_basis_v051(_slot_dir(slot)), _slot_dir(slot) * 1.04)
			body.add_child(spatial_collision)


func _restore_palette_arrows_v051() -> void:
	if rod_label == null:
		return
	var row := rod_label.get_parent() as HBoxContainer
	if row == null:
		return
	for child_value in row.get_children():
		var button := child_value as Button
		if button != null and button.text in ["◀ Rod", "Rod ▶", "◀ Conn", "Conn ▶"]:
			button.visible = true
			button.custom_minimum_size.x = 82.0
	if parts_button_v050 != null:
		parts_button_v050.custom_minimum_size.x = 92.0
	rod_label.custom_minimum_size.x = 142.0
	connector_label.custom_minimum_size.x = 160.0


func _prev_rod() -> void:
	_cycle_next_rod_v051(-1)


func _next_rod() -> void:
	_cycle_next_rod_v051(1)


func _prev_connector() -> void:
	_cycle_next_connector_v051(-1)


func _next_connector() -> void:
	_cycle_next_connector_v051(1)


func _cycle_next_rod_v051(delta: int) -> void:
	if simulating or rod_defs.is_empty():
		return
	selected_rod_type = wrapi(selected_rod_type + delta, 0, rod_defs.size())
	_status("Next rod: %s" % str((rod_defs[selected_rod_type] as Dictionary).get("name", "Rod")))
	_update_ui()
	_refresh_parts_browser_v050()


func _cycle_next_connector_v051(delta: int) -> void:
	if simulating or connector_defs.is_empty():
		return
	selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
	_status("Next connector: %s" % str((connector_defs[selected_connector_type] as Dictionary).get("name", "Connector")))
	_update_ui()
	_refresh_parts_browser_v050()


func _preview_camera_v051(viewport: SubViewport) -> void:
	var camera_preview := Camera3D.new()
	camera_preview.position = Vector3(0.0, 3.8, 5.0)
	viewport.add_child(camera_preview)
	camera_preview.look_at(Vector3.ZERO, Vector3.UP)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	light.light_energy = 1.6
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28.0, 145.0, 0.0)
	fill.light_energy = 0.55
	viewport.add_child(fill)


func _add_part_preview_v051(parent: VBoxContainer, definition: Dictionary, is_rod: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var container_preview := SubViewportContainer.new()
	container_preview.custom_minimum_size = Vector2(176.0, 92.0)
	container_preview.stretch = true
	container_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container_preview)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(352, 184)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container_preview.add_child(viewport)
	_preview_camera_v051(viewport)
	var visual_root := Node3D.new()
	viewport.add_child(visual_root)
	if is_rod:
		var color: Color = definition.get("color", Color.WHITE) as Color
		var mat := _mat(color)
		_add_cylinder_visual(visual_root, 0.14, 3.0, Vector3.ZERO, mat, 10)
		for angle_deg in [45.0, -45.0]:
			_add_box_visual(visual_root, Vector3(0.34, 2.72, 0.07), Vector3.ZERO, deg_to_rad(angle_deg), mat)
		visual_root.rotation_degrees = Vector3(68.0, 0.0, 55.0)
	else:
		if str(definition.get("special", "")) == "o_ring":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = O_RING_INNER_RADIUS
			torus.outer_radius = O_RING_OUTER_RADIUS
			ring.mesh = torus
			ring.material_override = _mat(Color("3b424b"))
			visual_root.add_child(ring)
		else:
			_populate_connector_visual_v051(visual_root, definition)
		visual_root.rotation_degrees = Vector3(-18.0, 18.0, 0.0)


func _refresh_parts_browser_v050() -> void:
	if parts_grid_v050 == null:
		return
	for child_value in parts_grid_v050.get_children():
		parts_grid_v050.remove_child(child_value)
		child_value.queue_free()
	part_card_buttons_v050.clear()
	var defs: Array = rod_defs if parts_tab_v050 == 0 else connector_defs
	for i in range(defs.size()):
		var definition: Dictionary = defs[i] as Dictionary
		var name_value := str(definition.get("name", "Part"))
		var detail := ""
		if parts_tab_v050 == 0:
			detail = "%.1f mm" % float(definition.get("actual_mm", 0.0))
		else:
			detail = "Axle stop" if str(definition.get("special", "")) == "o_ring" else "%d connection points" % (definition.get("slots", []) as Array).size()
		var selected: bool = i == (selected_rod_type if parts_tab_v050 == 0 else selected_connector_type)
		var color: Color = definition.get("color", Color(0.4, 0.5, 0.6)) as Color
		if DisplayServer.get_name() == "headless":
			var headless_button := _ui_button("%s\n%s" % [name_value, detail], func(index_value: int = i) -> void: _choose_part_v050(index_value), false)
			headless_button.custom_minimum_size = Vector2(180.0, 76.0)
			headless_button.add_theme_stylebox_override("normal", _part_card_style_v050(color, selected))
			parts_grid_v050.add_child(headless_button)
			part_card_buttons_v050.append(headless_button)
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _part_card_style_v050(color, selected))
		card.custom_minimum_size = Vector2(190.0, 148.0)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)
		_add_part_preview_v051(box, definition, parts_tab_v050 == 0)
		var choose := _ui_button("%s\n%s" % [name_value, detail], func(index_value: int = i) -> void: _choose_part_v050(index_value), false)
		choose.custom_minimum_size = Vector2(180.0, 48.0)
		choose.add_theme_font_size_override("font_size", 13)
		box.add_child(choose)
		parts_grid_v050.add_child(card)
		part_card_buttons_v050.append(choose)
	if parts_rods_button_v050 != null:
		parts_rods_button_v050.text = ("● " if parts_tab_v050 == 0 else "") + "RODS"
	if parts_connectors_button_v050 != null:
		parts_connectors_button_v050.text = ("● " if parts_tab_v050 == 1 else "") + "CONNECTORS"


func _find_button_text_v051(node: Node, text_value: String) -> Button:
	if node is Button and (node as Button).text == text_value:
		return node as Button
	for child_value in node.get_children():
		var found := _find_button_text_v051(child_value as Node, text_value)
		if found != null:
			return found
	return null


func _make_options_scrollable_v051() -> void:
	if options_panel == null or options_panel.get_child_count() == 0:
		return
	options_panel.anchor_left = 0.22
	options_panel.anchor_right = 0.78
	options_panel.anchor_top = 0.07
	options_panel.anchor_bottom = 0.91
	var margin := options_panel.get_child(0) as MarginContainer
	if margin == null:
		return
	var content := _find_first_vbox_v050(margin)
	if content == null or content.get_parent() != margin:
		return
	margin.remove_child(content)
	var scroll := ScrollContainer.new()
	scroll.name = "OptionsScrollV051"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var close_button := _find_button_text_v051(content, "Close")
	if close_button != null and close_button.get_parent() == content:
		content.move_child(close_button, content.get_child_count() - 1)


func _motion_mount_record_v051(piece: RigidBody3D) -> Dictionary:
	if not is_instance_valid(piece):
		return {}
	_rebuild_connection_graph_v020()
	var kind := str(piece.get_meta("kind", ""))
	var attached := _connections_for_piece_v020(piece)
	if kind == "connector":
		var primary := _primary_record_for_connector_v020(piece)
		if not primary.is_empty():
			return primary
		for record_value in attached:
			var record: Dictionary = record_value as Dictionary
			if str(record.get("kind", "")) in ["cross", "axle"]:
				return record
		if attached.size() == 1 and not bool(piece.get_meta("root_piece_v020", false)):
			return attached[0] as Dictionary
	elif kind == "rod":
		for record_value in attached:
			var record: Dictionary = record_value as Dictionary
			if str(record.get("kind", "")) == "axle":
				return record
	elif kind == "o_ring":
		for record_value in attached:
			var record: Dictionary = record_value as Dictionary
			if str(record.get("kind", "")) == "o_ring":
				return record
	return {}


func _item_context_v051(piece: RigidBody3D) -> Dictionary:
	if not is_instance_valid(piece):
		return {"valid": false, "reason": "no selected piece"}
	var kind := str(piece.get_meta("kind", ""))
	var mount := _motion_mount_record_v051(piece)
	if mount.is_empty():
		return {"valid": true, "constrained": false, "component": _fixed_component_v020(piece), "anchor": piece.global_position, "piece_kind": kind, "mount": {}}
	var mount_kind := str(mount.get("kind", ""))
	var uid := int(mount.get("uid", -1))
	var component: Array
	if kind == "o_ring":
		component = [piece]
	elif _fixed_connection_kind_v020(mount_kind):
		component = _fixed_component_v020(piece, uid)
		var other := _other_body_v020(mount, piece)
		if _component_has_piece_v020(component, other):
			return {"valid": false, "reason": "connection is part of a closed rigid loop"}
	else:
		component = _fixed_component_v020(piece)
	var axis := _record_axis_v020(mount)
	if kind == "rod" and mount_kind == "axle":
		axis = _rod_axis_v020(piece)
	if axis.length_squared() < 0.5:
		return {"valid": false, "reason": "mount axis is unavailable"}
	return {"valid": true, "constrained": true, "component": component, "anchor": _record_anchor_v020(mount) if mount_kind in ["socket", "cross"] else piece.global_position, "axis": axis.normalized(), "mount": mount, "mount_kind": mount_kind, "piece_kind": kind}


func _basis_for_constraint_axis_v051(axis_value: Vector3) -> Basis:
	var axis := axis_value.normalized()
	var base := Basis(Quaternion(Vector3.UP, axis))
	var x := (base * Vector3.RIGHT).normalized()
	var preferred := Vector3.RIGHT - axis * axis.dot(Vector3.RIGHT)
	if preferred.length_squared() < 0.05:
		preferred = Vector3.BACK - axis * axis.dot(Vector3.BACK)
	if preferred.length_squared() > 0.05:
		var angle := x.signed_angle_to(preferred.normalized(), axis)
		base = Basis(axis, angle) * base
	return base.orthonormalized()


func _space_basis_v051(for_move: bool = false) -> Dictionary:
	if not is_instance_valid(selected_piece):
		return {"valid": false}
	if transform_space_v051 == TRANSFORM_WORLD_051:
		return {"valid": true, "basis": Basis.IDENTITY, "constrained": false, "context": {}}
	var context := _item_context_v051(selected_piece)
	if not bool(context.get("valid", false)):
		return {"valid": false, "context": context}
	if bool(context.get("constrained", false)):
		var mount_kind := str(context.get("mount_kind", ""))
		if for_move and mount_kind == "socket":
			return {"valid": true, "basis": _basis_for_constraint_axis_v051(context.get("axis", Vector3.UP) as Vector3), "constrained": true, "translation_locked": true, "context": context}
		return {"valid": true, "basis": _basis_for_constraint_axis_v051(context.get("axis", Vector3.UP) as Vector3), "constrained": true, "context": context}
	return {"valid": true, "basis": selected_piece.global_transform.basis.orthonormalized(), "constrained": false, "context": context}


func _gizmo_anchor_v030() -> Vector3:
	if not is_instance_valid(selected_piece):
		return Vector3.ZERO
	if transform_space_v051 == TRANSFORM_WORLD_051:
		return selected_piece.global_position
	var context := _item_context_v051(selected_piece)
	if bool(context.get("valid", false)):
		return context.get("anchor", selected_piece.global_position) as Vector3
	return selected_piece.global_position


func _rotation_candidate_v030(axis_value: Vector3, steps: int) -> Dictionary:
	if transform_space_v051 == TRANSFORM_WORLD_051:
		return super._rotation_candidate_v030(axis_value, steps)
	if simulating or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a piece"}
	if steps == 0:
		return {"valid": true, "transforms": {}, "component": []}
	var context := _item_context_v051(selected_piece)
	if not bool(context.get("valid", false)):
		return context
	var axis := axis_value.normalized()
	if bool(context.get("constrained", false)):
		var allowed := context.get("axis", Vector3.UP) as Vector3
		if absf(axis.dot(allowed.normalized())) < ITEM_AXIS_EPS_051:
			return {"valid": false, "reason": "that direction is locked by the connection"}
		axis = allowed.normalized() if axis.dot(allowed) >= 0.0 else -allowed.normalized()
	var component: Array = context.get("component", []) as Array
	if component.is_empty():
		return {"valid": false, "reason": "selected component is unavailable"}
	var anchor := context.get("anchor", selected_piece.global_position) as Vector3
	var transforms := _rotation_delta_map_v020(component, axis, GIZMO_STEP_030 * float(steps), anchor)
	var validation := _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "connection blocks that rotation")), "transforms": transforms, "component": component}
	return {"valid": true, "transforms": transforms, "component": component, "anchor": anchor, "axis": axis}


func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var best: Dictionary = {}
	var best_distance := WORLD_GIZMO_PICK_PX_035
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = gizmo_axes_v030.get(name_value, {}) as Dictionary
		if data.is_empty():
			continue
		var axis := data.get("axis", Vector3.ZERO) as Vector3
		if axis.length_squared() < 0.5:
			continue
		var plus_valid := bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid := bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		if not plus_valid and not minus_valid:
			continue
		var pick := _ring_param_pick_v036(axis, screen_pos, best_distance)
		if pick.is_empty():
			continue
		var distance := float(pick.get("distance", best_distance))
		if distance <= best_distance:
			best_distance = distance
			best = {"name": name_value, "axis": axis, "center": pick.get("center", _gizmo_anchor_v030()), "param": pick.get("param", 0.0)}
	return best


func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not tool_mode_v030.is_empty() or not is_instance_valid(selected_piece):
		return false
	var picked := _pick_gizmo_axis_v030(screen_pos)
	if picked.is_empty():
		return false
	var component: Array
	if transform_space_v051 == TRANSFORM_WORLD_051:
		component = _connected_island_v037(selected_piece)
	else:
		var context := _item_context_v051(selected_piece)
		if not bool(context.get("valid", false)):
			return false
		component = context.get("component", []) as Array
	if component.is_empty():
		return false
	gizmo_drag_active_v030 = true
	gizmo_drag_axis_v030 = picked.get("axis", Vector3.ZERO) as Vector3
	gizmo_drag_axis_name_v030 = str(picked.get("name", ""))
	gizmo_drag_center_v030 = picked.get("center", _gizmo_anchor_v030()) as Vector3
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = component
	gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
	gizmo_drag_last_param_v036 = float(picked.get("param", 0.0))
	gizmo_drag_accum_angle_v036 = 0.0
	_build_rotation_ghost_v030(component)
	_status("%s rotation axis selected — exact 45° snap" % ("ITEM" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD"))
	return true


func _finish_gizmo_drag_v030() -> void:
	if not gizmo_drag_active_v030:
		return
	var steps := gizmo_drag_steps_v030
	var preview := gizmo_drag_preview_v030
	gizmo_drag_active_v030 = false
	gizmo_drag_steps_v030 = 0
	gizmo_drag_accum_angle_v036 = 0.0
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Rotation unchanged")
		return
	if not bool(preview.get("valid", false)):
		_status("Rotation blocked — %s" % str(preview.get("reason", "connection constraint")))
		_refresh_gizmo_validity_v030()
		return
	var space_name := "ITEM" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD"
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated %s by %d°" % [space_name, steps * 45])
	_refresh_gizmo_validity_v030()


func _item_move_candidate_v051(axis_value: Vector3, steps: int) -> Dictionary:
	if simulating or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a piece"}
	if steps == 0:
		return {"valid": true, "transforms": {}, "component": []}
	if transform_space_v051 == TRANSFORM_WORLD_051:
		var world_component := _connected_island_v037(selected_piece)
		var world_delta := axis_value.normalized() * MOVE_STEP_042 * float(steps)
		return {"valid": true, "transforms": _translation_map_v042(world_component, world_delta), "component": world_component, "delta": world_delta, "special": ""}
	var context := _item_context_v051(selected_piece)
	if not bool(context.get("valid", false)):
		return context
	var axis := axis_value.normalized()
	var special := ""
	var mount: Dictionary = context.get("mount", {}) as Dictionary
	var mount_kind := str(context.get("mount_kind", ""))
	var uid := int(mount.get("uid", -1))
	if bool(context.get("constrained", false)):
		if mount_kind == "socket":
			return {"valid": false, "reason": "socket connection has no sliding movement"}
		var allowed := context.get("axis", Vector3.UP) as Vector3
		if absf(axis.dot(allowed.normalized())) < ITEM_AXIS_EPS_051:
			return {"valid": false, "reason": "that direction is locked by the connection"}
		axis = allowed.normalized() if axis.dot(allowed) >= 0.0 else -allowed.normalized()
		if mount_kind in ["cross", "o_ring"]:
			special = mount_kind
	var amount := MOVE_STEP_042 * float(steps)
	var delta := axis * amount
	var host_along_new := 0.0
	if special in ["cross", "o_ring"]:
		var rod: RigidBody3D = mount.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			return {"valid": false, "reason": "host rod is unavailable"}
		var host_axis := _rod_axis_v020(rod)
		var current_along := float(mount.get("host_along", (selected_piece.global_position - rod.global_position).dot(host_axis)))
		var half_len := maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.50)
		host_along_new = clampf(current_along + delta.dot(host_axis), -half_len, half_len)
		delta = host_axis * (host_along_new - current_along)
	var component: Array = context.get("component", []) as Array
	var transforms := _translation_map_v042(component, delta)
	var validation: Dictionary
	if special in ["cross", "o_ring"]:
		validation = _validate_transforms_excluding_v032(transforms, uid)
	else:
		validation = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "another connection blocks movement")), "transforms": transforms}
	return {"valid": true, "transforms": transforms, "component": component, "delta": delta, "special": special, "record_uid": uid, "host_along_new": host_along_new}


func _apply_move_candidate_v051(preview: Dictionary, label: String) -> bool:
	if not bool(preview.get("valid", false)):
		_status("Move blocked — %s" % str(preview.get("reason", "constraint")))
		return false
	var transforms := preview.get("transforms", {}) as Dictionary
	var special := str(preview.get("special", ""))
	if special.is_empty():
		_apply_transform_map_v020(transforms, label)
		return true
	var record := _record_by_uid_v020(int(preview.get("record_uid", -1)))
	if record.is_empty():
		_status("Move blocked — connection changed")
		return false
	var delta := preview.get("delta", Vector3.ZERO) as Vector3
	_apply_transforms_raw_v030(transforms)
	var joint: Joint3D = record.get("joint") as Joint3D
	if is_instance_valid(joint):
		joint.set_meta("host_along_v020", float(preview.get("host_along_new", record.get("host_along", 0.0))))
		joint.global_position += delta
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	_status(label)
	return true


func _apply_move_button_v051(axis_name: String, direction_sign: int) -> void:
	if editor_mode_v032 != EDITOR_MOVE_042 or simulating:
		return
	var axis := _current_gizmo_axis_v051(axis_name, true)
	if axis.length_squared() < 0.5:
		return
	var preview := _item_move_candidate_v051(axis, direction_sign)
	var space_name := "ITEM" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD"
	_apply_move_candidate_v051(preview, "Moved %s %s by %.2f" % [space_name, axis_name, MOVE_STEP_042 * float(direction_sign)])


func _begin_move_drag_v042(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_MOVE_042 or simulating or not is_instance_valid(selected_piece):
		return false
	var picked := _pick_move_axis_v042(screen_pos)
	if picked.is_empty():
		return false
	var preview_one := _item_move_candidate_v051(picked.get("axis", Vector3.ZERO) as Vector3, 1)
	var preview_minus := _item_move_candidate_v051(picked.get("axis", Vector3.ZERO) as Vector3, -1)
	if not bool(preview_one.get("valid", false)) and not bool(preview_minus.get("valid", false)):
		return false
	var component: Array = preview_one.get("component", preview_minus.get("component", [])) as Array
	move_drag_active_v042 = true
	move_drag_axis_name_v042 = str(picked.get("name", ""))
	move_drag_axis_v042 = picked.get("axis", Vector3.ZERO) as Vector3
	move_drag_screen_dir_v042 = picked.get("screen_dir", Vector2.RIGHT) as Vector2
	move_drag_start_screen_v042 = screen_pos
	move_drag_steps_v042 = 0
	move_drag_component_v042 = component
	move_drag_preview_v042 = {"valid": true, "transforms": {}}
	_build_rotation_ghost_v030(component)
	_status("%s move axis selected — %.2f-unit snap" % [("ITEM" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD"), MOVE_STEP_042])
	return true


func _update_move_drag_v042(screen_pos: Vector2) -> void:
	if not move_drag_active_v042:
		return
	var projected := (screen_pos - move_drag_start_screen_v042).dot(move_drag_screen_dir_v042)
	var steps := clampi(int(round(projected / MOVE_GIZMO_STEP_PX_042)), -40, 40)
	if steps == move_drag_steps_v042:
		return
	move_drag_steps_v042 = steps
	if steps == 0:
		move_drag_preview_v042 = {"valid": true, "transforms": {}}
		_update_rotation_ghost_v030({}, true)
		return
	var preview := _item_move_candidate_v051(move_drag_axis_v042, steps)
	move_drag_preview_v042 = preview
	_update_rotation_ghost_v030(preview.get("transforms", {}) as Dictionary, bool(preview.get("valid", false)))
	_status("Move preview: %.2f%s" % [MOVE_STEP_042 * float(steps), "" if bool(preview.get("valid", false)) else " — BLOCKED"])


func _finish_move_drag_v042() -> void:
	if not move_drag_active_v042:
		return
	var steps := move_drag_steps_v042
	var preview := move_drag_preview_v042
	move_drag_active_v042 = false
	move_drag_steps_v042 = 0
	move_drag_component_v042 = []
	move_drag_preview_v042 = {}
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Move unchanged")
		return
	var space_name := "ITEM" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD"
	_apply_move_candidate_v051(preview, "Moved %s by %.2f" % [space_name, MOVE_STEP_042 * float(steps)])


func _hide_children_v051(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		var item := child_value as CanvasItem
		if item != null:
			item.visible = false


func _axis_button_row_v051(parent: VBoxContainer, axis_name: String, rotate: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var minus: Button
	var plus: Button
	if rotate:
		minus = _ui_button("%s −" % axis_name, func() -> void: _apply_rotation_button_v051(axis_name, -1))
		plus = _ui_button("%s +" % axis_name, func() -> void: _apply_rotation_button_v051(axis_name, 1))
		rotate_axis_buttons_v051[axis_name] = [minus, plus]
	else:
		minus = _ui_button("%s −" % axis_name, func() -> void: _apply_move_button_v051(axis_name, -1))
		plus = _ui_button("%s +" % axis_name, func() -> void: _apply_move_button_v051(axis_name, 1))
		move_axis_buttons_v051[axis_name] = [minus, plus]
	row.add_child(minus)
	row.add_child(plus)
	return row


func _rebuild_transform_panels_v051() -> void:
	if rotation_body != null:
		_hide_children_v051(rotation_body)
		rotation_body.add_child(_section_label("TRANSFORM SPACE"))
		var space_row := HBoxContainer.new()
		space_row.add_theme_constant_override("separation", 4)
		rotation_body.add_child(space_row)
		rotate_item_button_v051 = _ui_button("ITEM", func() -> void: _set_transform_space_v051(TRANSFORM_ITEM_051), true)
		rotate_world_button_v051 = _ui_button("WORLD", func() -> void: _set_transform_space_v051(TRANSFORM_WORLD_051), true)
		space_row.add_child(rotate_item_button_v051)
		space_row.add_child(rotate_world_button_v051)
		rotate_hint_v051 = Label.new()
		rotate_hint_v051.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rotate_hint_v051.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotate_hint_v051.add_theme_font_size_override("font_size", 11)
		rotation_body.add_child(rotate_hint_v051)
		for axis_name in ["X", "Y", "Z"]:
			rotate_axis_rows_v051[axis_name] = _axis_button_row_v051(rotation_body, axis_name, true)
		reset_rotation_button_v051 = _ui_button("Reset Placement Rotation", _reset_rotation_v020)
		rotation_body.add_child(reset_rotation_button_v051)
	if move_body != null:
		_hide_children_v051(move_body)
		move_body.add_child(_section_label("TRANSFORM SPACE"))
		var move_space_row := HBoxContainer.new()
		move_space_row.add_theme_constant_override("separation", 4)
		move_body.add_child(move_space_row)
		move_item_button_v051 = _ui_button("ITEM", func() -> void: _set_transform_space_v051(TRANSFORM_ITEM_051), true)
		move_world_button_v051 = _ui_button("WORLD", func() -> void: _set_transform_space_v051(TRANSFORM_WORLD_051), true)
		move_space_row.add_child(move_item_button_v051)
		move_space_row.add_child(move_world_button_v051)
		move_hint_v051 = Label.new()
		move_hint_v051.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		move_hint_v051.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		move_hint_v051.add_theme_font_size_override("font_size", 11)
		move_body.add_child(move_hint_v051)
		for axis_name in ["X", "Y", "Z"]:
			move_axis_rows_v051[axis_name] = _axis_button_row_v051(move_body, axis_name, false)
	_refresh_transform_ui_v051()


func _current_gizmo_axis_v051(axis_name: String, for_move: bool) -> Vector3:
	var space := _space_basis_v051(for_move)
	if not bool(space.get("valid", false)):
		return Vector3.ZERO
	var constrained := bool(space.get("constrained", false))
	if constrained and axis_name != "Y":
		return Vector3.ZERO
	if for_move and bool(space.get("translation_locked", false)):
		return Vector3.ZERO
	var basis: Basis = space.get("basis", Basis.IDENTITY) as Basis
	match axis_name:
		"X": return (basis * Vector3.RIGHT).normalized()
		"Y": return (basis * Vector3.UP).normalized()
		"Z": return (basis * Vector3.BACK).normalized()
	return Vector3.ZERO


func _apply_rotation_button_v051(axis_name: String, direction_sign: int) -> void:
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating:
		return
	var axis := _current_gizmo_axis_v051(axis_name, false)
	if axis.length_squared() < 0.5:
		return
	var preview := _rotation_candidate_v030(axis, direction_sign)
	if not bool(preview.get("valid", false)):
		_status("Rotation blocked — %s" % str(preview.get("reason", "constraint")))
		return
	var space_name := "ITEM" if transform_space_v051 == TRANSFORM_ITEM_051 else "WORLD"
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated %s %s by %d°" % [space_name, axis_name, direction_sign * 45])
	_refresh_gizmo_validity_v030()


func _refresh_transform_ui_v051() -> void:
	var item_active := transform_space_v051 == TRANSFORM_ITEM_051
	for button_value in [rotate_item_button_v051, move_item_button_v051]:
		var button := button_value as Button
		if button != null:
			button.text = ("● " if item_active else "") + "ITEM"
	for button_value in [rotate_world_button_v051, move_world_button_v051]:
		var button := button_value as Button
		if button != null:
			button.text = ("● " if not item_active else "") + "WORLD"
	var rotate_space := _space_basis_v051(false)
	var move_space := _space_basis_v051(true)
	var rotate_constrained := bool(rotate_space.get("constrained", false))
	var move_constrained := bool(move_space.get("constrained", false))
	if rotate_hint_v051 != null:
		if transform_space_v051 == TRANSFORM_WORLD_051:
			rotate_hint_v051.text = "WORLD: rotates the entire connected island around the selected piece."
		elif rotate_constrained:
			rotate_hint_v051.text = "ITEM: only the real mount/rod axis is free. Attached branches on this side follow it."
		else:
			rotate_hint_v051.text = "ITEM: X/Y/Z follow the selected piece, not the world."
	if move_hint_v051 != null:
		if transform_space_v051 == TRANSFORM_WORLD_051:
			move_hint_v051.text = "WORLD: moves the entire connected island."
		elif bool(move_space.get("translation_locked", false)):
			move_hint_v051.text = "ITEM: this socket mount has no translational degree of freedom."
		elif move_constrained:
			move_hint_v051.text = "ITEM: only sliding along the host/axle rod is valid."
		else:
			move_hint_v051.text = "ITEM: X/Y/Z follow the selected piece."
	for axis_name in ["X", "Y", "Z"]:
		var rrow := rotate_axis_rows_v051.get(axis_name) as HBoxContainer
		var mrow := move_axis_rows_v051.get(axis_name) as HBoxContainer
		var raxis := _current_gizmo_axis_v051(axis_name, false)
		var maxis := _current_gizmo_axis_v051(axis_name, true)
		if rrow != null:
			rrow.visible = raxis.length_squared() > 0.5
		if mrow != null:
			mrow.visible = maxis.length_squared() > 0.5
		var rbuttons: Array = rotate_axis_buttons_v051.get(axis_name, []) as Array
		for i in range(rbuttons.size()):
			var rb := rbuttons[i] as Button
			if rb != null:
				var sign_value := -1 if i == 0 else 1
				rb.disabled = raxis.length_squared() < 0.5 or not bool(_rotation_candidate_v030(raxis, sign_value).get("valid", false))
				rb.text = (("Axis" if rotate_constrained and axis_name == "Y" else axis_name) + (" −" if i == 0 else " +"))
		var mbuttons: Array = move_axis_buttons_v051.get(axis_name, []) as Array
		for i in range(mbuttons.size()):
			var mb := mbuttons[i] as Button
			if mb != null:
				var sign_value := -1 if i == 0 else 1
				mb.disabled = maxis.length_squared() < 0.5 or not bool(_item_move_candidate_v051(maxis, sign_value).get("valid", false))
				mb.text = (("Slide" if move_constrained and axis_name == "Y" else axis_name) + (" −" if i == 0 else " +"))
	if reset_rotation_button_v051 != null:
		reset_rotation_button_v051.disabled = simulating or _selected_kind() != "connector"
	_update_mode_ui_v032()


func _layout_right_panels_v032() -> void:
	if rotation_panel == null or move_panel == null:
		return
	rotation_panel.anchor_left = 1.0
	rotation_panel.anchor_right = 1.0
	move_panel.anchor_left = 1.0
	move_panel.anchor_right = 1.0
	rotation_panel.offset_left = -248.0
	rotation_panel.offset_right = -8.0
	move_panel.offset_left = -248.0
	move_panel.offset_right = -8.0
	rotation_panel.clip_contents = true
	move_panel.clip_contents = true
	var top_value := 112.0
	var collapsed := 48.0
	var gap := 6.0
	var viewport_height := get_viewport().get_visible_rect().size.y
	var bottom_limit := maxf(top_value + 300.0, viewport_height - 106.0)
	if right_panel_state_v037 == "rotate":
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = bottom_limit - collapsed - gap
		move_panel.offset_top = rotation_panel.offset_bottom + gap
		move_panel.offset_bottom = move_panel.offset_top + collapsed
	elif right_panel_state_v037 == "move":
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = bottom_limit
	else:
		rotation_panel.offset_top = top_value
		rotation_panel.offset_bottom = top_value + collapsed
		move_panel.offset_top = top_value + collapsed + gap
		move_panel.offset_bottom = move_panel.offset_top + collapsed


func _set_axis_data_v051(data: Dictionary, axis: Vector3, visible_value: bool) -> void:
	data["axis"] = axis if visible_value else Vector3.ZERO
	var root_node := data.get("root") as Node3D
	if root_node != null:
		root_node.visible = visible_value


func _update_gizmo_spaces_v051() -> void:
	if not is_instance_valid(selected_piece):
		return
	var rotate_space := _space_basis_v051(false)
	if gizmo_root_v030 != null and editor_mode_v032 == EDITOR_ROTATE_032 and bool(rotate_space.get("valid", false)):
		var rbasis: Basis = rotate_space.get("basis", Basis.IDENTITY) as Basis
		var rscale := clampf(camera_distance / 19.0, 0.62, 2.25)
		gizmo_root_v030.global_basis = rbasis
		gizmo_root_v030.scale = Vector3.ONE * rscale
		gizmo_root_v030.global_position = _gizmo_anchor_v030()
		var rconstrained := bool(rotate_space.get("constrained", false))
		_set_axis_data_v051(gizmo_axes_v030.get("X", {}) as Dictionary, (rbasis * Vector3.RIGHT).normalized(), not rconstrained)
		_set_axis_data_v051(gizmo_axes_v030.get("Y", {}) as Dictionary, (rbasis * Vector3.UP).normalized(), true)
		_set_axis_data_v051(gizmo_axes_v030.get("Z", {}) as Dictionary, (rbasis * Vector3.BACK).normalized(), not rconstrained)
		gizmo_root_v030.visible = not simulating and not (help_panel != null and help_panel.visible) and not (options_panel != null and options_panel.visible)
	var move_space := _space_basis_v051(true)
	if move_gizmo_root_v042 != null and editor_mode_v032 == EDITOR_MOVE_042 and bool(move_space.get("valid", false)):
		var mbasis: Basis = move_space.get("basis", Basis.IDENTITY) as Basis
		var mscale := clampf(camera_distance / 19.0, 0.62, 2.10)
		move_gizmo_root_v042.global_basis = mbasis
		move_gizmo_root_v042.scale = Vector3.ONE * mscale
		move_gizmo_root_v042.global_position = selected_piece.global_position
		var mconstrained := bool(move_space.get("constrained", false))
		var locked := bool(move_space.get("translation_locked", false))
		_set_axis_data_v051(move_gizmo_axes_v042.get("X", {}) as Dictionary, (mbasis * Vector3.RIGHT).normalized(), not mconstrained and not locked)
		_set_axis_data_v051(move_gizmo_axes_v042.get("Y", {}) as Dictionary, (mbasis * Vector3.UP).normalized(), not locked)
		_set_axis_data_v051(move_gizmo_axes_v042.get("Z", {}) as Dictionary, (mbasis * Vector3.BACK).normalized(), not mconstrained and not locked)
		move_gizmo_root_v042.visible = not locked and not simulating and not (help_panel != null and help_panel.visible) and not (options_panel != null and options_panel.visible)


func _refresh_gizmo_validity_v030() -> void:
	super._refresh_gizmo_validity_v030()


func _update_ui() -> void:
	super._update_ui()
	_refresh_transform_ui_v051()


func _process(delta: float) -> void:
	super._process(delta)
	_update_gizmo_spaces_v051()


func _pan_camera(screen_delta: Vector2) -> void:
	if camera == null:
		return
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	var x_factor := -1.0 if reverse_pan_x else 1.0
	var y_factor := -1.0 if reverse_pan_y else 1.0
	var move_scale := camera_distance * 0.0027 * camera_sensitivity
	camera_target += (-right * screen_delta.x * x_factor + up * screen_delta.y * y_factor) * move_scale
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.y = clampf(camera_target.y, -60.0, 220.0)


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label := _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nITEM vs WORLD: ITEM is the default. A free piece uses its own local X/Y/Z. A mounted piece shows only its real physical degree of freedom. WORLD intentionally transforms the entire connected island. The ITEM/WORLD choice is shared by both Rotate and Move panels.\n\nCROSS: a cross-mounted connector rotates only around the host rod and slides only along that rod. AXLE: a connector or axle rod slides/rotates along its axle axis; fixed attachments on the selected side follow, while the free axle side does not. SOCKET: mount-axis rotation is possible when the remaining topology permits it, but translation is locked.\n\nATTACH: no preview line. Tap one connection point and then a compatible point. If an occupied connector port is tapped, Connex automatically treats the connected rod side as the moving source, so selecting a different port re-seats that connection reliably. CROSS ports use bold + markers.\n\nPARTS: quick Rod/Conn arrows are back, and PARTS opens visual rendered cards. Both change the NEXT part only.\n\nOPTIONS: the panel scrolls, so Saves & Recovery and Physics controls are reachable.\n\nCAMERA: one finger orbits; two fingers pan in the full screen plane and pinch-zoom.\n\n3D CONNECTORS: every extra 11/14-point spatial socket participates in picking and ATTACH." % VERSION_051


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var release: Dictionary = parsed as Dictionary
	var latest := str(release.get("tag_name", "")).trim_prefix("v")
	if latest.is_empty():
		return
	if _compare_versions_v021(latest, VERSION_051) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_051)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
