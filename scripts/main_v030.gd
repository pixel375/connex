extends "res://scripts/main_v021.gd"

const VERSION_030 := "0.3.0"
const GIZMO_STEP_030 := PI / 4.0
const GIZMO_RADIUS_030 := 2.35
const GIZMO_PICK_TOLERANCE_030 := 0.34
const HANDLE_SCREEN_RADIUS_030 := 52.0
const ATTACH_SOCKET_GAP_030 := 0.72
const ATTACH_CROSS_GAP_030 := 0.36
const ATTACH_AXLE_GAP_030 := 0.38

var gizmo_root_v030: Node3D
var gizmo_axes_v030: Dictionary = {}
var gizmo_drag_active_v030: bool = false
var gizmo_drag_axis_v030: Vector3 = Vector3.ZERO
var gizmo_drag_axis_name_v030: String = ""
var gizmo_drag_center_v030: Vector3 = Vector3.ZERO
var gizmo_drag_start_vec_v030: Vector3 = Vector3.ZERO
var gizmo_drag_steps_v030: int = 0
var gizmo_drag_component_v030: Array = []
var gizmo_drag_preview_v030: Dictionary = {}

var ghost_root_v030: Node3D
var ghost_entries_v030: Array = []
var ghost_valid_mat_v030: StandardMaterial3D
var ghost_invalid_mat_v030: StandardMaterial3D

var tool_handle_root_v030: Node3D
var target_handle_root_v030: Node3D
var tool_mode_v030: String = ""
var attach_drag_active_v030: bool = false
var attach_source_v030: Dictionary = {}
var attach_target_v030: Dictionary = {}
var tether_layer_v030: CanvasLayer
var tether_line_v030: Line2D
var current_target_marker_v030: MeshInstance3D

var roll_minus_v030: Button
var roll_plus_v030: Button
var reseat_button_v030: Button
var detach_button_v030: Button
var attach_button_v030: Button
var cancel_tool_button_v030: Button
var topology_label_v030: Label

var auto_connect_context_v030: bool = false
var manual_detach_blocks_v030: Dictionary = {}

var gizmo_x_mat_v030: StandardMaterial3D
var gizmo_y_mat_v030: StandardMaterial3D
var gizmo_z_mat_v030: StandardMaterial3D
var gizmo_disabled_mat_v030: StandardMaterial3D
var handle_current_mat_v030: StandardMaterial3D
var handle_valid_mat_v030: StandardMaterial3D
var handle_invalid_mat_v030: StandardMaterial3D
var handle_detach_mat_v030: StandardMaterial3D


# -----------------------------------------------------------------------------
# Startup / version / deterministic placement
# -----------------------------------------------------------------------------

func _ready() -> void:
	super._ready()
	_build_editor_overlay_v030()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_030)
	_refresh_editor_overlay_v030()
	_status("Select a piece, then use the world-axis gizmo or explicit Re-seat / Detach / Attach tools. Camera angle no longer changes construction axes.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_030, text]


func _stable_perpendicular_v030(axis_value: Vector3) -> Vector3:
	var axis: Vector3 = axis_value.normalized()
	var preferred: Vector3 = Vector3.UP - axis * Vector3.UP.dot(axis)
	if preferred.length_squared() < 0.02:
		preferred = Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	if preferred.length_squared() < 0.02:
		preferred = Vector3.BACK - axis * Vector3.BACK.dot(axis)
	return preferred.normalized()


# v0.2 used the camera to pick a default roll/cross direction. In v0.3 the same
# geometry receives the same initial orientation regardless of viewing angle.
func _preferred_camera_perpendicular_v020(axis: Vector3) -> Vector3:
	return _stable_perpendicular_v030(axis)


func _basis_for_axle_v020(axis: Vector3) -> Basis:
	var target_axis: Vector3 = axis.normalized()
	var base: Basis = Basis(Quaternion(Vector3.UP, target_axis))
	var current_right: Vector3 = (base * Vector3.RIGHT).normalized()
	var preferred_right: Vector3 = _stable_perpendicular_v030(target_axis)
	var angle: float = current_right.signed_angle_to(preferred_right, target_axis)
	return (Basis(target_axis, angle) * base).orthonormalized()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nBUILD: normal taps still place SOCKET / AXLE / CROSS parts. The newest piece stays selected; Select is a one-shot way to choose an older piece.\n\nROTATE: drag the red X, green Y, or blue Z world-axis ring around the selected piece. The ring uses ray/plane geometry, never camera direction, and snaps to exact 45° states. Invalid one-step directions are greyed before you drag. Mounted connectors also keep dedicated Roll around their real rod/axle axis.\n\nRE-SEAT: choose which connector jaw owns an existing socket/cross mount without pretending that connection change is ordinary rotation. Cyan = current jaw, green = valid alternative, gray = blocked.\n\nDETACH: arm the tool, then tap one highlighted connection anchor. The pieces stay where they are and that pair will not silently auto-fuse again until explicitly re-attached.\n\nATTACH: uses the current SOCKET / AXLE / CROSS mode. Arm Attach, drag from a highlighted free handle on the selected piece to a compatible target, then release. The source rigid component snaps only after the candidate geometry validates.\n\nCamera: one finger orbits, two fingers pan/zoom. Options persist between launches. Updates are checked from GitHub Releases." % VERSION_030


func _find_label_v030(node: Node) -> Label:
	for child_value in node.get_children():
		if child_value is Label:
			return child_value as Label
		var nested: Label = _find_label_v030(child_value)
		if nested != null:
			return nested
	return null


# -----------------------------------------------------------------------------
# Updater compatibility — v0.2.1 owns the updater, v0.3 supplies current version.
# -----------------------------------------------------------------------------

func _on_update_request_completed_v021(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	update_check_in_progress_v021 = false
	if update_button_v021 != null:
		update_button_v021.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_update_status_v021("Update check failed (HTTP %d)." % response_code)
		if update_button_v021 != null:
			update_button_v021.text = "Retry Update Check"
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_set_update_status_v021("GitHub returned an unreadable release response.")
		if update_button_v021 != null:
			update_button_v021.text = "Retry Update Check"
		return
	var release: Dictionary = parsed as Dictionary
	var tag: String = str(release.get("tag_name", ""))
	var latest: String = tag.trim_prefix("v")
	if latest.is_empty():
		_set_update_status_v021("Latest release has no version tag.")
		return
	var apk_url: String = ""
	var apk_name: String = ""
	var assets: Array = release.get("assets", []) as Array
	for asset_value in assets:
		var asset: Dictionary = asset_value as Dictionary
		var asset_name: String = str(asset.get("name", ""))
		if asset_name.to_lower().ends_with(".apk"):
			apk_url = str(asset.get("browser_download_url", ""))
			apk_name = asset_name
			break
	if _compare_versions_v021(latest, VERSION_030) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_030)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
		return
	update_available_version_v021 = latest
	update_available_url_v021 = apk_url if not apk_url.is_empty() else UPDATE_REPO_URL_021
	update_available_filename_v021 = apk_name
	if apk_url.is_empty():
		_set_update_status_v021("v%s is available, but its APK asset was not found." % latest)
		if update_button_v021 != null:
			update_button_v021.text = "Open Releases"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_030, latest])
		if update_button_v021 != null:
			update_button_v021.text = "Update to v%s" % latest


# -----------------------------------------------------------------------------
# UI additions. Old camera arrows are hidden; the 3D gizmo is the primary tool.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	if rotation_panel != null:
		rotation_panel.offset_left = -246.0
		rotation_panel.offset_bottom = 590.0
	for old_button in [rot_up_v020, rot_down_v020, rot_left_v020, rot_right_v020, roll_left_v020, roll_right_v020]:
		if old_button != null:
			old_button.visible = false
	if selected_label_v020 != null:
		selected_label_v020.text = "Selected: —"
	if rotation_body != null:
		rotation_body.add_child(_section_label("WORLD XYZ GIZMO • DRAG RINGS • 45° SNAP"))
		var roll_title: Label = _section_label("REAL MOUNT AXIS")
		rotation_body.add_child(roll_title)
		var roll_row: HBoxContainer = HBoxContainer.new()
		roll_row.add_theme_constant_override("separation", 4)
		rotation_body.add_child(roll_row)
		roll_minus_v030 = _ui_button("Roll −45°", func() -> void: _apply_roll_v030(-1))
		roll_plus_v030 = _ui_button("Roll +45°", func() -> void: _apply_roll_v030(1))
		roll_row.add_child(roll_minus_v030)
		roll_row.add_child(roll_plus_v030)
		rotation_body.add_child(_section_label("CONNECTION TOPOLOGY"))
		reseat_button_v030 = _ui_button("Re-seat Mount Socket", _toggle_reseat_v030, true)
		detach_button_v030 = _ui_button("Detach Connection", _toggle_detach_v030)
		attach_button_v030 = _ui_button("Attach / Re-attach", _toggle_attach_v030, true)
		cancel_tool_button_v030 = _ui_button("Cancel Tool", func() -> void: _cancel_editor_tools_v030(true))
		rotation_body.add_child(reseat_button_v030)
		rotation_body.add_child(detach_button_v030)
		rotation_body.add_child(attach_button_v030)
		rotation_body.add_child(cancel_tool_button_v030)
		topology_label_v030 = Label.new()
		topology_label_v030.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		topology_label_v030.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		topology_label_v030.add_theme_font_size_override("font_size", 11)
		topology_label_v030.add_theme_color_override("font_color", Color(0.62, 0.72, 0.80))
		rotation_body.add_child(topology_label_v030)
	if reset_rotation_v020 != null:
		reset_rotation_v020.text = "Reset Placement Rotation"
	_update_ui()


