extends "res://scripts/main_v071.gd"

const VERSION_072 := "0.5.16"
const O_RING_TOUCH_RADIUS_PX_V072 := 82.0
const AXLE_HUB_STACK_SPACING_V072 := 0.56
const STRUCTURE_FLEX_MAX_DEG_V072 := 12.0


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_072)
	_status("v0.5.16 ready — durable O-Ring stops, realistic rigidity, true CROSS rods and multi-mount socket re-seat.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_072, text]


# -----------------------------------------------------------------------------
# O-Ring touch selection
#
# O-Rings are intentionally small parts. Their physical size should not make
# them hard to select on a phone, so selection gets a screen-space target that
# is independent from collision geometry. This priority is used only when the
# user is explicitly selecting/moving/rotating a part; CREATE/ATTACH semantics
# remain unchanged.
# -----------------------------------------------------------------------------

func _pick_o_ring_touch_v072(screen_pos: Vector2, radius_px: float = O_RING_TOUCH_RADIUS_PX_V072) -> RigidBody3D:
	if camera == null:
		return null
	var best: RigidBody3D = null
	var best_distance: float = radius_px
	var best_depth: float = INF
	for value in o_ring_stops:
		var ring := value as RigidBody3D
		if not is_instance_valid(ring) or camera.is_position_behind(ring.global_position):
			continue
		var projected: Vector2 = camera.unproject_position(ring.global_position)
		var distance: float = projected.distance_to(screen_pos)
		if distance > radius_px:
			continue
		var depth: float = camera.global_position.distance_to(ring.global_position)
		if distance < best_distance - 0.5 or (absf(distance - best_distance) <= 0.5 and depth < best_depth):
			best = ring
			best_distance = distance
			best_depth = depth
	return best


func _handle_tap(screen_pos: Vector2) -> void:
	if not simulating and (editor_mode_v032 in [EDITOR_ROTATE_032, EDITOR_MOVE_042] or select_armed_v020):
		var ring: RigidBody3D = _pick_o_ring_touch_v072(screen_pos)
		if is_instance_valid(ring):
			_set_selected(ring)
			select_armed_v020 = false
			_refresh_editor_overlay_v030()
			_refresh_gizmo_validity_v030()
			_status("Selected O-Ring Stop")
			return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# Structure rigidity
#
# v0.5.11 only softened the single redundant SOCKET edge chosen to break a
# closed graph cycle. That made the slider almost invisible in normal builds.
# v0.5.16 applies bounded angular compliance to every SOCKET/CROSS structure
# connection during SIMULATE. Linear positions remain locked. 100% is rigid;
# lower values provide visible but bounded flex instead of turning joints into
# unconstrained hinges.
# -----------------------------------------------------------------------------

func _structure_flex_angle_rad_v066() -> float:
	var rigidity01: float = clampf(physics_structure_rigidity_v066 / 100.0, 0.0, 1.0)
	var degrees: float = STRUCTURE_FLEX_MAX_DEG_V072 * pow(1.0 - rigidity01, 1.01)
	return deg_to_rad(degrees)


func _structure_flex_angle_deg_v066() -> float:
	return rad_to_deg(_structure_flex_angle_rad_v066())


func _apply_structure_flex_all_v072() -> int:
	var flex: float = _structure_flex_angle_rad_v066()
	var count := 0
	_rebuild_connection_graph_v020(false)
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) not in ["socket", "cross"]:
			continue
		var joint := record.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			continue
		for axis_name in ["x", "y", "z"]:
			joint.set("angular_limit_%s/enabled" % axis_name, true)
			joint.set("angular_limit_%s/lower_angle" % axis_name, -flex)
			joint.set("angular_limit_%s/upper_angle" % axis_name, flex)
		joint.set_meta("sim_rigidity_all_v072", true)
		joint.set_meta("sim_structure_rigidity_v066", physics_structure_rigidity_v066)
		joint.set_meta("sim_structure_flex_rad_v066", flex)
		count += 1
	return count


func _restore_structure_flex_all_v072() -> void:
	for joint_value in joints:
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("sim_rigidity_all_v072", false)):
			continue
		for axis_name in ["x", "y", "z"]:
			joint.set("angular_limit_%s/enabled" % axis_name, true)
			joint.set("angular_limit_%s/lower_angle" % axis_name, 0.0)
			joint.set("angular_limit_%s/upper_angle" % axis_name, 0.0)
		joint.remove_meta("sim_rigidity_all_v072")
		joint.remove_meta("sim_structure_rigidity_v066")
		joint.remove_meta("sim_structure_flex_rad_v066")


