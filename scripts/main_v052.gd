extends "res://scripts/main_v051.gd"

const VERSION_052 := "0.5.1-dev2"
const SPATIAL_PICK_RADIUS_V052 := 92.0

var parts_preview_container_v052: SubViewportContainer
var parts_preview_viewport_v052: SubViewport
var parts_preview_root_v052: Node3D
var parts_preview_camera_v052: Camera3D
var parts_preview_label_v052: Label


func _ready() -> void:
	super._ready()
	_refresh_parts_preview_v052()
	_status("v0.5.1 preview: item-aware transforms, restored 3D camera pan, open-jaw connector geometry and rendered Parts preview are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_052, text]


# -----------------------------------------------------------------------------
# Camera pan regression: v0.1.5 had real two-finger centroid pan, but its helper
# flattened the target to Y=4 on every event. That made vertical screen panning
# effectively impossible. Pan now follows camera RIGHT and camera UP in 3D.
# -----------------------------------------------------------------------------

func _pan_camera(screen_delta: Vector2) -> void:
	if camera == null:
		return
	var right: Vector3 = camera.global_transform.basis.x.normalized()
	var up: Vector3 = camera.global_transform.basis.y.normalized()
	var x_factor: float = -1.0 if reverse_pan_x else 1.0
	var y_factor: float = -1.0 if reverse_pan_y else 1.0
	var move_scale: float = camera_distance * 0.0027 * camera_sensitivity
	camera_target += (-right * screen_delta.x * x_factor + up * screen_delta.y * y_factor) * move_scale
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.y = clampf(camera_target.y, -80.0, 160.0)


# -----------------------------------------------------------------------------
# Connector visual redesign.
# Rounded capsule rails create an open fork mouth with no rectangular plug across
# the gap. The hub-side web stays solid; the outer jaw remains visibly open.
# -----------------------------------------------------------------------------

func _add_capsule_between_v052(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, radial_segments: int = 12) -> MeshInstance3D:
	var delta: Vector3 = b - a
	var length: float = delta.length()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(length + radius * 2.0, radius * 2.05)
	capsule.radial_segments = radial_segments
	capsule.rings = 4
	mesh_instance.mesh = capsule
	mesh_instance.material_override = material
	mesh_instance.position = (a + b) * 0.5
	if length > 0.001:
		mesh_instance.basis = Basis(Quaternion(Vector3.UP, delta / length))
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_real_socket_visual(parent: Node3D, angle_deg: int, color: Color) -> void:
	var direction: Vector3 = _slot_dir(angle_deg).normalized()
	var tangent: Vector3 = Vector3(-direction.z, 0.0, direction.x).normalized()
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.055))

	# Tapered-looking radial web: short, thick inner bridge only, never crossing
	# the fork mouth at the outside edge.
	_add_capsule_between_v052(parent, direction * 0.48, direction * 0.94, 0.17, main_mat, 12)
	_add_cylinder_visual(parent, 0.20, 0.30, direction * 0.88, edge_mat, 14)

	# Two independent rounded jaws. Their center gap stays visibly open all the
	# way through the mouth, matching the characteristic real K'NEX fork shape.
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var offset: Vector3 = tangent * (0.235 * side)
		_add_capsule_between_v052(parent, direction * 0.82 + offset, direction * 1.48 + offset, 0.105, main_mat, 12)
		_add_cylinder_visual(parent, 0.125, 0.30, direction * 1.49 + offset, edge_mat, 14)


func _add_spatial_socket_visual_v041(parent: Node3D, slot: int, color: Color) -> void:
	var direction: Vector3 = _slot_dir(slot).normalized()
	var normal: Vector3 = Vector3.BACK
	if absf(direction.dot(normal)) > 0.95:
		normal = Vector3.RIGHT
	var tangent: Vector3 = direction.cross(normal).normalized()
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.055))
	_add_capsule_between_v052(parent, direction * 0.48, direction * 0.94, 0.17, main_mat, 12)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var offset: Vector3 = tangent * (0.235 * side)
		_add_capsule_between_v052(parent, direction * 0.82 + offset, direction * 1.48 + offset, 0.105, main_mat, 12)
		_add_cylinder_visual(parent, 0.125, 0.30, direction * 1.49 + offset, edge_mat, 14)


