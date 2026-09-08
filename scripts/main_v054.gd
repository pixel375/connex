extends "res://scripts/main_v053.gd"

const VERSION_054 := "0.5.2-dev"
const SPATIAL_PICK_RADIUS_V054 := 138.0
const CREATE_POINT_PICK_RADIUS_V054 := 74.0
const GLOBAL_CREATE_POINT_PICK_RADIUS_V054 := 52.0
const AUTO_SOCKET_CAPTURE_V054 := 1.02
const AUTO_SOCKET_ALIGN_V054 := 0.90
const DISCONNECT_NUDGE_V054 := 0.48
const CAMERA_MIN_DISTANCE_V054 := 3.0
const CAMERA_MAX_DISTANCE_V054 := 420.0

var mode_owned_panels_ready_v054: bool = false
var options_scroll_v054: ScrollContainer
var rotation_scroll_v054: ScrollContainer
var move_scroll_v054: ScrollContainer
var physics_scroll_v054: ScrollContainer
var physics_sliders_v054: Dictionary = {}
var modal_blockers_v054: Dictionary = {}


func _ready() -> void:
	super._ready()
	_install_scroll_surfaces_v054()
	_install_modal_blockers_v054()
	mode_owned_panels_ready_v054 = true
	_apply_right_panel_state_v037()
	_refresh_attach_points_v032()
	_update_ui()
	_status("v0.5.2 interaction reliability build: scrollable menus, direct transform selection, connection-axis ITEM rotation and reliable move commits active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_054, text]


# -----------------------------------------------------------------------------
# Scrollable UI and true modal input blocking.
# -----------------------------------------------------------------------------

func _configure_scroll_v054(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.scroll_deadzone = 6
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func _wrap_vbox_v054(box: VBoxContainer) -> ScrollContainer:
	if box == null:
		return null
	if box.get_parent() is ScrollContainer:
		var existing: ScrollContainer = box.get_parent() as ScrollContainer
		_configure_scroll_v054(existing)
		return existing
	var old_parent: Node = box.get_parent()
	if old_parent == null:
		return null
	var old_index: int = box.get_index()
	old_parent.remove_child(box)
	var scroll: ScrollContainer = ScrollContainer.new()
	_configure_scroll_v054(scroll)
	old_parent.add_child(scroll)
	old_parent.move_child(scroll, old_index)
	scroll.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return scroll


func _find_first_scroll_v054(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node as ScrollContainer
	for child_value in node.get_children():
		var found: ScrollContainer = _find_first_scroll_v054(child_value as Node)
		if found != null:
			return found
	return null


func _install_scroll_surfaces_v054() -> void:
	if options_panel != null:
		var options_box: VBoxContainer = _find_first_vbox_v050(options_panel)
		if options_box != null:
			options_scroll_v054 = _wrap_vbox_v054(options_box)
	if rotation_body != null:
		rotation_scroll_v054 = _wrap_vbox_v054(rotation_body)
	if move_body != null:
		move_scroll_v054 = _wrap_vbox_v054(move_body)
	if physics_box_v051 != null:
		physics_scroll_v054 = _wrap_vbox_v054(physics_box_v051)
	if parts_panel_v050 != null:
		var parts_scroll: ScrollContainer = _find_first_scroll_v054(parts_panel_v050)
		_configure_scroll_v054(parts_scroll)
	if parts_preview_container_v052 != null:
		# The preview is visual only. Let vertical swipes pass to its ScrollContainer.
		parts_preview_container_v052.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rotation_collapse_button != null:
		rotation_collapse_button.visible = false
	if move_collapse_button != null:
		move_collapse_button.visible = false


func _make_modal_blocker_v054(panel: Control) -> ColorRect:
	if panel == null or panel.get_parent() == null:
		return null
	var parent_node: Node = panel.get_parent()
	var blocker: ColorRect = ColorRect.new()
	blocker.name = "ModalBlockerV054_%s" % panel.name
	blocker.anchor_left = 0.0
	blocker.anchor_top = 0.0
	blocker.anchor_right = 1.0
	blocker.anchor_bottom = 1.0
	blocker.offset_left = 0.0
	blocker.offset_top = 0.0
	blocker.offset_right = 0.0
	blocker.offset_bottom = 0.0
	blocker.color = Color(0.0, 0.0, 0.0, 0.18)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = panel.visible
	parent_node.add_child(blocker)
	parent_node.move_child(blocker, maxi(0, panel.get_index() - 1))
	return blocker


func _install_modal_blockers_v054() -> void:
	for panel_value in [options_panel, help_panel, parts_panel_v050, builds_panel_v050, physics_panel_v051]:
		var panel: Control = panel_value as Control
		if panel == null:
			continue
		var key: int = panel.get_instance_id()
		if modal_blockers_v054.has(key):
			continue
		var blocker: ColorRect = _make_modal_blocker_v054(panel)
		if blocker != null:
			modal_blockers_v054[key] = blocker


func _sync_modal_blockers_v054() -> void:
	for panel_value in [options_panel, help_panel, parts_panel_v050, builds_panel_v050, physics_panel_v051]:
		var panel: Control = panel_value as Control
		if panel == null:
			continue
		var blocker: ColorRect = modal_blockers_v054.get(panel.get_instance_id()) as ColorRect
		if blocker != null:
			blocker.visible = panel.visible


func _any_modal_open_v054() -> bool:
	return (options_panel != null and options_panel.visible) or (help_panel != null and help_panel.visible) or (parts_panel_v050 != null and parts_panel_v050.visible) or (builds_panel_v050 != null and builds_panel_v050.visible) or (physics_panel_v051 != null and physics_panel_v051.visible)


# Side panels are owned by their editor mode from now on: no collapsed headers.
func _apply_right_panel_state_v037() -> void:
	if not mode_owned_panels_ready_v054:
		super._apply_right_panel_state_v037()
		return
	var rotate_active: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating
	var move_active: bool = editor_mode_v032 == EDITOR_MOVE_042 and not simulating
	right_panel_state_v037 = "rotate" if rotate_active else ("move" if move_active else "")
	if rotation_panel != null:
		rotation_panel.visible = rotate_active
	if rotation_body != null:
		rotation_body.visible = rotate_active
	if move_panel != null:
		move_panel.visible = move_active
	if move_body != null:
		move_body.visible = move_active
	if rotation_collapse_button != null:
		rotation_collapse_button.visible = false
	if move_collapse_button != null:
		move_collapse_button.visible = false
	_layout_right_panels_v032()


func _layout_right_panels_v032() -> void:
	if not mode_owned_panels_ready_v054:
		super._layout_right_panels_v032()
		return
	var top_value: float = 112.0
	var bottom_value: float = maxf(top_value + 300.0, get_viewport().get_visible_rect().size.y - 108.0)
	for panel_value in [rotation_panel, move_panel]:
		var panel: PanelContainer = panel_value as PanelContainer
		if panel == null:
			continue
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.offset_left = -268.0
		panel.offset_right = -8.0
		panel.offset_top = top_value
		panel.offset_bottom = bottom_value
		panel.clip_contents = true


func _toggle_rotation_panel() -> void:
	if not mode_owned_panels_ready_v054:
		super._toggle_rotation_panel()
		return
	# Non-collapsible by design. Mode switching controls visibility.
	_apply_right_panel_state_v037()


func _toggle_move_panel() -> void:
	if not mode_owned_panels_ready_v054:
		super._toggle_move_panel()
		return
	_apply_right_panel_state_v037()


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	super._set_editor_mode_v032(mode_value, report)
	if mode_owned_panels_ready_v054:
		_apply_right_panel_state_v037()


# -----------------------------------------------------------------------------
# Physics sliders: reset backing values AND the visible controls.
# -----------------------------------------------------------------------------

func _physics_slider_row_v050(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float, callback: Callable) -> Label:
	var before_count: int = parent.get_child_count()
	var label: Label = super._physics_slider_row_v050(parent, label_text, min_value, max_value, step, value, callback)
	for i in range(before_count, parent.get_child_count()):
		var slider: HSlider = parent.get_child(i) as HSlider
		if slider != null:
			physics_sliders_v054[label_text] = slider
			break
	return label


func _reset_physics_v050() -> void:
	super._reset_physics_v050()
	var defaults: Dictionary = {
		"Gravity": 9.81,
		"Surface friction": 0.72,
		"Bounce": 0.04,
		"Linear damping": 0.20,
		"Angular damping": 0.34,
	}
	for key_value in defaults.keys():
		var slider: HSlider = physics_sliders_v054.get(str(key_value)) as HSlider
		if slider != null:
			slider.set_value_no_signal(float(defaults[key_value]))
	_refresh_physics_labels_v050()


# -----------------------------------------------------------------------------
# Selection / palette / input reliability.
# -----------------------------------------------------------------------------

func _undo() -> void:
	var keep_rod: int = selected_rod_type
	var keep_connector: int = selected_connector_type
	super._undo()
	selected_rod_type = clampi(keep_rod, 0, rod_defs.size() - 1)
	selected_connector_type = clampi(keep_connector, 0, connector_defs.size() - 1)
	_update_ui()
	_refresh_parts_browser_v050()


func _redo() -> void:
	var keep_rod: int = selected_rod_type
	var keep_connector: int = selected_connector_type
	super._redo()
	selected_rod_type = clampi(keep_rod, 0, rod_defs.size() - 1)
	selected_connector_type = clampi(keep_connector, 0, connector_defs.size() - 1)
	_update_ui()
	_refresh_parts_browser_v050()


func _nearest_free_socket_on_body_v054(connector: RigidBody3D, screen_pos: Vector2, max_distance: float) -> Dictionary:
	if not is_instance_valid(connector):
		return {}
	_rebuild_connection_graph_v020()
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return {}
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	var candidates: Array = []
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		if occupied.has(slot):
			continue
		var socket: Dictionary = _socket_world_v020(connector, slot)
		candidates.append({"type": "socket", "body": connector, "slot": slot, "point": socket["point"]})
	return _nearest_projected_candidate_v030(candidates, screen_pos, max_distance)


func _nearest_free_rod_end_v054(rod: RigidBody3D, screen_pos: Vector2, max_distance: float) -> Dictionary:
	if not is_instance_valid(rod):
		return {}
	_rebuild_connection_graph_v020()
	var occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	var candidates: Array = []
	for sign_value in [-1, 1]:
		if not occupied.has(sign_value):
			candidates.append({"type": "rod_end", "body": rod, "sign": sign_value, "point": _rod_end_v020(rod, sign_value)})
	return _nearest_projected_candidate_v030(candidates, screen_pos, max_distance)


func _global_create_candidate_v054(screen_pos: Vector2) -> Dictionary:
	var candidates: Array = []
	_rebuild_connection_graph_v020()
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var kind: String = str(body.get_meta("kind", ""))
		if kind == "connector":
			var def_index: int = int(body.get_meta("connector_type", -1))
			if def_index < 0 or def_index >= connector_defs.size():
				continue
			var occupied: Dictionary = body.get_meta("occupied", {}) as Dictionary
			for slot_value in connector_defs[def_index]["slots"]:
				var slot: int = int(slot_value)
				if not occupied.has(slot):
					candidates.append({"type": "socket", "body": body, "slot": slot, "point": _socket_world_v020(body, slot)["point"]})
		elif kind == "rod":
			var end_occupied: Dictionary = body.get_meta("end_occupied", {}) as Dictionary
			for sign_value in [-1, 1]:
				if not end_occupied.has(sign_value):
					candidates.append({"type": "rod_end", "body": body, "sign": sign_value, "point": _rod_end_v020(body, sign_value)})
	return _nearest_projected_candidate_v030(candidates, screen_pos, GLOBAL_CREATE_POINT_PICK_RADIUS_V054)


func _try_socket_create_tap_v054(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_CREATE_032 or attach_mode != 0 or simulating:
		return false
	var hit: Dictionary = _raycast_piece(screen_pos)
	var candidate: Dictionary = {}
	if not hit.is_empty():
		var body: RigidBody3D = hit.get("collider") as RigidBody3D
		if is_instance_valid(body):
			var kind: String = str(body.get_meta("kind", ""))
			if kind == "connector":
				candidate = _nearest_free_socket_on_body_v054(body, screen_pos, CREATE_POINT_PICK_RADIUS_V054)
			elif kind == "rod":
				candidate = _nearest_free_rod_end_v054(body, screen_pos, CREATE_POINT_PICK_RADIUS_V054)
	if candidate.is_empty():
		candidate = _global_create_candidate_v054(screen_pos)
	if candidate.is_empty():
		return false
	var type_value: String = str(candidate.get("type", ""))
	if type_value == "socket":
		_extend_socket(candidate.get("body") as RigidBody3D, int(candidate.get("slot", -1)))
		return true
	if type_value == "rod_end":
		_attach_connector_to_rod_end(candidate.get("body") as RigidBody3D, int(candidate.get("sign", 0)))
		return true
	return false


func _handle_tap(screen_pos: Vector2) -> void:
	if _any_modal_open_v054():
		return
	# ROTATE and MOVE are direct-selection modes. The top Select button is no
	# longer needed just to choose another piece.
	if editor_mode_v032 in [EDITOR_ROTATE_032, EDITOR_MOVE_042]:
		var hit: Dictionary = _raycast_piece(screen_pos)
		var body: RigidBody3D = hit.get("collider") as RigidBody3D if not hit.is_empty() else null
		if is_instance_valid(body):
			_set_selected(body)
			_refresh_editor_overlay_v030()
			_refresh_gizmo_validity_v030()
			_status("Selected %s for %s" % [_piece_display_name(body), "ROTATE" if editor_mode_v032 == EDITOR_ROTATE_032 else "MOVE"])
		return
	if _try_socket_create_tap_v054(screen_pos):
		return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# ITEM transform solver.
# SOCKET/CROSS/AXLE connectors rotate around the actual connection axis.
# Ordinary attached ITEM movement rigidly translates the whole structure, but in
# the selected item's local axes. CROSS/AXLE/O-Ring movement remains a true slide.
# -----------------------------------------------------------------------------

func _mobility_v054() -> Dictionary:
	if not is_instance_valid(selected_piece):
		return {"kind": "none", "record": {}, "axis": Vector3.ZERO}
	_rebuild_connection_graph_v020()
	var records: Array = _connections_for_piece_v020(selected_piece)
	if records.is_empty():
		return {"kind": "free", "record": {}, "axis": Vector3.ZERO}
	var selected_kind: String = str(selected_piece.get_meta("kind", ""))
	var preferred: Dictionary = {}
	if selected_kind == "connector":
		preferred = _primary_record_for_connector_v020(selected_piece)
		if not preferred.is_empty() and str(preferred.get("kind", "")) not in ["socket", "cross", "axle"]:
			preferred = {}
	if preferred.is_empty():
		var matches: Array = []
		for record_value in records:
			var record: Dictionary = record_value as Dictionary
			var kind: String = str(record.get("kind", ""))
			if kind == "cross" and selected_kind == "connector" and record.get("connector") == selected_piece:
				matches.append(record)
			elif kind == "axle" and (record.get("connector") == selected_piece or record.get("rod") == selected_piece):
				matches.append(record)
			elif kind == "o_ring" and selected_kind == "o_ring" and record.get("ring") == selected_piece:
				matches.append(record)
			elif kind == "socket" and selected_kind == "connector" and record.get("connector") == selected_piece:
				matches.append(record)
		if matches.size() == 1:
			preferred = matches[0] as Dictionary
	if preferred.is_empty():
		return {"kind": "rigid", "record": {}, "axis": Vector3.ZERO}
	var rod: RigidBody3D = preferred.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return {"kind": "rigid", "record": {}, "axis": Vector3.ZERO}
	return {"kind": str(preferred.get("kind", "rigid")), "record": preferred, "axis": _rod_axis_v020(rod).normalized()}


func _mobility_v051() -> Dictionary:
	return _mobility_v054()


func _rotation_component_v054(mobility: Dictionary) -> Array:
	if not is_instance_valid(selected_piece):
		return []
	var kind: String = str(mobility.get("kind", "none"))
	if kind == "free":
		return [selected_piece]
	if kind in ["socket", "cross", "axle"]:
		var record: Dictionary = mobility.get("record", {}) as Dictionary
		var uid: int = int(record.get("uid", -1))
		if uid < 0:
			return []
		var component: Array = _fixed_component_v020(selected_piece, uid)
		var other: RigidBody3D = _other_body_v020(record, selected_piece)
		if is_instance_valid(other) and _component_has_piece_v020(component, other):
			return []
		return component
	return []


func _move_component_v054(mobility: Dictionary) -> Array:
	if not is_instance_valid(selected_piece):
		return []
	var kind: String = str(mobility.get("kind", "none"))
	if kind == "free":
		return [selected_piece]
	if kind in ["cross", "axle", "o_ring"]:
		var record: Dictionary = mobility.get("record", {}) as Dictionary
		return _fixed_component_v020(selected_piece, int(record.get("uid", -1)))
	# A normally socket-connected item is moved as one rigid structure, oriented
	# by the selected item's local basis instead of WORLD axes.
	return _connected_island_v037(selected_piece)


func _gizmo_anchor_v030() -> Vector3:
	if transform_space_v051 == SPACE_ITEM_051 and is_instance_valid(selected_piece):
		var mobility: Dictionary = _mobility_v054()
		if str(mobility.get("kind", "")) in ["socket", "cross", "axle"]:
			var record: Dictionary = mobility.get("record", {}) as Dictionary
			if not record.is_empty():
				return _record_anchor_v020(record)
	return super._gizmo_anchor_v030()


func _rotation_candidate_v030(axis_value: Vector3, direction_sign: int) -> Dictionary:
	if transform_space_v051 == SPACE_WORLD_051:
		return super._rotation_candidate_v030(axis_value, direction_sign)
	if not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "no selected piece"}
	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	var component: Array = _rotation_component_v054(mobility)
	if component.is_empty():
		return {"valid": false, "reason": "this item has no independent rotation at its current connections"}
	var requested_axis: Vector3 = axis_value.normalized()
	var pivot: Vector3 = selected_piece.global_position
	var excluded_uid: int = -1
	if kind in ["socket", "cross", "axle"]:
		var allowed_axis: Vector3 = mobility.get("axis", Vector3.ZERO) as Vector3
		if absf(requested_axis.dot(allowed_axis)) < 0.985:
			return {"valid": false, "reason": "%s only rotates around its actual connection axis" % kind.to_upper()}
		requested_axis = allowed_axis if requested_axis.dot(allowed_axis) >= 0.0 else -allowed_axis
		var record: Dictionary = mobility.get("record", {}) as Dictionary
		excluded_uid = int(record.get("uid", -1))
		pivot = _record_anchor_v020(record)
	elif kind != "free":
		return {"valid": false, "reason": "this item is rotationally locked"}
	var transforms: Dictionary = _rotate_map_v051(component, pivot, requested_axis, GIZMO_STEP_030 * float(direction_sign))
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "another connection blocks this rotation"))}
	return {"valid": true, "transforms": transforms, "component": component, "axis": requested_axis, "anchor": pivot, "kind": kind}


