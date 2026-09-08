extends "res://scripts/main_v042.gd"

const VERSION_050 := "0.5.0"
const BUILDS_DIR_V050 := "user://connex_builds"
const AUTOSAVE_PATH_V050 := "user://connex_autosave.connex"
const SESSION_MARKER_V050 := "user://connex_session_active.flag"
const SAVE_FORMAT_V050 := 2
const AUTOSAVE_DELAY_MS_V050 := 350
const SPATIAL_CELL_V050 := 4.0

var parts_button_v050: Button
var parts_panel_v050: PanelContainer
var parts_grid_v050: GridContainer
var parts_title_v050: Label
var parts_rods_button_v050: Button
var parts_connectors_button_v050: Button
var parts_tab_v050: int = 0
var part_card_buttons_v050: Array = []

var builds_button_v050: Button
var builds_panel_v050: PanelContainer
var build_name_v050: LineEdit
var builds_list_v050: ItemList
var build_paths_v050: Array = []
var build_load_button_v050: Button
var build_delete_button_v050: Button
var recover_button_v050: Button
var recovery_label_v050: Label
var previous_unclean_v050: bool = false
var recovery_pending_v050: bool = false
var session_tracking_v050: bool = false

var physics_gravity_v050: float = 9.81
var physics_friction_v050: float = 0.72
var physics_bounce_v050: float = 0.04
var physics_linear_damp_v050: float = 0.20
var physics_angular_damp_v050: float = 0.34
var physics_gravity_label_v050: Label
var physics_friction_label_v050: Label
var physics_bounce_label_v050: Label
var physics_linear_label_v050: Label
var physics_angular_label_v050: Label
var shared_physics_material_v050: PhysicsMaterial

var primitive_mesh_cache_v050: Dictionary = {}

var attach_spatial_dirty_v050: bool = true
var attach_spatial_cells_v050: Dictionary = {}
var attach_points_by_body_v050: Dictionary = {}
var attach_overlay_dirty_v050: bool = true
var last_overlay_visibility_signature_v050: String = ""

var autosave_ready_v050: bool = false
var autosave_pending_v050: bool = false
var autosave_due_ms_v050: int = 0


