extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_PAIR_MIN_SPACING_V074 := 0.60
const AXLE_HUB_PAIR_CONTACT_SLOP_V074 := 0.012
const AXLE_HUB_PAIR_PROJECTION_EPS_V074 := 0.001

# Number of AXLE hubs participating in multi-hub segments on rods that contain
# at least one O-Ring. Kept under the old debug name for compatibility with the
# v0.5.16 follow-up regression.
var axle_ranked_stop_count_v074: int = 0
var axle_pair_guard_events_v074: int = 0
var axle_pair_projection_events_v074: int = 0
var axle_pair_collision_exception_count_v074: int = 0

# Compatibility/debug surfaces for abandoned experiments. They stay inactive.
var o_ring_precision_ticks_active_v074: bool = false
var saved_physics_ticks_v074: int = -1
var axle_order_repair_events_v074: int = 0
var axle_stack_shape_state_v074: Array = []
var axle_pair_stop_joints_v074: Array = []
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring simulation
#
# Keep the released v0.5.15 O-Ring boundary model intact:
#
# - O-Rings are collisionless exact rod-local followers;
# - the normal AXLE joint stays free in axial slide and axle rotation;
# - only the BUILD-order outer hubs own the finite O-Ring / rod-end bounds;
# - the host rod is never translated by a stop correction;
# - physics stays at the normal project cadence.
#
# The remaining failure is specifically same-axle hub contact. Jolt can reverse
# the pair's relative velocity inside one solver step and tunnel one connector
# through the other, even when their pre-step velocity says they are separating.
# A second Generic6DOF also proved unsuitable because its translational frame is
# body-local while both hubs remain free to rotate around the axle.
#
# v0.5.16 therefore removes ONLY mutual collision between independently movable
# connector hubs that occupy the same O-Ring-bounded axle segment. Their physical
# one-dimensional stack is represented explicitly instead:
#
# 1. A pre-step momentum-conserving velocity clamp prevents predictable closing
#    motion from entering the normal connector-thickness spacing.
# 2. A post-step position projection catches only residual solver-time reversals
#    and restores BUILD order / physical spacing before the next solver step.
# 3. Closing axial velocity is then removed dissipatively. Internal fixed-joint
#    frames move with any projected connector-side component, exactly like the
#    proven v0.5.15 O-Ring boundary correction.
#
# The two same-axle hub bodies no longer fight those deterministic corrections
# with a simultaneous Jolt contact impulse. They still collide with the ground,
# the host rod according to normal AXLE rules, and unrelated construction parts.
# No collision geometry, O-Ring collider, tick rate, normal AXLE limit, or extra
# persistent joint is created.
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


func _hub_component_for_group_v074(group: Dictionary, hub_info: Dictionary) -> Array:
	var rod := group.get("rod") as RigidBody3D
	var connector := hub_info.get("connector") as RigidBody3D
	var segment: int = int(group.get("segment", 0))
	if not is_instance_valid(rod) or not is_instance_valid(connector):
		return []
	var stop: Dictionary = _find_stop_v074(rod, connector, segment)
	if stop.is_empty():
		return []
	return _stop_component_v071(stop)


func _group_is_independently_movable_v074(group: Dictionary) -> bool:
	var hubs: Array = group.get("hubs", []) as Array
	var components: Array = []
	for hub_value in hubs:
		var component: Array = _hub_component_for_group_v074(group, hub_value as Dictionary)
		if component.is_empty():
			return false
		for prior_value in components:
			if _components_overlap_v070(component, prior_value as Array):
				# Two hubs already belong to the same fixed component. Their relative
				# axle order is structural, not a free stack DOF, so do not interfere.
				return false
		components.append(component)
	return true


