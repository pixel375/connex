extends "res://scripts/main_v085.gd"

const VERSION_086 := "0.5.24-dev"
const ATTACH_POSE_CHECK_MS_086 := 120
const AUTOFUSE_LOCAL_MATCH_BUDGET_086 := 32

var save_confirmation_v086: AcceptDialog
var autofuse_body_cache_v086: Dictionary = {}
var autofuse_force_full_v086: bool = false
var next_attach_pose_check_ms_v086: int = 0


func _ready() -> void:
	super._ready()
	_build_save_confirmation_v086()
	_snapshot_autofuse_bodies_v086()

	# These are the retired v0.3.5 side-panel controls. Their parent panel has been
	# hidden since the unified TRANSFORM UI, but inherited _update_ui() still ran
	# expensive graph/rotation previews merely to decide whether these invisible
	# buttons should be disabled. Keep the nodes alive for compatibility while
	# removing those stale references from the hot update path.
	roll_minus_v035 = null
	roll_plus_v035 = null
	reset_rotation_v035 = null

	_status("v0.5.24 staging — save confirmation, live parts inventory and build-mode performance optimizations are active.")


# -----------------------------------------------------------------------------
# Save confirmation.
# -----------------------------------------------------------------------------

func _build_save_confirmation_v086() -> void:
	if save_confirmation_v086 != null:
		return
	save_confirmation_v086 = AcceptDialog.new()
	save_confirmation_v086.title = "Saved"
	save_confirmation_v086.dialog_text = "Build has been saved."
	save_confirmation_v086.exclusive = true
	add_child(save_confirmation_v086)
	var close_button: Button = save_confirmation_v086.get_ok_button()
	if close_button != null:
		close_button.text = "Close"


func _show_save_confirmation_v086() -> void:
	if save_confirmation_v086 == null:
		_build_save_confirmation_v086()
	if save_confirmation_v086 != null:
		save_confirmation_v086.dialog_text = "Build has been saved."
		save_confirmation_v086.popup_centered(Vector2i(420, 180))


func _save_named_build_v050() -> void:
	if not _ensure_builds_dir_v050():
		_status("Could not create the saves folder")
		return
	var requested: String = build_name_v050.text if build_name_v050 != null else "Build"
	var safe: String = _safe_build_name_v050(requested)
	var path: String = "%s/%s.connex" % [BUILDS_DIR_V050, safe]
	if not _write_variant_file_v050(path, _save_bundle_v050(safe)):
		_status("Save failed: %s" % safe)
		return
	if build_name_v050 != null:
		build_name_v050.text = safe
	_refresh_build_list_v050()
	_status("Saved build: %s" % safe)
	_show_save_confirmation_v086()


# -----------------------------------------------------------------------------
# Parts inventory.
# Counts are always derived from the authoritative live body arrays, so Undo,
# Redo, Delete, Restart and Load cannot leave a stale counter behind.
# -----------------------------------------------------------------------------

func _parts_usage_counts_v086() -> Dictionary:
	var rod_counts: Array = []
	rod_counts.resize(rod_defs.size())
	for i in range(rod_counts.size()):
		rod_counts[i] = 0

	var connector_counts: Array = []
	connector_counts.resize(connector_defs.size())
	for i in range(connector_counts.size()):
		connector_counts[i] = 0

	var counted_ids: Dictionary = {}
	var total: int = 0
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		counted_ids[body.get_instance_id()] = true
		var kind: String = str(body.get_meta("kind", ""))
		if kind == "rod":
			var rod_index: int = int(body.get_meta("rod_type", -1))
			if rod_index >= 0 and rod_index < rod_counts.size():
				rod_counts[rod_index] = int(rod_counts[rod_index]) + 1
				total += 1
		elif kind == "connector":
			var connector_index: int = int(body.get_meta("connector_type", -1))
			if connector_index >= 0 and connector_index < connector_counts.size():
				connector_counts[connector_index] = int(connector_counts[connector_index]) + 1
				total += 1
		elif kind == "o_ring" and o_ring_index >= 0 and o_ring_index < connector_counts.size():
			connector_counts[o_ring_index] = int(connector_counts[o_ring_index]) + 1
			total += 1

	# O-Rings normally live outside `bodies`; keep the ID guard so a future storage
	# change cannot double-count them.
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring) or counted_ids.has(ring.get_instance_id()):
			continue
		if o_ring_index >= 0 and o_ring_index < connector_counts.size():
			connector_counts[o_ring_index] = int(connector_counts[o_ring_index]) + 1
			total += 1

	return {"rods": rod_counts, "connectors": connector_counts, "total": total}


