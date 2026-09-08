extends "res://scripts/main_v054.gd"

const VERSION_055 := "0.5.2"


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_055)
	_status("Interaction reliability release active — scrollable menus, direct transform selection, connection-axis ITEM transforms and reliable move commits.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_055, text]


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nMENUS: Options, Parts, Physics, Rotate and Move are touch-scrollable. Rotate/Move side panels exist only while that editor mode is active and are not collapsible. Modal menus block construction input behind them.\n\nSELECTION: in ROTATE or MOVE, tap a piece directly to select it; the separate Select button is not required.\n\nITEM ROTATE: free pieces use local XYZ. SOCKET/CROSS/AXLE-mounted connectors rotate around the real attachment axis; the gizmo ring and Roll use the same physical degree of freedom.\n\nITEM MOVE: ordinary connected structures translate in the selected item's LOCAL axes. CROSS/AXLE/O-Ring parts slide only along the host rod. Drag preview and release use the same validated transform.\n\nATTACH: valid re-seat sockets stay green, CROSS + markers are larger, and 11/14 spatial ports use enlarged picking targets.\n\nCREATE: socket/rod-end taps use screen-space point picking and nearby compatible second ends auto-connect more reliably.\n\nDISCONNECT: opens a visible gap and blocks immediate snap-back until explicit re-attach.\n\nCAMERA: two-finger pan/zoom remains active with a wider 3–420 distance range." % VERSION_055


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
	if _compare_versions_v021(latest, VERSION_055) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_055)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
