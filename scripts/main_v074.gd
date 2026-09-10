extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_STACK_SPACING_V074 := 0.62
const AXLE_HUB_STACK_ACTIVE_DISTANCE_V074 := 0.82
const AXLE_HUB_STACK_EPS_V074 := 0.0001
const AXLE_HUB_STACK_PASSES_V074 := 4

var axle_hub_ccd_events_v074: int = 0
var axle_hub_post_corrections_v074: int = 0


# -----------------------------------------------------------------------------
# O-Ring-local AXLE hub stacking guard
#
# v0.5.15 remains the authority for the actual O-Ring / rod-end boundary. Only
# the original outer hub owns that stop. The extra v0.5.16 logic exists solely
# to prevent another hub from tunnelling through that stopped connector.
#
# Before integration we dissipate only follower motion that would overlap the
# stopped stack. After integration we repair only a residual connector overlap,
# moving the follower-side fixed component while its internal joint frames move
# with it through _shift_stop_component_v071(). The boundary owner and host rod
# are never translated by this guard, ownership never changes, and AXLE slide /
# rotation remain free away from a real stopped stack.
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


func _stack_pair_gap_v074(low: Dictionary, high: Dictionary, rod: RigidBody3D) -> float:
	var low_body := low.get("connector") as RigidBody3D
	var high_body := high.get("connector") as RigidBody3D
	if not is_instance_valid(low_body) or not is_instance_valid(high_body):
		return INF
	return _rod_local_along_v070(high_body, rod) - _rod_local_along_v070(low_body, rod)


func _stack_pair_allowed_closing_v074(low: Dictionary, high: Dictionary, rod: RigidBody3D, delta: float) -> float:
	var gap: float = _stack_pair_gap_v074(low, high, rod)
	if gap >= INF:
		return INF
	return maxf(0.0, (gap - AXLE_HUB_STACK_SPACING_V074) / delta)


func _lower_stack_active_v074(group: Dictionary, rod: RigidBody3D) -> bool:
	var hubs: Array = group.get("hubs", []) as Array
	var lower: float = float(group.get("lower", -INF))
	if hubs.size() < 2 or lower <= -INF:
		return false
	var owner := (hubs[0] as Dictionary).get("connector") as RigidBody3D
	return is_instance_valid(owner) and _rod_local_along_v070(owner, rod) - lower <= AXLE_HUB_STACK_ACTIVE_DISTANCE_V074


func _upper_stack_active_v074(group: Dictionary, rod: RigidBody3D) -> bool:
	var hubs: Array = group.get("hubs", []) as Array
	var upper: float = float(group.get("upper", INF))
	if hubs.size() < 2 or upper >= INF:
		return false
	var owner := (hubs[hubs.size() - 1] as Dictionary).get("connector") as RigidBody3D
	return is_instance_valid(owner) and upper - _rod_local_along_v070(owner, rod) <= AXLE_HUB_STACK_ACTIVE_DISTANCE_V074


func _guard_lower_stack_v074(group: Dictionary, rod: RigidBody3D, axis: Vector3, delta: float) -> bool:
	if not _lower_stack_active_v074(group, rod):
		return false
	var hubs: Array = group.get("hubs", []) as Array
	var changed := false
	for i in range(hubs.size() - 1):
		var leader := hubs[i] as Dictionary
		var follower := hubs[i + 1] as Dictionary
		if _stack_components_overlap_v074(leader, follower):
			continue
		var allowed: float = _stack_pair_allowed_closing_v074(leader, follower, rod, delta)
		var leader_speed: float = _stack_axis_speed_v074(leader, axis, rod)
		var follower_speed: float = _stack_axis_speed_v074(follower, axis, rod)
		# Inward at the lower stop is negative. Do not launch the follower upward
		# if the leader happens to rebound; only remove excessive inward motion.
		var minimum_follower_speed: float = minf(0.0, leader_speed) - allowed
		if follower_speed < minimum_follower_speed - AXLE_HUB_STACK_EPS_V074:
			_stack_apply_axis_delta_v074(follower, axis, minimum_follower_speed - follower_speed)
			axle_hub_ccd_events_v074 += 1
			changed = true
	return changed


func _guard_upper_stack_v074(group: Dictionary, rod: RigidBody3D, axis: Vector3, delta: float) -> bool:
	if not _upper_stack_active_v074(group, rod):
		return false
	var hubs: Array = group.get("hubs", []) as Array
	var changed := false
	for offset in range(hubs.size() - 1):
		var high_index: int = hubs.size() - 1 - offset
		var leader := hubs[high_index] as Dictionary
		var follower := hubs[high_index - 1] as Dictionary
		if _stack_components_overlap_v074(follower, leader):
			continue
		var allowed: float = _stack_pair_allowed_closing_v074(follower, leader, rod, delta)
		var leader_speed: float = _stack_axis_speed_v074(leader, axis, rod)
		var follower_speed: float = _stack_axis_speed_v074(follower, axis, rod)
		# Inward at the upper stop is positive. Do not launch the follower downward
		# if the leader rebounds; only remove excessive inward motion.
		var maximum_follower_speed: float = maxf(0.0, leader_speed) + allowed
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


