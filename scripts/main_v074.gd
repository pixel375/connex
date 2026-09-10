extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.18"
const LEGACY_AXLE_ALIGN_V074 := 0.985
const LEGACY_AXLE_RADIAL_V074 := 0.18
const LEGACY_AXLE_END_MARGIN_V074 := 0.28

var legacy_axle_geometry_repairs_v074: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_074)
	_status("v0.5.18 ready — legacy saves can recover AXLE hubs from exact hub/shaft geometry.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_074, text]


func _legacy_axle_geometry_score_v074(connector: RigidBody3D, rod: RigidBody3D) -> float:
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return INF
	if str(connector.get_meta("kind", "")) != "connector" or str(rod.get_meta("kind", "")) != "rod":
		return INF
	var rod_axis: Vector3 = _rod_axis_v020(rod).normalized()
	var hub_axis: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
	var alignment: float = absf(rod_axis.dot(hub_axis))
	if alignment < LEGACY_AXLE_ALIGN_V074:
		return INF
	var delta: Vector3 = connector.global_position - rod.global_position
	var along: float = delta.dot(rod_axis)
	var radial: float = (delta - rod_axis * along).length()
	if radial > LEGACY_AXLE_RADIAL_V074:
		return INF
	var half_len: float = float(rod.get_meta("visual_length", 0.0)) * 0.5
	if half_len <= 0.0 or absf(along) > half_len + LEGACY_AXLE_END_MARGIN_V074:
		return INF
	# AXLE placement puts the connector hub center directly on the shaft and aligns
	# the connector local Y / hub axis with the rod. SOCKET rods live in the
	# connector plane; CROSS mounts offset the connector center by CONNECTOR_D.
	return radial * 12.0 + (1.0 - alignment) * 5.0


func _direct_non_axle_joints_v074(connector: RigidBody3D, rod: RigidBody3D) -> Array:
	var result: Array = []
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes.size() < 2:
			continue
		if (nodes[0] == connector and nodes[1] == rod) or (nodes[0] == rod and nodes[1] == connector):
			result.append(joint)
	return result


func _remove_joint_node_v074(joint: Joint3D) -> void:
	if not is_instance_valid(joint):
		return
	joint.node_a = NodePath()
	joint.node_b = NodePath()
	joints.erase(joint)
	joint.queue_free()


func _legacy_connector_has_rigid_context_v074(connector: RigidBody3D, candidate_rod: RigidBody3D) -> bool:
	# A corrupted AXLE commonly comes back as a direct false fixed/socket twin.
	# If that twin is absent, require the hub to belong to another rigid branch so
	# an unrelated free connector that happens to overlap a rod is not guessed.
	if not _direct_non_axle_joints_v074(connector, candidate_rod).is_empty():
		return true
	return _fixed_component_for_axle_v072(connector).size() > 1


func _recover_legacy_axles_from_geometry_v074(snapshot: Dictionary) -> int:
	# v0.5.17+ snapshots have an explicit stable-UID AXLE table. Never infer from
	# geometry for those; this path exists only for v0.5.16-and-earlier saves where
	# AXLE identity may already have been lost or mislabeled as SOCKET/FIXED.
	if snapshot.has("v072_axles"):
		return 0

	_rebuild_connection_graph_v020()
	var repaired: int = 0
	for body_value in bodies:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		if _connector_has_live_axle_v072(connector):
			continue

		var best_rod: RigidBody3D = null
		var best_score: float = INF
		for rod_value in bodies:
			var rod := rod_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			var score: float = _legacy_axle_geometry_score_v074(connector, rod)
			if score < best_score:
				best_score = score
				best_rod = rod

		if not is_instance_valid(best_rod) or best_score == INF:
			continue
		if not _legacy_connector_has_rigid_context_v074(connector, best_rod):
			continue

		var false_joints: Array = _direct_non_axle_joints_v074(connector, best_rod)
		var old_primary_uid: int = int(connector.get_meta("primary_connection_uid_v020", -1))
		var removed_primary: bool = false
		for false_joint_value in false_joints:
			var false_joint := false_joint_value as Joint3D
			if is_instance_valid(false_joint) and int(false_joint.get_meta("connection_uid_v020", -2)) == old_primary_uid:
				removed_primary = true
			_remove_joint_node_v074(false_joint)

		var axis: Vector3 = _rod_axis_v020(best_rod).normalized()
		var along: float = (connector.global_position - best_rod.global_position).dot(axis)
		var axle_joint: Generic6DOFJoint3D = _make_axle_joint(connector, best_rod)
		var make_primary: bool = removed_primary or old_primary_uid < 0
		var axle_uid: int = _tag_connection_v020(axle_joint, "axle", connector, best_rod, -1, 0, along, null, make_primary)
		connector.set_meta("axle_occupied", true)
		connector.set_meta("axle_host_rod", best_rod)
		if make_primary:
			connector.set_meta("primary_connection_uid_v020", axle_uid)
		_canonicalize_axle_joint_v072(axle_joint, connector)
		repaired += 1

	if repaired > 0:
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
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
	return repaired


func _restore_state(snapshot: Dictionary) -> void:
	super._restore_state(snapshot)
	legacy_axle_geometry_repairs_v074 = _recover_legacy_axles_from_geometry_v074(snapshot)
	if legacy_axle_geometry_repairs_v074 > 0:
		# Re-run the normal v0.5.17 cleanup now that the recovered AXLE identities are
		# authoritative, then normalize the final graph and occupancy from live joints.
		_remove_false_fixed_axle_duplicates_v073()
		_canonicalize_all_axles_v072()
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
		_recalculate_occupancy_from_joints()
		_rebuild_connection_graph_v020()
		print("LEGACY_AXLE_GEOMETRY_REPAIR_074: recovered %d AXLE connection(s) and removed their false fixed/socket records" % legacy_axle_geometry_repairs_v074)


func _on_update_download_complete_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if update_status_v021 != null and str(update_status_v021.text).contains("v%s" % VERSION_074):
		_set_update_status_v021("Current version: v%s" % VERSION_074)
		return
	super._on_update_download_complete_v021(result, response_code, headers, body)
