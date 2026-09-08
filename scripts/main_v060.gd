extends "res://scripts/main_v050_hotfix.gd"

const VERSION_060 := "0.6.0"
const TRANSFORM_ITEM_060 := 0
const TRANSFORM_WORLD_060 := 1
const PAN_SCALE_060 := 0.0017
const ATTACH_PICK_RADIUS_060 := 88.0

var rotate_space_v060: int = TRANSFORM_ITEM_060
var move_space_v060: int = TRANSFORM_ITEM_060
var rotate_space_button_v060: Button
var move_space_button_v060: Button
var options_scroll_v060: ScrollContainer
var rotation_scroll_v060: ScrollContainer
var move_scroll_v060: ScrollContainer
var pan_touch_positions_v060: Dictionary = {}
var pan_center_valid_v060: bool = false
var pan_center_v060: Vector2 = Vector2.ZERO
var item_move_drag_context_v060: Dictionary = {}
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
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_060)
	_status("ITEM transforms are now mechanical by default; WORLD is an explicit whole-build transform. Attachment, camera and menu fixes are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_060, text]


# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------

func _load_settings() -> void:
	super._load_settings()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	rotate_space_v060 = clampi(int(cfg.get_value("editor", "rotate_space", TRANSFORM_ITEM_060)), TRANSFORM_ITEM_060, TRANSFORM_WORLD_060)
	move_space_v060 = clampi(int(cfg.get_value("editor", "move_space", TRANSFORM_ITEM_060)), TRANSFORM_ITEM_060, TRANSFORM_WORLD_060)


func _save_settings() -> void:
	super._save_settings()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("editor", "rotate_space", rotate_space_v060)
	cfg.set_value("editor", "move_space", move_space_v060)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		_status("Could not save editor transform settings (%s)" % error_string(err))


# -----------------------------------------------------------------------------
# UI fixes: correct mode highlight, restore the quick arrows as a hybrid palette,
# make Options/right-side bodies scrollable, and expose ITEM/WORLD explicitly.
# -----------------------------------------------------------------------------

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
		match editor_mode_v032:
			EDITOR_MOVE_042:
				mode_hint_v032.text = "ITEM mechanical move" if move_space_v060 == TRANSFORM_ITEM_060 else "WORLD whole-build move"
			EDITOR_ROTATE_032:
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
			var button := child as Button
			if button.text in ["◀ Rod", "Rod ▶", "◀ Conn", "Conn ▶"]:
				button.visible = true
		_restore_palette_buttons_recursive_v060(child)


func _change_rod_type(delta: int) -> void:
	if simulating:
		return
	selected_rod_type = wrapi(selected_rod_type + delta, 0, rod_defs.size())
	_update_ui()
	_refresh_parts_browser_v050()
	_status("Next rod: %s" % str(rod_defs[selected_rod_type].get("name", "Rod")))


func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
	_update_ui()
	_refresh_parts_browser_v050()
	_status("Next connector: %s" % str(connector_defs[selected_connector_type].get("name", "Connector")))


func _set_selected(body: RigidBody3D) -> void:
	# Selection and the future-part palette are deliberately independent in v0.6.
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
		var found := _find_first_margin_v060(child_value as Node)
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
	var margin := _find_first_margin_v060(options_panel)
	if margin == null or margin.get_child_count() == 0:
		return
	var body := _find_first_vbox_v050(margin)
	if body == null or body.get_parent() is ScrollContainer:
		return
	var parent := body.get_parent()
	var index := body.get_index()
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
	var parent := body.get_parent()
	if parent == null:
		return null
	var index := body.get_index()
	parent.remove_child(body)
	var scroll := ScrollContainer.new()
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
	_cancel_rotation_drag_v060()
	_save_settings()
	_update_ui()
	_status("Rotate space: %s" % ("ITEM — only valid mechanical freedom" if rotate_space_v060 == TRANSFORM_ITEM_060 else "WORLD — whole connected construction"))


func _toggle_move_space_v060() -> void:
	move_space_v060 = TRANSFORM_WORLD_060 if move_space_v060 == TRANSFORM_ITEM_060 else TRANSFORM_ITEM_060
	_cancel_move_drag_v060()
	_save_settings()
	_update_ui()
	_status("Move space: %s" % ("ITEM — only valid mechanical freedom" if move_space_v060 == TRANSFORM_ITEM_060 else "WORLD — whole connected construction"))


func _layout_right_panels_v032() -> void:
	if rotation_panel == null or move_panel == null:
		return
	var top_value := 112.0
	var collapsed := 50.0
	var gap := 6.0
	var viewport_height := get_viewport().get_visible_rect().size.y
	var bottom_limit := maxf(top_value + 260.0, viewport_height - 108.0)
	for panel_value in [rotation_panel, move_panel]:
		var panel := panel_value as PanelContainer
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


# -----------------------------------------------------------------------------
# Attachment editor: no tether line, mode-specific points, bold CROSS + markers,
# occupied source normalization and larger special-port picking.
# -----------------------------------------------------------------------------

func _build_attach_preview_v042() -> void:
	# Deliberately removed in v0.6. The live tether was visually noisy and prone to
	# stale target state. Attachment is now click-point -> click-point only.
	attach_preview_layer_v042 = null
	attach_preview_line_v042 = null


func _update_attach_preview_v042() -> void:
	if attach_preview_line_v042 != null:
		attach_preview_line_v042.visible = false


func _point_visible_for_mode_v060(point: Dictionary) -> bool:
	var type_value := str(point.get("type", ""))
	match attach_mode:
		0:
			return type_value in ["rod_end", "socket"]
		1:
			return type_value in ["rod_body", "connector_hub", "o_ring"]
		2:
			return type_value in ["rod_body", "socket"]
	return false


func _make_cross_plus_v060(point: Dictionary, selected: bool) -> void:
	var material := _point_material_v032(point, selected)
	var label := Label3D.new()
	label.text = "+"
	label.font_size = 62 if selected else 50
	label.modulate = material.albedo_color if material != null else Color(0.2, 1.0, 0.5)
	label.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
	label.outline_size = 10 if selected else 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	attach_points_root_v032.add_child(label)
	label.global_position = point.get("point", Vector3.ZERO) as Vector3


func _refresh_attach_points_v032() -> void:
	if attach_points_root_v032 == null:
		return
	if not attach_overlay_dirty_v050:
		return
	attach_overlay_dirty_v050 = false
	_clear_children_v030(attach_points_root_v032)
	if editor_mode_v032 != EDITOR_ATTACH_032 or simulating or _modal_open_v060():
		return
	var current_key := _point_key_v032(attach_point_selected_v032)
	var matched_selection := current_key.is_empty()
	for point_value in _all_attach_points_v032():
		var point := point_value as Dictionary
		if not _point_visible_for_mode_v060(point):
			continue
		var key := _point_key_v032(point)
		var selected := not current_key.is_empty() and key == current_key
		if selected:
			matched_selection = true
			attach_point_selected_v032 = point.duplicate(true)
		if attach_mode == 2:
			_make_cross_plus_v060(point, selected)
		else:
			var marker_scale := 0.36 if selected else (0.22 if str(point.get("type", "")) != "rod_body" else 0.16)
			_make_handle_v030(attach_points_root_v032, point.get("point", Vector3.ZERO) as Vector3, _point_material_v032(point, selected), marker_scale)
		if selected:
			var info := Label3D.new()
			info.text = _point_display_v032(point)
			info.font_size = 32
			info.modulate = Color(1.0, 0.94, 0.25)
			info.outline_modulate = Color(0.01, 0.02, 0.03, 1.0)
			info.outline_size = 7
			info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			info.no_depth_test = true
			attach_points_root_v032.add_child(info)
			info.global_position = (point.get("point", Vector3.ZERO) as Vector3) + Vector3.UP * 0.55
	if not matched_selection:
		attach_point_selected_v032 = {}
	_update_mode_ui_v032()


func _normalize_occupied_source_v060(point: Dictionary) -> Dictionary:
	if point.is_empty():
		return point
	var record := _connection_record_for_point_v032(point)
	if record.is_empty():
		return point
	var type_value := str(point.get("type", ""))
	var kind := str(record.get("kind", ""))
	if attach_mode == 0 and type_value == "socket" and kind == "socket":
		var rod := record.get("rod") as RigidBody3D
		var sign_value := int(record.get("rod_end", 0))
		if is_instance_valid(rod) and sign_value != 0:
			return {"type": "rod_end", "body": rod, "sign": sign_value, "point": _rod_end_v020(rod, sign_value)}
	return point


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	var visible_candidates: Array = []
	for point_value in _all_attach_points_v032():
		var point := point_value as Dictionary
		if _point_visible_for_mode_v060(point) and _allowed_initial_point_v035(point):
			visible_candidates.append(point)
	var direct := _nearest_projected_candidate_v030(visible_candidates, screen_pos, ATTACH_PICK_RADIUS_060)
	if not direct.is_empty():
		return _normalize_occupied_source_v060(direct)
	var fallback := super._pick_initial_attach_point_v035(screen_pos)
	return _normalize_occupied_source_v060(fallback)


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	var expected := _expected_target_types_v035(str(source.get("type", "")))
	if expected.is_empty():
		return {}
	if "rod_body" in expected:
		return super._pick_attach_target_v035(screen_pos, source)
	var candidates: Array = []
	for point_value in _all_attach_points_v032():
		var point := point_value as Dictionary
		if not (str(point.get("type", "")) in expected):
			continue
		if _attach_target_is_available_v040(source, point):
			candidates.append(point)
	var direct := _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PICK_RADIUS_060)
	if not direct.is_empty():
		return direct
	return super._pick_attach_target_v035(screen_pos, source)


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	if simulating:
		return
	attach_overlay_dirty_v050 = true
	if not attach_point_selected_v032.is_empty() and _selected_point_hit_v035(screen_pos):
		_deselect_attach_point_v032(false)
		_status("Attachment source deselected")
		return
	if attach_point_selected_v032.is_empty():
		var source := _pick_initial_attach_point_v035(screen_pos)
		if source.is_empty():
			_status(["SOCKET: tap a rod end or connector socket", "AXLE: tap a hub/O-Ring or exact rod shaft position", "CROSS: tap a + socket or + rod-shaft point"][attach_mode])
			_refresh_attach_points_v032()
			return
		attach_point_selected_v032 = source.duplicate(true)
		_refresh_attach_points_v032()
		_status("Source selected: %s. Tap the destination point." % _point_display_v032(source))
		return
	var source_selected := attach_point_selected_v032
	var target := _pick_attach_target_v035(screen_pos, source_selected)
	if target.is_empty():
		_status("Source stays selected — tap another compatible point")
		_refresh_attach_points_v032()
		return
	var source := source_selected
	if str(source.get("type", "")) == "rod_body" and str(target.get("type", "")) == "o_ring":
		var swap := source
		source = target
		target = swap
	if _pair_mode_v032(source, target) < 0:
		_status("Those points are not compatible in %s mode" % ["SOCKET", "AXLE", "CROSS"][attach_mode])
		_refresh_attach_points_v032()
		return
	if _connect_points_v035(source, target):
		attach_point_selected_v032 = {}
		attach_spatial_dirty_v050 = true
	else:
		attach_point_selected_v032 = source_selected
	attach_overlay_dirty_v050 = true
	_refresh_attach_points_v032()


