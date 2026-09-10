extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_STACK_SPACING_V074 := 0.62
const AXLE_HUB_STACK_ACTIVE_DISTANCE_V074 := 0.82
const AXLE_HUB_STACK_EPS_V074 := 0.0001
const AXLE_HUB_STACK_PASSES_V074 := 4

var axle_hub_ccd_events_v074: int = 0


# -----------------------------------------------------------------------------
# O-Ring-local AXLE hub stacking guard
#
# v0.5.15 is stable when the outer hub owns the real O-Ring / rod-end stop.
# Its remaining failure mode is narrowly defined: once that owner is stopped,
# another AXLE hub can occasionally tunnel through it in one Jolt step and then
# reach the O-Ring itself.
#
# Do not create ranked floors, swap ownership, move bodies, or exchange impulses
# with the stopped owner. Only while an owner is physically near its boundary,
# cap an approaching follower's axial speed so its center cannot enter the
# connector ahead of it on the next step. The cap is dissipative: it can remove
# inward relative motion, but it never launches a follower away from the stop.
# -----------------------------------------------------------------------------

func _stack_component_v074(hub_info: Dictionary) -> Array:
	var cached := hub_info.get("stack_component_v074", []) as Array
	var valid := not cached.is_empty()
	if valid:
		for value in cached:
			if not is_instance_valid(value):
				valid = false
				break
	if valid:
		return cached
	var component: Array = _stop_component_v071(hub_info)
	hub_info["stack_component_v074"] = component
	return component


func _stack_components_overlap_v074(a: Dictionary, b: Dictionary) -> bool:
	var ids: Dictionary = {}
	for value in _stack_component_v074(a):
		var body := value as RigidBody3D
		if is_instance_valid(body):
			ids[body.get_instance_id()] = true
	for value in _stack_component_v074(b):
		var body := value as RigidBody3D
		if is_instance_valid(body) and ids.has(body.get_instance_id()):
			return true
	return false


func _stack_apply_axis_delta_v074(hub_info: Dictionary, axis: Vector3, amount: float) -> void:
	if absf(amount) <= 0.000001:
		return
	for value in _stack_component_v074(hub_info):
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		body.linear_velocity += axis * amount
		body.sleeping = false


func _stack_axis_speed_v074(hub_info: Dictionary, axis: Vector3, rod: RigidBody3D) -> float:
	var connector := hub_info.get("connector") as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return 0.0
	return (connector.linear_velocity - rod.linear_velocity).dot(axis)


func _stack_pair_allowed_closing_v074(a: Dictionary, b: Dictionary, rod: RigidBody3D, delta: float) -> float:
	var body_a := a.get("connector") as RigidBody3D
	var body_b := b.get("connector") as RigidBody3D
	if not is_instance_valid(body_a) or not is_instance_valid(body_b):
		return INF
	var gap: float = _rod_local_along_v070(body_b, rod) - _rod_local_along_v070(body_a, rod)
	return maxf(0.0, (gap - AXLE_HUB_STACK_SPACING_V074) / delta)


