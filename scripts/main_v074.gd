extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_PAIR_MIN_SPACING_V074 := 0.60

# Number of AXLE hubs participating in multi-hub segments on rods that contain
# at least one O-Ring. Kept under the old debug name for test compatibility.
var axle_ranked_stop_count_v074: int = 0
var axle_pair_stop_joints_v074: Array = []

# Compatibility/debug surfaces for abandoned experiments. They stay inactive.
var axle_pair_guard_events_v074: int = 0
var o_ring_precision_ticks_active_v074: bool = false
var saved_physics_ticks_v074: int = -1
var axle_order_repair_events_v074: int = 0
var axle_stack_shape_state_v074: Array = []
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring simulation
#
# The O-Ring stop itself remains the released v0.5.15 design:
#
# - O-Rings are collisionless exact rod-local followers;
# - the normal AXLE joint stays free in axial slide and axle rotation;
# - the original outer hub owns the finite O-Ring / rod-end boundary;
# - no O-Ring proxy, enlarged collider, rank floor, tick-rate change or scripted
#   hub teleport is introduced.
#
# Diagnostics showed the actual bypass is a solver-time hub-through-hub tunnel:
# immediately before the bad step the two hubs can be separating rapidly, so a
# pre-step velocity predictor cannot foresee the inversion. On the next Jolt
# solve their relative velocity can reverse hard enough to exchange positions in
# one step. Post-facto transform repairs proved unstable because the attached
# fixed assemblies are already interpenetrating by then.
#
# v0.5.16 therefore models the missing physical rule directly in Jolt. Adjacent
# AXLE hubs that share an O-Ring-bearing rod get one temporary unilateral
# separation Generic6DOF. Every angular DOF and X/Z translation is free; only
# relative Y travel toward one another is limited so their center spacing cannot
# shrink below the normal connector thickness (~0.60). Motion apart is unlimited.
# Ordinary connector collision remains enabled, so normal contact/stacking still
# happens physically; this joint is only a no-pass-through backstop inside the
# solver. It connects hub to hub, never hub to rod, so it does not constrain the
# axle's free slide/rotation or drag the host rod into stop correction.
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


func _remove_axle_pair_stop_joints_v074() -> void:
	for value in axle_pair_stop_joints_v074:
		var joint := value as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			continue
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.queue_free()
	axle_pair_stop_joints_v074.clear()


func _make_axle_pair_stop_joint_v074(rod: RigidBody3D, lower: RigidBody3D, upper: RigidBody3D) -> Generic6DOFJoint3D:
	if not is_instance_valid(rod) or not is_instance_valid(lower) or not is_instance_valid(upper):
		return null
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	var lower_along: float = _rod_local_along_v070(lower, rod)
	var upper_along: float = _rod_local_along_v070(upper, rod)
	var initial_gap: float = upper_along - lower_along
	if initial_gap <= 0.0001:
		return null

	# The joint is created in the current satisfied configuration, so relative Y
	# displacement starts at zero. Moving the upper hub toward the lower hub (or
	# the lower hub toward the upper) decreases that relative Y coordinate. Allow
	# exactly the current excess spacing before the lower unilateral limit engages.
	var allowed_closing: float = maxf(0.0, initial_gap - AXLE_HUB_PAIR_MIN_SPACING_V074)

	var joint := Generic6DOFJoint3D.new()
	joint.name = "AxleHubPairStop_%d" % axle_pair_stop_joints_v074.size()
	joint.exclude_nodes_from_collision = false
	for axis_name in ["x", "z"]:
		joint.set("linear_limit_%s/enabled" % axis_name, false)
	for axis_name in ["x", "y", "z"]:
		joint.set("angular_limit_%s/enabled" % axis_name, false)
	joint.set("linear_limit_y/enabled", true)
	joint.set("linear_limit_y/lower_distance", -allowed_closing)
	joint.set("linear_limit_y/upper_distance", 1000.0)
	joint.set_meta("sim_axle_pair_stop_v074", true)
	joint.set_meta("initial_gap_v074", initial_gap)
	joint.set_meta("min_gap_v074", AXLE_HUB_PAIR_MIN_SPACING_V074)
	joint.set_meta("host_rod_id_v074", rod.get_instance_id())

	add_child(joint)
	var midpoint: Vector3 = (lower.global_position + upper.global_position) * 0.5
	joint.global_transform = Transform3D(_basis_for_axle_v020(axis), midpoint)
	joint.node_a = lower.get_path()
	joint.node_b = upper.get_path()
	axle_pair_stop_joints_v074.append(joint)
	return joint


func _configure_axle_pair_stop_joints_v074() -> int:
	_remove_axle_pair_stop_joints_v074()
	var count := 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		var hubs: Array = group.get("hubs", []) as Array
		if not is_instance_valid(rod) or hubs.size() <= 1 or not _group_has_o_ring_v074(group):
			continue
		for i in range(hubs.size() - 1):
			var lower := (hubs[i] as Dictionary).get("connector") as RigidBody3D
			var upper := (hubs[i + 1] as Dictionary).get("connector") as RigidBody3D
			if is_instance_valid(_make_axle_pair_stop_joint_v074(rod, lower, upper)):
				count += 1
	return count


func _build_axle_stop_ranges_v070() -> void:
	# v073 builds the stable v0.5.15 outer-owner ranges and remembers BUILD order.
	# Keep those stop ranges exactly as-is; add only adjacent hub no-pass joints.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()
	_configure_axle_pair_stop_joints_v074()


# The pairwise constraint lives inside Jolt, so no pre-step velocity intervention
# and no post-facto ownership/position repair are needed.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return

	# Apply only the released v0.5.15 finite O-Ring / rod-end correction.
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
	_remove_axle_pair_stop_joints_v074()
	axle_ranked_stop_count_v074 = 0
	axle_stack_shape_state_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