# -----------------------------------------------------------------------------
# Spatial 11/14-point picking: prioritize the six out-of-plane socket markers in
# screen space before physical-body fallback. Their geometry can sit outside the
# broad central connector collision volume, so a marker tap must not depend on a
# body raycast landing first.
# -----------------------------------------------------------------------------

func _spatial_socket_candidates_v052(expected_body: RigidBody3D = null) -> Array:
	var result: Array = []
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		if str(point.get("type", "")) != "socket":
			continue
		if not _is_spatial_slot_v041(int(point.get("slot", -1))):
			continue
		if is_instance_valid(expected_body) and point.get("body") != expected_body:
			continue
		result.append(point)
	return result


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	if editor_mode_v032 == EDITOR_ATTACH_032 and attach_mode in [0, 2]:
		var spatial: Dictionary = _nearest_projected_candidate_v030(_spatial_socket_candidates_v052(), screen_pos, SPATIAL_PICK_RADIUS_V052)
		if not spatial.is_empty() and _allowed_initial_point_v035(spatial):
			return spatial
	return super._pick_initial_attach_point_v035(screen_pos)


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	var expected: Array = _expected_target_types_v035(str(source.get("type", "")))
	if "socket" in expected:
		var spatial_candidates: Array = []
		for point_value in _spatial_socket_candidates_v052():
			var point: Dictionary = point_value as Dictionary
			if point.get("body") != source.get("body") and _attach_target_is_available_v040(source, point):
				spatial_candidates.append(point)
		var spatial: Dictionary = _nearest_projected_candidate_v030(spatial_candidates, screen_pos, SPATIAL_PICK_RADIUS_V052)
		if not spatial.is_empty():
			return spatial
	return super._pick_attach_target_v035(screen_pos, source)


# -----------------------------------------------------------------------------
# Runtime-rendered Parts preview. No checked-in screenshots are needed: GitHub
# source is sufficient because the app renders its own procedural part meshes in
# a small isolated SubViewport above the cards.
# -----------------------------------------------------------------------------

func _build_parts_browser_v050() -> void:
	super._build_parts_browser_v050()
	_install_parts_preview_v052()


func _install_parts_preview_v052() -> void:
	if parts_panel_v050 == null or parts_preview_container_v052 != null:
		return
	var box: VBoxContainer = _find_first_vbox_v050(parts_panel_v050)
	if box == null:
		return
	var preview_shell: VBoxContainer = VBoxContainer.new()
	preview_shell.custom_minimum_size.y = 156.0
	preview_shell.add_theme_constant_override("separation", 2)
	box.add_child(preview_shell)
	box.move_child(preview_shell, mini(2, box.get_child_count() - 1))
	parts_preview_label_v052 = Label.new()
	parts_preview_label_v052.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parts_preview_label_v052.add_theme_font_size_override("font_size", 14)
	parts_preview_label_v052.add_theme_color_override("font_color", Color(0.74, 0.84, 0.92))
	preview_shell.add_child(parts_preview_label_v052)

	parts_preview_container_v052 = SubViewportContainer.new()
	parts_preview_container_v052.custom_minimum_size = Vector2(0.0, 128.0)
	parts_preview_container_v052.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_preview_container_v052.stretch = true
	preview_shell.add_child(parts_preview_container_v052)
	parts_preview_viewport_v052 = SubViewport.new()
	parts_preview_viewport_v052.size = Vector2i(560, 180)
	parts_preview_viewport_v052.transparent_bg = true
	parts_preview_viewport_v052.own_world_3d = true
	parts_preview_viewport_v052.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parts_preview_container_v052.add_child(parts_preview_viewport_v052)
	parts_preview_root_v052 = Node3D.new()
	parts_preview_viewport_v052.add_child(parts_preview_root_v052)
	parts_preview_camera_v052 = Camera3D.new()
	parts_preview_camera_v052.position = Vector3(0.0, 4.1, 8.2)
	parts_preview_camera_v052.look_at_from_position(parts_preview_camera_v052.position, Vector3.ZERO, Vector3.UP)
	parts_preview_camera_v052.fov = 36.0
	parts_preview_root_v052.add_child(parts_preview_camera_v052)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	key.light_energy = 1.45
	parts_preview_root_v052.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28.0, 145.0, 0.0)
	fill.light_energy = 0.70
	parts_preview_root_v052.add_child(fill)


