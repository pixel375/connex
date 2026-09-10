extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_RANK_SPACING_V074 := 0.62
const AXLE_HUB_STACK_HEIGHT_V074 := 0.72

var axle_ranked_stop_count_v074: int = 0
var axle_stack_shape_state_v074: Array = []

# Compatibility/debug surfaces for abandoned experiments. They must remain empty.
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring stops
#
# Keep the released v0.5.15 stop topology: only the outer hub at each real
# O-Ring/rod-end boundary may receive a post-step connector-side correction.
# That path is proven stable even with asymmetric spoke assemblies.
#
# The user-reported failure in larger builds is different: an interior AXLE hub
# can occasionally tunnel through the outer hub, after which it can bypass the
# boundary owner. Two deliberately low-impact protections close that hole:
#
# 1. Every hub keeps a predictive rod-local rank limit, spaced by physical hub
#    thickness. Interior rank limits are VELOCITY-ONLY; they never teleport or
#    post-correct attached assemblies.
# 2. AXLE hubs sharing a rod that contains an O-Ring temporarily use a slightly
#    taller axial collision cylinder (0.72 vs 0.60). This begins ordinary
#    hub-to-hub contact 0.06 units earlier per face, giving Jolt/CCD more room to
#    resolve stacking before a one-frame pass-through. The visible connector is
#    unchanged and the original collision shape is restored in BUILD.
#
# O-Rings themselves remain collisionless exact rod-local followers. The normal
# AXLE joint is never replaced or limited, and Y rotation remains free.
# -----------------------------------------------------------------------------

func _rank_spacing_for_group_v074(group: Dictionary) -> float:
	var hubs: Array = group.get("hubs", []) as Array
	if hubs.size() <= 1:
		return 0.0
	var rod := group.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return 0.0
	var lower: float = float(group.get("lower", -INF))
	var upper: float = float(group.get("upper", INF))
	var spacing := AXLE_HUB_RANK_SPACING_V074

	# Use the actual BUILD positions at simulation setup. This avoids depending on
	# legacy group metadata and never makes a compact valid build jump apart.
	var initial_values: Array = []
	for hub_value in hubs:
		var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
		initial_values.append(_rod_local_along_v070(connector, rod) if is_instance_valid(connector) else 0.0)
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


func _group_has_o_ring_v074(group: Dictionary) -> bool:
	var rod := group.get("rod") as RigidBody3D
	var segment: int = int(group.get("segment", 0))
	for hub_value in group.get("hubs", []) as Array:
		var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
		var stop: Dictionary = _find_rank_stop_v074(rod, connector, segment)
		if not stop.is_empty() and int(stop.get("ring_count", 0)) > 0:
			return true
	return false


func _apply_ranked_axle_stops_v074() -> void:
	axle_ranked_stop_count_v074 = 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		var hubs: Array = group.get("hubs", []) as Array
		if not is_instance_valid(rod) or hubs.is_empty() or not _group_has_o_ring_v074(group):
			continue
		var segment: int = int(group.get("segment", 0))
		var lower: float = float(group.get("lower", -INF))
		var upper: float = float(group.get("upper", INF))
		var spacing: float = _rank_spacing_for_group_v074(group)
		for i in range(hubs.size()):
			var connector := (hubs[i] as Dictionary).get("connector") as RigidBody3D
			if not is_instance_valid(connector):
				continue
			var stop: Dictionary = _find_rank_stop_v074(rod, connector, segment)
			if stop.is_empty():
				continue
			stop["original_lower_owner_v074"] = i == 0
			stop["original_upper_owner_v074"] = i == hubs.size() - 1
			if lower > -INF:
				stop["lower"] = lower + spacing * float(i)
			if upper < INF:
				stop["upper"] = upper - spacing * float(hubs.size() - 1 - i)
			stop["rank_spacing_v074"] = spacing
			stop["ranked_stop_v074"] = hubs.size() > 1
			if hubs.size() > 1:
				axle_ranked_stop_count_v074 += 1


func _restore_axle_stack_shapes_v074() -> void:
	for state_value in axle_stack_shape_state_v074:
		var state := state_value as Dictionary
		var collider := state.get("collider") as CollisionShape3D
		var original_shape := state.get("shape") as Shape3D
		if is_instance_valid(collider) and original_shape != null:
			collider.shape = original_shape
	axle_stack_shape_state_v074.clear()


func _expand_axle_hub_shape_v074(connector: RigidBody3D) -> bool:
	if not is_instance_valid(connector):
		return false
	for state_value in axle_stack_shape_state_v074:
		if (state_value as Dictionary).get("connector") == connector:
			return true
	var best: CollisionShape3D = null
	var best_radius := 0.0
	for child_value in connector.get_children():
		var collider := child_value as CollisionShape3D
		if collider == null or collider.disabled or not (collider.shape is CylinderShape3D):
			continue
		var cylinder := collider.shape as CylinderShape3D
		if cylinder.radius > best_radius:
			best = collider
			best_radius = cylinder.radius
	if best == null:
		return false
	var original_shape := best.shape
	var expanded := original_shape.duplicate(true) as CylinderShape3D
	if expanded == null:
		return false
	expanded.height = maxf(expanded.height, AXLE_HUB_STACK_HEIGHT_V074)
	axle_stack_shape_state_v074.append({"connector": connector, "collider": best, "shape": original_shape})
	best.shape = expanded
	connector.sleeping = false
	return true


func _prepare_axle_stack_shapes_v074() -> int:
	_restore_axle_stack_shapes_v074()
	var count := 0
	var seen: Dictionary = {}
	for stop_value in axle_stop_ranges_v070:
		var stop := stop_value as Dictionary
		if int(stop.get("ring_count", 0)) <= 0:
			continue
		var connector := stop.get("connector") as RigidBody3D
		if not is_instance_valid(connector) or seen.has(connector.get_instance_id()):
			continue
		seen[connector.get_instance_id()] = true
		if _expand_axle_hub_shape_v074(connector):
			count += 1
	return count


func _build_axle_stop_ranges_v070() -> void:
	# main_v073 builds v0.5.15 boundary ownership and initial hub ordering.
	super._build_axle_stop_ranges_v070()
	_apply_ranked_axle_stops_v074()
	_prepare_axle_stack_shapes_v074()


# Interior ranked limits are predictive only. Post-step correction remains
# exclusive to the original outer owners, preserving v0.5.15's stable topology.
func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return
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
		if bool(stop.get("original_lower_owner_v074", true)) and lower > -INF and along < lower - AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (lower - along))
			var lower_speed: float = _relative_axial_speed_v071(stop)
			if lower_speed < 0.0:
				_shift_component_velocity_v071(stop, axis * -lower_speed)
		elif bool(stop.get("original_upper_owner_v074", true)) and upper < INF and along > upper + AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (upper - along))
			var upper_speed: float = _relative_axial_speed_v071(stop)
			if upper_speed > 0.0:
				_shift_component_velocity_v071(stop, axis * -upper_speed)


# All abandoned dynamic ownership/order interventions remain disabled.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_axle_stack_shapes_v074()
	axle_ranked_stop_count_v074 = 0
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
