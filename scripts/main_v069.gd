extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
# Physical connector/O-Ring center clearance. Jolt's Generic6DOF hard linear
# limit can transiently overshoot by about 0.22 units during an asymmetric
# ground impact, so arm the solver slightly early while continuing to validate
# the true physical clearance separately in regression tests.
const O_RING_AXLE_CLEARANCE_V069 := 0.43
const O_RING_AXLE_SOLVER_MARGIN_V069 := 0.27
const O_RING_AXLE_LIMIT_CLEARANCE_V069 := O_RING_AXLE_CLEARANCE_V069 + O_RING_AXLE_SOLVER_MARGIN_V069
const O_RING_UNBOUNDED_TRAVEL_V069 := 1000.0

var o_ring_stop_pair_count_v069: int = 0
var o_ring_axle_limit_restore_v069: Array = []
# Kept as an empty compatibility/debug surface so a regression can prove that
# the abandoned moving-proxy implementation is not recreated.
var o_ring_stop_proxies_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops now bound the axle joint's real sliding degree of freedom.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# v0.5.13 copied O-Ring collision into the host rod, but the axle joint excludes
# connector-vs-host collision. Keep that broken route permanently disabled.
func _add_o_ring_proxy_shapes_v068(_ring: RigidBody3D, _rod: RigidBody3D) -> int:
	return 0


func _restore_o_ring_axle_limits_v069() -> void:
	for value in o_ring_axle_limit_restore_v069:
		var state := value as Dictionary
		var joint := state.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			continue
		joint.set("linear_limit_y/enabled", bool(state.get("enabled", false)))
		joint.set("linear_limit_y/lower_distance", float(state.get("lower", 0.0)))
		joint.set("linear_limit_y/upper_distance", float(state.get("upper", 0.0)))
		joint.remove_meta("sim_o_ring_axle_limit_v069")
	o_ring_axle_limit_restore_v069.clear()
	o_ring_stop_pair_count_v069 = 0
	o_ring_stop_proxies_v069.clear()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_o_ring_axle_limits_v069()
	super._restore_o_ring_followers_v068(restore_build_pose)


func _o_ring_alongs_for_rod_v069(rod: RigidBody3D) -> Array:
	var result: Array = []
	if not is_instance_valid(rod):
		return result
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	if axis.length_squared() < 0.5:
		return result
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		if follower.get("rod") != rod:
			continue
		var ring := follower.get("ring") as RigidBody3D
		if not is_instance_valid(ring):
			continue
		result.append((ring.global_position - rod.global_position).dot(axis))
	return result


func _configure_o_ring_stoppers_v069() -> int:
	_restore_o_ring_axle_limits_v069()
	var configured_pairs := 0

	# main_v068 has already converted each visible O-Ring into a collisionless
	# follower of its host rod. connections_v020 was rebuilt immediately before
	# that conversion, so its AXLE records still point at the authoritative axle
	# joint. Bound only that joint's Y slide; X/Z and rotation behavior are left
	# exactly as the axle implementation defines them.
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		var joint := record.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(connector) or not is_instance_valid(rod) or not is_instance_valid(joint):
			continue

		var ring_alongs: Array = _o_ring_alongs_for_rod_v069(rod)
		if ring_alongs.is_empty():
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		if axis.length_squared() < 0.5:
			continue
		var hub_along: float = (connector.global_position - rod.global_position).dot(axis)
		var lower_limit := -O_RING_UNBOUNDED_TRAVEL_V069
		var upper_limit := O_RING_UNBOUNDED_TRAVEL_V069
		var has_lower := false
		var has_upper := false

		for ring_along_value in ring_alongs:
			var ring_along := float(ring_along_value)
			var delta := ring_along - hub_along
			if delta < 0.0:
				# Arm before contact by the measured Jolt solver margin. The test still
				# measures actual hub/ring separation and rejects physical crossing.
				lower_limit = maxf(lower_limit, delta + O_RING_AXLE_LIMIT_CLEARANCE_V069)
				has_lower = true
				configured_pairs += 1
			elif delta > 0.0:
				upper_limit = minf(upper_limit, delta - O_RING_AXLE_LIMIT_CLEARANCE_V069)
				has_upper = true
				configured_pairs += 1
			else:
				# Exact overlap is already an invalid build pose. Lock this run at the
				# current slide coordinate rather than injecting a corrective impulse.
				lower_limit = 0.0
				upper_limit = 0.0
				has_lower = true
				has_upper = true
				configured_pairs += 1

		if not has_lower and not has_upper:
			continue
		# Never start a run with an inverted interval. If an edited build already
		# overlaps two opposing stops, hold the current position instead of asking
		# the solver to teleport the assembly out of penetration.
		if lower_limit > upper_limit:
			lower_limit = 0.0
			upper_limit = 0.0

		o_ring_axle_limit_restore_v069.append({
			"joint": joint,
			"enabled": bool(joint.get("linear_limit_y/enabled")),
			"lower": float(joint.get("linear_limit_y/lower_distance")),
			"upper": float(joint.get("linear_limit_y/upper_distance")),
		})
		joint.set("linear_limit_y/lower_distance", lower_limit)
		joint.set("linear_limit_y/upper_distance", upper_limit)
		joint.set("linear_limit_y/enabled", true)
		joint.set_meta("sim_o_ring_axle_limit_v069", true)
		connector.sleeping = false
		rod.sleeping = false

	o_ring_stop_pair_count_v069 = configured_pairs
	return configured_pairs


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	_configure_o_ring_stoppers_v069()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d O-Ring/axle stop relation%s active on native axle limits; no proxy collider or O-Ring weld" % [
		o_ring_stop_pair_count_v069,
		"" if o_ring_stop_pair_count_v069 == 1 else "s"
	])


func _reset_pose() -> void:
	_restore_o_ring_axle_limits_v069()
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_restore_o_ring_axle_limits_v069()
	super._restore_state(snapshot)


func _restart_build() -> void:
	_restore_o_ring_axle_limits_v069()
	super._restart_build()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.14 O-RING STOPPER: the broken v0.5.13 host-rod collision proxy and the experimental moving proxy body are both removed. The visible O-Ring remains a collisionless follower of its axle during SIMULATE. Each connector already mounted as AXLE on that rod gets a temporary lower/upper bound on the same Generic6DOF Y slide it already uses, calculated from the nearest O-Ring positions and physical hub clearance. A small measured solver guard band arms the hard stop before contact so Jolt's transient impact slop cannot let the hub visibly cross the ring. No collision mass, world-following collider, second joint, frame correction, or over-constrained solver loop is added. BUILD/Restore returns the axle joint to its original free-slide state."


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