func _correct_lower_stack_v074(group: Dictionary, rod: RigidBody3D, axis: Vector3) -> bool:
	if not _lower_stack_active_v074(group, rod):
		return false
	var hubs: Array = group.get("hubs", []) as Array
	var upper: float = float(group.get("upper", INF))
	var changed := false
	for i in range(hubs.size() - 1):
		var leader := hubs[i] as Dictionary
		var follower := hubs[i + 1] as Dictionary
		if _stack_components_overlap_v074(leader, follower):
			continue
		var gap: float = _stack_pair_gap_v074(leader, follower, rod)
		if gap >= AXLE_HUB_STACK_SPACING_V074 - AXLE_HUB_STACK_EPS_V074:
			continue
		var correction: float = AXLE_HUB_STACK_SPACING_V074 - gap
		# If this follower is also the far-side boundary owner, never push it past
		# that real boundary. Tight impossible stacks receive only available room.
		if i + 1 == hubs.size() - 1 and upper < INF:
			var follower_body := follower.get("connector") as RigidBody3D
			if is_instance_valid(follower_body):
				correction = minf(correction, maxf(0.0, upper - _rod_local_along_v070(follower_body, rod)))
		if correction <= AXLE_HUB_STACK_EPS_V074:
			continue
		_shift_stop_component_v071(follower, axis * correction)
		var leader_speed: float = _stack_axis_speed_v074(leader, axis, rod)
		var follower_speed: float = _stack_axis_speed_v074(follower, axis, rod)
		var minimum_follower_speed: float = minf(0.0, leader_speed)
		if follower_speed < minimum_follower_speed:
			_stack_apply_axis_delta_v074(follower, axis, minimum_follower_speed - follower_speed)
		axle_hub_post_corrections_v074 += 1
		changed = true
	return changed


func _correct_upper_stack_v074(group: Dictionary, rod: RigidBody3D, axis: Vector3) -> bool:
	if not _upper_stack_active_v074(group, rod):
		return false
	var hubs: Array = group.get("hubs", []) as Array
	var lower: float = float(group.get("lower", -INF))
	var changed := false
	for offset in range(hubs.size() - 1):
		var high_index: int = hubs.size() - 1 - offset
		var leader := hubs[high_index] as Dictionary
		var follower := hubs[high_index - 1] as Dictionary
		if _stack_components_overlap_v074(follower, leader):
			continue
		var gap: float = _stack_pair_gap_v074(follower, leader, rod)
		if gap >= AXLE_HUB_STACK_SPACING_V074 - AXLE_HUB_STACK_EPS_V074:
			continue
		var correction: float = AXLE_HUB_STACK_SPACING_V074 - gap
		if high_index - 1 == 0 and lower > -INF:
			var follower_body := follower.get("connector") as RigidBody3D
			if is_instance_valid(follower_body):
				correction = minf(correction, maxf(0.0, _rod_local_along_v070(follower_body, rod) - lower))
		if correction <= AXLE_HUB_STACK_EPS_V074:
			continue
		_shift_stop_component_v071(follower, -axis * correction)
		var leader_speed: float = _stack_axis_speed_v074(leader, axis, rod)
		var follower_speed: float = _stack_axis_speed_v074(follower, axis, rod)
		var maximum_follower_speed: float = maxf(0.0, leader_speed)
		if follower_speed > maximum_follower_speed:
			_stack_apply_axis_delta_v074(follower, axis, maximum_follower_speed - follower_speed)
		axle_hub_post_corrections_v074 += 1
		changed = true
	return changed


func _correct_axle_hub_stack_positions_v074() -> bool:
	if not simulating:
		return false
	var any_changed := false
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		any_changed = _correct_lower_stack_v074(group, rod, axis) or any_changed
		any_changed = _correct_upper_stack_v074(group, rod, axis) or any_changed
	return any_changed


# Disable the abandoned ownership-swap path. Stop ownership remains exactly as
# v0.5.15 built it for the entire simulation.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _predict_axle_stops_v071(delta: float) -> void:
	for _pass in range(AXLE_HUB_STACK_PASSES_V074):
		super._predict_axle_stops_v071(delta)
		if not _predict_axle_hub_stack_v074(delta):
			return
	super._predict_axle_stops_v071(delta)


func _correct_axle_stop_positions_v071() -> void:
	# Parent v0.5.15/v0.5.16 stop correction first puts the real boundary owner
	# back at its O-Ring/rod-end. Then repair only any small follower overlap that
	# survived Jolt. No second ownership correction or symmetric impulse follows.
	super._correct_axle_stop_positions_v071()
	_correct_axle_hub_stack_positions_v074()


func _prepare_stable_simulation_graph() -> void:
	axle_hub_ccd_events_v074 = 0
	axle_hub_post_corrections_v074 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_hub_ccd_events_v074 = 0
	axle_hub_post_corrections_v074 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