func _point_display_v032(point: Dictionary) -> String:
	if str(point.get("type", "")) == "socket":
		var slot := int(point.get("slot", -1))
		match slot:
			1001:
				return "Upper-right spatial socket"
			1002:
				return "Top spatial socket"
			1003:
				return "Upper-left spatial socket"
			2001:
				return "Lower-right spatial socket"
			2002:
				return "Bottom spatial socket"
			2003:
				return "Lower-left spatial socket"
	return super._point_display_v032(point)


# -----------------------------------------------------------------------------
# Mechanical ITEM transform contexts.
# -----------------------------------------------------------------------------

func _record_for_kind_v060(piece: RigidBody3D, kind_value: String) -> Dictionary:
	if not is_instance_valid(piece):
		return {}
	_rebuild_connection_graph_v020()
	for record_value in _connections_for_piece_v020(piece):
		var record := record_value as Dictionary
		if str(record.get("kind", "")) == kind_value:
			return record
	return {}


func _item_rotation_context_v060(piece: RigidBody3D = selected_piece) -> Dictionary:
	if simulating or not is_instance_valid(piece):
		return {"valid": false, "reason": "select a piece"}
	_rebuild_connection_graph_v020()
	var kind := str(piece.get_meta("kind", ""))
	if kind == "o_ring":
		return {"valid": false, "reason": "O-Ring rotation has no useful mechanical degree of freedom"}
	if kind == "connector":
		var cross := _record_for_kind_v060(piece, "cross")
		if not cross.is_empty():
			var cross_rod := cross.get("rod") as RigidBody3D
			return {"valid": true, "kind": "cross", "record": cross, "axis": _rod_axis_v020(cross_rod), "anchor": _record_anchor_v020(cross), "component": _fixed_component_v020(piece, int(cross.get("uid", -1))), "names": ["Y"]}
		var axle := _record_for_kind_v060(piece, "axle")
		if not axle.is_empty():
			var axle_rod := axle.get("rod") as RigidBody3D
			return {"valid": true, "kind": "axle", "record": axle, "axis": _rod_axis_v020(axle_rod), "anchor": _record_anchor_v020(axle), "component": _fixed_component_v020(piece), "names": ["Y"]}
		var primary := _primary_record_for_connector_v020(piece)
		if not primary.is_empty() and str(primary.get("kind", "")) == "socket":
			return {"valid": true, "kind": "socket_roll", "record": primary, "axis": _record_axis_v020(primary), "anchor": _record_anchor_v020(primary), "component": _fixed_component_v020(piece, int(primary.get("uid", -1))), "names": ["Y"]}
	var axle_for_rod := _record_for_kind_v060(piece, "axle") if kind == "rod" else {}
	if not axle_for_rod.is_empty():
		var host_rod := axle_for_rod.get("rod") as RigidBody3D
		return {"valid": true, "kind": "axle", "record": axle_for_rod, "axis": _rod_axis_v020(host_rod), "anchor": piece.global_position, "component": _fixed_component_v020(piece), "names": ["Y"]}
	var connections := _connections_for_piece_v020(piece)
	if connections.is_empty():
		return {"valid": true, "kind": "free", "record": {}, "component": [piece], "anchor": piece.global_position, "basis": piece.global_transform.basis.orthonormalized(), "names": ["X", "Y", "Z"]}
	return {"valid": false, "reason": "this connection has no independent rotational freedom"}