func _update_rotation_buttons_v020() -> void:
	# v0.3 deliberately retires the camera-relative arrow solver.
	for old_button in [rot_up_v020, rot_down_v020, rot_left_v020, rot_right_v020, roll_left_v020, roll_right_v020]:
		if old_button != null:
			old_button.disabled = true
			old_button.visible = false
	if reset_rotation_v020 != null:
		reset_rotation_v020.disabled = simulating or _selected_kind() != "connector"


func _update_ui() -> void:
	super._update_ui()
	if selected_label_v020 != null:
		selected_label_v020.text = "Selected: %s" % (_piece_display_name(selected_piece) if is_instance_valid(selected_piece) else "—")
	var connector_selected: bool = not simulating and _selected_kind() == "connector"
	var roll_minus_preview: Dictionary = _roll_candidate_v030(-1) if connector_selected else {"valid": false}
	var roll_plus_preview: Dictionary = _roll_candidate_v030(1) if connector_selected else {"valid": false}
	if roll_minus_v030 != null:
		roll_minus_v030.disabled = not bool(roll_minus_preview.get("valid", false))
	if roll_plus_v030 != null:
		roll_plus_v030.disabled = not bool(roll_plus_preview.get("valid", false))
	if reseat_button_v030 != null:
		reseat_button_v030.disabled = not _can_reseat_v030()
		reseat_button_v030.text = "RE-SEAT…" if tool_mode_v030 == "reseat" else "Re-seat Mount Socket"
	if detach_button_v030 != null:
		detach_button_v030.disabled = simulating or not is_instance_valid(selected_piece) or _connections_for_piece_v020(selected_piece).is_empty()
		detach_button_v030.text = "DETACH…" if tool_mode_v030 == "detach" else "Detach Connection"
	if attach_button_v030 != null:
		attach_button_v030.disabled = simulating or not _selected_has_attach_source_v030()
		attach_button_v030.text = "ATTACH…" if tool_mode_v030 == "attach" else "Attach / Re-attach"
	if cancel_tool_button_v030 != null:
		cancel_tool_button_v030.disabled = tool_mode_v030.is_empty() and not attach_drag_active_v030
	if topology_label_v030 != null:
		topology_label_v030.text = _topology_hint_v030()
	_refresh_editor_overlay_v030()


func _topology_hint_v030() -> String:
	if tool_mode_v030 == "reseat":
		return "Tap a green socket handle. Cyan is the current mount; gray choices would break existing geometry."
	if tool_mode_v030 == "detach":
		return "Tap an orange connection anchor. Detach leaves both pieces where they are."
	if tool_mode_v030 == "attach":
		return "Drag from a highlighted free handle on the selected piece to a compatible target. Current mode: %s." % ["SOCKET", "AXLE", "CROSS"][attach_mode]
	return "XYZ rings use fixed world axes. Roll preserves the current mount; Re-seat / Detach / Attach explicitly change topology."


# -----------------------------------------------------------------------------
# Overlay materials, gizmo and handle visuals
# -----------------------------------------------------------------------------

func _overlay_material_v030(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.7
	material.no_depth_test = true
	if alpha < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _build_editor_overlay_v030() -> void:
	gizmo_x_mat_v030 = _overlay_material_v030(Color(1.0, 0.18, 0.20))
	gizmo_y_mat_v030 = _overlay_material_v030(Color(0.20, 0.95, 0.34))
	gizmo_z_mat_v030 = _overlay_material_v030(Color(0.18, 0.48, 1.0))
	gizmo_disabled_mat_v030 = _overlay_material_v030(Color(0.34, 0.37, 0.42), 0.70)
	handle_current_mat_v030 = _overlay_material_v030(Color(0.05, 0.90, 1.0))
	handle_valid_mat_v030 = _overlay_material_v030(Color(0.20, 1.0, 0.48))
	handle_invalid_mat_v030 = _overlay_material_v030(Color(0.34, 0.37, 0.42), 0.65)
	handle_detach_mat_v030 = _overlay_material_v030(Color(1.0, 0.55, 0.12))
	ghost_valid_mat_v030 = _overlay_material_v030(Color(0.05, 0.90, 1.0), 0.28)
	ghost_invalid_mat_v030 = _overlay_material_v030(Color(1.0, 0.18, 0.18), 0.28)

	gizmo_root_v030 = Node3D.new()
	gizmo_root_v030.name = "RotationGizmoV030"
	add_child(gizmo_root_v030)
	_build_gizmo_axis_v030("X", Vector3.RIGHT, gizmo_x_mat_v030)
	_build_gizmo_axis_v030("Y", Vector3.UP, gizmo_y_mat_v030)
	_build_gizmo_axis_v030("Z", Vector3.BACK, gizmo_z_mat_v030)

	ghost_root_v030 = Node3D.new()
	ghost_root_v030.name = "RotationGhostV030"
	add_child(ghost_root_v030)

	tool_handle_root_v030 = Node3D.new()
	tool_handle_root_v030.name = "ToolHandlesV030"
	add_child(tool_handle_root_v030)
	target_handle_root_v030 = Node3D.new()
	target_handle_root_v030.name = "AttachTargetsV030"
	add_child(target_handle_root_v030)

	tether_layer_v030 = CanvasLayer.new()
	tether_layer_v030.layer = 8
	add_child(tether_layer_v030)
	tether_line_v030 = Line2D.new()
	tether_line_v030.width = 4.0
	tether_line_v030.default_color = Color(0.08, 0.82, 1.0, 0.95)
	tether_line_v030.visible = false
	tether_layer_v030.add_child(tether_line_v030)
	_refresh_editor_overlay_v030()


func _build_gizmo_axis_v030(name_value: String, axis: Vector3, material: StandardMaterial3D) -> void:
	var root: Node3D = Node3D.new()
	root.name = "Gizmo%s" % name_value
	root.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	gizmo_root_v030.add_child(root)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = GIZMO_RADIUS_030 - 0.075
	torus.outer_radius = GIZMO_RADIUS_030 + 0.075
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = material
	root.add_child(ring)
	var plus_label: Label3D = _gizmo_label_v030("%s+" % name_value, material.albedo_color)
	plus_label.position = Vector3(GIZMO_RADIUS_030 + 0.34, 0.0, 0.0)
	root.add_child(plus_label)
	var minus_label: Label3D = _gizmo_label_v030("%s−" % name_value, material.albedo_color)
	minus_label.position = Vector3(-GIZMO_RADIUS_030 - 0.34, 0.0, 0.0)
	root.add_child(minus_label)
	gizmo_axes_v030[name_value] = {"root": root, "ring": ring, "plus": plus_label, "minus": minus_label, "axis": axis.normalized(), "material": material}


func _gizmo_label_v030(text_value: String, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.font_size = 42
	label.modulate = color
	label.outline_modulate = Color(0.02, 0.02, 0.03, 1.0)
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label


func _make_handle_v030(parent: Node3D, point: Vector3, material: StandardMaterial3D, scale_value: float = 0.22) -> MeshInstance3D:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = scale_value
	sphere.height = scale_value * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	marker.mesh = sphere
	marker.material_override = material
	parent.add_child(marker)
	marker.global_position = point
	return marker


func _clear_children_v030(node: Node) -> void:
	if node == null:
		return
	for child_value in node.get_children():
		child_value.queue_free()


func _process(delta: float) -> void:
	super._process(delta)
	if gizmo_root_v030 == null:
		return
	var show_gizmo: bool = not simulating and is_instance_valid(selected_piece) and not help_panel.visible and not options_panel.visible and tool_mode_v030.is_empty()
	gizmo_root_v030.visible = show_gizmo
	if show_gizmo:
		gizmo_root_v030.global_position = _gizmo_anchor_v030()
		var scale_value: float = clampf(camera_distance / 19.0, 0.62, 2.25)
		gizmo_root_v030.scale = Vector3.ONE * scale_value


func _gizmo_anchor_v030() -> Vector3:
	if not is_instance_valid(selected_piece):
		return Vector3.ZERO
	if _selected_kind() == "connector":
		var pivot: Dictionary = _primary_record_for_connector_v020(selected_piece)
		if not pivot.is_empty() and _fixed_connection_kind_v020(str(pivot["kind"])):
			return _record_anchor_v020(pivot)
	return selected_piece.global_position


func _refresh_editor_overlay_v030() -> void:
	if gizmo_root_v030 == null:
		return
	_refresh_gizmo_validity_v030()
	_refresh_tool_handles_v030()


func _refresh_gizmo_validity_v030() -> void:
	var enabled: bool = not simulating and is_instance_valid(selected_piece) and tool_mode_v030.is_empty()
	for name_value in ["X", "Y", "Z"]:
		if not gizmo_axes_v030.has(name_value):
			continue
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var ring: MeshInstance3D = data["ring"] as MeshInstance3D
		var plus_label: Label3D = data["plus"] as Label3D
		var minus_label: Label3D = data["minus"] as Label3D
		var axis: Vector3 = data["axis"] as Vector3
		var base_material: StandardMaterial3D = data["material"] as StandardMaterial3D
		var plus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, 1).get("valid", false))
		var minus_valid: bool = enabled and bool(_rotation_candidate_v030(axis, -1).get("valid", false))
		ring.material_override = base_material if plus_valid or minus_valid else gizmo_disabled_mat_v030
		plus_label.modulate = base_material.albedo_color if plus_valid else gizmo_disabled_mat_v030.albedo_color
		minus_label.modulate = base_material.albedo_color if minus_valid else gizmo_disabled_mat_v030.albedo_color