func _configure_axle_stack_collision_exceptions_v074() -> int:
	var count := 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var hubs: Array = group.get("hubs", []) as Array
		if hubs.size() <= 1 or not _group_has_o_ring_v074(group) or not _group_is_independently_movable_v074(group):
			continue
		for i in range(hubs.size() - 1):
			var lower := (hubs[i] as Dictionary).get("connector") as RigidBody3D
			var upper := (hubs[i + 1] as Dictionary).get("connector") as RigidBody3D
			if not is_instance_valid(lower) or not is_instance_valid(upper):
				continue
			_add_simulation_collision_exception(lower, upper)
			count += 1
	return count


func _build_axle_stop_ranges_v070() -> void:
	# v073 supplies stable v0.5.15 outer-owner ranges plus immutable BUILD order.
	# Do not transfer boundary ownership after a tunnel; prevent the tunnel instead.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()
	axle_pair_collision_exception_count_v074 = _configure_axle_stack_collision_exceptions_v074()


func _guard_adjacent_axle_pair_v074(group: Dictionary, lower_info: Dictionary, upper_info: Dictionary, delta: float) -> bool:
	var rod := group.get("rod") as RigidBody3D
	var segment: int = int(group.get("segment", 0))
	var lower := lower_info.get("connector") as RigidBody3D
	var upper := upper_info.get("connector") as RigidBody3D
	if not is_instance_valid(rod) or not is_instance_valid(lower) or not is_instance_valid(upper):
		return false

	var lower_stop: Dictionary = _find_stop_v074(rod, lower, segment)
	var upper_stop: Dictionary = _find_stop_v074(rod, upper, segment)
	if lower_stop.is_empty() or upper_stop.is_empty():
		return false
	var lower_component: Array = _stop_component_v071(lower_stop)
	var upper_component: Array = _stop_component_v071(upper_stop)
	if lower_component.is_empty() or upper_component.is_empty() or _components_overlap_v070(lower_component, upper_component):
		return false

	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var lower_along: float = _rod_local_along_v070(lower, rod)
	var upper_along: float = _rod_local_along_v070(upper, rod)
	var gap: float = upper_along - lower_along
	if gap <= 0.0:
		# A post-step residual inversion is handled by the projection path, never by
		# silently swapping stop ownership.
		return false

	var relative_speed: float = (upper.linear_velocity - lower.linear_velocity).dot(axis)
	if relative_speed >= 0.0:
		return false
	var predicted_gap: float = gap + relative_speed * delta
	var guard_spacing: float = AXLE_HUB_PAIR_MIN_SPACING_V074 + AXLE_HUB_PAIR_CONTACT_SLOP_V074
	if predicted_gap >= guard_spacing:
		return false

	# Permit at most the closing speed that reaches the contact guard next step.
	# If the pair is already inside the guard, prevent any further closing.
	var allowed_relative: float = minf(0.0, (guard_spacing - gap) / delta)
	var relative_change: float = allowed_relative - relative_speed
	if relative_change <= 0.000001:
		return false

	var inv_lower: float = _component_inverse_mass_v070(lower_component)
	var inv_upper: float = _component_inverse_mass_v070(upper_component)
	var inv_sum: float = inv_lower + inv_upper
	if inv_sum <= 0.000001:
		return false

	# One-dimensional perfectly-inelastic contact impulse. Splitting by inverse
	# component mass preserves total axial momentum while only removing closing
	# relative kinetic energy.
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
		if hubs.size() <= 1 or not _group_has_o_ring_v074(group) or not _group_is_independently_movable_v074(group):
			continue
		for i in range(hubs.size() - 1):
			_guard_adjacent_axle_pair_v074(group, hubs[i] as Dictionary, hubs[i + 1] as Dictionary, delta)


# Ownership stays with BUILD-order outer hubs. A same-axle inversion is repaired
# as the impossible stack state itself, not redefined as a new valid order.
func _correct_axle_order_v073() -> bool:
	return false


func _correct_finite_axle_boundaries_v074() -> void:
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