func _guard_lower_stack_v074(group: Dictionary, rod: RigidBody3D, axis: Vector3, delta: float) -> bool:
	var hubs: Array = group.get("hubs", []) as Array
	if hubs.size() < 2:
		return false
	var lower: float = float(group.get("lower", -INF))
	if lower <= -INF:
		return false
	var owner := (hubs[0] as Dictionary).get("connector") as RigidBody3D
	if not is_instance_valid(owner):
		return false
	var owner_along: float = _rod_local_along_v070(owner, rod)
	if owner_along - lower > AXLE_HUB_STACK_ACTIVE_DISTANCE_V074:
		return false

	var changed := false
	# Propagate from the lower stop outward. Each upper follower is allowed to
	# approach the hub below it only as fast as the remaining physical gap permits.
	for i in range(hubs.size() - 1):
		var leader := hubs[i] as Dictionary
		var follower := hubs[i + 1] as Dictionary
		if _stack_components_overlap_v074(leader, follower):
			continue
		var allowed: float = _stack_pair_allowed_closing_v074(leader, follower, rod, delta)
		var leader_speed: float = _stack_axis_speed_v074(leader, axis, rod)
		var follower_speed: float = _stack_axis_speed_v074(follower, axis, rod)
		# Lower-boundary inward motion is negative. Never accelerate a follower
		# upward just because the leader is rebounding away from the stop.
		var reference_speed: float = minf(0.0, leader_speed)
		var minimum_follower_speed: float = reference_speed - allowed
		if follower_speed < minimum_follower_speed - AXLE_HUB_STACK_EPS_V074:
			_stack_apply_axis_delta_v074(follower, axis, minimum_follower_speed - follower_speed)
			axle_hub_ccd_events_v074 += 1
			changed = true
	return changed


func _guard_upper_stack_v074(group: Dictionary, rod: RigidBody3D, axis: Vector3, delta: float) -> bool:
	var hubs: Array = group.get("hubs", []) as Array
	if hubs.size() < 2:
		return false
	var upper: float = float(group.get("upper", INF))
	if upper >= INF:
		return false
	var owner := (hubs[hubs.size() - 1] as Dictionary).get("connector") as RigidBody3D
	if not is_instance_valid(owner):
		return false
	var owner_along: float = _rod_local_along_v070(owner, rod)
	if upper - owner_along > AXLE_HUB_STACK_ACTIVE_DISTANCE_V074:
		return false

	var changed := false
	# Propagate from the upper stop inward. Each lower follower is allowed to
	# approach the hub above it only as fast as the remaining physical gap permits.
	for offset in range(hubs.size() - 1):
		var high_index: int = hubs.size() - 1 - offset
		var leader := hubs[high_index] as Dictionary
		var follower := hubs[high_index - 1] as Dictionary
		if _stack_components_overlap_v074(follower, leader):
			continue
		var allowed: float = _stack_pair_allowed_closing_v074(follower, leader, rod, delta)
		var leader_speed: float = _stack_axis_speed_v074(leader, axis, rod)
		var follower_speed: float = _stack_axis_speed_v074(follower, axis, rod)
		# Upper-boundary inward motion is positive. Never accelerate a follower
		# downward just because the leader is rebounding away from the stop.
		var reference_speed: float = maxf(0.0, leader_speed)
		var maximum_follower_speed: float = reference_speed + allowed
		if follower_speed > maximum_follower_speed + AXLE_HUB_STACK_EPS_V074:
			_stack_apply_axis_delta_v074(follower, axis, maximum_follower_speed - follower_speed)
			axle_hub_ccd_events_v074 += 1
			changed = true
	return changed


func _predict_axle_hub_stack_v074(delta: float) -> bool:
	if not simulating or delta <= 0.000001:
		return false
	var any_changed := false
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		any_changed = _guard_lower_stack_v074(group, rod, axis, delta) or any_changed
		any_changed = _guard_upper_stack_v074(group, rod, axis, delta) or any_changed
	return any_changed


# Disable the abandoned ownership-swap path. Stop ownership remains exactly as
# v0.5.15 built it for the entire simulation.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _predict_axle_stops_v071(delta: float) -> void:
	# First let the proven O-Ring predictor settle the actual boundary owner.
	# Then, only near that boundary, dissipate follower motion that would tunnel
	# through the stopped connector. A few passes propagate the stopped stack
	# through 3+ hubs without ever moving the O-Ring owner itself.
	for _pass in range(AXLE_HUB_STACK_PASSES_V074):
		super._predict_axle_stops_v071(delta)
		if not _predict_axle_hub_stack_v074(delta):
			return
	super._predict_axle_stops_v071(delta)


func _prepare_stable_simulation_graph() -> void:
	axle_hub_ccd_events_v074 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_hub_ccd_events_v074 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
