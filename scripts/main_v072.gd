extends "res://scripts/main_v071.gd"

const VERSION_072 := "0.5.17"
const AXLE_RECOVERY_ALIGN_V072 := 0.985
const AXLE_RECOVERY_RADIAL_V072 := 0.46

# v0.5.17 fixes a general AXLE simulation problem, not an O-Ring special case.
# Every AXLE is normalized from the authoritative connection graph before each
# simulation and after state restore. Both fixed components connected by an
# active axle remain awake, and physical bodies on the opposite component keep
# their collisions even when the old rigid-component preflight installed broad
# collision exceptions elsewhere in the construction.

var active_axle_component_ids_v072: Dictionary = {}
var protected_axle_collision_pairs_v072: int = 0
var restored_axles_v072: int = 0
var recovered_legacy_axles_v072: int = 0


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


func _find_body_uid_v072(uid_value: int) -> RigidBody3D:
	if uid_value < 0:
		return null
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body) and int(body.get_meta("piece_uid_v020", -1)) == uid_value:
			return body
	return null


func _find_axle_joint_between_v072(connector: RigidBody3D, rod: RigidBody3D) -> Generic6DOFJoint3D:
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return null
	for joint_value in joints:
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes.size() < 2:
			continue
		if (nodes[0] == connector and nodes[1] == rod) or (nodes[0] == rod and nodes[1] == connector):
			return joint
	return null


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


func _apply_saved_axle_meta_v072(joint: Generic6DOFJoint3D, connector: RigidBody3D, rod: RigidBody3D, saved: Dictionary) -> void:
	if not is_instance_valid(joint) or not is_instance_valid(connector) or not is_instance_valid(rod):
		return
	var saved_uid: int = int(saved.get("uid", saved.get("connection_uid", -1)))
	if saved_uid >= 0:
		joint.set_meta("connection_uid_v020", saved_uid)
	joint.set_meta("connection_kind_v020", "axle")
	joint.set_meta("connector_uid_v020", _ensure_piece_uid_v020(connector))
	joint.set_meta("rod_uid_v020", _ensure_piece_uid_v020(rod))
	joint.set_meta("connector_slot_v020", -1)
	joint.set_meta("rod_end_v020", 0)
	var axis := _rod_axis_v020(rod).normalized()
	var derived_along := (connector.global_position - rod.global_position).dot(axis)
	joint.set_meta("host_along_v020", float(saved.get("host_along", derived_along)))
	if saved.has("rest_gap"):
		joint.set_meta("rest_gap_v020", float(saved.get("rest_gap", 0.0)))
	if saved.has("rest_align"):
		joint.set_meta("rest_align_v020", float(saved.get("rest_align", 1.0)))
	if saved.has("rest_perp"):
		joint.set_meta("rest_perp_v020", float(saved.get("rest_perp", 0.0)))
	if saved.has("rest_plane"):
		joint.set_meta("rest_plane_v020", float(saved.get("rest_plane", 0.0)))
	connector.set_meta("axle_occupied", true)
	connector.set_meta("axle_host_rod", rod)
	_canonicalize_axle_joint_v072(joint, connector)


func _capture_state() -> Dictionary:
	# Keep a second, stable-UID AXLE table independent of the legacy generic joint
	# list. The old list can omit a temporarily detached solver joint; this table is
	# the canonical source for v0.5.17+ named saves, undo and crash recovery.
	_restore_simulation_joint_graph()
	_rebuild_connection_graph_v020()
	var snapshot: Dictionary = super._capture_state()
	var saved_axles: Array = []
	var seen_pairs: Dictionary = {}
	for joint_value in joints:
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var pair_info: Dictionary = _axle_bodies_v072(joint)
		if pair_info.is_empty():
			continue
		var connector := pair_info.get("connector") as RigidBody3D
		var rod := pair_info.get("rod") as RigidBody3D
		var connector_uid := _ensure_piece_uid_v020(connector)
		var rod_uid := _ensure_piece_uid_v020(rod)
		var pair_key := "%d:%d" % [connector_uid, rod_uid]
		if seen_pairs.has(pair_key):
			continue
		seen_pairs[pair_key] = true
		var axis := _rod_axis_v020(rod).normalized()
		saved_axles.append({
			"connector_uid": connector_uid,
			"rod_uid": rod_uid,
			"connection_uid": int(joint.get_meta("connection_uid_v020", -1)),
			"host_along": float(joint.get_meta("host_along_v020", (connector.global_position - rod.global_position).dot(axis))),
			"rest_gap": float(joint.get_meta("rest_gap_v020", 0.0)),
			"rest_align": float(joint.get_meta("rest_align_v020", 1.0)),
			"rest_perp": float(joint.get_meta("rest_perp_v020", 0.0)),
			"rest_plane": float(joint.get_meta("rest_plane_v020", 0.0)),
		})
	snapshot["v072_axles"] = saved_axles
	return snapshot


func _repair_axle_from_saved_pair_v072(connector: RigidBody3D, rod: RigidBody3D, saved: Dictionary) -> bool:
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return false
	var joint := _find_axle_joint_between_v072(connector, rod)
	var created := false
	if not is_instance_valid(joint):
		joint = _make_axle_joint(connector, rod)
		created = true
	_apply_saved_axle_meta_v072(joint, connector, rod, saved)
	return created