func _project_group_targets_v074(group: Dictionary) -> Array:
	var rod := group.get("rod") as RigidBody3D
	var hubs: Array = group.get("hubs", []) as Array
	if not is_instance_valid(rod) or hubs.size() <= 1:
		return []
	var lower_bound: float = float(group.get("lower", -INF))
	var upper_bound: float = float(group.get("upper", INF))
	if lower_bound <= -INF or upper_bound >= INF:
		return []
	var required_span: float = AXLE_HUB_PAIR_MIN_SPACING_V074 * float(hubs.size() - 1)
	if upper_bound - lower_bound < required_span - 0.0001:
		return []

	var targets: Array = []
	for hub_value in hubs:
		var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			return []
		targets.append(_rod_local_along_v070(connector, rod))

	# Symmetric position-based projection. Pair pushes preserve the group's center
	# until a real O-Ring/rod-end boundary requires translating the whole stack.
	for _pass in range(maxi(8, hubs.size() * 4)):
		var changed := false
		for i in range(targets.size() - 1):
			var gap: float = float(targets[i + 1]) - float(targets[i])
			if gap >= AXLE_HUB_PAIR_MIN_SPACING_V074 - AXLE_HUB_PAIR_PROJECTION_EPS_V074:
				continue
			var correction: float = (AXLE_HUB_PAIR_MIN_SPACING_V074 - gap) * 0.5
			targets[i] = float(targets[i]) - correction
			targets[i + 1] = float(targets[i + 1]) + correction
			changed = true

		var group_shift := 0.0
		if float(targets[0]) < lower_bound:
			group_shift = lower_bound - float(targets[0])
		elif float(targets[targets.size() - 1]) > upper_bound:
			group_shift = upper_bound - float(targets[targets.size() - 1])
		if absf(group_shift) > 0.0000001:
			for i in range(targets.size()):
				targets[i] = float(targets[i]) + group_shift
			changed = true
		if not changed:
			break

	# Finish deterministically from the lower side, then shift the completed stack
	# as one unit if the upper boundary would otherwise be exceeded.
	for i in range(1, targets.size()):
		var min_value: float = float(targets[i - 1]) + AXLE_HUB_PAIR_MIN_SPACING_V074
		if float(targets[i]) < min_value:
			targets[i] = min_value
	if float(targets[targets.size() - 1]) > upper_bound:
		var shift_down: float = upper_bound - float(targets[targets.size() - 1])
		for i in range(targets.size()):
			targets[i] = float(targets[i]) + shift_down
	if float(targets[0]) < lower_bound - AXLE_HUB_PAIR_PROJECTION_EPS_V074:
		return []
	return targets


func _cancel_pair_closing_velocity_v074(group: Dictionary, lower_info: Dictionary, upper_info: Dictionary, lower_target: float, upper_target: float) -> bool:
	if upper_target - lower_target > AXLE_HUB_PAIR_MIN_SPACING_V074 + AXLE_HUB_PAIR_CONTACT_SLOP_V074:
		return false
	var rod := group.get("rod") as RigidBody3D
	var segment: int = int(group.get("segment", 0))
	var lower := lower_info.get("connector") as RigidBody3D
	var upper := upper_info.get("connector") as RigidBody3D
	if not is_instance_valid(rod) or not is_instance_valid(lower) or not is_instance_valid(upper):
		return false
	var lower_stop: Dictionary = _find_stop_v074(rod, lower, segment)
	var upper_stop: Dictionary = _find_stop_v074(rod, upper, segment)
	if lower_stop.is_empty() or upper_stop.is_empty():
		return false
	var lower_component: Array = _stop_component_v071(lower_stop)
	var upper_component: Array = _stop_component_v071(upper_stop)
	if lower_component.is_empty() or upper_component.is_empty() or _components_overlap_v070(lower_component, upper_component):
		return false

	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var relative_speed: float = (upper.linear_velocity - lower.linear_velocity).dot(axis)
	if relative_speed >= 0.0:
		return false

	var lower_bound: float = float(group.get("lower", -INF))
	var upper_bound: float = float(group.get("upper", INF))
	var lower_on_boundary: bool = lower_target <= lower_bound + AXLE_HUB_PAIR_CONTACT_SLOP_V074
	var upper_on_boundary: bool = upper_target >= upper_bound - AXLE_HUB_PAIR_CONTACT_SLOP_V074

	# If an outer hub is already resting on a finite boundary, preserve that
	# boundary owner's rod-relative velocity and make only the incoming neighbour
	# match it. Otherwise use the momentum-conserving inelastic pair impulse.
	if lower_on_boundary and not upper_on_boundary:
		_shift_component_velocity_v071(upper_stop, axis * -relative_speed)
		return true
	if upper_on_boundary and not lower_on_boundary:
		_shift_component_velocity_v071(lower_stop, axis * relative_speed)
		return true

	var inv_lower: float = _component_inverse_mass_v070(lower_component)
	var inv_upper: float = _component_inverse_mass_v070(upper_component)
	var inv_sum: float = inv_lower + inv_upper
	if inv_sum <= 0.000001:
		return false
	var relative_change: float = -relative_speed
	_shift_component_velocity_v071(lower_stop, axis * (-relative_change * inv_lower / inv_sum))
	_shift_component_velocity_v071(upper_stop, axis * (relative_change * inv_upper / inv_sum))
	return true