# -----------------------------------------------------------------------------
# World-axis gizmo solver. Camera affects only projection, never physical axes.
# -----------------------------------------------------------------------------

func _rotation_context_v030(piece: RigidBody3D) -> Dictionary:
	if not is_instance_valid(piece):
		return {"valid": false, "reason": "no selected piece"}
	_rebuild_connection_graph_v020()
	var pivot: Dictionary = {}
	var excluded_uid: int = -1
	if str(piece.get_meta("kind", "")) == "connector":
		pivot = _primary_record_for_connector_v020(piece)
		if not pivot.is_empty() and _fixed_connection_kind_v020(str(pivot["kind"])):
			excluded_uid = int(pivot["uid"])
	var component: Array = _fixed_component_v020(piece, excluded_uid)
	if not pivot.is_empty() and excluded_uid >= 0:
		var pivot_other: RigidBody3D = _other_body_v020(pivot, piece)
		if _component_has_piece_v020(component, pivot_other):
			return {"valid": false, "reason": "mount is part of a closed rigid loop"}
	return {"valid": true, "piece": piece, "pivot": pivot, "excluded_uid": excluded_uid, "component": component, "anchor": _record_anchor_v020(pivot) if not pivot.is_empty() and excluded_uid >= 0 else piece.global_position}


func _rotation_candidate_v030(axis_value: Vector3, steps: int) -> Dictionary:
	if simulating or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a piece"}
	if steps == 0:
		return {"valid": true, "transforms": {}, "component": []}
	var context: Dictionary = _rotation_context_v030(selected_piece)
	if not bool(context.get("valid", false)):
		return context
	var axis: Vector3 = axis_value.normalized()
	var component: Array = context["component"] as Array
	var anchor: Vector3 = context["anchor"] as Vector3
	var transforms: Dictionary = _rotation_delta_map_v020(component, axis, GIZMO_STEP_030 * float(steps), anchor)
	var validation: Dictionary = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "connection geometry blocks this rotation")), "transforms": transforms, "component": component, "anchor": anchor, "axis": axis}
	return {"valid": true, "transforms": transforms, "component": component, "anchor": anchor, "axis": axis}


func _roll_candidate_v030(direction_sign: int) -> Dictionary:
	if simulating or _selected_kind() != "connector" or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a connector"}
	var context: Dictionary = _rotation_context_v030(selected_piece)
	if not bool(context.get("valid", false)):
		return context
	var pivot: Dictionary = context["pivot"] as Dictionary
	var axis: Vector3
	var anchor: Vector3
	if pivot.is_empty():
		axis = (selected_piece.global_transform.basis * Vector3.UP).normalized()
		anchor = selected_piece.global_position
	else:
		axis = _record_axis_v020(pivot)
		anchor = _record_anchor_v020(pivot)
	var component: Array = context["component"] as Array
	var transforms: Dictionary = _rotation_delta_map_v020(component, axis, GIZMO_STEP_030 * float(direction_sign), anchor)
	var validation: Dictionary = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "mount blocks roll")), "transforms": transforms}
	return {"valid": true, "transforms": transforms, "component": component, "axis": axis, "anchor": anchor}


func _apply_roll_v030(direction_sign: int) -> void:
	var preview: Dictionary = _roll_candidate_v030(direction_sign)
	if not bool(preview.get("valid", false)):
		_status("Roll blocked — %s" % str(preview.get("reason", "not valid")))
		return
	_apply_transform_map_v020(preview["transforms"] as Dictionary, "Rolled %s45° around the real mount axis" % ("+" if direction_sign > 0 else "−"))


func _ray_plane_point_v030(screen_pos: Vector2, center: Vector3, normal_value: Vector3) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var normal: Vector3 = normal_value.normalized()
	var denominator: float = direction.dot(normal)
	if absf(denominator) < 0.0005:
		return {}
	var distance: float = (center - origin).dot(normal) / denominator
	if distance <= 0.0:
		return {}
	return {"point": origin + direction * distance, "distance": distance}


func _pick_gizmo_axis_v030(screen_pos: Vector2) -> Dictionary:
	if gizmo_root_v030 == null or not gizmo_root_v030.visible:
		return {}
	var center: Vector3 = _gizmo_anchor_v030()
	var scale_value: float = gizmo_root_v030.scale.x
	var radius: float = GIZMO_RADIUS_030 * scale_value
	var tolerance: float = GIZMO_PICK_TOLERANCE_030 * scale_value
	var best: Dictionary = {}
	var best_error: float = tolerance
	for name_value in ["X", "Y", "Z"]:
		var data: Dictionary = gizmo_axes_v030[name_value] as Dictionary
		var axis: Vector3 = data["axis"] as Vector3
		var hit: Dictionary = _ray_plane_point_v030(screen_pos, center, axis)
		if hit.is_empty():
			continue
		var point: Vector3 = hit["point"] as Vector3
		var radial: Vector3 = point - center
		var error: float = absf(radial.length() - radius)
		if error <= best_error:
			var plus_valid: bool = bool(_rotation_candidate_v030(axis, 1).get("valid", false))
			var minus_valid: bool = bool(_rotation_candidate_v030(axis, -1).get("valid", false))
			if plus_valid or minus_valid:
				best_error = error
				best = {"name": name_value, "axis": axis, "point": point, "center": center}
	return best


func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	if not tool_mode_v030.is_empty() or simulating:
		return false
	var picked: Dictionary = _pick_gizmo_axis_v030(screen_pos)
	if picked.is_empty():
		return false
	var context: Dictionary = _rotation_context_v030(selected_piece)
	if not bool(context.get("valid", false)):
		return false
	gizmo_drag_active_v030 = true
	gizmo_drag_axis_v030 = picked["axis"] as Vector3
	gizmo_drag_axis_name_v030 = str(picked["name"])
	gizmo_drag_center_v030 = picked["center"] as Vector3
	gizmo_drag_start_vec_v030 = ((picked["point"] as Vector3) - gizmo_drag_center_v030).normalized()
	gizmo_drag_steps_v030 = 0
	gizmo_drag_component_v030 = context["component"] as Array
	gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
	_build_rotation_ghost_v030(gizmo_drag_component_v030)
	_status("Dragging world %s ring — snap 0°" % gizmo_drag_axis_name_v030)
	return true


func _update_gizmo_drag_v030(screen_pos: Vector2) -> void:
	if not gizmo_drag_active_v030:
		return
	var hit: Dictionary = _ray_plane_point_v030(screen_pos, gizmo_drag_center_v030, gizmo_drag_axis_v030)
	if hit.is_empty():
		return
	var current_vec: Vector3 = ((hit["point"] as Vector3) - gizmo_drag_center_v030).normalized()
	if current_vec.length_squared() < 0.5:
		return
	var raw_angle: float = gizmo_drag_start_vec_v030.signed_angle_to(current_vec, gizmo_drag_axis_v030)
	var steps: int = clampi(int(round(raw_angle / GIZMO_STEP_030)), -7, 7)
	if steps == gizmo_drag_steps_v030:
		return
	gizmo_drag_steps_v030 = steps
	if steps == 0:
		gizmo_drag_preview_v030 = {"valid": true, "transforms": {}}
		_update_rotation_ghost_v030({}, true)
		_status("Dragging world %s ring — snap 0°" % gizmo_drag_axis_name_v030)
		return
	var preview: Dictionary = _rotation_candidate_v030(gizmo_drag_axis_v030, steps)
	gizmo_drag_preview_v030 = preview
	_update_rotation_ghost_v030(preview.get("transforms", {}) as Dictionary, bool(preview.get("valid", false)))
	var degrees_value: int = steps * 45
	_status("World %s preview: %d°%s" % [gizmo_drag_axis_name_v030, degrees_value, "" if bool(preview.get("valid", false)) else " — BLOCKED"])