func _roll_candidate_v030(direction_sign: int) -> Dictionary:
	var mobility: Dictionary = _mobility_v054()
	if transform_space_v051 == SPACE_ITEM_051 and str(mobility.get("kind", "")) in ["socket", "cross", "axle"]:
		return _rotation_candidate_v030(mobility.get("axis", Vector3.ZERO) as Vector3, direction_sign)
	return super._roll_candidate_v030(direction_sign)


func _apply_roll_v030(direction_sign: int) -> void:
	var mobility: Dictionary = _mobility_v054()
	if transform_space_v051 == SPACE_ITEM_051 and str(mobility.get("kind", "")) in ["socket", "cross", "axle"]:
		var preview: Dictionary = _roll_candidate_v030(direction_sign)
		if not bool(preview.get("valid", false)):
			_status("ITEM roll blocked — %s" % str(preview.get("reason", "constraint")))
			return
		_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated ITEM around its connection axis by %d°" % (direction_sign * 45))
		return
	super._apply_roll_v030(direction_sign)


func _apply_world_rotation_step_v042(axis_name: String, direction_sign: int) -> void:
	if transform_space_v051 == SPACE_WORLD_051:
		super._apply_world_rotation_step_v042(axis_name, direction_sign)
		return
	if editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not is_instance_valid(selected_piece):
		return
	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	var axis: Vector3 = _local_axis_v051(axis_name)
	if kind in ["socket", "cross", "axle"]:
		if axis_name != "Y":
			_status("ITEM %s — only the real connection-axis rotation is valid" % kind.to_upper())
			return
		axis = mobility.get("axis", axis) as Vector3
	var preview: Dictionary = _rotation_candidate_v030(axis, direction_sign)
	if not bool(preview.get("valid", false)):
		_status("ITEM rotation blocked — %s" % str(preview.get("reason", "constraint")))
		return
	_apply_transform_map_v020(preview.get("transforms", {}) as Dictionary, "Rotated ITEM %s by %d°" % [axis_name, direction_sign * 45])


