extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_RANK_SPACING_V074 := 0.62
const AXLE_STOP_SOLVER_GUARD_V074 := 0.20

var axle_ranked_stop_count_v074: int = 0
var o_ring_axle_stop_joints_v074: Array = []


# -----------------------------------------------------------------------------
# Solver-native O-Ring stops
#
# Keep the normal AXLE joint completely intact. It still owns radial alignment,
# free axial slide and free axle rotation. O-Rings remain exact rod-local visual
# followers as in v0.5.15.
#
# The v0.5.15 failure that remains with multiple hubs is tunnelling: Jolt can
# solve a violent spoke/contact step after our pre-step predictor and move an
# interior hub through the outer hub before script-side correction runs.
# Script-side position projection then over-constrains the attached spoke graph
# and can manufacture energy.
#
# Instead, create one TEMPORARY orthogonal Generic6DOF per AXLE hub. Every DOF on
# this extra joint is free except linear Y, which is bounded to the hub's initial
# non-overlapping rank inside the O-Ring/rod-end segment. Because the extra joint
# constrains only the one degree of freedom the normal AXLE deliberately leaves
# free, Jolt resolves the stop in the same solver step without teleporting any
# body or changing O-Ring ownership. The temporary joints are removed on BUILD.
# -----------------------------------------------------------------------------

func _rank_spacing_for_group_v074(group: Dictionary) -> float:
	var hubs: Array = group.get("hubs", []) as Array
	if hubs.size() <= 1:
		return 0.0
	var lower: float = float(group.get("lower", -INF))
	var upper: float = float(group.get("upper", INF))
	var spacing := AXLE_HUB_RANK_SPACING_V074

	# Do not make SIMULATE rearrange a compact but valid BUILD pose. Reduce the
	# spacing only when the existing build genuinely has less room than 0.62.
	var initial_values: Array = []
	for hub_value in hubs:
		var hub := hub_value as Dictionary
		var connector := hub.get("connector") as RigidBody3D
		var rod := group.get("rod") as RigidBody3D
		if is_instance_valid(connector) and is_instance_valid(rod):
			initial_values.append(_rod_local_along_v070(connector, rod))
		else:
			initial_values.append(0.0)
	if lower > -INF and upper < INF:
		spacing = minf(spacing, maxf(0.0, (upper - lower) / float(hubs.size() - 1)))
	for i in range(initial_values.size()):
		var initial: float = float(initial_values[i])
		if i > 0 and lower > -INF:
			spacing = minf(spacing, maxf(0.0, (initial - lower) / float(i)))
		var above: int = initial_values.size() - 1 - i
		if above > 0 and upper < INF:
			spacing = minf(spacing, maxf(0.0, (upper - initial) / float(above)))
	return maxf(0.0, spacing)


func _find_rank_stop_v074(rod: RigidBody3D, connector: RigidBody3D, segment: int) -> Dictionary:
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		if stop.get("rod") == rod and stop.get("connector") == connector and int(stop.get("segment", -999)) == segment:
			return stop
	return {}


func _apply_ranked_axle_stops_v074() -> void:
	axle_ranked_stop_count_v074 = 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		var hubs: Array = group.get("hubs", []) as Array
		if not is_instance_valid(rod) or hubs.is_empty():
			continue
		var segment: int = int(group.get("segment", 0))
		var lower: float = float(group.get("lower", -INF))
		var upper: float = float(group.get("upper", INF))
		var spacing: float = _rank_spacing_for_group_v074(group)
		for i in range(hubs.size()):
			var hub := hubs[i] as Dictionary
			var connector := hub.get("connector") as RigidBody3D
			if not is_instance_valid(connector):
				continue
			var stop: Dictionary = _find_rank_stop_v074(rod, connector, segment)
			if stop.is_empty():
				continue
			if lower > -INF:
				stop["lower"] = lower + spacing * float(i)
			if upper < INF:
				stop["upper"] = upper - spacing * float(hubs.size() - 1 - i)
			stop["rank_spacing_v074"] = spacing
			stop["ranked_stop_v074"] = hubs.size() > 1
			if hubs.size() > 1:
				axle_ranked_stop_count_v074 += 1