func _item_move_context_v060(piece: RigidBody3D = selected_piece) -> Dictionary:
	if simulating or not is_instance_valid(piece):
		return {"valid": false, "reason": "select a piece"}
	_rebuild_connection_graph_v020()
	var kind := str(piece.get_meta("kind", ""))
	if kind == "o_ring":
		var host := _find_o_ring_host(piece)
		if is_instance_valid(host):
			return {"valid": true, "kind": "o_ring", "axis": _rod_axis_v020(host), "host": host, "component": [piece], "names": ["Y"]}
	if kind == "connector":
		var cross := _record_for_kind_v060(piece, "cross")
		if not cross.is_empty():
			var cross_rod := cross.get("rod") as RigidBody3D
			return {"valid": true, "kind": "cross", "record": cross, "axis": _rod_axis_v020(cross_rod), "host": cross_rod, "component": _fixed_component_v020(piece, int(cross.get("uid", -1))), "names": ["Y"]}
	var axle := _record_for_kind_v060(piece, "axle")
	if not axle.is_empty():
		var axle_rod := axle.get("rod") as RigidBody3D
		return {"valid": true, "kind": "axle", "record": axle, "axis": _rod_axis_v020(axle_rod), "host": axle_rod, "component": _fixed_component_v020(piece), "names": ["Y"]}
	if _connections_for_piece_v020(piece).is_empty():
		return {"valid": true, "kind": "free", "basis": piece.global_transform.basis.orthonormalized(), "component": [piece], "names": ["X", "Y", "Z"]}
	return {"valid": false, "reason": "this connection has no independent translation freedom"}


func _basis_with_y_v060(axis_value: Vector3) -> Basis:
	var y := axis_value.normalized()
	var x := Vector3.RIGHT - y * Vector3.RIGHT.dot(y)
	if x.length_squared() < 0.04:
		x = Vector3.BACK - y * Vector3.BACK.dot(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z).orthonormalized()


func _logical_axis_v060(name_value: String, basis_value: Basis) -> Vector3:
	match name_value:
		"X":
			return (basis_value * Vector3.RIGHT).normalized()
		"Y":
			return (basis_value * Vector3.UP).normalized()
		"Z":
			return (basis_value * Vector3.BACK).normalized()
	return Vector3.ZERO


func _item_axis_for_context_v060(context: Dictionary, name_value: String) -> Vector3:
	if not bool(context.get("valid", false)) or not (name_value in (context.get("names", []) as Array)):
		return Vector3.ZERO
	if str(context.get("kind", "")) == "free":
		return _logical_axis_v060(name_value, context.get("basis", Basis.IDENTITY) as Basis)
	return (context.get("axis", Vector3.ZERO) as Vector3).normalized() if name_value == "Y" else Vector3.ZERO


func _item_rotation_candidate_v060(axis_value: Vector3, steps: int) -> Dictionary:
	var context := _item_rotation_context_v060()
	if not bool(context.get("valid", false)):
		return context
	var matched_axis := Vector3.ZERO
	for name_value in context.get("names", []) as Array:
		var candidate_axis := _item_axis_for_context_v060(context, str(name_value))
		if candidate_axis.length_squared() > 0.5 and absf(candidate_axis.dot(axis_value.normalized())) > 0.985:
			matched_axis = candidate_axis if candidate_axis.dot(axis_value) >= 0.0 else -candidate_axis
			break
	if matched_axis.length_squared() < 0.5:
		return {"valid": false, "reason": "that axis is not a valid mechanical rotation for this piece"}
	if steps == 0:
		return {"valid": true, "transforms": {}, "component": context.get("component", []), "context": context}
	var transforms := _rotation_delta_map_v020(context.get("component", []) as Array, matched_axis, GIZMO_STEP_030 * float(steps), context.get("anchor", selected_piece.global_position) as Vector3)
	var record := context.get("record", {}) as Dictionary
	var excluded_uid := int(record.get("uid", -1))
	var validation := _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "another connection blocks this rotation")), "transforms": transforms, "component": context.get("component", []), "context": context}
	return {"valid": true, "transforms": transforms, "component": context.get("component", []), "context": context, "axis": matched_axis, "anchor": context.get("anchor", selected_piece.global_position)}


func _rotation_candidate_v030(axis_value: Vector3, steps: int) -> Dictionary:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		return super._rotation_candidate_v030(axis_value, steps)
	return _item_rotation_candidate_v060(axis_value, steps)


func _roll_candidate_v030(direction_sign: int) -> Dictionary:
	if _selected_kind() == "connector" and is_instance_valid(selected_piece):
		var context := _item_rotation_context_v060(selected_piece)
		if bool(context.get("valid", false)) and str(context.get("kind", "")) in ["cross", "axle", "socket_roll"]:
			return _item_rotation_candidate_v060((context.get("axis", Vector3.ZERO) as Vector3).normalized(), direction_sign)
	return super._roll_candidate_v030(direction_sign)


func _apply_roll_v030(direction_sign: int) -> void:
	var preview := _roll_candidate_v030(direction_sign)
	if not bool(preview.get("valid", false)):
		_status("Item rotation blocked — %s" % str(preview.get("reason", "no valid mount axis")))
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated ITEM %s45° around its real mount axis" % ("+" if direction_sign > 0 else "−"))


func _apply_world_rotation_step_v042(axis_name: String, direction_sign: int) -> void:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		super._apply_world_rotation_step_v042(axis_name, direction_sign)
		return
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not is_instance_valid(selected_piece):
		return
	var context := _item_rotation_context_v060()
	var axis := _item_axis_for_context_v060(context, axis_name)
	if axis.length_squared() < 0.5:
		_status("ITEM rotation: %s is not a valid axis for this connection" % axis_name)
		return
	var preview := _item_rotation_candidate_v060(axis, direction_sign)
	if not bool(preview.get("valid", false)):
		_status("ITEM rotation blocked — %s" % str(preview.get("reason", "constraint")))
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated ITEM %s by %d°" % [axis_name, direction_sign * 45])


func _cancel_rotation_drag_v060() -> void:
	if gizmo_drag_active_v030:
		gizmo_drag_active_v030 = false
		gizmo_drag_steps_v030 = 0
		gizmo_drag_component_v030 = []
		gizmo_drag_preview_v030 = {}
		_clear_rotation_ghost_v030()


func _cancel_move_drag_v060() -> void:
	if move_drag_active_v042:
		move_drag_active_v042 = false
		move_drag_steps_v042 = 0
		move_drag_component_v042 = []
		move_drag_preview_v042 = {}
		item_move_drag_context_v060 = {}
		_clear_rotation_ghost_v030()


# -----------------------------------------------------------------------------
# Move semantics: ITEM follows only a real DOF; WORLD keeps the existing whole-
# island transform. Cross connectors slide on their host rod, axle members use
# the proven axle-slide path, and free pieces use local XYZ.
# -----------------------------------------------------------------------------

