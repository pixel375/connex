extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_PAIR_GUARD_SPACING_V074 := 0.60

# Number of AXLE hubs participating in multi-hub segments on rods that contain
# at least one O-Ring. Kept under the old debug name for test compatibility.
var axle_ranked_stop_count_v074: int = 0
var axle_pair_guard_events_v074: int = 0

# Compatibility/debug surfaces for abandoned experiments. They stay inactive.
var o_ring_precision_ticks_active_v074: bool = false
var saved_physics_ticks_v074: int = -1
var axle_order_repair_events_v074: int = 0
var axle_stack_shape_state_v074: Array = []
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring simulation
#
# Keep the released v0.5.15 O-Ring stop topology and the normal project physics
# cadence:
#
# - O-Rings are collisionless exact rod-local followers;
# - the normal AXLE joint remains free in axial slide and rotation;
# - only the original outer hub owns each finite O-Ring / rod-end stop;
# - ordinary connector collision remains the visible/physical stack behavior;
# - physics stays at the project-default tick rate (60 Hz).
#
# The actual failure in larger assemblies was rare hub-through-hub tunnelling.
# Post-facto transform repairs and 120 Hz both proved destabilizing. v0.5.16
# instead adds one narrow predictive contact rule between adjacent AXLE hubs on
# an O-Ring-bearing rod. Only when their current relative axial velocity predicts
# that they will enter the normal ~0.60 hub contact spacing during the NEXT step,
# apply a one-dimensional perfectly-inelastic contact impulse along the rod axis.
#
# The impulse is split between the two connector-side fixed components by inverse
# mass, so total axial momentum is conserved while closing relative kinetic energy
# can only decrease. No body transform, O-Ring coordinate, collision shape, joint
# limit, or persistent rank boundary is changed. Once the pair is not closing,
# the guard is completely dormant.
# -----------------------------------------------------------------------------

func _find_stop_v074(rod: RigidBody3D, connector: RigidBody3D, segment: int) -> Dictionary:
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		if stop.get("rod") == rod and stop.get("connector") == connector and int(stop.get("segment", -999)) == segment:
			return stop
	return {}


func _group_has_o_ring_v074(group: Dictionary) -> bool:
	var rod := group.get("rod") as RigidBody3D
	var segment: int = int(group.get("segment", 0))
	if not is_instance_valid(rod):
		return false
	for hub_value in group.get("hubs", []) as Array:
		var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
		var stop: Dictionary = _find_stop_v074(rod, connector, segment)
		if not stop.is_empty() and int(stop.get("ring_count", 0)) > 0:
			return true
	return false


func _count_complex_o_ring_hubs_v074() -> int:
	var count := 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var hubs: Array = group.get("hubs", []) as Array
		if hubs.size() > 1 and _group_has_o_ring_v074(group):
			count += hubs.size()
	return count


func _build_axle_stop_ranges_v070() -> void:
	# v073 builds the stable v0.5.15 outer-owner ranges and remembers BUILD order.
	# Do not rewrite any stop boundary/ownership or change Engine tick rate here.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()


func _guard_adjacent_axle_pair_v074(group: Dictionary, lower_info: Dictionary, upper_info: Dictionary, delta: float) -> bool:
	var rod := group.get("rod") as RigidBody3D
	var segment: int = int(group.get("segment", 0))
	var lower := lower_info.get("connector") as RigidBody3D
	var upper := upper_info.get("connector") as RigidBody3D
	if not is_instance_valid(rod) or not is_instance_valid(lower) or not is_instance_valid(upper):
		return false

	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var lower_along: float = _rod_local_along_v070(lower, rod)
	var upper_along: float = _rod_local_along_v070(upper, rod)
	var gap: float = upper_along - lower_along
	if gap <= 0.0:
		# Never hide a missed tunnel with post-facto position repair.
		return false

	var relative_speed: float = (upper.linear_velocity - lower.linear_velocity).dot(axis)
	if relative_speed >= 0.0:
		return false
	var predicted_gap: float = gap + relative_speed * delta
	if predicted_gap >= AXLE_HUB_PAIR_GUARD_SPACING_V074:
		return false

	# Permit the most closing speed that lands exactly at the contact guard next
	# step. If already inside that spacing, prevent further closing but do not
	# separate or teleport the hubs.
	var allowed_relative: float = minf(0.0, (AXLE_HUB_PAIR_GUARD_SPACING_V074 - gap) / delta)
	var relative_change: float = allowed_relative - relative_speed
	if relative_change <= 0.000001:
		return false

	var lower_stop: Dictionary = _find_stop_v074(rod, lower, segment)
	var upper_stop: Dictionary = _find_stop_v074(rod, upper, segment)
	if lower_stop.is_empty() or upper_stop.is_empty():
		return false
	var lower_component: Array = _stop_component_v071(lower_stop)
	var upper_component: Array = _stop_component_v071(upper_stop)
	if lower_component.is_empty() or upper_component.is_empty() or _components_overlap_v070(lower_component, upper_component):
		return false

	var inv_lower: float = _component_inverse_mass_v070(lower_component)
	var inv_upper: float = _component_inverse_mass_v070(upper_component)
	var inv_sum: float = inv_lower + inv_upper
	if inv_sum <= 0.000001:
		return false

	# 1-D inelastic contact impulse. The inverse-mass split makes the summed axial
	# momentum change zero while increasing relative speed only toward zero.
	var lower_delta_speed: float = -relative_change * inv_lower / inv_sum
	var upper_delta_speed: float = relative_change * inv_upper / inv_sum
	_shift_component_velocity_v071(lower_stop, axis * lower_delta_speed)
	_shift_component_velocity_v071(upper_stop, axis * upper_delta_speed)
	axle_pair_guard_events_v074 += 1
	return true


func _predict_axle_order_v073(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var hubs: Array = group.get("hubs", []) as Array
		if hubs.size() <= 1 or not _group_has_o_ring_v074(group):
			continue
		for i in range(hubs.size() - 1):
			_guard_adjacent_axle_pair_v074(group, hubs[i] as Dictionary, hubs[i + 1] as Dictionary, delta)


# Disable v073's post-facto ownership transfer. A missed inversion remains a hard
# regression failure instead of translating an already-overlapped assembly.
func _correct_axle_order_v073() -> bool:
	return false


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return

	# Apply only the released v0.5.15 finite boundary correction. Pairwise hub
	# protection is predictive and velocity-only.
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		var connector := stop.get("connector") as RigidBody3D
		var rod := stop.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		var along: float = _rod_local_along_v070(connector, rod)
		var lower: float = float(stop.get("lower", -INF))
		var upper: float = float(stop.get("upper", INF))
		if lower > -INF and along < lower - AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (lower - along))
			var lower_speed: float = _relative_axial_speed_v071(stop)
			if lower_speed < 0.0:
				_shift_component_velocity_v071(stop, axis * -lower_speed)
		elif upper < INF and along > upper + AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (upper - along))
			var upper_speed: float = _relative_axial_speed_v071(stop)
			if upper_speed > 0.0:
				_shift_component_velocity_v071(stop, axis * -upper_speed)


func _prepare_stable_simulation_graph() -> void:
	axle_pair_guard_events_v074 = 0
	axle_order_repair_events_v074 = 0
	o_ring_precision_ticks_active_v074 = false
	saved_physics_ticks_v074 = -1
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_ranked_stop_count_v074 = 0
	axle_stack_shape_state_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
