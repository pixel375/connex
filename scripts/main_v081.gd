extends "res://scripts/main_v080.gd"

const VERSION_081 := "0.5.16"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_081)
	_status("v0.5.16 test runtime — native hub contact restored; deterministic AXLE guard intervenes only before a would-cross event.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_081, text]


# v076 permanently disabled collision between every pair of AXLE hubs in a
# protected O-Ring segment. The v080 trace showed the stack could then remain
# numerically ordered for hundreds of frames yet eventually develop a common-mode
# solver instability. Restore the v0.5.15 load path: ordinary Jolt connector
# contact stays active at rest. We still build the immutable ordered component
# metadata needed by the predictive guard and rare residual repair, but add NO
# hub-to-hub collision exception and NO force-integration callback.
func _prepare_component_groups_v076() -> int:
	_clear_component_callbacks_v076()
	axle_component_groups_v076.clear()
	axle_guarded_hubs_v076.clear()
	axle_component_guard_events_v076 = 0
	axle_component_projection_events_v076 = 0
	axle_component_invalid_groups_v076 = 0
	axle_pair_guard_events_v074 = 0
	axle_pair_projection_events_v074 = 0
	axle_pair_collision_exception_count_v074 = 0
	var prepared_hubs := 0

	for group_value in axle_order_groups_v073:
		var source_group := group_value as Dictionary
		var rod := source_group.get("rod") as RigidBody3D
		var hubs: Array = source_group.get("hubs", []) as Array
		var segment: int = int(source_group.get("segment", 0))
		if not is_instance_valid(rod) or hubs.size() <= 1 or not _group_has_o_ring_v074(source_group):
			continue

		var guarded_hubs: Array = []
		var valid_group := true
		for hub_value in hubs:
			var hub_info := hub_value as Dictionary
			var connector := hub_info.get("connector") as RigidBody3D
			var stop: Dictionary = _find_stop_v074(rod, connector, segment)
			if not is_instance_valid(connector) or stop.is_empty():
				valid_group = false
				break
			var component: Array = _stop_component_v071(stop)
			if component.is_empty():
				component = [connector]
			for existing_value in guarded_hubs:
				if _components_overlap_v076(component, (existing_value as Dictionary).get("component", []) as Array):
					valid_group = false
					break
			if not valid_group:
				break
			guarded_hubs.append({
				"connector": connector,
				"component": component,
				"mass": _component_mass_v076(component),
				"uid": int(hub_info.get("uid", -1)),
			})

		if not valid_group or guarded_hubs.size() != hubs.size():
			axle_component_invalid_groups_v076 += 1
			continue

		# Read finite travel limits directly from the authoritative v0.5.15 stop
		# records rather than from duplicate group metadata.
		var first_connector := (guarded_hubs[0] as Dictionary).get("connector") as RigidBody3D
		var last_connector := (guarded_hubs[guarded_hubs.size() - 1] as Dictionary).get("connector") as RigidBody3D
		var first_stop: Dictionary = _find_stop_v074(rod, first_connector, segment)
		var last_stop: Dictionary = _find_stop_v074(rod, last_connector, segment)
		var lower: float = float(first_stop.get("lower", source_group.get("lower", -INF)))
		var upper: float = float(last_stop.get("upper", source_group.get("upper", INF)))
		if lower > -INF and upper < INF and upper - lower < AXLE_PAIR_SEPARATION_V079 * float(guarded_hubs.size() - 1):
			axle_component_invalid_groups_v076 += 1
			continue

		for guarded_value in guarded_hubs:
			var guarded := guarded_value as Dictionary
			var connector := guarded.get("connector") as RigidBody3D
			if is_instance_valid(connector):
				axle_guarded_hubs_v076[connector.get_instance_id()] = true
				prepared_hubs += 1

		axle_component_groups_v076.append({
			"rod": rod,
			"hubs": guarded_hubs,
			"lower": lower,
			"upper": upper,
			"segment": segment,
		})

	return prepared_hubs


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — native hub collision carries resting AXLE loads; velocity guard prevents imminent order crossing without extra joints or collision exclusions.")
