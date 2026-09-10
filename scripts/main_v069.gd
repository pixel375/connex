extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
const O_RING_SIM_LAYER_V069 := 8
const O_RING_SIM_CONNECTOR_LAYER_V069 := 16

# v0.5.14 keeps the normal AXLE joint completely unchanged. During SIMULATE an
# O-Ring becomes an exact rod-relative kinematic collider. Its editable BUILD
# weld is detached, and a temporary collision-layer split lets connectors collide
# with the O-Ring while rods (including its host axle) cannot. This avoids both
# the v0.5.13 rod-owned proxy bug and collision filtering through the joint graph.
var o_ring_stop_pair_count_v069: int = 0
var o_ring_axle_replacements_v069: Array = []
var o_ring_stop_proxies_v069: Array = []
var o_ring_connector_collision_state_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops are exact rod-relative connector stops.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# Never copy O-Ring collision into the host rod. AXLE joints intentionally
# exclude connector-vs-rod collision, so a rod-owned proxy can never stop the
# axle connector reliably.
func _add_o_ring_proxy_shapes_v068(_ring: RigidBody3D, _rod: RigidBody3D) -> int:
	return 0


func _restore_o_ring_connector_collision_state_v069() -> void:
	for state_value in o_ring_connector_collision_state_v069:
		var state := state_value as Dictionary
		var connector := state.get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			continue
		connector.collision_layer = int(state.get("layer", connector.collision_layer))
		connector.collision_mask = int(state.get("mask", connector.collision_mask))
	o_ring_connector_collision_state_v069.clear()


func _enable_o_ring_connector_collision_v069() -> void:
	_restore_o_ring_connector_collision_state_v069()
	for body_value in bodies:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		o_ring_connector_collision_state_v069.append({
			"connector": connector,
			"layer": connector.collision_layer,
			"mask": connector.collision_mask,
		})
		# Keep every existing construction layer/mask bit. The extra layer lets an
		# O-Ring target connectors specifically, while the extra mask lets the
		# connector see the O-Ring's dedicated simulation layer.
		connector.collision_layer |= O_RING_SIM_CONNECTOR_LAYER_V069
		connector.collision_mask |= O_RING_SIM_LAYER_V069


func _prepare_o_ring_followers_v068() -> int:
	_restore_o_ring_followers_v068(false)
	o_ring_proxy_shapes_v068.clear()
	o_ring_stop_proxies_v069.clear()
	o_ring_axle_replacements_v069.clear()
	o_ring_stop_pair_count_v069 = 0
	_rebuild_connection_graph_v020()

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
		o_ring_followers_v068.append({
			"ring": ring,
			"rod": rod,
			"joint": joint,
			"local_transform": local_transform,
			"collision_layer": ring.collision_layer,
			"collision_mask": ring.collision_mask,
			"continuous_cd": ring.continuous_cd,
			"freeze_mode": ring.freeze_mode,
			"can_sleep": ring.can_sleep,
			"original_parent": ring.get_parent(),
			"original_index": ring.get_index(),
		})

		# Remove the BUILD weld completely from the live Jolt graph. Self-collision
		# is handled by the dedicated temporary layer split below, so the joint is
		# not needed for either force or filtering during SIMULATE.
		_disable_o_ring_joint_v068(joint)

		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		ring.continuous_cd = false
		ring.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		ring.freeze = true
		ring.sleeping = false
		ring.can_sleep = false
		# The ring sees only the temporary connector-only layer. Rods never gain
		# this bit, so the host axle cannot collide with its own stop.
		ring.collision_layer = O_RING_SIM_LAYER_V069
		ring.collision_mask = O_RING_SIM_CONNECTOR_LAYER_V069
		ring.global_transform = rod.global_transform * local_transform
		o_ring_stop_pair_count_v069 += 1

	if o_ring_stop_pair_count_v069 > 0:
		_enable_o_ring_connector_collision_v069()
		_rebind_all_joints()
	return o_ring_stop_pair_count_v069


# Keep the real O-Ring body in world space rather than nesting one physics body
# below another. The saved local transform is authoritative; idle + physics
# process synchronization keeps the displayed stop on its moving host rod.
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
		ring.global_transform = rod.global_transform * local_transform
		ring.linear_velocity = rod.linear_velocity
		ring.angular_velocity = rod.angular_velocity


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_o_ring_connector_collision_state_v069()
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		if is_instance_valid(ring):
			ring.set("freeze_mode", int(follower.get("freeze_mode", RigidBody3D.FREEZE_MODE_STATIC)))
			ring.continuous_cd = bool(follower.get("continuous_cd", false))
			ring.can_sleep = bool(follower.get("can_sleep", true))
	# The v0.5.13 base restore reparents only if necessary, restores the saved
	# collision layer/mask, reattaches the temporarily detached BUILD weld, and
	# returns the O-Ring to an editable frozen pose.
	super._restore_o_ring_followers_v068(restore_build_pose)
	o_ring_stop_pair_count_v069 = 0


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d collidable O-Ring Stop%s locked to host rod%s; AXLE slide/rotation stay free until connector contact" % [
		o_ring_stop_pair_count_v069,
		"" if o_ring_stop_pair_count_v069 == 1 else "s",
		"" if o_ring_stop_pair_count_v069 == 1 else "s"
	])


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.14 O-RING STOPPER: the real O-Ring collider is locked to its host rod as a frozen kinematic body synchronized in world space. Its BUILD weld is detached during SIMULATE. A temporary dedicated collision-layer split makes O-Rings collide with connectors while rods—including the host axle—do not collide with O-Rings, avoiding both self-contact and joint-graph collision filtering. The visible part and original 0.26 collision thickness are unchanged. The normal AXLE joint remains untouched with free Y slide and free axle rotation until physical connector/O-Ring contact. No rod-owned proxy collider, moving proxy body, replacement AXLE joint, artificial travel limit, nested physics-body parenting, enlarged O-Ring collider, or O-Ring-specific CCD is used. BUILD/Restore restores the original collision layers and fixed O-Ring weld."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_069) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_069)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