func _refresh_parts_browser_v050() -> void:
	if parts_grid_v050 == null:
		return
	# Detach old cards immediately rather than leaving a second queued tree in the
	# GridContainer until the end of the frame.
	for child_value in parts_grid_v050.get_children():
		var old_child := child_value as Node
		parts_grid_v050.remove_child(old_child)
		old_child.queue_free()
	part_card_buttons_v050.clear()

	var usage: Dictionary = _parts_usage_counts_v086()
	var rod_counts: Array = usage.get("rods", []) as Array
	var connector_counts: Array = usage.get("connectors", []) as Array
	var total: int = int(usage.get("total", 0))
	if parts_title_v050 != null:
		parts_title_v050.text = "PARTS BROWSER • %d IN BUILD" % total

	var defs: Array = rod_defs if parts_tab_v050 == 0 else connector_defs
	var counts: Array = rod_counts if parts_tab_v050 == 0 else connector_counts
	for i in range(defs.size()):
		var definition: Dictionary = defs[i] as Dictionary
		var name_value: String = str(definition.get("name", "Part"))
		var detail: String = ""
		if parts_tab_v050 == 0:
			detail = "%.1f mm" % float(definition.get("actual_mm", 0.0))
		else:
			var special: String = str(definition.get("special", ""))
			detail = "Axle stop" if special == "o_ring" else "%d connection points" % (definition.get("slots", []) as Array).size()
		var used: int = int(counts[i]) if i < counts.size() else 0
		var button: Button = _ui_button(
			"%s\n%s\nUsed: %d" % [name_value, detail, used],
			func(index_value: int = i) -> void: _choose_part_v050(index_value),
			false
		)
		button.custom_minimum_size = Vector2(180.0, 92.0)
		button.add_theme_font_size_override("font_size", 14)
		var selected: bool = i == (selected_rod_type if parts_tab_v050 == 0 else selected_connector_type)
		var color: Color = definition.get("color", Color(0.4, 0.5, 0.6)) as Color
		button.add_theme_stylebox_override("normal", _part_card_style_v050(color, selected))
		button.add_theme_stylebox_override("hover", _part_card_style_v050(color.lightened(0.10), selected))
		parts_grid_v050.add_child(button)
		part_card_buttons_v050.append(button)

	if parts_rods_button_v050 != null:
		parts_rods_button_v050.text = ("● " if parts_tab_v050 == 0 else "") + "RODS"
	if parts_connectors_button_v050 != null:
		parts_connectors_button_v050.text = ("● " if parts_tab_v050 == 1 else "") + "CONNECTORS"


func _refresh_parts_usage_if_open_v086() -> void:
	if parts_panel_v050 != null and parts_panel_v050.visible:
		_refresh_parts_browser_v050()


# -----------------------------------------------------------------------------
# PERFORMANCE: retire hidden legacy preview work.
#
# v0.2 evaluated up to seven complete graph/rotation previews from every UI
# refresh solely to gray out rotation buttons. Those buttons are no longer shown
# by the modern TRANSFORM UI, so calculating their previews is pure overhead.
# -----------------------------------------------------------------------------

