extends "res://scripts/main_v072.gd"

const VERSION_083 := "0.5.16"
const O_RING_SIM_LAYER_V083 := 8
const O_RING_CONNECTOR_LAYER_V083 := 16
const O_RING_SIM_HITBOX_HEIGHT_V083 := 0.42

var o_ring_connector_state_v083: Array = []
var o_ring_sim_hitboxes_v083: Array = []


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_083)
	_status("v0.5.16 candidate — O-Rings are simple rod-pinned physical collider stops.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_083, text]


# O-Rings are ordinary physical stops. Disable the special scripted axle-stop
# system completely in this runtime.
func _build_axle_stop_ranges_v070() -> void:
	axle_stop_ranges_v070.clear()


func _predict_axle_stops_v071(_delta: float) -> void:
	pass


func _correct_axle_stop_positions_v071() -> void:
	pass


func _restore_connector_collision_v083() -> void:
	for value in o_ring_connector_state_v083:
		var state := value as Dictionary
		var connector := state.get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			continue
		connector.collision_layer = int(state.get("layer", connector.collision_layer))
		connector.collision_mask = int(state.get("mask", connector.collision_mask))
	o_ring_connector_state_v083.clear()


func _enable_connector_collision_v083() -> void:
	_restore_connector_collision_v083()
	for body_value in bodies:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		o_ring_connector_state_v083.append({
			"connector": connector,
			"layer": connector.collision_layer,
			"mask": connector.collision_mask,
		})
		connector.collision_layer |= O_RING_CONNECTOR_LAYER_V083
		connector.collision_mask |= O_RING_SIM_LAYER_V083


func _add_sim_hitbox_v083(ring: RigidBody3D) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "O_Ring_Sim_Hitbox_v083"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = O_RING_RADIUS
	cylinder.height = O_RING_SIM_HITBOX_HEIGHT_V083
	collision.shape = cylinder
	collision.set_meta("o_ring_sim_hitbox_v083", true)
	ring.add_child(collision)
	o_ring_sim_hitboxes_v083.append(collision)


# Keep the O-Ring's existing fixed mount to its rod alive during SIMULATE. The
# ring remains a separate physics body, so the AXLE connector's rod collision
# exception cannot suppress connector-vs-O-Ring contact.
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

		# Defensive recovery from any previous experimental detached-follower state.
		_restore_o_ring_joint_v068(joint)
		o_ring_followers_v068.append({
			"ring": ring,
			"rod": rod,
			"joint": joint,
			"collision_layer": ring.collision_layer,
			"collision_mask": ring.collision_mask,
			"continuous_cd": ring.continuous_cd,
			"freeze_mode": ring.freeze_mode,
			"can_sleep": ring.can_sleep,
		})

		# Dedicated connector-only collision. Rods never receive layer 16, so the
		# O-Ring cannot collide with its host axle or any other rod.
		ring.collision_layer = O_RING_SIM_LAYER_V083
		ring.collision_mask = O_RING_CONNECTOR_LAYER_V083
		ring.continuous_cd = true
		ring.can_sleep = false
		ring.freeze = false
		ring.sleeping = false
		ring.linear_velocity = rod.linear_velocity
		ring.angular_velocity = rod.angular_velocity
		_add_sim_hitbox_v083(ring)
		prepared += 1

	if prepared > 0:
		_enable_connector_collision_v083()
	return prepared


# The fixed joint owns the O-Ring transform. No manual follower teleporting.
func _sync_o_ring_followers_v068() -> void:
	pass


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_connector_collision_v083()
	for shape_value in o_ring_sim_hitboxes_v083:
		var collision := shape_value as CollisionShape3D
		if is_instance_valid(collision):
			collision.queue_free()
	o_ring_sim_hitboxes_v083.clear()

	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var joint := follower.get("joint") as Joint3D
		_restore_o_ring_joint_v068(joint)
		if not is_instance_valid(ring):
			continue
		ring.collision_layer = int(follower.get("collision_layer", ring.collision_layer))
		ring.collision_mask = int(follower.get("collision_mask", ring.collision_mask))
		ring.continuous_cd = bool(follower.get("continuous_cd", false))
		ring.freeze_mode = int(follower.get("freeze_mode", RigidBody3D.FREEZE_MODE_STATIC))
		ring.can_sleep = bool(follower.get("can_sleep", true))
		ring.freeze = true
		ring.sleeping = false
		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		if restore_build_pose and ring.has_meta("build_transform"):
			ring.global_transform = ring.get_meta("build_transform") as Transform3D
	o_ring_followers_v068.clear()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		ring.freeze = false
		ring.sleeping = false
		ring.linear_velocity = rod.linear_velocity
		ring.angular_velocity = rod.angular_velocity
	_status("Physics running — %d physical O-Ring stop%s pinned to rod%s; AXLE connectors stop by collider contact." % [
		o_ring_followers_v068.size(),
		"" if o_ring_followers_v068.size() == 1 else "s",
		"" if o_ring_followers_v068.size() == 1 else "s"
	])


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.16 O-RING: the O-Ring is a normal rod-mounted physical stopper. Its existing fixed mount stays active in SIMULATE and its own connector-only collider stops AXLE connectors. Rods are excluded by collision layer, so the stop never collides with its host axle. No ownership/rank solver, scripted axle travel clamp, extra AXLE joint, hub-order guard, or manual follower transform is used. BUILD selection/movement remains unchanged."
