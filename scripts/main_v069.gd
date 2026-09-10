extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
const O_RING_AXLE_CLEARANCE_V069 := 0.43
const O_RING_UNBOUNDED_TRAVEL_V069 := 1000.0

var o_ring_stop_pair_count_v069: int = 0
var o_ring_axle_replacements_v069: Array = []
# Compatibility/debug surface kept empty so regressions prove that no moving
# O-Ring proxy collider has returned.
var o_ring_stop_proxies_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops now constrain the axle's real sliding joint.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# v0.5.13 copied O-Ring collision into the host rod, but AXLE joints exclude
# connector-vs-host collision. Keep that broken route permanently disabled.
func _add_o_ring_proxy_shapes_v068(_ring: RigidBody3D, _rod: RigidBody3D) -> int:
	return 0


func _copy_joint_metadata_v069(source: Joint3D, target: Joint3D) -> void:
	for meta_name in source.get_meta_list():
		target.set_meta(meta_name, source.get_meta(meta_name))


func _restore_o_ring_axles_v069() -> void:
	var restored_any := false
	for value in o_ring_axle_replacements_v069:
		var state := value as Dictionary
		var original := state.get("original") as Generic6DOFJoint3D
		var replacement := state.get("replacement") as Generic6DOFJoint3D
		if is_instance_valid(replacement):
			replacement.node_a = NodePath()
			replacement.node_b = NodePath()
			joints.erase(replacement)
			replacement.queue_free()
		if is_instance_valid(original):
			original.node_a = state.get("node_a", NodePath()) as NodePath
			original.node_b = state.get("node_b", NodePath()) as NodePath
			original.remove_meta("sim_o_ring_axle_replaced_v069")
			restored_any = true
	o_ring_axle_replacements_v069.clear()
	o_ring_stop_pair_count_v069 = 0
	o_ring_stop_proxies_v069.clear()
	if restored_any:
		_rebind_all_joints()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_o_ring_axles_v069()
	super._restore_o_ring_followers_v068(restore_build_pose)


func _o_ring_alongs_for_rod_v069(rod: RigidBody3D) -> Array:
	var result: Array = []
	if not is_instance_valid(rod):
		return result
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	if axis.length_squared() < 0.5:
		return result
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		if follower.get("rod") != rod:
			continue
		var ring := follower.get("ring") as RigidBody3D
		if not is_instance_valid(ring):
			continue
		result.append((ring.global_position - rod.global_position).dot(axis))
	return result


func _make_bounded_axle_joint_v069(original: Generic6DOFJoint3D, lower_limit: float, upper_limit: float) -> Generic6DOFJoint3D:
	if not is_instance_valid(original):
		return null

	var path_a: NodePath = original.node_a
	var path_b: NodePath = original.node_b
	if path_a.is_empty() or path_b.is_empty():
		return null

	# Remove the original free-Y constraint first so there is never more than one
	# live axle constraint between this hub and rod.
	original.node_a = NodePath()
	original.node_b = NodePath()
	original.set_meta("sim_o_ring_axle_replaced_v069", true)

	# Build a fresh Generic6DOF with the same axle frame. Critically, configure its
	# limit mode BEFORE assigning node_a/node_b. Jolt creates the native constraint
	# when the body paths are bound; changing a previously-free axis afterward did
	# not alter the live constraint in the reproduced regression.
	var bounded := Generic6DOFJoint3D.new()
	bounded.name = "%s_O_Ring_Stop" % original.name
	bounded.exclude_nodes_from_collision = original.exclude_nodes_from_collision
	bounded.solver_priority = original.solver_priority
	for axis_name in ["x", "z"]:
		bounded.set("linear_limit_%s/enabled" % axis_name, true)
		bounded.set("linear_limit_%s/lower_distance" % axis_name, 0.0)
		bounded.set("linear_limit_%s/upper_distance" % axis_name, 0.0)
		bounded.set("angular_limit_%s/enabled" % axis_name, true)
		bounded.set("angular_limit_%s/lower_angle" % axis_name, 0.0)
		bounded.set("angular_limit_%s/upper_angle" % axis_name, 0.0)
	bounded.set("linear_limit_y/enabled", true)
	bounded.set("linear_limit_y/lower_distance", lower_limit)
	bounded.set("linear_limit_y/upper_distance", upper_limit)
	bounded.set("angular_limit_y/enabled", false)
	_copy_joint_metadata_v069(original, bounded)
	bounded.set_meta("sim_o_ring_axle_constraint_v069", true)

	add_child(bounded)
	bounded.global_transform = original.global_transform
	bounded.node_a = path_a
	bounded.node_b = path_b
	joints.append(bounded)
	o_ring_axle_replacements_v069.append({
		"original": original,
		"replacement": bounded,
		"node_a": path_a,
		"node_b": path_b,
	})
	return bounded