func _slide_cross_v060(context: Dictionary, amount: float) -> bool:
	var record := context.get("record", {}) as Dictionary
	var connector := selected_piece
	var host := context.get("host") as RigidBody3D
	if record.is_empty() or not is_instance_valid(connector) or not is_instance_valid(host):
		return false
	var axis := _rod_axis_v020(host)
	var half_len := maxf(0.10, float(host.get_meta("visual_length", 0.0)) * 0.5 - 0.42)
	var current_along := float(record.get("host_along", (connector.global_position - host.global_position).dot(axis)))
	var new_along := clampf(current_along + amount, -half_len, half_len)
	var actual_amount := new_along - current_along
	if absf(actual_amount) < 0.0001:
		_status("Cross connector is at the end of the host rod")
		return false
	var component := context.get("component", []) as Array
	var transforms := _translation_map_v042(component, axis * actual_amount)
	var validation := _validate_transforms_excluding_v032(transforms, int(record.get("uid", -1)))
	if not bool(validation.get("valid", false)):
		_status("Cross slide blocked — %s" % str(validation.get("reason", "another connection prevents movement")))
		return false
	var joint := record.get("joint") as Joint3D
	if is_instance_valid(joint):
		joint.set_meta("host_along_v020", new_along)
	_apply_transform_map_v020(transforms, "Slid cross connector %.2f along its rod" % actual_amount)
	return true


func _apply_item_move_step_v060(axis_name: String, steps: int) -> void:
	var context := _item_move_context_v060()
	if not bool(context.get("valid", false)):
		_status("ITEM move blocked — %s" % str(context.get("reason", "no independent movement")))
		return
	var axis := _item_axis_for_context_v060(context, axis_name)
	if axis.length_squared() < 0.5:
		_status("ITEM move: %s is not a valid direction for this connection" % axis_name)
		return
	var amount := MOVE_STEP_042 * float(steps)
	match str(context.get("kind", "")):
		"cross":
			_slide_cross_v060(context, amount)
		"axle":
			_slide_selected_on_axle(amount)
		"o_ring":
			_slide_o_ring(selected_piece, amount)
		"free":
			var transforms := _translation_map_v042(context.get("component", []) as Array, axis * amount)
			_apply_transform_map_v020(transforms, "Moved ITEM %s by %.2f" % [axis_name, amount])


func _apply_world_move_step_v042(axis: Vector3, steps: int) -> void:
	if move_space_v060 == TRANSFORM_WORLD_060:
		super._apply_world_move_step_v042(axis, steps)
		return
	_apply_item_move_step_v060(_axis_name_v042(axis), steps)


func _pick_move_axis_v042(screen_pos: Vector2) -> Dictionary:
	if move_space_v060 == TRANSFORM_WORLD_060:
		return super._pick_move_axis_v042(screen_pos)
	if move_gizmo_root_v042 == null or not move_gizmo_root_v042.visible or camera == null or not is_instance_valid(selected_piece):
		return {}
	var center := selected_piece.global_position
	var scale_value := move_gizmo_root_v042.scale.x
	var best: Dictionary = {}
	var best_distance := MOVE_GIZMO_PICK_PX_042
	for name_value in ["X", "Y", "Z"]:
		var data := move_gizmo_axes_v042.get(name_value, {}) as Dictionary
		var axis_root := data.get("root") as Node3D
		if data.is_empty() or not is_instance_valid(axis_root) or not axis_root.visible:
			continue
		var axis := data.get("axis", Vector3.ZERO) as Vector3
		var positive := center + axis * MOVE_GIZMO_LENGTH_042 * scale_value
		var negative := center - axis * MOVE_GIZMO_LENGTH_042 * scale_value
		if camera.is_position_behind(positive) or camera.is_position_behind(negative):
			continue
		var screen_positive := camera.unproject_position(positive)
		var screen_negative := camera.unproject_position(negative)
		var screen_axis := screen_positive - screen_negative
		if screen_axis.length() < 28.0:
			continue
		var pick := _point_segment_pick_v035(screen_pos, screen_negative, screen_positive)
		var distance := float(pick.get("distance", 9999.0))
		if distance <= best_distance:
			best_distance = distance
			best = {"name": name_value, "axis": axis, "screen_dir": screen_axis.normalized()}
	return best


func _begin_move_drag_v042(screen_pos: Vector2) -> bool:
	if move_space_v060 == TRANSFORM_WORLD_060:
		return super._begin_move_drag_v042(screen_pos)
	if editor_mode_v032 != EDITOR_MOVE_042 or simulating or not is_instance_valid(selected_piece):
		return false
	var picked := _pick_move_axis_v042(screen_pos)
	if picked.is_empty():
		return false
	var context := _item_move_context_v060()
	if not bool(context.get("valid", false)):
		return false
	item_move_drag_context_v060 = context
	move_drag_active_v042 = true
	move_drag_axis_name_v042 = str(picked.get("name", ""))
	move_drag_axis_v042 = picked.get("axis", Vector3.ZERO) as Vector3
	move_drag_screen_dir_v042 = picked.get("screen_dir", Vector2.RIGHT) as Vector2
	move_drag_start_screen_v042 = screen_pos
	move_drag_steps_v042 = 0
	move_drag_component_v042 = context.get("component", []) as Array
	move_drag_preview_v042 = {"valid": true, "transforms": {}}
	_build_rotation_ghost_v030(move_drag_component_v042)
	_status("ITEM move selected — drag only along the valid mechanical arrow")
	return true


func _update_move_drag_v042(screen_pos: Vector2) -> void:
	if move_space_v060 == TRANSFORM_WORLD_060:
		super._update_move_drag_v042(screen_pos)
		return
	if not move_drag_active_v042:
		return
	var projected := (screen_pos - move_drag_start_screen_v042).dot(move_drag_screen_dir_v042)
	var steps := clampi(int(round(projected / MOVE_GIZMO_STEP_PX_042)), -40, 40)
	if steps == move_drag_steps_v042:
		return
	move_drag_steps_v042 = steps
	var delta := move_drag_axis_v042 * MOVE_STEP_042 * float(steps)
	var transforms := _translation_map_v042(move_drag_component_v042, delta)
	var record := item_move_drag_context_v060.get("record", {}) as Dictionary
	var validation := _validate_transforms_excluding_v032(transforms, int(record.get("uid", -1)))
	var valid := bool(validation.get("valid", false))
	move_drag_preview_v042 = {"valid": valid, "transforms": transforms, "reason": validation.get("reason", "")}
	_update_rotation_ghost_v030(transforms, valid)
	_status("ITEM move preview: %.2f%s" % [MOVE_STEP_042 * float(steps), "" if valid else " — BLOCKED"])


func _finish_move_drag_v042() -> void:
	if move_space_v060 == TRANSFORM_WORLD_060:
		super._finish_move_drag_v042()
		return
	if not move_drag_active_v042:
		return
	var steps := move_drag_steps_v042
	var valid := bool(move_drag_preview_v042.get("valid", true))
	move_drag_active_v042 = false
	move_drag_steps_v042 = 0
	move_drag_component_v042 = []
	move_drag_preview_v042 = {}
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Move unchanged")
		return
	if not valid:
		_status("ITEM move blocked by another connection")
		return
	_apply_item_move_step_v060(move_drag_axis_name_v042, steps)
	item_move_drag_context_v060 = {}


