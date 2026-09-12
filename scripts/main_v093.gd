extends "res://scripts/main_v092.gd"

const VERSION_093 := "0.5.29"

# Undo/Redo should not pay the original v0.1.3 cost of destroying and recreating
# the entire construction. Adjacent history states already contain stable v0.2
# piece/connection UIDs, so common history operations can be diffed in place.
# SIMULATE, named load/recovery, and every non-history restore keep the inherited
# conservative full validation/rebuild path.
var history_restore_context_v093: bool = false
var history_fast_used_v093: bool = false
var last_history_restore_ms_v093: float = 0.0
var last_undo_ms_v093: float = 0.0
var last_redo_ms_v093: float = 0.0
var history_removed_bodies_v093: int = 0
var history_created_bodies_v093: int = 0
var history_rebuilt_bodies_v093: int = 0
var history_removed_connections_v093: int = 0
var history_created_connections_v093: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_093)
	_status("v0.5.29 ready — instant placement retained; Undo/Redo use adjacent-state diff restore when safe.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_093, text]


# -----------------------------------------------------------------------------
# History UI suppression.
#
# Full fallback restore still runs every proven ancestor restore hook, but there
# is no reason for those layers to rebuild highlights/ATTACH/UI several times in
# the middle of one Undo/Redo. One authoritative refresh happens at the end.
# -----------------------------------------------------------------------------

func _update_ui() -> void:
	if history_restore_context_v093:
		return
	super._update_ui()


func _refresh_selection_highlight() -> void:
	if history_restore_context_v093:
		return
	super._refresh_selection_highlight()


func _refresh_attach_points_v032() -> void:
	if history_restore_context_v093:
		return
	super._refresh_attach_points_v032()


func _refresh_parts_browser_v050() -> void:
	if history_restore_context_v093:
		return
	super._refresh_parts_browser_v050()


func _finish_history_refresh_v093() -> void:
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	last_overlay_visibility_signature_v050 = ""
	attach_pose_cache_v076.clear()
	_refresh_selection_highlight()
	_refresh_attach_points_v032()
	if parts_panel_v050 != null and parts_panel_v050.visible:
		_refresh_parts_browser_v050()
	_update_ui()
	_sync_deselect_button_v083()


func _flush_pending_placement_before_history_v093() -> void:
	if placement_commit_queued_v091 or placement_commit_pending_v091:
		_flush_visible_commit_v091()


func _reset_history_profile_v093() -> void:
	history_fast_used_v093 = false
	last_history_restore_ms_v093 = 0.0
	history_removed_bodies_v093 = 0
	history_created_bodies_v093 = 0
	history_rebuilt_bodies_v093 = 0
	history_removed_connections_v093 = 0
	history_created_connections_v093 = 0


func _undo() -> void:
	if simulating:
		return
	_flush_pending_placement_before_history_v093()
	if state_index <= 0 or state_history.is_empty():
		return
	_reset_history_profile_v093()
	var started: int = Time.get_ticks_usec()
	var source := state_history[state_index] as Dictionary
	var target := state_history[state_index - 1] as Dictionary
	history_restore_context_v093 = true
	if _try_fast_history_restore_v093(source, target):
		state_index -= 1
		history_fast_used_v093 = true
		# Preserve v0.5.24's deliberate Undo behavior: after geometry changes the
		# palette should target the NEXT part, not a stale restored selection.
		_deselect_piece_v039(false)
	else:
		# Proven fallback for unusual/legacy snapshots and O-Ring topology edits.
		super._undo()
	history_restore_context_v093 = false
	_finish_history_refresh_v093()
	last_undo_ms_v093 = float(Time.get_ticks_usec() - started) / 1000.0
	_status("Undo")
	print("HISTORY_093_MS action=undo fast=%s total=%.2f core=%.2f removed_bodies=%d created_bodies=%d rebuilt_bodies=%d removed_connections=%d created_connections=%d bodies=%d" % [
		str(history_fast_used_v093), last_undo_ms_v093, last_history_restore_ms_v093,
		history_removed_bodies_v093, history_created_bodies_v093, history_rebuilt_bodies_v093,
		history_removed_connections_v093, history_created_connections_v093, bodies.size()
	])


func _redo() -> void:
	if simulating:
		return
	_flush_pending_placement_before_history_v093()
	if state_index < 0 or state_index >= state_history.size() - 1:
		return
	_reset_history_profile_v093()
	var started: int = Time.get_ticks_usec()
	var source := state_history[state_index] as Dictionary
	var target := state_history[state_index + 1] as Dictionary
	history_restore_context_v093 = true
	if _try_fast_history_restore_v093(source, target):
		state_index += 1
		history_fast_used_v093 = true
	else:
		super._redo()
	history_restore_context_v093 = false
	_finish_history_refresh_v093()
	last_redo_ms_v093 = float(Time.get_ticks_usec() - started) / 1000.0
	_status("Redo")
	print("HISTORY_093_MS action=redo fast=%s total=%.2f core=%.2f removed_bodies=%d created_bodies=%d rebuilt_bodies=%d removed_connections=%d created_connections=%d bodies=%d" % [
		str(history_fast_used_v093), last_redo_ms_v093, last_history_restore_ms_v093,
		history_removed_bodies_v093, history_created_bodies_v093, history_rebuilt_bodies_v093,
		history_removed_connections_v093, history_created_connections_v093, bodies.size()
	])


# -----------------------------------------------------------------------------
# Snapshot helpers.
# -----------------------------------------------------------------------------

func _snapshot_body_meta_v093(snapshot: Dictionary) -> Array:
	return snapshot.get("v020_body_meta", []) as Array


func _snapshot_bodies_v093(snapshot: Dictionary) -> Array:
	return snapshot.get("bodies", []) as Array


func _snapshot_uid_at_v093(snapshot: Dictionary, index: int) -> int:
	var meta: Array = _snapshot_body_meta_v093(snapshot)
	if index < 0 or index >= meta.size():
		return -1
	return int((meta[index] as Dictionary).get("uid", -1))


func _snapshot_uid_set_v093(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var meta: Array = _snapshot_body_meta_v093(snapshot)
	for value in meta:
		var entry := value as Dictionary
		var uid: int = int(entry.get("uid", -1))
		if uid >= 0:
			result[uid] = true
	return result


func _live_body_map_v093() -> Dictionary:
	var result: Dictionary = {}
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var uid: int = int(body.get_meta("piece_uid_v020", -1))
		if uid >= 0:
			result[uid] = body
	return result


func _dict_key_set_equal_v093(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true


func _rings_unchanged_v093(source: Dictionary, target: Dictionary) -> bool:
	var a: Array = source.get("o_rings", []) as Array
	var b: Array = target.get("o_rings", []) as Array
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		var aa := a[i] as Dictionary
		var bb := b[i] as Dictionary
		if int(aa.get("host", -1)) != int(bb.get("host", -1)):
			return false
		var at: Transform3D = aa.get("transform", Transform3D.IDENTITY) as Transform3D
		var bt: Transform3D = bb.get("transform", Transform3D.IDENTITY) as Transform3D
		if not at.is_equal_approx(bt):
			return false
		var ap: Vector3 = aa.get("anchor", at.origin) as Vector3
		var bp: Vector3 = bb.get("anchor", bt.origin) as Vector3
		if not ap.is_equal_approx(bp):
			return false
	return true


func _snapshot_connection_map_v093(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for value in snapshot.get("v020_connections", []) as Array:
		var saved := value as Dictionary
		var uid: int = int(saved.get("uid", -1))
		if uid >= 0:
			result[uid] = saved
	return result


func _snapshot_connection_signature_v093(snapshot: Dictionary, saved: Dictionary) -> String:
	var connector_uid: int = _snapshot_uid_at_v093(snapshot, int(saved.get("connector_index", -1)))
	var rod_uid: int = _snapshot_uid_at_v093(snapshot, int(saved.get("rod_index", -1)))
	var ring_index: int = int(saved.get("ring_index", -1))
	return "%s|c%d|r%d|o%d" % [str(saved.get("kind", "")), connector_uid, rod_uid, ring_index]


func _live_connection_map_v093() -> Dictionary:
	var result: Dictionary = {}
	for value in connections_v020:
		var record := value as Dictionary
		var uid: int = int(record.get("uid", -1))
		if uid >= 0:
			result[uid] = record
	return result


func _live_connection_signature_v093(record: Dictionary) -> String:
	var connector := record.get("connector") as RigidBody3D
	var rod := record.get("rod") as RigidBody3D
	var ring := record.get("ring") as RigidBody3D
	var connector_uid: int = int(connector.get_meta("piece_uid_v020", -1)) if is_instance_valid(connector) else -1
	var rod_uid: int = int(rod.get_meta("piece_uid_v020", -1)) if is_instance_valid(rod) else -1
	var ring_index: int = o_ring_stops.find(ring) if is_instance_valid(ring) else -1
	return "%s|c%d|r%d|o%d" % [str(record.get("kind", "")), connector_uid, rod_uid, ring_index]


func _source_matches_live_v093(source: Dictionary) -> bool:
	var source_uids: Dictionary = _snapshot_uid_set_v093(source)
	var live_bodies: Dictionary = _live_body_map_v093()
	if not _dict_key_set_equal_v093(source_uids, live_bodies):
		return false
	var source_connections: Dictionary = _snapshot_connection_map_v093(source)
	var live_connections: Dictionary = _live_connection_map_v093()
	if source_connections.size() != live_connections.size():
		return false
	for uid_value in source_connections.keys():
		var uid: int = int(uid_value)
		if not live_connections.has(uid):
			return false
		if _snapshot_connection_signature_v093(source, source_connections[uid] as Dictionary) != _live_connection_signature_v093(live_connections[uid] as Dictionary):
			return false
	return true


func _body_snapshot_compatible_v093(source: Dictionary, target: Dictionary, uid: int) -> bool:
	var source_meta: Array = _snapshot_body_meta_v093(source)
	var target_meta: Array = _snapshot_body_meta_v093(target)
	var source_bodies: Array = _snapshot_bodies_v093(source)
	var target_bodies: Array = _snapshot_bodies_v093(target)
	var source_index: int = -1
	var target_index: int = -1
	for i in range(source_meta.size()):
		if int((source_meta[i] as Dictionary).get("uid", -1)) == uid:
			source_index = i
			break
	for i in range(target_meta.size()):
		if int((target_meta[i] as Dictionary).get("uid", -1)) == uid:
			target_index = i
			break
	if source_index < 0 or target_index < 0 or source_index >= source_bodies.size() or target_index >= target_bodies.size():
		return false
	return str((source_bodies[source_index] as Dictionary).get("kind", "")) == str((target_bodies[target_index] as Dictionary).get("kind", ""))


# -----------------------------------------------------------------------------
# Fast adjacent-state restore.
# -----------------------------------------------------------------------------

func _try_fast_history_restore_v093(source: Dictionary, target: Dictionary) -> bool:
	var started: int = Time.get_ticks_usec()
	if _snapshot_body_meta_v093(source).size() != _snapshot_bodies_v093(source).size():
		return false
	if _snapshot_body_meta_v093(target).size() != _snapshot_bodies_v093(target).size():
		return false
	if not _rings_unchanged_v093(source, target):
		return false

	# Refresh once so the diff is based on the authoritative current graph. This
	# is linear bookkeeping, not the old whole-scene node recreation.
	_rebuild_connection_graph_v020()
	if not _source_matches_live_v093(source):
		return false

	var source_uids: Dictionary = _snapshot_uid_set_v093(source)
	var target_uids: Dictionary = _snapshot_uid_set_v093(target)
	var removed: Array = []
	var added: Array = []
	for uid_value in source_uids.keys():
		if not target_uids.has(uid_value):
			removed.append(int(uid_value))
	for uid_value in target_uids.keys():
		if not source_uids.has(uid_value):
			added.append(int(uid_value))
	# One editor operation may add OR remove one normal body. More complex legacy
	# snapshots still use the inherited full restore.
	if removed.size() > 1 or added.size() > 1 or (not removed.is_empty() and not added.is_empty()):
		return false
	for uid_value in source_uids.keys():
		var uid: int = int(uid_value)
		if target_uids.has(uid) and not _body_snapshot_compatible_v093(source, target, uid):
			return false

	var source_conn: Dictionary = _snapshot_connection_map_v093(source)
	var target_conn: Dictionary = _snapshot_connection_map_v093(target)
	# O-Ring bodies stay on the conservative path if their topology changes.
	for uid_value in source_conn.keys():
		var uid: int = int(uid_value)
		var src := source_conn[uid] as Dictionary
		if str(src.get("kind", "")) == "o_ring":
			if not target_conn.has(uid) or _snapshot_connection_signature_v093(source, src) != _snapshot_connection_signature_v093(target, target_conn[uid] as Dictionary):
				return false
	for uid_value in target_conn.keys():
		var uid: int = int(uid_value)
		var dst := target_conn[uid] as Dictionary
		if str(dst.get("kind", "")) == "o_ring" and not source_conn.has(uid):
			return false

	_clear_selection_highlight()
	select_armed_v020 = false
	# Remove connections that do not exist in the target, or whose endpoints/kind
	# changed under the same UID. Never create Detach quarantine entries here.
	var live_conn: Dictionary = _live_connection_map_v093()
	for uid_value in live_conn.keys():
		var uid: int = int(uid_value)
		var record := live_conn[uid] as Dictionary
		var keep: bool = target_conn.has(uid)
		if keep:
			keep = _live_connection_signature_v093(record) == _snapshot_connection_signature_v093(target, target_conn[uid] as Dictionary)
		if keep:
			continue
		var joint := record.get("joint") as Joint3D
		if is_instance_valid(joint):
			joints.erase(joint)
			joint.queue_free()
		history_removed_connections_v093 += 1

	var live_bodies: Dictionary = _live_body_map_v093()
	for uid_value in removed:
		var body := live_bodies.get(uid_value) as RigidBody3D
		if not is_instance_valid(body):
			return false
		body.collision_layer = 0
		body.collision_mask = 0
		body.freeze = true
		bodies.erase(body)
		body.queue_free()
		live_bodies.erase(uid_value)
		history_removed_bodies_v093 += 1

	# Create only the one body missing from the live scene. Every existing piece
	# keeps its MeshInstance/CollisionShape node tree and physics body identity.
	if not added.is_empty():
		var added_uid: int = int(added[0])
		var target_meta: Array = _snapshot_body_meta_v093(target)
		var target_states: Array = _snapshot_bodies_v093(target)
		var target_index: int = -1
		for i in range(target_meta.size()):
			if int((target_meta[i] as Dictionary).get("uid", -1)) == added_uid:
				target_index = i
				break
		if target_index < 0:
			return false
		var state := target_states[target_index] as Dictionary
		var transform: Transform3D = state.get("transform", Transform3D.IDENTITY) as Transform3D
		var body: RigidBody3D
		if str(state.get("kind", "")) == "connector":
			body = _make_connector(int(state.get("type", 0)), transform)
		else:
			var length: float = float(state.get("length", 0.0))
			var axis: Vector3 = (transform.basis * Vector3.UP).normalized()
			body = _make_rod(int(state.get("type", 0)), transform.origin - axis * length * 0.5, transform.origin + axis * length * 0.5)
			body.global_transform = transform
		if not is_instance_valid(body):
			return false
		body.set_meta("piece_uid_v020", added_uid)
		live_bodies[added_uid] = body
		history_created_bodies_v093 += 1

	# Apply the target body state in target order. Type/length changes rebuild only
	# that one piece's visuals/collider; ordinary transform/placement history does
	# not recreate any existing body nodes.
	var target_meta_all: Array = _snapshot_body_meta_v093(target)
	var target_states_all: Array = _snapshot_bodies_v093(target)
	var target_body_order: Array = []
	for i in range(target_states_all.size()):
		var meta := target_meta_all[i] as Dictionary
		var uid: int = int(meta.get("uid", -1))
		var body := live_bodies.get(uid) as RigidBody3D
		if not is_instance_valid(body):
			return false
		_apply_target_body_state_v093(body, target_states_all[i] as Dictionary, meta)
		target_body_order.append(body)
	bodies = target_body_order

	# Restore cross host references now that target body ordering is authoritative.
	for i in range(target_states_all.size()):
		var state := target_states_all[i] as Dictionary
		if str(state.get("kind", "")) != "connector" or not bool(state.get("cross_mount", false)):
			continue
		var connector := bodies[i] as RigidBody3D
		var host_index: int = int(state.get("cross_host_index", -1))
		if host_index >= 0 and host_index < bodies.size():
			connector.set_meta("cross_host_rod", bodies[host_index])

	# Existing connections keep their Joint3D objects. Add only target connections
	# that are missing after the diff.
	for uid_value in target_conn.keys():
		var uid: int = int(uid_value)
		if _joint_by_connection_uid_v093(uid) != null:
			continue
		if not _create_target_connection_v093(target, target_conn[uid] as Dictionary):
			return false
		history_created_connections_v093 += 1

	# Apply exact saved topology metadata to both retained and newly-created joints.
	for uid_value in target_conn.keys():
		var uid: int = int(uid_value)
		var joint := _joint_by_connection_uid_v093(uid)
		if not is_instance_valid(joint):
			return false
		_apply_target_connection_meta_v093(joint, target_conn[uid] as Dictionary)

	next_piece_uid_v020 = int(target.get("v020_next_piece_uid", next_piece_uid_v020))
	next_connection_uid_v020 = int(target.get("v020_next_connection_uid", next_connection_uid_v020))
	selected_rod_type = int(target.get("rod_type", selected_rod_type))
	selected_connector_type = int(target.get("connector_type", selected_connector_type))
	edit_mode = true
	last_placed_connector = null
	history.clear()

	# First discover tagged joints without overwriting snapshot occupancy, then put
	# every joint frame at the target geometry and perform one authoritative graph /
	# occupancy rebuild. This is the same graph representation SIMULATE consumes.
	_rebuild_connection_graph_v020(false)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020(true)

	# Reconstruct convenience host metadata from the now-authoritative target graph.
	for value in connections_v020:
		var record := value as Dictionary
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var kind: String = str(record.get("kind", ""))
		if kind == "axle":
			connector.set_meta("axle_occupied", true)
			connector.set_meta("axle_host_rod", rod)
		elif kind == "cross":
			connector.set_meta("cross_mount", true)
			connector.set_meta("cross_host_rod", rod)

	var selected_ring: int = int(target.get("selected_o_ring", -1))
	if selected_ring >= 0 and selected_ring < o_ring_stops.size():
		selected_piece = o_ring_stops[selected_ring] as RigidBody3D
	else:
		var selected_index: int = int(target.get("selected", -1))
		selected_piece = bodies[selected_index] as RigidBody3D if selected_index >= 0 and selected_index < bodies.size() else null

	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	last_history_restore_ms_v093 = float(Time.get_ticks_usec() - started) / 1000.0
	return true


func _apply_target_body_state_v093(body: RigidBody3D, state: Dictionary, meta: Dictionary) -> void:
	var kind: String = str(state.get("kind", ""))
	var transform: Transform3D = state.get("transform", body.global_transform) as Transform3D
	body.freeze = true
	body.sleeping = false
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	if kind == "connector":
		var target_type: int = int(state.get("type", body.get_meta("connector_type", 0)))
		if int(body.get_meta("connector_type", -1)) != target_type:
			_rebuild_connector(body, target_type)
			history_rebuilt_bodies_v093 += 1
		body.global_transform = transform
		body.set_meta("kind", "connector")
		body.set_meta("connector_type", target_type)
		body.set_meta("occupied", (state.get("occupied", {}) as Dictionary).duplicate(true))
		body.set_meta("axle_occupied", bool(state.get("axle_occupied", false)))
		body.set_meta("mount_slot", -1)
		body.set_meta("mount_target_dir", Vector3.ZERO)
		body.set_meta("twist", 0)
		body.set_meta("axle_host_rod", null)
		body.set_meta("cross_mount", bool(state.get("cross_mount", false)))
		body.set_meta("cross_host_rod", null)
		if bool(state.get("cross_mount", false)):
			body.set_meta("cross_home_offset", state.get("cross_home_offset", Vector3.ZERO))
			body.set_meta("cross_home_basis", state.get("cross_home_basis", transform.basis))
		elif body.has_meta("cross_home_offset"):
			body.remove_meta("cross_home_offset")
		if not bool(state.get("cross_mount", false)) and body.has_meta("cross_home_basis"):
			body.remove_meta("cross_home_basis")
		var home_transform: Transform3D = state.get("rotation_home_transform", transform) as Transform3D
		body.set_meta("rotation_home_transform", home_transform)
		body.set_meta("rotation_home_basis", home_transform.basis)
	else:
		var target_type: int = int(state.get("type", body.get_meta("rod_type", 0)))
		var target_length: float = float(state.get("length", body.get_meta("visual_length", 0.0)))
		if int(body.get_meta("rod_type", -1)) != target_type or not is_equal_approx(float(body.get_meta("visual_length", -1.0)), target_length):
			_rebuild_rod(body, target_type, target_length)
			history_rebuilt_bodies_v093 += 1
		body.global_transform = transform
		var axis: Vector3 = (transform.basis * Vector3.UP).normalized()
		body.set_meta("kind", "rod")
		body.set_meta("rod_type", target_type)
		body.set_meta("visual_length", target_length)
		body.set_meta("axis", axis)
		body.set_meta("end_occupied", (state.get("end_occupied", {}) as Dictionary).duplicate(true))
		body.set_meta("axle_connector", null)
	body.set_meta("seed", bool(state.get("seed", false)))
	body.set_meta("build_transform", transform)
	body.set_meta("piece_uid_v020", int(meta.get("uid", body.get_meta("piece_uid_v020", -1))))
	body.set_meta("root_piece_v020", bool(meta.get("root", false)))
	body.set_meta("primary_connection_uid_v020", int(meta.get("primary", -1)))
	body.set_meta("rotation_home_basis_v020", meta.get("home_basis", transform.basis))


func _joint_by_connection_uid_v093(uid: int) -> Joint3D:
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if is_instance_valid(joint) and int(joint.get_meta("connection_uid_v020", -1)) == uid:
			return joint
	return null


func _create_target_connection_v093(target: Dictionary, saved: Dictionary) -> bool:
	var kind: String = str(saved.get("kind", ""))
	if kind == "o_ring":
		return false
	var connector_index: int = int(saved.get("connector_index", -1))
	var rod_index: int = int(saved.get("rod_index", -1))
	if connector_index < 0 or connector_index >= bodies.size() or rod_index < 0 or rod_index >= bodies.size():
		return false
	var connector := bodies[connector_index] as RigidBody3D
	var rod := bodies[rod_index] as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return false
	var joint: Joint3D
	if kind == "axle":
		joint = _make_axle_joint(connector, rod)
	else:
		joint = _make_fixed_joint(rod, connector, rod.global_position)
	if not is_instance_valid(joint):
		return false
	var uid: int = int(saved.get("uid", -1))
	joint.set_meta("connection_uid_v020", uid)
	_tag_connection_v020(
		joint, kind, connector, rod,
		int(saved.get("slot", -1)), int(saved.get("rod_end", 0)),
		float(saved.get("host_along", 0.0)), null, false
	)
	return true


func _apply_target_connection_meta_v093(joint: Joint3D, saved: Dictionary) -> void:
	var kind: String = str(saved.get("kind", ""))
	joint.set_meta("connection_uid_v020", int(saved.get("uid", -1)))
	joint.set_meta("connection_kind_v020", kind)
	joint.set_meta("connector_slot_v020", int(saved.get("slot", -1)))
	joint.set_meta("rod_end_v020", int(saved.get("rod_end", 0)))
	joint.set_meta("host_along_v020", float(saved.get("host_along", 0.0)))
	joint.set_meta("rest_gap_v020", float(saved.get("rest_gap", 0.0)))
	joint.set_meta("rest_align_v020", float(saved.get("rest_align", 1.0)))
	joint.set_meta("rest_perp_v020", float(saved.get("rest_perp", 0.0)))
	joint.set_meta("rest_plane_v020", float(saved.get("rest_plane", 0.0)))
	if kind == "cross":
		joint.set_meta("cross_mount", true)
	elif joint.has_meta("cross_mount"):
		joint.remove_meta("cross_mount")


# -----------------------------------------------------------------------------
# Persist/update metadata on the actual running version.
# -----------------------------------------------------------------------------

func _save_bundle_v050(name_value: String) -> Dictionary:
	var bundle: Dictionary = super._save_bundle_v050(name_value)
	bundle["app_version"] = VERSION_093
	return bundle


func _autosave_bundle_v089() -> Dictionary:
	var bundle: Dictionary = super._autosave_bundle_v089()
	bundle["app_version"] = VERSION_093
	return bundle


func _reconcile_update_version_v089(latest: String) -> void:
	var clean: String = latest.strip_edges().trim_prefix("v")
	if clean.is_empty():
		return
	if _compare_versions_v021(clean, VERSION_093) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		pending_apk_uri_v021 = null
		waiting_unknown_sources_permission_v021 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_093)
		if update_button_v021 != null:
			update_button_v021.disabled = false
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_093, clean])
		if update_button_v021 != null and not update_available_url_v021.is_empty():
			update_button_v021.text = "Update to v%s" % clean
