extends "res://scripts/main_v082.gd"

const VERSION_083 := "0.5.24-dev"
const SELECT_ICON_FONT_SIZE_083 := 40
const BOTTOM_ARROW_FONT_SIZE_083 := 42
const LEFT_MODE_HEIGHT_083 := 64.0
const LEFT_FREE_HEIGHT_083 := 52.0
const LEFT_UTILITY_HEIGHT_083 := 48.0
const LEFT_PANEL_BOTTOM_083 := 684.0
const ATTACH_OTHER_PIECE_PICK_RADIUS_083 := 420.0


func _ready() -> void:
	super._ready()
	_stack_free_create_buttons_v083()
	_resize_left_toolbar_v083()
	_sync_deselect_button_v083()
	_bump_bottom_icon_sizes_v082()
	_refresh_top_toolbar_v081()
	_status("v0.5.24 staging — unified Deselect, larger controls and cross-piece ATTACH retargeting are active.")


# -----------------------------------------------------------------------------
# Deselect: one button for both piece selection and ATTACH point selection.
# Every mode/marker refresh must recompute the combined enabled state.
# -----------------------------------------------------------------------------

func _sync_deselect_button_v083() -> void:
	if deselect_piece_button_v039 == null:
		return
	deselect_piece_button_v039.text = "Deselect"
	var has_piece: bool = is_instance_valid(selected_piece)
	var has_point: bool = not attach_point_selected_v032.is_empty()
	deselect_piece_button_v039.disabled = simulating or not (has_piece or has_point)


func _update_mode_ui_v032() -> void:
	super._update_mode_ui_v032()
	if deselect_point_button_v032 != null:
		deselect_point_button_v032.hide()
		deselect_point_button_v032.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_deselect_button_v083()


func _update_ui() -> void:
	super._update_ui()
	_sync_deselect_button_v083()
	_stack_free_create_buttons_v083()
	_resize_left_toolbar_v083()
	_bump_bottom_icon_sizes_v082()


# -----------------------------------------------------------------------------
# Top/bottom icon polish.
# -----------------------------------------------------------------------------

func _style_top_icon_v081(button: Button, glyph: String, tooltip: String) -> void:
	super._style_top_icon_v081(button, glyph, tooltip)
	if button == select_button_v020:
		button.add_theme_font_size_override("font_size", SELECT_ICON_FONT_SIZE_083)


func _bump_bottom_icon_sizes_v082() -> void:
	super._bump_bottom_icon_sizes_v082()
	if rod_label == null or rod_label.get_parent() == null:
		return
	var row := rod_label.get_parent() as HBoxContainer
	if row == null:
		return
	for child_value in row.get_children():
		var button := child_value as Button
		if button != null and button.text in ["←", "→"]:
			button.add_theme_font_size_override("font_size", BOTTOM_ARROW_FONT_SIZE_083)


# -----------------------------------------------------------------------------
# Left toolbar sizing/layout.
# New Rod / New Connector become full-width stacked controls like the other
# editor actions, and the left-side touch targets gain a little more height.
# -----------------------------------------------------------------------------

func _stack_free_create_buttons_v083() -> void:
	if new_free_rod_button_v070 == null or new_free_connector_button_v070 == null:
		return
	var row := new_free_rod_button_v070.get_parent() as HBoxContainer
	if row == null or new_free_connector_button_v070.get_parent() != row:
		# Already stacked by an earlier refresh.
		for button_value in [new_free_rod_button_v070, new_free_connector_button_v070]:
			var existing := button_value as Button
			if existing != null:
				existing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				existing.custom_minimum_size.x = 194.0
				existing.custom_minimum_size.y = LEFT_FREE_HEIGHT_083
		return
	var box := row.get_parent() as VBoxContainer
	if box == null:
		return
	var insert_at: int = row.get_index()
	row.remove_child(new_free_rod_button_v070)
	row.remove_child(new_free_connector_button_v070)
	box.add_child(new_free_rod_button_v070)
	box.add_child(new_free_connector_button_v070)
	box.move_child(new_free_rod_button_v070, insert_at)
	box.move_child(new_free_connector_button_v070, insert_at + 1)
	row.hide()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button_value in [new_free_rod_button_v070, new_free_connector_button_v070]:
		var button := button_value as Button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(194.0, LEFT_FREE_HEIGHT_083)
		button.add_theme_font_size_override("font_size", 14)