# -----------------------------------------------------------------------------
# ITEM/WORLD rotation gizmo reuse. The inherited rings/arrows are reoriented and
# hidden per valid DOF rather than always showing impossible world directions.
# -----------------------------------------------------------------------------

func _rotation_gizmo_basis_v060(context: Dictionary) -> Basis:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		return Basis.IDENTITY
	if str(context.get("kind", "")) == "free":
		return context.get("basis", Basis.IDENTITY) as Basis
	return _basis_with_y_v060(context.get("axis", Vector3.UP) as Vector3)


func _move_gizmo_basis_v060(context: Dictionary) -> Basis:
	if move_space_v060 == TRANSFORM_WORLD_060:
		return Basis.IDENTITY
	if str(context.get("kind", "")) == "free":
		return context.get("basis", Basis.IDENTITY) as Basis
	return _basis_with_y_v060(context.get("axis", Vector3.UP) as Vector3)


func _configure_rotation_gizmo_v060() -> void:
	if gizmo_root_v030 == null:
		return
	var show := editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and not _modal_open_v060()
	var context := {"valid": true, "kind": "world", "names": ["X", "Y", "Z"]} if rotate_space_v060 == TRANSFORM_WORLD_060 else _item_rotation_context_v060()
	if not bool(context.get("valid", false)):
		show = false
	gizmo_root_v030.visible = show
	if not show:
		return
	var basis_value := _rotation_gizmo_basis_v060(context)
	gizmo_root_v030.global_basis = basis_value
	gizmo_root_v030.global_position = _gizmo_anchor_v030()
	gizmo_root_v030.scale = Vector3.ONE * clampf(camera_distance / 19.0, 0.62, 2.25)
	var names := context.get("names", ["X", "Y", "Z"]) as Array
	for name_value in ["X", "Y", "Z"]:
		var data := gizmo_axes_v030.get(name_value, {}) as Dictionary
		if data.is_empty():
			continue
		var visible_axis := name_value in names
		var ring := data.get("ring") as MeshInstance3D
		var plus := data.get("plus") as Label3D
		var minus := data.get("minus") as Label3D
		if is_instance_valid(ring):
			ring.visible = visible_axis
		if is_instance_valid(plus):
			plus.visible = visible_axis
		if is_instance_valid(minus):
			minus.visible = visible_axis
		if visible_axis:
			data["axis"] = _logical_axis_v060(name_value, basis_value)
			gizmo_axes_v030[name_value] = data
	_refresh_gizmo_validity_v060(context)


func _refresh_gizmo_validity_v060(context: Dictionary) -> void:
	var enabled := gizmo_root_v030 != null and gizmo_root_v030.visible and tool_mode_v030.is_empty()
	for name_value in ["X", "Y", "Z"]:
		var data := gizmo_axes_v030.get(name_value, {}) as Dictionary
		if data.is_empty():
			continue
		var ring := data.get("ring") as MeshInstance3D
		if not is_instance_valid(ring) or not ring.visible:
			continue
		var axis := data.get("axis", Vector3.ZERO) as Vector3
		var mat := data.get("material") as StandardMaterial3D
		var plus := data.get("plus") as Label3D
		var minus := data.get("minus") as Label3D
		var plus_valid := enabled and bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid := enabled and bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		ring.material_override = mat if plus_valid or minus_valid else gizmo_disabled_mat_v030
		if is_instance_valid(plus):
			plus.modulate = mat.albedo_color if plus_valid else gizmo_disabled_mat_v030.albedo_color
		if is_instance_valid(minus):
			minus.modulate = mat.albedo_color if minus_valid else gizmo_disabled_mat_v030.albedo_color


func _refresh_gizmo_validity_v030() -> void:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		super._refresh_gizmo_validity_v030()
		return
	var context := _item_rotation_context_v060()
	_refresh_gizmo_validity_v060(context)


func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		return super._pick_gizmo_axis_v030(screen_pos)
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var best: Dictionary = {}
	var best_distance := WORLD_GIZMO_PICK_PX_035
	for name_value in ["X", "Y", "Z"]:
		var data := gizmo_axes_v030.get(name_value, {}) as Dictionary
		var ring := data.get("ring") as MeshInstance3D
		if data.is_empty() or not is_instance_valid(ring) or not ring.visible:
			continue
		var axis := data.get("axis", Vector3.ZERO) as Vector3
		if not bool(_rotation_candidate_v030(axis, 1).get("valid", false)) and not bool(_rotation_candidate_v030(axis, -1).get("valid", false)):
			continue
		var pick := _ring_pick_v035(axis, screen_pos, best_distance)
		if pick.is_empty():
			continue
		var distance := float(pick.get("distance", 9999.0))
		if distance <= best_distance:
			best_distance = distance
			best = {"name": name_value, "axis": axis, "center": pick.get("center", selected_piece.global_position), "tangent": pick.get("tangent", Vector2.RIGHT)}
	return best


func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		return super._begin_gizmo_drag_v030(screen_pos)
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not tool_mode_v030.is_empty():
		return false
	var picked := _pick_gizmo_axis_v030(screen_pos)
	if picked.is_empty():
		return false
	var context := _item_rotation_context_v060()
	if not bool(context.get("valid", false)):
		return false
	gizmo_drag_active_v030 = true
	gizmo_drag_axis_v030 = picked.get("axis", Vector3.ZERO) as Vector3
	gizmo_drag_axis_name_v030 = str(picked.get("name", ""))
	gizmo_drag_center_v030 = picked.get("center", selected_piece.global_position) as Vector3
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = context.get("component", []) as Array
	gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
	gizmo_drag_last_screen_v035 = screen_pos
	gizmo_drag_accum_px_v035 = 0.0
	gizmo_drag_tangent_v035 = (picked.get("tangent", Vector2.RIGHT) as Vector2).normalized()
	_build_rotation_ghost_v030(gizmo_drag_component_v030)
	_status("ITEM mechanical rotation selected — drag the visible valid ring")
	return true


func _update_gizmo_drag_v030(screen_pos: Vector2) -> void:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		super._update_gizmo_drag_v030(screen_pos)
		return
	if not gizmo_drag_active_v030:
		return
	var tangent_pick := _ring_pick_v035(gizmo_drag_axis_v030, screen_pos, 110.0)
	var tangent := gizmo_drag_tangent_v035
	if not tangent_pick.is_empty():
		tangent = (tangent_pick.get("tangent", tangent) as Vector2).normalized()
		gizmo_drag_tangent_v035 = tangent
	var delta := screen_pos - gizmo_drag_last_screen_v035
	gizmo_drag_last_screen_v035 = screen_pos
	gizmo_drag_accum_px_v035 += delta.dot(tangent)
	var steps := clampi(int(round(gizmo_drag_accum_px_v035 / WORLD_GIZMO_STEP_PIXELS_035)), -7, 7)
	if steps == gizmo_drag_steps_v030:
		return
	gizmo_drag_steps_v030 = steps
	var preview := _item_rotation_candidate_v060(gizmo_drag_axis_v030, steps)
	gizmo_drag_preview_v030 = preview
	_update_rotation_ghost_v030(preview.get("transforms", {}) as Dictionary, bool(preview.get("valid", false)))
	_status("ITEM rotation preview: %d°%s" % [steps * 45, "" if bool(preview.get("valid", false)) else " — BLOCKED"])