func _finish_gizmo_drag_v030() -> void:
	if not gizmo_drag_active_v030:
		return
	var steps: int = gizmo_drag_steps_v030
	var preview: Dictionary = gizmo_drag_preview_v030
	gizmo_drag_active_v030 = false
	gizmo_drag_steps_v030 = 0
	_clear_rotation_ghost_v030()
	if steps == 0:
		_status("Rotation unchanged")
		return
	if not bool(preview.get("valid", false)):
		_status("Rotation blocked — %s" % str(preview.get("reason", "current connections prevent that snapped state")))
		_refresh_editor_overlay_v030()
		return
	_apply_transform_map_v020(preview["transforms"] as Dictionary, "Rotated world %s by %d°" % [gizmo_drag_axis_name_v030, steps * 45])


func _build_rotation_ghost_v030(component: Array) -> void:
	_clear_rotation_ghost_v030()
	for body_value in component:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		for child_value in body.get_children():
			var source: MeshInstance3D = child_value as MeshInstance3D
			if source == null or source.mesh == null or source.is_queued_for_deletion():
				continue
			var clone: MeshInstance3D = MeshInstance3D.new()
			clone.mesh = source.mesh
			clone.material_override = ghost_valid_mat_v030
			ghost_root_v030.add_child(clone)
			clone.global_transform = body.global_transform * source.transform
			ghost_entries_v030.append({"clone": clone, "body": body, "local": source.transform})


func _update_rotation_ghost_v030(transforms: Dictionary, valid: bool) -> void:
	var material: StandardMaterial3D = ghost_valid_mat_v030 if valid else ghost_invalid_mat_v030
	for entry_value in ghost_entries_v030:
		var entry: Dictionary = entry_value as Dictionary
		var clone: MeshInstance3D = entry["clone"] as MeshInstance3D
		var body: RigidBody3D = entry["body"] as RigidBody3D
		if not is_instance_valid(clone) or not is_instance_valid(body):
			continue
		var body_tf: Transform3D = transforms.get(body.get_instance_id(), body.global_transform) as Transform3D
		clone.global_transform = body_tf * (entry["local"] as Transform3D)
		clone.material_override = material


func _clear_rotation_ghost_v030() -> void:
	ghost_entries_v030.clear()
	_clear_children_v030(ghost_root_v030)


# -----------------------------------------------------------------------------
# Re-seat — topology change is explicit and separate from ordinary rotation.
# -----------------------------------------------------------------------------

func _can_reseat_v030() -> bool:
	if simulating or _selected_kind() != "connector" or not is_instance_valid(selected_piece):
		return false
	var record: Dictionary = _primary_record_for_connector_v020(selected_piece)
	return not record.is_empty() and str(record["kind"]) in ["socket", "cross"]


func _toggle_reseat_v030() -> void:
	if not _can_reseat_v030():
		_status("Re-seat requires a socket- or cross-mounted selected connector")
		return
	if tool_mode_v030 == "reseat":
		_cancel_editor_tools_v030(true)
		return
	_cancel_editor_tools_v030(false)
	tool_mode_v030 = "reseat"
	_refresh_editor_overlay_v030()
	_update_ui()
	_status("Re-seat armed — tap a green connector socket handle")


func _reseat_preview_v030(new_slot: int) -> Dictionary:
	if not _can_reseat_v030():
		return {"valid": false, "reason": "connector is not re-seatable"}
	_rebuild_connection_graph_v020()
	var connector: RigidBody3D = selected_piece
	var record: Dictionary = _primary_record_for_connector_v020(connector)
	var old_slot: int = int(record["slot"])
	if new_slot == old_slot:
		return {"valid": false, "reason": "that is already the mounted socket"}
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size() or not (new_slot in (connector_defs[def_index]["slots"] as Array)):
		return {"valid": false, "reason": "socket does not exist on this connector"}
	for other_value in _connections_for_piece_v020(connector):
		var other: Dictionary = other_value as Dictionary
		if int(other["uid"]) != int(record["uid"]) and int(other.get("slot", -1)) == new_slot:
			return {"valid": false, "reason": "socket is already occupied"}
	var context: Dictionary = _rotation_context_v030(connector)
	if not bool(context.get("valid", false)):
		return context
	var anchor: Vector3 = _record_anchor_v020(record)
	var desired_dir: Vector3
	if str(record["kind"]) == "socket":
		var rod: RigidBody3D = record["rod"] as RigidBody3D
		desired_dir = -_rod_axis_v020(rod) * float(int(record["rod_end"]))
	else:
		desired_dir = (anchor - connector.global_position).normalized()
		if desired_dir.length_squared() < 0.5:
			desired_dir = (_socket_world_v020(connector, old_slot)["dir"] as Vector3).normalized()
	var current_new_dir: Vector3 = (_socket_world_v020(connector, new_slot)["dir"] as Vector3).normalized()
	var rotate_basis: Basis = Basis(Quaternion(current_new_dir, desired_dir.normalized()))
	var target_basis: Basis = (rotate_basis * connector.global_transform.basis).orthonormalized()
	var target_origin: Vector3 = anchor - desired_dir.normalized() * CONNECTOR_D
	var target_tf: Transform3D = Transform3D(target_basis, target_origin)
	var component: Array = context["component"] as Array
	var transforms: Dictionary = _rigid_delta_map_v020(component, connector.global_transform, target_tf)
	var validation: Dictionary = _validate_transforms_with_slot_override_v030(transforms, int(record["uid"]), new_slot)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "other connections prevent re-seat")), "transforms": transforms}
	return {"valid": true, "transforms": transforms, "record": record, "new_slot": new_slot}


func _validate_transforms_with_slot_override_v030(transforms: Dictionary, connection_uid: int, new_slot: int) -> Dictionary:
	for record_value in connections_v020:
		var record: Dictionary = (record_value as Dictionary).duplicate(true)
		if int(record["uid"]) == connection_uid:
			record["slot"] = new_slot
		var result: Dictionary = _validate_record_v020(record, transforms)
		if not bool(result.get("valid", false)):
			return result
	return {"valid": true}


func _apply_reseat_v030(new_slot: int) -> void:
	var preview: Dictionary = _reseat_preview_v030(new_slot)
	if not bool(preview.get("valid", false)):
		_status("Re-seat blocked — %s" % str(preview.get("reason", "not valid")))
		return
	_apply_transforms_raw_v030(preview["transforms"] as Dictionary)
	var record: Dictionary = preview["record"] as Dictionary
	var joint: Joint3D = record["joint"] as Joint3D
	if is_instance_valid(joint):
		joint.set_meta("connector_slot_v020", new_slot)
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_cancel_editor_tools_v030(false)
	_refresh_selection_highlight()
	_update_ui()
	_status("Mount re-seated from socket %d° to %d°" % [int(record["slot"]), new_slot])


# -----------------------------------------------------------------------------
# Manual detach blocking prevents the automatic overlap detector from instantly
# undoing an intentional Detach while the two pieces are still touching.
# -----------------------------------------------------------------------------

func _pair_key_v030(a: RigidBody3D, b: RigidBody3D) -> String:
	var first: int = _ensure_piece_uid_v020(a)
	var second: int = _ensure_piece_uid_v020(b)
	if first > second:
		var swap_value: int = first
		first = second
		second = swap_value
	return "%d:%d" % [first, second]


func _fixed_pair_exists_v020(a: RigidBody3D, b: RigidBody3D) -> bool:
	if auto_connect_context_v030 and manual_detach_blocks_v030.has(_pair_key_v030(a, b)):
		return true
	return super._fixed_pair_exists_v020(a, b)


func _auto_connect_all_v020() -> int:
	auto_connect_context_v030 = true
	var result: int = super._auto_connect_all_v020()
	auto_connect_context_v030 = false
	return result


func _toggle_detach_v030() -> void:
	if simulating or not is_instance_valid(selected_piece):
		return
	var attached: Array = _connections_for_piece_v020(selected_piece)
	if attached.is_empty():
		_status("Selected piece has no recorded connection to detach")
		return
	if tool_mode_v030 == "detach":
		_cancel_editor_tools_v030(true)
		return
	_cancel_editor_tools_v030(false)
	tool_mode_v030 = "detach"
	_refresh_editor_overlay_v030()
	_update_ui()
	_status("Detach armed — tap an orange connection anchor")


