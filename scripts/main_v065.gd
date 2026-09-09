extends "res://scripts/main_v064.gd"

const VERSION_065 := "0.5.10"

# Auto-connect means overlap, not proximity. The old v0.5.5 shell was 3.50
# world units and could treat a visibly separated rod/socket pair as connected.
# These limits intentionally prefer a missed auto-connect over bending an
# existing build to manufacture a connection.
const AUTO_SOCKET_CAPTURE_V065 := 0.38
const AUTO_SOCKET_LATERAL_V065 := 0.22
const AUTO_SOCKET_ALIGN_V065 := 0.98


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_065)
	_status("Strict socket overlap is active; SIMULATE no longer rewrites build geometry.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_065, text]


# -----------------------------------------------------------------------------
# Strict rod-end -> socket matching.
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
	var best_distance: float = INF
	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or connector == rod or str(connector.get_meta("kind", "")) != "connector":
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
			var socket_point: Vector3 = socket.get("point", connector.global_position) as Vector3
			var socket_dir: Vector3 = (socket.get("dir", Vector3.ZERO) as Vector3).normalized()
			if socket_dir.length_squared() < 0.5:
				continue
			var alignment: float = socket_dir.dot(-outward)
			if alignment < AUTO_SOCKET_ALIGN_V065:
				continue
			var delta: Vector3 = end_point - socket_point
			var distance: float = delta.length()
			if distance > AUTO_SOCKET_CAPTURE_V065:
				continue
			var axial: float = delta.dot(socket_dir)
			var lateral: float = (delta - socket_dir * axial).length()
			if lateral > AUTO_SOCKET_LATERAL_V065:
				continue
			if distance < best_distance:
				best_distance = distance
				best = {
					"connector": connector,
					"slot": slot,
					"distance": distance,
					"alignment": alignment,
					"lateral": lateral,
					"point": socket_point,
					"rod_point": end_point,
				}
	return best


# Connect in the pose that already exists. No component translation, no loop
# projection, and no priority correction pass are allowed here.
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

	var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
	var anchor: Vector3 = target.get("rod_point", _rod_end_v020(rod, sign_value)) as Vector3
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
	_tag_connection_v020(joint, "socket", connector, rod, slot, sign_value, 0.0, null, primary)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	return true


# v0.5.5 wrapped the graph matcher in a geometry relaxation pass. Retire that
# behavior completely: auto-connect may add a record, but it may not reshape the
# construction.
func _auto_connect_all_v020() -> int:
	if restoring_v020 or restoring_state:
		return 0
	_rebuild_connection_graph_v020()
	var total: int = 0
	for _pass in range(5):
		var pass_count: int = 0
		for body_value in bodies:
			var rod: RigidBody3D = body_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			if _auto_connect_end_v020(rod, -1):
				pass_count += 1
			if _auto_connect_end_v020(rod, 1):
				pass_count += 1
		if pass_count > 0:
			_rebuild_connection_graph_v020()
		var cross_count: int = _auto_connect_crosses_v020()
		pass_count += cross_count
		if cross_count > 0:
			_rebuild_connection_graph_v020()
		total += pass_count
		if pass_count == 0:
			break
	return total


# v0.5.7's immediate far-end behavior is still useful, but only when the new rod
# already lands inside another socket. The previous relaxation call after a far
# attachment is deliberately removed.
func _extend_socket(connector: RigidBody3D, slot: int) -> void:
	if simulating or slot < 0 or not is_instance_valid(connector):
		return
	_rebuild_connection_graph_v020()
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	if occupied.has(slot):
		_status("That connector socket already has a rod")
		return

	var rod_len: float = float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var socket: Dictionary = _socket_world_v020(connector, slot)
	var start: Vector3 = socket.get("point", connector.global_position) as Vector3
	var direction: Vector3 = (socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var finish: Vector3 = start + direction * rod_len
	var rod: RigidBody3D = _make_rod(selected_rod_type, start, finish)

	var source_joint: Generic6DOFJoint3D = _make_fixed_joint(connector, rod, start)
	_tag_connection_v020(source_joint, "socket", connector, rod, slot, -1, 0.0, null, false)
	_set_connector_occupied(connector, slot, true)
	_set_rod_end_occupied(rod, -1, true)
	rod.set_meta("build_transform", rod.global_transform)

	_rebuild_connection_graph_v020()
	var far_attached: bool = _auto_connect_end_v020(rod, 1)
	if far_attached:
		_rebuild_connection_graph_v020()
		_update_build_transforms_v059()
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()

	_set_selected(rod)
	_commit_state()
	if far_attached:
		_status("Rod added — far end was already inside an aligned socket, so it attached without moving the build.")
	else:
		_status("Rod added — far end remains free because it is not directly inside an aligned socket.")


# -----------------------------------------------------------------------------
# SIMULATE must not be an editor operation.
# -----------------------------------------------------------------------------

func _prepare_stable_simulation_graph() -> void:
	var before: Dictionary = {}
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			before[body.get_instance_id()] = body.global_transform
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			before[ring.get_instance_id()] = ring.global_transform

	var restoring_before: bool = restoring_v020
	restoring_v020 = true
	super._prepare_stable_simulation_graph()
	restoring_v020 = restoring_before

	# Hard safeguard: preflight is allowed to change joints/collision exceptions,
	# never body transforms. Restore any transform if a future ancestor regresses.
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body) and before.has(body.get_instance_id()):
			body.global_transform = before[body.get_instance_id()] as Transform3D
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring) and before.has(ring.get_instance_id()):
			ring.global_transform = before[ring.get_instance_id()] as Transform3D


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.10 SOCKET RULE: auto-connect is overlap-only. A rod end must already be directly inside a strongly aligned free socket; the editor will not translate, rotate, bend, or relax a construction to make a nearby candidate fit. SIMULATE no longer auto-docks, auto-connects, or re-projects build geometry before physics starts."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_065) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_065)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