func _finish_gizmo_drag_v030() -> void:
	if rotate_space_v060 == TRANSFORM_WORLD_060:
		super._finish_gizmo_drag_v030()
		return
	if not gizmo_drag_active_v030:
		return
	var steps := gizmo_drag_steps_v030
	var preview := gizmo_drag_preview_v030
	gizmo_drag_active_v030 = false
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = []
	gizmo_drag_preview_v030 = {}
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Rotation unchanged")
		return
	if not bool(preview.get("valid", false)):
		_status("ITEM rotation blocked — %s" % str(preview.get("reason", "constraint")))
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated ITEM %s by %d°" % [gizmo_drag_axis_name_v030, steps * 45])


func _configure_move_gizmo_v060() -> void:
	if move_gizmo_root_v042 == null:
		return
	var show := editor_mode_v032 == EDITOR_MOVE_042 and not simulating and is_instance_valid(selected_piece) and not _modal_open_v060()
	var context := {"valid": true, "kind": "world", "names": ["X", "Y", "Z"]} if move_space_v060 == TRANSFORM_WORLD_060 else _item_move_context_v060()
	if not bool(context.get("valid", false)):
		show = false
	move_gizmo_root_v042.visible = show
	if not show:
		return
	var basis_value := _move_gizmo_basis_v060(context)
	move_gizmo_root_v042.global_basis = basis_value
	move_gizmo_root_v042.global_position = selected_piece.global_position
	move_gizmo_root_v042.scale = Vector3.ONE * clampf(camera_distance / 19.0, 0.62, 2.10)
	var names := context.get("names", ["X", "Y", "Z"]) as Array
	for name_value in ["X", "Y", "Z"]:
		var data := move_gizmo_axes_v042.get(name_value, {}) as Dictionary
		var axis_root := data.get("root") as Node3D
		if data.is_empty() or not is_instance_valid(axis_root):
			continue
		var visible_axis := name_value in names
		axis_root.visible = visible_axis
		if visible_axis:
			data["axis"] = _logical_axis_v060(name_value, basis_value)
			move_gizmo_axes_v042[name_value] = data


func _modal_open_v060() -> bool:
	return (help_panel != null and help_panel.visible) or (options_panel != null and options_panel.visible) or (parts_panel_v050 != null and parts_panel_v050.visible) or (builds_panel_v050 != null and builds_panel_v050.visible)


# -----------------------------------------------------------------------------
# Restore two-finger pan. Parent code still owns orbit/pinch zoom; this adds a
# stable centroid translation path so pan cannot disappear when editor input grows.
# -----------------------------------------------------------------------------

func _pan_centroid_v060() -> Vector2:
	if pan_touch_positions_v060.is_empty():
		return Vector2.ZERO
	var result := Vector2.ZERO
	for value in pan_touch_positions_v060.values():
		result += value as Vector2
	return result / float(pan_touch_positions_v060.size())


