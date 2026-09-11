extends "res://scripts/main_v087.gd"

const VERSION_088 := "0.5.25"
const LEFT_MODE_HEIGHT_088 := 58.0
const LEFT_FREE_HEIGHT_088 := 43.0
const LEFT_UTILITY_HEIGHT_088 := 38.0
const LEFT_PANEL_BOTTOM_088 := 548.0


func _ready() -> void:
	super._ready()
	_resize_left_toolbar_v083()
	_sync_deselect_button_v083()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_088)
	_status("v0.5.25 ready — normal left controls and bounded edit-local auto-connect are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_088, text]


# -----------------------------------------------------------------------------
# Left toolbar: keep the v0.5.24 full-width New Rod / New Connector layout, but
# return every left-side button to the compact pre-v0.5.24 heights.
# -----------------------------------------------------------------------------

func _stack_free_create_buttons_v083() -> void:
	super._stack_free_create_buttons_v083()
	if new_free_rod_button_v070 != null:
		new_free_rod_button_v070.custom_minimum_size.y = LEFT_FREE_HEIGHT_088
	if new_free_connector_button_v070 != null:
		new_free_connector_button_v070.custom_minimum_size.y = LEFT_FREE_HEIGHT_088


func _resize_left_toolbar_v083() -> void:
	for button_value in [create_button_v032, rotate_button_v032, move_mode_button_v042, attach_button_v032]:
		var button := button_value as Button
		if button != null:
			button.custom_minimum_size.y = LEFT_MODE_HEIGHT_088
	if new_free_rod_button_v070 != null:
		new_free_rod_button_v070.custom_minimum_size.y = LEFT_FREE_HEIGHT_088
	if new_free_connector_button_v070 != null:
		new_free_connector_button_v070.custom_minimum_size.y = LEFT_FREE_HEIGHT_088
	if disconnect_button_v042 != null:
		disconnect_button_v042.custom_minimum_size.y = LEFT_UTILITY_HEIGHT_088
	if deselect_piece_button_v039 != null:
		deselect_piece_button_v039.custom_minimum_size.y = LEFT_UTILITY_HEIGHT_088
	if mode_panel_v032 != null:
		mode_panel_v032.offset_right = 198.0
		mode_panel_v032.offset_bottom = LEFT_PANEL_BOTTOM_088


# -----------------------------------------------------------------------------
# Performance hotfix.
#
# v0.5.24 tried to discover edited pieces by rebuilding a Dictionary state for
# every body before each commit, then allowed a 32-pass local matcher which could
# rebuild the connection graph repeatedly. On Android that bookkeeping can cost
# more than the old whole-build path even on small constructions.
#
# v0.5.25 makes the edit target explicit: normal CREATE/ATTACH/palette commits
# consider only the currently edited piece. TRANSFORM considers only members of
# the selected fixed component whose transforms actually changed. Full matching
# remains the safety path for removals and before SIMULATE.
# -----------------------------------------------------------------------------

# Keep only the transform snapshot required to detect moved members during a
# TRANSFORM edit. Avoid allocating nested state dictionaries for every piece.
func _snapshot_autofuse_bodies_v086() -> void:
	autofuse_body_cache_v086.clear()
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			autofuse_body_cache_v086[body.get_instance_id()] = body.global_transform


func _autofuse_body_changed_v086(body: RigidBody3D) -> bool:
	if not is_instance_valid(body):
		return false
	var key: int = body.get_instance_id()
	if not autofuse_body_cache_v086.has(key):
		return true
	var old_transform: Transform3D = autofuse_body_cache_v086.get(key, body.global_transform) as Transform3D
	return not old_transform.is_equal_approx(body.global_transform)


func _autofuse_removed_since_snapshot_v088() -> bool:
	if autofuse_body_cache_v086.is_empty():
		return false
	var current_ids: Dictionary = {}
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			current_ids[body.get_instance_id()] = true
	for cached_id in autofuse_body_cache_v086.keys():
		if not current_ids.has(cached_id):
			return true
	return false


func _append_autofuse_candidate_v088(result: Array, seen: Dictionary, body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return
	var kind: String = str(body.get_meta("kind", ""))
	if kind != "rod" and kind != "connector":
		return
	var key: int = body.get_instance_id()
	if seen.has(key):
		return
	seen[key] = true
	result.append(body)


func _autofuse_candidates_v088() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	if not is_instance_valid(selected_piece):
		return result

	# The actively edited/created part is always the primary candidate. This also
	# preserves the important far-end auto-connect behavior for newly created rods.
	_append_autofuse_candidate_v088(result, seen, selected_piece)

	# Unified TRANSFORM can move a rigid fixed component. Only in that mode do we
	# inspect the component, and only bodies whose transforms changed are added.
	if editor_mode_v032 == EDITOR_ROTATE_032:
		for body_value in _fixed_component_v020(selected_piece):
			var body := body_value as RigidBody3D
			if body == selected_piece or not is_instance_valid(body):
				continue
			if _autofuse_body_changed_v086(body):
				_append_autofuse_candidate_v088(result, seen, body)
	return result


func _rebuild_graph_after_match_v088() -> void:
	_rebuild_connection_graph_v020()


func _auto_connect_targeted_v088(changed: Array) -> int:
	if changed.is_empty():
		return 0
	_rebuild_connection_graph_v020()
	var total: int = 0
	var endpoint_matches: int = 0

	# SOCKET first: exactly the same priority as the inherited matcher.
	for body_value in changed:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body) or str(body.get_meta("kind", "")) != "rod":
			continue
		if _auto_connect_end_v020(body, -1):
			endpoint_matches += 1
		if _auto_connect_end_v020(body, 1):
			endpoint_matches += 1
	if endpoint_matches > 0:
		total += endpoint_matches
		_rebuild_graph_after_match_v088()

	# A moved/created connector can meet an unchanged free rod end. Match only as
	# many times as the connector actually has sockets; no empty 32-pass loop.
	for body_value in changed:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		var def_index: int = int(connector.get_meta("connector_type", -1))
		var slot_limit: int = 1
		if def_index >= 0 and def_index < connector_defs.size():
			slot_limit = maxi(1, (connector_defs[def_index].get("slots", []) as Array).size())
		for _match_index in range(slot_limit):
			if not _auto_connect_one_connector_end_v086(connector):
				break
			total += 1
			_rebuild_graph_after_match_v088()

	# CROSS comes only after free end/socket matches. Again, the loop is bounded
	# by real candidate capacity rather than a fixed number of whole scans.
	for body_value in changed:
		var connector := body_value as RigidBody3D
		if not is_instance_valid(connector) or str(connector.get_meta("kind", "")) != "connector":
			continue
		var def_index: int = int(connector.get_meta("connector_type", -1))
		var slot_limit: int = 1
		if def_index >= 0 and def_index < connector_defs.size():
			slot_limit = maxi(1, (connector_defs[def_index].get("slots", []) as Array).size())
		for _match_index in range(slot_limit):
			if not _auto_connect_one_connector_cross_v086(connector):
				break
			total += 1
			_rebuild_graph_after_match_v088()

	for body_value in changed:
		var rod := body_value as RigidBody3D
		if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
			continue
		# A rod can legitimately cross several connectors along its length. Each
		# successful match removes one candidate; stop immediately when none remain.
		for _match_index in range(maxi(1, bodies.size())):
			if not _auto_connect_one_rod_cross_v086(rod):
				break
			total += 1
			_rebuild_graph_after_match_v088()

	return total


func _run_full_autofuse_v088() -> int:
	autofuse_force_full_v086 = true
	var total: int = super._auto_connect_all_v020()
	autofuse_force_full_v086 = false
	return total


func _auto_connect_all_v020() -> int:
	if suppress_autofuse_v087 or restoring_v020 or restoring_state:
		return 0

	# v0.5.24 already sets this before SIMULATE. Keep that exact correctness gate.
	if autofuse_force_full_v086:
		return super._auto_connect_all_v020()

	# Deletion/removal may free a socket on a body that was otherwise unchanged,
	# so removals still receive the inherited whole-build safety pass.
	if _autofuse_removed_since_snapshot_v088():
		return _run_full_autofuse_v088()

	var candidates: Array = _autofuse_candidates_v088()
	if candidates.is_empty():
		return 0
	var total: int = _auto_connect_targeted_v088(candidates)
	# Calls outside the normal history commit do not get the post-commit snapshot.
	if not committing_v020:
		_snapshot_autofuse_bodies_v086()
	return total


# The Parts inventory still derives from authoritative live bodies, but when the
# panel is already open an edit only needs to update labels/counts. Do not destroy
# and recreate every card after each commit.
func _refresh_parts_usage_if_open_v086() -> void:
	if parts_panel_v050 == null or not parts_panel_v050.visible:
		return
	var usage: Dictionary = _parts_usage_counts_v086()
	var counts: Array = (usage.get("rods", []) as Array) if parts_tab_v050 == 0 else (usage.get("connectors", []) as Array)
	var defs: Array = rod_defs if parts_tab_v050 == 0 else connector_defs
	if part_card_buttons_v050.size() != defs.size():
		_refresh_parts_browser_v050()
		return
	if parts_title_v050 != null:
		parts_title_v050.text = "PARTS BROWSER • %d IN BUILD" % int(usage.get("total", 0))
	for i in range(defs.size()):
		var button := part_card_buttons_v050[i] as Button
		if button == null:
			continue
		var definition: Dictionary = defs[i] as Dictionary
		var name_value: String = str(definition.get("name", "Part"))
		var detail: String = ""
		if parts_tab_v050 == 0:
			detail = "%.1f mm" % float(definition.get("actual_mm", 0.0))
		else:
			var special: String = str(definition.get("special", ""))
			detail = "Axle stop" if special == "o_ring" else "%d connection points" % (definition.get("slots", []) as Array).size()
		var used: int = int(counts[i]) if i < counts.size() else 0
		button.text = "%s\n%s\nUsed: %d" % [name_value, detail, used]
