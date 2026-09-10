extends "res://scripts/main_v071.gd"

const VERSION_072 := "0.5.17"

# v0.5.17 fixes a general AXLE simulation problem, not an O-Ring special case.
# Every AXLE is normalized from the authoritative connection graph before each
# simulation and after state restore. Both fixed components connected by an
# active axle remain awake, and physical bodies on the opposite component keep
# their collisions even when the old rigid-component preflight installed broad
# collision exceptions elsewhere in the construction.

var active_axle_component_ids_v072: Dictionary = {}
var protected_axle_collision_pairs_v072: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_072)
	_status("v0.5.17 ready — AXLE state is deterministic across build/load and physical CROSS stops stay collidable.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_072, text]


func _axle_bodies_v072(joint: Joint3D) -> Dictionary:
	if not is_instance_valid(joint):
		return {}
	var nodes: Array = _joint_nodes(joint)
	if nodes.size() < 2:
		return {}
	var a := nodes[0] as RigidBody3D
	var b := nodes[1] as RigidBody3D
	if not is_instance_valid(a) or not is_instance_valid(b):
		return {}
	var connector: RigidBody3D = a if str(a.get_meta("kind", "")) == "connector" else (b if str(b.get_meta("kind", "")) == "connector" else null)
	var rod: RigidBody3D = a if str(a.get_meta("kind", "")) == "rod" else (b if str(b.get_meta("kind", "")) == "rod" else null)
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return {}
	return {"connector": connector, "rod": rod}


func _canonicalize_axle_joint_v072(joint: Generic6DOFJoint3D, connector: RigidBody3D) -> void:
	if not is_instance_valid(joint) or not is_instance_valid(connector):
		return
	# The connector collider is intentionally a solid disk, so the host rod itself
	# must remain excluded. Nothing else on the host component inherits this rule.
	joint.exclude_nodes_from_collision = true
	joint.global_transform = connector.global_transform
	for axis_name in ["x", "z"]:
		joint.set("linear_limit_%s/enabled" % axis_name, true)
		joint.set("linear_limit_%s/lower_distance" % axis_name, 0.0)
		joint.set("linear_limit_%s/upper_distance" % axis_name, 0.0)
		joint.set("angular_limit_%s/enabled" % axis_name, true)
		joint.set("angular_limit_%s/lower_angle" % axis_name, 0.0)
		joint.set("angular_limit_%s/upper_angle" % axis_name, 0.0)
	# AXLE means exactly two free DOFs: translate along local Y and rotate around Y.
	joint.set("linear_limit_y/enabled", false)
	joint.set("angular_limit_y/enabled", false)
	joint.set_meta("axle_canonical_v072", true)


func _canonicalize_all_axles_v072() -> int:
	_rebuild_connection_graph_v020()
	var count := 0
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var joint := record.get("joint") as Generic6DOFJoint3D
		var connector := record.get("connector") as RigidBody3D
		if not is_instance_valid(joint) or not is_instance_valid(connector):
			continue
		_canonicalize_axle_joint_v072(joint, connector)
		count += 1
	if count > 0:
		_rebind_all_joints()
	return count


func _fixed_component_for_axle_v072(seed: RigidBody3D) -> Array:
	# The inherited component walker intentionally ignores AxleJoint nodes, which
	# is exactly what is needed here: each side of the free joint is one rigid island.
	return _fixed_component(seed)


func _pair_matches_v072(pair: Array, a: RigidBody3D, b: RigidBody3D) -> bool:
	if pair.size() < 2:
		return false
	var x := pair[0] as RigidBody3D
	var y := pair[1] as RigidBody3D
	return (x == a and y == b) or (x == b and y == a)


func _remove_tracked_collision_exception_v072(a: RigidBody3D, b: RigidBody3D) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b) or a == b:
		return false
	var key: String = _collision_pair_key(a, b)
	var tracked: bool = simulation_collision_pair_keys.has(key)
	# remove_collision_exception_with is safe even if the pair is not currently
	# excluded, so this also repairs stale body-level exceptions after a restore.
	a.remove_collision_exception_with(b)
	b.remove_collision_exception_with(a)
	simulation_collision_pair_keys.erase(key)
	for i in range(simulation_collision_pairs.size() - 1, -1, -1):
		var pair := simulation_collision_pairs[i] as Array
		if _pair_matches_v072(pair, a, b):
			simulation_collision_pairs.remove_at(i)
	return tracked


