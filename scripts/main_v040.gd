extends "res://scripts/main_v039.gd"

const VERSION_040 := "0.3.10"
const O_RING_INNER_RADIUS_V040 := 0.245
const ATTACH_PICK_RADIUS_V040 := 72.0
const ATTACH_BODY_FALLBACK_RADIUS_V040 := 260.0


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_040)
	_status("O-Rings now fit tighter and place on any rod as axle-style stops. ROTATE/ATTACH misses no longer clear piece selection, and ATTACH target picking is more forgiving.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_040, text]


# -----------------------------------------------------------------------------
# O-Ring Stop
#
# O-Ring is a special axle-style part, not a normal connector topology. It can
# be placed on any existing rod regardless of whether that rod was originally
# created by SOCKET / AXLE / CROSS and regardless of the current create mode.
# -----------------------------------------------------------------------------

func _make_o_ring_body(transform: Transform3D) -> RigidBody3D:
	var ring: RigidBody3D = super._make_o_ring_body(transform)
	if not is_instance_valid(ring):
		return ring

	# Tighten the visible center hole while retaining the compact outer diameter.
	for child_value in ring.get_children():
		var visual: MeshInstance3D = child_value as MeshInstance3D
		if visual == null or not (visual.mesh is TorusMesh):
			continue
		var torus: TorusMesh = visual.mesh as TorusMesh
		torus.inner_radius = O_RING_INNER_RADIUS_V040

	# Match the v0.3.8 construction collision policy for newly created rings too.
	ring.collision_layer = 2
	ring.collision_mask = 3
	return ring


func _place_o_ring_on_rod(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod":
		_status("O-Ring Stop — tap any rod")
		return

	var axis: Vector3 = _rod_axis_v020(rod)
	if axis.length_squared() < 0.5:
		axis = (rod.global_transform.basis * Vector3.UP).normalized()
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.40)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = _basis_for_axle_v020(axis)
	var ring: RigidBody3D = _make_o_ring_body(Transform3D(basis, center))
	var ring_joint: Generic6DOFJoint3D = _make_fixed_joint(rod, ring, center)
	ring_joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_set_selected(ring)
	_commit_state()
	_refresh_selection_highlight()
	_update_ui()
	_status("O-Ring Stop placed on rod as an axle-style stop — SOCKET / AXLE / CROSS selection was ignored")


# -----------------------------------------------------------------------------
# Piece selection vs editor gestures
#
# Empty-space deselection remains useful in CREATE. In ROTATE and ATTACH, however,
# a near-miss on a ring/port must not turn into a destructive selection change.
# Those modes already have explicit Select / Deselect controls.
# -----------------------------------------------------------------------------

func _handle_tap(screen_pos: Vector2) -> void:
	if simulating or help_panel.visible or options_panel.visible:
		super._handle_tap(screen_pos)
		return

	# O-Ring is hard-wired to axle-style placement semantics. The current bottom
	# SOCKET / AXLE / CROSS mode is deliberately ignored while it is the next part.
	if editor_mode_v032 == EDITOR_CREATE_032 and selected_connector_type == o_ring_index:
		var hit: Dictionary = _raycast_piece(screen_pos)
		if hit.is_empty():
			if is_instance_valid(selected_piece):
				_deselect_piece_v039(true)
			else:
				_status("O-Ring Stop selected — tap any existing rod")
			return
		var body: RigidBody3D = hit.get("collider") as RigidBody3D
		if is_instance_valid(body) and str(body.get_meta("kind", "")) == "rod":
			_place_o_ring_on_rod(body, hit.get("position", body.global_position) as Vector3)
		else:
			_status("O-Ring Stop ignores SOCKET / AXLE / CROSS — tap any existing rod")
		return

	# ATTACH owns every world tap while active. Missing a small marker keeps both
	# piece selection and the current attachment source intact.
	if editor_mode_v032 == EDITOR_ATTACH_032:
		_handle_attach_point_tap_v032(screen_pos)
		return

	# ROTATE near-misses no longer fall through to v0.3.9 empty-space deselection.
	if editor_mode_v032 == EDITOR_ROTATE_032 and not _tap_has_world_target_v039(screen_pos):
		_status("ROTATE mode — selection kept. Drag a gizmo ring, or use Select / Deselect Piece explicitly.")
		return

	super._handle_tap(screen_pos)


# -----------------------------------------------------------------------------
# More reliable ATTACH point selection
#
# The older picker chose the nearest projected socket even when that socket was
# occupied. On dense connectors this made a valid-looking second tap fail often.
# v0.3.10 first considers FREE (or same-record) compatible targets, enlarges the
# touch radius, then falls back to the physical connector/rod body that was hit.
# -----------------------------------------------------------------------------

func _attach_target_is_available_v040(source: Dictionary, candidate: Dictionary) -> bool:
	var source_body: RigidBody3D = source.get("body") as RigidBody3D
	var candidate_body: RigidBody3D = candidate.get("body") as RigidBody3D
	if not is_instance_valid(source_body) or not is_instance_valid(candidate_body) or source_body == candidate_body:
		return false
	var candidate_record: Dictionary = _connection_record_for_point_v032(candidate)
	if candidate_record.is_empty():
		return true
	var source_record: Dictionary = _connection_record_for_point_v032(source)
	return _same_record_v035(source_record, candidate_record)


func _eligible_discrete_targets_v040(source: Dictionary) -> Array:
	var result: Array = []
	var expected: Array = _expected_target_types_v035(str(source.get("type", "")))
	if expected.is_empty() or "rod_body" in expected:
		return result
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		if not (str(point.get("type", "")) in expected):
			continue
		if _attach_target_is_available_v040(source, point):
			result.append(point)
	return result


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	var candidates: Array = _all_attach_points_v032()
	var discrete: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PICK_RADIUS_V040)
	if not discrete.is_empty() and _allowed_initial_point_v035(discrete):
		return discrete
	if attach_mode in [1, 2]:
		return _rod_body_from_screen_v035(screen_pos)
	return {}