func _detach_record_v030(record: Dictionary) -> void:
	var a: RigidBody3D = record["a"] as RigidBody3D
	var b: RigidBody3D = record["b"] as RigidBody3D
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	manual_detach_blocks_v030[_pair_key_v030(a, b)] = true
	var connector: RigidBody3D = record["connector"] as RigidBody3D
	if is_instance_valid(connector) and int(connector.get_meta("primary_connection_uid_v020", -1)) == int(record["uid"]):
		connector.set_meta("primary_connection_uid_v020", -1)
	if str(record["kind"]) == "cross" and is_instance_valid(connector):
		connector.set_meta("cross_mount", false)
		connector.set_meta("cross_host_rod", null)
	var joint: Joint3D = record["joint"] as Joint3D
	if is_instance_valid(joint):
		joints.erase(joint)
		joint.queue_free()
	_rebuild_connection_graph_v020()
	_commit_state()
	_cancel_editor_tools_v030(false)
	_refresh_selection_highlight()
	_update_ui()
	_status("Connection detached. Pieces stay in place; use Attach to reconnect them explicitly.")


# -----------------------------------------------------------------------------
# Attach drag tool
# -----------------------------------------------------------------------------

func _toggle_attach_v030() -> void:
	if simulating or not _selected_has_attach_source_v030():
		_status("Selected piece has no free handle for the current %s mode" % ["SOCKET", "AXLE", "CROSS"][attach_mode])
		return
	if tool_mode_v030 == "attach":
		_cancel_editor_tools_v030(true)
		return
	_cancel_editor_tools_v030(false)
	tool_mode_v030 = "attach"
	_refresh_editor_overlay_v030()
	_update_ui()
	_status("Attach armed — drag from a highlighted handle on the selected piece")


func _selected_has_attach_source_v030() -> bool:
	if simulating or not is_instance_valid(selected_piece):
		return false
	var kind: String = _selected_kind()
	if kind == "o_ring":
		return true
	if attach_mode == 0:
		if kind == "rod":
			var ends: Dictionary = selected_piece.get_meta("end_occupied", {}) as Dictionary
			return not ends.has(-1) or not ends.has(1)
		if kind == "connector":
			return not _free_connector_slots_v030(selected_piece).is_empty()
	if attach_mode == 1:
		if kind == "rod":
			return true
		if kind == "connector":
			return not bool(selected_piece.get_meta("axle_occupied", false))
	if attach_mode == 2:
		if kind == "rod":
			return true
		if kind == "connector":
			return not _free_connector_slots_v030(selected_piece).is_empty()
	return false


func _free_connector_slots_v030(connector: RigidBody3D) -> Array:
	var result: Array = []
	if not is_instance_valid(connector):
		return result
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return result
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		if not occupied.has(slot):
			result.append(slot)
	return result


func _source_candidates_v030() -> Array:
	var result: Array = []
	if not is_instance_valid(selected_piece):
		return result
	var kind: String = _selected_kind()
	if kind == "o_ring":
		result.append({"type": "o_ring", "body": selected_piece, "point": selected_piece.global_position})
		return result
	if attach_mode == 0:
		if kind == "rod":
			var occupied_ends: Dictionary = selected_piece.get_meta("end_occupied", {}) as Dictionary
			for sign_value in [-1, 1]:
				if not occupied_ends.has(sign_value):
					result.append({"type": "rod_end", "body": selected_piece, "sign": sign_value, "point": _rod_end_v020(selected_piece, sign_value)})
		elif kind == "connector":
			for slot_value in _free_connector_slots_v030(selected_piece):
				var socket: Dictionary = _socket_world_v020(selected_piece, int(slot_value))
				result.append({"type": "socket", "body": selected_piece, "slot": int(slot_value), "point": socket["point"]})
	elif attach_mode == 1:
		if kind == "connector":
			result.append({"type": "connector_hub", "body": selected_piece, "point": selected_piece.global_position})
		elif kind == "rod":
			result.append({"type": "rod_body", "body": selected_piece, "point": selected_piece.global_position, "along": 0.0})
	elif attach_mode == 2:
		if kind == "connector":
			for slot_value in _free_connector_slots_v030(selected_piece):
				var cross_socket: Dictionary = _socket_world_v020(selected_piece, int(slot_value))
				result.append({"type": "socket", "body": selected_piece, "slot": int(slot_value), "point": cross_socket["point"]})
		elif kind == "rod":
			result.append({"type": "rod_body", "body": selected_piece, "point": selected_piece.global_position, "along": 0.0})
	return result


func _begin_attach_drag_v030(screen_pos: Vector2) -> bool:
	if tool_mode_v030 != "attach" or not is_instance_valid(selected_piece):
		return false
	var source: Dictionary = _nearest_projected_candidate_v030(_source_candidates_v030(), screen_pos, HANDLE_SCREEN_RADIUS_030)
	if source.is_empty() and _selected_kind() == "rod" and attach_mode in [1, 2]:
		var hit: Dictionary = _raycast_piece(screen_pos)
		if not hit.is_empty() and hit.get("collider") == selected_piece:
			var point: Vector3 = hit["position"] as Vector3
			var axis: Vector3 = _rod_axis_v020(selected_piece)
			var half_len: float = maxf(0.1, float(selected_piece.get_meta("visual_length", 0.0)) * 0.5 - 0.35)
			var along: float = clampf((point - selected_piece.global_position).dot(axis), -half_len, half_len)
			source = {"type": "rod_body", "body": selected_piece, "point": selected_piece.global_position + axis * along, "along": along}
	if source.is_empty():
		_status("Start the drag on one of the highlighted free handles")
		return false
	attach_drag_active_v030 = true
	attach_source_v030 = source
	attach_target_v030 = {}
	var start_screen: Vector2 = camera.unproject_position(source["point"] as Vector3)
	tether_line_v030.points = PackedVector2Array([start_screen, screen_pos])
	tether_line_v030.visible = true
	_refresh_attach_target_handles_v030(source)
	return true


func _update_attach_drag_v030(screen_pos: Vector2) -> void:
	if not attach_drag_active_v030:
		return
	var start_screen: Vector2 = camera.unproject_position(attach_source_v030["point"] as Vector3)
	tether_line_v030.points = PackedVector2Array([start_screen, screen_pos])
	attach_target_v030 = _target_for_source_v030(attach_source_v030, screen_pos)
	tether_line_v030.default_color = Color(0.20, 1.0, 0.48, 0.95) if not attach_target_v030.is_empty() else Color(0.08, 0.82, 1.0, 0.95)
	if is_instance_valid(current_target_marker_v030):
		current_target_marker_v030.queue_free()
	current_target_marker_v030 = null
	if not attach_target_v030.is_empty():
		current_target_marker_v030 = _make_handle_v030(target_handle_root_v030, attach_target_v030["point"] as Vector3, handle_valid_mat_v030, 0.27)


func _finish_attach_drag_v030() -> void:
	if not attach_drag_active_v030:
		return
	attach_drag_active_v030 = false
	tether_line_v030.visible = false
	if attach_target_v030.is_empty():
		_status("Attach cancelled — release over a compatible highlighted target")
		attach_source_v030 = {}
		_refresh_tool_handles_v030()
		return
	var source: Dictionary = attach_source_v030
	var target: Dictionary = attach_target_v030
	attach_source_v030 = {}
	attach_target_v030 = {}
	_perform_attach_v030(source, target)


func _target_for_source_v030(source: Dictionary, screen_pos: Vector2) -> Dictionary:
	var source_type: String = str(source["type"])
	if source_type == "rod_end":
		return _nearest_projected_candidate_v030(_all_free_socket_targets_v030(source["body"] as RigidBody3D), screen_pos, HANDLE_SCREEN_RADIUS_030)
	if source_type == "socket" and attach_mode == 0:
		return _nearest_projected_candidate_v030(_all_free_rod_end_targets_v030(source["body"] as RigidBody3D), screen_pos, HANDLE_SCREEN_RADIUS_030)
	if source_type == "socket" and attach_mode == 2:
		return _rod_body_target_from_screen_v030(screen_pos, source["body"] as RigidBody3D)
	if source_type == "connector_hub":
		return _rod_body_target_from_screen_v030(screen_pos, source["body"] as RigidBody3D)
	if source_type == "rod_body" and attach_mode == 2:
		return _nearest_projected_candidate_v030(_all_free_socket_targets_v030(source["body"] as RigidBody3D), screen_pos, HANDLE_SCREEN_RADIUS_030)
	if source_type == "rod_body" and attach_mode == 1:
		return _nearest_projected_candidate_v030(_all_free_hub_targets_v030(source["body"] as RigidBody3D), screen_pos, HANDLE_SCREEN_RADIUS_030)
	if source_type == "o_ring":
		var ring_target: Dictionary = _rod_body_target_from_screen_v030(screen_pos, source["body"] as RigidBody3D)
		if not ring_target.is_empty() and _rod_is_axle(ring_target["body"] as RigidBody3D):
			return ring_target
	return {}