func _restore_softened_socket_loops_v064() -> void:
	_restore_structure_flex_all_v072()
	super._restore_softened_socket_loops_v064()


# -----------------------------------------------------------------------------
# CROSS creation from a connector socket
#
# CROSS means the socket clips onto the SIDE/MIDDLE of the rod. The rod axis is
# tangent to the connector at that socket and its midpoint lands at the socket
# mouth. Rod ends remain free. This is deliberately different from SOCKET,
# where a rod end is inserted into the jaw.
# -----------------------------------------------------------------------------

func _cross_rod_axis_for_socket_v072(connector: RigidBody3D, slot: int) -> Vector3:
	var local_dir: Vector3 = _slot_dir(slot).normalized()
	var local_axis: Vector3
	if _is_spatial_slot_v041(slot):
		local_axis = _spatial_socket_basis_v041(local_dir).z.normalized()
	else:
		local_axis = Vector3.UP.cross(local_dir).normalized()
	if local_axis.length_squared() < 0.25:
		local_axis = _stable_perpendicular_v030(local_dir)
	return (connector.global_transform.basis * local_axis).normalized()


func _create_cross_rod_from_socket_v072(connector: RigidBody3D, slot: int) -> bool:
	if simulating or not is_instance_valid(connector) or slot < 0:
		return false
	_rebuild_connection_graph_v020()
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	if occupied.has(slot):
		_status("That connector socket is already occupied")
		return false
	var length: float = float(rod_defs[selected_rod_type].get("actual_mm", 55.0)) / 10.0
	var socket: Dictionary = _socket_world_v020(connector, slot)
	var anchor: Vector3 = socket.get("point", connector.global_position) as Vector3
	var axis: Vector3 = _cross_rod_axis_for_socket_v072(connector, slot)
	if axis.length_squared() < 0.5:
		_status("Could not determine CROSS rod direction for that socket")
		return false
	var rod := _make_rod(selected_rod_type, anchor - axis * length * 0.5, anchor + axis * length * 0.5) as RigidBody3D
	_create_cross_connection_v030(connector, slot, rod, 0.0)
	_set_connector_occupied(connector, slot, true)
	rod.set_meta("build_transform", rod.global_transform)
	_set_selected(rod)
	_rebuild_connection_graph_v020()
	_commit_state()
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_update_ui()
	_status("CROSS rod added — socket clips to the rod side/middle; both rod ends remain free")
	return true