func _physical_target_fallback_v040(screen_pos: Vector2, source: Dictionary, candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	var hit: Dictionary = _raycast_piece(screen_pos)
	if hit.is_empty():
		return {}
	var hit_body: RigidBody3D = hit.get("collider") as RigidBody3D
	if not is_instance_valid(hit_body):
		return {}
	var on_hit_body: Array = []
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		if candidate.get("body") == hit_body:
			on_hit_body.append(candidate)
	if on_hit_body.is_empty():
		return {}
	return _nearest_projected_candidate_v030(on_hit_body, screen_pos, ATTACH_BODY_FALLBACK_RADIUS_V040)


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	var source_type: String = str(source.get("type", ""))
	var expected: Array = _expected_target_types_v035(source_type)
	if expected.is_empty():
		return {}

	if "rod_body" in expected:
		return _rod_body_from_screen_v035(screen_pos, source.get("body") as RigidBody3D)

	var candidates: Array = _eligible_discrete_targets_v040(source)
	var direct: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, ATTACH_PICK_RADIUS_V040)
	if not direct.is_empty():
		return direct

	# If the user clearly tapped the physical counterpart piece but missed its
	# small projected port marker, choose the nearest FREE compatible port on that
	# exact piece. This is especially important on crowded 5/8-way connectors.
	return _physical_target_fallback_v040(screen_pos, source, candidates)


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	if simulating:
		return

	if not attach_point_selected_v032.is_empty() and _selected_point_hit_v035(screen_pos):
		_deselect_attach_point_v032(false)
		_status("Attachment source deselected")
		return

	if attach_point_selected_v032.is_empty():
		var source: Dictionary = _pick_initial_attach_point_v035(screen_pos)
		if source.is_empty():
			match attach_mode:
				0:
					_status("SOCKET: tap a rod END or connector SOCKET")
				1:
					_status("AXLE: tap a connector HUB / O-Ring or the exact place on a rod shaft")
				2:
					_status("CROSS: tap a connector SOCKET or the exact place on a rod shaft")
			return
		attach_point_selected_v032 = source.duplicate(true)
		_refresh_attach_points_v032()
		_status("Source selected: %s. Tap a compatible target; the source stays selected until success or explicit deselect." % _point_display_v032(source))
		return

	var source_selected: Dictionary = attach_point_selected_v032
	var target: Dictionary = _pick_attach_target_v035(screen_pos, source_selected)
	if target.is_empty():
		var expected: Array = _expected_target_types_v035(str(source_selected.get("type", "")))
		_status("Source stays selected — no free compatible %s found at that tap" % ", ".join(expected))
		_refresh_attach_points_v032()
		return

	var source: Dictionary = source_selected
	if str(source.get("type", "")) == "rod_body" and str(target.get("type", "")) == "o_ring":
		var swap_value: Dictionary = source
		source = target
		target = swap_value

	if _pair_mode_v032(source, target) < 0:
		_status("Those points are not compatible in %s mode; source remains selected" % ["SOCKET", "AXLE", "CROSS"][attach_mode])
		_refresh_attach_points_v032()
		return
	if _connect_points_v035(source, target):
		attach_point_selected_v032 = {}
		_refresh_attach_points_v032()
	else:
		# A failed geometry/topology validation must never silently replace or clear
		# the source. The user can immediately try a different target.
		attach_point_selected_v032 = source_selected
		_refresh_attach_points_v032()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nO-RING STOP: O-Ring is in Conn, has a tighter center hole, and can be placed on ANY existing rod. While O-Ring is the next connector, CREATE always treats it as an axle-style stop and ignores the SOCKET / AXLE / CROSS mode button.\n\nSELECTION: Deselect Piece remains on the left. Empty workspace can deselect in CREATE. ROTATE and ATTACH protect the current piece from accidental empty-tap deselection so missed gizmo/port taps do not destroy your working selection.\n\nATTACH: after the first point is selected, it stays selected until a connection succeeds, the same point is tapped, or Deselect Point is pressed. Compatible free targets receive a much larger touch radius. If you tap the physical body of a connector/rod but miss the small port marker, Connex falls back to the nearest free compatible port on that exact piece. Occupied neighboring sockets are not preferred over a free socket.\n\nROTATE: X/Y/Z remains a fixed-world 45° gizmo over the entire connected island; Roll remains mount-relative.\n\nPHYSICS: disconnected constructions collide with each other and the ground; rigid fixed components suppress internal self-collision.\n\nCamera: one finger orbit, two fingers pan/zoom." % VERSION_040


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
	if _compare_versions_v021(latest, VERSION_040) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_040)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_040, latest])
