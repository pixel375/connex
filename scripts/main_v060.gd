extends "res://scripts/main_v059.gd"

const VERSION_060 := "0.5.5"

# v0.5.5 keeps the wider visual capture shell, but a 3.5-unit sphere around a
# dense 8/11/14-point connector can include several neighboring sockets. The
# correct target is the socket the rod is actually approaching, not simply the
# closest socket point. Tighten direction requirements as distance grows and
# weight lateral miss / direction mismatch strongly in the candidate score.
const SNAP_NEAR_DISTANCE_V060 := 1.25
const SNAP_MID_DISTANCE_V060 := 2.25
const SNAP_ALIGN_NEAR_V060 := -0.15
const SNAP_ALIGN_MID_V060 := 0.35
const SNAP_ALIGN_FAR_V060 := 0.70
const SNAP_LATERAL_MID_MAX_V060 := 1.55
const SNAP_LATERAL_FAR_MAX_V060 := 1.10


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_060)
	_status("v0.5.5 active — phantom-highlight cleanup plus direction-locked wide capture and closed-loop geometry projection.")


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
			if socket_dir.length_squared() < 0.5:
				continue
			var alignment: float = socket_dir.dot(-outward)
			var min_alignment: float
			var lateral_max: float
			if distance <= SNAP_NEAR_DISTANCE_V060:
				min_alignment = SNAP_ALIGN_NEAR_V060
				lateral_max = AUTO_SOCKET_LATERAL_MAX_V059
			elif distance <= SNAP_MID_DISTANCE_V060:
				min_alignment = SNAP_ALIGN_MID_V060
				lateral_max = SNAP_LATERAL_MID_MAX_V060
			else:
				min_alignment = SNAP_ALIGN_FAR_V060
				lateral_max = SNAP_LATERAL_FAR_MAX_V060
			if alignment < min_alignment:
				continue

			var axial: float = delta.dot(outward)
			var lateral: float = (delta - outward * axial).length()
			if distance > SNAP_NEAR_DISTANCE_V060 and lateral > lateral_max:
				continue

			# The angle term intentionally dominates tiny distance differences between
			# adjacent 45-degree sockets. A clearly aligned farther socket is preferred
			# over a slightly closer neighboring jaw that the rod is not entering.
			var score: float = distance + lateral * 0.90 + (1.0 - alignment) * 2.40
			if axial < -0.35:
				# The target point is substantially behind the free rod end; penalize
				# accidental back-side captures without banning very close overlaps.
				score += minf(2.0, absf(axial) * 0.75)
			if score < best_score:
				best_score = score
				best = {
					"connector": connector,
					"slot": slot,
					"distance": distance,
					"alignment": alignment,
					"lateral": lateral,
					"axial": axial,
					"score": score,
					"point": point,
					"rod_point": end_point,
				}
	return best


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_060) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_060)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
