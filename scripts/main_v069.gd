extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
const AXLE_STOP_CLEARANCE_V069 := CONNECTOR_THICKNESS * 0.5 + O_RING_HEIGHT * 0.5 + 0.03
const AXLE_END_CLEARANCE_V069 := CONNECTOR_THICKNESS * 0.5 + 0.04
const AXLE_LIMIT_EPS_V069 := 0.001
const AXLE_STOP_SLOP_V069 := 0.015
const AXLE_SOLVER_PRIORITY_V069 := 8

var axle_stop_limit_count_v069: int = 0
var axle_component_exception_count_v069: int = 0
var axle_bound_records_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops now hard-stop axle travel instead of relying on collision proxies.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


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
	axle_bound_records_v069.clear()
	axle_stop_limit_count_v069 = 0


func _o_ring_alongs_for_rod_v069(rod: RigidBody3D, axis: Vector3) -> Array:
	var result: Array = []
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

		var connector_lower_rel: float = minf(0.0, lower_center - start_along)
		var connector_upper_rel: float = maxf(0.0, upper_center - start_along)
		if connector_lower_rel > connector_upper_rel:
			connector_lower_rel = 0.0
			connector_upper_rel = 0.0

		# Generic6DOF uses p2-p1 and node_a is the connector, so its translation
		# sign is opposite the connector's geometric travel along the rod.
		var joint_lower: float = -connector_upper_rel
		var joint_upper: float = -connector_lower_rel
		_save_axle_joint_limits_v069(joint)
		joint.set("linear_limit_y/enabled", true)
		joint.set("linear_limit_y/lower_distance", joint_lower)
		joint.set("linear_limit_y/upper_distance", joint_upper)
		joint.solver_priority = maxi(joint.solver_priority, AXLE_SOLVER_PRIORITY_V069)
		joint.set_meta("sim_axle_stop_lower_v069", connector_lower_rel)
		joint.set_meta("sim_axle_stop_upper_v069", connector_upper_rel)
		joint.set_meta("sim_axle_stop_count_v069", stop_count)

		var component: Array = _fixed_component_v020(connector, -1)
		if component.is_empty():
			component = [connector]
		axle_bound_records_v069.append({
			"connector": connector,
			"rod": rod,
			"lower_center": lower_center,
			"upper_center": upper_center,
			"component": component,
			"has_o_ring": stop_count > 0,
		})
		applied += 1
	axle_stop_limit_count_v069 = applied
	return applied


func _apply_component_axis_velocity_delta_v069(component: Array, axis_delta: Vector3) -> void:
	if axis_delta.length_squared() < 0.00000001:
		return
	for member_value in component:
		var member := member_value as RigidBody3D
		if is_instance_valid(member) and not member.freeze:
			member.linear_velocity += axis_delta
			member.sleeping = false


func _translate_component_v069(component: Array, delta: Vector3) -> void:
	if delta.length_squared() < 0.00000001:
		return
	for member_value in component:
		var member := member_value as RigidBody3D
		if is_instance_valid(member) and not member.freeze:
			member.global_position += delta
			member.sleeping = false


# Jolt's 6DOF limit is a solver limit, not continuous collision. A fast loaded
# carriage can penetrate it by a fraction of a unit for one physics step before
# correction. The O-Ring must behave like a real stopper, so we also perform a
# predictive, inelastic travel guard on the SAME axle degree of freedom. It does
# not add a collider or an extra joint and therefore cannot kick the frame.
func _enforce_axle_bounds_v069(delta: float) -> void:
	if not simulating or axle_bound_records_v069.is_empty():
		return
	var dt := maxf(delta, 0.0001)
	for bound_value in axle_bound_records_v069:
		var bound := bound_value as Dictionary
		var connector := bound.get("connector") as RigidBody3D
		var rod := bound.get("rod") as RigidBody3D
		var component := bound.get("component", []) as Array
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var axis := _rod_axis_v020(rod).normalized()
		if axis.length_squared() < 0.5:
			continue
		var lower := float(bound.get("lower_center", -INF))
		var upper := float(bound.get("upper_center", INF))
		var safe_lower := lower + AXLE_STOP_SLOP_V069
		var safe_upper := upper - AXLE_STOP_SLOP_V069
		if safe_lower > safe_upper:
			var midpoint := (lower + upper) * 0.5
			safe_lower = midpoint
			safe_upper = midpoint

		var along := (connector.global_position - rod.global_position).dot(axis)
		if along < safe_lower:
			_translate_component_v069(component, axis * (safe_lower - along))
			along = safe_lower
		elif along > safe_upper:
			_translate_component_v069(component, axis * (safe_upper - along))
			along = safe_upper

		var relative_speed := (connector.linear_velocity - rod.linear_velocity).dot(axis)
		var min_speed := (safe_lower - along) / dt
		var max_speed := (safe_upper - along) / dt
		var clamped_speed := clampf(relative_speed, min_speed, max_speed)
		if absf(clamped_speed - relative_speed) > 0.0001:
			_apply_component_axis_velocity_delta_v069(component, axis * (clamped_speed - relative_speed))


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
	_restore_axle_stop_limits_v069()
	super._prepare_stable_simulation_graph()
	_apply_axle_stop_limits_v069()
	_apply_axle_component_exceptions_v069()


func _physics_process(delta: float) -> void:
	_enforce_axle_bounds_v069(delta)
	super._physics_process(delta)


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
	_status("Physics running — %d axle guide%s hard-bounded by rod ends/O-Rings; %d guide self-collision exception%s active" % [
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
		label.text += "\n\nv0.5.14 AXLE STOPS: O-Rings directly bound axle travel. The old host-rod collision proxy is gone. A solver-native 6DOF travel limit is backed by a predictive non-penetration guard on the same slide degree of freedom, so a loaded connector cannot tunnel through an O-Ring during a fast physics step. The whole fixed carriage is corrected together and its relative velocity into the stop is removed, avoiding the violent collision impulse that caused the device-video instability."


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
