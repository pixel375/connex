extends "res://scripts/main_v038.gd"

const VERSION_039 := "0.3.9"

var deselect_piece_button_v039: Button


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_039)
	_status("Deselect is available on the left and by tapping empty workspace. With nothing selected, the bottom palette chooses the NEXT part; O-Ring Stop is selectable from Conn.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_039, text]


# -----------------------------------------------------------------------------
# Selection UX
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	if mode_panel_v032 == null or mode_panel_v032.get_child_count() == 0:
		return
	var mode_box: VBoxContainer = mode_panel_v032.get_child(0) as VBoxContainer
	if mode_box == null:
		return
	deselect_piece_button_v039 = _ui_button("Deselect Piece", _deselect_piece_v039)
	deselect_piece_button_v039.custom_minimum_size.y = 50.0
	mode_box.add_child(deselect_piece_button_v039)
	if delete_button_v032 != null:
		mode_box.move_child(deselect_piece_button_v039, delete_button_v032.get_index() + 1)
	_update_ui()


func _deselect_piece_v039(report: bool = true) -> void:
	if simulating:
		if report:
			_status("Return to BUILD before changing selection")
		return
	var had_selection: bool = is_instance_valid(selected_piece)
	select_armed_v020 = false
	_deselect_attach_point_v032(false)
	_cancel_editor_tools_v030(false)
	_set_selected(null)
	_refresh_selection_highlight()
	_refresh_editor_overlay_v030()
	_refresh_attach_points_v032()
	_update_ui()
	if report:
		if had_selection:
			_status("Selection cleared — bottom Rod / Conn choices now set the NEXT part. O-Ring Stop is available in Conn.")
		else:
			_status("Nothing selected — bottom Rod / Conn choices set the NEXT part. O-Ring Stop is available in Conn.")


func _tap_has_world_target_v039(screen_pos: Vector2) -> bool:
	# Attachment points may sit slightly outside a physical collision shape, so
	# treat a visible ATTACH handle as a real target before falling back to a
	# piece raycast.
	if editor_mode_v032 == EDITOR_ATTACH_032:
		var candidates: Array = _all_attach_points_v032()
		var point: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, POINT_PICK_RADIUS_032)
		if not point.is_empty():
			return true
	elif editor_mode_v032 == EDITOR_ROTATE_032 and is_instance_valid(selected_piece):
		# A ring click/drag should never be interpreted as an empty-workspace tap.
		if not _pick_gizmo_axis_v030(screen_pos).is_empty():
			return true
	return not _raycast_piece(screen_pos).is_empty()


func _handle_tap(screen_pos: Vector2) -> void:
	if simulating or help_panel.visible or options_panel.visible:
		super._handle_tap(screen_pos)
		return
	if not _tap_has_world_target_v039(screen_pos):
		_deselect_piece_v039(true)
		return
	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# Bottom palette behavior
#
# Existing behavior is intentionally retained while a piece is selected: the
# matching Rod/Conn arrows may edit that selected piece when the connection graph
# allows it. Once selection is cleared, the palette is purely a future-piece
# chooser. This also exposes the special O-Ring entry, which cannot be converted
# into from an already-mounted normal connector.
# -----------------------------------------------------------------------------

func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	if not is_instance_valid(selected_piece):
		_cancel_editor_tools_v030(false)
		_deselect_attach_point_v032(false)
		selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
		_update_ui()
		_refresh_editor_overlay_v030()
		_refresh_attach_points_v032()
		var next_name: String = str(connector_defs[selected_connector_type].get("name", "Connector"))
		if selected_connector_type == o_ring_index:
			_status("Next connector: O-Ring Stop — in CREATE, tap a rod already used as an axle to place it.")
		else:
			_status("Next connector: %s" % next_name)
		return
	super._change_connector_type(delta)


func _update_ui() -> void:
	super._update_ui()
	var nothing_selected: bool = not is_instance_valid(selected_piece)
	if deselect_piece_button_v039 != null:
		deselect_piece_button_v039.disabled = simulating or nothing_selected
	if nothing_selected:
		if rod_label != null and selected_rod_type >= 0 and selected_rod_type < rod_defs.size():
			rod_label.text = "NEXT • %s" % str(rod_defs[selected_rod_type].get("name", "Rod"))
		if connector_label != null and selected_connector_type >= 0 and selected_connector_type < connector_defs.size():
			connector_label.text = "NEXT • %s" % str(connector_defs[selected_connector_type].get("name", "Connector"))
		if mode_hint_v032 != null:
			mode_hint_v032.text = "No piece selected • bottom palette chooses the next part"


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nSELECTION: newest pieces are still selected automatically. Press Deselect Piece on the left, or tap empty workspace, to clear selection. With nothing selected, the bottom Rod / Conn arrows never modify an existing piece — they choose what will be created next.\n\nO-RING STOP: O-Ring Stop is a real entry in the bottom Conn list. Deselect first, cycle Conn until NEXT • O-Ring Stop is shown, choose/create AXLE geometry, then tap a rod already used as an axle to place the stop.\n\nROTATE: X/Y/Z is a fixed-world transform gizmo. It rotates the selected connected island rigidly and snaps to exact 45° steps. Roll remains mount-relative.\n\nATTACH: SOCKET uses rod ends ↔ sockets. AXLE uses hub/O-Ring ↔ rod shaft. CROSS uses side socket ↔ rod shaft. Deselect Point clears only an ATTACH source; Deselect Piece clears the actual piece selection.\n\nPHYSICS: disconnected constructions collide with each other and the ground; rigid fixed components suppress internal self-collision.\n\nCamera: one finger orbit, two fingers pan/zoom." % VERSION_039


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var release: Dictionary = parsed as Dictionary
	var latest: String = str(release.get("tag_name", "")).trim_prefix("v")
	if latest.is_empty():
		return
	if _compare_versions_v021(latest, VERSION_039) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_039)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_039, latest])