func _update_rotation_buttons_v020() -> void:
	var enabled: bool = not simulating and _selected_kind() == "connector"
	for button_value in [rot_up_v020, rot_down_v020, rot_left_v020, rot_right_v020, roll_left_v020, roll_right_v020]:
		var button := button_value as Button
		if button != null:
			button.disabled = not enabled
	if reset_rotation_v020 != null:
		reset_rotation_v020.disabled = not enabled


# The visible world-axis gizmo also used to pre-solve +45° and -45° for every
# axis whenever its state refreshed. Actual drag already validates the selected
# axis/step before commit, so keep only the cheap visual enable state here.
func _refresh_gizmo_validity_v030() -> void:
	if gizmo_root_v030 == null:
		return
	var enabled: bool = editor_mode_v032 == EDITOR_ROTATE_032 and not simulating and is_instance_valid(selected_piece) and tool_mode_v030.is_empty()
	for name_value in ["X", "Y", "Z"]:
		if not gizmo_axes_v030.has(name_value):
			continue
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var ring := data.get("ring") as MeshInstance3D
		var plus_label := data.get("plus") as Label3D
		var minus_label := data.get("minus") as Label3D
		var base_material := data.get("material") as StandardMaterial3D
		if ring != null:
			ring.material_override = base_material if enabled else gizmo_disabled_mat_v030
		if plus_label != null:
			plus_label.modulate = base_material.albedo_color if enabled and base_material != null else gizmo_disabled_mat_v030.albedo_color
		if minus_label != null:
			minus_label.modulate = base_material.albedo_color if enabled and base_material != null else gizmo_disabled_mat_v030.albedo_color


# Picking a ring should be geometry picking, not six whole-construction trial
# rotations. _begin_gizmo_drag_v030() checks the rotation context and each snapped
# drag step still runs _rotation_candidate_v030(), preserving correctness.
func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var best: Dictionary = {}
	var best_distance: float = WORLD_GIZMO_PICK_PX_035
	for name_value in ["X", "Y", "Z"]:
		if not gizmo_axes_v030.has(name_value):
			continue
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var axis: Vector3 = data.get("axis", Vector3.ZERO) as Vector3
		if axis.length_squared() < 0.5:
			continue
		var pick: Dictionary = _ring_pick_v035(axis, screen_pos, best_distance)
		if pick.is_empty():
			continue
		var distance: float = float(pick.get("distance", best_distance))
		if distance <= best_distance:
			best_distance = distance
			best = {
				"name": name_value,
				"axis": axis,
				"center": pick.get("center", _gizmo_anchor_v030()),
				"tangent": pick.get("tangent", Vector2.RIGHT),
			}
	return best


# -----------------------------------------------------------------------------
# PERFORMANCE: local auto-connect instead of whole-build O(n²) scans on every
# click. A full inherited scan still runs before SIMULATE and after removals.
# -----------------------------------------------------------------------------

func _autofuse_body_state_v086(body: RigidBody3D) -> Dictionary:
	if not is_instance_valid(body):
		return {}
	var kind: String = str(body.get_meta("kind", ""))
	var type_index: int = -1
	if kind == "rod":
		type_index = int(body.get_meta("rod_type", -1))
	elif kind == "connector":
		type_index = int(body.get_meta("connector_type", -1))
	return {
		"transform": body.global_transform,
		"kind": kind,
		"type": type_index,
		"length": float(body.get_meta("visual_length", 0.0)),
	}


func _snapshot_autofuse_bodies_v086() -> void:
	autofuse_body_cache_v086.clear()
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			autofuse_body_cache_v086[body.get_instance_id()] = _autofuse_body_state_v086(body)