func _ready() -> void:
	session_tracking_v050 = DisplayServer.get_name() != "headless"
	if session_tracking_v050:
		previous_unclean_v050 = FileAccess.file_exists(SESSION_MARKER_V050)
	super._ready()
	_build_parts_browser_v050()
	_build_builds_panel_v050()
	_add_options_sections_v050()
	_clean_bottom_palette_v050()
	_apply_physics_settings_v050()
	_refresh_parts_browser_v050()
	_refresh_build_list_v050()
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	if session_tracking_v050:
		_write_session_marker_v050()
		recovery_pending_v050 = previous_unclean_v050 and FileAccess.file_exists(AUTOSAVE_PATH_V050)
		autosave_ready_v050 = not recovery_pending_v050
		if recovery_pending_v050:
			_show_builds_panel_v050(true)
			_status("Recovery available — the previous session did not close cleanly. Restore the autosave or archive it and continue.")
	else:
		autosave_ready_v050 = false
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_050)
	if not recovery_pending_v050:
		_status("Parts browser, named saves, crash recovery, physics controls and build-performance improvements are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_050, text]


# -----------------------------------------------------------------------------
# Persistent settings: retain every inherited camera/UI setting and add physics.
# -----------------------------------------------------------------------------

func _load_settings() -> void:
	super._load_settings()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	physics_gravity_v050 = clampf(float(cfg.get_value("physics", "gravity", 9.81)), 0.0, 24.0)
	physics_friction_v050 = clampf(float(cfg.get_value("physics", "friction", 0.72)), 0.0, 1.0)
	physics_bounce_v050 = clampf(float(cfg.get_value("physics", "bounce", 0.04)), 0.0, 0.60)
	physics_linear_damp_v050 = clampf(float(cfg.get_value("physics", "linear_damp", 0.20)), 0.0, 2.0)
	physics_angular_damp_v050 = clampf(float(cfg.get_value("physics", "angular_damp", 0.34)), 0.0, 2.0)


func _save_settings() -> void:
	super._save_settings()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("physics", "gravity", physics_gravity_v050)
	cfg.set_value("physics", "friction", physics_friction_v050)
	cfg.set_value("physics", "bounce", physics_bounce_v050)
	cfg.set_value("physics", "linear_damp", physics_linear_damp_v050)
	cfg.set_value("physics", "angular_damp", physics_angular_damp_v050)
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		_status("Could not save physics options (%s)" % error_string(err))


# -----------------------------------------------------------------------------
# Primitive mesh caching. Repeated socket jaws/ribs/cylinders now share immutable
# mesh Resources instead of allocating an identical mesh for every piece.
# -----------------------------------------------------------------------------

func _box_mesh_v050(size: Vector3) -> BoxMesh:
	var key: String = "box:%.4f:%.4f:%.4f" % [size.x, size.y, size.z]
	if primitive_mesh_cache_v050.has(key):
		return primitive_mesh_cache_v050[key] as BoxMesh
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	primitive_mesh_cache_v050[key] = mesh
	return mesh


func _cylinder_mesh_v050(radius: float, height: float, segments: int) -> CylinderMesh:
	var key: String = "cyl:%.4f:%.4f:%d" % [radius, height, segments]
	if primitive_mesh_cache_v050.has(key):
		return primitive_mesh_cache_v050[key] as CylinderMesh
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	primitive_mesh_cache_v050[key] = mesh
	return mesh


func _add_box_visual(parent: Node3D, size: Vector3, position: Vector3, rotation_y: float, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = _box_mesh_v050(size)
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder_visual(parent: Node3D, radius: float, height: float, position: Vector3, material: Material, segments: int = 14) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = _cylinder_mesh_v050(radius, height, segments)
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


# -----------------------------------------------------------------------------
# Physics controls. These modify simulation behavior without changing build
# geometry, connection topology or the permanent package/update identity.
# -----------------------------------------------------------------------------

func _physics_material_v050() -> PhysicsMaterial:
	if shared_physics_material_v050 == null:
		shared_physics_material_v050 = PhysicsMaterial.new()
	shared_physics_material_v050.friction = physics_friction_v050
	shared_physics_material_v050.bounce = physics_bounce_v050
	return shared_physics_material_v050


func _apply_physics_to_body_v050(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return
	body.gravity_scale = physics_gravity_v050 / 9.81 if physics_gravity_v050 > 0.0 else 0.0
	body.linear_damp = physics_linear_damp_v050
	body.angular_damp = physics_angular_damp_v050
	body.physics_material_override = _physics_material_v050()


func _apply_physics_settings_v050() -> void:
	_physics_material_v050()
	for body_value in bodies:
		_apply_physics_to_body_v050(body_value as RigidBody3D)
	for ring_value in o_ring_stops:
		_apply_physics_to_body_v050(ring_value as RigidBody3D)
	var ground: StaticBody3D = get_node_or_null("Ground") as StaticBody3D
	if ground != null:
		ground.physics_material_override = _physics_material_v050()
	_refresh_physics_labels_v050()


func _make_connector(def_index: int, xform: Transform3D) -> RigidBody3D:
	var body: RigidBody3D = super._make_connector(def_index, xform)
	_apply_physics_to_body_v050(body)
	return body


func _make_rod(def_index: int, start: Vector3, finish: Vector3) -> RigidBody3D:
	var body: RigidBody3D = super._make_rod(def_index, start, finish)
	_apply_physics_to_body_v050(body)
	return body


func _make_o_ring_body(transform: Transform3D) -> RigidBody3D:
	var ring: RigidBody3D = super._make_o_ring_body(transform)
	_apply_physics_to_body_v050(ring)
	return ring


func _physics_slider_row_v050(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float, callback: Callable) -> Label:
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(380.0, 28.0)
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return label


func _on_gravity_v050(value: float) -> void:
	physics_gravity_v050 = value
	_apply_physics_settings_v050()
	_save_settings()


func _on_friction_v050(value: float) -> void:
	physics_friction_v050 = value
	_apply_physics_settings_v050()
	_save_settings()


func _on_bounce_v050(value: float) -> void:
	physics_bounce_v050 = value
	_apply_physics_settings_v050()
	_save_settings()


func _on_linear_damp_v050(value: float) -> void:
	physics_linear_damp_v050 = value
	_apply_physics_settings_v050()
	_save_settings()


func _on_angular_damp_v050(value: float) -> void:
	physics_angular_damp_v050 = value
	_apply_physics_settings_v050()
	_save_settings()


func _reset_physics_v050() -> void:
	physics_gravity_v050 = 9.81
	physics_friction_v050 = 0.72
	physics_bounce_v050 = 0.04
	physics_linear_damp_v050 = 0.20
	physics_angular_damp_v050 = 0.34
	_apply_physics_settings_v050()
	_save_settings()
	_status("Physics reset to Connex defaults")


func _refresh_physics_labels_v050() -> void:
	if physics_gravity_label_v050 != null:
		physics_gravity_label_v050.text = "Gravity: %.2f m/s²" % physics_gravity_v050
	if physics_friction_label_v050 != null:
		physics_friction_label_v050.text = "Surface friction: %.2f" % physics_friction_v050
	if physics_bounce_label_v050 != null:
		physics_bounce_label_v050.text = "Bounce: %.2f" % physics_bounce_v050
	if physics_linear_label_v050 != null:
		physics_linear_label_v050.text = "Linear damping: %.2f" % physics_linear_damp_v050
	if physics_angular_label_v050 != null:
		physics_angular_label_v050.text = "Angular damping: %.2f" % physics_angular_damp_v050


# -----------------------------------------------------------------------------
# UI additions: Parts becomes the only part-selection surface in the bottom bar;
# Saves/Recovery and Physics live behind Options to keep the editor uncluttered.
# -----------------------------------------------------------------------------

func _find_first_vbox_v050(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node as VBoxContainer
	for child_value in node.get_children():
		var found: VBoxContainer = _find_first_vbox_v050(child_value as Node)
		if found != null:
			return found
	return null


func _add_options_sections_v050() -> void:
	if options_panel == null:
		return
	var box: VBoxContainer = _find_first_vbox_v050(options_panel)
	if box == null:
		return
	box.add_child(HSeparator.new())
	box.add_child(_section_label("BUILDS / RECOVERY"))
	builds_button_v050 = _ui_button("Open Saves & Recovery", func() -> void: _show_builds_panel_v050(false), true)
	box.add_child(builds_button_v050)
	box.add_child(HSeparator.new())
	box.add_child(_section_label("PHYSICS"))
	physics_gravity_label_v050 = _physics_slider_row_v050(box, "Gravity", 0.0, 24.0, 0.25, physics_gravity_v050, _on_gravity_v050)
	physics_friction_label_v050 = _physics_slider_row_v050(box, "Surface friction", 0.0, 1.0, 0.02, physics_friction_v050, _on_friction_v050)
	physics_bounce_label_v050 = _physics_slider_row_v050(box, "Bounce", 0.0, 0.60, 0.01, physics_bounce_v050, _on_bounce_v050)
	physics_linear_label_v050 = _physics_slider_row_v050(box, "Linear damping", 0.0, 2.0, 0.02, physics_linear_damp_v050, _on_linear_damp_v050)
	physics_angular_label_v050 = _physics_slider_row_v050(box, "Angular damping", 0.0, 2.0, 0.02, physics_angular_damp_v050, _on_angular_damp_v050)
	box.add_child(_ui_button("Reset Physics Defaults", _reset_physics_v050))
	_refresh_physics_labels_v050()


func _clean_bottom_palette_v050() -> void:
	if bottom_panel == null or rod_label == null:
		return
	var row: HBoxContainer = rod_label.get_parent() as HBoxContainer
	if row == null:
		return
	for child_value in row.get_children():
		var button: Button = child_value as Button
		if button != null and button.text in ["◀ Rod", "Rod ▶", "◀ Conn", "Conn ▶"]:
			button.visible = false
	parts_button_v050 = _ui_button("PARTS", _toggle_parts_panel_v050, true)
	parts_button_v050.custom_minimum_size.x = 120.0
	row.add_child(parts_button_v050)
	row.move_child(parts_button_v050, 0)
	rod_label.custom_minimum_size.x = 185.0
	connector_label.custom_minimum_size.x = 220.0
	_rename_palette_title_v050(bottom_panel)


func _rename_palette_title_v050(node: Node) -> void:
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child is Label and (child as Label).text == "PARTS / CONNECTION MODE":
			(child as Label).text = "PARTS / MODE"
		_rename_palette_title_v050(child)


# -----------------------------------------------------------------------------
# Parts browser.
# -----------------------------------------------------------------------------

func _build_parts_browser_v050() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	parts_panel_v050 = PanelContainer.new()
	parts_panel_v050.anchor_left = 0.16
	parts_panel_v050.anchor_right = 0.84
	parts_panel_v050.anchor_top = 0.10
	parts_panel_v050.anchor_bottom = 0.88
	parts_panel_v050.add_theme_stylebox_override("panel", _panel_style(0.99, 16, 0.55))
	parts_panel_v050.visible = false
	layer.add_child(parts_panel_v050)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	parts_panel_v050.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	parts_title_v050 = Label.new()
	parts_title_v050.text = "PARTS BROWSER"
	parts_title_v050.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parts_title_v050.add_theme_font_size_override("font_size", 22)
	box.add_child(parts_title_v050)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	parts_rods_button_v050 = _ui_button("RODS", func() -> void: _set_parts_tab_v050(0), true)
	parts_connectors_button_v050 = _ui_button("CONNECTORS", func() -> void: _set_parts_tab_v050(1), true)
	tabs.add_child(parts_rods_button_v050)
	tabs.add_child(parts_connectors_button_v050)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	parts_grid_v050 = GridContainer.new()
	parts_grid_v050.columns = 3
	parts_grid_v050.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_grid_v050.add_theme_constant_override("h_separation", 8)
	parts_grid_v050.add_theme_constant_override("v_separation", 8)
	scroll.add_child(parts_grid_v050)
	var note: Label = Label.new()
	note.text = "Choosing a card changes the NEXT part only. It never silently converts the currently selected construction piece."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.66, 0.76, 0.84))
	box.add_child(note)
	box.add_child(_ui_button("Done", _toggle_parts_panel_v050, true))


func _set_parts_tab_v050(tab: int) -> void:
	parts_tab_v050 = clampi(tab, 0, 1)
	_refresh_parts_browser_v050()


func _part_card_style_v050(color: Color, selected: bool) -> StyleBoxFlat:
	var base: Color = Color(0.075, 0.085, 0.105).lerp(color, 0.32 if not selected else 0.48)
	var style: StyleBoxFlat = _button_style(base, 10)
	style.border_color = Color(0.38, 0.85, 1.0, 0.95) if selected else Color(0.34, 0.55, 0.70, 0.30)
	style.set_border_width_all(2 if selected else 1)
	return style


func _refresh_parts_browser_v050() -> void:
	if parts_grid_v050 == null:
		return
	for child_value in parts_grid_v050.get_children():
		(child_value as Node).queue_free()
	part_card_buttons_v050.clear()
	var defs: Array = rod_defs if parts_tab_v050 == 0 else connector_defs
	for i in range(defs.size()):
		var definition: Dictionary = defs[i] as Dictionary
		var name_value: String = str(definition.get("name", "Part"))
		var detail: String = ""
		if parts_tab_v050 == 0:
			detail = "%.1f mm" % float(definition.get("actual_mm", 0.0))
		else:
			var special: String = str(definition.get("special", ""))
			detail = "Axle stop" if special == "o_ring" else "%d connection points" % (definition.get("slots", []) as Array).size()
		var button: Button = _ui_button("%s\n%s" % [name_value, detail], func(index_value: int = i) -> void: _choose_part_v050(index_value), false)
		button.custom_minimum_size = Vector2(180.0, 76.0)
		button.add_theme_font_size_override("font_size", 14)
		var selected: bool = i == (selected_rod_type if parts_tab_v050 == 0 else selected_connector_type)
		var color: Color = definition.get("color", Color(0.4, 0.5, 0.6)) as Color
		button.add_theme_stylebox_override("normal", _part_card_style_v050(color, selected))
		button.add_theme_stylebox_override("hover", _part_card_style_v050(color.lightened(0.10), selected))
		parts_grid_v050.add_child(button)
		part_card_buttons_v050.append(button)
	parts_rods_button_v050.text = ("● " if parts_tab_v050 == 0 else "") + "RODS"
	parts_connectors_button_v050.text = ("● " if parts_tab_v050 == 1 else "") + "CONNECTORS"


func _choose_part_v050(index_value: int) -> void:
	if simulating:
		_status("Return to BUILD before changing the next part")
		return
	if parts_tab_v050 == 0:
		selected_rod_type = clampi(index_value, 0, rod_defs.size() - 1)
		_status("Next rod: %s" % str(rod_defs[selected_rod_type].get("name", "Rod")))
	else:
		selected_connector_type = clampi(index_value, 0, connector_defs.size() - 1)
		_status("Next connector: %s" % str(connector_defs[selected_connector_type].get("name", "Connector")))
	_update_ui()
	_refresh_parts_browser_v050()


func _toggle_parts_panel_v050() -> void:
	if parts_panel_v050 == null:
		return
	parts_panel_v050.visible = not parts_panel_v050.visible
	if parts_panel_v050.visible:
		if builds_panel_v050 != null:
			builds_panel_v050.visible = false
		if options_panel != null:
			options_panel.visible = false
		if help_panel != null:
			help_panel.visible = false
		_refresh_parts_browser_v050()
	attach_overlay_dirty_v050 = true


# -----------------------------------------------------------------------------
# Named saves + crash recovery.
# -----------------------------------------------------------------------------

func _ensure_builds_dir_v050() -> bool:
	var root: DirAccess = DirAccess.open("user://")
	if root == null:
		return false
	if not root.dir_exists("connex_builds"):
		return root.make_dir("connex_builds") == OK
	return true


func _safe_build_name_v050(name_value: String) -> String:
	var safe: String = name_value.strip_edges()
	for bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(str(bad), "_")
	while "  " in safe:
		safe = safe.replace("  ", " ")
	if safe.is_empty():
		safe = "Build"
	if safe.length() > 48:
		safe = safe.substr(0, 48)
	return safe


func _save_bundle_v050(name_value: String) -> Dictionary:
	return {
		"format": SAVE_FORMAT_V050,
		"app_version": VERSION_050,
		"name": name_value,
		"saved_unix": Time.get_unix_time_from_system(),
		"snapshot": _capture_state(),
		"camera_target": camera_target,
		"camera_distance": camera_distance,
		"camera_yaw": camera_yaw,
		"camera_pitch": camera_pitch,
		"attach_mode": attach_mode,
	}


func _write_variant_file_v050(path: String, value: Variant) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(var_to_str(value))
	file.flush()
	file.close()
	return true


func _read_variant_file_v050(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return null
	return str_to_var(text)


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


func _restore_bundle_v050(bundle: Dictionary, source_label: String) -> bool:
	if int(bundle.get("format", 0)) < 1 or not (bundle.get("snapshot") is Dictionary):
		_status("Could not load %s — unsupported or damaged save" % source_label)
		return false
	var snapshot: Dictionary = bundle.get("snapshot", {}) as Dictionary
	_restore_state(snapshot)
	camera_target = bundle.get("camera_target", camera_target) as Vector3
	camera_distance = float(bundle.get("camera_distance", camera_distance))
	camera_yaw = float(bundle.get("camera_yaw", camera_yaw))
	camera_pitch = float(bundle.get("camera_pitch", camera_pitch))
	attach_mode = clampi(int(bundle.get("attach_mode", attach_mode)), 0, 2)
	# Loading establishes a new Undo root without triggering auto-fuse. That is
	# important for intentionally detached-but-overlapping saved constructions.
	state_history.clear()
	state_history.append(_capture_state())
	state_index = 0
	_set_editor_mode_v032(EDITOR_CREATE_032, false)
	attach_spatial_dirty_v050 = true
	attach_overlay_dirty_v050 = true
	_apply_physics_settings_v050()
	_refresh_selection_highlight()
	_update_ui()
	_update_camera()
	return true


func _selected_build_path_v050() -> String:
	if builds_list_v050 == null:
		return ""
	var selected: PackedInt32Array = builds_list_v050.get_selected_items()
	if selected.is_empty():
		return ""
	var index: int = int(selected[0])
	if index < 0 or index >= build_paths_v050.size():
		return ""
	return str(build_paths_v050[index])


func _load_selected_build_v050() -> void:
	var path: String = _selected_build_path_v050()
	if path.is_empty():
		return
	var value: Variant = _read_variant_file_v050(path)
	if not (value is Dictionary):
		_status("Selected save is unreadable")
		return
	var bundle: Dictionary = value as Dictionary
	if _restore_bundle_v050(bundle, str(bundle.get("name", "build"))):
		builds_panel_v050.visible = false
		autosave_ready_v050 = true
		recovery_pending_v050 = false
		_schedule_autosave_v050()
		_status("Loaded build: %s" % str(bundle.get("name", "Build")))


func _delete_selected_build_v050() -> void:
	var path: String = _selected_build_path_v050()
	if path.is_empty():
		return
	var global_path: String = ProjectSettings.globalize_path(path)
	var err: Error = DirAccess.remove_absolute(global_path)
	if err != OK:
		_status("Could not delete selected save")
		return
	_refresh_build_list_v050()
	_status("Save deleted")


func _write_autosave_v050() -> bool:
	if simulating:
		return false
	var bundle: Dictionary = _save_bundle_v050("Autosave")
	var ok: bool = _write_variant_file_v050(AUTOSAVE_PATH_V050, bundle)
	if ok:
		autosave_pending_v050 = false
	return ok


func _schedule_autosave_v050() -> void:
	if not autosave_ready_v050 or not session_tracking_v050:
		return
	autosave_pending_v050 = true
	autosave_due_ms_v050 = Time.get_ticks_msec() + AUTOSAVE_DELAY_MS_V050


func _restore_autosave_v050() -> void:
	var value: Variant = _read_variant_file_v050(AUTOSAVE_PATH_V050)
	if not (value is Dictionary):
		_status("Autosave is missing or unreadable")
		return
	if _restore_bundle_v050(value as Dictionary, "autosave"):
		recovery_pending_v050 = false
		autosave_ready_v050 = true
		builds_panel_v050.visible = false
		_schedule_autosave_v050()
		_status("Autosave recovered")


func _archive_recovery_v050() -> void:
	if not FileAccess.file_exists(AUTOSAVE_PATH_V050):
		recovery_pending_v050 = false
		autosave_ready_v050 = true
		return
	if not _ensure_builds_dir_v050():
		_status("Could not archive recovery save")
		return
	var source: FileAccess = FileAccess.open(AUTOSAVE_PATH_V050, FileAccess.READ)
	if source == null:
		return
	var content: String = source.get_as_text()
	source.close()
	var archive_name: String = "Recovery_%d.connex" % int(Time.get_unix_time_from_system())
	var target: FileAccess = FileAccess.open("%s/%s" % [BUILDS_DIR_V050, archive_name], FileAccess.WRITE)
	if target != null:
		target.store_string(content)
		target.close()
	recovery_pending_v050 = false
	autosave_ready_v050 = true
	_refresh_build_list_v050()
	_schedule_autosave_v050()
	_status("Previous autosave archived in Saves; current build will autosave normally")


func _refresh_build_list_v050() -> void:
	if builds_list_v050 == null:
		return
	builds_list_v050.clear()
	build_paths_v050.clear()
	_ensure_builds_dir_v050()
	var dir: DirAccess = DirAccess.open(BUILDS_DIR_V050)
	if dir != null:
		var files: PackedStringArray = dir.get_files()
		files.sort()
		for file_name in files:
			if not file_name.to_lower().ends_with(".connex"):
				continue
			var path: String = "%s/%s" % [BUILDS_DIR_V050, file_name]
			var display_name: String = file_name.trim_suffix(".connex")
			var value: Variant = _read_variant_file_v050(path)
			if value is Dictionary:
				display_name = str((value as Dictionary).get("name", display_name))
			builds_list_v050.add_item(display_name)
			build_paths_v050.append(path)
	if build_load_button_v050 != null:
		build_load_button_v050.disabled = true
	if build_delete_button_v050 != null:
		build_delete_button_v050.disabled = true
	if recover_button_v050 != null:
		recover_button_v050.disabled = not FileAccess.file_exists(AUTOSAVE_PATH_V050)
	if recovery_label_v050 != null:
		if recovery_pending_v050:
			recovery_label_v050.text = "RECOVERY FOUND: the previous session did not close cleanly. Restore it, or Archive Recovery and continue with the current build."
		elif FileAccess.file_exists(AUTOSAVE_PATH_V050):
			recovery_label_v050.text = "Last autosave is available as an additional recovery point."
		else:
			recovery_label_v050.text = "Autosave starts after the first build change."


func _on_build_selected_v050(_index: int) -> void:
	if build_load_button_v050 != null:
		build_load_button_v050.disabled = false
	if build_delete_button_v050 != null:
		build_delete_button_v050.disabled = false


func _build_builds_panel_v050() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	builds_panel_v050 = PanelContainer.new()
	builds_panel_v050.anchor_left = 0.24
	builds_panel_v050.anchor_right = 0.76
	builds_panel_v050.anchor_top = 0.10
	builds_panel_v050.anchor_bottom = 0.88
	builds_panel_v050.add_theme_stylebox_override("panel", _panel_style(0.995, 16, 0.60))
	builds_panel_v050.visible = false
	layer.add_child(builds_panel_v050)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	builds_panel_v050.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "SAVES & RECOVERY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	recovery_label_v050 = Label.new()
	recovery_label_v050.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recovery_label_v050.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recovery_label_v050.add_theme_color_override("font_color", Color(0.82, 0.86, 0.64))
	box.add_child(recovery_label_v050)
	var recovery_row: HBoxContainer = HBoxContainer.new()
	recovery_row.add_theme_constant_override("separation", 6)
	box.add_child(recovery_row)
	recover_button_v050 = _ui_button("Restore Autosave", _restore_autosave_v050, true)
	recovery_row.add_child(recover_button_v050)
	recovery_row.add_child(_ui_button("Archive Recovery", _archive_recovery_v050))
	box.add_child(HSeparator.new())
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	box.add_child(name_row)
	build_name_v050 = LineEdit.new()
	build_name_v050.placeholder_text = "Build name"
	build_name_v050.text = "Build"
	build_name_v050.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_name_v050.custom_minimum_size.y = 44.0
	name_row.add_child(build_name_v050)
	name_row.add_child(_ui_button("Save Current", _save_named_build_v050, true))
	builds_list_v050 = ItemList.new()
	builds_list_v050.size_flags_vertical = Control.SIZE_EXPAND_FILL
	builds_list_v050.custom_minimum_size.y = 220.0
	builds_list_v050.item_selected.connect(_on_build_selected_v050)
	box.add_child(builds_list_v050)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	box.add_child(action_row)
	build_load_button_v050 = _ui_button("Load Selected", _load_selected_build_v050, true)
	build_delete_button_v050 = _ui_button("Delete Selected", _delete_selected_build_v050)
	action_row.add_child(build_load_button_v050)
	action_row.add_child(build_delete_button_v050)
	box.add_child(_ui_button("Close", _close_builds_panel_v050))
	_refresh_build_list_v050()


func _show_builds_panel_v050(from_recovery: bool = false) -> void:
	if builds_panel_v050 == null:
		return
	builds_panel_v050.visible = true
	if options_panel != null:
		options_panel.visible = false
	if help_panel != null:
		help_panel.visible = false
	if parts_panel_v050 != null:
		parts_panel_v050.visible = false
	if from_recovery:
		recovery_pending_v050 = true
	_refresh_build_list_v050()
	attach_overlay_dirty_v050 = true


func _close_builds_panel_v050() -> void:
	if recovery_pending_v050:
		_archive_recovery_v050()
	if builds_panel_v050 != null:
		builds_panel_v050.visible = false
	attach_overlay_dirty_v050 = true


func _write_session_marker_v050() -> void:
	var file: FileAccess = FileAccess.open(SESSION_MARKER_V050, FileAccess.WRITE)
	if file != null:
		file.store_string(str(Time.get_unix_time_from_system()))
		file.close()


func _clear_session_marker_v050() -> void:
	if FileAccess.file_exists(SESSION_MARKER_V050):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_MARKER_V050))


# -----------------------------------------------------------------------------
# Attachment spatial index and dirty overlay rebuilding.
# -----------------------------------------------------------------------------

func _spatial_key_v050(point: Vector3) -> String:
	return "%d:%d:%d" % [int(floor(point.x / SPATIAL_CELL_V050)), int(floor(point.y / SPATIAL_CELL_V050)), int(floor(point.z / SPATIAL_CELL_V050))]


func _rebuild_attach_spatial_index_v050() -> void:
	attach_spatial_cells_v050.clear()
	attach_points_by_body_v050.clear()
	for point_value in _all_attach_points_v032():
		var point: Dictionary = point_value as Dictionary
		var body: RigidBody3D = point.get("body") as RigidBody3D
		if not is_instance_valid(body):
			continue
		var world_point: Vector3 = point.get("point", body.global_position) as Vector3
		var cell_key: String = _spatial_key_v050(world_point)
		if not attach_spatial_cells_v050.has(cell_key):
			attach_spatial_cells_v050[cell_key] = []
		(attach_spatial_cells_v050[cell_key] as Array).append(point)
		var body_key: int = body.get_instance_id()
		if not attach_points_by_body_v050.has(body_key):
			attach_points_by_body_v050[body_key] = []
		(attach_points_by_body_v050[body_key] as Array).append(point)
	attach_spatial_dirty_v050 = false


func _ensure_attach_spatial_index_v050() -> void:
	if attach_spatial_dirty_v050:
		_rebuild_attach_spatial_index_v050()


func _indexed_body_points_v050(body: RigidBody3D) -> Array:
	if not is_instance_valid(body):
		return []
	_ensure_attach_spatial_index_v050()
	return (attach_points_by_body_v050.get(body.get_instance_id(), []) as Array).duplicate(false)


func _pick_initial_attach_point_v035(screen_pos: Vector2) -> Dictionary:
	if editor_mode_v032 == EDITOR_ATTACH_032:
		var hit: Dictionary = _raycast_piece(screen_pos)
		if not hit.is_empty():
			var body: RigidBody3D = hit.get("collider") as RigidBody3D
			if is_instance_valid(body):
				var indexed: Array = []
				for point_value in _indexed_body_points_v050(body):
					var point: Dictionary = point_value as Dictionary
					if _allowed_initial_point_v035(point):
						indexed.append(point)
				var picked: Dictionary = _nearest_projected_candidate_v030(indexed, screen_pos, ATTACH_PICK_RADIUS_V040)
				if not picked.is_empty():
					return picked
	return super._pick_initial_attach_point_v035(screen_pos)


func _pick_attach_target_v035(screen_pos: Vector2, source: Dictionary) -> Dictionary:
	var expected: Array = _expected_target_types_v035(str(source.get("type", "")))
	if expected.is_empty() or "rod_body" in expected:
		return super._pick_attach_target_v035(screen_pos, source)
	var hit: Dictionary = _raycast_piece(screen_pos)
	if not hit.is_empty():
		var body: RigidBody3D = hit.get("collider") as RigidBody3D
		if is_instance_valid(body) and body != source.get("body"):
			var indexed: Array = []
			for point_value in _indexed_body_points_v050(body):
				var point: Dictionary = point_value as Dictionary
				if str(point.get("type", "")) in expected and _attach_target_is_available_v040(source, point):
					indexed.append(point)
			var picked: Dictionary = _nearest_projected_candidate_v030(indexed, screen_pos, ATTACH_PICK_RADIUS_V040)
			if not picked.is_empty():
				return picked
	return super._pick_attach_target_v035(screen_pos, source)


func _refresh_attach_points_v032() -> void:
	if attach_points_root_v032 == null:
		super._refresh_attach_points_v032()
		attach_overlay_dirty_v050 = true
		return
	if not attach_overlay_dirty_v050:
		return
	attach_overlay_dirty_v050 = false
	super._refresh_attach_points_v032()


func _handle_attach_point_tap_v032(screen_pos: Vector2) -> void:
	attach_overlay_dirty_v050 = true
	super._handle_attach_point_tap_v032(screen_pos)
	attach_overlay_dirty_v050 = true
	_refresh_attach_points_v032()


func _set_selected(body: RigidBody3D) -> void:
	attach_overlay_dirty_v050 = true
	super._set_selected(body)


func _set_editor_mode_v032(mode_value: int, report: bool = true) -> void:
	attach_overlay_dirty_v050 = true
	attach_spatial_dirty_v050 = true
	super._set_editor_mode_v032(mode_value, report)


func _cycle_mode() -> void:
	attach_overlay_dirty_v050 = true
	attach_spatial_dirty_v050 = true
	super._cycle_mode()
	_refresh_attach_points_v032()


func _commit_state() -> void:
	attach_overlay_dirty_v050 = true
	attach_spatial_dirty_v050 = true
	super._commit_state()
	_schedule_autosave_v050()


func _restore_state(snapshot: Dictionary) -> void:
	attach_overlay_dirty_v050 = true
	attach_spatial_dirty_v050 = true
	super._restore_state(snapshot)
	_apply_physics_settings_v050()


func _update_ui() -> void:
	super._update_ui()
	if parts_button_v050 != null:
		parts_button_v050.disabled = simulating
	if builds_button_v050 != null:
		builds_button_v050.disabled = simulating
	_refresh_physics_labels_v050()


func _process(delta: float) -> void:
	super._process(delta)
	var signature: String = "%d:%d:%d:%d" % [editor_mode_v032, attach_mode, int(help_panel != null and help_panel.visible), int(options_panel != null and options_panel.visible)]
	if signature != last_overlay_visibility_signature_v050:
		last_overlay_visibility_signature_v050 = signature
		attach_overlay_dirty_v050 = true
		_refresh_attach_points_v032()
	if autosave_pending_v050 and autosave_ready_v050 and Time.get_ticks_msec() >= autosave_due_ms_v050:
		_write_autosave_v050()


func _notification(what: int) -> void:
	if not session_tracking_v050:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if autosave_ready_v050:
			_write_autosave_v050()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if autosave_ready_v050:
			_write_autosave_v050()
		_clear_session_marker_v050()


# -----------------------------------------------------------------------------
# Help + updater version awareness.
# -----------------------------------------------------------------------------

func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nPARTS: tap PARTS in the bottom bar. Rods and connectors are shown as color-coded cards. Choosing a card changes only the NEXT part, never an existing selected piece.\n\nSAVES: Options → Open Saves & Recovery. Give a build a name, save it, and load it later. Camera position, connection mode, exact topology, O-Rings and 3D connectors are preserved.\n\nCRASH RECOVERY: every committed build change is autosaved after a short debounce. If Android closes unexpectedly, the next launch offers Restore Autosave. Ignoring it archives the recovery before normal autosaving resumes.\n\nPHYSICS: Options exposes gravity, friction, bounce and linear/angular damping. These affect SIMULATE without changing construction geometry.\n\nPERFORMANCE: identical box/cylinder primitives share mesh resources; ATTACH has a per-body/world-cell target index; repeated attachment overlays rebuild only when topology/mode/selection becomes dirty.\n\nEDITOR: CREATE / ROTATE / MOVE / ATTACH remain unchanged. Rotation is fixed-world 45°; Move is fixed-world 0.5-unit snap; Roll stays mount-relative.\n\n3D CONNECTORS / O-RING: 11-point, 14-point and O-Ring Stop remain fully functional." % VERSION_050


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
	if _compare_versions_v021(latest, VERSION_050) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_050)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_050, latest])