func _all_free_socket_targets_v030(exclude_body: RigidBody3D) -> Array:
	var result: Array = []
	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or connector == exclude_body or str(connector.get_meta("kind", "")) != "connector":
			continue
		for slot_value in _free_connector_slots_v030(connector):
			var socket: Dictionary = _socket_world_v020(connector, int(slot_value))
			result.append({"type": "socket", "body": connector, "slot": int(slot_value), "point": socket["point"]})
	return result


func _all_free_rod_end_targets_v030(exclude_body: RigidBody3D) -> Array:
	var result: Array = []
	for body_value in bodies:
		var rod: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(rod) or rod == exclude_body or str(rod.get_meta("kind", "")) != "rod":
			continue
		var occupied: Dictionary = rod.get_meta("end_occupied", {}) as Dictionary
		for sign_value in [-1, 1]:
			if not occupied.has(sign_value):
				result.append({"type": "rod_end", "body": rod, "sign": sign_value, "point": _rod_end_v020(rod, sign_value)})
	return result


func _all_free_hub_targets_v030(exclude_body: RigidBody3D) -> Array:
	var result: Array = []
	for body_value in bodies:
		var connector: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(connector) or connector == exclude_body or str(connector.get_meta("kind", "")) != "connector":
			continue
		if bool(connector.get_meta("axle_occupied", false)):
			continue
		result.append({"type": "connector_hub", "body": connector, "point": connector.global_position})
	return result


func _rod_body_target_from_screen_v030(screen_pos: Vector2, exclude_body: RigidBody3D) -> Dictionary:
	var hit: Dictionary = _raycast_piece(screen_pos)
	if hit.is_empty():
		return {}
	var rod: RigidBody3D = hit.get("collider") as RigidBody3D
	if not is_instance_valid(rod) or rod == exclude_body or str(rod.get_meta("kind", "")) != "rod":
		return {}
	var axis: Vector3 = _rod_axis_v020(rod)
	var half_len: float = maxf(0.1, float(rod.get_meta("visual_length", 0.0)) * 0.5 - 0.35)
	var along: float = clampf(((hit["position"] as Vector3) - rod.global_position).dot(axis), -half_len, half_len)
	return {"type": "rod_body", "body": rod, "along": along, "point": rod.global_position + axis * along}


func _nearest_projected_candidate_v030(candidates: Array, screen_pos: Vector2, max_distance: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = max_distance
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		var point: Vector3 = candidate["point"] as Vector3
		if camera.is_position_behind(point):
			continue
		var projected: Vector2 = camera.unproject_position(point)
		var distance: float = projected.distance_to(screen_pos)
		if distance <= best_distance:
			best_distance = distance
			best = candidate
	return best


func _perform_attach_v030(source: Dictionary, target: Dictionary) -> void:
	var source_body: RigidBody3D = source["body"] as RigidBody3D
	var target_body: RigidBody3D = target["body"] as RigidBody3D
	if not is_instance_valid(source_body) or not is_instance_valid(target_body) or source_body == target_body:
		_status("Attach cancelled — invalid source/target")
		return
	_rebuild_connection_graph_v020()
	var source_component: Array = _fixed_component_v020(source_body)
	var same_component: bool = _component_has_piece_v020(source_component, target_body)
	var transforms: Dictionary = {}
	if same_component:
		var current_check: Dictionary = _current_attach_geometry_v030(source, target)
		if not bool(current_check.get("valid", false)):
			_status("Attach blocked — these handles are in the same rigid assembly but are not geometrically aligned")
			return
	else:
		var snap: Dictionary = _snap_source_component_v030(source, target, source_component)
		if not bool(snap.get("valid", false)):
			_status("Attach blocked — %s" % str(snap.get("reason", "existing connections prevent the required snap")))
			return
		transforms = snap.get("transforms", {}) as Dictionary
		var validation: Dictionary = _validate_transforms_v020(transforms)
		if not bool(validation.get("valid", false)):
			_status("Attach blocked — %s" % str(validation.get("reason", "source component cannot move without breaking another connection")))
			return
		_apply_transforms_raw_v030(transforms)
	_create_explicit_connection_v030(source, target)
	manual_detach_blocks_v030.erase(_pair_key_v030(source_body, target_body))
	_refresh_joint_frames_v020()
	_rebuild_connection_graph_v020()
	_commit_state()
	_cancel_editor_tools_v030(false)
	_refresh_selection_highlight()
	_update_ui()
	_status("Explicit %s connection attached and recorded" % ["SOCKET", "AXLE", "CROSS"][attach_mode])


func _snap_source_component_v030(source: Dictionary, target: Dictionary, component: Array) -> Dictionary:
	var source_type: String = str(source["type"])
	var target_type: String = str(target["type"])
	var source_body: RigidBody3D = source["body"] as RigidBody3D
	if source_type == "rod_end" and target_type == "socket":
		var rod: RigidBody3D = source_body
		var connector: RigidBody3D = target["body"] as RigidBody3D
		var sign_value: int = int(source["sign"])
		var socket: Dictionary = _socket_world_v020(connector, int(target["slot"]))
		var desired_axis: Vector3 = -(socket["dir"] as Vector3).normalized() * float(sign_value)
		var current_axis: Vector3 = _rod_axis_v020(rod)
		var rotate_basis: Basis = Basis(Quaternion(current_axis, desired_axis))
		var target_basis: Basis = (rotate_basis * rod.global_transform.basis).orthonormalized()
		var length: float = float(rod.get_meta("visual_length", 0.0))
		var target_origin: Vector3 = (socket["point"] as Vector3) - desired_axis * (length * 0.5 * float(sign_value))
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, rod.global_transform, Transform3D(target_basis, target_origin))}
	if source_type == "socket" and target_type == "rod_end":
		var connector_source: RigidBody3D = source_body
		var rod_target: RigidBody3D = target["body"] as RigidBody3D
		var sign_target: int = int(target["sign"])
		var outward: Vector3 = _rod_axis_v020(rod_target) * float(sign_target)
		var desired_dir: Vector3 = -outward
		var current_dir: Vector3 = (_socket_world_v020(connector_source, int(source["slot"]))["dir"] as Vector3).normalized()
		var connector_rotate: Basis = Basis(Quaternion(current_dir, desired_dir.normalized()))
		var connector_basis: Basis = (connector_rotate * connector_source.global_transform.basis).orthonormalized()
		var connector_origin: Vector3 = _rod_end_v020(rod_target, sign_target) - desired_dir.normalized() * CONNECTOR_D
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, connector_source.global_transform, Transform3D(connector_basis, connector_origin))}
	if source_type == "socket" and target_type == "rod_body" and attach_mode == 2:
		var cross_connector: RigidBody3D = source_body
		var host_rod: RigidBody3D = target["body"] as RigidBody3D
		var host_axis: Vector3 = _rod_axis_v020(host_rod)
		var current_socket_dir: Vector3 = (_socket_world_v020(cross_connector, int(source["slot"]))["dir"] as Vector3).normalized()
		var radial: Vector3 = current_socket_dir - host_axis * current_socket_dir.dot(host_axis)
		if radial.length_squared() < 0.05:
			radial = _stable_perpendicular_v030(host_axis)
		radial = radial.normalized()
		var cross_basis: Basis = _basis_for_cross_v020(_slot_dir(int(source["slot"])), host_axis, radial)
		var cross_origin: Vector3 = (target["point"] as Vector3) - radial * CONNECTOR_D
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, cross_connector.global_transform, Transform3D(cross_basis, cross_origin))}
	if source_type == "rod_body" and target_type == "socket" and attach_mode == 2:
		var cross_rod: RigidBody3D = source_body
		var target_connector: RigidBody3D = target["body"] as RigidBody3D
		var target_socket: Dictionary = _socket_world_v020(target_connector, int(target["slot"]))
		var slot_dir: Vector3 = (target_socket["dir"] as Vector3).normalized()
		var plane_normal: Vector3 = (target_connector.global_transform.basis * Vector3.UP).normalized()
		var desired_rod_axis: Vector3 = plane_normal.cross(slot_dir).normalized()
		var current_rod_axis: Vector3 = _rod_axis_v020(cross_rod)
		if desired_rod_axis.dot(current_rod_axis) < 0.0:
			desired_rod_axis = -desired_rod_axis
		var rod_rotate: Basis = Basis(Quaternion(current_rod_axis, desired_rod_axis))
		var rod_basis: Basis = (rod_rotate * cross_rod.global_transform.basis).orthonormalized()
		var rod_origin: Vector3 = (target_socket["point"] as Vector3) - desired_rod_axis * float(source["along"])
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, cross_rod.global_transform, Transform3D(rod_basis, rod_origin))}
	if source_type == "connector_hub" and target_type == "rod_body":
		var axle_connector: RigidBody3D = source_body
		var axle_rod: RigidBody3D = target["body"] as RigidBody3D
		var axle_axis: Vector3 = _rod_axis_v020(axle_rod)
		var current_up: Vector3 = (axle_connector.global_transform.basis * Vector3.UP).normalized()
		if current_up.dot(axle_axis) < 0.0:
			axle_axis = -axle_axis
		var axle_rotate: Basis = Basis(Quaternion(current_up, axle_axis))
		var axle_basis: Basis = (axle_rotate * axle_connector.global_transform.basis).orthonormalized()
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, axle_connector.global_transform, Transform3D(axle_basis, target["point"] as Vector3))}
	if source_type == "rod_body" and target_type == "connector_hub":
		var source_rod: RigidBody3D = source_body
		var hub_connector: RigidBody3D = target["body"] as RigidBody3D
		var hub_axis: Vector3 = (hub_connector.global_transform.basis * Vector3.UP).normalized()
		var source_axis: Vector3 = _rod_axis_v020(source_rod)
		if source_axis.dot(hub_axis) < 0.0:
			hub_axis = -hub_axis
		var source_rotate: Basis = Basis(Quaternion(source_axis, hub_axis))
		var source_basis: Basis = (source_rotate * source_rod.global_transform.basis).orthonormalized()
		var source_origin: Vector3 = hub_connector.global_position - hub_axis * float(source["along"])
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, source_rod.global_transform, Transform3D(source_basis, source_origin))}
	if source_type == "o_ring" and target_type == "rod_body":
		var ring: RigidBody3D = source_body
		var ring_rod: RigidBody3D = target["body"] as RigidBody3D
		var ring_axis: Vector3 = _rod_axis_v020(ring_rod)
		var ring_up: Vector3 = (ring.global_transform.basis * Vector3.UP).normalized()
		if ring_up.dot(ring_axis) < 0.0:
			ring_axis = -ring_axis
		var ring_rotate: Basis = Basis(Quaternion(ring_up, ring_axis))
		var ring_basis: Basis = (ring_rotate * ring.global_transform.basis).orthonormalized()
		return {"valid": true, "transforms": _rigid_delta_map_v020(component, ring.global_transform, Transform3D(ring_basis, target["point"] as Vector3))}
	return {"valid": false, "reason": "source and target handle types are not compatible"}


