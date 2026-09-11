extends "res://scripts/main_v075.gd"

const VERSION_076 := "0.5.20"

var attach_pose_cache_v076: Dictionary = {}


func _ready() -> void:
	super._ready()
	attach_pose_cache_v076.clear()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_076)
	_status("v0.5.20 ready — ATTACH selection, O-Ring rod creation, live attachment markers and multi-rod reconnect are fixed.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_076, text]


# -----------------------------------------------------------------------------
# ATTACH piece selection + O-Ring create behavior.
#
# ATTACH owns normal taps, so the inherited one-shot Select action never reached
# the piece picker. Honor Select before the attachment-point state machine. Also
# keep SOCKET rod creation authoritative even while O-Ring Stop is the current
# connector-palette choice; tapping a rod still follows the normal O-Ring path.
# -----------------------------------------------------------------------------

func _select_piece_in_attach_v076(screen_pos: Vector2) -> bool:
	if editor_mode_v032 != EDITOR_ATTACH_032 or not select_armed_v020:
		return false
	var hit: Dictionary = _raycast_piece(screen_pos)
	if hit.is_empty():
		_status("Select armed — tap one piece. Attachment points are ignored until a piece is selected.")
		return true
	var body := hit.get("collider") as RigidBody3D
	if not is_instance_valid(body):
		_status("Select armed — tap one piece")
		return true
	_deselect_attach_point_v032(false)
	_set_selected(body)
	attach_pose_cache_v076.clear()
	_invalidate_attach_overlay_v075()
	_status("Selected %s for ATTACH" % _piece_display_name(body))
	return true


func _handle_tap(screen_pos: Vector2) -> void:
	if _any_modal_open_v054():
		return
	if _select_piece_in_attach_v076(screen_pos):
		return
	if editor_mode_v032 == EDITOR_CREATE_032 and attach_mode == 0 and selected_connector_type == o_ring_index:
		# O-Ring is a connector-palette item, but it must never stop an ordinary
		# free connector socket from creating the selected rod.
		if _try_socket_create_tap_v054(screen_pos):
			return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# Live ATTACH marker tracking.
#
# v0.5.19 invalidated markers after snapshot restore/Undo/Redo, but Restore and
# other direct transform paths can move pieces without touching those caches.
# Track actual build transforms while ATTACH is visible and rebuild only when a
# piece really moved/appeared/disappeared.
# -----------------------------------------------------------------------------

func _attach_pose_snapshot_v076() -> Dictionary:
	var result: Dictionary = {}
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			result[body.get_instance_id()] = body.global_transform
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if is_instance_valid(ring):
			result[ring.get_instance_id()] = ring.global_transform
	return result


func _sync_attach_overlay_pose_v076(force_refresh: bool = false) -> bool:
	var current: Dictionary = _attach_pose_snapshot_v076()
	var changed: bool = force_refresh or current.size() != attach_pose_cache_v076.size()
	if not changed:
		for id_value in current.keys():
			if not attach_pose_cache_v076.has(id_value):
				changed = true
				break
			var now_tf: Transform3D = current[id_value] as Transform3D
			var old_tf: Transform3D = attach_pose_cache_v076[id_value] as Transform3D
			if not now_tf.is_equal_approx(old_tf):
				changed = true
				break
	attach_pose_cache_v076 = current
	if changed:
		_invalidate_attach_overlay_v075()
	return changed


func _process(delta: float) -> void:
	super._process(delta)
	if editor_mode_v032 == EDITOR_ATTACH_032 and not simulating and not _any_modal_open_v054():
		_sync_attach_overlay_pose_v076(false)
	else:
		attach_pose_cache_v076.clear()


func _reset_pose() -> void:
	super._reset_pose()
	attach_pose_cache_v076.clear()
	_sync_attach_overlay_pose_v076(true)
	call_deferred("_invalidate_attach_overlay_v075")


func _toggle_simulation() -> void:
	super._toggle_simulation()
	attach_pose_cache_v076.clear()
	if not simulating:
		_sync_attach_overlay_pose_v076(true)
		call_deferred("_invalidate_attach_overlay_v075")


# -----------------------------------------------------------------------------
# Explicit SOCKET reconnect releases the whole connector from Detach quarantine.
#
# Disconnect Selected intentionally blocks every former pair so touching pieces
# do not instantly re-fuse. Previously an explicit reconnect cleared only the one
# pair clicked. For a connector that had two rods, the second pair therefore
# stayed blocked forever. Once the user explicitly SOCKET-reconnects a connector,
# release that connector's old pair blocks before the single commit. The existing
# commit-time auto-connect then restores every other still-aligned free rod/socket
# in the same operation and Undo remains one step.
# -----------------------------------------------------------------------------

func _release_detach_blocks_for_piece_v076(piece: RigidBody3D) -> int:
	if not is_instance_valid(piece):
		return 0
	var uid: int = _ensure_piece_uid_v020(piece)
	var removed: int = 0
	var keys: Array = manual_detach_blocks_v030.keys().duplicate()
	for key_value in keys:
		var key_text: String = str(key_value)
		var pair: PackedStringArray = key_text.split(":")
		if pair.size() != 2:
			continue
		if int(pair[0]) == uid or int(pair[1]) == uid:
			manual_detach_blocks_v030.erase(key_value)
			removed += 1
	return removed


func _connect_points_v035(source: Dictionary, target: Dictionary) -> bool:
	var source_body: RigidBody3D = source.get("body") as RigidBody3D
	var target_body: RigidBody3D = target.get("body") as RigidBody3D
	if not is_instance_valid(source_body) or not is_instance_valid(target_body) or source_body == target_body:
		_status("Connection blocked — choose two different pieces")
		return false

	_rebuild_connection_graph_v020()
	var source_record: Dictionary = _connection_record_for_point_v032(source)
	var target_record: Dictionary = _connection_record_for_point_v032(target)
	var old_record: Dictionary = source_record

	if old_record.is_empty():
		var pair_records: Array = _records_between_bodies_v035(source_body, target_body)
		if pair_records.size() == 1:
			old_record = pair_records[0] as Dictionary
		elif pair_records.size() > 1:
			_status("Connection blocked — these pieces have multiple existing links. Start from the occupied port you want to move.")
			return false

	if not target_record.is_empty() and not _same_record_v035(target_record, old_record):
		_status("Target is already occupied by another connection")
		return false

	if not source_record.is_empty() and _same_record_v035(source_record, target_record):
		var desired_kind: String = "socket" if attach_mode == 0 else ("cross" if attach_mode == 2 else ("o_ring" if str(source.get("type", "")) == "o_ring" or str(target.get("type", "")) == "o_ring" else "axle"))
		if str(source_record.get("kind", "")) == desired_kind:
			_status("Those two attachment points are already connected")
			return false

	var excluded_uid: int = int(old_record.get("uid", -1)) if not old_record.is_empty() else -1
	var source_component: Array = _fixed_component_v020(source_body, excluded_uid)
	if _component_has_piece_v020(source_component, target_body):
		_status("Connection blocked — another rigid path still locks these two pieces together")
		return false

	var snap: Dictionary = _snap_source_component_v030(source, target, source_component)
	if not bool(snap.get("valid", false)):
		_status("Connection blocked — %s" % str(snap.get("reason", "cannot align those points")))
		return false
	var transforms: Dictionary = snap.get("transforms", {}) as Dictionary
	var validation: Dictionary = _validate_transforms_excluding_v032(transforms, excluded_uid)
	if not bool(validation.get("valid", false)):
		_status("Connection blocked — %s" % str(validation.get("reason", "moving that side would break another connection")))
		return false

	if not old_record.is_empty():
		_detach_record_raw_v032(old_record)
	_apply_transforms_raw_v030(transforms)
	_create_explicit_connection_v030(source, target)
	manual_detach_blocks_v030.erase(_pair_key_v030(source_body, target_body))

	var released_blocks: int = 0
	var reattached_connector: RigidBody3D = null
	if attach_mode == 0:
		if str(source_body.get_meta("kind", "")) == "connector":
			reattached_connector = source_body
		elif str(target_body.get_meta("kind", "")) == "connector":
			reattached_connector = target_body
		if is_instance_valid(reattached_connector):
			released_blocks = _release_detach_blocks_for_piece_v076(reattached_connector)

	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	var connector_links_before_commit: int = _connections_for_piece_v020(reattached_connector).size() if is_instance_valid(reattached_connector) else 0
	_commit_state()
	_rebuild_connection_graph_v020()
	var connector_links_after_commit: int = _connections_for_piece_v020(reattached_connector).size() if is_instance_valid(reattached_connector) else connector_links_before_commit
	var auto_restored: int = maxi(0, connector_links_after_commit - connector_links_before_commit)

	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	attach_pose_cache_v076.clear()
	_refresh_selection_highlight()
	_update_ui()
	var mode_name: String = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	var reconnect_note: String = ""
	if released_blocks > 1 and auto_restored > 0:
		reconnect_note = " • %d other aligned connection%s auto-restored" % [auto_restored, "" if auto_restored == 1 else "s"]
	_status("%s %s%s" % [mode_name, "re-attached" if not old_record.is_empty() else "attached", reconnect_note])
	return true