func _resize_left_toolbar_v083() -> void:
	for button_value in [create_button_v032, rotate_button_v032, move_mode_button_v042, attach_button_v032]:
		var button := button_value as Button
		if button != null:
			button.custom_minimum_size.y = LEFT_MODE_HEIGHT_083
	if new_free_rod_button_v070 != null:
		new_free_rod_button_v070.custom_minimum_size.y = LEFT_FREE_HEIGHT_083
	if new_free_connector_button_v070 != null:
		new_free_connector_button_v070.custom_minimum_size.y = LEFT_FREE_HEIGHT_083
	if disconnect_button_v042 != null:
		disconnect_button_v042.custom_minimum_size.y = LEFT_UTILITY_HEIGHT_083
	if deselect_piece_button_v039 != null:
		deselect_piece_button_v039.custom_minimum_size.y = LEFT_UTILITY_HEIGHT_083
	if mode_panel_v032 != null:
		mode_panel_v032.offset_bottom = maxf(mode_panel_v032.offset_bottom, LEFT_PANEL_BOTTOM_083)


# -----------------------------------------------------------------------------
# ATTACH cross-piece retargeting.
#
# v0.5.15 added a convenient socket re-seat path for changing which socket is
# used against an already-attached rod. Keep that behavior for the current
# counterpart, but when the user taps a DIFFERENT piece, treat that piece as the
# intended destination and run the normal atomic reconnect path against it.
# -----------------------------------------------------------------------------

func _record_other_body_v083(record: Dictionary, source_body: RigidBody3D) -> RigidBody3D:
	if record.is_empty() or not is_instance_valid(source_body):
		return null
	var a := record.get("a") as RigidBody3D
	var b := record.get("b") as RigidBody3D
	if a == source_body and is_instance_valid(b):
		return b
	if b == source_body and is_instance_valid(a):
		return a
	return null


func _rod_body_point_on_hit_v083(rod: RigidBody3D, hit_position: Vector3) -> Dictionary:
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		return {}
	var axis: Vector3 = _rod_axis_v020(rod)
	if axis.length_squared() < 0.5:
		return {}
	axis = axis.normalized()
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.38)
	var along: float = clampf((hit_position - rod.global_position).dot(axis), -half_len, half_len)
	return {"type": "rod_body", "body": rod, "along": along, "point": rod.global_position + axis * along}


func _compatible_target_on_body_v083(source: Dictionary, target_body: RigidBody3D, screen_pos: Vector2, hit_position: Vector3) -> Dictionary:
	if source.is_empty() or not is_instance_valid(target_body):
		return {}
	var expected: Array = _expected_target_types_v035(str(source.get("type", "")))
	if expected.is_empty():
		return {}
	if "rod_body" in expected and str(target_body.get_meta("kind", "")) == "rod":
		return _rod_body_point_on_hit_v083(target_body, hit_position)

	var candidates: Array = []
	for point_value in _all_attach_points_v032():
		var point := point_value as Dictionary
		if point.get("body") != target_body:
			continue
		if not (str(point.get("type", "")) in expected):
			continue
		if not _attach_target_is_available_v040(source, point):
			continue
		candidates.append(point)
	if candidates.is_empty():
		return {}
	return _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_OTHER_PIECE_PICK_RADIUS_083)


func _try_cross_piece_attach_v083(screen_pos: Vector2) -> bool:
	if simulating or editor_mode_v032 != EDITOR_ATTACH_032 or attach_point_selected_v032.is_empty():
		return false
	var source_selected: Dictionary = attach_point_selected_v032
	var source_body := source_selected.get("body") as RigidBody3D
	if not is_instance_valid(source_body):
		return false
	var hit: Dictionary = _raycast_piece(screen_pos)
	if hit.is_empty():
		return false
	var target_body := hit.get("collider") as RigidBody3D
	if not is_instance_valid(target_body) or target_body == source_body:
		return false

	# Leave taps on the current counterpart to the inherited socket re-seat path.
	var source_record: Dictionary = _connection_record_for_point_v032(source_selected)
	var current_counterpart: RigidBody3D = _record_other_body_v083(source_record, source_body)
	if is_instance_valid(current_counterpart) and target_body == current_counterpart:
		return false

	var target: Dictionary = _compatible_target_on_body_v083(
		source_selected,
		target_body,
		screen_pos,
		hit.get("position", target_body.global_position) as Vector3
	)
	if target.is_empty():
		return false

	var source: Dictionary = source_selected
	if str(source.get("type", "")) == "rod_body" and str(target.get("type", "")) == "o_ring":
		var swap_value: Dictionary = source
		source = target
		target = swap_value
	if _pair_mode_v032(source, target) < 0:
		return false

	if _connect_points_v035(source, target):
		attach_point_selected_v032 = {}
		_refresh_attach_points_v032()
	else:
		# Preserve the original source so another destination can be tried at once.
		attach_point_selected_v032 = source_selected
		_refresh_attach_points_v032()
	_sync_deselect_button_v083()
	return true


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	if _try_cross_piece_attach_v083(screen_pos):
		return
	super._handle_attach_point_tap_v032(screen_pos)