func _project_axle_stack_group_v074(group: Dictionary) -> bool:
	if not _group_has_o_ring_v074(group) or not _group_is_independently_movable_v074(group):
		return false
	var rod := group.get("rod") as RigidBody3D
	var hubs: Array = group.get("hubs", []) as Array
	if not is_instance_valid(rod) or hubs.size() <= 1:
		return false
	var targets: Array = _project_group_targets_v074(group)
	if targets.size() != hubs.size():
		return false
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var segment: int = int(group.get("segment", 0))
	var changed := false

	# Move each independent connector-side fixed component once. _shift_stop_component
	# also translates that component's active internal fixed-joint frames, preventing
	# stale anchors from manufacturing energy on the next Jolt solve.
	for i in range(hubs.size()):
		var connector := (hubs[i] as Dictionary).get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			continue
		var current: float = _rod_local_along_v070(connector, rod)
		var correction: float = float(targets[i]) - current
		if absf(correction) <= AXLE_HUB_PAIR_PROJECTION_EPS_V074:
			continue
		var stop: Dictionary = _find_stop_v074(rod, connector, segment)
		if stop.is_empty():
			continue
		_shift_stop_component_v071(stop, axis * correction)
		changed = true

	for i in range(hubs.size() - 1):
		if _cancel_pair_closing_velocity_v074(group, hubs[i] as Dictionary, hubs[i + 1] as Dictionary, float(targets[i]), float(targets[i + 1])):
			changed = true
	if changed:
		axle_pair_projection_events_v074 += 1
	return changed


func _project_axle_stacks_v074() -> bool:
	if not simulating:
		return false
	var changed := false
	for group_value in axle_order_groups_v073:
		changed = _project_axle_stack_group_v074(group_value as Dictionary) or changed
	return changed


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return
	# Finite O-Ring/rod-end boundaries first, then the same-segment 1D stack. The
	# stack projection itself respects both finite group bounds, so no ownership
	# handoff or second boundary owner is required.
	_correct_finite_axle_boundaries_v074()
	_project_axle_stacks_v074()


func _prepare_stable_simulation_graph() -> void:
	axle_pair_guard_events_v074 = 0
	axle_pair_projection_events_v074 = 0
	axle_pair_collision_exception_count_v074 = 0
	axle_order_repair_events_v074 = 0
	o_ring_precision_ticks_active_v074 = false
	saved_physics_ticks_v074 = -1
	axle_pair_stop_joints_v074.clear()
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_ranked_stop_count_v074 = 0
	axle_pair_guard_events_v074 = 0
	axle_pair_projection_events_v074 = 0
	axle_pair_collision_exception_count_v074 = 0
	axle_stack_shape_state_v074.clear()
	axle_pair_stop_joints_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
