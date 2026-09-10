extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.18"
const LEGACY_AXLE_ALIGN_V074 := 0.985
const LEGACY_AXLE_RADIAL_V074 := 0.18
const LEGACY_AXLE_END_MARGIN_V074 := 0.28
const CROSS_ROD_END_MARGIN_V074 := 0.42
const CROSS_SLIDE_GIZMO_OFFSET_V074 := 0.72

var legacy_axle_geometry_repairs_v074: int = 0
var cross_slide_drag_v074: bool = false
var cross_slide_connection_uid_v074: int = -1
var cross_slide_start_host_along_v074: float = 0.0
var cross_slide_target_host_along_v074: float = 0.0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_074)
	_status("v0.5.18 ready — legacy AXLE repair and midpoint CROSS rod insertion are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_074, text]


# -----------------------------------------------------------------------------
# Stable save healing.
# -----------------------------------------------------------------------------

func _capture_state() -> Dictionary:
	var snapshot: Dictionary = super._capture_state()
	# Rebuild the canonical v0.5.17+ AXLE table from the authoritative connection
	# graph, not from joint names. This guarantees that AXLEs recovered from an old
	# broken save become permanently explicit the next time the user saves.
	_rebuild_connection_graph_v020()
	var saved_axles: Array = []
	var seen_pairs: Dictionary = {}
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		var joint := record.get("joint") as Joint3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var connector_uid: int = _ensure_piece_uid_v020(connector)
		var rod_uid: int = _ensure_piece_uid_v020(rod)
		var pair_key := "%d:%d" % [connector_uid, rod_uid]
		if seen_pairs.has(pair_key):
			continue
		seen_pairs[pair_key] = true
		var axis := _rod_axis_v020(rod).normalized()
		var derived_along := (connector.global_position - rod.global_position).dot(axis)
		saved_axles.append({
			"connector_uid": connector_uid,
			"rod_uid": rod_uid,
			"connection_uid": int(record.get("uid", joint.get_meta("connection_uid_v020", -1) if is_instance_valid(joint) else -1)),
			"host_along": float(record.get("host_along", joint.get_meta("host_along_v020", derived_along) if is_instance_valid(joint) else derived_along)),
			"rest_gap": float(record.get("rest_gap", joint.get_meta("rest_gap_v020", 0.0) if is_instance_valid(joint) else 0.0)),
			"rest_align": float(record.get("rest_align", joint.get_meta("rest_align_v020", 1.0) if is_instance_valid(joint) else 1.0)),
			"rest_perp": float(record.get("rest_perp", joint.get_meta("rest_perp_v020", 0.0) if is_instance_valid(joint) else 0.0)),
			"rest_plane": float(record.get("rest_plane", joint.get_meta("rest_plane_v020", 0.0) if is_instance_valid(joint) else 0.0)),
		})
	snapshot["v072_axles"] = saved_axles
	return snapshot


# -----------------------------------------------------------------------------
# Legacy AXLE repair. Some v0.5.16-and-earlier saves have already lost AXLE
# identity and contain the hub/shaft pair as a false fixed/socket constraint.
# -----------------------------------------------------------------------------

func _legacy_axle_geometry_score_v074(connector: RigidBody3D, rod: RigidBody3D) -> float:
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return INF
	if str(connector.get_meta("kind", "")) != "connector" or str(rod.get_meta("kind", "")) != "rod":
		return INF
	var rod_axis: Vector3 = _rod_axis_v020(rod).normalized()
	var hub_axis: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
	var alignment: float = absf(rod_axis.dot(hub_axis))
	if alignment < LEGACY_AXLE_ALIGN_V074:
		return INF
	var delta: Vector3 = connector.global_position - rod.global_position
	var along: float = delta.dot(rod_axis)
	var radial: float = (delta - rod_axis * along).length()
	if radial > LEGACY_AXLE_RADIAL_V074:
		return INF
	var half_len: float = float(rod.get_meta("visual_length", 0.0)) * 0.5
	if half_len <= 0.0 or absf(along) > half_len + LEGACY_AXLE_END_MARGIN_V074:
		return INF
	return radial * 12.0 + (1.0 - alignment) * 5.0


func _direct_non_axle_joints_v074(connector: RigidBody3D, rod: RigidBody3D) -> Array:
	var result: Array = []
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes.size() < 2:
			continue
		if (nodes[0] == connector and nodes[1] == rod) or (nodes[0] == rod and nodes[1] == connector):
			result.append(joint)
	return result


func _remove_joint_node_v074(joint: Joint3D) -> void:
	if not is_instance_valid(joint):
		return
	joint.node_a = NodePath()
	joint.node_b = NodePath()
	joints.erase(joint)
	joint.queue_free()


func _legacy_connector_has_rigid_context_v074(connector: RigidBody3D, candidate_rod: RigidBody3D) -> bool:
	if not _direct_non_axle_joints_v074(connector, candidate_rod).is_empty():
		return true
	return _fixed_component_for_axle_v072(connector).size() > 1


func _recover_legacy_axles_from_geometry_v074(snapshot: Dictionary) -> int:
	# Never infer for a modern save. Geometry is only the migration fallback for an
	# older snapshot which has no canonical stable-UID AXLE table at all.
	if snapshot.has("v072_axles"):
		return 0

	_rebuild_connection_graph_v020()
	var repaired: int = 0
	for body_value in bodies:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		if _connector_has_live_axle_v072(connector):
			continue

		var best_rod: RigidBody3D = null
		var best_score: float = INF
		for rod_value in bodies:
			var rod := rod_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			var score: float = _legacy_axle_geometry_score_v074(connector, rod)
			if score < best_score:
				best_score = score
				best_rod = rod

		if not is_instance_valid(best_rod) or best_score == INF:
			continue
		if not _legacy_connector_has_rigid_context_v074(connector, best_rod):
			continue

		var false_joints: Array = _direct_non_axle_joints_v074(connector, best_rod)
		var old_primary_uid: int = int(connector.get_meta("primary_connection_uid_v020", -1))
		var removed_primary: bool = false
		for false_joint_value in false_joints:
			var false_joint := false_joint_value as Joint3D
			if is_instance_valid(false_joint) and int(false_joint.get_meta("connection_uid_v020", -2)) == old_primary_uid:
				removed_primary = true
			_remove_joint_node_v074(false_joint)

		var axis: Vector3 = _rod_axis_v020(best_rod).normalized()
		var along: float = (connector.global_position - best_rod.global_position).dot(axis)
		var axle_joint: Generic6DOFJoint3D = _make_axle_joint(connector, best_rod)
		var make_primary: bool = removed_primary or old_primary_uid < 0
		var axle_uid: int = _tag_connection_v020(axle_joint, "axle", connector, best_rod, -1, 0, along, null, make_primary)
		connector.set_meta("axle_occupied", true)
		connector.set_meta("axle_host_rod", best_rod)
		if make_primary:
			connector.set_meta("primary_connection_uid_v020", axle_uid)
		_canonicalize_axle_joint_v072(axle_joint, connector)
		repaired += 1

	if repaired > 0:
		_rebuild_connection_graph_v020()
		_recalculate_occupancy_from_joints()
		_rebuild_connection_graph_v020()
		for record_value in connections_v020:
			var record := record_value as Dictionary
			if str(record.get("kind", "")) != "axle":
				continue
			var connector := record.get("connector") as RigidBody3D
			var rod := record.get("rod") as RigidBody3D
			if is_instance_valid(connector) and is_instance_valid(rod):
				connector.set_meta("axle_occupied", true)
				connector.set_meta("axle_host_rod", rod)
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
	return repaired


func _restore_state(snapshot: Dictionary) -> void:
	super._restore_state(snapshot)
	legacy_axle_geometry_repairs_v074 = _recover_legacy_axles_from_geometry_v074(snapshot)
	if legacy_axle_geometry_repairs_v074 > 0:
		_canonicalize_all_axles_v072()
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
		_recalculate_occupancy_from_joints()
		_rebuild_connection_graph_v020()
		print("LEGACY_AXLE_GEOMETRY_REPAIR_074: recovered %d AXLE connection(s) and removed their false fixed/socket records" % legacy_axle_geometry_repairs_v074)


# -----------------------------------------------------------------------------
# CREATE + CROSS: inverse CROSS placement.
#
# Existing behavior lets the user tap a rod and place a connector crosswise onto
# it. The inverse operation now works too: with CROSS selected, tap a free socket
# on an existing connector and the currently selected rod is clipped into that
# socket at the rod midpoint. It is one ordinary CROSS connection, not SOCKET.
# The rod follows the connector face normal, matching the existing CROSS geometry.
# -----------------------------------------------------------------------------

func _cross_rod_axis_for_socket_v074(connector: RigidBody3D, _slot: int) -> Vector3:
	if not is_instance_valid(connector):
		return Vector3.UP
	return (connector.global_transform.basis * Vector3.UP).normalized()


func _place_cross_rod_in_socket_v074(connector: RigidBody3D, slot: int) -> RigidBody3D:
	if not is_instance_valid(connector) or slot < 0:
		return null
	_rebuild_connection_graph_v020()
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	if occupied.has(slot):
		_status("CROSS: that connector socket is already occupied")
		return null
	var socket: Dictionary = _socket_world_v020(connector, slot)
	var midpoint: Vector3 = socket.get("point", connector.global_position) as Vector3
	var rod_axis: Vector3 = _cross_rod_axis_for_socket_v074(connector, slot)
	var length: float = float(rod_defs[selected_rod_type].get("actual_mm", 55.0)) / 10.0
	var half: Vector3 = rod_axis * (length * 0.5)
	var rod := _make_rod(selected_rod_type, midpoint - half, midpoint + half) as RigidBody3D
	if not is_instance_valid(rod):
		return null
	var joint := _make_fixed_joint(rod, connector, midpoint) as Generic6DOFJoint3D
	var connection_uid: int = _tag_connection_v020(joint, "cross", connector, rod, slot, 0, 0.0, null, false)
	joint.set_meta("cross_mount", true)
	joint.set_meta("cross_socket_rod_v074", true)
	rod.set_meta("cross_socket_rod_v074", true)
	rod.set_meta("cross_socket_connection_uid_v074", connection_uid)
	_set_connector_occupied(connector, slot, true)
	manual_detach_blocks_v030.erase(_pair_key_v030(connector, rod))
	rod.set_meta("build_transform", rod.global_transform)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_set_selected(rod)
	_commit_state()
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_update_ui()
	_status("CROSS rod inserted through socket at its midpoint — select MOVE to slide the rod through that socket")
	return rod


func _try_socket_create_tap_v054(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_CREATE_032 or simulating:
		return false
	if attach_mode == 0:
		return super._try_socket_create_tap_v054(screen_pos)
	if attach_mode != 2:
		return false
	var connector: RigidBody3D = _raycast_connector_v070(screen_pos)
	if not is_instance_valid(connector):
		return false
	var candidate: Dictionary = _pick_socket_on_connector_v070(connector, screen_pos, SOCKET_JAW_PICK_RADIUS_V070, true)
	if candidate.is_empty():
		return false
	_place_cross_rod_in_socket_v074(connector, int(candidate.get("slot", -1)))
	return true


# -----------------------------------------------------------------------------
# MOVE: a rod whose only fixed graph edge is one CROSS socket can slide through
# that socket in BUILD. The ordinary XYZ gizmo becomes one axis parallel to the
# rod and is drawn just beside it. The CROSS joint stays fixed in SIMULATE.
# -----------------------------------------------------------------------------

func _cross_slide_record_v074(rod: RigidBody3D) -> Dictionary:
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		return {}
	var records: Array = _connections_for_piece_v020(rod)
	if records.size() != 1:
		return {}
	var record := records[0] as Dictionary
	if str(record.get("kind", "")) != "cross" or record.get("rod") != rod:
		return {}
	var connector := record.get("connector") as RigidBody3D
	var joint := record.get("joint") as Joint3D
	if not is_instance_valid(connector) or not is_instance_valid(joint):
		return {}
	return record


func _connection_by_uid_v074(uid_value: int) -> Dictionary:
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if int(record.get("uid", -1)) == uid_value:
			return record
	return {}


func _set_move_axis_label_v074(axis_root: Node3D, text_value: String) -> void:
	if axis_root == null:
		return
	for child_value in axis_root.get_children():
		if child_value is Label3D:
			(child_value as Label3D).text = text_value


func _process(delta: float) -> void:
	super._process(delta)
	if move_gizmo_root_v042 == null:
		return
	var special: Dictionary = _cross_slide_record_v074(selected_piece as RigidBody3D) if is_instance_valid(selected_piece) else {}
	var x_data := move_gizmo_axes_v042.get("X", {}) as Dictionary
	var y_data := move_gizmo_axes_v042.get("Y", {}) as Dictionary
	var z_data := move_gizmo_axes_v042.get("Z", {}) as Dictionary
	var x_root := x_data.get("root") as Node3D
	var y_root := y_data.get("root") as Node3D
	var z_root := z_data.get("root") as Node3D
	if special.is_empty() or editor_mode_v032 != EDITOR_MOVE_042 or not move_gizmo_root_v042.visible:
		if x_root != null:
			x_root.visible = true
		if z_root != null:
			z_root.visible = true
		if y_root != null:
			y_root.visible = true
			y_root.basis = Basis.IDENTITY
			_set_move_axis_label_v074(y_root, "Y")
		return

	var rod := special.get("rod") as RigidBody3D
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	if x_root != null:
		x_root.visible = false
	if z_root != null:
		z_root.visible = false
	if y_root != null:
		y_root.visible = true
		y_root.basis = Basis(Quaternion(Vector3.UP, axis))
		_set_move_axis_label_v074(y_root, "SLIDE")
	var view: Vector3 = camera.global_position - rod.global_position
	var side: Vector3 = axis.cross(view)
	if side.length_squared() < 0.02:
		side = _stable_perpendicular_v030(axis)
	else:
		side = side.normalized()
	var scale_value: float = move_gizmo_root_v042.scale.x
	move_gizmo_root_v042.global_position = rod.global_position + side * CROSS_SLIDE_GIZMO_OFFSET_V074 * scale_value


func _update_ui() -> void:
	super._update_ui()
	var special: Dictionary = _cross_slide_record_v074(selected_piece as RigidBody3D) if is_instance_valid(selected_piece) else {}
	if special.is_empty() or editor_mode_v032 != EDITOR_MOVE_042:
		return
	# WORLD XYZ movement would drag the fixed connector with the rod. For this one
	# topology the intended edit is only sliding through the CROSS jaw, so use the
	# single on-rod gizmo and disable the unrelated world-step buttons.
	for button_value in [move_x_minus_v042, move_x_plus_v042, move_y_minus_v042, move_y_plus_v042, move_z_minus_v042, move_z_plus_v042]:
		var button := button_value as Button
		if button != null:
			button.disabled = true


func _pick_move_axis_v042(screen_pos: Vector2) -> Dictionary:
	var special: Dictionary = _cross_slide_record_v074(selected_piece as RigidBody3D) if is_instance_valid(selected_piece) else {}
	if special.is_empty():
		return super._pick_move_axis_v042(screen_pos)
	if move_gizmo_root_v042 == null or not move_gizmo_root_v042.visible or camera == null:
		return {}
	var rod := special.get("rod") as RigidBody3D
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var center: Vector3 = move_gizmo_root_v042.global_position
	var scale_value: float = move_gizmo_root_v042.scale.x
	var positive: Vector3 = center + axis * MOVE_GIZMO_LENGTH_042 * scale_value
	var negative: Vector3 = center - axis * MOVE_GIZMO_LENGTH_042 * scale_value
	if camera.is_position_behind(positive) or camera.is_position_behind(negative):
		return {}
	var screen_positive: Vector2 = camera.unproject_position(positive)
	var screen_negative: Vector2 = camera.unproject_position(negative)
	var screen_axis: Vector2 = screen_positive - screen_negative
	if screen_axis.length() < 28.0:
		return {}
	var distance: float = _screen_segment_distance_v070(screen_pos, negative, positive)
	if distance > MOVE_GIZMO_PICK_PX_042:
		return {}
	return {"name": "SLIDE", "axis": axis, "screen_dir": screen_axis.normalized()}


func _begin_move_drag_v042(screen_pos: Vector2) -> bool:
	var special: Dictionary = _cross_slide_record_v074(selected_piece as RigidBody3D) if is_instance_valid(selected_piece) else {}
	if special.is_empty():
		return super._begin_move_drag_v042(screen_pos)
	if editor_mode_v032 != EDITOR_MOVE_042 or simulating:
		return false
	var picked: Dictionary = _pick_move_axis_v042(screen_pos)
	if picked.is_empty():
		return false
	var rod := special.get("rod") as RigidBody3D
	move_drag_active_v042 = true
	cross_slide_drag_v074 = true
	cross_slide_connection_uid_v074 = int(special.get("uid", -1))
	cross_slide_start_host_along_v074 = float(special.get("host_along", 0.0))
	cross_slide_target_host_along_v074 = cross_slide_start_host_along_v074
	move_drag_axis_name_v042 = "SLIDE"
	move_drag_axis_v042 = picked.get("axis", Vector3.UP) as Vector3
	move_drag_screen_dir_v042 = picked.get("screen_dir", Vector2.UP) as Vector2
	move_drag_start_screen_v042 = screen_pos
	move_drag_steps_v042 = 0
	move_drag_component_v042 = [rod]
	move_drag_preview_v042 = {"valid": true, "transforms": {}}
	_build_rotation_ghost_v030([rod])
	_status("CROSS rod slide selected — drag along the rod; %.2f-unit snap" % MOVE_STEP_042)
	return true


func _update_move_drag_v042(screen_pos: Vector2) -> void:
	if not cross_slide_drag_v074:
		super._update_move_drag_v042(screen_pos)
		return
	if not move_drag_active_v042 or not is_instance_valid(selected_piece):
		return
	var rod := selected_piece as RigidBody3D
	var projected: float = (screen_pos - move_drag_start_screen_v042).dot(move_drag_screen_dir_v042)
	var steps: int = clampi(int(round(projected / MOVE_GIZMO_STEP_PX_042)), -80, 80)
	if steps == move_drag_steps_v042:
		return
	move_drag_steps_v042 = steps
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - CROSS_ROD_END_MARGIN_V074)
	var wanted_delta: float = MOVE_STEP_042 * float(steps)
	var target_host: float = clampf(cross_slide_start_host_along_v074 - wanted_delta, -half_len, half_len)
	var actual_delta: float = cross_slide_start_host_along_v074 - target_host
	cross_slide_target_host_along_v074 = target_host
	var transforms: Dictionary = _translation_map_v042([rod], move_drag_axis_v042 * actual_delta)
	move_drag_preview_v042 = {"valid": true, "transforms": transforms, "delta": actual_delta}
	_update_rotation_ghost_v030(transforms, true)
	_status("CROSS rod slide preview: %.2f" % actual_delta)


func _finish_move_drag_v042() -> void:
	if not cross_slide_drag_v074:
		super._finish_move_drag_v042()
		return
	var rod := selected_piece as RigidBody3D
	var connection_uid: int = cross_slide_connection_uid_v074
	var target_host: float = cross_slide_target_host_along_v074
	var preview: Dictionary = move_drag_preview_v042.duplicate(true)
	cross_slide_drag_v074 = false
	cross_slide_connection_uid_v074 = -1
	move_drag_active_v042 = false
	move_drag_steps_v042 = 0
	move_drag_component_v042 = []
	move_drag_preview_v042 = {}
	_clear_rotation_ghost_v030()
	if not is_instance_valid(rod) or preview.is_empty():
		_status("CROSS rod slide unchanged")
		return
	var transforms := preview.get("transforms", {}) as Dictionary
	if not transforms.has(rod.get_instance_id()):
		_status("CROSS rod slide unchanged")
		return
	var delta_value: float = float(preview.get("delta", 0.0))
	if absf(delta_value) < 0.0001:
		_status("CROSS rod slide unchanged")
		return
	var record: Dictionary = _connection_by_uid_v074(connection_uid)
	if record.is_empty():
		_status("CROSS rod slide cancelled — mount record is missing")
		return
	var connector := record.get("connector") as RigidBody3D
	var joint := record.get("joint") as Joint3D
	var slot: int = int(record.get("slot", -1))
	if not is_instance_valid(connector) or not is_instance_valid(joint) or slot < 0:
		_status("CROSS rod slide cancelled — mount is incomplete")
		return

	rod.global_transform = transforms[rod.get_instance_id()] as Transform3D
	rod.set_meta("build_transform", rod.global_transform)
	joint.set_meta("host_along_v020", target_host)
	var socket: Dictionary = _socket_world_v020(connector, slot)
	var joint_tf: Transform3D = joint.global_transform
	joint_tf.origin = socket.get("point", joint.global_position) as Vector3
	joint.global_transform = joint_tf
	_measure_connection_rest_v020(joint, "cross", connector, rod, slot, 0, target_host, null)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_update_ui()
	_status("Slid CROSS rod %.2f through its socket" % delta_value)