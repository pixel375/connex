extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_PAIR_MIN_SPACING_V074 := 0.60
const AXLE_HUB_PAIR_CONTACT_SLOP_V074 := 0.012

# Number of AXLE hubs participating in multi-hub segments on rods that contain
# at least one O-Ring. Kept under the old debug name for test compatibility.
var axle_ranked_stop_count_v074: int = 0
var axle_pair_guard_events_v074: int = 0
var axle_pair_collision_exception_count_v074: int = 0

# Compatibility/debug surfaces for abandoned experiments. They stay inactive.
var axle_pair_projection_events_v074: int = 0
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
# - O-Rings remain collisionless exact rod-local followers;
# - normal AXLE joints stay free in axial slide and axle rotation;
# - BUILD-order outer hubs own the finite O-Ring / rod-end boundaries;
# - the host rod is never moved by an O-Ring correction;
# - physics remains at the normal project tick rate.
#
# Diagnostics isolated the rare bypass to Jolt's mutual contact solve between two
# independently moving connector hubs on the SAME axle segment. That contact can
# reverse relative velocity inside a single solver step and tunnel the hubs even
# when their pre-step velocity says they are separating. A second Generic6DOF and
# post-step transform projection both prevented the tunnel but manufactured late
# solver energy in attached spoke assemblies.
#
# v0.5.16 therefore removes only that one redundant source of solver conflict:
# direct connector-to-connector collision between adjacent, independently movable
# hubs that share an O-Ring-bounded axle segment. Their one-dimensional stack is
# represented with a pre-step momentum-conserving contact clamp along the actual
# host-rod axis. No transforms are moved and no extra joint/shape is created.
# All other collisions (ground, unrelated parts, other structures) are unchanged.
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


func _hub_component_v074(group: Dictionary, hub_info: Dictionary) -> Array:
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
	var components: Array = []
	for hub_value in group.get("hubs", []) as Array:
		var component: Array = _hub_component_v074(group, hub_value as Dictionary)
		if component.is_empty():
			return false
		for prior_value in components:
			if _components_overlap_v070(component, prior_value as Array):
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
	# v073 supplies the released outer-owner boundaries and immutable BUILD order.
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
	var gap: float = _rod_local_along_v070(upper, rod) - _rod_local_along_v070(lower, rod)
	if gap <= 0.0:
		# Never hide an actual order inversion. The strict regression will expose it.
		return false
	var relative_speed: float = (upper.linear_velocity - lower.linear_velocity).dot(axis)
	if relative_speed >= 0.0:
		return false
	var guard_spacing: float = AXLE_HUB_PAIR_MIN_SPACING_V074 + AXLE_HUB_PAIR_CONTACT_SLOP_V074
	if gap + relative_speed * delta >= guard_spacing:
		return false

	var allowed_relative: float = minf(0.0, (guard_spacing - gap) / delta)
	var relative_change: float = allowed_relative - relative_speed
	if relative_change <= 0.000001:
		return false

	# If one of the pair is the outer hub already resting on a finite stop, keep
	# that boundary owner's rod-relative axial speed and make only the incoming hub
	# match it. This models a stack resting against a real O-Ring/rod end without
	# pushing the stopped assembly back into the boundary controller.
	var lower_bound: float = float(group.get("lower", -INF))
	var upper_bound: float = float(group.get("upper", INF))
	var lower_along: float = _rod_local_along_v070(lower, rod)
	var upper_along: float = _rod_local_along_v070(upper, rod)
	var lower_on_boundary: bool = lower_along <= lower_bound + AXLE_HUB_PAIR_CONTACT_SLOP_V074
	var upper_on_boundary: bool = upper_along >= upper_bound - AXLE_HUB_PAIR_CONTACT_SLOP_V074
	if lower_on_boundary and not upper_on_boundary:
		_shift_component_velocity_v071(upper_stop, axis * relative_change)
		axle_pair_guard_events_v074 += 1
		return true
	if upper_on_boundary and not lower_on_boundary:
		_shift_component_velocity_v071(lower_stop, axis * -relative_change)
		axle_pair_guard_events_v074 += 1
		return true

	# Free pair contact: split the one-dimensional inelastic impulse by inverse
	# component mass. This preserves total axial momentum and can only remove
	# closing relative kinetic energy.
	var inv_lower: float = _component_inverse_mass_v070(lower_component)
	var inv_upper: float = _component_inverse_mass_v070(upper_component)
	var inv_sum: float = inv_lower + inv_upper
	if inv_sum <= 0.000001:
		return false
	_shift_component_velocity_v071(lower_stop, axis * (-relative_change * inv_lower / inv_sum))
	_shift_component_velocity_v071(upper_stop, axis * (relative_change * inv_upper / inv_sum))
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


# Stop ownership never changes. Same-axle tunnelling must be prevented, not made
# valid by transferring the O-Ring boundary to the hub that happened to tunnel.
func _correct_axle_order_v073() -> bool:
	return false


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return
	# Only the proven v0.5.15 finite O-Ring / rod-end boundary correction remains.
	# Same-axle stack handling is velocity-only and never changes transforms.
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
