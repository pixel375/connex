extends "res://scripts/main_v058.gd"

const VERSION_059 := "0.5.5"

# Mathematical socket points sit inside the visible jaws. A phone user can have
# two parts that are visibly touching while the internal endpoint points are still
# more than the old 2.0-unit capture radius apart. Use a wider candidate shell,
# but keep direction/lateral scoring so dense hubs still choose the intended port.
const AUTO_SOCKET_CAPTURE_V059 := 3.50
const AUTO_SOCKET_NEAR_V059 := 1.30
const AUTO_SOCKET_ALIGN_NEAR_V059 := -0.20
const AUTO_SOCKET_ALIGN_FAR_V059 := 0.10
const AUTO_SOCKET_LATERAL_MAX_V059 := 1.75

# Position/orientation projection used after a loop-closing auto attachment.
# Existing builds used fixed-joint rest frames even when the visible endpoints
# were not coincident. The legacy simulation then suppresses redundant cycle
# joints, exposing those stored gaps. v0.5.5 projects all recorded attachment
# points into a geometrically closed build pose before those redundant solver
# constraints are suppressed.
const SNAP_RELAX_PASSES_V059 := 28
const SNAP_POSITION_STRENGTH_V059 := 0.64
const SNAP_PRIORITY_STRENGTH_V059 := 0.92
const SNAP_POSITION_MAX_STEP_V059 := 0.72
const SNAP_ALIGN_FRACTION_V059 := 0.42
const SNAP_ALIGN_MAX_STEP_V059 := 0.13
const SNAP_GAP_EPS_V059 := 0.018