func _track_two_finger_pan_v060(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			pan_touch_positions_v060[touch.index] = touch.position
		else:
			pan_touch_positions_v060.erase(touch.index)
		pan_center_valid_v060 = pan_touch_positions_v060.size() >= 2
		if pan_center_valid_v060:
			pan_center_v060 = _pan_centroid_v060()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not pan_touch_positions_v060.has(drag.index):
			pan_touch_positions_v060[drag.index] = drag.position
			return
		var old_center := _pan_centroid_v060()
		pan_touch_positions_v060[drag.index] = drag.position
		if pan_touch_positions_v060.size() < 2:
			pan_center_valid_v060 = false
			return
		var new_center := _pan_centroid_v060()
		if not pan_center_valid_v060:
			pan_center_v060 = new_center
			pan_center_valid_v060 = true
			return
		var delta := new_center - old_center
		pan_center_v060 = new_center
		if delta.length_squared() < 0.01 or _modal_open_v060() or move_drag_active_v042 or gizmo_drag_active_v030:
			return
		var right := camera.global_transform.basis.x.normalized()
		var up := camera.global_transform.basis.y.normalized()
		var x_sign := -1.0 if reverse_pan_x else 1.0
		var y_sign := -1.0 if reverse_pan_y else 1.0
		var scale_value := camera_distance * PAN_SCALE_060 * camera_sensitivity
		camera_target += (-right * delta.x * x_sign + up * delta.y * y_sign) * scale_value


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	_track_two_finger_pan_v060(event)


# -----------------------------------------------------------------------------
# Rounded original procedural connector geometry. This uses no imported K'NEX
# mesh/assets: the silhouette is generated from rounded ribs, open fork arms and
# an open hub so the jaw gap remains visibly open instead of being bridged by a
# rectangular stop bar.
# -----------------------------------------------------------------------------

func _capsule_mesh_v060(radius: float, height: float) -> CapsuleMesh:
	var safe_height := maxf(height, radius * 2.02)
	var key := "capsule:%.4f:%.4f" % [radius, safe_height]
	if capsule_mesh_cache_v060.has(key):
		return capsule_mesh_cache_v060[key] as CapsuleMesh
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = safe_height
	mesh.radial_segments = 12
	mesh.rings = 4
	capsule_mesh_cache_v060[key] = mesh
	return mesh


func _add_capsule_segment_v060(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var delta := b - a
	var length := delta.length()
	var instance := MeshInstance3D.new()
	instance.mesh = _capsule_mesh_v060(radius, length + radius * 2.0)
	instance.material_override = material
	parent.add_child(instance)
	instance.position = (a + b) * 0.5
	if length > 0.0001:
		instance.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
	return instance


func _socket_frame_v060(direction_value: Vector3, normal_hint: Vector3) -> Basis:
	var x := direction_value.normalized()
	var y := normal_hint - x * normal_hint.dot(x)
	if y.length_squared() < 0.04:
		y = Vector3.UP - x * Vector3.UP.dot(x)
	if y.length_squared() < 0.04:
		y = Vector3.BACK - x * Vector3.BACK.dot(x)
	y = y.normalized()
	var z := x.cross(y).normalized()
	y = z.cross(x).normalized()
	return Basis(x, y, z).orthonormalized()


func _add_open_fork_local_v060(parent: Node3D, color: Color) -> void:
	var main_mat := _mat(color)
	var edge_mat := _mat(color.lightened(0.055))
	# Tapered-looking central spine, then two independent rounded fork arms.
	_add_capsule_segment_v060(parent, Vector3(0.42, 0.0, 0.0), Vector3(0.91, 0.0, 0.0), 0.145, main_mat)
	_add_capsule_segment_v060(parent, Vector3(0.55, 0.0, -0.055), Vector3(0.92, 0.0, -0.19), 0.085, main_mat)
	_add_capsule_segment_v060(parent, Vector3(0.55, 0.0, 0.055), Vector3(0.92, 0.0, 0.19), 0.085, main_mat)
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		_add_capsule_segment_v060(parent, Vector3(0.84, 0.0, 0.22 * side), Vector3(1.48, 0.0, 0.22 * side), 0.105, main_mat)
		# Small inward grip nubs; they never bridge the open U-shaped mouth.
		_add_capsule_segment_v060(parent, Vector3(1.18, 0.0, 0.18 * side), Vector3(1.31, 0.0, 0.145 * side), 0.070, edge_mat)


func _add_rounded_socket_v060(parent: Node3D, direction: Vector3, normal_hint: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.basis = _socket_frame_v060(direction, normal_hint)
	parent.add_child(root)
	_add_open_fork_local_v060(root, color)


func _build_connector_visuals_v060(parent: Node3D, def_index: int) -> void:
	var definition := connector_defs[def_index] as Dictionary
	var color := definition.get("color", Color(0.8, 0.8, 0.8)) as Color
	var main_mat := _mat(color)
	var edge_mat := _mat(color.lightened(0.055))
	var hub := MeshInstance3D.new()
	var hub_mesh := TorusMesh.new()
	hub_mesh.inner_radius = 0.31
	hub_mesh.outer_radius = 0.61
	hub_mesh.rings = 24
	hub_mesh.ring_segments = 14
	hub.mesh = hub_mesh
	hub.scale.y = 0.82
	hub.material_override = main_mat
	parent.add_child(hub)
	var collar := MeshInstance3D.new()
	var collar_mesh := TorusMesh.new()
	collar_mesh.inner_radius = 0.285
	collar_mesh.outer_radius = 0.42
	collar_mesh.rings = 20
	collar_mesh.ring_segments = 12
	collar.mesh = collar_mesh
	collar.scale.y = 0.58
	collar.material_override = edge_mat
	parent.add_child(collar)
	for slot_value in definition.get("slots", []) as Array:
		var slot := int(slot_value)
		var direction := _slot_dir(slot)
		var normal_hint := Vector3.UP
		if slot >= 1000:
			normal_hint = Vector3.BACK
		_add_rounded_socket_v060(parent, direction, normal_hint, color)


func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if def_index < 0 or def_index >= connector_defs.size() or def_index == o_ring_index:
		return
	for child_value in body.get_children():
		var child := child_value as Node
		if child is MeshInstance3D or child is CollisionShape3D or child.name.begins_with("SpatialSocket"):
			body.remove_child(child)
			child.queue_free()
	var definition := connector_defs[def_index] as Dictionary
	body.mass = float(definition.get("mass", 0.12))
	body.set_meta("connector_type", def_index)
	_build_connector_visuals_v060(body, def_index)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.54
	shape.height = 0.50
	collision.shape = shape
	body.add_child(collision)
	# Extra spatial jaw collision capsules retain reach for the 11/14 point ports.
	for slot_value in definition.get("slots", []) as Array:
		var slot := int(slot_value)
		if slot >= 1000:
			_add_spatial_collision_v041(body, _slot_dir(slot))


func _refresh_all_connector_visuals_v060() -> void:
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body) and str(body.get_meta("kind", "")) == "connector":
			_rebuild_connector(body, int(body.get_meta("connector_type", -1)))


func _collect_meshes_v060(node: Node, result: Array) -> void:
	for child_value in node.get_children():
		var child := child_value as Node
		if child.name == "SelectionHighlight":
			continue
		if child is MeshInstance3D:
			result.append(child)
		_collect_meshes_v060(child, result)


func _refresh_selection_highlight() -> void:
	_clear_selection_highlight()
	if not is_instance_valid(selected_piece):
		return
	var body := selected_piece
	var highlight := Node3D.new()
	highlight.name = "SelectionHighlight"
	highlighted_body = body
	body.add_child(highlight)
	var meshes: Array = []
	_collect_meshes_v060(body, meshes)
	for mesh_value in meshes:
		var source := mesh_value as MeshInstance3D
		if source == null or source.mesh == null:
			continue
		var clone := MeshInstance3D.new()
		clone.mesh = source.mesh
		clone.transform = body.global_transform.affine_inverse() * source.global_transform
		clone.scale *= 1.075
		clone.material_override = _selection_mat()
		highlight.add_child(clone)


# -----------------------------------------------------------------------------
# Parts browser with real runtime 3D previews. GitHub only hosts the source; the
# thumbnails are rendered by Godot on-device, so no external preview service or
# proprietary meshes are required.
# -----------------------------------------------------------------------------

func _part_preview_v060(definition: Dictionary, index_value: int, is_rod: bool) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(180.0, 92.0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(220, 110)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var root3d := Node3D.new()
	viewport.add_child(root3d)
	var camera3d := Camera3D.new()
	viewport.add_child(camera3d)
	camera3d.position = Vector3(0.0, 4.1, 7.6)
	camera3d.look_at(Vector3.ZERO, Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_energy = 1.6
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(35.0, 150.0, 0.0)
	fill.light_energy = 0.65
	viewport.add_child(fill)
	var color := definition.get("color", Color(0.7, 0.7, 0.7)) as Color
	if is_rod:
		var preview_length := clampf(1.4 + float(definition.get("actual_mm", 33.0)) / 80.0, 1.6, 4.0)
		_add_capsule_segment_v060(root3d, Vector3(-preview_length * 0.5, 0, 0), Vector3(preview_length * 0.5, 0, 0), 0.12, _mat(color))
		_add_capsule_segment_v060(root3d, Vector3(-preview_length * 0.52, 0, 0), Vector3(-preview_length * 0.40, 0, 0), 0.22, _mat(color.lightened(0.06)))
		_add_capsule_segment_v060(root3d, Vector3(preview_length * 0.40, 0, 0), Vector3(preview_length * 0.52, 0, 0), 0.22, _mat(color.lightened(0.06)))
	else:
		if str(definition.get("special", "")) == "o_ring":
			var torus := TorusMesh.new()
			torus.inner_radius = O_RING_INNER_RADIUS_V040
			torus.outer_radius = O_RING_OUTER_RADIUS
			var ring := MeshInstance3D.new()
			ring.mesh = torus
			ring.material_override = _mat(color)
			root3d.add_child(ring)
		else:
			_build_connector_visuals_v060(root3d, index_value)
		root3d.rotation_degrees = Vector3(-18.0, 18.0, 0.0)
	return container


func _refresh_parts_browser_v050() -> void:
	if parts_grid_v050 == null:
		return
	for child_value in parts_grid_v050.get_children():
		var child := child_value as Node
		parts_grid_v050.remove_child(child)
		child.queue_free()
	part_card_buttons_v050.clear()
	var defs: Array = rod_defs if parts_tab_v050 == 0 else connector_defs
	for i in range(defs.size()):
		var definition := defs[i] as Dictionary
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(190.0, 142.0)
		card.add_theme_constant_override("separation", 3)
		parts_grid_v050.add_child(card)
		card.add_child(_part_preview_v060(definition, i, parts_tab_v050 == 0))
		var name_value := str(definition.get("name", "Part"))
		var detail := ""
		if parts_tab_v050 == 0:
			detail = "%.1f mm" % float(definition.get("actual_mm", 0.0))
		else:
			var special := str(definition.get("special", ""))
			detail = "Axle stop" if special == "o_ring" else "%d ports" % (definition.get("slots", []) as Array).size()
		var button := _ui_button("%s\n%s" % [name_value, detail], func(index_arg: int = i) -> void: _choose_part_v050(index_arg), false)
		button.custom_minimum_size = Vector2(180.0, 48.0)
		button.add_theme_font_size_override("font_size", 13)
		var selected := i == (selected_rod_type if parts_tab_v050 == 0 else selected_connector_type)
		var color := definition.get("color", Color(0.4, 0.5, 0.6)) as Color
		button.add_theme_stylebox_override("normal", _part_card_style_v050(color, selected))
		button.add_theme_stylebox_override("hover", _part_card_style_v050(color.lightened(0.10), selected))
		card.add_child(button)
		part_card_buttons_v050.append(button)
	if parts_rods_button_v050 != null:
		parts_rods_button_v050.text = ("● " if parts_tab_v050 == 0 else "") + "RODS"
	if parts_connectors_button_v050 != null:
		parts_connectors_button_v050.text = ("● " if parts_tab_v050 == 1 else "") + "CONNECTORS"


# -----------------------------------------------------------------------------
# Final UI state and runtime gizmo alignment.
# -----------------------------------------------------------------------------

func _set_axis_button_pair_v060(minus: Button, plus: Button, visible_value: bool, label_value: String, minus_valid: bool, plus_valid: bool) -> void:
	if minus != null:
		minus.visible = visible_value
		minus.text = "%s −" % label_value
		minus.disabled = not visible_value or not minus_valid
	if plus != null:
		plus.visible = visible_value
		plus.text = "%s +" % label_value
		plus.disabled = not visible_value or not plus_valid


func _update_transform_controls_v060() -> void:
	if rotate_space_button_v060 != null:
		rotate_space_button_v060.text = "ITEM • MECHANICAL" if rotate_space_v060 == TRANSFORM_ITEM_060 else "WORLD • GROUP"
	if move_space_button_v060 != null:
		move_space_button_v060.text = "ITEM • MECHANICAL" if move_space_v060 == TRANSFORM_ITEM_060 else "WORLD • GROUP"
	var rotate_context := {"valid": true, "names": ["X", "Y", "Z"], "kind": "world"} if rotate_space_v060 == TRANSFORM_WORLD_060 else _item_rotation_context_v060()
	var rotate_names := rotate_context.get("names", []) as Array
	for entry_value in [["X", rot_x_minus_v042, rot_x_plus_v042], ["Y", rot_y_minus_v042, rot_y_plus_v042], ["Z", rot_z_minus_v042, rot_z_plus_v042]]:
		var entry := entry_value as Array
		var name_value := str(entry[0])
		var visible_value := bool(rotate_context.get("valid", false)) and name_value in rotate_names
		var axis := _world_axis_v035(name_value) if rotate_space_v060 == TRANSFORM_WORLD_060 else _item_axis_for_context_v060(rotate_context, name_value)
		var minus_valid := visible_value and bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		var plus_valid := visible_value and bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var label_value := ("WORLD %s" % name_value) if rotate_space_v060 == TRANSFORM_WORLD_060 else ("LOCAL %s" % name_value if str(rotate_context.get("kind", "")) == "free" else "MOUNT")
		_set_axis_button_pair_v060(entry[1] as Button, entry[2] as Button, visible_value, label_value, minus_valid, plus_valid)
	var move_context := {"valid": true, "names": ["X", "Y", "Z"], "kind": "world"} if move_space_v060 == TRANSFORM_WORLD_060 else _item_move_context_v060()
	var move_names := move_context.get("names", []) as Array
	for entry_value in [["X", move_x_minus_v042, move_x_plus_v042], ["Y", move_y_minus_v042, move_y_plus_v042], ["Z", move_z_minus_v042, move_z_plus_v042]]:
		var entry := entry_value as Array
		var name_value := str(entry[0])
		var visible_value := bool(move_context.get("valid", false)) and name_value in move_names
		var label_value := ("WORLD %s" % name_value) if move_space_v060 == TRANSFORM_WORLD_060 else ("LOCAL %s" % name_value if str(move_context.get("kind", "")) == "free" else "ALONG ROD")
		_set_axis_button_pair_v060(entry[1] as Button, entry[2] as Button, visible_value, label_value, true, true)
	var roll_context := _item_rotation_context_v060(selected_piece) if is_instance_valid(selected_piece) else {"valid": false}
	var roll_valid := bool(roll_context.get("valid", false)) and str(roll_context.get("kind", "")) in ["cross", "axle", "socket_roll"]
	for button_value in [roll_minus_v035, roll_plus_v035, roll_minus_v030, roll_plus_v030]:
		var button := button_value as Button
		if button != null:
			button.disabled = simulating or not roll_valid
	if rotation_hint_v035 != null:
		rotation_hint_v035.text = "ITEM shows only mechanically valid axes. WORLD rotates the full connected group."


func _update_ui() -> void:
	super._update_ui()
	_update_mode_ui_v032()
	if rod_label != null and selected_rod_type >= 0 and selected_rod_type < rod_defs.size():
		rod_label.text = "NEXT ROD • %s" % str(rod_defs[selected_rod_type].get("name", "Rod"))
	if connector_label != null and selected_connector_type >= 0 and selected_connector_type < connector_defs.size():
		connector_label.text = "NEXT CONN • %s" % str(connector_defs[selected_connector_type].get("name", "Connector"))
	_update_transform_controls_v060()
	_layout_right_panels_v032()


func _process(delta: float) -> void:
	super._process(delta)
	_configure_rotation_gizmo_v060()
	_configure_move_gizmo_v060()
	if attach_preview_line_v042 != null:
		attach_preview_line_v042.visible = false


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label := _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nCREATE: the bottom arrows are back as quick NEXT-part selectors; PARTS opens visual 3D cards for the same choices. Selecting a construction piece never changes the next-part palette.\n\nROTATE: defaults to ITEM. ITEM exposes only real mechanical freedom: cross connectors spin around their host rod, axle members spin around the axle, single socket-mounted connectors roll around the mount, and free pieces use local XYZ. WORLD explicitly rotates the whole connected construction.\n\nMOVE: defaults to ITEM. Cross connectors slide only along their host rod; axle members slide only through the axle hole; free pieces use local XYZ. WORLD explicitly moves the connected construction. Impossible arrows/rings are hidden.\n\nATTACH: no tether line. Tap a visible source point, then a destination. Occupied socket taps resolve to their attached rod end so an existing rod can be re-seated onto another socket. CROSS points use bold + markers. All 11/14 spatial ports are included.\n\nOPTIONS: the panel scrolls, so Saves/Recovery and Physics are reachable on a phone. Rotate/Move detail panels scroll too.\n\nCAMERA: one finger orbits; two fingers pan and pinch-zoom." % VERSION_060


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var release := parsed as Dictionary
	var latest := str(release.get("tag_name", "")).trim_prefix("v")
	if latest.is_empty():
		return
	if _compare_versions_v021(latest, VERSION_060) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_060)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_060, latest])