# Ring picking must return the real parametric finger-down position. v0.5.1
# returned tangent only, so the inherited drag solver started at param=0 and the
# first movement jumped the piece before tracking the finger.
func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var best: Dictionary = {}
	var best_distance: float = WORLD_GIZMO_PICK_PX_035
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = gizmo_axes_v030.get(name_value, {}) as Dictionary
		var ring: MeshInstance3D = data.get("ring") as MeshInstance3D
		if not is_instance_valid(ring) or not ring.visible:
			continue
		var axis: Vector3 = data.get("axis", Vector3.ZERO) as Vector3
		var pick: Dictionary = _ring_param_pick_v036(axis, screen_pos, best_distance)
		if not pick.is_empty() and float(pick.get("distance", 9999.0)) <= best_distance:
			best_distance = float(pick.get("distance", 9999.0))
			best = {
				"name": name_value,
				"axis": axis,
				"param": float(pick.get("param", 0.0)),
				"center": pick.get("center", _gizmo_anchor_v030()),
				"tangent": pick.get("tangent", Vector2.RIGHT),
			}
	return best


func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	if _any_modal_open_v054() or editor_mode_v032 != EDITOR_ROTATE_032 or simulating or not is_instance_valid(selected_piece):
		return false
	var picked: Dictionary = _pick_gizmo_axis_v030(screen_pos)
	if picked.is_empty():
		return false
	var axis: Vector3 = picked.get("axis", Vector3.ZERO) as Vector3
	var plus: Dictionary = _rotation_candidate_v030(axis, 1)
	var minus: Dictionary = _rotation_candidate_v030(axis, -1)
	if not bool(plus.get("valid", false)) and not bool(minus.get("valid", false)):
		return false
	var mobility: Dictionary = _mobility_v054()
	var component: Array = _rotation_component_v054(mobility) if transform_space_v051 == SPACE_ITEM_051 else _connected_island_v037(selected_piece)
	if component.is_empty():
		return false
	gizmo_drag_active_v030 = true
	gizmo_drag_axis_v030 = axis
	gizmo_drag_axis_name_v030 = str(picked.get("name", ""))
	gizmo_drag_center_v030 = picked.get("center", _gizmo_anchor_v030()) as Vector3
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = component
	gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
	gizmo_drag_last_param_v036 = float(picked.get("param", 0.0))
	gizmo_drag_accum_angle_v036 = 0.0
	_build_rotation_ghost_v030(component)
	return true


