extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
const AXLE_STOP_CLEARANCE_V069 := CONNECTOR_THICKNESS * 0.5 + O_RING_HEIGHT * 0.5 + 0.03
const AXLE_END_CLEARANCE_V069 := CONNECTOR_THICKNESS * 0.5 + 0.04
const AXLE_LIMIT_EPS_V069 := 0.001
const AXLE_SOLVER_PRIORITY_V069 := 8

var axle_stop_limit_count_v069: int = 0
var axle_component_exception_count_v069: int = 0


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops now bound the axle slide itself; no proxy collision is used as a stopper.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# v0.5.13 copied each O-Ring collision shape onto the host axle rod. Axle joints
# deliberately exclude connector-vs-host-rod collision, so an axle connector
# could never collide with that proxy. Other pieces in the connector's rigid
# structure still could, which is exactly the wrong combination: the hub passed
# through the stop while the surrounding build could receive violent proxy hits.
# v0.5.14 intentionally creates no host-rod proxy. The stop is expressed in the
# prismatic axle joint's free Y translation instead.
func _add_o_ring_proxy_shapes_v068(_ring: RigidBody3D, _rod: RigidBody3D) -> int:
	return 0


func _save_axle_joint_limits_v069(joint: Generic6DOFJoint3D) -> void:
	if not is_instance_valid(joint) or bool(joint.get_meta("sim_axle_limits_saved_v069", false)):
		return
	joint.set_meta("sim_axle_limits_saved_v069", true)
	joint.set_meta("sim_axle_y_enabled_v069", bool(joint.get("linear_limit_y/enabled")))
	joint.set_meta("sim_axle_y_lower_v069", float(joint.get("linear_limit_y/lower_distance")))
	joint.set_meta("sim_axle_y_upper_v069", float(joint.get("linear_limit_y/upper_distance")))
	joint.set_meta("sim_axle_solver_priority_v069", int(joint.solver_priority))


func _restore_axle_stop_limits_v069() -> void:
	for joint_value in joints:
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("sim_axle_limits_saved_v069", false)):
			continue
		joint.set("linear_limit_y/enabled", bool(joint.get_meta("sim_axle_y_enabled_v069", false)))
		joint.set("linear_limit_y/lower_distance", float(joint.get_meta("sim_axle_y_lower_v069", 0.0)))
		joint.set("linear_limit_y/upper_distance", float(joint.get_meta("sim_axle_y_upper_v069", 0.0)))
		joint.solver_priority = int(joint.get_meta("sim_axle_solver_priority_v069", 1))
		joint.remove_meta("sim_axle_limits_saved_v069")
		joint.remove_meta("sim_axle_y_enabled_v069")
		joint.remove_meta("sim_axle_y_lower_v069")
		joint.remove_meta("sim_axle_y_upper_v069")
		joint.remove_meta("sim_axle_solver_priority_v069")
		joint.remove_meta("sim_axle_stop_lower_v069")
		joint.remove_meta("sim_axle_stop_upper_v069")
		joint.remove_meta("sim_axle_stop_count_v069")
	axle_stop_limit_count_v069 = 0


func _o_ring_alongs_for_rod_v069(rod: RigidBody3D, axis: Vector3) -> Array:
	var result: Array = []
	# v0.5.13 detaches O-Ring joints before this pass, so those records disappear
	# from a fresh graph rebuild. The follower list is therefore the authoritative
	# simulation-time source for ring/host pairs.
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		if follower.get("rod") != rod:
			continue
		var ring := follower.get("ring") as RigidBody3D
		if is_instance_valid(ring):
			result.append((ring.global_position - rod.global_position).dot(axis))
	if not result.is_empty():
		result.sort()
		return result

	# Fallback for direct preflight calls before follower conversion.
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "o_ring" or record.get("rod") != rod:
			continue
		var ring := record.get("ring") as RigidBody3D
		if is_instance_valid(ring):
			result.append((ring.global_position - rod.global_position).dot(axis))
	result.sort()
	return result


