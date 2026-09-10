extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"

# v0.5.14 keeps the normal AXLE joint completely unchanged. During SIMULATE an
# O-Ring becomes an exact rod-relative kinematic collider: the editable BUILD
# weld is detached, the real ring remains collidable, and its world transform is
# synchronized from the host rod's saved local transform every physics tick.
# It is deliberately NOT reparented under the RigidBody3D host because nested
# physics bodies are unreliable under Godot 4.6.3/Jolt.
var o_ring_stop_pair_count_v069: int = 0
var o_ring_axle_replacements_v069: Array = []
var o_ring_stop_proxies_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops are exact rod-relative physical stops.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# Never copy O-Ring collision into the host rod. AXLE joints intentionally
# exclude connector-vs-rod collision, so a rod-owned proxy can never stop the
# axle connector reliably.
func _add_o_ring_proxy_shapes_v068(_ring: RigidBody3D, _rod: RigidBody3D) -> int:
	return 0


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
		var original_parent := ring.get_parent()
		var original_index := ring.get_index()
		var ring_had_host_exception: bool = ring.get_collision_exceptions().has(rod)
		var rod_had_ring_exception: bool = rod.get_collision_exceptions().has(ring)
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
			"original_parent": original_parent,
			"original_index": original_index,
			"ring_had_host_exception": ring_had_host_exception,
			"rod_had_ring_exception": rod_had_ring_exception,
		})

		# The BUILD weld is no longer needed in SIMULATE because the ring follows
		# the rod transform exactly. Removing it also removes the source of the
		# measured weld stretch under repeated stopper impacts.
		_disable_o_ring_joint_v068(joint)

		# Preserve normal construction collision for every other body, but never
		# collide the O-Ring with the rod it is mounted around.
		if not ring_had_host_exception:
			ring.add_collision_exception_with(rod)
		if not rod_had_ring_exception:
			rod.add_collision_exception_with(ring)

		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		ring.continuous_cd = false
		ring.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		ring.freeze = true
		ring.sleeping = false
		ring.can_sleep = false
		ring.global_transform = rod.global_transform * local_transform
		o_ring_stop_pair_count_v069 += 1

	if o_ring_stop_pair_count_v069 > 0:
		_rebind_all_joints()
	return o_ring_stop_pair_count_v069


# Override v0.5.13's follower sync specifically to avoid reparenting one physics
# body beneath another. A frozen kinematic RigidBody3D is intended for bodies
# animated by code and still participates in collision along its movement path.
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
	# Remove only the temporary host/self exceptions added by v0.5.14. The base
	# restore then restores the BUILD weld, collision policy and editable pose.
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		if is_instance_valid(ring) and is_instance_valid(rod):
			if not bool(follower.get("ring_had_host_exception", false)):
				ring.remove_collision_exception_with(rod)
			if not bool(follower.get("rod_had_ring_exception", false)):
				rod.remove_collision_exception_with(ring)
			ring.set("freeze_mode", int(follower.get("freeze_mode", RigidBody3D.FREEZE_MODE_STATIC)))
			ring.continuous_cd = bool(follower.get("continuous_cd", false))
			ring.can_sleep = bool(follower.get("can_sleep", true))
	super._restore_o_ring_followers_v068(restore_build_pose)
	o_ring_stop_pair_count_v069 = 0


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d collidable O-Ring Stop%s locked exactly to host rod%s; AXLE slide/rotation stay free until contact" % [
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
		label.text += "\n\nv0.5.14 O-RING STOPPER: the real O-Ring collider is locked exactly to its host rod during SIMULATE. Its BUILD weld is temporarily detached and the ring becomes a frozen kinematic collider whose world transform is synchronized from the rod every physics tick. This avoids both tiny rigid-body weld stretch and unreliable nested RigidBody3D parenting in Jolt. The ring keeps normal construction collision against axle connectors and other pieces, while host-rod self-collision is excluded. The normal AXLE joint remains untouched and keeps free Y slide plus free axle rotation until physical contact. No rod-owned proxy collider, moving proxy body, replacement AXLE joint, artificial travel limit, enlarged O-Ring collider, or O-Ring-specific CCD is used. BUILD/Restore returns the original editable ring and weld."


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
