extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_CCD_SPACING_V074 := 0.62
const AXLE_HUB_CCD_EPS_V074 := 0.0001
const AXLE_HUB_CCD_MAX_PASSES_V074 := 4

var axle_hub_ccd_events_v074: int = 0


# -----------------------------------------------------------------------------
# AXLE hub continuous collision
#
# Keep v0.5.15's proven O-Ring ownership exactly as built: the original
# outermost AXLE hubs own the O-Ring / rod-end boundaries for their segment.
# The missing case is hub-vs-hub tunnelling after an outer hub reaches a stop.
#
# Resolve only the one-dimensional axial approach before integration. For each
# adjacent hub pair, reduce only the amount of relative closing speed that would
# place their centers inside the physical connector thickness next frame.
# Velocity changes are mass-weighted and equal/opposite across each connector's
# fixed component, so axial linear momentum is conserved. No transform, angular
# velocity, O-Ring ownership, host-rod velocity, or AXLE joint limit is changed.
# -----------------------------------------------------------------------------

func _ccd_component_v074(hub_info: Dictionary) -> Array:
	var cached := hub_info.get("ccd_component_v074", []) as Array
	var valid := not cached.is_empty()
	if valid:
		for value in cached:
			if not is_instance_valid(value):
				valid = false
				break
	if valid:
		return cached
	var component: Array = _stop_component_v071(hub_info)
	hub_info["ccd_component_v074"] = component
	return component


func _ccd_dynamic_mass_v074(hub_info: Dictionary) -> float:
	var total := 0.0
	for value in _ccd_component_v074(hub_info):
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		total += maxf(body.mass, 0.0001)
	return total


func _ccd_components_overlap_v074(a: Dictionary, b: Dictionary) -> bool:
	var ids: Dictionary = {}
	for value in _ccd_component_v074(a):
		var body := value as RigidBody3D
		if is_instance_valid(body):
			ids[body.get_instance_id()] = true
	for value in _ccd_component_v074(b):
		var body := value as RigidBody3D
		if is_instance_valid(body) and ids.has(body.get_instance_id()):
			return true
	return false


func _ccd_apply_velocity_delta_v074(hub_info: Dictionary, delta_velocity: Vector3) -> void:
	if delta_velocity.length_squared() <= 0.0000000001:
		return
	for value in _ccd_component_v074(hub_info):
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		body.linear_velocity += delta_velocity
		body.sleeping = false


func _ccd_hub_axis_speed_v074(hub_info: Dictionary, axis: Vector3, rod: RigidBody3D) -> float:
	var connector := hub_info.get("connector") as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return 0.0
	return (connector.linear_velocity - rod.linear_velocity).dot(axis)


func _resolve_axle_hub_pair_v074(low: Dictionary, high: Dictionary, rod: RigidBody3D, axis: Vector3, delta: float) -> bool:
	var low_body := low.get("connector") as RigidBody3D
	var high_body := high.get("connector") as RigidBody3D
	if not is_instance_valid(low_body) or not is_instance_valid(high_body):
		return false
	if low_body.freeze and high_body.freeze:
		return false
	if _ccd_components_overlap_v074(low, high):
		return false

	var low_along: float = _rod_local_along_v070(low_body, rod)
	var high_along: float = _rod_local_along_v070(high_body, rod)
	var gap: float = high_along - low_along
	# If a previous physics step already produced a small penetration, do not
	# teleport either body. We only stop further closing; Jolt can separate the
	# existing overlap through its normal connector collision response.
	var allowed_closing: float = maxf(0.0, (gap - AXLE_HUB_CCD_SPACING_V074) / delta)
	var low_speed: float = _ccd_hub_axis_speed_v074(low, axis, rod)
	var high_speed: float = _ccd_hub_axis_speed_v074(high, axis, rod)
	var closing_speed: float = low_speed - high_speed
	if closing_speed <= allowed_closing + AXLE_HUB_CCD_EPS_V074:
		return false

	var low_mass: float = _ccd_dynamic_mass_v074(low)
	var high_mass: float = _ccd_dynamic_mass_v074(high)
	if low_mass <= 0.0001 or high_mass <= 0.0001:
		return false

	var remove_relative: float = closing_speed - allowed_closing
	var impulse: float = remove_relative / (1.0 / low_mass + 1.0 / high_mass)
	var low_delta: float = -impulse / low_mass
	var high_delta: float = impulse / high_mass
	_ccd_apply_velocity_delta_v074(low, axis * low_delta)
	_ccd_apply_velocity_delta_v074(high, axis * high_delta)
	axle_hub_ccd_events_v074 += 1
	return true


func _predict_axle_hub_ccd_v074(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var hubs: Array = group.get("hubs", []) as Array
		if hubs.size() < 2:
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		# A few projected Gauss-Seidel passes are enough for a short hub stack.
		# Every pair update is momentum-conserving, and normally no pass fires at
		# all until two hubs are genuinely on course to overlap next frame.
		var pass_count: int = mini(AXLE_HUB_CCD_MAX_PASSES_V074, hubs.size() + 1)
		for _pass in range(pass_count):
			var changed := false
			for i in range(hubs.size() - 1):
				if _resolve_axle_hub_pair_v074(hubs[i] as Dictionary, hubs[i + 1] as Dictionary, rod, axis, delta):
					changed = true
			if not changed:
				break


# Disable v0.5.16's experimental ownership-swap path. Boundary ownership stays
# exactly as produced by _build_axle_stop_ranges_v070(), matching v0.5.15.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _predict_axle_stops_v071(delta: float) -> void:
	# Prevent adjacent AXLE hubs from tunnelling first, then run the proven
	# v0.5.15 O-Ring / rod-end predictive stop on the unchanged boundary owner.
	_predict_axle_hub_ccd_v074(delta)
	super._predict_axle_stops_v071(delta)


func _prepare_stable_simulation_graph() -> void:
	axle_hub_ccd_events_v074 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_hub_ccd_events_v074 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
