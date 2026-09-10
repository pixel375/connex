extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"


func _assign_axle_stop_order_v074(group: Dictionary, ordered: Array) -> bool:
	var previous: Array = group.get("hubs", []) as Array
	if _same_hub_order_v073(previous, ordered):
		return false
	var rod := group.get("rod") as RigidBody3D
	if not is_instance_valid(rod) or ordered.is_empty():
		return false
	var segment: int = int(group.get("segment", 0))
	var lower_boundary: float = float(group.get("lower", -INF))
	var upper_boundary: float = float(group.get("upper", INF))

	for stop_value in axle_stop_ranges_v070:
		var stop := stop_value as Dictionary
		if stop.get("rod") == rod and int(stop.get("segment", -999)) == segment:
			stop["lower"] = -INF
			stop["upper"] = INF
			stop["segment_index"] = -1

	for i in range(ordered.size()):
		var hub_info := ordered[i] as Dictionary
		var connector := hub_info.get("connector") as RigidBody3D
		for stop_value in axle_stop_ranges_v070:
			var stop := stop_value as Dictionary
			if stop.get("rod") != rod or stop.get("connector") != connector or int(stop.get("segment", -999)) != segment:
				continue
			stop["segment_index"] = i
			if i == 0:
				stop["lower"] = lower_boundary
			if i == ordered.size() - 1:
				stop["upper"] = upper_boundary
			break
	group["hubs"] = ordered
	axle_order_guard_events_v073 += 1
	return true


func _predicted_hub_order_v074(group: Dictionary, delta: float) -> Array:
	var rod := group.get("rod") as RigidBody3D
	var ordered: Array = (group.get("hubs", []) as Array).duplicate()
	if not is_instance_valid(rod) or delta <= 0.000001:
		return ordered
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var body_a := a.get("connector") as RigidBody3D
		var body_b := b.get("connector") as RigidBody3D
		if not is_instance_valid(body_a):
			return false
		if not is_instance_valid(body_b):
			return true
		var along_a: float = _rod_local_along_v070(body_a, rod)
		var along_b: float = _rod_local_along_v070(body_b, rod)
		var speed_a: float = (body_a.linear_velocity - rod.linear_velocity).dot(axis)
		var speed_b: float = (body_b.linear_velocity - rod.linear_velocity).dot(axis)
		return along_a + speed_a * delta < along_b + speed_b * delta
	)
	return ordered


# Predict only ownership. No hub/rod transform or velocity is changed here.
# This lets the inherited v0.5.15 stop predictor act on the hub that is about to
# become outermost before that hub can reach an O-Ring in the same physics step.
func _predict_axle_order_v073(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		_assign_axle_stop_order_v074(group, _predicted_hub_order_v074(group, delta))


# main_v074 performs the current-position handoff before invoking the inherited
# correction. Returning false here prevents main_v073 from doing a second owner
# change/correction after the first physical stop correction in the same sync.
func _correct_axle_order_v073() -> bool:
	return false


func _predict_axle_stops_v071(delta: float) -> void:
	_predict_axle_order_v073(delta)
	super._predict_axle_stops_v071(delta)


func _correct_axle_stop_positions_v071() -> void:
	_handoff_axle_stop_ownership_v073()
	super._correct_axle_stop_positions_v071()
