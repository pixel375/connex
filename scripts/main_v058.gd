extends "res://scripts/main_v057.gd"

const VERSION_058 := "0.5.4"
const TRANSFORM_RELEASE_SUPPRESS_MS_V058 := 320
const AUTO_SOCKET_CAPTURE_V058 := 2.00
const AUTO_SOCKET_ALIGN_V058 := 0.38

var transform_release_suppress_until_v058: int = 0


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_058)
	_status("v0.5.4 active — transform-release tap suppression, clean connector highlight rebuilds and stronger proximity auto-attachment.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_058, text]


# -----------------------------------------------------------------------------
# A transform drag release is not a tap.
#
# On Android the release event can continue through the inherited input chain
# after the gizmo has committed. If the finger happens to be over another piece,
# ROTATE/MOVE direct-selection used to select that piece. Arm a short suppression
# window only when an actual gizmo drag finishes.
# -----------------------------------------------------------------------------

func _arm_transform_release_suppression_v058() -> void:
	transform_release_suppress_until_v058 = Time.get_ticks_msec() + TRANSFORM_RELEASE_SUPPRESS_MS_V058


func _transform_release_tap_suppressed_v058() -> bool:
	return Time.get_ticks_msec() <= transform_release_suppress_until_v058


func _finish_gizmo_drag_v030() -> void:
	var was_dragging: bool = gizmo_drag_active_v030
	super._finish_gizmo_drag_v030()
	if was_dragging:
		_arm_transform_release_suppression_v058()


func _finish_move_drag_v042() -> void:
	var was_dragging: bool = move_drag_active_v042
	super._finish_move_drag_v042()
	if was_dragging:
		_arm_transform_release_suppression_v058()


func _handle_tap(screen_pos: Vector2) -> void:
	if editor_mode_v032 in [EDITOR_ROTATE_032, EDITOR_MOVE_042] and _transform_release_tap_suppressed_v058():
		return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# Connector type changes must invalidate the old selection outline immediately.
# 11/14-point connectors contain nested spatial meshes; the old highlight cloned
# those meshes and could survive after the real connector had been rebuilt into
# a smaller connector. Remove that clone synchronously, rebuild, then regenerate
# the highlight from the new geometry only.
# -----------------------------------------------------------------------------

func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if not is_instance_valid(body):
		return
	var was_selected: bool = is_instance_valid(selected_piece) and selected_piece == body
	var stale_highlight: Node = body.get_node_or_null("SelectionHighlight")
	if stale_highlight != null:
		body.remove_child(stale_highlight)
		stale_highlight.free()
	if is_instance_valid(highlighted_body) and highlighted_body == body:
		highlighted_body = null
	super._rebuild_connector(body, def_index)
	if was_selected:
		_refresh_selection_highlight()


# -----------------------------------------------------------------------------
# Proximity auto-attachment.
#
# v0.5.3 permitted loop closure but still used a small capture shell. On actual
# phone builds a visually adjacent rod end can be farther from the mathematical
# socket point because both pieces include jaw/cap geometry. Use a wider capture
# shell, rank candidates by distance + alignment, and still require a reasonably
# opposing direction. Explicit Disconnect pair blocks remain authoritative.
# -----------------------------------------------------------------------------

func _best_socket_for_end_v020(rod: RigidBody3D, sign_value: int) -> Dictionary:
	if not is_instance_valid(rod):
		return {}
	var rod_occ: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	if rod_occ.has(sign_value):
		return {}
	var end_point: Vector3 = _rod_end_v020(rod, sign_value)
	var outward: Vector3 = _rod_axis_v020(rod) * float(sign_value)
	var best: Dictionary = {}
	var best_score: float = INF

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
			var socket_dir: Vector3 = (socket.get("dir", Vector3.ZERO) as Vector3).normalized()
			var alignment: float = socket_dir.dot(-outward.normalized())
			if alignment < AUTO_SOCKET_ALIGN_V058:
				continue
			var point: Vector3 = socket.get("point", connector.global_position) as Vector3
			var distance: float = point.distance_to(end_point)
			if distance > AUTO_SOCKET_CAPTURE_V058:
				continue
			# Distance dominates. Alignment breaks ties in dense multi-port hubs.
			var score: float = distance + (1.0 - alignment) * 0.42
			if score < best_score:
				best_score = score
				best = {
					"connector": connector,
					"slot": slot,
					"distance": distance,
					"alignment": alignment,
					"point": point,
					"rod_point": end_point,
				}
	return best


func _component_has_root_v058(component: Array) -> bool:
	for value in component:
		var body: RigidBody3D = value as RigidBody3D
		if is_instance_valid(body) and bool(body.get_meta("root_piece_v020", false)):
			return true
	return false


func _translate_component_v058(component: Array, delta: Vector3) -> void:
	if delta.length_squared() < 0.000001:
		return
	for value in component:
		var body: RigidBody3D = value as RigidBody3D
		if is_instance_valid(body):
			body.global_position += delta


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

	# If the two pieces are separate islands, close the visible gap by translating
	# the smaller/non-root island rigidly before creating the joint. Internal
	# connections remain unchanged. If they already belong to the same rigid loop,
	# do not distort the loop; record the valid close connection in-place.
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
	var anchor: Vector3 = (socket_point_now + rod_point_now) * 0.5
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
	_tag_connection_v020(joint, "socket", connector, rod, slot, sign_value, 0.0, null, primary)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	return true


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.4: releasing a Rotate/Move gizmo never selects the piece under your finger; connector-type changes rebuild the selection glow from current geometry; nearby free rod ends and sockets use a larger phone-friendly auto-snap capture shell and separate build islands visibly close the remaining gap before fusing."


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
	if _compare_versions_v021(latest, VERSION_058) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_058)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
