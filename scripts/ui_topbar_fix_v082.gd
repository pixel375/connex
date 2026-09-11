extends Node

# Finalize the v0.5.23 top toolbar after the complete inherited UI tree exists.
# This keeps the historical toolbar reconstruction safety net from v0.5.22 while
# removing the obsolete status frame and applying the new neutral icon styling.

func _ready() -> void:
	call_deferred("_apply_topbar_fix")


func _nearest_panel(node: Node, stop: Node) -> PanelContainer:
	if node == null:
		return null
	var current := node.get_parent()
	while current != null and current != stop:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null


func _apply_topbar_fix() -> void:
	var main := get_parent()
	if main == null:
		return

	var status := main.get("status_label") as Label
	if status != null:
		status.hide()
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var legacy_delete := main.get("delete_button_v032") as Button
	if legacy_delete != null:
		legacy_delete.hide()
		legacy_delete.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var select_button := main.get("select_button_v020") as Button
	if select_button == null:
		return
	var top_row := select_button.get_parent() as HBoxContainer
	if top_row == null:
		return

	var toolbar_panel := _nearest_panel(select_button, main)
	var status_panel := _nearest_panel(status, main)
	if status_panel != null and status_panel != toolbar_panel:
		status_panel.hide()
		status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if toolbar_panel != null:
		toolbar_panel.offset_bottom = maxf(toolbar_panel.offset_bottom, 78.0)
		if status_panel == toolbar_panel:
			var transparent := StyleBoxFlat.new()
			transparent.bg_color = Color(0, 0, 0, 0)
			toolbar_panel.add_theme_stylebox_override("panel", transparent)
		else:
			toolbar_panel.add_theme_stylebox_override("panel", main.call("_panel_style", 0.97, 11))
	top_row.add_theme_constant_override("separation", 4)

	for child_value in top_row.get_children():
		var old_help := child_value as Button
		if old_help != null and old_help.text == "?":
			old_help.hide()
			old_help.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_delete := main.get("top_delete_button_v081") as Button
	if top_delete == null:
		top_delete = main.call("_ui_button", "🗑", Callable(main, "_request_delete_v081"), true) as Button
		main.set("top_delete_button_v081", top_delete)
		top_row.add_child(top_delete)

	var center_button := main.get("top_center_button") as Button
	var undo_button := main.get("top_undo_button") as Button
	var redo_button := main.get("top_redo_button") as Button
	var simulate_button := main.get("top_simulate_button") as Button
	var restore_button := main.get("top_restore_button") as Button
	var restart_button := main.get("top_restart_button") as Button
	var options_button := main.get("options_button") as Button

	main.call("_style_top_icon_v081", select_button, "◎", "Select a piece")
	main.call("_style_top_icon_v081", center_button, "⊕", "Center selected piece / construction")
	main.call("_style_top_icon_v081", undo_button, "↶", "Undo")
	main.call("_style_top_icon_v081", redo_button, "↷", "Redo")
	main.call("_style_top_icon_v081", simulate_button, "▶", "Simulate")
	main.call("_style_top_icon_v081", restore_button, "⟳", "Restore build pose")
	main.call("_style_top_icon_v081", restart_button, "⊘", "Restart project")
	main.call("_style_top_icon_v081", top_delete, "🗑", "Delete selected piece")
	main.call("_style_top_icon_v081", options_button, "⚙", "Options")
	main.call("_replace_pressed_callback_v081", restart_button, Callable(main, "_request_restart_v081"))

	for child_value in top_row.get_children():
		if child_value is VSeparator:
			top_row.remove_child(child_value)
			(child_value as Node).queue_free()

	var separators: Array[VSeparator] = []
	for _i in range(4):
		var separator := main.call("_toolbar_separator_v081") as VSeparator
		separators.append(separator)
		top_row.add_child(separator)

	var ordered: Array[Node] = [
		select_button, center_button, separators[0],
		undo_button, redo_button, separators[1],
		simulate_button, restore_button, separators[2],
		restart_button, top_delete, separators[3],
		options_button,
	]
	for i in range(ordered.size()):
		var node := ordered[i]
		if node != null and node.get_parent() == top_row:
			top_row.move_child(node, i)

	main.call("_refresh_top_toolbar_v081")
	main.call("_remove_status_frame_v082")
	if status != null:
		status.hide()
	if legacy_delete != null:
		legacy_delete.hide()