func _connector_has_live_axle_v072(connector: RigidBody3D) -> bool:
	if not is_instance_valid(connector):
		return false
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var pair_info := _axle_bodies_v072(joint)
		if not pair_info.is_empty() and pair_info.get("connector") == connector:
			return true
	return false


func _best_geometric_axle_host_v072(connector: RigidBody3D) -> RigidBody3D:
	if not is_instance_valid(connector):
		return null
	var hub_axis := (connector.global_transform.basis * Vector3.UP).normalized()
	var best: RigidBody3D = null
	var best_score := INF
	for body_value in bodies:
		var rod := body_value as RigidBody3D
		if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
			continue
		var rod_axis := _rod_axis_v020(rod).normalized()
		var alignment := absf(hub_axis.dot(rod_axis))
		if alignment < AXLE_RECOVERY_ALIGN_V072:
			continue
		var delta := connector.global_position - rod.global_position
		var along := delta.dot(rod_axis)
		var half_len := float(rod.get_meta("visual_length", 0.0)) * 0.5 + 0.50
		if absf(along) > half_len:
			continue
		var radial := (delta - rod_axis * along).length()
		if radial > AXLE_RECOVERY_RADIAL_V072:
			continue
		var score := radial * 8.0 + (1.0 - alignment) * 4.0
		if score < best_score:
			best_score = score
			best = rod
	return best


func _repair_axles_after_restore_v072(snapshot: Dictionary) -> int:
	var repaired := 0
	var explicitly_restored: Dictionary = {}

	# v0.5.17+ saves: stable UID pair is the primary source and cannot be confused
	# by body reordering or by multiple joints involving the same fixed component.
	var saved_v072: Array = snapshot.get("v072_axles", []) as Array
	for value in saved_v072:
		var saved := value as Dictionary
		var connector := _find_body_uid_v072(int(saved.get("connector_uid", -1)))
		var rod := _find_body_uid_v072(int(saved.get("rod_uid", -1)))
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		if _repair_axle_from_saved_pair_v072(connector, rod, saved):
			repaired += 1
		explicitly_restored[connector.get_instance_id()] = true

	# v0.2-v0.5.16 saves already contain exact AXLE body indices in the extended
	# connection table. Recreate the joint directly if the older generic joint list
	# failed to bring it back, rather than silently dropping the connection.
	var saved_connections: Array = snapshot.get("v020_connections", []) as Array
	for value in saved_connections:
		var saved := value as Dictionary
		if str(saved.get("kind", "")) != "axle":
			continue
		var ci := int(saved.get("connector_index", -1))
		var ri := int(saved.get("rod_index", -1))
		if ci < 0 or ci >= bodies.size() or ri < 0 or ri >= bodies.size():
			continue
		var connector := bodies[ci] as RigidBody3D
		var rod := bodies[ri] as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		if _repair_axle_from_saved_pair_v072(connector, rod, saved):
			repaired += 1
		explicitly_restored[connector.get_instance_id()] = true

	# Any surviving legacy AxleJoint is still useful evidence. Canonicalize and tag
	# it even if an old connection table failed to match it after reconstruction.
	for joint_value in joints:
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var pair_info := _axle_bodies_v072(joint)
		if pair_info.is_empty():
			continue
		var connector := pair_info.get("connector") as RigidBody3D
		var rod := pair_info.get("rod") as RigidBody3D
		var axis := _rod_axis_v020(rod).normalized()
		var inferred := {
			"uid": int(joint.get_meta("connection_uid_v020", -1)),
			"host_along": float(joint.get_meta("host_along_v020", (connector.global_position - rod.global_position).dot(axis))),
		}
		_apply_saved_axle_meta_v072(joint, connector, rod, inferred)
		explicitly_restored[connector.get_instance_id()] = true

	_rebuild_connection_graph_v020()

	# Last-resort migration for a save captured while the old simulation had a
	# redundant AxleJoint temporarily detached: connector.axle_occupied survived in
	# the body state even though the joint did not. Recover the single rod actually
	# passing through and aligned with that hub. This is specifically for existing
	# v0.5.16-and-older saves and is never used for an ordinary free connector.
	var legacy_recovered := 0
	for body_value in bodies:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		if not bool(connector.get_meta("axle_occupied", false)) or _connector_has_live_axle_v072(connector):
			continue
		var rod := _best_geometric_axle_host_v072(connector)
		if not is_instance_valid(rod):
			continue
		var axis := _rod_axis_v020(rod).normalized()
		var along := (connector.global_position - rod.global_position).dot(axis)
		var joint := _make_axle_joint(connector, rod)
		_tag_connection_v020(joint, "axle", connector, rod, -1, 0, along, null, int(connector.get_meta("primary_connection_uid_v020", -1)) < 0)
		connector.set_meta("axle_occupied", true)
		connector.set_meta("axle_host_rod", rod)
		_canonicalize_axle_joint_v072(joint, connector)
		repaired += 1
		legacy_recovered += 1

	recovered_legacy_axles_v072 = legacy_recovered
	_rebuild_connection_graph_v020()
	_recalculate_occupancy_from_joints()
	# Reassert AXLE-specific convenience metadata after the generic occupancy pass.
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if is_instance_valid(connector) and is_instance_valid(rod):
			connector.set_meta("axle_occupied", true)
			connector.set_meta("axle_host_rod", rod)
	_rebuild_connection_graph_v020()
	return repaired


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
	restored_axles_v072 = _repair_axles_after_restore_v072(snapshot)
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