func _configure_o_ring_stoppers_v069() -> int:
	_restore_o_ring_axles_v069()
	var configured_pairs := 0
	var records: Array = connections_v020.duplicate()

	# v0.5.13 has already converted each visible O-Ring into a collisionless
	# follower of its host rod. Compute one lower/upper travel interval per AXLE,
	# then replace the original free-Y constraint with a bounded version created
	# in that mode from the start.
	for record_value in records:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		var original := record.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(connector) or not is_instance_valid(rod) or not is_instance_valid(original):
			continue

		var ring_alongs: Array = _o_ring_alongs_for_rod_v069(rod)
		if ring_alongs.is_empty():
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		if axis.length_squared() < 0.5:
			continue
		var hub_along: float = (connector.global_position - rod.global_position).dot(axis)
		var lower_limit := -O_RING_UNBOUNDED_TRAVEL_V069
		var upper_limit := O_RING_UNBOUNDED_TRAVEL_V069
		var has_lower := false
		var has_upper := false

		for ring_along_value in ring_alongs:
			var ring_along := float(ring_along_value)
			var delta := ring_along - hub_along
			if delta < 0.0:
				lower_limit = maxf(lower_limit, delta + O_RING_AXLE_CLEARANCE_V069)
				has_lower = true
				configured_pairs += 1
			elif delta > 0.0:
				upper_limit = minf(upper_limit, delta - O_RING_AXLE_CLEARANCE_V069)
				has_upper = true
				configured_pairs += 1
			else:
				lower_limit = 0.0
				upper_limit = 0.0
				has_lower = true
				has_upper = true
				configured_pairs += 1

		if not has_lower and not has_upper:
			continue
		if lower_limit > upper_limit:
			# Invalid BUILD overlap between opposing stops: hold the current slide
			# coordinate instead of creating an inverted solver interval.
			lower_limit = 0.0
			upper_limit = 0.0

		var bounded := _make_bounded_axle_joint_v069(original, lower_limit, upper_limit)
		if not is_instance_valid(bounded):
			continue
		connector.sleeping = false
		rod.sleeping = false

	# Rebuild authoritative connection records so later simulation code sees the
	# replacement axle joint rather than the detached BUILD joint.
	if not o_ring_axle_replacements_v069.is_empty():
		_rebuild_connection_graph_v020()

	o_ring_stop_pair_count_v069 = configured_pairs
	return configured_pairs


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	_configure_o_ring_stoppers_v069()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d O-Ring/axle stop relation%s active on bounded axle constraints; no proxy collider or O-Ring weld" % [
		o_ring_stop_pair_count_v069,
		"" if o_ring_stop_pair_count_v069 == 1 else "s"
	])


func _reset_pose() -> void:
	_restore_o_ring_axles_v069()
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_restore_o_ring_axles_v069()
	super._restore_state(snapshot)


func _restart_build() -> void:
	_restore_o_ring_axles_v069()
	super._restart_build()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.14 O-RING STOPPER: the broken v0.5.13 host-rod collision proxy and the experimental moving proxy body are removed. The visible O-Ring remains a collisionless follower of its axle during SIMULATE. For an axle containing O-Rings, the BUILD-time free-slide Generic6DOF is temporarily detached and replaced by one simulation-time Generic6DOF whose Y lower/upper limits are configured before it is bound to the bodies. This preserves the same axle frame, free Y rotation, locked radial axes and collision exclusion while giving Jolt a real native stop from constraint creation. Only one axle joint is live at a time; BUILD/Restore removes the bounded constraint and restores the original free-slide joint."


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
