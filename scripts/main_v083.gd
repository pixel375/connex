extends "res://scripts/main_v074.gd"

const VERSION_083 := "0.5.16"
# This is deliberately far below the ~0.53 natural resting center gap observed
# for two colliding axle hubs. It is an order/tunnelling guard, not a substitute
# contact solver.
const AXLE_PAIR_TUNNEL_GUARD_V083 := 0.080
const AXLE_PAIR_SUPPORT_EPS_V083 := 0.020
const AXLE_PAIR_SPEED_EPS_V083 := 0.0005

var axle_pair_guard_events_v083: int = 0
var axle_pair_supported_events_v083: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_083)
	_status("v0.5.16 candidate — stable v074 O-Ring physics with a sparse would-cross velocity guard only.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_083, text]


func _component_mass_for_stop_v083(stop: Dictionary) -> float:
	var total := 0.0
	for value in _stop_component_v071(stop):
		var body := value as RigidBody3D
		if is_instance_valid(body):
			total += maxf(body.mass, 0.001)
	return maxf(total, 0.001)


func _lower_boundary_support_v083(stop: Dictionary, along: float) -> bool:
	var lower: float = float(stop.get("lower", -INF))
	return lower > -INF and along <= lower + AXLE_PAIR_SUPPORT_EPS_V083


func _upper_boundary_support_v083(stop: Dictionary, along: float) -> bool:
	var upper: float = float(stop.get("upper", INF))
	return upper < INF and along >= upper - AXLE_PAIR_SUPPORT_EPS_V083


func _set_component_axial_speed_v083(stop: Dictionary, axis: Vector3, current_speed: float, target_speed: float) -> void:
	var delta_speed := target_speed - current_speed
	if absf(delta_speed) <= AXLE_PAIR_SPEED_EPS_V083:
		return
	_shift_component_velocity_v071(stop, axis * delta_speed)


func _predict_axle_order_v073(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		var hubs: Array = group.get("hubs", []) as Array
		if not is_instance_valid(rod) or hubs.size() <= 1 or not _group_has_o_ring_v074(group):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		if axis.length_squared() < 0.5:
			continue
		var rod_speed: float = rod.linear_velocity.dot(axis)
		var segment: int = int(group.get("segment", 0))

		for i in range(hubs.size() - 1):
			var lower_hub := (hubs[i] as Dictionary).get("connector") as RigidBody3D
			var upper_hub := (hubs[i + 1] as Dictionary).get("connector") as RigidBody3D
			if not is_instance_valid(lower_hub) or not is_instance_valid(upper_hub):
				continue
			var lower_stop: Dictionary = _find_stop_v074(rod, lower_hub, segment)
			var upper_stop: Dictionary = _find_stop_v074(rod, upper_hub, segment)
			if lower_stop.is_empty() or upper_stop.is_empty():
				continue

			var lower_along: float = _rod_local_along_v070(lower_hub, rod)
			var upper_along: float = _rod_local_along_v070(upper_hub, rod)
			var gap: float = upper_along - lower_along
			var lower_speed: float = lower_hub.linear_velocity.dot(axis)
			var upper_speed: float = upper_hub.linear_velocity.dot(axis)
			var closing_speed: float = upper_speed - lower_speed
			if closing_speed >= -AXLE_PAIR_SPEED_EPS_V083:
				continue

			# Normal collision owns the entire physical contact region. Intervene only
			# if current velocity would put the BUILD-order pair at/through the tiny
			# order guard on the next step.
			if gap + closing_speed * delta >= AXLE_PAIR_TUNNEL_GUARD_V083:
				continue

			var lower_mass: float = _component_mass_for_stop_v083(lower_stop)
			var upper_mass: float = _component_mass_for_stop_v083(upper_stop)
			var common_speed: float = (lower_speed * lower_mass + upper_speed * upper_mass) / (lower_mass + upper_mass)
			var common_relative: float = common_speed - rod_speed
			var lower_supported: bool = _lower_boundary_support_v083(lower_stop, lower_along)
			var upper_supported: bool = _upper_boundary_support_v083(upper_stop, upper_along)

			# A finite stop can absorb forbidden axial momentum. Never feed an incoming
			# hub's outward velocity back into a hub already supported by its O-Ring or
			# rod end.
			if lower_supported and common_relative < 0.0:
				common_speed = rod_speed
				axle_pair_supported_events_v083 += 1
			elif upper_supported and common_relative > 0.0:
				common_speed = rod_speed
				axle_pair_supported_events_v083 += 1

			_set_component_axial_speed_v083(lower_stop, axis, lower_speed, common_speed)
			_set_component_axial_speed_v083(upper_stop, axis, upper_speed, common_speed)
			axle_pair_guard_events_v083 += 1
			axle_pair_guard_events_v074 += 1


func _prepare_stable_simulation_graph() -> void:
	axle_pair_guard_events_v083 = 0
	axle_pair_supported_events_v083 = 0
	axle_pair_guard_events_v074 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_pair_guard_events_v083 = 0
	axle_pair_supported_events_v083 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — ordinary AXLE hub collision is untouched; a sparse velocity-only guard acts only on imminent hub order crossing.")