func _clear_parts_preview_v052() -> void:
	if parts_preview_root_v052 == null:
		return
	for child_value in parts_preview_root_v052.get_children():
		var child: Node = child_value as Node
		if child == parts_preview_camera_v052 or child is Light3D:
			continue
		parts_preview_root_v052.remove_child(child)
		child.queue_free()


func _refresh_parts_preview_v052() -> void:
	if parts_preview_root_v052 == null:
		return
	_clear_parts_preview_v052()
	if parts_tab_v050 == 0:
		var index: int = clampi(selected_rod_type, 0, rod_defs.size() - 1)
		var definition: Dictionary = rod_defs[index] as Dictionary
		if parts_preview_label_v052 != null:
			parts_preview_label_v052.text = "%s  •  %.1f mm" % [str(definition.get("name", "Rod")), float(definition.get("actual_mm", 0.0))]
		var rod: RigidBody3D = RigidBody3D.new()
		rod.freeze = true
		parts_preview_root_v052.add_child(rod)
		_rebuild_rod(rod, index, float(definition.get("actual_mm", 0.0)) / 10.0)
		rod.rotation_degrees = Vector3(72.0, 0.0, 90.0)
		var length_world: float = float(definition.get("actual_mm", 0.0)) / 10.0
		parts_preview_camera_v052.position = Vector3(0.0, maxf(3.4, length_world * 0.25), maxf(7.0, length_world * 0.72))
	else:
		var index: int = clampi(selected_connector_type, 0, connector_defs.size() - 1)
		var definition: Dictionary = connector_defs[index] as Dictionary
		if parts_preview_label_v052 != null:
			parts_preview_label_v052.text = str(definition.get("name", "Connector"))
		if index == o_ring_index or str(definition.get("special", "")) == "o_ring":
			var visual: MeshInstance3D = MeshInstance3D.new()
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = O_RING_INNER_RADIUS_V040
			torus.outer_radius = O_RING_OUTER_RADIUS
			torus.rings = 24
			torus.ring_segments = 16
			visual.mesh = torus
			visual.material_override = _mat(definition.get("color", Color("343b44")) as Color)
			parts_preview_root_v052.add_child(visual)
		else:
			var connector: RigidBody3D = RigidBody3D.new()
			connector.freeze = true
			parts_preview_root_v052.add_child(connector)
			_rebuild_connector(connector, index)
			connector.rotation_degrees = Vector3(64.0, 0.0, 22.0)
		parts_preview_camera_v052.position = Vector3(0.0, 4.0, 7.2)
	parts_preview_camera_v052.look_at_from_position(parts_preview_camera_v052.position, Vector3.ZERO, Vector3.UP)


func _refresh_parts_browser_v050() -> void:
	super._refresh_parts_browser_v050()
	_refresh_parts_preview_v052()


func _choose_part_v050(index_value: int) -> void:
	super._choose_part_v050(index_value)
	_refresh_parts_preview_v052()


func _set_parts_tab_v050(tab: int) -> void:
	super._set_parts_tab_v050(tab)
	_refresh_parts_preview_v052()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nPARTS: the browser now renders the currently chosen rod/connector from the same procedural 3D geometry used by the build. Compact R/C previous-next controls remain available for fast cycling.\n\nCONNECTORS: fork mouths are open and the jaws use rounded rails/tips instead of a closed rectangular stop across the gap. Spatial 11/14-point sockets receive a larger marker-first picking zone.\n\nTRANSFORMS: ITEM is default and shows only physically valid axes; WORLD explicitly transforms the connected construction.\n\nATTACH: CROSS uses bold + markers and the old tether line is removed.\n\nCAMERA: one finger orbits; two fingers pinch to zoom AND pan in screen X/Y, including true vertical view panning." % VERSION_052