var auto_snap_priority_uids_v059: Dictionary = {}
var snap_relax_running_v059: bool = false


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_059)
	_status("v0.5.5 active — queued geometry cannot enter highlights, and close-loop SOCKET connections are projected into a visibly closed build pose before physics.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_059, text]


# -----------------------------------------------------------------------------
# Selection-highlight rebuild correctness.
#
# The v0.5.4 fix removed the previous SelectionHighlight node, but the inherited
# planar connector rebuild still queue_free()'d old MeshInstance3D children.
# queue_free() leaves those children in the tree until the end of the frame, so
# the recursive v0.5.3 highlight collector immediately cloned them into the NEW
# highlight. That is the phantom cyan geometry visible after 14 -> 1/2/3/4-way.
#
# Fix both sides of the race:
# 1) physically detach old connector visual/collision children before rebuilding;
# 2) never clone a queued-for-deletion node into a highlight.
# -----------------------------------------------------------------------------

func _collect_selection_meshes_v056(node: Node, result: Array) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null or str(child.name) == "SelectionHighlight" or child.is_queued_for_deletion():
			continue
		if child is MeshInstance3D:
			var mesh_source: MeshInstance3D = child as MeshInstance3D
			if mesh_source.mesh != null and mesh_source.visible:
				result.append(mesh_source)
		_collect_selection_meshes_v056(child, result)


func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if not is_instance_valid(body):
		return
	# Remove the selection clone synchronously.
	var stale_highlight: Node = body.get_node_or_null("SelectionHighlight")
	if stale_highlight != null:
		body.remove_child(stale_highlight)
		stale_highlight.queue_free()
	if is_instance_valid(highlighted_body) and highlighted_body == body:
		highlighted_body = null

	# Crucial difference from v0.5.4: remove ALL old direct meshes/collisions and
	# spatial roots from the body before any inherited rebuild can queue them.
	_remove_connector_visuals_immediate_v054(body)
	super._rebuild_connector(body, def_index)


# -----------------------------------------------------------------------------
# Wider but still deterministic free-end -> free-socket candidate matching.
# -----------------------------------------------------------------------------

func _best_socket_for_end_v020(rod: RigidBody3D, sign_value: int) -> Dictionary:
	if not is_instance_valid(rod):
		return {}
	var rod_occ: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	if rod_occ.has(sign_value):
		return {}

	var end_point: Vector3 = _rod_end_v020(rod, sign_value)
	var outward: Vector3 = (_rod_axis_v020(rod) * float(sign_value)).normalized()
	if outward.length_squared() < 0.5:
		return {}
	var best: Dictionary = {}
	var best_score: float = INF

	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or connector == rod or str(connector.get_meta("kind", "")) != "connector":
			continue
		# Explicit Disconnect is still a hard no-snap instruction for that pair.
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
			var point: Vector3 = socket.get("point", connector.global_position) as Vector3
			var delta: Vector3 = point - end_point
			var distance: float = delta.length()
			if distance > AUTO_SOCKET_CAPTURE_V059:
				continue
			var socket_dir: Vector3 = (socket.get("dir", Vector3.ZERO) as Vector3).normalized()
			var alignment: float = socket_dir.dot(-outward)
			var min_alignment: float = AUTO_SOCKET_ALIGN_NEAR_V059 if distance <= AUTO_SOCKET_NEAR_V059 else AUTO_SOCKET_ALIGN_FAR_V059
			if alignment < min_alignment:
				continue
			var axial: float = delta.dot(outward)
			var lateral: float = (delta - outward * axial).length()
			if distance > AUTO_SOCKET_NEAR_V059 and lateral > AUTO_SOCKET_LATERAL_MAX_V059:
				continue
			# Distance is primary. Lateral miss and direction mismatch disambiguate
			# neighboring 45-degree ports on dense 8/11/14-point connectors.
			var score: float = distance + lateral * 0.52 + (1.0 - alignment) * 0.68
			if score < best_score:
				best_score = score
				best = {
					"connector": connector,
					"slot": slot,
					"distance": distance,
					"alignment": alignment,
					"lateral": lateral,
					"point": point,
					"rod_point": end_point,
				}
	return best


# -----------------------------------------------------------------------------
# Rigid-point geometry projection.
# -----------------------------------------------------------------------------

func _snap_body_locked_v059(body: RigidBody3D) -> bool:
	return not is_instance_valid(body) or bool(body.get_meta("root_piece_v020", false))


func _snap_translate_body_v059(body: RigidBody3D, delta: Vector3) -> void:
	if not is_instance_valid(body) or _snap_body_locked_v059(body):
		return
	if delta.length() > SNAP_POSITION_MAX_STEP_V059:
		delta = delta.normalized() * SNAP_POSITION_MAX_STEP_V059
	body.global_position += delta


func _snap_rotate_body_about_v059(body: RigidBody3D, pivot: Vector3, axis_value: Vector3, angle_value: float) -> void:
	if not is_instance_valid(body) or _snap_body_locked_v059(body):
		return
	if axis_value.length_squared() < 0.000001 or absf(angle_value) < 0.00001:
		return
	var angle: float = clampf(angle_value, -SNAP_ALIGN_MAX_STEP_V059, SNAP_ALIGN_MAX_STEP_V059)
	var axis: Vector3 = axis_value.normalized()
	var rotation_basis: Basis = Basis(axis, angle)
	var old_axis: Vector3 = _rod_axis_v020(body) if str(body.get_meta("kind", "")) == "rod" else Vector3.ZERO
	var transform_value: Transform3D = body.global_transform
	transform_value.origin = pivot + rotation_basis * (transform_value.origin - pivot)
	transform_value.basis = (rotation_basis * transform_value.basis).orthonormalized()
	body.global_transform = transform_value
	if str(body.get_meta("kind", "")) == "rod" and old_axis.length_squared() > 0.5:
		body.set_meta("axis", (rotation_basis * old_axis).normalized())


func _snap_constraint_v059(record: Dictionary) -> Dictionary:
	if record.is_empty():
		return {}
	var kind: String = str(record.get("kind", ""))
	var connector: RigidBody3D = record.get("connector") as RigidBody3D
	var rod: RigidBody3D = record.get("rod") as RigidBody3D
	var ring: RigidBody3D = record.get("ring") as RigidBody3D
	var host_along: float = float(record.get("host_along", 0.0))

	if kind == "socket":
		var slot: int = int(record.get("slot", -1))
		var rod_end: int = int(record.get("rod_end", 0))
		if not is_instance_valid(connector) or not is_instance_valid(rod) or slot < 0 or rod_end == 0:
			return {}
		var socket: Dictionary = _socket_world_v020(connector, slot)
		return {
			"kind": kind,
			"a": connector,
			"b": rod,
			"point_a": socket.get("point", connector.global_position) as Vector3,
			"point_b": _rod_end_v020(rod, rod_end),
			"slot": slot,
			"rod_end": rod_end,
		}

	if kind == "cross":
		var cross_slot: int = int(record.get("slot", -1))
		if not is_instance_valid(connector) or not is_instance_valid(rod) or cross_slot < 0:
			return {}
		var cross_socket: Dictionary = _socket_world_v020(connector, cross_slot)
		return {
			"kind": kind,
			"a": connector,
			"b": rod,
			"point_a": cross_socket.get("point", connector.global_position) as Vector3,
			"point_b": rod.global_position + _rod_axis_v020(rod).normalized() * host_along,
		}

	if kind == "axle":
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			return {}
		return {
			"kind": kind,
			"a": connector,
			"b": rod,
			"point_a": connector.global_position,
			"point_b": rod.global_position + _rod_axis_v020(rod).normalized() * host_along,
		}

	if kind == "o_ring":
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			return {}
		return {
			"kind": kind,
			"a": ring,
			"b": rod,
			"point_a": ring.global_position,
			"point_b": rod.global_position + _rod_axis_v020(rod).normalized() * host_along,
		}
	return {}


func _project_snap_position_v059(record: Dictionary, strength: float) -> float:
	var constraint: Dictionary = _snap_constraint_v059(record)
	if constraint.is_empty():
		return 0.0
	var a: RigidBody3D = constraint.get("a") as RigidBody3D
	var b: RigidBody3D = constraint.get("b") as RigidBody3D
	var point_a: Vector3 = constraint.get("point_a", Vector3.ZERO) as Vector3
	var point_b: Vector3 = constraint.get("point_b", Vector3.ZERO) as Vector3
	var error: Vector3 = point_b - point_a
	var gap: float = error.length()
	if gap <= SNAP_GAP_EPS_V059:
		return gap
	var a_locked: bool = _snap_body_locked_v059(a)
	var b_locked: bool = _snap_body_locked_v059(b)
	if a_locked and b_locked:
		return gap
	if a_locked:
		_snap_translate_body_v059(b, -error * strength)
	elif b_locked:
		_snap_translate_body_v059(a, error * strength)
	else:
		_snap_translate_body_v059(a, error * (0.5 * strength))
		_snap_translate_body_v059(b, -error * (0.5 * strength))
	return gap


func _project_socket_alignment_v059(record: Dictionary, strength: float) -> void:
	if str(record.get("kind", "")) != "socket":
		return
	var connector: RigidBody3D = record.get("connector") as RigidBody3D
	var rod: RigidBody3D = record.get("rod") as RigidBody3D
	var slot: int = int(record.get("slot", -1))
	var rod_end: int = int(record.get("rod_end", 0))
	if not is_instance_valid(connector) or not is_instance_valid(rod) or slot < 0 or rod_end == 0:
		return
	var socket: Dictionary = _socket_world_v020(connector, slot)
	var socket_point: Vector3 = socket.get("point", connector.global_position) as Vector3
	var rod_point: Vector3 = _rod_end_v020(rod, rod_end)
	var pivot: Vector3 = (socket_point + rod_point) * 0.5
	var socket_dir: Vector3 = (socket.get("dir", Vector3.ZERO) as Vector3).normalized()
	var rod_out: Vector3 = (_rod_axis_v020(rod) * float(rod_end)).normalized()
	if socket_dir.length_squared() < 0.5 or rod_out.length_squared() < 0.5:
		return
	var desired_rod: Vector3 = -socket_dir
	var dot_value: float = clampf(rod_out.dot(desired_rod), -1.0, 1.0)
	if dot_value > 0.9996:
		return
	var angle: float = acos(dot_value)
	var rod_axis: Vector3 = rod_out.cross(desired_rod)
	if rod_axis.length_squared() < 0.000001:
		rod_axis = rod_out.cross(Vector3.UP)
		if rod_axis.length_squared() < 0.000001:
			rod_axis = rod_out.cross(Vector3.RIGHT)
	var connector_target: Vector3 = -rod_out
	var connector_axis: Vector3 = socket_dir.cross(connector_target)
	if connector_axis.length_squared() < 0.000001:
		connector_axis = rod_axis

	var a_locked: bool = _snap_body_locked_v059(connector)
	var b_locked: bool = _snap_body_locked_v059(rod)
	var fraction: float = SNAP_ALIGN_FRACTION_V059 * strength
	if a_locked and not b_locked:
		_snap_rotate_body_about_v059(rod, pivot, rod_axis, angle * fraction)
	elif b_locked and not a_locked:
		_snap_rotate_body_about_v059(connector, pivot, connector_axis, angle * fraction)
	elif not a_locked and not b_locked:
		_snap_rotate_body_about_v059(rod, pivot, rod_axis, angle * fraction * 0.5)
		_snap_rotate_body_about_v059(connector, pivot, connector_axis, angle * fraction * 0.5)


func _connection_gap_v059(record: Dictionary) -> float:
	var constraint: Dictionary = _snap_constraint_v059(record)
	if constraint.is_empty():
		return 0.0
	return (constraint.get("point_a", Vector3.ZERO) as Vector3).distance_to(constraint.get("point_b", Vector3.ZERO) as Vector3)


func _relax_connection_geometry_v059(passes: int = SNAP_RELAX_PASSES_V059) -> Dictionary:
	if snap_relax_running_v059 or restoring_state or restoring_v020:
		return {"max_gap": 0.0, "passes": 0}
	snap_relax_running_v059 = true
	_rebuild_connection_graph_v020()
	var pass_count: int = maxi(1, passes)
	var last_max_gap: float = 0.0

	for _pass in range(pass_count):
		last_max_gap = 0.0
		# Normal constraints first.
		for record_value in connections_v020:
			var record: Dictionary = record_value as Dictionary
			var uid: int = int(record.get("uid", -1))
			if auto_snap_priority_uids_v059.has(uid):
				continue
			last_max_gap = maxf(last_max_gap, _project_snap_position_v059(record, SNAP_POSITION_STRENGTH_V059))
			_project_socket_alignment_v059(record, SNAP_POSITION_STRENGTH_V059)

		# Newly auto-connected closures are processed last so the visible connection
		# itself cannot be left as the residual gap of a closed loop.
		for record_value in connections_v020:
			var record: Dictionary = record_value as Dictionary
			var uid: int = int(record.get("uid", -1))
			if not auto_snap_priority_uids_v059.has(uid):
				continue
			last_max_gap = maxf(last_max_gap, _project_snap_position_v059(record, SNAP_PRIORITY_STRENGTH_V059))
			_project_socket_alignment_v059(record, SNAP_PRIORITY_STRENGTH_V059)

		if last_max_gap <= SNAP_GAP_EPS_V059:
			break

	# One exact positional sweep for priority closures after iterative settling.
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		if auto_snap_priority_uids_v059.has(int(record.get("uid", -1))):
			_project_snap_position_v059(record, 1.0)

	_update_build_transforms_v059()
	_refresh_joint_frames_v020()
	_remeasure_connection_rest_v059()
	_rebuild_connection_graph_v020()

	var measured_max: float = 0.0
	for record_value in connections_v020:
		measured_max = maxf(measured_max, _connection_gap_v059(record_value as Dictionary))
	snap_relax_running_v059 = false
	return {"max_gap": measured_max, "passes": pass_count}


func _update_build_transforms_v059() -> void:
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			body.set_meta("build_transform", body.global_transform)
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.set_meta("build_transform", ring.global_transform)


func _remeasure_connection_rest_v059() -> void:
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var joint: Joint3D = record.get("joint") as Joint3D
		if not is_instance_valid(joint):
			continue
		for meta_name in ["rest_gap_v020", "rest_align_v020", "rest_perp_v020", "rest_plane_v020"]:
			if joint.has_meta(meta_name):
				joint.remove_meta(meta_name)
		_measure_connection_rest_v020(
			joint,
			str(record.get("kind", "")),
			record.get("connector") as RigidBody3D,
			record.get("rod") as RigidBody3D,
			int(record.get("slot", -1)),
			int(record.get("rod_end", 0)),
			float(record.get("host_along", 0.0)),
			record.get("ring") as RigidBody3D
		)


# -----------------------------------------------------------------------------
# Auto-connect and simulation preflight integration.
# -----------------------------------------------------------------------------

func _auto_connect_end_v020(rod: RigidBody3D, sign_value: int) -> bool:
	var target: Dictionary = _best_socket_for_end_v020(rod, sign_value)
	if target.is_empty():
		return false
	var connector: RigidBody3D = target.get("connector") as RigidBody3D
	if not is_instance_valid(connector):
		return false
	var slot: int = int(target.get("slot", -1))
	if slot < 0:
		return false

	# Separate islands can still be closed exactly with a rigid translation. For
	# same-island loop closures, create the new constraint first and let the PBD
	# projection distribute the small correction through the already-connected
	# construction rather than deliberately preserving a visible gap (v0.5.4).
	var rod_component: Array = _fixed_component_v020(rod, -1)
	var same_island: bool = _component_has_piece_v020(rod_component, connector)
	if not same_island:
		var connector_component: Array = _fixed_component_v020(connector, -1)
		var rod_end_before: Vector3 = _rod_end_v020(rod, sign_value)
		var socket_before: Vector3 = (_socket_world_v020(connector, slot).get("point", connector.global_position) as Vector3)
		var delta_to_socket: Vector3 = socket_before - rod_end_before
		var rod_rooted: bool = _component_has_root_v058(rod_component)
		var connector_rooted: bool = _component_has_root_v058(connector_component)
		if rod_rooted and not connector_rooted:
			_translate_component_v058(connector_component, -delta_to_socket)
		elif connector_rooted and not rod_rooted:
			_translate_component_v058(rod_component, delta_to_socket)
		elif connector_component.size() < rod_component.size():
			_translate_component_v058(connector_component, -delta_to_socket)
		else:
			_translate_component_v058(rod_component, delta_to_socket)
		_refresh_joint_frames_v020()

	var socket_now: Dictionary = _socket_world_v020(connector, slot)
	var rod_point_now: Vector3 = _rod_end_v020(rod, sign_value)
	var socket_point_now: Vector3 = socket_now.get("point", connector.global_position) as Vector3
	var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, (socket_point_now + rod_point_now) * 0.5)
	var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
	var uid: int = _tag_connection_v020(joint, "socket", connector, rod, slot, sign_value, 0.0, null, primary)
	auto_snap_priority_uids_v059[uid] = true
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	return true