func _try_socket_create_tap_v054(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_CREATE_032 or simulating:
		return false
	if attach_mode == 0:
		return super._try_socket_create_tap_v054(screen_pos)
	if attach_mode != 2:
		return false
	var connector: RigidBody3D = _raycast_connector_v070(screen_pos)
	if not is_instance_valid(connector):
		return false
	var candidate: Dictionary = _pick_socket_on_connector_v070(connector, screen_pos, SOCKET_JAW_PICK_RADIUS_V070, true)
	if candidate.is_empty():
		return false
	return _create_cross_rod_from_socket_v072(connector, int(candidate.get("slot", -1)))


# -----------------------------------------------------------------------------
# Reconnect assistance
#
# Disconnect Selected intentionally records pair-blocks so pieces do not silently
# fuse again. Once the user explicitly reconnects one socket of that connector,
# however, any OTHER previously-detached rod that is now exactly aligned should
# be allowed to snap back. Only geometrically valid blocked pairs involving that
# connector are released; unrelated deliberate detaches stay blocked.
# -----------------------------------------------------------------------------

func _reactivate_aligned_detached_socket_pairs_v072(connector: RigidBody3D) -> int:
	if not is_instance_valid(connector):
		return 0
	_rebuild_connection_graph_v020()
	var reactivated := 0
	var old_context: bool = auto_connect_context_v030
	auto_connect_context_v030 = false
	for body_value in bodies:
		var rod := body_value as RigidBody3D
		if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
			continue
		var key: String = _pair_key_v030(connector, rod)
		if not manual_detach_blocks_v030.has(key):
			continue
		var end_occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
		var aligned := false
		for sign_value in [-1, 1]:
			if end_occupied.has(sign_value):
				continue
			var target: Dictionary = _best_socket_for_end_v020(rod, sign_value)
			if not target.is_empty() and target.get("connector") == connector:
				aligned = true
				break
		if aligned:
			manual_detach_blocks_v030.erase(key)
			reactivated += 1
	auto_connect_context_v030 = old_context
	return reactivated


func _resnap_reactivated_socket_pairs_v072(connector: RigidBody3D) -> int:
	var released: int = _reactivate_aligned_detached_socket_pairs_v072(connector)
	if released <= 0:
		return 0
	var attached: int = _auto_connect_all_v020()
	if attached > 0:
		_update_build_transforms_v059()
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()
		_commit_state()
	return attached


func _connect_points_v032(source: Dictionary, target: Dictionary, inferred_mode: int) -> bool:
	var connected: bool = super._connect_points_v032(source, target, inferred_mode)
	if not connected or inferred_mode != 0:
		return connected
	var connector: RigidBody3D = null
	if str(source.get("type", "")) == "socket":
		connector = source.get("body") as RigidBody3D
	elif str(target.get("type", "")) == "socket":
		connector = target.get("body") as RigidBody3D
	if is_instance_valid(connector):
		var snapped: int = _resnap_reactivated_socket_pairs_v072(connector)
		if snapped > 0:
			_status("SOCKET reconnected; %d aligned detached rod%s snapped back automatically" % [snapped, "" if snapped == 1 else "s"])
	return true


# -----------------------------------------------------------------------------
# Multi-rod socket re-seat
#
# v0.5.15 moved the connector-side fixed component around the chosen rod. If the
# other rods had fixed far ends, validation correctly rejected that movement.
# The real K'NEX operation is different: rods stay put while the connector alone
# rotates and each existing mount moves to the socket now occupying the same
# world-space jaw. Solve that socket permutation atomically.
# -----------------------------------------------------------------------------

func _multi_socket_reseat_preview_v072(connector: RigidBody3D, record: Dictionary, new_slot: int) -> Dictionary:
	if not is_instance_valid(connector) or record.is_empty() or str(record.get("kind", "")) != "socket":
		return {"valid": false, "reason": "socket re-seat requires an existing socket mount"}
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return {"valid": false, "reason": "connector definition is missing"}
	var slots: Array = connector_defs[def_index].get("slots", []) as Array
	if not (new_slot in slots):
		return {"valid": false, "reason": "socket does not exist on this connector"}
	var old_slot: int = int(record.get("slot", -1))
	if new_slot == old_slot:
		return {"valid": false, "reason": "that socket is already on this rod"}
	var rod := record.get("rod") as RigidBody3D
	var rod_end: int = int(record.get("rod_end", 0))
	if not is_instance_valid(rod) or rod_end == 0:
		return {"valid": false, "reason": "attached rod end is missing"}
	var anchor: Vector3 = _rod_end_v020(rod, rod_end)
	var desired_dir: Vector3 = (-_rod_axis_v020(rod) * float(rod_end)).normalized()
	var current_new_dir: Vector3 = (_socket_world_v020(connector, new_slot).get("dir", Vector3.RIGHT) as Vector3).normalized()
	var rotate_basis: Basis = Basis(Quaternion(current_new_dir, desired_dir))
	var target_basis: Basis = (rotate_basis * connector.global_transform.basis).orthonormalized()
	var target_origin: Vector3 = anchor - desired_dir * CONNECTOR_D
	var target_tf := Transform3D(target_basis, target_origin)
	var transforms: Dictionary = {connector.get_instance_id(): target_tf}
	var target_candidate: Dictionary = record.duplicate(true)
	target_candidate["slot"] = new_slot
	var target_validation: Dictionary = _validate_record_v020(target_candidate, transforms)
	if not bool(target_validation.get("valid", false)):
		return {"valid": false, "reason": str(target_validation.get("reason", "selected rod cannot use that socket"))}

	var slot_map: Dictionary = {int(record.get("uid", -1)): new_slot}
	var used_slots: Dictionary = {new_slot: true}
	var radial_records: Array = []
	var non_radial_records: Array = []
	for value in _connections_for_piece_v020(connector):
		var other := value as Dictionary
		if int(other.get("uid", -1)) == int(record.get("uid", -2)):
			continue
		if str(other.get("kind", "")) in ["socket", "cross"]:
			radial_records.append(other)
		else:
			non_radial_records.append(other)

	# Most constrained mounts first. Existing socket mounts usually have one exact
	# candidate after a 45-degree step, so this remains deterministic for 1..14
	# point connectors while allowing occupied sockets to participate in a cycle.
	for other_value in radial_records:
		var other := other_value as Dictionary
		var best_slot := -1
		var best_score := INF
		for slot_value in slots:
			var candidate_slot: int = int(slot_value)
			if used_slots.has(candidate_slot):
				continue
			var candidate: Dictionary = other.duplicate(true)
			candidate["slot"] = candidate_slot
			var validation: Dictionary = _validate_record_v020(candidate, transforms)
			if not bool(validation.get("valid", false)):
				continue
			var socket: Dictionary = _socket_world_v020(connector, candidate_slot, target_tf, true)
			var score: float = (socket.get("point", target_tf.origin) as Vector3).distance_to(_record_anchor_v020(other))
			if score < best_score:
				best_score = score
				best_slot = candidate_slot
		if best_slot < 0:
			return {"valid": false, "reason": "another connected rod has no socket after this rotation"}
		used_slots[best_slot] = true
		slot_map[int(other.get("uid", -1))] = best_slot

	for other_value in non_radial_records:
		var other := other_value as Dictionary
		var validation: Dictionary = _validate_record_v020(other, transforms)
		if not bool(validation.get("valid", false)):
			return {"valid": false, "reason": str(validation.get("reason", "another connection blocks this rotation"))}

	return {
		"valid": true,
		"transforms": transforms,
		"record": record,
		"old_slot": old_slot,
		"new_slot": new_slot,
		"slot_map_v072": slot_map,
	}


func _reseat_record_preview_v070(connector: RigidBody3D, record: Dictionary, new_slot: int) -> Dictionary:
	if str(record.get("kind", "")) == "socket":
		return _multi_socket_reseat_preview_v072(connector, record, new_slot)
	return super._reseat_record_preview_v070(connector, record, new_slot)


func _apply_reseat_record_v070(connector: RigidBody3D, record: Dictionary, new_slot: int) -> bool:
	var preview: Dictionary = _reseat_record_preview_v070(connector, record, new_slot)
	if not bool(preview.get("valid", false)):
		_status("Socket re-seat blocked — %s" % str(preview.get("reason", "not valid")))
		return false
	if not preview.has("slot_map_v072"):
		return super._apply_reseat_record_v070(connector, record, new_slot)
	var old_slot: int = int(preview.get("old_slot", -1))
	_apply_transforms_raw_v030(preview.get("transforms", {}) as Dictionary)
	var slot_map: Dictionary = preview.get("slot_map_v072", {}) as Dictionary
	for value in _connections_for_piece_v020(connector):
		var connected_record := value as Dictionary
		var uid: int = int(connected_record.get("uid", -1))
		if not slot_map.has(uid):
			continue
		var joint := connected_record.get("joint") as Joint3D
		if is_instance_valid(joint):
			joint.set_meta("connector_slot_v020", int(slot_map[uid]))
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	var snapped: int = _resnap_reactivated_socket_pairs_v072(connector)
	if snapped <= 0:
		_commit_state()
	_set_selected(connector)
	attach_point_selected_v032 = {}
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	_update_ui()
	_status("Socket re-seated %s → %s; connected rods stayed fixed%s" % [_slot_label_v070(old_slot), _slot_label_v070(new_slot), " and aligned detached rods re-snapped" if snapped > 0 else ""])
	return true


# -----------------------------------------------------------------------------
# Durable O-Ring / rod-end axle bounds
#
# Every hub receives finite limits for its O-Ring segment. Bounds are ranked by
# the hubs' starting order so several hubs cannot be projected onto one O-Ring
# coordinate. Connector-side correction explicitly refuses to traverse into the
# host axle rod, even if a complicated construction has another fixed path back
# to that rod.
# -----------------------------------------------------------------------------

func _stop_component_v071(stop: Dictionary) -> Array:
	var connector := stop.get("connector") as RigidBody3D
	var host_rod := stop.get("rod") as RigidBody3D
	if not is_instance_valid(connector):
		return []
	_rebuild_connection_graph_v020(false)
	var result: Array = []
	var queue: Array = [connector]
	var seen: Dictionary = {connector.get_instance_id(): true}
	var excluded_uid: int = int(stop.get("uid", -1))
	while not queue.is_empty():
		var current := queue.pop_front() as RigidBody3D
		if not is_instance_valid(current) or current == host_rod:
			continue
		result.append(current)
		for record_value in connections_v020:
			var record := record_value as Dictionary
			if int(record.get("uid", -1)) == excluded_uid or str(record.get("kind", "")) not in ["socket", "cross", "o_ring"]:
				continue
			if record.get("a") != current and record.get("b") != current:
				continue
			var other := _other_body_v020(record, current) as RigidBody3D
			if not is_instance_valid(other) or other == host_rod or seen.has(other.get_instance_id()):
				continue
			seen[other.get_instance_id()] = true
			queue.append(other)
	if result.is_empty():
		result = [connector]
	return result


func _build_axle_stop_ranges_v070() -> void:
	axle_stop_ranges_v070.clear()
	_rebuild_connection_graph_v020()
	var groups: Dictionary = {}
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var key: int = rod.get_instance_id()
		var group: Dictionary = groups.get(key, {"rod": rod, "axles": [], "rings": []}) as Dictionary
		var axles: Array = group.get("axles", []) as Array
		axles.append({"connector": connector, "uid": int(record.get("uid", -1)), "initial": _rod_local_along_v070(connector, rod)})
		group["axles"] = axles
		groups[key] = group
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		var key: int = rod.get_instance_id()
		if not groups.has(key):
			continue
		var group: Dictionary = groups[key] as Dictionary
		var rings: Array = group.get("rings", []) as Array
		rings.append(_rod_local_along_v070(ring, rod))
		group["rings"] = rings
		groups[key] = group

	for key_value in groups.keys():
		var group: Dictionary = groups[key_value] as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var rings: Array = group.get("rings", []) as Array
		rings.sort()
		var by_segment: Dictionary = {}
		for axle_value in group.get("axles", []) as Array:
			var axle := axle_value as Dictionary
			var initial: float = float(axle.get("initial", 0.0))
			var segment := 0
			for ring_value in rings:
				if float(ring_value) < initial:
					segment += 1
			var segment_axles: Array = by_segment.get(segment, []) as Array
			segment_axles.append(axle)
			by_segment[segment] = segment_axles

		var rod_half: float = maxf(AXLE_CONNECTOR_HALF_V070, float(rod.get_meta("visual_length", 0.0)) * 0.5)
		for segment_value in by_segment.keys():
			var segment: int = int(segment_value)
			var segment_axles: Array = by_segment[segment] as Array
			segment_axles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("initial", 0.0)) < float(b.get("initial", 0.0)))
			if segment_axles.is_empty():
				continue
			var base_lower: float = -rod_half + AXLE_CONNECTOR_HALF_V070
			var base_upper: float = rod_half - AXLE_CONNECTOR_HALF_V070
			if segment > 0:
				base_lower = float(rings[segment - 1]) + O_RING_AXLE_CLEARANCE_V070
			if segment < rings.size():
				base_upper = float(rings[segment]) - O_RING_AXLE_CLEARANCE_V070
			if base_lower > base_upper:
				var midpoint: float = (base_lower + base_upper) * 0.5
				base_lower = midpoint
				base_upper = midpoint

			var n: int = segment_axles.size()
			var spacing: float = AXLE_HUB_STACK_SPACING_V072
			if n > 1:
				spacing = minf(spacing, maxf(0.0, (base_upper - base_lower) / float(n - 1)))
				for i in range(n):
					var initial: float = float((segment_axles[i] as Dictionary).get("initial", 0.0))
					if i > 0:
						spacing = minf(spacing, maxf(0.0, (initial - base_lower) / float(i)))
					if i < n - 1:
						spacing = minf(spacing, maxf(0.0, (base_upper - initial) / float(n - 1 - i)))
			for i in range(n):
				var axle := segment_axles[i] as Dictionary
				var initial: float = float(axle.get("initial", 0.0))
				var lower: float = base_lower + spacing * float(i)
				var upper: float = base_upper - spacing * float(n - 1 - i)
				# Never manufacture an initial correction merely from ranking a build
				# that was already valid when SIMULATE was pressed.
				lower = minf(lower, initial)
				upper = maxf(upper, initial)
				axle_stop_ranges_v070.append({
					"connector": axle.get("connector"),
					"rod": rod,
					"uid": int(axle.get("uid", -1)),
					"lower": lower,
					"upper": upper,
					"ring_count": rings.size(),
					"segment": segment,
					"segment_index": i,
					"segment_size": n,
					"stack_spacing_v072": spacing,
				})


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	# Parent builds the O-Ring follower/range graph. Rebuild once more with the
	# v0.5.16 ranked finite bounds, then apply requested structural compliance.
	_build_axle_stop_ranges_v070()
	_apply_structure_flex_all_v072()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — durable O-Ring/rod-end stops active; Structure Rigidity %d%% = ±%.2f° SOCKET/CROSS flex" % [int(round(physics_structure_rigidity_v066)), _structure_flex_angle_deg_v066()])


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.16: O-Rings have a larger touch target for selection without changing physical size. Every axle hub receives durable rod-local O-Ring/rod-end travel limits, including complex multi-hub builds. Structure Rigidity now controls bounded SOCKET/CROSS flex across the whole construction: 100% is rigid, lower values visibly flex while linear connections stay locked. CREATE+CROSS places a rod SIDE/MIDDLE onto the tapped socket, perpendicular to the socket direction. Explicitly reconnecting one socket allows other still-aligned rods from the same Disconnect operation to snap back. Socket re-seat rotates the connector itself and remaps all of its attached rods to valid sockets, so rods anchored at their far ends can stay fixed."


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