func _current_attach_geometry_v030(source: Dictionary, target: Dictionary) -> Dictionary:
	var source_type: String = str(source["type"])
	var target_type: String = str(target["type"])
	if source_type == "rod_end" and target_type == "socket":
		var rod: RigidBody3D = source["body"] as RigidBody3D
		var connector: RigidBody3D = target["body"] as RigidBody3D
		var sign_value: int = int(source["sign"])
		var socket: Dictionary = _socket_world_v020(connector, int(target["slot"]))
		var outward: Vector3 = _rod_axis_v020(rod) * float(sign_value)
		return {"valid": _rod_end_v020(rod, sign_value).distance_to(socket["point"] as Vector3) <= ATTACH_SOCKET_GAP_030 and (socket["dir"] as Vector3).dot(-outward) >= 0.94}
	if source_type == "socket" and target_type == "rod_end":
		return _current_attach_geometry_v030(target, source)
	if source_type == "socket" and target_type == "rod_body":
		var cross_connector: RigidBody3D = source["body"] as RigidBody3D
		var cross_rod: RigidBody3D = target["body"] as RigidBody3D
		var cross_socket: Dictionary = _socket_world_v020(cross_connector, int(source["slot"]))
		var host_axis: Vector3 = _rod_axis_v020(cross_rod)
		var normal: Vector3 = (cross_connector.global_transform.basis * Vector3.UP).normalized()
		return {"valid": (cross_socket["point"] as Vector3).distance_to(target["point"] as Vector3) <= ATTACH_CROSS_GAP_030 and absf((cross_socket["dir"] as Vector3).dot(host_axis)) <= 0.26 and absf(normal.dot(host_axis)) <= 0.26}
	if source_type == "rod_body" and target_type == "socket":
		return _current_attach_geometry_v030(target, source)
	if source_type == "connector_hub" and target_type == "rod_body":
		var axle_connector: RigidBody3D = source["body"] as RigidBody3D
		var axle_rod: RigidBody3D = target["body"] as RigidBody3D
		var axis: Vector3 = _rod_axis_v020(axle_rod)
		var delta: Vector3 = axle_connector.global_position - axle_rod.global_position
		var radial: Vector3 = delta - axis * delta.dot(axis)
		var hub_axis: Vector3 = (axle_connector.global_transform.basis * Vector3.UP).normalized()
		return {"valid": radial.length() <= ATTACH_AXLE_GAP_030 and absf(hub_axis.dot(axis)) >= 0.94}
	if source_type == "rod_body" and target_type == "connector_hub":
		return _current_attach_geometry_v030(target, source)
	if source_type == "o_ring" and target_type == "rod_body":
		var ring: RigidBody3D = source["body"] as RigidBody3D
		var host: RigidBody3D = target["body"] as RigidBody3D
		var ring_axis: Vector3 = _rod_axis_v020(host)
		var ring_delta: Vector3 = ring.global_position - host.global_position
		var ring_radial: Vector3 = ring_delta - ring_axis * ring_delta.dot(ring_axis)
		return {"valid": ring_radial.length() <= ATTACH_AXLE_GAP_030}
	return {"valid": false}


func _create_explicit_connection_v030(source: Dictionary, target: Dictionary) -> void:
	var source_type: String = str(source["type"])
	var target_type: String = str(target["type"])
	if source_type == "rod_end" and target_type == "socket":
		_create_socket_connection_v030(source["body"] as RigidBody3D, int(source["sign"]), target["body"] as RigidBody3D, int(target["slot"]))
		return
	if source_type == "socket" and target_type == "rod_end":
		_create_socket_connection_v030(target["body"] as RigidBody3D, int(target["sign"]), source["body"] as RigidBody3D, int(source["slot"]))
		return
	if source_type == "socket" and target_type == "rod_body":
		_create_cross_connection_v030(source["body"] as RigidBody3D, int(source["slot"]), target["body"] as RigidBody3D, float(target["along"]))
		return
	if source_type == "rod_body" and target_type == "socket":
		_create_cross_connection_v030(target["body"] as RigidBody3D, int(target["slot"]), source["body"] as RigidBody3D, float(source["along"]))
		return
	if source_type == "connector_hub" and target_type == "rod_body":
		_create_axle_connection_v030(source["body"] as RigidBody3D, target["body"] as RigidBody3D)
		return
	if source_type == "rod_body" and target_type == "connector_hub":
		_create_axle_connection_v030(target["body"] as RigidBody3D, source["body"] as RigidBody3D)
		return
	if source_type == "o_ring" and target_type == "rod_body":
		_create_o_ring_connection_v030(source["body"] as RigidBody3D, target["body"] as RigidBody3D, float(target["along"]))


func _create_socket_connection_v030(rod: RigidBody3D, sign_value: int, connector: RigidBody3D, slot: int) -> void:
	var anchor: Vector3 = (_rod_end_v020(rod, sign_value) + (_socket_world_v020(connector, slot)["point"] as Vector3)) * 0.5
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	var primary: bool = _connections_for_piece_v020(connector).is_empty() and not bool(connector.get_meta("root_piece_v020", false))
	_tag_connection_v020(joint, "socket", connector, rod, slot, sign_value, 0.0, null, primary)


func _create_cross_connection_v030(connector: RigidBody3D, slot: int, rod: RigidBody3D, along: float) -> void:
	var anchor: Vector3 = rod.global_position + _rod_axis_v020(rod) * along
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, connector, anchor)
	var primary: bool = _connections_for_piece_v020(connector).is_empty() and not bool(connector.get_meta("root_piece_v020", false))
	_tag_connection_v020(joint, "cross", connector, rod, slot, 0, along, null, primary)
	joint.set_meta("cross_mount", true)
	connector.set_meta("cross_mount", true)
	connector.set_meta("cross_host_rod", rod)


func _create_axle_connection_v030(connector: RigidBody3D, rod: RigidBody3D) -> void:
	var joint: Generic6DOFJoint3D = _make_axle_joint(connector, rod)
	var primary: bool = _connections_for_piece_v020(connector).is_empty() and not bool(connector.get_meta("root_piece_v020", false))
	_tag_connection_v020(joint, "axle", connector, rod, -1, 0, 0.0, null, primary)
	connector.set_meta("axle_occupied", true)
	connector.set_meta("axle_host_rod", rod)


func _create_o_ring_connection_v030(ring: RigidBody3D, rod: RigidBody3D, along: float) -> void:
	var anchor: Vector3 = rod.global_position + _rod_axis_v020(rod) * along
	var joint: Generic6DOFJoint3D = _make_fixed_joint(rod, ring, anchor)
	_tag_connection_v020(joint, "o_ring", null, rod, -1, 0, along, ring, false)
	joint.set_meta("o_ring_mount", true)
	ring.set_meta("host_rod", rod)


