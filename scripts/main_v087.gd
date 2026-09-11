extends "res://scripts/main_v086.gd"

const VERSION_087 := "0.5.24"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_087)
	_status("v0.5.24 ready — UI refinements, reconnect workflow, live rotation feedback, inventory counts and build-mode performance optimizations are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_087, text]


# main_v077 adds Android-friendly scroll handling after every Parts rebuild.
# v0.5.24 replaces the card contents to show live inventory counts, so reapply
# that inherited touch configuration after the custom card refresh.
func _refresh_parts_browser_v050() -> void:
	super._refresh_parts_browser_v050()
	if parts_panel_v050 != null:
		_configure_scroll_touch_v077(parts_panel_v050, false)
