extends "res://scripts/main_v060.gd"

const VERSION_061 := "0.5.6"

# Auto-dock is specifically for the common build action shown in the device
# report: place a planar connector onto an axle rod after several surrounding rod
# ends already exist. The connector is free to roll around the axle, so use that
# physical DOF to line its sockets up with nearby free rod ends before fusing.
const AUTO_DOCK_SEARCH_RADIUS_V061 := 5.75
const AUTO_DOCK_PLANE_TOLERANCE_V061 := 1.55
const AUTO_DOCK_ROD_PERP_DOT_V061 := 0.42
const AUTO_DOCK_MATCH_DISTANCE_V061 := 4.20
const AUTO_DOCK_MATCH_ALIGN_V061 := 0.58
const AUTO_DOCK_MIN_IMPROVEMENT_V061 := 0.0005

# Camera keeps the requested wide zoom range, but pinch uses a ratio instead of
# raw screen pixels and pan speed stops growing without bound at extreme zoom.
const CAMERA_MIN_DISTANCE_V061 := 3.0
const CAMERA_MAX_DISTANCE_V061 := 420.0
const CAMERA_PINCH_RESPONSE_V061 := 0.92
const CAMERA_PAN_DISTANCE_CAP_V061 := 135.0
const CAMERA_PAN_SCALE_V061 := 0.00215