func _item_move_candidate_v054(axis_value: Vector3, requested_delta: float) -> Dictionary:
	if not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "no selected piece"}
	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	var component: Array = _move_component_v054(mobility)
	if component.is_empty():
		return {"valid": false, "reason": "nothing movable is selected"}
	var axis: Vector3 = axis_value.normalized()
	var delta_value: float = requested_delta
	var excluded_uid: int = -1
	if kind in ["cross", "axle", "o_ring"]:
		var allowed_axis: Vector3 = mobility.get("axis", Vector3.ZERO) as Vector3
		if absf(axis.dot(allowed_axis)) < 0.985:
			return {"valid": false, "reason": "%s only slides along the host rod" % kind.to_upper()}
		var sign_value: float = 1.0 if axis.dot(allowed_axis) >= 0.0 else -1.0
		axis = allowed_axis * sign_value
		delta_value = _clamp_slide_delta_v051(mobility, requested_delta * sign_value)
		excluded_uid = int((mobility.get("record", {}) as Dictionary).get("uid", -1))
	if absf(delta_value) < 0.0001:
		return {"valid": false, "reason": "already at the end of the available slide"}
	var delta: Vector3 = axis * delta_value
	var transforms: Dictionary = _translation_map_v042(component, delta)
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "another connection prevents the move"))}
	return {"valid": true, "transforms": transforms, "component": component, "mobility": mobility, "kind": kind, "delta": delta}