func _auto_connect_all_v020() -> int:
	if restoring_state or restoring_v020:
		return 0
	auto_snap_priority_uids_v059.clear()
	var total: int = super._auto_connect_all_v020()
	if total > 0:
		_rebuild_connection_graph_v020()
		var relax_result: Dictionary = _relax_connection_geometry_v059(SNAP_RELAX_PASSES_V059)
		var max_gap: float = float(relax_result.get("max_gap", 0.0))
		_status("Auto-attached %d close connection%s; snapped closed-loop geometry (max residual %.3f)." % [total, "" if total == 1 else "s", max_gap])
	return total


func _prepare_stable_simulation_graph() -> void:
	# Normalize ALL recorded attachment points immediately before the legacy
	# spanning-tree/redundant-constraint pass. This also repairs v0.5.4 builds that
	# already contain a loop joint whose rest frame was recorded with a visible gap.
	if not restoring_state and not restoring_v020:
		auto_snap_priority_uids_v059.clear()
		_rebuild_connection_graph_v020()
		_relax_connection_geometry_v059(SNAP_RELAX_PASSES_V059 + 8)
	super._prepare_stable_simulation_graph()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.5: connector-type changes synchronously remove old mesh children before rebuilding the selection glow, eliminating queued-geometry phantom highlights. Close free rod ends/sockets use a wider direction-aware capture zone. Loop-closing SOCKET joints now project the connected build into a visibly closed pose, and simulation re-normalizes every recorded attachment before redundant cycle constraints are suppressed."


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
	if _compare_versions_v021(latest, VERSION_059) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_059)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