var auto_dock_running_v061: bool = false


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_061)
	_status("v0.5.6 active — axle connectors auto-orient to surrounding free rod ends, simulation performs a final socket-fuse pass, and two-finger camera pan/zoom is stabilized.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_061, text]


# -----------------------------------------------------------------------------
# Axle connector auto-docking
# -----------------------------------------------------------------------------

func _axle_record_for_connector_v061(connector: RigidBody3D) -> Dictionary:
	if not is_instance_valid(connector):
		return {}
	for value in _connections_for_piece_v020(connector):
		var record: Dictionary = value as Dictionary
		if str(record.get("kind", "")) == "axle" and record.get("connector") == connector:
			return record
	return {}


func _connector_has_radial_connections_v061(connector: RigidBody3D) -> bool:
	if not is_instance_valid(connector):
		return false
	for value in _connections_for_piece_v020(connector):
		var record: Dictionary = value as Dictionary
		if str(record.get("kind", "")) in ["socket", "cross"]:
			return true
	return false


func _free_slots_v061(connector: RigidBody3D) -> Array:
	var result: Array = []
	if not is_instance_valid(connector):
		return result
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return result
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		if not occupied.has(slot):
			result.append(slot)
	return result


func _nearby_free_rod_ends_v061(connector: RigidBody3D, axle_axis: Vector3) -> Array:
	var result: Array = []
	if not is_instance_valid(connector):
		return result
	var axis_n: Vector3 = axle_axis.normalized()
	if axis_n.length_squared() < 0.5:
		return result
	for body_value in bodies:
		var rod: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
			continue
		var rod_axis: Vector3 = _rod_axis_v020(rod).normalized()
		if rod_axis.length_squared() < 0.5 or absf(rod_axis.dot(axis_n)) > AUTO_DOCK_ROD_PERP_DOT_V061:
			continue
		var occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
		for sign_value in [-1, 1]:
			if occupied.has(sign_value):
				continue
			var point: Vector3 = _rod_end_v020(rod, sign_value)
			var center_delta: Vector3 = point - connector.global_position
			if center_delta.length() > AUTO_DOCK_SEARCH_RADIUS_V061:
				continue
			if absf(center_delta.dot(axis_n)) > AUTO_DOCK_PLANE_TOLERANCE_V061:
				continue
			var outward: Vector3 = rod_axis * float(sign_value)
			var desired: Vector3 = -outward
			desired -= axis_n * desired.dot(axis_n)
			if desired.length_squared() < 0.25:
				continue
			result.append({
				"rod": rod,
				"sign": sign_value,
				"point": point,
				"desired": desired.normalized(),
			})
	return result


func _project_to_plane_v061(vector_value: Vector3, normal: Vector3) -> Vector3:
	var projected: Vector3 = vector_value - normal * vector_value.dot(normal)
	return projected.normalized() if projected.length_squared() > 0.000001 else Vector3.ZERO


func _dock_score_for_basis_v061(connector: RigidBody3D, basis_value: Basis, axle_axis: Vector3, rod_ends: Array, free_slots: Array) -> Dictionary:
	var used_slots: Dictionary = {}
	var matches: int = 0
	var total_score: float = 0.0
	var assignments: Array = []
	var axis_n: Vector3 = axle_axis.normalized()

	# Process the most constrained endpoints first: each endpoint computes its best
	# available socket under this candidate roll. This is deterministic and enough
	# for the small 1/2/3/4/5/6/8/11/14-point connector slot sets.
	for endpoint_value in rod_ends:
		var endpoint: Dictionary = endpoint_value as Dictionary
		var best_slot: int = -1
		var best_score: float = INF
		var best_distance: float = INF
		var best_alignment: float = -1.0
		var desired: Vector3 = endpoint.get("desired", Vector3.ZERO) as Vector3
		var rod_point: Vector3 = endpoint.get("point", Vector3.ZERO) as Vector3
		for slot_value in free_slots:
			var slot: int = int(slot_value)
			if used_slots.has(slot):
				continue
			var socket_dir: Vector3 = _project_to_plane_v061((basis_value * _slot_dir(slot)).normalized(), axis_n)
			if socket_dir.length_squared() < 0.25:
				continue
			var alignment: float = socket_dir.dot(desired)
			if alignment < AUTO_DOCK_MATCH_ALIGN_V061:
				continue
			var socket_point: Vector3 = connector.global_position + socket_dir * CONNECTOR_D
			var distance: float = socket_point.distance_to(rod_point)
			if distance > AUTO_DOCK_MATCH_DISTANCE_V061:
				continue
			var score: float = distance + (1.0 - alignment) * 1.75
			if score < best_score:
				best_score = score
				best_slot = slot
				best_distance = distance
				best_alignment = alignment
		if best_slot >= 0:
			used_slots[best_slot] = true
			matches += 1
			total_score += best_score
			assignments.append({
				"rod": endpoint.get("rod"),
				"sign": int(endpoint.get("sign", 0)),
				"slot": best_slot,
				"distance": best_distance,
				"alignment": best_alignment,
			})

	return {"matches": matches, "score": total_score, "assignments": assignments}


func _candidate_dock_angles_v061(connector: RigidBody3D, axle_axis: Vector3, rod_ends: Array, free_slots: Array) -> Array:
	var result: Array = [0.0]
	var axis_n: Vector3 = axle_axis.normalized()
	var base: Basis = connector.global_transform.basis.orthonormalized()
	for endpoint_value in rod_ends:
		var endpoint: Dictionary = endpoint_value as Dictionary
		var desired: Vector3 = endpoint.get("desired", Vector3.ZERO) as Vector3
		if desired.length_squared() < 0.25:
			continue
		for slot_value in free_slots:
			var slot: int = int(slot_value)
			var current_dir: Vector3 = _project_to_plane_v061((base * _slot_dir(slot)).normalized(), axis_n)
			if current_dir.length_squared() < 0.25:
				continue
			var angle: float = current_dir.signed_angle_to(desired, axis_n)
			var duplicate_angle: bool = false
			for existing_value in result:
				if absf(wrapf(angle - float(existing_value), -PI, PI)) < 0.002:
					duplicate_angle = true
					break
			if not duplicate_angle:
				result.append(angle)
	return result


func _auto_orient_axle_connector_v061(connector: RigidBody3D) -> Dictionary:
	if auto_dock_running_v061 or not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
		return {"changed": false, "matches": 0}
	_rebuild_connection_graph_v020()
	if _connector_has_radial_connections_v061(connector):
		return {"changed": false, "matches": 0}
	var axle_record: Dictionary = _axle_record_for_connector_v061(connector)
	if axle_record.is_empty():
		return {"changed": false, "matches": 0}
	var host_rod: RigidBody3D = axle_record.get("rod") as RigidBody3D
	if not is_instance_valid(host_rod):
		return {"changed": false, "matches": 0}
	var axle_axis: Vector3 = _rod_axis_v020(host_rod).normalized()
	var rod_ends: Array = _nearby_free_rod_ends_v061(connector, axle_axis)
	var free_slots: Array = _free_slots_v061(connector)
	if rod_ends.is_empty() or free_slots.is_empty():
		return {"changed": false, "matches": 0}

	auto_dock_running_v061 = true
	var base: Basis = connector.global_transform.basis.orthonormalized()
	var angles: Array = _candidate_dock_angles_v061(connector, axle_axis, rod_ends, free_slots)
	var best_angle: float = 0.0
	var best_matches: int = -1
	var best_score: float = INF
	for angle_value in angles:
		var angle: float = float(angle_value)
		var candidate_basis: Basis = (Basis(axle_axis, angle) * base).orthonormalized()
		var scored: Dictionary = _dock_score_for_basis_v061(connector, candidate_basis, axle_axis, rod_ends, free_slots)
		var matches: int = int(scored.get("matches", 0))
		var score: float = float(scored.get("score", INF))
		if matches > best_matches or (matches == best_matches and score < best_score - AUTO_DOCK_MIN_IMPROVEMENT_V061) or (matches == best_matches and absf(score - best_score) <= AUTO_DOCK_MIN_IMPROVEMENT_V061 and absf(angle) < absf(best_angle)):
			best_matches = matches
			best_score = score
			best_angle = angle

	var changed: bool = best_matches > 0 and absf(best_angle) > 0.002
	if changed:
		var transform_value: Transform3D = connector.global_transform
		transform_value.basis = (Basis(axle_axis, best_angle) * base).orthonormalized()
		connector.global_transform = transform_value
		connector.set_meta("rotation_home_basis_v020", transform_value.basis)
		connector.set_meta("rotation_home_transform", transform_value)
		connector.set_meta("build_transform", transform_value)
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
	auto_dock_running_v061 = false
	return {"changed": changed, "matches": maxi(best_matches, 0), "angle": best_angle, "score": best_score}


func _auto_orient_empty_axle_connectors_v061() -> int:
	if auto_dock_running_v061:
		return 0
	_rebuild_connection_graph_v020()
	var count: int = 0
	var connector_list: Array = []
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body) and str(body.get_meta("kind", "")) == "connector":
			connector_list.append(body)
	for connector_value in connector_list:
		var connector: RigidBody3D = connector_value as RigidBody3D
		var result: Dictionary = _auto_orient_axle_connector_v061(connector)
		if bool(result.get("changed", false)):
			count += 1
	return count