func _apply_item_move_preview_v054(preview: Dictionary, label_value: String) -> void:
	if not bool(preview.get("valid", false)):
		_status("ITEM move blocked — %s" % str(preview.get("reason", "constraint")))
		return
	var transforms: Dictionary = preview.get("transforms", {}) as Dictionary
	var mobility: Dictionary = preview.get("mobility", {}) as Dictionary
	var kind: String = str(preview.get("kind", "none"))
	var delta: Vector3 = preview.get("delta", Vector3.ZERO) as Vector3
	_apply_transforms_raw_v030(transforms)
	if kind in ["cross", "o_ring"]:
		var record: Dictionary = mobility.get("record", {}) as Dictionary
		var joint: Joint3D = record.get("joint") as Joint3D
		var axis: Vector3 = mobility.get("axis", Vector3.UP) as Vector3
		var new_along: float = float(record.get("host_along", 0.0)) + delta.dot(axis)
		if is_instance_valid(joint):
			joint.set_meta("host_along_v020", new_along)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	_status(label_value)


func _apply_item_move_v051(axis_value: Vector3, requested_delta: float, label_value: String) -> void:
	_apply_item_move_preview_v054(_item_move_candidate_v054(axis_value, requested_delta), label_value)


func _apply_world_move_step_v042(axis: Vector3, steps: int) -> void:
	if transform_space_v051 == SPACE_WORLD_051:
		super._apply_world_move_step_v042(axis, steps)
		return
	if simulating or editor_mode_v032 != EDITOR_MOVE_042 or not is_instance_valid(selected_piece):
		return
	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	var axis_value: Vector3
	if kind in ["cross", "axle", "o_ring"]:
		if absf(axis.dot(Vector3.UP)) < 0.99:
			_status("ITEM %s — only host-axis movement is valid" % kind.to_upper())
			return
		axis_value = mobility.get("axis", Vector3.UP) as Vector3
	else:
		axis_value = _local_axis_v051(_axis_name_v042(axis))
	_apply_item_move_v051(axis_value, MOVE_STEP_042 * float(steps), "Moved ITEM by %.2f" % (MOVE_STEP_042 * float(steps)))


func _begin_move_drag_v042(screen_pos: Vector2) -> bool:
	if transform_space_v051 == SPACE_WORLD_051:
		return super._begin_move_drag_v042(screen_pos)
	if _any_modal_open_v054() or editor_mode_v032 != EDITOR_MOVE_042 or simulating or not is_instance_valid(selected_piece):
		return false
	var picked: Dictionary = _pick_move_axis_v042(screen_pos)
	if picked.is_empty():
		return false
	var mobility: Dictionary = _mobility_v054()
	var component: Array = _move_component_v054(mobility)
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
	return true


func _update_move_drag_v042(screen_pos: Vector2) -> void:
	if transform_space_v051 == SPACE_WORLD_051:
		super._update_move_drag_v042(screen_pos)
		return
	if not move_drag_active_v042:
		return
	var screen_delta: float = (screen_pos - move_drag_start_screen_v042).dot(move_drag_screen_dir_v042)
	var steps: int = int(round(screen_delta / MOVE_DRAG_STEP_PX_042))
	if steps == move_drag_steps_v042:
		return
	move_drag_steps_v042 = steps
	if steps == 0:
		move_drag_preview_v042 = {"valid": true, "transforms": {}}
		_show_rotation_ghost_v030({}, true)
		return
	var preview: Dictionary = _item_move_candidate_v054(move_drag_axis_v042, MOVE_STEP_042 * float(steps))
	move_drag_preview_v042 = preview
	_show_rotation_ghost_v030(preview.get("transforms", {}) as Dictionary, bool(preview.get("valid", false)))


