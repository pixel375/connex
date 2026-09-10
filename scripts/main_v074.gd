extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const COMPLEX_ORING_PHYSICS_TPS_V074 := 120
const AXLE_HUB_PAIR_GUARD_SPACING_V074 := 0.60

# Number of AXLE hubs participating in multi-hub segments on rods that contain
# at least one O-Ring. Kept under the old debug name for test compatibility.
var axle_ranked_stop_count_v074: int = 0
var o_ring_precision_ticks_active_v074: bool = false
var saved_physics_ticks_v074: int = -1
var axle_pair_guard_events_v074: int = 0
var axle_order_repair_events_v074: int = 0

# Compatibility/debug surfaces for abandoned experiments. They stay empty.
var axle_stack_shape_state_v074: Array = []
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring simulation
#
# Keep the released v0.5.15 O-Ring stop topology:
#
# - O-Rings are collisionless exact rod-local followers;
# - the normal AXLE joint remains free in axial slide and rotation;
# - only the original outer hub owns each finite O-Ring / rod-end stop;
# - ordinary connector collision remains the visible/physical stack behavior.
#
# The remaining failure was not the O-Ring boundary itself. Under a loaded
# asymmetric assembly, Jolt could occasionally move one AXLE hub completely
# through its adjacent hub in a single integration step. Every post-facto repair
# that translated an already-tunnelled fixed assembly produced large solver
# energy later.
#
# v0.5.16 prevents that impossible state before it happens. For adjacent hubs in
# a multi-hub O-Ring segment, only when their current relative axial velocity
# predicts that their centers will cross the normal ~0.60 hub contact spacing in
# the next physics step, apply a one-dimensional, perfectly inelastic contact
# impulse along the rod axis. The two connector-side fixed components receive
# equal/opposite momentum-conserving velocity changes weighted by inverse mass.
# This can only remove closing relative kinetic energy; it does not move bodies,
# impose persistent rank floors, or push either component relative to the rod.
# Once the pair is no longer closing, the guard is completely dormant.
#
# Multi-hub O-Ring builds additionally run at 120 Hz while SIMULATE is active to
# reduce one-step travel. Ordinary simulations keep the project tick rate, and
# BUILD restores the exact prior value.
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


func _enable_precision_ticks_v074() -> void:
	if axle_ranked_stop_count_v074 <= 0 or o_ring_precision_ticks_active_v074:
		return
	saved_physics_ticks_v074 = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = maxi(saved_physics_ticks_v074, COMPLEX_ORING_PHYSICS_TPS_V074)
	o_ring_precision_ticks_active_v074 = Engine.physics_ticks_per_second > saved_physics_ticks_v074


func _restore_precision_ticks_v074() -> void:
	if saved_physics_ticks_v074 > 0:
		Engine.physics_ticks_per_second = saved_physics_ticks_v074
	saved_physics_ticks_v074 = -1
	o_ring_precision_ticks_active_v074 = false


func _build_axle_stop_ranges_v070() -> void:
	# v073 builds the stable v0.5.15 outer-owner ranges and remembers BUILD order.
	# Do not rewrite any stop boundary or ownership here.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()
	_enable_precision_ticks_v074()


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
		# Never perform a post-facto transform repair. A negative gap is left as a
		# hard regression failure so this predictor cannot hide a missed tunnel.
		return false

	var relative_speed: float = (upper.linear_velocity - lower.linear_velocity).dot(axis)
	if relative_speed >= 0.0:
		return false
	var predicted_gap: float = gap + relative_speed * delta
	if predicted_gap >= AXLE_HUB_PAIR_GUARD_SPACING_V074:
		return false

	# Permit the maximum closing speed that lands exactly at the contact guard on
	# the next step. If the pair is already inside that spacing, stop additional
	# closing but do not separate/teleport it.
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

	# Equivalent to a perfectly inelastic 1-D contact impulse. Because the
	# relative change is split by inverse mass, total axial momentum is conserved.
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
		# The array remains in BUILD order. Guard each neighboring pair against
		# closing through that order; ordinary Jolt collision still handles contact.
		for i in range(hubs.size() - 1):
			_guard_adjacent_axle_pair_v074(group, hubs[i] as Dictionary, hubs[i + 1] as Dictionary, delta)


# Disable v073's post-facto ownership transfer. If the predictor ever misses an
# inversion, the strict regression must expose it rather than translating an
# already-overlapped assembly or moving the O-Ring boundary to the bad state.
func _correct_axle_order_v073() -> bool:
	return false


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return

	# Apply only the released v0.5.15 finite boundary correction. Pairwise hub
	# protection happens predictively through _predict_axle_order_v073().
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
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_precision_ticks_v074()
	axle_ranked_stop_count_v074 = 0
	axle_stack_shape_state_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