func _run_close_attachment_pass_v061(commit_change: bool = false, report: bool = false) -> Dictionary:
	if simulating or restoring_state or restoring_v020:
		return {"oriented": 0, "attached": 0}
	_rebuild_connection_graph_v020()
	var oriented: int = _auto_orient_empty_axle_connectors_v061()
	var attached: int = _auto_connect_all_v020()
	if oriented > 0 or attached > 0:
		_update_build_transforms_v059()
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
		if commit_change:
			_commit_state()
		if report:
			_status("Auto-dock: oriented %d axle connector%s and fused %d nearby rod/socket connection%s." % [oriented, "" if oriented == 1 else "s", attached, "" if attached == 1 else "s"])
	return {"oriented": oriented, "attached": attached}


func _place_connector_on_rod_as_axle(rod: RigidBody3D, hit_pos: Vector3) -> void:
	var was_o_ring: bool = selected_connector_type == o_ring_index
	super._place_connector_on_rod_as_axle(rod, hit_pos)
	if was_o_ring or simulating:
		return
	var placed: RigidBody3D = last_placed_connector
	if is_instance_valid(placed) and str(placed.get_meta("kind", "")) == "connector":
		var orient_result: Dictionary = _auto_orient_axle_connector_v061(placed)
		var attached: int = _auto_connect_all_v020()
		if bool(orient_result.get("changed", false)) or attached > 0:
			_update_build_transforms_v059()
			_refresh_joint_frames_v020()
			_rebuild_connection_graph_v020()
			_commit_state()
			_status("Axle connector placed — auto-docked to %d nearby rod/socket connection%s." % [attached, "" if attached == 1 else "s"])