func _apply_axle_stop_limits_v069() -> int:
	_restore_axle_stop_limits_v069()
	var applied := 0
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		var joint := record.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(connector) or not is_instance_valid(rod) or not is_instance_valid(joint):
			continue
		if bool(joint.get_meta("sim_disabled", false)):
			continue

		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		if axis.length_squared() < 0.5:
			continue
		var start_along: float = (connector.global_position - rod.global_position).dot(axis)
		var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5)

		# Rod ends are physical travel stops too. Axle joints otherwise have an
		# infinite Y slide and can remain constrained after the hub visibly leaves
		# the rod, which is another source of bad solver leverage.
		var lower_center: float = -half_len + AXLE_END_CLEARANCE_V069
		var upper_center: float = half_len - AXLE_END_CLEARANCE_V069
		var stop_count := 0
		for ring_along_value in _o_ring_alongs_for_rod_v069(rod, axis):
			var ring_along := float(ring_along_value)
			if ring_along < start_along - AXLE_LIMIT_EPS_V069:
				lower_center = maxf(lower_center, ring_along + AXLE_STOP_CLEARANCE_V069)
				stop_count += 1
			elif ring_along > start_along + AXLE_LIMIT_EPS_V069:
				upper_center = minf(upper_center, ring_along - AXLE_STOP_CLEARANCE_V069)
				stop_count += 1

		# Never start a simulation outside the active limit. If the BUILD pose is
		# already visually touching/overlapping a stop, that side begins at zero
		# travel instead of snapping the structure to manufacture clearance.
		var lower_rel: float = minf(0.0, lower_center - start_along)
		var upper_rel: float = maxf(0.0, upper_center - start_along)
		if lower_rel > upper_rel:
			lower_rel = 0.0
			upper_rel = 0.0

		_save_axle_joint_limits_v069(joint)
		joint.set("linear_limit_y/enabled", true)
		joint.set("linear_limit_y/lower_distance", lower_rel)
		joint.set("linear_limit_y/upper_distance", upper_rel)
		joint.solver_priority = maxi(joint.solver_priority, AXLE_SOLVER_PRIORITY_V069)
		joint.set_meta("sim_axle_stop_lower_v069", lower_rel)
		joint.set_meta("sim_axle_stop_upper_v069", upper_rel)
		joint.set_meta("sim_axle_stop_count_v069", stop_count)
		applied += 1
	axle_stop_limit_count_v069 = applied
	return applied


# A connector carried by an axle may be the root of a much larger fixed frame.
# Simplified collision hulls around that frame must not fight the very axle that
# guides it. The axle joint already excludes hub-vs-rod collision; extend that
# exception to the hub's fixed SOCKET/CROSS component for this host axle only.
# O-Ring stopping is independent and remains solver-native through the Y limit.
func _apply_axle_component_exceptions_v069() -> int:
	var added := 0
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var component: Array = _fixed_component_v020(connector, -1)
		for member_value in component:
			var member := member_value as RigidBody3D
			if not is_instance_valid(member) or member == rod or str(member.get_meta("kind", "")) == "o_ring":
				continue
			var before_size := simulation_collision_pairs.size()
			_add_simulation_collision_exception(member, rod)
			if simulation_collision_pairs.size() > before_size:
				added += 1
	axle_component_exception_count_v069 = added
	return added


func _prepare_stable_simulation_graph() -> void:
	# Restore any previous run's temporary limit state before inherited preflight.
	_restore_axle_stop_limits_v069()
	super._prepare_stable_simulation_graph()
	# super() has converted O-Rings into collisionless visual followers. Unlike
	# v0.5.13, no proxy shapes were created. connections_v020 still contains the
	# axle records from that preflight; follower state supplies the detached rings.
	_apply_axle_stop_limits_v069()
	_apply_axle_component_exceptions_v069()


func _reset_pose() -> void:
	_restore_axle_stop_limits_v069()
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_restore_axle_stop_limits_v069()
	super._restore_state(snapshot)


func _restart_build() -> void:
	_restore_axle_stop_limits_v069()
	super._restart_build()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d axle guide%s bounded by rod ends/O-Rings; %d guide self-collision exception%s active" % [
		axle_stop_limit_count_v069,
		"" if axle_stop_limit_count_v069 == 1 else "s",
		axle_component_exception_count_v069,
		"" if axle_component_exception_count_v069 == 1 else "s"
	])


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.14 AXLE STOPS: O-Rings no longer rely on a collision shape copied onto the host axle rod. Axle joints intentionally exclude hub-vs-host collision, so that v0.5.13 proxy could never stop the hub and could instead strike surrounding fixed pieces. O-Rings now directly bound the axle joint's free slide range, including connector thickness and rod-end limits. The fixed structure carried by an axle also ignores collision with its own guide rod, preventing simplified construction hulls from fighting the axle constraint."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_069) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_069)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
