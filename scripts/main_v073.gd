extends "res://scripts/main_v072.gd"

# v0.5.17 release candidate follow-up.
# The stable solver is allowed to temporarily disable redundant joints. AXLE
# wake and collision ownership therefore have to be captured before preflight
# mutates node_a/node_b, then reused for the entire simulation.

var authoritative_axle_component_ids_v073: Dictionary = {}
var authoritative_axle_pairs_v073: Array = []


func _cache_authoritative_axle_components_v073() -> int:
	authoritative_axle_component_ids_v073.clear()
	authoritative_axle_pairs_v073.clear()
	# At this point the BUILD graph is intact, so rebuilding is safe and gives us
	# the exact saved/live AXLE records before the solver starts suppressing edges.
	_rebuild_connection_graph_v020()
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var slider_component: Array = _fixed_component_for_axle_v072(connector)
		var host_component: Array = _fixed_component_for_axle_v072(rod)
		authoritative_axle_pairs_v073.append({
			"connector": connector,
			"rod": rod,
			"slider": slider_component.duplicate(),
			"host": host_component.duplicate(),
		})
		for component_value in [slider_component, host_component]:
			for body_value in component_value as Array:
				var body := body_value as RigidBody3D
				if is_instance_valid(body):
					authoritative_axle_component_ids_v073[body.get_instance_id()] = true
	return authoritative_axle_component_ids_v073.size()


func _prepare_stable_simulation_graph() -> void:
	_cache_authoritative_axle_components_v073()
	super._prepare_stable_simulation_graph()


func _wake_authoritative_axles_v073() -> int:
	active_axle_component_ids_v072.clear()
	var awakened := 0
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var id := body.get_instance_id()
		if not authoritative_axle_component_ids_v073.has(id):
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


func _protect_active_axle_collisions_v072() -> int:
	# Do not rediscover AXLEs from the solver-mutated joint list. Use the exact two
	# rigid islands cached while still in BUILD state. Only the direct hub/shaft
	# pair stays excluded because the simplified hub collider is a solid disk.
	var restored := 0
	for pair_value in authoritative_axle_pairs_v073:
		var pair := pair_value as Dictionary
		var connector := pair.get("connector") as RigidBody3D
		var rod := pair.get("rod") as RigidBody3D
		var slider_component := pair.get("slider", []) as Array
		var host_component := pair.get("host", []) as Array
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		for slider_value in slider_component:
			var slider := slider_value as RigidBody3D
			if not is_instance_valid(slider):
				continue
			slider.collision_layer |= 2
			slider.collision_mask |= 3
			slider.continuous_cd = true
			for host_value in host_component:
				var host := host_value as RigidBody3D
				if not is_instance_valid(host) or host == slider:
					continue
				host.collision_layer |= 2
				host.collision_mask |= 3
				host.continuous_cd = true
				if slider == connector and host == rod:
					continue
				if _remove_tracked_collision_exception_v072(slider, host):
					restored += 1
	protected_axle_collision_pairs_v072 = restored
	return restored


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	var awakened := _wake_authoritative_axles_v073()
	_protect_active_axle_collisions_v072()
	_status("Physics running — %d authoritative AXLE-side bodies kept awake; physical stops remain collidable" % awakened)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not simulating:
		return
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body) or not authoritative_axle_component_ids_v073.has(body.get_instance_id()):
			continue
		body.can_sleep = false
		body.sleeping = false