func _autofuse_body_changed_v086(body: RigidBody3D) -> bool:
	if not is_instance_valid(body):
		return false
	var key: int = body.get_instance_id()
	if not autofuse_body_cache_v086.has(key):
		return true
	var old_state: Dictionary = autofuse_body_cache_v086.get(key, {}) as Dictionary
	var current_state: Dictionary = _autofuse_body_state_v086(body)
	if str(old_state.get("kind", "")) != str(current_state.get("kind", "")):
		return true
	if int(old_state.get("type", -1)) != int(current_state.get("type", -1)):
		return true
	if not is_equal_approx(float(old_state.get("length", 0.0)), float(current_state.get("length", 0.0))):
		return true
	var old_transform: Transform3D = old_state.get("transform", body.global_transform) as Transform3D
	return not old_transform.is_equal_approx(body.global_transform)


func _changed_autofuse_bodies_v086() -> Dictionary:
	var changed: Array = []
	var current_ids: Dictionary = {}
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		current_ids[body.get_instance_id()] = true
		if _autofuse_body_changed_v086(body):
			changed.append(body)
	var removed: bool = false
	for cached_id in autofuse_body_cache_v086.keys():
		if not current_ids.has(cached_id):
			removed = true
			break
	return {"changed": changed, "removed": removed}


func _auto_connect_one_connector_end_v086(connector: RigidBody3D) -> bool:
	if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
		return false
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return false
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	var best: Dictionary = {}
	var best_distance: float = SOCKET_CAPTURE_V020

	for slot_value in connector_defs[def_index].get("slots", []):
		var slot: int = int(slot_value)
		if occupied.has(slot):
			continue
		var socket: Dictionary = _socket_world_v020(connector, slot)
		var socket_point: Vector3 = socket.get("point", connector.global_position) as Vector3
		var socket_dir: Vector3 = socket.get("dir", Vector3.ZERO) as Vector3
		for rod_value in bodies:
			var rod := rod_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			if _fixed_pair_exists_v020(rod, connector):
				continue
			var rod_occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
			var rod_axis: Vector3 = _rod_axis_v020(rod)
			for sign_value in [-1, 1]:
				var sign_int: int = int(sign_value)
				if rod_occupied.has(sign_int):
					continue
				var outward: Vector3 = rod_axis * float(sign_int)
				if socket_dir.dot(-outward) < SOCKET_ALIGN_V020:
					continue
				var rod_point: Vector3 = _rod_end_v020(rod, sign_int)
				var distance: float = socket_point.distance_to(rod_point)
				if distance <= best_distance:
					best_distance = distance
					best = {
						"rod": rod,
						"slot": slot,
						"sign": sign_int,
						"socket_point": socket_point,
						"rod_point": rod_point,
					}

	if best.is_empty():
		return false
	var rod := best.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return false
	var slot: int = int(best.get("slot", -1))
	var sign_value: int = int(best.get("sign", 0))
	var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
	var anchor: Vector3 = ((best.get("socket_point") as Vector3) + (best.get("rod_point") as Vector3)) * 0.5
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
	_tag_connection_v020(joint, "socket", connector, rod, slot, sign_value, 0.0, null, primary)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	return true


func _auto_connect_one_connector_cross_v086(connector: RigidBody3D) -> bool:
	if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
		return false
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return false
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	for slot_value in connector_defs[def_index].get("slots", []):
		var slot: int = int(slot_value)
		if occupied.has(slot):
			continue
		var socket: Dictionary = _socket_world_v020(connector, slot)
		var mouth: Vector3 = socket.get("point", connector.global_position) as Vector3
		var slot_dir: Vector3 = socket.get("dir", Vector3.ZERO) as Vector3
		var best_rod: RigidBody3D = null
		var best_along: float = 0.0
		var best_distance: float = CROSS_CAPTURE_V020
		for rod_value in bodies:
			var rod := rod_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
				continue
			if _fixed_pair_exists_v020(rod, connector):
				continue
			var axis: Vector3 = _rod_axis_v020(rod)
			if absf(axis.dot(slot_dir)) > CROSS_PERP_V020:
				continue
			var half_len: float = maxf(0.0, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.50)
			var along: float = clampf((mouth - rod.global_position).dot(axis), -half_len, half_len)
			var closest: Vector3 = rod.global_position + axis * along
			var distance: float = closest.distance_to(mouth)
			if distance <= best_distance:
				best_distance = distance
				best_rod = rod
				best_along = along
		if is_instance_valid(best_rod):
			var host_point: Vector3 = best_rod.global_position + _rod_axis_v020(best_rod) * best_along
			var anchor: Vector3 = (mouth + host_point) * 0.5
			var joint: Generic6DOFJoint3D = _make_fixed_joint(best_rod, connector, anchor)
			var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
			var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
			_tag_connection_v020(joint, "cross", connector, best_rod, slot, 0, best_along, null, primary)
			_set_connector_occupied(connector, slot, true)
			return true
	return false


