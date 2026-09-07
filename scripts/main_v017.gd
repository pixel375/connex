extends "res://scripts/main_v016.gd"

const VERSION_017 = "0.1.7"
const END_FUSE_CAPTURE_DISTANCE = 0.68
const END_FUSE_ALIGN_DOT = 0.955
const CROSS_FUSE_CAPTURE_DISTANCE = 0.30
const CROSS_FUSE_PERP_DOT = 0.24

var auto_fuse_in_progress_v017: bool = false
var last_auto_fuse_count_v017: int = 0


# v0.1.7 makes auto-fusing part of every committed build state, not only the
# final SIMULATE pass. This means a rod end that visually lands in a compatible
# socket becomes a real graph connection immediately after placement/editing.
func _commit_state() -> void:
	if not restoring_state and not simulating and not auto_fuse_in_progress_v017:
		auto_fuse_in_progress_v017 = true
		last_auto_fuse_count_v017 = _auto_fuse_all_v017()
		auto_fuse_in_progress_v017 = false
	super._commit_state()


func _rod_axis_world_v017(rod: RigidBody3D) -> Vector3:
	# Prefer the actual transform so future rigid-component rotations cannot leave
	# the legacy `axis` metadata stale.
	var axis: Vector3 = rod.global_transform.basis * Vector3.UP
	if axis.length_squared() < 0.25:
		axis = rod.get_meta("axis", Vector3.UP) as Vector3
	return axis.normalized()


func _rod_end_world_v017(rod: RigidBody3D, sign_value: int) -> Vector3:
	var length: float = float(rod.get_meta("visual_length", 0.0))
	return rod.global_position + _rod_axis_world_v017(rod) * (length * 0.5 * float(sign_value))


func _connector_socket_world_v017(connector: RigidBody3D, slot: int) -> Dictionary:
	var direction: Vector3 = (connector.global_transform.basis * _slot_dir(slot)).normalized()
	return {
		"dir": direction,
		"point": connector.global_position + direction * CONNECTOR_D,
	}


func _best_socket_for_free_rod_end_v017(rod: RigidBody3D, sign_value: int) -> Dictionary:
	var rod_occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	if rod_occupied.has(sign_value):
		return {}

	var end_point: Vector3 = _rod_end_world_v017(rod, sign_value)
	var outward: Vector3 = _rod_axis_world_v017(rod) * float(sign_value)
	var best: Dictionary = {}
	var best_distance: float = END_FUSE_CAPTURE_DISTANCE

	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or connector == rod:
			continue
		if str(connector.get_meta("kind", "")) != "connector":
			continue
		if _fixed_pair_exists(rod, connector):
			continue

		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size():
			continue
		var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			if occupied.has(slot):
				continue
			var socket: Dictionary = _connector_socket_world_v017(connector, slot)
			var socket_dir: Vector3 = socket["dir"] as Vector3
			if socket_dir.dot(-outward) < END_FUSE_ALIGN_DOT:
				continue
			var socket_point: Vector3 = socket["point"] as Vector3
			var distance: float = socket_point.distance_to(end_point)
			if distance <= best_distance:
				best_distance = distance
				best = {
					"connector": connector,
					"slot": slot,
					"point": socket_point,
					"rod_point": end_point,
					"distance": distance,
				}
	return best


func _fuse_free_rod_end_v017(rod: RigidBody3D, sign_value: int) -> bool:
	var target: Dictionary = _best_socket_for_free_rod_end_v017(rod, sign_value)
	if target.is_empty():
		return false

	var connector: RigidBody3D = target["connector"] as RigidBody3D
	var slot: int = int(target["slot"])
	if not is_instance_valid(connector):
		return false
	var rod_occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
	var connector_occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	if rod_occupied.has(sign_value) or connector_occupied.has(slot):
		return false
	if _fixed_pair_exists(rod, connector):
		return false

	# Use the midpoint of the two logical connection points as the joint frame.
	# Generic6DOF stores both local frames from the current build pose, so this
	# creates no solver preload even when the visual overlap is a few mm imperfect.
	var rod_point: Vector3 = target["rod_point"] as Vector3
	var socket_point: Vector3 = target["point"] as Vector3
	var anchor: Vector3 = (rod_point + socket_point) * 0.5
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	joint.set_meta("auto_fused", true)
	joint.set_meta("auto_fuse_kind", "rod_end_socket")
	joint.set_meta("auto_fuse_gap", float(target["distance"]))
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	return true


func _fuse_free_connector_crosses_v017(connector: RigidBody3D) -> int:
	var fused: int = 0
	if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
		return fused
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return fused

	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
		if occupied.has(slot):
			continue
		var socket: Dictionary = _connector_socket_world_v017(connector, slot)
		var mouth: Vector3 = socket["point"] as Vector3
		var slot_dir: Vector3 = socket["dir"] as Vector3

		var best_rod: RigidBody3D = null
		var best_point: Vector3 = Vector3.ZERO
		var best_distance: float = CROSS_FUSE_CAPTURE_DISTANCE
		for body_value in bodies:
			var rod: RigidBody3D = body_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			if _fixed_pair_exists(rod, connector):
				continue
			var axis: Vector3 = _rod_axis_world_v017(rod)
			if absf(axis.dot(slot_dir)) > CROSS_FUSE_PERP_DOT:
				continue
			var half_len: float = maxf(0.0, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.42)
			var along: float = clampf((mouth - rod.global_position).dot(axis), -half_len, half_len)
			var closest: Vector3 = rod.global_position + axis * along
			var distance: float = closest.distance_to(mouth)
			if distance <= best_distance:
				best_distance = distance
				best_rod = rod
				best_point = closest

		if is_instance_valid(best_rod):
			var anchor: Vector3 = (best_point + mouth) * 0.5
			var joint: Generic6DOFJoint3D = _make_fixed_joint(best_rod, connector, anchor)
			joint.set_meta("auto_fused", true)
			joint.set_meta("auto_fuse_kind", "cross")
			joint.set_meta("cross_mount", true)
			joint.set_meta("auto_fuse_gap", best_distance)
			_set_connector_occupied(connector, slot, true)
			fused += 1
	return fused


func _auto_fuse_all_v017() -> int:
	var total: int = 0
	# Re-run because one successful match changes occupancy and can expose the next
	# unambiguous candidate in the same local cluster.
	for _pass in range(6):
		var pass_count: int = 0
		for body_value in bodies:
			var rod: RigidBody3D = body_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			if _fuse_free_rod_end_v017(rod, -1):
				pass_count += 1
			if _fuse_free_rod_end_v017(rod, 1):
				pass_count += 1

		# Preserve automatic cross capture too, but only after end/socket matches get
		# priority. This prevents a rod end near a jaw from being mistaken for a cross.
		for body_value in bodies:
			var connector: RigidBody3D = body_value as RigidBody3D
			if is_instance_valid(connector) and str(connector.get_meta("kind", "")) == "connector":
				pass_count += _fuse_free_connector_crosses_v017(connector)

		total += pass_count
		if pass_count == 0:
			break
	return total


# Override the legacy simulation scan so the exact same robust matcher is used
# both during BUILD commits and immediately before physics release.
func _auto_fuse_all() -> bool:
	last_auto_fuse_count_v017 = _auto_fuse_all_v017()
	return last_auto_fuse_count_v017 > 0


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_017, text]
