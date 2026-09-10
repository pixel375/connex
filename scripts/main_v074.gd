extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_RANK_SPACING_V074 := 0.62

var axle_ranked_stop_count_v074: int = 0


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring stops
#
# v0.5.15's stable rule remains: only the physically outer hub is allowed to
# receive a post-step transform correction at an O-Ring / rod end. Interior hubs
# receive only predictive rod-local limits, offset by connector thickness, so a
# missed Jolt hub collision cannot let them continue all the way through the
# O-Ring. This avoids multiple post-step assembly translations in one frame.
# -----------------------------------------------------------------------------

func _rank_spacing_for_group_v074(group: Dictionary) -> float:
	var hubs: Array = group.get("hubs", []) as Array
	if hubs.size() <= 1:
		return 0.0
	var lower: float = float(group.get("lower", -INF))
	var upper: float = float(group.get("upper", INF))
	var spacing := AXLE_HUB_RANK_SPACING_V074
	if lower > -INF and upper < INF:
		spacing = minf(spacing, maxf(0.0, (upper - lower) / float(hubs.size() - 1)))
	for i in range(hubs.size()):
		var initial: float = float((hubs[i] as Dictionary).get("initial", 0.0))
		if i > 0 and lower > -INF:
			spacing = minf(spacing, maxf(0.0, (initial - lower) / float(i)))
		var above: int = hubs.size() - 1 - i
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
			var hub_info := hubs[i] as Dictionary
			var connector := hub_info.get("connector") as RigidBody3D
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


func _build_axle_stop_ranges_v070() -> void:
	super._build_axle_stop_ranges_v070()
	_apply_ranked_axle_stops_v074()


# Interior ranked limits are predictive only. Post-step position correction is
# kept exclusively on the original lower/upper owners, preserving the exact
# v0.5.15 correction topology that was stable in the mixed spoke fixture.
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


func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_ranked_stop_count_v074 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
