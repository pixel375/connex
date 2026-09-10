extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const AXLE_HUB_RANK_SPACING_V074 := 0.62

var axle_ranked_stop_count_v074: int = 0


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring stops
#
# v0.5.15 became stable by stopping only the hub nearest each O-Ring/rod end.
# That leaves one rare failure: Jolt can tunnel an interior AXLE hub through the
# outer hub, after which the interior hub has no boundary and can reach the
# O-Ring.
#
# Preserve the same deterministic rod-local stop solver, but give every hub in
# the initial physical order a non-overlapping travel interval. Adjacent ranks
# are separated by the connector thickness (0.62 units). Nothing is done every
# frame between hubs: no hub-hub impulse, ownership swap, teleport, or new joint.
# The normal v0.5.15 predictor/corrector simply sees a distinct lower/upper stop
# for each rank. The outer hub still reaches the real O-Ring clearance; hubs
# behind it can approach until they would physically contact the hub ahead.
# -----------------------------------------------------------------------------

func _rank_spacing_for_group_v074(group: Dictionary) -> float:
	var hubs: Array = group.get("hubs", []) as Array
	if hubs.size() <= 1:
		return 0.0
	var lower: float = float(group.get("lower", -INF))
	var upper: float = float(group.get("upper", INF))
	var spacing := AXLE_HUB_RANK_SPACING_V074

	# Never make SIMULATE reposition a valid BUILD pose merely to create the rank
	# limits. If a deliberately compact build starts with less than 0.62 spacing,
	# shrink only this segment's rank spacing to fit its existing geometry.
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
			if lower > -INF:
				stop["lower"] = lower + spacing * float(i)
			if upper < INF:
				stop["upper"] = upper - spacing * float(hubs.size() - 1 - i)
			stop["rank_spacing_v074"] = spacing
			stop["ranked_stop_v074"] = hubs.size() > 1
			if hubs.size() > 1:
				axle_ranked_stop_count_v074 += 1


func _build_axle_stop_ranges_v070() -> void:
	# main_v073 builds the stable v0.5.15 segment ownership plus the initial hub
	# order metadata. Convert those ranges once, at simulation setup, into distinct
	# non-overlapping rank intervals. Runtime stop enforcement remains v0.5.15.
	super._build_axle_stop_ranges_v070()
	_apply_ranked_axle_stops_v074()


# Disable the abandoned dynamic ownership/order guards from main_v073. Initial
# physical rank is fixed for this simulation, just as solid connectors cannot
# pass through each other on a real axle.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_ranked_stop_count_v074 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