func _finish_move_drag_v042() -> void:
	if transform_space_v051 == SPACE_WORLD_051:
		super._finish_move_drag_v042()
		return
	if not move_drag_active_v042:
		return
	var steps: int = move_drag_steps_v042
	var preview: Dictionary = move_drag_preview_v042.duplicate(false)
	move_drag_active_v042 = false
	move_drag_steps_v042 = 0
	move_drag_component_v042 = []
	move_drag_preview_v042 = {}
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Move unchanged")
		return
	_apply_item_move_preview_v054(preview, "Moved ITEM by %.2f" % (MOVE_STEP_042 * float(steps)))


# -----------------------------------------------------------------------------
# Attachment marker correctness, spatial ports, and larger CROSS plus signs.
# -----------------------------------------------------------------------------

func _point_material_v032(point: Dictionary, selected: bool) -> StandardMaterial3D:
	if not attach_point_selected_v032.is_empty() and attach_mode == 0:
		var source: Dictionary = attach_point_selected_v032
		var source_record: Dictionary = _connection_record_for_point_v032(source)
		if str(source.get("type", "")) == "socket" and not source_record.is_empty() and str(source_record.get("kind", "")) == "socket":
			if point.get("body") == source.get("body") and str(point.get("type", "")) == "socket" and int(point.get("slot", -1)) != int(source.get("slot", -1)) and _connection_record_for_point_v032(point).is_empty():
				return point_selected_mat_v032 if selected else attach_target_mat_v042
	return super._point_material_v032(point, selected)


func _refresh_attach_points_v032() -> void:
	super._refresh_attach_points_v032()
	if attach_points_root_v032 == null or attach_mode != 2:
		return
	for child_value in attach_points_root_v032.get_children():
		var label: Label3D = child_value as Label3D
		if label != null and str(label.name).begins_with("CrossPlusV051"):
			var is_selected: bool = label.modulate.is_equal_approx(Color(1.0, 0.92, 0.08))
			label.font_size = 144 if is_selected else 108
			label.outline_size = 20


func _spatial_socket_candidates_v054(expected_body: RigidBody3D = null) -> Array:
	var result: Array = []
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		if str(point.get("type", "")) != "socket" or not _is_spatial_slot_v041(int(point.get("slot", -1))):
			continue
		if is_instance_valid(expected_body) and point.get("body") != expected_body:
			continue
		result.append(point)
	return result


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	if editor_mode_v032 == EDITOR_ATTACH_032 and attach_mode in [0, 2]:
		var spatial: Dictionary = _nearest_projected_candidate_v030(_spatial_socket_candidates_v054(), screen_pos, SPATIAL_PICK_RADIUS_V054)
		if not spatial.is_empty() and _allowed_initial_point_v035(spatial):
			return spatial
	return super._pick_initial_attach_point_v035(screen_pos)


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	var expected: Array = _expected_target_types_v035(str(source.get("type", "")))
	if "socket" in expected:
		var candidates: Array = []
		for point_value in _spatial_socket_candidates_v054():
			var point: Dictionary = point_value as Dictionary
			if point.get("body") != source.get("body") and _attach_target_is_available_v040(source, point):
				candidates.append(point)
		var spatial: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, SPATIAL_PICK_RADIUS_V054)
		if not spatial.is_empty():
			return spatial
	return super._pick_attach_target_v035(screen_pos, source)


# -----------------------------------------------------------------------------
# 11/14-point connector rebuild: current rounded jaws on ALL ports, immediate
# stale-geometry removal, and rounded bridges for the out-of-plane arcs.
# -----------------------------------------------------------------------------

func _remove_connector_visuals_immediate_v054(body: RigidBody3D) -> void:
	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child is MeshInstance3D or child is CollisionShape3D or str(child.name).begins_with("SpatialSocket_") or str(child.name).begins_with("SpatialArcBridgeV054"):
			body.remove_child(child)
			child.queue_free()


func _add_spatial_arc_bridge_v054(parent: Node3D, slots: Array, color: Color, name_value: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = name_value
	parent.add_child(root)
	var material: Material = _mat(color.darkened(0.035))
	var points: Array = []
	for slot_value in slots:
		points.append(_slot_dir(int(slot_value)) * 0.84)
	for i in range(points.size() - 1):
		_add_capsule_between_v052(root, points[i] as Vector3, points[i + 1] as Vector3, 0.105, material, 12)


func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if def_index < 0 or def_index >= connector_defs.size() or def_index == o_ring_index:
		return
	var definition: Dictionary = connector_defs[def_index] as Dictionary
	if not bool(definition.get("spatial_3d", false)):
		# Remove nested spatial assemblies immediately before the inherited planar
		# rebuild queues/replaces the ordinary mesh children.
		for child_value in body.get_children():
			var child: Node = child_value as Node
			if str(child.name).begins_with("SpatialSocket_") or str(child.name).begins_with("SpatialArcBridgeV054"):
				body.remove_child(child)
				child.queue_free()
		super._rebuild_connector(body, def_index)
		return

	_remove_connector_visuals_immediate_v054(body)
	body.mass = float(definition.get("mass", 0.30))
	body.set_meta("connector_type", def_index)
	var color: Color = definition.get("color", Color.WHITE) as Color
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.06))
	var hub: MeshInstance3D = MeshInstance3D.new()
	var hub_mesh: TorusMesh = TorusMesh.new()
	hub_mesh.inner_radius = 0.30
	hub_mesh.outer_radius = 0.61
	hub_mesh.rings = 20
	hub_mesh.ring_segments = 12
	hub.mesh = hub_mesh
	hub.material_override = main_mat
	body.add_child(hub)
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
	for slot_value in definition.get("slots", []):
		var slot: int = int(slot_value)
		if _is_spatial_slot_v041(slot):
			_add_spatial_socket_visual_v041(body, slot, color)
		else:
			# Dynamic call resolves to the current v0.5.1 rounded/open-jaw design.
			_add_real_socket_visual(body, slot, color)
	if bool(definition.get("arc_top", false)):
		_add_spatial_arc_bridge_v054(body, TOP_ARC_SLOTS_041, color, "SpatialArcBridgeV054_Top")
	if bool(definition.get("arc_bottom", false)):
		_add_spatial_arc_bridge_v054(body, BOTTOM_ARC_SLOTS_041, color, "SpatialArcBridgeV054_Bottom")
	var central_collision: CollisionShape3D = CollisionShape3D.new()
	var central_shape: CylinderShape3D = CylinderShape3D.new()
	central_shape.radius = 1.46
	central_shape.height = 0.52
	central_collision.shape = central_shape
	body.add_child(central_collision)
	for slot_value in definition.get("slots", []):
		var slot: int = int(slot_value)
		if _is_spatial_slot_v041(slot):
			_add_spatial_collision_v041(body, slot)


