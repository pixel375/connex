extends "res://scripts/main_v055.gd"

const VERSION_056 := "0.5.3-dev"
const TOUCH_SCROLL_DEADZONE_V056 := 10.0
const TOUCH_SCROLL_AXIS_BIAS_V056 := 1.08
const AUTO_SOCKET_CAPTURE_V056 := 1.10
const AUTO_SOCKET_ALIGN_V056 := 0.86

var panel_scrolls_v056: Dictionary = {}
var scroll_touch_index_v056: int = -1
var scroll_touch_target_v056: Object
var scroll_touch_kind_v056: String = ""
var scroll_touch_origin_v056: Vector2 = Vector2.ZERO
var scroll_touch_last_v056: Vector2 = Vector2.ZERO
var scroll_touch_start_value_v056: float = 0.0
var scroll_touch_active_v056: bool = false
var modal_blocked_touches_v056: Dictionary = {}


func _ready() -> void:
	super._ready()
	_install_drag_scroll_surfaces_v056()
	_update_transform_ui_v051()
	_refresh_selection_highlight()
	_refresh_gizmo_validity_v030()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Development version: v%s" % VERSION_056)
	_status("v0.5.3 touch/attachment pass active — pull-to-scroll menus, hard modal input blocking, STRUCTURE rotation and occupied-end rewiring.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_056, text]


# -----------------------------------------------------------------------------
# Real touch scrolling.
#
# ScrollContainer alone was not sufficient on-device because child Controls can
# own the touch sequence. Track a vertical swipe at the viewport-input stage and
# drive the same scrollbar directly. A short tap is deliberately left alone so
# buttons, tabs and sliders keep their normal click behavior.
# -----------------------------------------------------------------------------

func _register_panel_scroll_v056(panel: Control, scroll: ScrollContainer) -> void:
	if panel == null or scroll == null:
		return
	_configure_scroll_v054(scroll)
	scroll.scroll_deadzone = 4
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar != null:
		bar.custom_minimum_size.x = maxf(bar.custom_minimum_size.x, 14.0)
	panel_scrolls_v056[panel.get_instance_id()] = scroll


func _ensure_panel_scroll_v056(panel: Control) -> ScrollContainer:
	if panel == null:
		return null
	var existing: ScrollContainer = _find_first_scroll_v054(panel)
	if existing != null:
		_configure_scroll_v054(existing)
		return existing
	var box: VBoxContainer = _find_first_vbox_v050(panel)
	if box == null:
		return null
	return _wrap_vbox_v054(box)


func _install_drag_scroll_surfaces_v056() -> void:
	panel_scrolls_v056.clear()
	_register_panel_scroll_v056(options_panel, options_scroll_v054 if options_scroll_v054 != null else _ensure_panel_scroll_v056(options_panel))
	_register_panel_scroll_v056(parts_panel_v050, _ensure_panel_scroll_v056(parts_panel_v050))
	_register_panel_scroll_v056(builds_panel_v050, _ensure_panel_scroll_v056(builds_panel_v050))
	_register_panel_scroll_v056(help_panel, _ensure_panel_scroll_v056(help_panel))
	_register_panel_scroll_v056(physics_panel_v051, physics_scroll_v054 if physics_scroll_v054 != null else _ensure_panel_scroll_v056(physics_panel_v051))
	_register_panel_scroll_v056(rotation_panel, rotation_scroll_v054 if rotation_scroll_v054 != null else _ensure_panel_scroll_v056(rotation_panel))
	_register_panel_scroll_v056(move_panel, move_scroll_v054 if move_scroll_v054 != null else _ensure_panel_scroll_v056(move_panel))


func _control_contains_v056(control: Control, screen_pos: Vector2) -> bool:
	return control != null and control.visible and control.is_visible_in_tree() and control.get_global_rect().has_point(screen_pos)


func _active_modal_v056() -> Control:
	# Highest/most-specific surfaces first. Normally only one is visible because
	# opening a child modal hides its parent, but priority makes this deterministic.
	for value in [physics_panel_v051, builds_panel_v050, parts_panel_v050, help_panel, options_panel]:
		var panel: Control = value as Control
		if panel != null and panel.visible and panel.is_visible_in_tree():
			return panel
	return null


func _scroll_target_for_point_v056(screen_pos: Vector2) -> Dictionary:
	var modal: Control = _active_modal_v056()
	var panel: Control = modal
	if panel == null:
		if _control_contains_v056(rotation_panel, screen_pos):
			panel = rotation_panel
		elif _control_contains_v056(move_panel, screen_pos):
			panel = move_panel
	if panel == null or not _control_contains_v056(panel, screen_pos):
		return {}

	# Saves contains an ItemList with its own scrollbar. Pulling directly on the
	# list should scroll the list instead of an outer wrapper.
	if panel == builds_panel_v050 and builds_list_v050 != null and _control_contains_v056(builds_list_v050, screen_pos):
		var list_bar: VScrollBar = builds_list_v050.get_v_scroll_bar()
		if list_bar != null:
			return {"kind": "range", "target": list_bar}

	var scroll: ScrollContainer = panel_scrolls_v056.get(panel.get_instance_id()) as ScrollContainer
	if scroll == null:
		return {}
	return {"kind": "scroll", "target": scroll}


func _begin_panel_scroll_v056(screen_pos: Vector2, touch_index: int) -> bool:
	var target_info: Dictionary = _scroll_target_for_point_v056(screen_pos)
	if target_info.is_empty():
		return false
	scroll_touch_index_v056 = touch_index
	scroll_touch_kind_v056 = str(target_info.get("kind", ""))
	scroll_touch_target_v056 = target_info.get("target") as Object
	scroll_touch_origin_v056 = screen_pos
	scroll_touch_last_v056 = screen_pos
	scroll_touch_active_v056 = false
	if scroll_touch_kind_v056 == "scroll":
		var scroll: ScrollContainer = scroll_touch_target_v056 as ScrollContainer
		scroll_touch_start_value_v056 = float(scroll.scroll_vertical) if scroll != null else 0.0
	elif scroll_touch_kind_v056 == "range":
		var range_value: Range = scroll_touch_target_v056 as Range
		scroll_touch_start_value_v056 = range_value.value if range_value != null else 0.0
	else:
		_end_panel_scroll_v056()
		return false
	return true


func _drag_panel_scroll_v056(screen_pos: Vector2, touch_index: int) -> bool:
	if touch_index != scroll_touch_index_v056 or scroll_touch_target_v056 == null:
		return false
	var total: Vector2 = screen_pos - scroll_touch_origin_v056
	if not scroll_touch_active_v056:
		if absf(total.y) < TOUCH_SCROLL_DEADZONE_V056:
			return false
		# Keep horizontal slider/button gestures horizontal. Vertical or diagonal
		# pulls become scrolling once Y is the dominant intent.
		if absf(total.y) < absf(total.x) * TOUCH_SCROLL_AXIS_BIAS_V056:
			return false
		scroll_touch_active_v056 = true
	var value: float = scroll_touch_start_value_v056 - total.y
	if scroll_touch_kind_v056 == "scroll":
		var scroll: ScrollContainer = scroll_touch_target_v056 as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = int(round(value))
	elif scroll_touch_kind_v056 == "range":
		var range_value: Range = scroll_touch_target_v056 as Range
		if range_value != null:
			range_value.value = clampf(value, range_value.min_value, range_value.max_value)
	scroll_touch_last_v056 = screen_pos
	return true


func _end_panel_scroll_v056() -> bool:
	var was_active: bool = scroll_touch_active_v056
	scroll_touch_index_v056 = -1
	scroll_touch_target_v056 = null
	scroll_touch_kind_v056 = ""
	scroll_touch_active_v056 = false
	return was_active


# _input runs before Control GUI activation. This is the missing piece in the old
# sibling-ColorRect blocker: a modal now blocks higher CanvasLayer controls too.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			var modal: Control = _active_modal_v056()
			if modal != null and not _control_contains_v056(modal, touch.position):
				modal_blocked_touches_v056[touch.index] = true
				get_viewport().set_input_as_handled()
				return
			_begin_panel_scroll_v056(touch.position, touch.index)
		else:
			if modal_blocked_touches_v056.has(touch.index):
				modal_blocked_touches_v056.erase(touch.index)
				get_viewport().set_input_as_handled()
				return
			if touch.index == scroll_touch_index_v056:
				if _end_panel_scroll_v056():
					# Swallow release so a Button that saw the initial press cannot fire
					# after the user actually performed a swipe.
					get_viewport().set_input_as_handled()
				return
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if modal_blocked_touches_v056.has(drag.index):
			get_viewport().set_input_as_handled()
			return
		if _drag_panel_scroll_v056(drag.position, drag.index):
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		var active_modal: Control = _active_modal_v056()
		if active_modal != null and not _control_contains_v056(active_modal, mouse_event.position):
			get_viewport().set_input_as_handled()
			return


# -----------------------------------------------------------------------------
# Selection must always win over CREATE.
# -----------------------------------------------------------------------------

func _try_socket_create_tap_v054(screen_pos: Vector2) -> bool:
	if select_armed_v020:
		return false
	return super._try_socket_create_tap_v054(screen_pos)


func _handle_tap(screen_pos: Vector2) -> void:
	if _active_modal_v056() != null:
		return
	if editor_mode_v032 == EDITOR_CREATE_032 and select_armed_v020:
		var hit: Dictionary = _raycast_piece(screen_pos)
		if hit.is_empty():
			_status("Select is still armed — tap a piece; CREATE placement is disabled until selection succeeds or Select is cancelled.")
			return
		var body: RigidBody3D = hit.get("collider") as RigidBody3D
		if is_instance_valid(body):
			_set_selected(body)
			_refresh_selection_highlight()
			_update_ui()
			_status("Selected %s" % _piece_display_name(body))
		return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# WORLD is a confusing name for a connected-build transform. The implementation
# constant remains unchanged for save/backward compatibility; user-facing text is
# STRUCTURE everywhere the shared transform-space switch is shown.
# -----------------------------------------------------------------------------

func _rename_world_labels_v056(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child is Label:
			var label: Label = child as Label
			if "WORLD" in label.text:
				label.text = label.text.replace("WORLD", "STRUCTURE")
		if child != null:
			_rename_world_labels_v056(child)


func _update_transform_ui_v051() -> void:
	super._update_transform_ui_v051()
	var structure_mode: bool = transform_space_v051 == SPACE_WORLD_051
	if rotate_space_button_v051 != null:
		rotate_space_button_v051.text = "Transform: STRUCTURE" if structure_mode else "Transform: ITEM"
	if move_space_button_v051 != null:
		# Transform space is shared; use one name in both tools so the two buttons
		# cannot appear to represent different states.
		move_space_button_v051.text = "Transform: STRUCTURE" if structure_mode else "Transform: ITEM"
	_rename_world_labels_v056(rotation_body)
	_rename_world_labels_v056(move_body)
	if mode_hint_v032 != null:
		if editor_mode_v032 == EDITOR_ROTATE_032 and structure_mode:
			mode_hint_v032.text = "STRUCTURE rotation • entire connected construction"
		elif editor_mode_v032 == EDITOR_MOVE_042 and structure_mode:
			mode_hint_v032.text = "STRUCTURE movement • entire connected construction"


func _toggle_transform_space_v051() -> void:
	super._toggle_transform_space_v051()
	_update_transform_ui_v051()
	_status("Transform: %s" % ("ITEM — only physically valid local motion" if transform_space_v051 == SPACE_ITEM_051 else "STRUCTURE — the entire connected construction transforms together"))


# -----------------------------------------------------------------------------
# Reset rotation means ZERO now.
# - STRUCTURE: rigidly rotate the entire connected island so the selected piece
#   has Basis.IDENTITY (zero world rotation).
# - free ITEM: zero that item itself.
# - mounted ITEM: restore the canonical zero-roll state allowed by that physical
#   socket/cross/axle connection, preserving fixed attachments on its side.
# -----------------------------------------------------------------------------

func _canonical_mount_transform_v056(mobility: Dictionary) -> Dictionary:
	if not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a connector"}
	var kind: String = str(mobility.get("kind", ""))
	var record: Dictionary = mobility.get("record", {}) as Dictionary
	var rod: RigidBody3D = record.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return {"valid": false, "reason": "mount rod is missing"}
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var target: Transform3D = selected_piece.global_transform

	if kind == "socket":
		var slot: int = int(record.get("slot", -1))
		var rod_end: int = int(record.get("rod_end", 0))
		if slot < 0 or rod_end == 0:
			return {"valid": false, "reason": "socket mount metadata is incomplete"}
		var outward: Vector3 = axis * float(rod_end)
		var desired_socket_dir: Vector3 = -outward
		target.basis = _basis_align_direction_v020(_slot_dir(slot), desired_socket_dir, Vector3.UP)
		# Socket connector centers sit on the rod axis, so zeroing roll leaves
		# origin unchanged.
		return {"valid": true, "transform": target}

	if kind == "axle":
		target.basis = _basis_for_axle_v020(axis)
		return {"valid": true, "transform": target}

	if kind == "cross":
		var cross_slot: int = int(record.get("slot", -1))
		if cross_slot < 0:
			return {"valid": false, "reason": "cross mount metadata is incomplete"}
		var radial: Vector3 = _world_perpendicular_v035(axis)
		target.basis = _basis_for_cross_v020(_slot_dir(cross_slot), axis, radial)
		var anchor: Vector3 = _record_anchor_v020(record)
		var actual_radial: Vector3 = (target.basis * _slot_dir(cross_slot)).normalized()
		target.origin = anchor - actual_radial * CONNECTOR_D
		return {"valid": true, "transform": target}

	return {"valid": false, "reason": "this mount has no independent zero rotation"}


func _reset_rotation_v020() -> void:
	if simulating or not is_instance_valid(selected_piece) or _selected_kind() != "connector":
		_status("Reset Rotation — select a connector in BUILD/ROTATE mode")
		return

	if transform_space_v051 == SPACE_WORLD_051:
		var structure: Array = _connected_island_v037(selected_piece)
		if structure.is_empty():
			structure = [selected_piece]
		var current: Transform3D = selected_piece.global_transform
		var target := Transform3D(Basis.IDENTITY, current.origin)
		var transforms: Dictionary = _rigid_delta_map_v020(structure, current, target)
		_apply_transform_map_v020(transforms, "STRUCTURE rotation reset — selected connector is now 0° / 0° / 0°")
		_refresh_gizmo_validity_v030()
		return

	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	if kind == "free":
		var free_current: Transform3D = selected_piece.global_transform
		var free_target := Transform3D(Basis.IDENTITY, free_current.origin)
		_apply_transform_map_v020(_rigid_delta_map_v020([selected_piece], free_current, free_target), "ITEM rotation reset to exact 0° / 0° / 0°")
		_refresh_gizmo_validity_v030()
		return

	if kind not in ["socket", "cross", "axle"]:
		_status("ITEM reset blocked — multiple rigid connections lock this connector. Switch to STRUCTURE to zero the whole connected construction.")
		return

	var component: Array = _rotation_component_v054(mobility)
	if component.is_empty():
		_status("ITEM reset blocked — another rigid path locks this connector. Use STRUCTURE to zero the connected construction.")
		return
	var canonical: Dictionary = _canonical_mount_transform_v056(mobility)
	if not bool(canonical.get("valid", false)):
		_status("ITEM reset blocked — %s" % str(canonical.get("reason", "no valid zero state")))
		return
	var target_transform: Transform3D = canonical.get("transform") as Transform3D
	var transforms: Dictionary = _rigid_delta_map_v020(component, selected_piece.global_transform, target_transform)
	var excluded_uid: int = int((mobility.get("record", {}) as Dictionary).get("uid", -1))
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		_status("ITEM reset blocked — %s" % str(validation.get("reason", "another connection prevents zero roll")))
		return
	_apply_transform_map_v020(transforms, "ITEM mount rotation reset to its physical zero state")
	_refresh_gizmo_validity_v030()


# -----------------------------------------------------------------------------
# Gizmo validity must use the selected connection axis immediately, not one frame
# later. This removes the gray-first/green-after-first-rotation artifact.
# -----------------------------------------------------------------------------

func _sync_gizmo_axes_v056() -> void:
	if gizmo_root_v030 == null or not is_instance_valid(selected_piece):
		return
	var mobility: Dictionary = _mobility_v054()
	var kind: String = str(mobility.get("kind", "none"))
	var item_mode: bool = transform_space_v051 == SPACE_ITEM_051
	var constrained: bool = item_mode and kind in ["socket", "cross", "axle"]
	var basis: Basis = Basis.IDENTITY
	if item_mode:
		basis = _item_basis_for_axis_v051(mobility.get("axis", Vector3.UP) as Vector3) if constrained else selected_piece.global_transform.basis.orthonormalized()
	gizmo_root_v030.global_basis = basis if item_mode else Basis.IDENTITY
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = gizmo_axes_v030.get(name_value, {}) as Dictionary
		if data.is_empty():
			continue
		var local_axis: Vector3 = Vector3.RIGHT if name_value == "X" else (Vector3.UP if name_value == "Y" else Vector3.BACK)
		data["axis"] = (basis * local_axis).normalized() if item_mode else local_axis
		var ring: MeshInstance3D = data.get("ring") as MeshInstance3D
		var plus: Label3D = data.get("plus") as Label3D
		var minus: Label3D = data.get("minus") as Label3D
		var show_axis: bool = not item_mode or kind == "free" or (constrained and name_value == "Y")
		if is_instance_valid(ring):
			ring.visible = show_axis
		if is_instance_valid(plus):
			plus.visible = show_axis
		if is_instance_valid(minus):
			minus.visible = show_axis


func _refresh_gizmo_validity_v030() -> void:
	_sync_gizmo_axes_v056()
	super._refresh_gizmo_validity_v030()


# -----------------------------------------------------------------------------
# Occupied endpoint editing and rigid-loop closure.
# -----------------------------------------------------------------------------

func _occupied_socket_as_rod_end_v056(point: Dictionary) -> Dictionary:
	if attach_mode != 0 or str(point.get("type", "")) not in ["socket", "rod_end"]:
		return point
	var record: Dictionary = _connection_record_for_point_v032(point)
	if record.is_empty() or str(record.get("kind", "")) != "socket":
		return point
	var rod: RigidBody3D = record.get("rod") as RigidBody3D
	var sign_value: int = int(record.get("rod_end", 0))
	if not is_instance_valid(rod) or sign_value == 0:
		return point
	return {"type": "rod_end", "body": rod, "sign": sign_value, "point": _rod_end_v020(rod, sign_value)}


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	var point: Dictionary = super._pick_initial_attach_point_v035(screen_pos)
	return _occupied_socket_as_rod_end_v056(point)


func _finish_explicit_connection_v056(source: Dictionary, target: Dictionary, old_record: Dictionary, in_place: bool) -> bool:
	var source_body: RigidBody3D = source.get("body") as RigidBody3D
	var target_body: RigidBody3D = target.get("body") as RigidBody3D
	if not old_record.is_empty():
		_detach_record_raw_v032(old_record)
	_create_explicit_connection_v030(source, target)
	manual_detach_blocks_v030.erase(_pair_key_v030(source_body, target_body))
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	var mode_name: String = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	_status("%s %s%s" % [mode_name, "re-attached" if not old_record.is_empty() else "attached", " in place" if in_place else ""])
	return true


func _connect_points_v035(source: Dictionary, target: Dictionary) -> bool:
	var source_body: RigidBody3D = source.get("body") as RigidBody3D
	var target_body: RigidBody3D = target.get("body") as RigidBody3D
	if not is_instance_valid(source_body) or not is_instance_valid(target_body) or source_body == target_body:
		_status("Connection blocked — choose two different pieces")
		return false

	_rebuild_connection_graph_v020()
	var source_record: Dictionary = _connection_record_for_point_v032(source)
	var target_record: Dictionary = _connection_record_for_point_v032(target)
	# The source point owns the connection being moved. Do NOT infer some other
	# existing edge merely because these two pieces happen to be linked elsewhere.
	var old_record: Dictionary = source_record

	if not target_record.is_empty() and not _same_record_v035(target_record, old_record):
		_status("Target is already occupied by another connection")
		return false

	if not source_record.is_empty() and _same_record_v035(source_record, target_record):
		var desired_kind: String = "socket" if attach_mode == 0 else ("cross" if attach_mode == 2 else ("o_ring" if str(source.get("type", "")) == "o_ring" or str(target.get("type", "")) == "o_ring" else "axle"))
		if str(source_record.get("kind", "")) == desired_kind:
			_status("Those exact attachment points are already connected")
			return false

	var excluded_uid: int = int(old_record.get("uid", -1)) if not old_record.is_empty() else -1
	var source_component: Array = _fixed_component_v020(source_body, excluded_uid)
	if source_component.is_empty():
		source_component = [source_body]

	if _component_has_piece_v020(source_component, target_body):
		# A second rigid path means nothing can move relative to the target without
		# breaking that path. But if the requested points are ALREADY geometrically
		# aligned, no movement is required: closing/reseating that loop is valid.
		var current_geometry: Dictionary = _current_attach_geometry_v030(source, target)
		if bool(current_geometry.get("valid", false)):
			return _finish_explicit_connection_v056(source, target, old_record, true)
		_status("Connection blocked — these pieces are rigidly linked elsewhere and these new points are not aligned. Disconnect the link you want to move, or use STRUCTURE to align the build first.")
		return false

	var snap: Dictionary = _snap_source_component_v030(source, target, source_component)
	if not bool(snap.get("valid", false)):
		_status("Connection blocked — %s" % str(snap.get("reason", "cannot align those points")))
		return false
	var transforms: Dictionary = snap.get("transforms", {}) as Dictionary
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		_status("Connection blocked — %s" % str(validation.get("reason", "moving that side would break another connection")))
		return false

	if not old_record.is_empty():
		_detach_record_raw_v032(old_record)
	_apply_transforms_raw_v030(transforms)
	_create_explicit_connection_v030(source, target)
	manual_detach_blocks_v030.erase(_pair_key_v030(source_body, target_body))
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	_status("%s %s — source connection moved with its attached component" % [["SOCKET", "AXLE", "CROSS"][attach_mode], "re-attached" if not old_record.is_empty() else "attached"])
	return true


# -----------------------------------------------------------------------------
# Auto-connect must permit an additional free rod-end/free-socket link between
# pieces already connected elsewhere. The old fixed-pair early-out prevented
# exact closed-loop geometry from ever becoming a real joint.
# -----------------------------------------------------------------------------

func _best_socket_for_end_v020(rod: RigidBody3D, sign_value: int) -> Dictionary:
	var rod_occ: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	if rod_occ.has(sign_value):
		return {}
	var end_point: Vector3 = _rod_end_v020(rod, sign_value)
	var outward: Vector3 = _rod_axis_v020(rod) * float(sign_value)
	var best: Dictionary = {}
	var best_distance: float = AUTO_SOCKET_CAPTURE_V056
	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		if manual_detach_blocks_v030.has(_pair_key_v030(rod, connector)):
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
			if socket_dir.dot(-outward) < AUTO_SOCKET_ALIGN_V056:
				continue
			var distance: float = (socket.get("point", connector.global_position) as Vector3).distance_to(end_point)
			if distance <= best_distance:
				best_distance = distance
				best = {"connector": connector, "slot": slot, "distance": distance, "point": socket["point"], "rod_point": end_point}
	return best


# -----------------------------------------------------------------------------
# Selection outline must recurse into 11/14-point spatial socket/arc assemblies.
# -----------------------------------------------------------------------------

func _collect_selection_meshes_v056(node: Node, result: Array) -> void:
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null or str(child.name) == "SelectionHighlight":
			continue
		if child is MeshInstance3D:
			var mesh_source: MeshInstance3D = child as MeshInstance3D
			if mesh_source.mesh != null and mesh_source.visible:
				result.append(mesh_source)
		_collect_selection_meshes_v056(child, result)


func _refresh_selection_highlight() -> void:
	_clear_selection_highlight()
	if not edit_mode or not is_instance_valid(selected_piece):
		return
	var body: RigidBody3D = selected_piece
	var highlight := Node3D.new()
	highlight.name = "SelectionHighlight"
	highlighted_body = body
	body.add_child(highlight)
	var meshes: Array = []
	_collect_selection_meshes_v056(body, meshes)
	var body_inverse: Transform3D = body.global_transform.affine_inverse()
	for mesh_value in meshes:
		var source: MeshInstance3D = mesh_value as MeshInstance3D
		if not is_instance_valid(source) or source.mesh == null:
			continue
		var outline := MeshInstance3D.new()
		outline.mesh = source.mesh
		outline.transform = body_inverse * source.global_transform
		outline.scale = outline.scale * 1.13
		outline.material_override = _selection_mat()
		highlight.add_child(outline)


func _update_ui() -> void:
	super._update_ui()
	_update_transform_ui_v051()
	if reset_rotation_v035 != null:
		reset_rotation_v035.text = "Reset Placement Rotation"


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nMENUS: drag/pull directly on Options, Parts, Saves, Help, Physics, Rotate or Move to scroll. The tiny scrollbar is optional. A real swipe is consumed before buttons/world input. Modal menus block every control outside their panel, even across higher CanvasLayers.\n\nSELECT: when Select is armed, CREATE placement is disabled until a piece is selected or Select is cancelled.\n\nROTATE: ITEM uses only physically valid local/mount axes. STRUCTURE rotates the whole connected construction. Reset Placement Rotation zeros STRUCTURE to world 0/0/0; a free ITEM also zeros exactly; a mounted ITEM resets to its canonical physical zero-roll state.\n\nATTACH: tapping an occupied SOCKET connection is normalized to its rod end, so an already-attached end can be moved to another free socket. A free connector point no longer steals an unrelated existing pair connection. Already-rigid loops may close/reseat when the new points are already aligned.\n\nAUTO-ATTACH: an exactly aligned free rod end and free socket may connect even when those two pieces already have another rigid link; explicit disconnect blocks are still respected.\n\n11/14 CONNECTORS: spatial top/bottom jaw and arc meshes participate in the recursive selected-piece glow.\n\nCAMERA: one finger orbits, two fingers pan/zoom." % VERSION_056