func _prepare_stable_simulation_graph() -> void:
	# This is the critical v0.5.6 behavior: simulation is the last chance to turn
	# every visually close free rod/socket pair into an actual graph connection.
	# v0.5.5 normalized only connections that already existed, so unrecorded rods
	# in the reported axle-connector scenario simply fell away.
	if not restoring_state and not restoring_v020:
		_run_close_attachment_pass_v061(false, false)
	super._prepare_stable_simulation_graph()


# -----------------------------------------------------------------------------
# Stable Android camera gestures
# -----------------------------------------------------------------------------

func _pan_camera(screen_delta: Vector2) -> void:
	if camera == null:
		return
	var right: Vector3 = camera.global_transform.basis.x.normalized()
	var up: Vector3 = camera.global_transform.basis.y.normalized()
	var x_factor: float = -1.0 if reverse_pan_x else 1.0
	var y_factor: float = -1.0 if reverse_pan_y else 1.0
	# At the old 420-unit maximum, camera_distance-proportional pan could jump by
	# enormous amounts from a tiny finger movement. Preserve scale with distance,
	# but cap the effective distance used for pan speed.
	var effective_distance: float = clampf(camera_distance, 5.0, CAMERA_PAN_DISTANCE_CAP_V061)
	var move_scale: float = effective_distance * CAMERA_PAN_SCALE_V061 * camera_sensitivity
	camera_target += (-right * screen_delta.x * x_factor + up * screen_delta.y * y_factor) * move_scale
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.y = clampf(camera_target.y, -80.0, 160.0)


func _apply_pinch_zoom_v061(previous_distance: float, current_distance: float) -> float:
	if previous_distance <= 1.0 or current_distance <= 1.0:
		return camera_distance
	# Ratio-based zoom behaves consistently across phones/tablets and does not
	# depend on raw pixel density. Spreading fingers zooms in; pinching zooms out.
	var ratio: float = clampf(previous_distance / current_distance, 0.35, 2.85)
	camera_distance = clampf(camera_distance * pow(ratio, CAMERA_PINCH_RESPONSE_V061), CAMERA_MIN_DISTANCE_V061, CAMERA_MAX_DISTANCE_V061)
	return camera_distance


func _mark_all_camera_touches_moved_v061() -> void:
	for key_value in touches.keys():
		touch_moved[key_value] = true


func _unhandled_input(event: InputEvent) -> void:
	if _any_modal_open_v054():
		return

	if event is InputEventScreenDrag and touches.size() >= 2:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		touches[drag.index] = drag.position
		_mark_all_camera_touches_moved_v061()
		var current_pinch: float = _pinch_distance()
		if pinch_last > 1.0:
			_apply_pinch_zoom_v061(pinch_last, current_pinch)
		pinch_last = current_pinch
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
			var factor: float = 0.88 if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14
			camera_distance = clampf(camera_distance * factor, CAMERA_MIN_DISTANCE_V061, CAMERA_MAX_DISTANCE_V061)
			get_viewport().set_input_as_handled()
			return

	# Touch press/release, one-finger orbit, gizmo drags and ordinary taps retain
	# the established input chain. The parent also resets pinch state correctly
	# when the touch count changes.
	super._unhandled_input(event)


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.6: placing a connector on an axle now uses its free roll axis to line up with nearby free rod ends, then fuses all matching sockets. SIMULATE performs the same final auto-dock/fuse pass before physics, so visually connected rods cannot simply fall off because their graph joints were never created. Camera pinch zoom is ratio-based, two-finger pan speed is bounded at extreme zoom, and both fingers are marked as gesture touches so lifting after a pinch cannot become an accidental tap."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_061) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_061)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