# -----------------------------------------------------------------------------
# Auto-connect and disconnect reliability.
# -----------------------------------------------------------------------------

func _best_socket_for_end_v020(rod: RigidBody3D, sign_value: int) -> Dictionary:
	var rod_occ: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	if rod_occ.has(sign_value):
		return {}
	var end_point: Vector3 = _rod_end_v020(rod, sign_value)
	var outward: Vector3 = _rod_axis_v020(rod) * float(sign_value)
	var best: Dictionary = {}
	var best_distance: float = AUTO_SOCKET_CAPTURE_V054
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
			var socket_dir: Vector3 = socket.get("dir", Vector3.ZERO) as Vector3
			if socket_dir.dot(-outward) < AUTO_SOCKET_ALIGN_V054:
				continue
			var distance: float = (socket.get("point", connector.global_position) as Vector3).distance_to(end_point)
			if distance <= best_distance:
				best_distance = distance
				best = {"connector": connector, "slot": slot, "distance": distance, "point": socket["point"], "rod_point": end_point}
	return best


func _disconnect_selected_v042() -> void:
	if simulating or not is_instance_valid(selected_piece):
		return
	_rebuild_connection_graph_v020()
	var attached: Array = _connections_for_piece_v020(selected_piece).duplicate(false)
	if attached.is_empty():
		_status("Selected piece is already disconnected")
		return
	var anchor_sum: Vector3 = Vector3.ZERO
	var anchor_count: int = 0
	for record_value in attached:
		var record: Dictionary = record_value as Dictionary
		var a: RigidBody3D = record.get("a") as RigidBody3D
		var b: RigidBody3D = record.get("b") as RigidBody3D
		if is_instance_valid(a) and is_instance_valid(b):
			manual_detach_blocks_v030[_pair_key_v030(a, b)] = true
		var anchor: Vector3 = _record_anchor_v020(record)
		anchor_sum += anchor
		anchor_count += 1
		var connector: RigidBody3D = record.get("connector") as RigidBody3D
		if is_instance_valid(connector) and int(connector.get_meta("primary_connection_uid_v020", -1)) == int(record.get("uid", -1)):
			connector.set_meta("primary_connection_uid_v020", -1)
		if str(record.get("kind", "")) == "cross" and is_instance_valid(connector):
			connector.set_meta("cross_mount", false)
			connector.set_meta("cross_host_rod", null)
		var joint: Joint3D = record.get("joint") as Joint3D
		if is_instance_valid(joint):
			joints.erase(joint)
			if joint.get_parent() != null:
				joint.get_parent().remove_child(joint)
			joint.queue_free()
	_rebuild_connection_graph_v020()
	var average_anchor: Vector3 = anchor_sum / float(anchor_count) if anchor_count > 0 else selected_piece.global_position
	var nudge_dir: Vector3 = selected_piece.global_position - average_anchor
	if nudge_dir.length_squared() < 0.04:
		nudge_dir = selected_piece.global_transform.basis.x
	if nudge_dir.length_squared() < 0.04:
		nudge_dir = Vector3.RIGHT
	selected_piece.global_position += nudge_dir.normalized() * DISCONNECT_NUDGE_V054
	selected_piece.set_meta("build_transform", selected_piece.global_transform)
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	_status("Disconnected selected piece and opened a visible gap. That pair stays snap-blocked until explicitly re-attached.")


# -----------------------------------------------------------------------------
# Wider camera zoom and modal-safe gesture routing.
# -----------------------------------------------------------------------------

func _handle_move_input_v042(event: InputEvent) -> bool:
	if _any_modal_open_v054():
		return false
	return super._handle_move_input_v042(event)


func _unhandled_input(event: InputEvent) -> void:
	if _any_modal_open_v054():
		return
	# Preserve the established two-finger pan, but widen the useful zoom range.
	if event is InputEventScreenDrag and touches.size() >= 2:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		touches[drag.index] = drag.position
		if drag.relative.length() > 2.0:
			touch_moved[drag.index] = true
		var distance: float = _pinch_distance()
		if pinch_last > 0.0:
			camera_distance = clampf(camera_distance - (distance - pinch_last) * 0.030, CAMERA_MIN_DISTANCE_V054, CAMERA_MAX_DISTANCE_V054)
		pinch_last = distance
		var center: Vector2 = _pinch_center()
		if pinch_center_valid:
			_pan_camera(center - pinch_center_last)
		pinch_center_last = center
		pinch_center_valid = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera_distance = clampf(camera_distance + (-2.0 if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0), CAMERA_MIN_DISTANCE_V054, CAMERA_MAX_DISTANCE_V054)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _update_transform_ui_v051() -> void:
	super._update_transform_ui_v051()
	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	if transform_space_v051 == SPACE_ITEM_051 and rotation_hint_v035 != null:
		if kind in ["socket", "cross", "axle"]:
			rotation_hint_v035.text = "ITEM %s: rotate around the actual attachment/rod axis. The gizmo and Roll perform the same physical rotation." % kind.to_upper()
		elif kind == "rigid":
			rotation_hint_v035.text = "ITEM rotation is locked by multiple connections. MOVE still translates the rigid structure in this item's local axes."


