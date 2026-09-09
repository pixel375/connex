extends "res://scripts/main_v067.gd"

const VERSION_068 := "0.5.13-dev"
const RUNAWAY_LINEAR_TRIGGER_V068 := 42.0
const RUNAWAY_ANGULAR_TRIGGER_V068 := 55.0
const RUNAWAY_LINEAR_RECOVER_V068 := 18.0
const RUNAWAY_ANGULAR_RECOVER_V068 := 24.0

var runaway_guard_events_v068: int = 0
var runaway_guard_last_status_ms_v068: int = 0
var o_ring_followers_v068: Array = []
var o_ring_proxy_shapes_v068: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_068)
	_status("O-Ring Stops now move with their host rods without adding unstable extra rigid-body welds.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_068, text]


func _disable_o_ring_joint_v068(joint: Joint3D) -> void:
	if not is_instance_valid(joint) or bool(joint.get_meta("sim_o_ring_detached_v068", false)):
		return
	joint.set_meta("sim_o_ring_saved_node_a_v068", joint.node_a)
	joint.set_meta("sim_o_ring_saved_node_b_v068", joint.node_b)
	joint.set_meta("sim_o_ring_detached_v068", true)
	joint.node_a = NodePath()
	joint.node_b = NodePath()


func _restore_o_ring_joint_v068(joint: Joint3D) -> void:
	if not is_instance_valid(joint) or not bool(joint.get_meta("sim_o_ring_detached_v068", false)):
		return
	joint.node_a = joint.get_meta("sim_o_ring_saved_node_a_v068", NodePath()) as NodePath
	joint.node_b = joint.get_meta("sim_o_ring_saved_node_b_v068", NodePath()) as NodePath
	joint.remove_meta("sim_o_ring_saved_node_a_v068")
	joint.remove_meta("sim_o_ring_saved_node_b_v068")
	joint.remove_meta("sim_o_ring_detached_v068")


func _add_o_ring_proxy_shapes_v068(ring: RigidBody3D, rod: RigidBody3D) -> int:
	var added := 0
	for child_value in ring.get_children():
		var source := child_value as CollisionShape3D
		if source == null or source.shape == null or source.disabled:
			continue
		var proxy := CollisionShape3D.new()
		proxy.name = "O_Ring_Stop_Proxy_%d" % o_ring_proxy_shapes_v068.size()
		proxy.shape = source.shape.duplicate(true)
		var world_shape: Transform3D = ring.global_transform * source.transform
		proxy.transform = rod.global_transform.affine_inverse() * world_shape
		proxy.set_meta("sim_o_ring_proxy_v068", true)
		rod.add_child(proxy)
		o_ring_proxy_shapes_v068.append(proxy)
		added += 1
	return added


func _prepare_o_ring_followers_v068() -> int:
	_restore_o_ring_followers_v068(false)
	_rebuild_connection_graph_v020()
	var prepared := 0
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "o_ring":
			continue
		var joint := record.get("joint") as Joint3D
		var ring := record.get("ring") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(joint) or not is_instance_valid(ring) or not is_instance_valid(rod):
			continue

		var local_transform: Transform3D = rod.global_transform.affine_inverse() * ring.global_transform
		var original_parent := ring.get_parent()
		var original_index := ring.get_index()
		o_ring_followers_v068.append({
			"ring": ring,
			"rod": rod,
			"joint": joint,
			"local_transform": local_transform,
			"collision_layer": ring.collision_layer,
			"collision_mask": ring.collision_mask,
			"original_parent": original_parent,
			"original_index": original_index,
		})

		_disable_o_ring_joint_v068(joint)
		_add_o_ring_proxy_shapes_v068(ring, rod)

		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		ring.freeze = true
		ring.sleeping = false
		ring.can_sleep = true
		ring.collision_layer = 0
		ring.collision_mask = 0
		ring.continuous_cd = false

		# Make the visible ring a direct transform child of the host rod. This is
		# deterministic and cannot lag one physics frame behind the host.
		ring.reparent(rod, true)
		ring.transform = local_transform
		prepared += 1

	if prepared > 0:
		_rebind_all_joints()
	return prepared


func _sync_o_ring_followers_v068() -> void:
	if not simulating:
		return
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		var local_transform := follower.get("local_transform", Transform3D.IDENTITY) as Transform3D
		if ring.get_parent() != rod:
			ring.reparent(rod, true)
		ring.transform = local_transform
		ring.linear_velocity = rod.linear_velocity
		ring.angular_velocity = rod.angular_velocity


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	for proxy_value in o_ring_proxy_shapes_v068:
		var proxy := proxy_value as CollisionShape3D
		if is_instance_valid(proxy):
			proxy.queue_free()
	o_ring_proxy_shapes_v068.clear()

	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var joint := follower.get("joint") as Joint3D
		if is_instance_valid(ring):
			var original_parent := follower.get("original_parent") as Node
			if is_instance_valid(original_parent) and ring.get_parent() != original_parent:
				ring.reparent(original_parent, true)
				var original_index := int(follower.get("original_index", -1))
				if original_index >= 0 and original_index < original_parent.get_child_count():
					original_parent.move_child(ring, original_index)
		_restore_o_ring_joint_v068(joint)
		if not is_instance_valid(ring):
			continue
		ring.collision_layer = int(follower.get("collision_layer", 1))
		ring.collision_mask = int(follower.get("collision_mask", 1))
		ring.freeze = true
		ring.sleeping = false
		ring.can_sleep = true
		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		if restore_build_pose and ring.has_meta("build_transform"):
			ring.global_transform = ring.get_meta("build_transform") as Transform3D
	o_ring_followers_v068.clear()
	_rebind_all_joints()


func _set_simulation_ccd_v068(enabled: bool) -> void:
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			body.continuous_cd = enabled


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	_prepare_o_ring_followers_v068()
	_set_simulation_ccd_v068(true)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_sync_o_ring_followers_v068()
	_status("Physics running — Structure Rigidity %d%%; %d axle slides awake; %d O-Ring Stop%s welded to host physics" % [
		int(round(active_structure_rigidity_v067)),
		_wake_axle_rods_v067(),
		o_ring_followers_v068.size(),
		"" if o_ring_followers_v068.size() == 1 else "s"
	])


func _reset_pose() -> void:
	_set_simulation_ccd_v068(false)
	_restore_o_ring_followers_v068(true)
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_set_simulation_ccd_v068(false)
	_restore_o_ring_followers_v068(false)
	super._restore_state(snapshot)


func _restart_build() -> void:
	_set_simulation_ccd_v068(false)
	_restore_o_ring_followers_v068(false)
	super._restart_build()


func _guard_body_energy_v068(body: RigidBody3D) -> bool:
	if not is_instance_valid(body) or body.freeze:
		return false
	var linear_speed := body.linear_velocity.length()
	var angular_speed := body.angular_velocity.length()
	if linear_speed <= RUNAWAY_LINEAR_TRIGGER_V068 and angular_speed <= RUNAWAY_ANGULAR_TRIGGER_V068:
		return false
	if linear_speed > RUNAWAY_LINEAR_RECOVER_V068:
		body.linear_velocity = body.linear_velocity.normalized() * RUNAWAY_LINEAR_RECOVER_V068
	if angular_speed > RUNAWAY_ANGULAR_RECOVER_V068:
		body.angular_velocity = body.angular_velocity.normalized() * RUNAWAY_ANGULAR_RECOVER_V068
	body.sleeping = false
	return true


func _guard_simulation_energy_v068() -> bool:
	if not simulating:
		return false
	var tripped := false
	for body_value in bodies:
		tripped = _guard_body_energy_v068(body_value as RigidBody3D) or tripped
	if not tripped:
		return false
	runaway_guard_events_v068 += 1
	var now := Time.get_ticks_msec()
	if now - runaway_guard_last_status_ms_v068 > 700:
		runaway_guard_last_status_ms_v068 = now
		_status("Stability guard damped a pathological solver-energy spike; build connections remain intact.")
	return true


func _physics_process(_delta: float) -> void:
	_sync_o_ring_followers_v068()
	_guard_simulation_energy_v068()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_o_ring_followers_v068()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.13 O-RINGS / STABILITY: an O-Ring Stop is physically welded into its host rod during SIMULATE instead of being solved as a separate tiny rigid body plus hard 6DOF joint. Its visible ring is temporarily parented directly to the rod, and its collision shape is copied into the host rod, so it still acts as a real axle stop without becoming an invisible world anchor or unstable high-frequency constraint. BUILD/Restore returns the original editable ring body and joint. SIMULATE also enables continuous collision detection on construction bodies and uses Jolt with higher solver iteration counts for hard impacts."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_068) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_068)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
