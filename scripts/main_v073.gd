extends "res://scripts/main_v072.gd"

# v0.5.17 release candidate follow-up.
# Solver preflight may temporarily disable an otherwise legitimate AXLE joint as
# redundant. Wake ownership must therefore come from the authoritative saved
# connection graph, not from the temporary solver-active joint list.

func _wake_authoritative_axles_v073() -> int:
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
		for seed_value in [connector, rod]:
			var seed := seed_value as RigidBody3D
			for body_value in _fixed_component_for_axle_v072(seed):
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


func _wake_active_axle_components_v072() -> int:
	return _wake_authoritative_axles_v073()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	# Reassert after the complete inherited release path. This intentionally does
	# not depend on whether preflight left a particular AxleJoint solver-active.
	var awakened := _wake_authoritative_axles_v073()
	_protect_active_axle_collisions_v072()
	_status("Physics running — %d authoritative AXLE-side bodies kept awake; physical stops remain collidable" % awakened)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not simulating:
		return
	# Android/Jolt may reconsider sleeping after freeze/contact state changes.
	# Authoritative AXLE islands stay non-sleeping for the duration of SIMULATE.
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body) or not active_axle_component_ids_v072.has(body.get_instance_id()):
			continue
		body.can_sleep = false
		body.sleeping = false