func _protect_active_axle_collisions_v072() -> int:
	# The old v0.1.4 preflight deliberately suppresses collision inside rigid
	# islands. That is fine. Across an ACTIVE axle, however, the two rigid islands
	# are mechanically separate and must collide. In particular, a CROSS-mounted
	# connector on the host shaft must be able to stop an AXLE-mounted connector.
	var restored := 0
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint") or bool(joint.get_meta("sim_disabled", false)):
			continue
		var pair_info: Dictionary = _axle_bodies_v072(joint)
		if pair_info.is_empty():
			continue
		var connector := pair_info.get("connector") as RigidBody3D
		var rod := pair_info.get("rod") as RigidBody3D
		var slider_component: Array = _fixed_component_for_axle_v072(connector)
		var host_component: Array = _fixed_component_for_axle_v072(rod)
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
				# Keep only the direct hub<->shaft exclusion required by the fake solid
				# hub collider. Every other cross-island pair is real physical contact.
				if slider == connector and host == rod:
					continue
				if _remove_tracked_collision_exception_v072(slider, host):
					restored += 1
	protected_axle_collision_pairs_v072 = restored
	return restored


func _wake_active_axle_components_v072() -> int:
	active_axle_component_ids_v072.clear()
	var awakened := 0
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint") or bool(joint.get_meta("sim_disabled", false)):
			continue
		var pair_info: Dictionary = _axle_bodies_v072(joint)
		if pair_info.is_empty():
			continue
		for seed_key in ["connector", "rod"]:
			var seed := pair_info.get(seed_key) as RigidBody3D
			if not is_instance_valid(seed):
				continue
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


func _restore_axle_sleep_policy_v072() -> void:
	active_axle_component_ids_v072.clear()
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			body.can_sleep = true
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.can_sleep = true


func _prepare_stable_simulation_graph() -> void:
	# Canonicalize before the inherited union-find analysis so a save/load or an
	# earlier simulation cannot leak altered 6DOF settings into the next run.
	_canonicalize_all_axles_v072()
	super._prepare_stable_simulation_graph()
	# The inherited preflight is allowed to suppress true rigid self-collision.
	# Reassert contact only across active AXLE islands after that analysis.
	_protect_active_axle_collisions_v072()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	var awakened: int = _wake_active_axle_components_v072()
	_protect_active_axle_collisions_v072()
	_status("Physics running — %d AXLE-side bodies kept awake; physical CROSS/O-Ring stops remain collidable" % awakened)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not simulating:
		return
	# can_sleep=false should be sufficient, but explicitly clear sleeping here to
	# make Android/Jolt behavior deterministic after save/load and contact changes.
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body) and active_axle_component_ids_v072.has(body.get_instance_id()):
			body.sleeping = false


func _restore_state(snapshot: Dictionary) -> void:
	_restore_axle_sleep_policy_v072()
	super._restore_state(snapshot)
	_restore_axle_sleep_policy_v072()
	_canonicalize_all_axles_v072()
	_clear_simulation_collision_exceptions()
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()


func _reset_pose() -> void:
	_restore_axle_sleep_policy_v072()
	super._reset_pose()
	_restore_axle_sleep_policy_v072()
	_canonicalize_all_axles_v072()


func _restart_build() -> void:
	_restore_axle_sleep_policy_v072()
	super._restart_build()
	_restore_axle_sleep_policy_v072()
	_canonicalize_all_axles_v072()


func _save_named_build_v050() -> void:
	# A running simulation contains temporary solver edits (softened cycle edges,
	# disabled redundant constraints, collision exceptions). Never serialize that
	# transient graph. Save the canonical BUILD graph only.
	if simulating:
		_status("Return to BUILD before saving — simulation solver state is temporary and is never written to a build")
		return
	super._save_named_build_v050()


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_072) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_072)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
