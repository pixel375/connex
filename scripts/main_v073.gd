extends "res://scripts/main_v072.gd"

# v0.5.17 release candidate follow-up.
# Two independent pieces of state must stay deterministic across save/load:
# 1) AXLE edges must serialize as AXLEs, never as generic fixed joints.
# 2) solver wake/collision ownership must be captured before preflight mutates
#    temporary node_a/node_b bindings.

var authoritative_axle_component_ids_v073: Dictionary = {}
var authoritative_axle_pairs_v073: Array = []


func _capture_state() -> Dictionary:
	var snapshot: Dictionary = super._capture_state()
	# The legacy serializer decides axle-vs-fixed from a node name. Keep that old
	# format for compatibility, but correct its type from authoritative connection
	# metadata. This prevents an AXLE from returning as a second fixed/socket joint
	# beside the repaired AXLE on the next load.
	var saved_joints: Array = snapshot.get("joints", []) as Array
	var live_body_ids: Dictionary = {}
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			live_body_ids[body.get_instance_id()] = true
	var saved_index := 0
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes.size() < 2:
			continue
		var a := nodes[0] as RigidBody3D
		var b := nodes[1] as RigidBody3D
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if not live_body_ids.has(a.get_instance_id()) or not live_body_ids.has(b.get_instance_id()):
			continue
		if saved_index >= saved_joints.size():
			break
		var state := saved_joints[saved_index] as Dictionary
		var kind := str(joint.get_meta("connection_kind_v020", ""))
		state["type"] = "axle" if kind == "axle" or str(joint.name).begins_with("AxleJoint") else "fixed"
		saved_index += 1
	snapshot["joints"] = saved_joints
	return snapshot


func _axle_pair_key_v073(connector: RigidBody3D, rod: RigidBody3D) -> String:
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return ""
	return "%d:%d" % [_ensure_piece_uid_v020(connector), _ensure_piece_uid_v020(rod)]


func _remove_false_fixed_axle_duplicates_v073() -> int:
	# A single straight rod cannot simultaneously be the same connector's center
	# AXLE and one of its fixed SOCKET/CROSS mounts. Older/broken round-trips could
	# reconstruct the saved AXLE once as a fixed joint, then v0.5.17 correctly
	# repair the missing AXLE as a second joint. The fixed twin makes union-find put
	# both AXLE sides in one rigid island, so preflight disables the real AXLE.
	_rebuild_connection_graph_v020()
	var axle_pairs: Dictionary = {}
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		var key := _axle_pair_key_v073(connector, rod)
		if not key.is_empty():
			axle_pairs[key] = true

	var removed := 0
	for joint_value in joints.duplicate():
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes.size() < 2:
			continue
		var a := nodes[0] as RigidBody3D
		var b := nodes[1] as RigidBody3D
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		var connector: RigidBody3D = a if str(a.get_meta("kind", "")) == "connector" else (b if str(b.get_meta("kind", "")) == "connector" else null)
		var rod: RigidBody3D = a if str(a.get_meta("kind", "")) == "rod" else (b if str(b.get_meta("kind", "")) == "rod" else null)
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var key := _axle_pair_key_v073(connector, rod)
		if key.is_empty() or not axle_pairs.has(key):
			continue
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joints.erase(joint)
		joint.queue_free()
		removed += 1

	if removed > 0:
		_rebuild_connection_graph_v020()
		_recalculate_occupancy_from_joints()
		_rebuild_connection_graph_v020()
		for record_value in connections_v020:
			var record := record_value as Dictionary
			if str(record.get("kind", "")) != "axle":
				continue
			var connector := record.get("connector") as RigidBody3D
			var rod := record.get("rod") as RigidBody3D
			if is_instance_valid(connector) and is_instance_valid(rod):
				connector.set_meta("axle_occupied", true)
				connector.set_meta("axle_host_rod", rod)
	return removed


func _restore_state(snapshot: Dictionary) -> void:
	super._restore_state(snapshot)
	var removed := _remove_false_fixed_axle_duplicates_v073()
	_canonicalize_all_axles_v072()
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	if removed > 0:
		print("AXLE_RESTORE_REPAIR_073: removed %d false fixed duplicates beside authoritative AXLEs" % removed)


func _cache_authoritative_axle_components_v073() -> int:
	authoritative_axle_component_ids_v073.clear()
	authoritative_axle_pairs_v073.clear()
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