func _auto_connect_one_rod_cross_v086(rod: RigidBody3D) -> bool:
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		return false
	var rod_axis: Vector3 = _rod_axis_v020(rod)
	var half_len: float = maxf(0.0, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.50)
	var best: Dictionary = {}
	var best_distance: float = CROSS_CAPTURE_V020
	for body_value in bodies:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		if _fixed_pair_exists_v020(rod, connector):
			continue
		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size():
			continue
		var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
		for slot_value in connector_defs[def_index].get("slots", []):
			var slot: int = int(slot_value)
			if occupied.has(slot):
				continue
			var socket: Dictionary = _socket_world_v020(connector, slot)
			var mouth: Vector3 = socket.get("point", connector.global_position) as Vector3
			var slot_dir: Vector3 = socket.get("dir", Vector3.ZERO) as Vector3
			if absf(rod_axis.dot(slot_dir)) > CROSS_PERP_V020:
				continue
			var along: float = clampf((mouth - rod.global_position).dot(rod_axis), -half_len, half_len)
			var closest: Vector3 = rod.global_position + rod_axis * along
			var distance: float = closest.distance_to(mouth)
			if distance <= best_distance:
				best_distance = distance
				best = {"connector": connector, "slot": slot, "along": along, "mouth": mouth}

	if best.is_empty():
		return false
	var connector := best.get("connector") as RigidBody3D
	if not is_instance_valid(connector):
		return false
	var slot: int = int(best.get("slot", -1))
	var along: float = float(best.get("along", 0.0))
	var mouth: Vector3 = best.get("mouth", connector.global_position) as Vector3
	var host_point: Vector3 = rod.global_position + rod_axis * along
	var anchor: Vector3 = (mouth + host_point) * 0.5
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	var had_connections: bool = not _connections_for_piece_v020(connector).is_empty()
	var primary: bool = not had_connections and not bool(connector.get_meta("root_piece_v020", false)) and int(connector.get_meta("primary_connection_uid_v020", -1)) < 0
	_tag_connection_v020(joint, "cross", connector, rod, slot, 0, along, null, primary)
	_set_connector_occupied(connector, slot, true)
	return true


func _auto_connect_local_v086(changed: Array) -> int:
	if changed.is_empty():
		return 0
	_rebuild_connection_graph_v020()
	var total: int = 0
	var budget: int = maxi(AUTOFUSE_LOCAL_MATCH_BUDGET_086, changed.size() * 4)
	for _pass in range(budget):
		var matched: bool = false

		# Rod-end/socket capture has priority, matching the inherited full scan.
		for body_value in changed:
			var body := body_value as RigidBody3D
			if not is_instance_valid(body) or str(body.get_meta("kind", "")) != "rod":
				continue
			if _auto_connect_end_v020(body, -1) or _auto_connect_end_v020(body, 1):
				matched = true
				break
		if not matched:
			for body_value in changed:
				var body := body_value as RigidBody3D
				if is_instance_valid(body) and str(body.get_meta("kind", "")) == "connector" and _auto_connect_one_connector_end_v086(body):
					matched = true
					break

		# Cross capture comes only after free rod-end/socket matches.
		if not matched:
			for body_value in changed:
				var body := body_value as RigidBody3D
				if is_instance_valid(body) and str(body.get_meta("kind", "")) == "connector" and _auto_connect_one_connector_cross_v086(body):
					matched = true
					break
		if not matched:
			for body_value in changed:
				var body := body_value as RigidBody3D
				if is_instance_valid(body) and str(body.get_meta("kind", "")) == "rod" and _auto_connect_one_rod_cross_v086(body):
					matched = true
					break

		if not matched:
			break
		total += 1
		# Keep the authoritative graph/occupancy current before looking for another
		# local match. Only successful matches pay this rebuild cost.
		_rebuild_connection_graph_v020()
	return total


