extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"

# v0.5.14 keeps the normal AXLE joint completely unchanged. During SIMULATE an
# O-Ring becomes an exact rod-relative kinematic collider: its real body remains
# collidable, its world transform is synchronized from the host rod every physics
# tick, and the existing mount joint keeps only host/self collision exclusion.
# All six mount constraints are temporarily disabled so the tiny O-Ring is not a
# separately solved weld and cannot stretch or inject solver energy.
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


func _set_o_ring_mount_constraints_v069(joint: Generic6DOFJoint3D, enabled_flags: Dictionary) -> void:
	if not is_instance_valid(joint):
		return
	for axis_name in ["x", "y", "z"]:
		joint.set("linear_limit_%s/enabled" % axis_name, bool(enabled_flags.get("linear_%s" % axis_name, false)))
		joint.set("angular_limit_%s/enabled" % axis_name, bool(enabled_flags.get("angular_%s" % axis_name, false)))


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
		var joint := record.get("joint") as Generic6DOFJoint3D
		var ring := record.get("ring") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(joint) or not is_instance_valid(ring) or not is_instance_valid(rod):
			continue

		var local_transform: Transform3D = rod.global_transform.affine_inverse() * ring.global_transform
		var saved_flags := {}
		for axis_name in ["x", "y", "z"]:
			saved_flags["linear_%s" % axis_name] = bool(joint.get("linear_limit_%s/enabled" % axis_name))
			saved_flags["angular_%s" % axis_name] = bool(joint.get("angular_limit_%s/enabled" % axis_name))
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
			"mount_enabled_flags_v069": saved_flags,
		})

		# Keep node_a/node_b and exclude_nodes_from_collision intact, but make this
		# a zero-constraint relationship for SIMULATE. The kinematic follower owns
		# the ring transform; the joint contributes no positional/angular force.
		_set_o_ring_mount_constraints_v069(joint, {})
		joint.exclude_nodes_from_collision = true

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
	# Restore the original fixed-mount limit flags before the base restore returns
	# the body to its editable BUILD pose/state.
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var joint := follower.get("joint") as Generic6DOFJoint3D
		if is_instance_valid(joint):
			_set_o_ring_mount_constraints_v069(joint, follower.get("mount_enabled_flags_v069", {}) as Dictionary)
		if is_instance_valid(ring):
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
		label.text += "\n\nv0.5.14 O-RING STOPPER: the real O-Ring collider is locked exactly to its host rod during SIMULATE as a frozen kinematic body synchronized in world space every physics tick. Its existing mount remains connected only to exclude O-Ring-vs-host-rod self collision; all six mount constraints are temporarily disabled, so the mount cannot stretch or inject solver force. The ring keeps normal construction collision against axle connectors and other pieces. The normal AXLE joint remains untouched and keeps free Y slide plus free axle rotation until physical contact. No rod-owned proxy collider, moving proxy body, replacement AXLE joint, artificial travel limit, enlarged O-Ring collider, nested physics-body parenting, or O-Ring-specific CCD is used. BUILD/Restore re-enables the original O-Ring mount constraints and editable state."


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
