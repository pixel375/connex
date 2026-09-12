extends "res://scripts/main_v090.gd"

const VERSION_091 := "0.5.28"

# A placement is now split into two phases:
# 1) create the real body/joint and return to the renderer immediately;
# 2) after that frame has been drawn, finalize auto-connect/history/UI bookkeeping.
# This keeps tap -> visible-piece latency independent of construction size while
# preserving the same authoritative commit path before the next editor frame.
var placement_depth_v091: int = 0
var placement_fast_context_v091: bool = false
var placement_commit_pending_v091: bool = false
var placement_commit_queued_v091: bool = false
var placement_commit_flushing_v091: bool = false
var placement_started_usec_v091: int = 0

# Exposed to regressions and useful in Android debug logs.
var last_visible_dispatch_ms_v091: float = 0.0
var last_deferred_commit_ms_v091: float = 0.0
var profile_capture_ms_v091: float = 0.0
var profile_autoconnect_ms_v091: float = 0.0
var profile_graph_ms_v091: float = 0.0
var profile_ui_ms_v091: float = 0.0
var profile_graph_skips_v091: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_091)
	_status("v0.5.28 ready — visible-first placement and incremental create-graph commits are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_091, text]


# -----------------------------------------------------------------------------
# Visible-first placement transaction.
# -----------------------------------------------------------------------------

func _reset_placement_profile_v091() -> void:
	profile_capture_ms_v091 = 0.0
	profile_autoconnect_ms_v091 = 0.0
	profile_graph_ms_v091 = 0.0
	profile_ui_ms_v091 = 0.0
	profile_graph_skips_v091 = 0


func _begin_visible_placement_v091() -> void:
	if placement_depth_v091 == 0:
		placement_fast_context_v091 = true
		placement_commit_pending_v091 = false
		placement_started_usec_v091 = Time.get_ticks_usec()
		_reset_placement_profile_v091()
	placement_depth_v091 += 1


func _end_visible_placement_v091() -> void:
	placement_depth_v091 = maxi(0, placement_depth_v091 - 1)
	if placement_depth_v091 > 0:
		return
	last_visible_dispatch_ms_v091 = float(Time.get_ticks_usec() - placement_started_usec_v091) / 1000.0
	placement_fast_context_v091 = false
	if placement_commit_pending_v091:
		_queue_visible_commit_v091()


func _queue_visible_commit_v091() -> void:
	if placement_commit_queued_v091 or placement_commit_flushing_v091:
		return
	placement_commit_queued_v091 = true
	call_deferred("_commit_after_visible_frame_v091")


func _commit_after_visible_frame_v091() -> void:
	if not placement_commit_queued_v091:
		return
	# Headless CI has no presented frame. On Android/Desktop this signal guarantees
	# the newly-created real body has reached the display before bookkeeping starts.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_flush_visible_commit_v091()


func _flush_visible_commit_v091() -> void:
	if not placement_commit_queued_v091 and not placement_commit_pending_v091:
		return
	placement_commit_queued_v091 = false
	placement_commit_pending_v091 = false
	placement_commit_flushing_v091 = true
	placement_fast_context_v091 = true
	var started: int = Time.get_ticks_usec()
	super._commit_state()
	last_deferred_commit_ms_v091 = float(Time.get_ticks_usec() - started) / 1000.0
	placement_fast_context_v091 = false
	placement_commit_flushing_v091 = false
	print("PLACEMENT_091_MS visible=%.2f finalize=%.2f capture=%.2f auto=%.2f graph=%.2f ui=%.2f graph_skips=%d bodies=%d" % [
		last_visible_dispatch_ms_v091,
		last_deferred_commit_ms_v091,
		profile_capture_ms_v091,
		profile_autoconnect_ms_v091,
		profile_graph_ms_v091,
		profile_ui_ms_v091,
		profile_graph_skips_v091,
		bodies.size(),
	])


# Intercept only the commit invoked from a placement. The actual scene mutation
# has already happened, so returning here lets Godot present it immediately.
func _commit_state() -> void:
	if placement_fast_context_v091 and not placement_commit_flushing_v091:
		placement_commit_pending_v091 = true
		return
	super._commit_state()


func _extend_socket(connector: RigidBody3D, slot: int) -> void:
	_begin_visible_placement_v091()
	super._extend_socket(connector, slot)
	_end_visible_placement_v091()


func _attach_connector_to_rod_end(rod: RigidBody3D, sign_value: int) -> void:
	_begin_visible_placement_v091()
	super._attach_connector_to_rod_end(rod, sign_value)
	_end_visible_placement_v091()


func _insert_axle(connector: RigidBody3D) -> void:
	_begin_visible_placement_v091()
	super._insert_axle(connector)
	_end_visible_placement_v091()


func _place_connector_on_rod_as_axle(rod: RigidBody3D, hit_pos: Vector3) -> void:
	_begin_visible_placement_v091()
	super._place_connector_on_rod_as_axle(rod, hit_pos)
	_end_visible_placement_v091()


func _cross_snap_v015(rod: RigidBody3D, hit_pos: Vector3) -> void:
	_begin_visible_placement_v091()
	super._cross_snap_v015(rod, hit_pos)
	_end_visible_placement_v091()


func _place_o_ring_on_rod(rod: RigidBody3D, hit_pos: Vector3) -> void:
	_begin_visible_placement_v091()
	super._place_o_ring_on_rod(rod, hit_pos)
	_end_visible_placement_v091()


func _finish_new_free_piece_v070(piece: RigidBody3D) -> void:
	_begin_visible_placement_v091()
	super._finish_new_free_piece_v070(piece)
	_end_visible_placement_v091()


# -----------------------------------------------------------------------------
# Incremental graph maintenance for additive CREATE operations.
#
# v0.2's graph rebuild is intentionally conservative: clear everything, walk
# every body/joint, then resync occupancy. During creation we already know the
# exact new connection(s), and no existing connection is removed or moved.
# Append those records as they are tagged and bypass redundant full rebuilds only
# inside this additive transaction. Delete/Disconnect/ATTACH/load/restore and
# SIMULATE continue to use the inherited full rebuild/safety paths.
# -----------------------------------------------------------------------------

func _upsert_incremental_connection_v091(uid: int, joint: Joint3D, kind: String, connector: RigidBody3D, rod: RigidBody3D, slot: int, rod_end: int, host_along: float, ring: RigidBody3D) -> void:
	if not is_instance_valid(joint) or not is_instance_valid(rod):
		return
	var body_a: RigidBody3D = connector if is_instance_valid(connector) else ring
	var body_b: RigidBody3D = rod
	if not is_instance_valid(body_a):
		return
	var record := {
		"uid": uid,
		"kind": kind,
		"joint": joint,
		"a": body_a,
		"b": body_b,
		"connector": connector,
		"rod": rod,
		"ring": ring,
		"slot": slot,
		"rod_end": rod_end,
		"host_along": host_along,
		"rest_gap": float(joint.get_meta("rest_gap_v020", 0.0)),
		"rest_align": float(joint.get_meta("rest_align_v020", 1.0)),
		"rest_perp": float(joint.get_meta("rest_perp_v020", 0.0)),
		"rest_plane": float(joint.get_meta("rest_plane_v020", 0.0)),
	}
	for i in range(connections_v020.size()):
		var existing := connections_v020[i] as Dictionary
		if int(existing.get("uid", -1)) == uid or existing.get("joint") == joint:
			connections_v020[i] = record
			return
	connections_v020.append(record)


func _tag_connection_v020(joint: Joint3D, kind: String, connector: RigidBody3D, rod: RigidBody3D, slot: int = -1, rod_end: int = 0, host_along: float = 0.0, ring: RigidBody3D = null, primary: bool = false) -> int:
	var uid: int = super._tag_connection_v020(joint, kind, connector, rod, slot, rod_end, host_along, ring, primary)
	if placement_fast_context_v091 and not rebuilding_graph_v020:
		_upsert_incremental_connection_v091(uid, joint, kind, connector, rod, slot, rod_end, host_along, ring)
	return uid


func _rebuild_connection_graph_v020(sync_occupancy: bool = true) -> void:
	if placement_fast_context_v091 and not rebuilding_graph_v020:
		profile_graph_skips_v091 += 1
		return
	var started: int = Time.get_ticks_usec()
	super._rebuild_connection_graph_v020(sync_occupancy)
	profile_graph_ms_v091 += float(Time.get_ticks_usec() - started) / 1000.0


# The current autofuse cache only needs transform/type information. CREATE does
# not move existing bodies, so update the newly selected body instead of rescanning
# every body after an additive placement commit.
func _snapshot_autofuse_bodies_v086() -> void:
	if placement_fast_context_v091:
		if is_instance_valid(selected_piece):
			var kind: String = str(selected_piece.get_meta("kind", ""))
			if kind == "rod" or kind == "connector":
				autofuse_body_cache_v086[selected_piece.get_instance_id()] = selected_piece.global_transform
		return
	super._snapshot_autofuse_bodies_v086()


# v0.5.15 rebuilt the full connection graph merely to pick a visible connector
# jaw. Picking only needs socket geometry + the connector's already-maintained
# occupancy metadata, so remove that unrelated pre-placement scan entirely.
func _pick_socket_on_connector_v070(connector: RigidBody3D, screen_pos: Vector2, max_distance: float = SOCKET_JAW_PICK_RADIUS_V070, free_only: bool = false, source: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(connector):
		return {}
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return {}
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	var best: Dictionary = {}
	var best_distance: float = max_distance
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		if free_only and occupied.has(slot):
			continue
		var world_dir: Vector3 = (connector.global_transform.basis * _slot_dir(slot)).normalized()
		var world_a: Vector3 = connector.global_position + world_dir * SOCKET_JAW_INNER_V070
		var world_b: Vector3 = connector.global_position + world_dir * SOCKET_JAW_OUTER_V070
		var distance: float = _screen_segment_distance_v070(screen_pos, world_a, world_b)
		if distance > best_distance:
			continue
		var socket: Dictionary = _socket_world_v020(connector, slot)
		var candidate := {"type": "socket", "body": connector, "slot": slot, "point": socket.get("point", connector.global_position)}
		if not source.is_empty() and not _attach_target_is_available_v040(source, candidate):
			continue
		best_distance = distance
		best = candidate
		best["pick_distance_v070"] = distance
	return best


# Free-part placement historically rebuilt the entire Parts card grid even while
# the Parts dialog was closed. The live counts are derived from bodies whenever
# the dialog opens, so a closed browser needs no work on the tap path.
func _refresh_parts_browser_v050() -> void:
	if placement_fast_context_v091 and (parts_panel_v050 == null or not parts_panel_v050.visible):
		return
	super._refresh_parts_browser_v050()


# Phase timers let the regression catch a future accidental scan without adding
# user-facing profiling UI.
func _capture_state() -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var snapshot: Dictionary = super._capture_state()
	if placement_fast_context_v091:
		profile_capture_ms_v091 += float(Time.get_ticks_usec() - started) / 1000.0
	return snapshot


func _auto_connect_all_v020() -> int:
	var started: int = Time.get_ticks_usec()
	var total: int = super._auto_connect_all_v020()
	if placement_fast_context_v091:
		profile_autoconnect_ms_v091 += float(Time.get_ticks_usec() - started) / 1000.0
	return total


func _update_ui() -> void:
	var started: int = Time.get_ticks_usec()
	super._update_ui()
	if placement_fast_context_v091:
		profile_ui_ms_v091 += float(Time.get_ticks_usec() - started) / 1000.0


# -----------------------------------------------------------------------------
# Persist/update metadata on the actual running version.
# -----------------------------------------------------------------------------

func _save_bundle_v050(name_value: String) -> Dictionary:
	var bundle: Dictionary = super._save_bundle_v050(name_value)
	bundle["app_version"] = VERSION_091
	return bundle


func _autosave_bundle_v089() -> Dictionary:
	var bundle: Dictionary = super._autosave_bundle_v089()
	bundle["app_version"] = VERSION_091
	return bundle


func _reconcile_update_version_v089(latest: String) -> void:
	var clean: String = latest.strip_edges().trim_prefix("v")
	if clean.is_empty():
		return
	if _compare_versions_v021(clean, VERSION_091) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		pending_apk_uri_v021 = null
		waiting_unknown_sources_permission_v021 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_091)
		if update_button_v021 != null:
			update_button_v021.disabled = false
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_091, clean])
		if update_button_v021 != null and not update_available_url_v021.is_empty():
			update_button_v021.text = "Update to v%s" % clean