func _auto_connect_all_v020() -> int:
	if restoring_v020 or restoring_state:
		return 0

	# Simulation preflight consumes this one-shot flag and uses the exact inherited
	# whole-build matcher. A removal also gets a full pass because freed ports can
	# make a previously unchanged neighbor eligible.
	if autofuse_force_full_v086:
		autofuse_force_full_v086 = false
		var full_total: int = super._auto_connect_all_v020()
		_snapshot_autofuse_bodies_v086()
		return full_total

	var change_info: Dictionary = _changed_autofuse_bodies_v086()
	var changed: Array = change_info.get("changed", []) as Array
	var removed: bool = bool(change_info.get("removed", false))
	if removed:
		var removal_total: int = super._auto_connect_all_v020()
		_snapshot_autofuse_bodies_v086()
		return removal_total
	if changed.is_empty():
		return 0

	var local_total: int = _auto_connect_local_v086(changed)
	_snapshot_autofuse_bodies_v086()
	return local_total


# -----------------------------------------------------------------------------
# PERFORMANCE: ATTACH marker pose polling.
# The build is frozen outside simulation, and explicit edit/restore paths already
# invalidate the marker overlay. Polling every body transform at 60+ Hz therefore
# wastes allocations; 8 Hz is ample as a fallback while dragging/editing.
# -----------------------------------------------------------------------------

func _sync_attach_overlay_pose_v076(force_refresh: bool = false) -> bool:
	var now: int = Time.get_ticks_msec()
	if not force_refresh and now < next_attach_pose_check_ms_v086:
		return false
	next_attach_pose_check_ms_v086 = now + ATTACH_POSE_CHECK_MS_086
	return super._sync_attach_overlay_pose_v076(force_refresh)


# -----------------------------------------------------------------------------
# State transitions keep inventory/autofuse caches authoritative.
# -----------------------------------------------------------------------------

func _commit_state() -> void:
	super._commit_state()
	_snapshot_autofuse_bodies_v086()
	_refresh_parts_usage_if_open_v086()


func _restore_state(snapshot: Dictionary) -> void:
	super._restore_state(snapshot)
	_snapshot_autofuse_bodies_v086()
	_refresh_parts_usage_if_open_v086()


func _restart_build() -> void:
	super._restart_build()
	_snapshot_autofuse_bodies_v086()
	_refresh_parts_usage_if_open_v086()


func _delete_selected() -> void:
	super._delete_selected()
	_snapshot_autofuse_bodies_v086()
	_refresh_parts_usage_if_open_v086()


func _change_rod_type(delta: int) -> void:
	super._change_rod_type(delta)
	_refresh_parts_usage_if_open_v086()


func _change_connector_type(delta: int) -> void:
	super._change_connector_type(delta)
	_refresh_parts_usage_if_open_v086()


func _toggle_simulation() -> void:
	if not simulating:
		# One exact whole-build auto-connect pass remains the SIMULATE safety net.
		autofuse_force_full_v086 = true
	super._toggle_simulation()
	autofuse_force_full_v086 = false
	_snapshot_autofuse_bodies_v086()
	_refresh_parts_usage_if_open_v086()