func _update_ui() -> void:
	super._update_ui()
	if mode_owned_panels_ready_v054:
		_apply_right_panel_state_v037()
	var mobility: Dictionary = _mobility_v054() if is_instance_valid(selected_piece) else {"kind": "none"}
	var kind: String = str(mobility.get("kind", "none"))
	var item_mode: bool = transform_space_v051 == SPACE_ITEM_051
	var constrained_rotate: bool = item_mode and kind in ["socket", "cross", "axle"]
	var constrained_move: bool = item_mode and kind in ["cross", "axle", "o_ring"]
	var rotation_buttons: Array = [rot_x_minus_v042, rot_x_plus_v042, rot_y_minus_v042, rot_y_plus_v042, rot_z_minus_v042, rot_z_plus_v042]
	var move_buttons: Array = [move_x_minus_v042, move_x_plus_v042, move_y_minus_v042, move_y_plus_v042, move_z_minus_v042, move_z_plus_v042]
	for i in range(rotation_buttons.size()):
		var axis_index: int = i / 2
		var rb: Button = rotation_buttons[i] as Button
		var mb: Button = move_buttons[i] as Button
		if rb != null:
			rb.visible = not item_mode or kind == "free" or (constrained_rotate and axis_index == 1)
		if mb != null:
			mb.visible = not item_mode or not constrained_move or axis_index == 1
	if roll_minus_v035 != null and item_mode and kind in ["socket", "cross", "axle"]:
		roll_minus_v035.disabled = not bool(_roll_candidate_v030(-1).get("valid", false))
	if roll_plus_v035 != null and item_mode and kind in ["socket", "cross", "axle"]:
		roll_plus_v035.disabled = not bool(_roll_candidate_v030(1).get("valid", false))


func _process(delta: float) -> void:
	super._process(delta)
	_sync_modal_blockers_v054()
	if mode_owned_panels_ready_v054:
		_apply_right_panel_state_v037()
	if not is_instance_valid(selected_piece):
		return
	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	var item_mode: bool = transform_space_v051 == SPACE_ITEM_051
	var rotation_constrained: bool = item_mode and kind in ["socket", "cross", "axle"]
	var move_constrained: bool = item_mode and kind in ["cross", "axle", "o_ring"]
	var rotation_basis: Basis = Basis.IDENTITY
	if item_mode:
		rotation_basis = _item_basis_for_axis_v051(mobility.get("axis", Vector3.UP) as Vector3) if rotation_constrained else selected_piece.global_transform.basis.orthonormalized()
	if gizmo_root_v030 != null and gizmo_root_v030.visible:
		gizmo_root_v030.global_basis = rotation_basis if item_mode else Basis.IDENTITY
		for name_value in ["X", "Y", "Z"]:
			var data: Dictionary = gizmo_axes_v030.get(name_value, {}) as Dictionary
			if data.is_empty():
				continue
			var local_axis: Vector3 = Vector3.RIGHT if name_value == "X" else (Vector3.UP if name_value == "Y" else Vector3.BACK)
			data["axis"] = (rotation_basis * local_axis).normalized() if item_mode else local_axis
			var ring: MeshInstance3D = data.get("ring") as MeshInstance3D
			var plus: Label3D = data.get("plus") as Label3D
			var minus: Label3D = data.get("minus") as Label3D
			var show_axis: bool = not item_mode or kind == "free" or (rotation_constrained and name_value == "Y")
			if is_instance_valid(ring): ring.visible = show_axis
			if is_instance_valid(plus): plus.visible = show_axis
			if is_instance_valid(minus): minus.visible = show_axis
	var move_basis: Basis = selected_piece.global_transform.basis.orthonormalized() if item_mode and not move_constrained else (_item_basis_for_axis_v051(mobility.get("axis", Vector3.UP) as Vector3) if move_constrained else Basis.IDENTITY)
	if move_gizmo_root_v042 != null and move_gizmo_root_v042.visible:
		move_gizmo_root_v042.global_basis = move_basis if item_mode else Basis.IDENTITY
		for name_value in ["X", "Y", "Z"]:
			var data: Dictionary = move_gizmo_axes_v042.get(name_value, {}) as Dictionary
			if data.is_empty():
				continue
			var local_axis: Vector3 = Vector3.RIGHT if name_value == "X" else (Vector3.UP if name_value == "Y" else Vector3.BACK)
			data["axis"] = (move_basis * local_axis).normalized() if item_mode else local_axis
			var root: Node3D = data.get("root") as Node3D
			if is_instance_valid(root):
				root.visible = not move_constrained or name_value == "Y"


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nMENUS: Options, Parts, Physics, Rotate and Move are touch-scrollable. Rotate/Move side panels exist only while that editor mode is active and are not collapsible. Modal menus block all construction input behind them.\n\nSELECTION: in ROTATE or MOVE, tap a piece directly to select it; the separate Select button is not required.\n\nITEM ROTATE: free pieces use local XYZ. A SOCKET/CROSS/AXLE-mounted connector rotates around its real attachment axis; the single gizmo ring and Roll are the same physical DOF.\n\nITEM MOVE: ordinary connected structures translate in the selected item's LOCAL axes. CROSS/AXLE/O-Ring parts slide only along the host rod. Drag preview and release use the exact same validated transform.\n\nATTACH: valid re-seat sockets stay green, CROSS + markers are larger, and 11/14 spatial ports get enlarged marker-first picking.\n\nCREATE: socket/rod-end taps use screen-space connection-point picking for fewer missed taps. Nearby compatible second rod ends auto-connect more forgivingly.\n\nDISCONNECT: creates a visible gap and keeps the old pair snap-blocked until explicit re-attach.\n\nCAMERA: two-finger pan/zoom remains active with a much wider 3–420 distance range." % VERSION_054
