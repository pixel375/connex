extends "res://scripts/main_v015.gd"

const VERSION_016 = "0.1.6"

var create_mode_button_v016: Button
var edit_mode_button_v016: Button
var mode_segment_v016: HBoxContainer


func _build_ui() -> void:
	super._build_ui()
	if top_mode_button == null:
		return

	# v0.1.5 used one button whose label changed between CREATE and EDIT.
	# That made the other mode effectively invisible. Replace it with an
	# always-visible two-button segmented control.
	var top_row: HBoxContainer = top_mode_button.get_parent() as HBoxContainer
	if top_row == null:
		return

	top_mode_button.visible = false
	mode_segment_v016 = HBoxContainer.new()
	mode_segment_v016.add_theme_constant_override("separation", 2)
	create_mode_button_v016 = _ui_button("CREATE", _enter_create_mode_v016)
	edit_mode_button_v016 = _ui_button("EDIT", _enter_edit_mode_v016)
	create_mode_button_v016.custom_minimum_size = Vector2(84, 44)
	edit_mode_button_v016.custom_minimum_size = Vector2(76, 44)
	mode_segment_v016.add_child(create_mode_button_v016)
	mode_segment_v016.add_child(edit_mode_button_v016)
	top_row.add_child(mode_segment_v016)
	var old_index: int = top_mode_button.get_index()
	top_row.move_child(mode_segment_v016, old_index + 1)
	_refresh_mode_segment_v016()


func _enter_create_mode_v016() -> void:
	if simulating:
		_status("Return to BUILD before changing mode")
		return
	if not edit_mode:
		_status("CREATE mode — taps place parts only")
		_refresh_mode_segment_v016()
		return
	edit_mode = false
	_clear_selection_for_create()
	_refresh_mode_segment_v016()
	_update_ui()


func _enter_edit_mode_v016() -> void:
	if simulating:
		_status("Return to BUILD before changing mode")
		return
	if edit_mode:
		_status("EDIT mode — tap a piece to select it")
		_refresh_mode_segment_v016()
		return
	edit_mode = true
	_status("EDIT mode — tap a piece to select it; Rotate and Move panels are now active")
	_refresh_mode_segment_v016()
	_update_ui()


func _refresh_mode_segment_v016() -> void:
	if create_mode_button_v016 == null or edit_mode_button_v016 == null:
		return
	var active: Color = Color(0.02, 0.48, 0.72, 1.0)
	var inactive: Color = Color(0.095, 0.115, 0.145, 0.96)
	var active_hover: Color = Color(0.04, 0.56, 0.82, 1.0)
	var inactive_hover: Color = Color(0.12, 0.20, 0.27, 0.98)

	create_mode_button_v016.text = "● CREATE" if not edit_mode else "CREATE"
	edit_mode_button_v016.text = "● EDIT" if edit_mode else "EDIT"

	create_mode_button_v016.add_theme_stylebox_override("normal", _button_style(active if not edit_mode else inactive))
	create_mode_button_v016.add_theme_stylebox_override("hover", _button_style(active_hover if not edit_mode else inactive_hover))
	edit_mode_button_v016.add_theme_stylebox_override("normal", _button_style(active if edit_mode else inactive))
	edit_mode_button_v016.add_theme_stylebox_override("hover", _button_style(active_hover if edit_mode else inactive_hover))


# Connector/rod rebuilds queue the old MeshInstance3D children for deletion.
# v0.1.5 refreshed the outline in the same frame and accidentally cloned those
# queued meshes as well as the new ones, so an old 8-way highlight could remain
# around a newly changed 1-way connector. Build the outline only from live mesh
# children and always destroy the previous highlight first.
func _refresh_selection_highlight() -> void:
	_clear_selection_highlight()
	if not edit_mode or not is_instance_valid(selected_piece):
		return
	var body: RigidBody3D = selected_piece
	var highlight: Node3D = Node3D.new()
	highlight.name = "SelectionHighlight"
	highlighted_body = body
	body.add_child(highlight)
	for child_value in body.get_children():
		var source: MeshInstance3D = child_value as MeshInstance3D
		if source == null or source.mesh == null or source.is_queued_for_deletion():
			continue
		var outline: MeshInstance3D = MeshInstance3D.new()
		outline.mesh = source.mesh
		outline.transform = source.transform
		outline.scale = source.scale * 1.16
		outline.material_override = _selection_mat()
		highlight.add_child(outline)


func _update_ui() -> void:
	super._update_ui()
	# The old toggle stays hidden; the two explicit buttons are the only mode UI.
	if top_mode_button != null:
		top_mode_button.visible = false
	_refresh_mode_segment_v016()
	if rotation_collapse_button != null:
		var rot_arrow: String = "▸" if rotation_collapsed else "▾"
		rotation_collapse_button.text = "ROTATE %s" % rot_arrow if edit_mode else "ROTATE • EDIT %s" % rot_arrow
	if move_collapse_button != null:
		var move_arrow: String = "▸" if move_collapsed else "▾"
		move_collapse_button.text = "MOVE %s" % move_arrow if edit_mode else "MOVE • EDIT %s" % move_arrow


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_016, text]