func _apply_transforms_raw_v030(transforms: Dictionary) -> void:
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body) and transforms.has(body.get_instance_id()):
			body.global_transform = transforms[body.get_instance_id()] as Transform3D
			body.set_meta("build_transform", body.global_transform)
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring) and transforms.has(ring.get_instance_id()):
			ring.global_transform = transforms[ring.get_instance_id()] as Transform3D
			ring.set_meta("build_transform", ring.global_transform)


# -----------------------------------------------------------------------------
# Tool handles and tap interception
# -----------------------------------------------------------------------------

func _refresh_tool_handles_v030() -> void:
	if tool_handle_root_v030 == null or target_handle_root_v030 == null:
		return
	_clear_children_v030(tool_handle_root_v030)
	if not attach_drag_active_v030:
		_clear_children_v030(target_handle_root_v030)
		current_target_marker_v030 = null
	if simulating or not is_instance_valid(selected_piece):
		return
	if tool_mode_v030 == "reseat":
		var connector: RigidBody3D = selected_piece
		var record: Dictionary = _primary_record_for_connector_v020(connector)
		if record.is_empty():
			return
		var current_slot: int = int(record["slot"])
		var def_index: int = int(connector.get_meta("connector_type", -1))
		if def_index < 0 or def_index >= connector_defs.size():
			return
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			var point: Vector3 = _socket_world_v020(connector, slot)["point"] as Vector3
			var material: StandardMaterial3D = handle_current_mat_v030 if slot == current_slot else (handle_valid_mat_v030 if bool(_reseat_preview_v030(slot).get("valid", false)) else handle_invalid_mat_v030)
			_make_handle_v030(tool_handle_root_v030, point, material, 0.20)
	elif tool_mode_v030 == "detach":
		for record_value in _connections_for_piece_v020(selected_piece):
			var record_detach: Dictionary = record_value as Dictionary
			_make_handle_v030(tool_handle_root_v030, _record_anchor_v020(record_detach), handle_detach_mat_v030, 0.23)
	elif tool_mode_v030 == "attach" and not attach_drag_active_v030:
		for source_value in _source_candidates_v030():
			var source: Dictionary = source_value as Dictionary
			_make_handle_v030(tool_handle_root_v030, source["point"] as Vector3, handle_valid_mat_v030, 0.22)


func _refresh_attach_target_handles_v030(source: Dictionary) -> void:
	_clear_children_v030(target_handle_root_v030)
	current_target_marker_v030 = null
	var targets: Array = []
	var source_type: String = str(source["type"])
	if source_type == "rod_end":
		targets = _all_free_socket_targets_v030(source["body"] as RigidBody3D)
	elif source_type == "socket" and attach_mode == 0:
		targets = _all_free_rod_end_targets_v030(source["body"] as RigidBody3D)
	elif source_type == "rod_body" and attach_mode == 2:
		targets = _all_free_socket_targets_v030(source["body"] as RigidBody3D)
	elif source_type == "rod_body" and attach_mode == 1:
		targets = _all_free_hub_targets_v030(source["body"] as RigidBody3D)
	else:
		# Continuous rod-body targets: show rod centres as hints; the live target
		# marker follows the exact point under the finger.
		for body_value in bodies:
			var rod: RigidBody3D = body_value as RigidBody3D
			if is_instance_valid(rod) and rod != source["body"] and str(rod.get_meta("kind", "")) == "rod":
				targets.append({"point": rod.global_position})
	for target_value in targets:
		var target: Dictionary = target_value as Dictionary
		_make_handle_v030(target_handle_root_v030, target["point"] as Vector3, handle_valid_mat_v030, 0.16)


func _handle_tap(screen_pos: Vector2) -> void:
	if tool_mode_v030 == "reseat":
		_handle_reseat_tap_v030(screen_pos)
		return
	if tool_mode_v030 == "detach":
		_handle_detach_tap_v030(screen_pos)
		return
	if tool_mode_v030 == "attach":
		_status("Attach is drag-based — press a highlighted source handle and drag to a target")
		return
	super._handle_tap(screen_pos)


func _handle_reseat_tap_v030(screen_pos: Vector2) -> void:
	if not _can_reseat_v030():
		_cancel_editor_tools_v030(false)
		return
	var connector: RigidBody3D = selected_piece
	var def_index: int = int(connector.get_meta("connector_type", -1))
	if def_index < 0 or def_index >= connector_defs.size():
		return
	var candidates: Array = []
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		candidates.append({"slot": slot, "point": _socket_world_v020(connector, slot)["point"]})
	var picked: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, HANDLE_SCREEN_RADIUS_030)
	if picked.is_empty():
		_status("Tap one of the visible socket handles")
		return
	_apply_reseat_v030(int(picked["slot"]))


func _handle_detach_tap_v030(screen_pos: Vector2) -> void:
	var attached: Array = _connections_for_piece_v020(selected_piece)
	var candidates: Array = []
	for record_value in attached:
		var record: Dictionary = record_value as Dictionary
		candidates.append({"record": record, "point": _record_anchor_v020(record)})
	var picked: Dictionary = _nearest_projected_candidate_v030(candidates, screen_pos, HANDLE_SCREEN_RADIUS_030)
	if picked.is_empty():
		_status("Tap an orange connection anchor")
		return
	_detach_record_v030(picked["record"] as Dictionary)


func _cancel_editor_tools_v030(report: bool = false) -> void:
	tool_mode_v030 = ""
	attach_drag_active_v030 = false
	attach_source_v030 = {}
	attach_target_v030 = {}
	if tether_line_v030 != null:
		tether_line_v030.visible = false
	_clear_rotation_ghost_v030()
	if tool_handle_root_v030 != null:
		_clear_children_v030(tool_handle_root_v030)
	if target_handle_root_v030 != null:
		_clear_children_v030(target_handle_root_v030)
	current_target_marker_v030 = null
	if report:
		_status("Editor tool cancelled")
	_refresh_editor_overlay_v030()


# -----------------------------------------------------------------------------
# Input — gizmo and Attach consume their own drag gestures; everything else keeps
# the inherited orbit/pan/zoom/build controls.
# -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _begin_gizmo_drag_v030(touch.position):
				return
			if tool_mode_v030 == "attach":
				_begin_attach_drag_v030(touch.position)
				return
		else:
			if gizmo_drag_active_v030:
				_finish_gizmo_drag_v030()
				return
			if attach_drag_active_v030:
				_finish_attach_drag_v030()
				return
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if gizmo_drag_active_v030:
			_update_gizmo_drag_v030(drag.position)
			return
		if attach_drag_active_v030:
			_update_attach_drag_v030(drag.position)
			return
		if tool_mode_v030 == "attach":
			return
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed:
			if _begin_gizmo_drag_v030(mouse_button.position):
				return
			if tool_mode_v030 == "attach":
				_begin_attach_drag_v030(mouse_button.position)
				return
		else:
			if gizmo_drag_active_v030:
				_finish_gizmo_drag_v030()
				return
			if attach_drag_active_v030:
				_finish_attach_drag_v030()
				return
	elif event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if gizmo_drag_active_v030:
			_update_gizmo_drag_v030(mouse_motion.position)
			return
		if attach_drag_active_v030:
			_update_attach_drag_v030(mouse_motion.position)
			return
	super._unhandled_input(event)


# -----------------------------------------------------------------------------
# Selection/state integration
# -----------------------------------------------------------------------------

func _set_selected(body: RigidBody3D) -> void:
	if gizmo_root_v030 != null:
		_cancel_editor_tools_v030(false)
	super._set_selected(body)
	_refresh_editor_overlay_v030()


func _change_connector_type(delta: int) -> void:
	_cancel_editor_tools_v030(false)
	super._change_connector_type(delta)
	_refresh_editor_overlay_v030()


func _change_rod_type(delta: int) -> void:
	_cancel_editor_tools_v030(false)
	super._change_rod_type(delta)
	_refresh_editor_overlay_v030()


func _cycle_mode() -> void:
	_cancel_editor_tools_v030(false)
	super._cycle_mode()
	_update_ui()


func _capture_state() -> Dictionary:
	var snapshot: Dictionary = super._capture_state()
	snapshot["v030_detach_blocks"] = manual_detach_blocks_v030.keys().duplicate()
	return snapshot


func _restore_state(snapshot: Dictionary) -> void:
	_cancel_editor_tools_v030(false)
	super._restore_state(snapshot)
	manual_detach_blocks_v030.clear()
	for key_value in snapshot.get("v030_detach_blocks", []) as Array:
		manual_detach_blocks_v030[str(key_value)] = true
	_refresh_editor_overlay_v030()


func _restart_build() -> void:
	manual_detach_blocks_v030.clear()
	_cancel_editor_tools_v030(false)
	super._restart_build()
	_refresh_editor_overlay_v030()


func _delete_selected() -> void:
	_cancel_editor_tools_v030(false)
	super._delete_selected()
	_refresh_editor_overlay_v030()


func _toggle_simulation() -> void:
	_cancel_editor_tools_v030(false)
	super._toggle_simulation()
	_refresh_editor_overlay_v030()
