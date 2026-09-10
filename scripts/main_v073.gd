extends "res://scripts/main_v072.gd"

# v0.5.17 release candidate follow-up.
# Solver preflight may temporarily disable an otherwise legitimate AXLE joint as
# redundant. Wake ownership must therefore come from the authoritative saved
# connection graph, not from the temporary solver-active joint list.

func _wake_active_axle_components_v072() -> int:
	active_axle_component_ids_v072.clear()
	_rebuild_connection_graph_v020()
	var awakened := 0
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		for seed in [connector, rod]:
			for body_value in _fixed_component_for_axle_v072(seed as RigidBody3D):
				var body := body_value as RigidBody3D
				if not is_instance_valid(body):
					continue
				var id := body.get_instance_id()
				if active_axle_component_ids_v072.has(id):
					continue
				active_axle_component_ids_v072[id] = true
				body.can_sleep = false
				body.freeze = false
				body.sleeping = false
				body.continuous_cd = true
				awakened += 1
	return awakened
