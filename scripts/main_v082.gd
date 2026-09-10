extends "res://scripts/main_v074.gd"

const VERSION_082 := "0.5.16"
const AXLE_PAIR_MIN_SEPARATION_V082 := AXLE_CONNECTOR_HALF_V070 * 2.0
const AXLE_PAIR_PREDICT_MARGIN_V082 := 0.018
const AXLE_PAIR_SUPPORT_EPS_V082 := 0.020
const AXLE_PAIR_SPEED_EPS_V082 := 0.0005

var axle_pair_guard_events_v082: int = 0
var axle_pair_supported_events_v082: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_082)
	_status("v0.5.16 candidate — stable v0.5.15/v074 O-Ring stops plus velocity-only adjacent-hub anti-tunnelling.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_082, text]


# v075 was the first unstable descendant: enabling ranked Generic6DOF Y limits
# turned each otherwise-free AXLE into another hard closed-loop constraint. This
# runtime deliberately starts again from v074, where the long mixed O-Ring test
# has the exact stable v0.5.15 dynamics. The only addition below is pre-step,
# velocity-only adjacent-hub anti-tunnelling. No joint mode, solver priority,
# collision exception, body transform, physics tick rate or force callback is
# changed.

func _component_mass_for_stop_v082(stop: Dictionary) -> float:
	var total := 0.0
	for value in _stop_component_v071(stop):
		var body := value as RigidBody3D
		if is_instance_valid(body):
			total += maxf(body.mass, 0.001)
	return maxf(total, 0.001)


func _finite_lower_supported_v082(stop: Dictionary, along: float) -> bool:
	var lower: float = float(stop.get("lower", -INF))
	return lower > -INF and along <= lower + AXLE_PAIR_SUPPORT_EPS_V082


func _finite_upper_supported_v082(stop: Dictionary, along: float) -> bool:
	var upper: float = float(stop.get("upper", INF))
	return upper < INF and along >= upper - AXLE_PAIR_SUPPORT_EPS_V082


func _set_component_axial_speed_v082(stop: Dictionary, axis: Vector3, current_speed: float, target_speed: float) -> void:
	var delta_speed := target_speed - current_speed
	if absf(delta_speed) <= AXLE_PAIR_SPEED_EPS_V082:
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

		# BUILD order is immutable here. Normal Jolt connector contact remains active
		# and resolves resting/ordinary impacts. We intervene only when an adjacent
		# pair is closing fast enough that its next 60 Hz position would enter the
		# physical hub spacing plus a very small predictive margin.
		for i in range(hubs.size() - 1):
			var lower_info := hubs[i] as Dictionary
			var upper_info := hubs[i + 1] as Dictionary
			var lower_hub := lower_info.get("connector") as RigidBody3D
			var upper_hub := upper_info.get("connector") as RigidBody3D
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
			if closing_speed >= -AXLE_PAIR_SPEED_EPS_V082:
				continue
			var guard_gap: float = AXLE_PAIR_MIN_SEPARATION_V082 + AXLE_PAIR_PREDICT_MARGIN_V082
			if gap + closing_speed * delta >= guard_gap:
				continue

			var lower_mass: float = _component_mass_for_stop_v082(lower_stop)
			var upper_mass: float = _component_mass_for_stop_v082(upper_stop)
			var common_speed: float = (lower_speed * lower_mass + upper_speed * upper_mass) / (lower_mass + upper_mass)
			var common_relative: float = common_speed - rod_speed
			var lower_supported: bool = _finite_lower_supported_v082(lower_stop, lower_along)
			var upper_supported: bool = _finite_upper_supported_v082(upper_stop, upper_along)

			# A finite O-Ring/rod-end stop is allowed to absorb axial momentum. This is
			# critical when the lower hub is already resting on an O-Ring: averaging
			# the incoming upper-hub velocity back into that supported hub creates the
			# clamp/re-add feedback loop that destabilized the later experimental
			# descendants. Keep the supported side stop-safe and dissipate only the
			# forbidden outward component.
			if lower_supported and common_relative < 0.0:
				common_speed = rod_speed
				axle_pair_supported_events_v082 += 1
			elif upper_supported and common_relative > 0.0:
				common_speed = rod_speed
				axle_pair_supported_events_v082 += 1

			_set_component_axial_speed_v082(lower_stop, axis, lower_speed, common_speed)
			_set_component_axial_speed_v082(upper_stop, axis, upper_speed, common_speed)
			axle_pair_guard_events_v082 += 1
			axle_pair_guard_events_v074 += 1


func _prepare_stable_simulation_graph() -> void:
	axle_pair_guard_events_v082 = 0
	axle_pair_supported_events_v082 = 0
	axle_pair_guard_events_v074 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_pair_guard_events_v082 = 0
	axle_pair_supported_events_v082 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — v0.5.15-compatible O-Ring stops; adjacent AXLE hubs keep normal collision with velocity-only anti-tunnelling prediction.")