func _normal_axle_joint_for_stop_v074(stop: Dictionary) -> Generic6DOFJoint3D:
	var uid: int = int(stop.get("uid", -1))
	var connector := stop.get("connector") as RigidBody3D
	var rod := stop.get("rod") as RigidBody3D
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		if int(record.get("uid", -2)) == uid and record.get("connector") == connector and record.get("rod") == rod:
			return record.get("joint") as Generic6DOFJoint3D
	return null


func _make_solver_stop_joint_v074(stop: Dictionary) -> Generic6DOFJoint3D:
	var connector := stop.get("connector") as RigidBody3D
	var rod := stop.get("rod") as RigidBody3D
	var normal := _normal_axle_joint_for_stop_v074(stop)
	if not is_instance_valid(connector) or not is_instance_valid(rod) or not is_instance_valid(normal):
		return null
	if normal.node_a.is_empty() or normal.node_b.is_empty():
		return null

	var current_along: float = _rod_local_along_v070(connector, rod)
	var lower_abs: float = float(stop.get("lower", -INF))
	var upper_abs: float = float(stop.get("upper", INF))
	var lower_delta := -1000.0
	var upper_delta := 1000.0
	if lower_abs > -INF:
		# Arm slightly early for Jolt's hard-limit slop, but never place the BUILD
		# pose outside the newly created constraint at simulation start.
		var guarded_lower: float = minf(current_along, lower_abs + AXLE_STOP_SOLVER_GUARD_V074)
		lower_delta = guarded_lower - current_along
	if upper_abs < INF:
		var guarded_upper: float = maxf(current_along, upper_abs - AXLE_STOP_SOLVER_GUARD_V074)
		upper_delta = guarded_upper - current_along
	if lower_delta > upper_delta:
		lower_delta = 0.0
		upper_delta = 0.0

	var joint := Generic6DOFJoint3D.new()
	joint.name = "AxleO_RingStop_%d" % o_ring_axle_stop_joints_v074.size()
	joint.exclude_nodes_from_collision = normal.exclude_nodes_from_collision
	# Explicitly leave every unrelated degree of freedom free. The existing AXLE
	# joint remains the sole owner of X/Z alignment and X/Z angular locking.
	for axis_name in ["x", "z"]:
		joint.set("linear_limit_%s/enabled" % axis_name, false)
		joint.set("angular_limit_%s/enabled" % axis_name, false)
	joint.set("linear_limit_y/enabled", true)
	joint.set("linear_limit_y/lower_distance", lower_delta)
	joint.set("linear_limit_y/upper_distance", upper_delta)
	joint.set("angular_limit_y/enabled", false)
	joint.set_meta("sim_o_ring_axle_stop_v074", true)
	joint.set_meta("sim_o_ring_lower_abs_v074", lower_abs)
	joint.set_meta("sim_o_ring_upper_abs_v074", upper_abs)
	joint.set_meta("sim_o_ring_initial_along_v074", current_along)

	add_child(joint)
	joint.global_transform = normal.global_transform
	# Configure before binding so Jolt creates the native constraint in limited-Y
	# mode from the beginning.
	joint.node_a = normal.node_a
	joint.node_b = normal.node_b
	joints.append(joint)
	o_ring_axle_stop_joints_v074.append(joint)
	return joint


func _remove_solver_stop_joints_v074() -> void:
	for value in o_ring_axle_stop_joints_v074:
		var joint := value as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			continue
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joints.erase(joint)
		joint.queue_free()
	o_ring_axle_stop_joints_v074.clear()


func _configure_solver_stop_joints_v074() -> int:
	_remove_solver_stop_joints_v074()
	var count := 0
	for stop_value in axle_stop_ranges_v070:
		if is_instance_valid(_make_solver_stop_joint_v074(stop_value as Dictionary)):
			count += 1
	return count


func _build_axle_stop_ranges_v070() -> void:
	super._build_axle_stop_ranges_v070()
	_apply_ranked_axle_stops_v074()
	_configure_solver_stop_joints_v074()


# The solver-native stop joints now own O-Ring/rod-end translation boundaries.
# Disable every script-side stop/order intervention so no body transform or
# linear velocity is rewritten after the Jolt solve.
func _predict_axle_stops_v071(_delta: float) -> void:
	pass


func _correct_axle_stop_positions_v071() -> void:
	pass


func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_remove_solver_stop_joints_v074()
	axle_ranked_stop_count_v074 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
