extends "res://scripts/main_v032.gd"

const VERSION_033 := "0.3.3"
const STATUS_STRIP_TOP_033 := 66.0
const STATUS_STRIP_BOTTOM_033 := 106.0
const SIDE_PANEL_TOP_033 := 112.0
const MIN_APK_BYTES_033 := 1048576

var apk_http_v033: HTTPRequest
var apk_download_in_progress_v033: bool = false
var apk_local_path_v033: String = ""
var apk_expected_sha256_v033: String = ""
var apk_ready_v033: bool = false
var apk_last_percent_v033: int = -1
var status_strip_v033: PanelContainer


func _ready() -> void:
	super._ready()
	_ensure_apk_request_v033()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_033)
	_status("CREATE mode — build normally. Runtime messages now use the separate status strip below the toolbar.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_033, text]


# -----------------------------------------------------------------------------
# UI: runtime status no longer shares horizontal space with toolbar buttons.
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	_build_status_strip_v033()
	if mode_panel_v032 != null:
		mode_panel_v032.offset_top = SIDE_PANEL_TOP_033
		mode_panel_v032.offset_bottom = 466.0
	_layout_right_panels_v032()


func _build_status_strip_v033() -> void:
	if status_label == null or status_strip_v033 != null:
		return
	var old_parent: Node = status_label.get_parent()
	if old_parent != null:
		old_parent.remove_child(status_label)

	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	status_strip_v033 = PanelContainer.new()
	status_strip_v033.anchor_right = 1.0
	status_strip_v033.offset_left = 8.0
	status_strip_v033.offset_right = -8.0
	status_strip_v033.offset_top = STATUS_STRIP_TOP_033
	status_strip_v033.offset_bottom = STATUS_STRIP_BOTTOM_033
	status_strip_v033.add_theme_stylebox_override("panel", _panel_style(0.94, 9))
	layer.add_child(status_strip_v033)

	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_font_size_override("font_size", 13)
	status_strip_v033.add_child(status_label)


# Override the v0.3.2 accordion layout so both right-side tools begin below the
# dedicated status strip and can never cover it.
func _layout_right_panels_v032() -> void:
	if rotation_panel == null or move_panel == null:
		return
	rotation_panel.anchor_left = 1.0
	rotation_panel.anchor_right = 1.0
	move_panel.anchor_left = 1.0
	move_panel.anchor_right = 1.0
	rotation_panel.offset_left = -246.0
	rotation_panel.offset_right = -8.0
	move_panel.offset_left = -246.0
	move_panel.offset_right = -8.0

	var rotate_open: bool = rotation_body != null and rotation_body.visible
	var move_open: bool = move_body != null and move_body.visible
	if rotate_open:
		rotation_panel.offset_top = SIDE_PANEL_TOP_033
		rotation_panel.offset_bottom = 536.0
		move_panel.offset_top = 542.0
		move_panel.offset_bottom = 594.0
	elif move_open:
		rotation_panel.offset_top = SIDE_PANEL_TOP_033
		rotation_panel.offset_bottom = 164.0
		move_panel.offset_top = 170.0
		move_panel.offset_bottom = 576.0
	else:
		rotation_panel.offset_top = SIDE_PANEL_TOP_033
		rotation_panel.offset_bottom = 164.0
		move_panel.offset_top = 170.0
		move_panel.offset_bottom = 222.0


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text = label.text.replace("v0.3.2", "v%s" % VERSION_033)


# -----------------------------------------------------------------------------
# Updater v0.3.3
#
# v0.3.1 used JavaClassWrapper to construct Android DownloadManager.Request.
# That constructor path fails on some Android/Godot combinations before enqueue.
# v0.3.3 removes DownloadManager from the update path entirely: Godot HTTPRequest
# downloads into user://, the GitHub asset digest is verified, then OS.shell_open
# gives the local APK to Godot's Android FileProvider / ACTION_VIEW implementation.
# -----------------------------------------------------------------------------

func _ensure_apk_request_v033() -> void:
	if apk_http_v033 != null:
		return
	apk_http_v033 = HTTPRequest.new()
	apk_http_v033.name = "APKDownloadHTTPRequestV033"
	add_child(apk_http_v033)
	apk_http_v033.request_completed.connect(_on_apk_download_completed_v033)


func _on_update_request_completed_v021(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	update_check_in_progress_v021 = false
	if update_button_v021 != null:
		update_button_v021.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_update_status_v021("Update check failed (HTTP %d)." % response_code)
		if update_button_v021 != null:
			update_button_v021.text = "Retry Update Check"
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
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
		if update_button_v021 != null:
			update_button_v021.text = "Retry Update Check"
		return

	var apk_url: String = ""
	var apk_name: String = ""
	var apk_digest: String = ""
	var assets: Array = release.get("assets", []) as Array
	for asset_value in assets:
		var asset: Dictionary = asset_value as Dictionary
		var asset_name: String = str(asset.get("name", ""))
		if asset_name.to_lower().ends_with(".apk"):
			apk_url = str(asset.get("browser_download_url", ""))
			apk_name = asset_name
			apk_digest = str(asset.get("digest", ""))
			break

	if _compare_versions_v021(latest, VERSION_033) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_033)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
		return

	update_available_version_v021 = latest
	update_available_url_v021 = apk_url if not apk_url.is_empty() else UPDATE_REPO_URL_021
	update_available_filename_v021 = apk_name
	apk_expected_sha256_v033 = apk_digest.trim_prefix("sha256:").to_lower()
	apk_ready_v033 = false

	if apk_url.is_empty():
		_set_update_status_v021("v%s is available, but its APK asset was not found." % latest)
		if update_button_v021 != null:
			update_button_v021.text = "Open Releases"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_033, latest])
		if update_button_v021 != null:
			update_button_v021.text = "Update to v%s" % latest


func _on_update_button_v021() -> void:
	if update_check_in_progress_v021 or apk_download_in_progress_v033:
		return
	if apk_ready_v033 and not apk_local_path_v033.is_empty() and FileAccess.file_exists(apk_local_path_v033):
		_open_downloaded_apk_v033()
		return
	if update_available_url_v021.is_empty():
		_check_for_updates_v021(false)
	else:
		_begin_update_v021()


func _begin_update_v021() -> void:
	if update_available_url_v021.is_empty():
		_check_for_updates_v021(false)
		return
	if not OS.has_feature("android"):
		OS.shell_open(update_available_url_v021)
		_set_update_status_v021("Opened the latest APK in your browser.")
		return
	_start_android_download_v021()


# Keep the inherited function name so every existing update button path reaches
# the new Godot-native downloader without changing the older UI wiring.
func _start_android_download_v021() -> void:
	if update_available_url_v021.is_empty() or update_available_url_v021 == UPDATE_REPO_URL_021:
		OS.shell_open(UPDATE_REPO_URL_021)
		_set_update_status_v021("APK URL unavailable; opened GitHub Releases instead.")
		return

	_ensure_apk_request_v033()
	if apk_http_v033 == null:
		_fail_apk_download_v033("Could not initialize the update downloader")
		return

	if not apk_local_path_v033.is_empty() and FileAccess.file_exists(apk_local_path_v033):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(apk_local_path_v033))

	var safe_version: String = update_available_version_v021.replace("/", "_").replace("\\", "_")
	apk_local_path_v033 = "user://Connex-update-v%s.apk" % safe_version
	if FileAccess.file_exists(apk_local_path_v033):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(apk_local_path_v033))

	apk_http_v033.download_file = apk_local_path_v033
	apk_download_in_progress_v033 = true
	apk_ready_v033 = false
	apk_last_percent_v033 = -1
	var request_headers := PackedStringArray([
		"Accept: application/octet-stream",
		"User-Agent: Connex-Lab-Updater-v%s" % VERSION_033
	])
	var err: Error = apk_http_v033.request(update_available_url_v021, request_headers)
	if err != OK:
		apk_download_in_progress_v033 = false
		apk_http_v033.download_file = ""
		_fail_apk_download_v033("Could not start APK download: %s" % error_string(err))
		return

	_set_update_status_v021("Downloading v%s…" % update_available_version_v021)
	if update_button_v021 != null:
		update_button_v021.disabled = true
		update_button_v021.text = "Downloading…"


func _process(delta: float) -> void:
	super._process(delta)
	if not apk_download_in_progress_v033 or apk_http_v033 == null:
		return
	var downloaded: int = apk_http_v033.get_downloaded_bytes()
	var total: int = apk_http_v033.get_body_size()
	if total > 0:
		var percent: int = clampi(int(round(float(downloaded) * 100.0 / float(total))), 0, 100)
		if percent != apk_last_percent_v033:
			apk_last_percent_v033 = percent
			_set_update_status_v021("Downloading v%s — %d%% (%.1f / %.1f MB)" % [update_available_version_v021, percent, float(downloaded) / 1048576.0, float(total) / 1048576.0])
			if update_button_v021 != null:
				update_button_v021.text = "Downloading %d%%" % percent
	else:
		_set_update_status_v021("Downloading v%s — %.1f MB received…" % [update_available_version_v021, float(downloaded) / 1048576.0])


func _on_apk_download_completed_v033(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	apk_download_in_progress_v033 = false
	if apk_http_v033 != null:
		apk_http_v033.download_file = ""
	if update_button_v021 != null:
		update_button_v021.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_apk_download_v033("Download transport failed (result %d)" % result)
		return
	if response_code < 200 or response_code >= 300:
		_fail_apk_download_v033("GitHub APK download failed (HTTP %d)" % response_code)
		return
	if apk_local_path_v033.is_empty() or not FileAccess.file_exists(apk_local_path_v033):
		_fail_apk_download_v033("Download finished but the APK file is missing")
		return

	var file: FileAccess = FileAccess.open(apk_local_path_v033, FileAccess.READ)
	if file == null:
		_fail_apk_download_v033("Downloaded APK could not be opened for verification")
		return
	var file_size: int = file.get_length()
	file.close()
	if file_size < MIN_APK_BYTES_033:
		_fail_apk_download_v033("Downloaded file is too small to be a valid Connex APK")
		return

	var actual_sha256: String = FileAccess.get_sha256(apk_local_path_v033).to_lower()
	if not apk_expected_sha256_v033.is_empty() and actual_sha256 != apk_expected_sha256_v033:
		_fail_apk_download_v033("APK SHA-256 verification failed")
		return

	apk_ready_v033 = true
	_set_update_status_v021("Download verified — v%s is ready to install." % update_available_version_v021)
	if update_button_v021 != null:
		update_button_v021.text = "Install v%s" % update_available_version_v021
	_open_downloaded_apk_v033()


func _fail_apk_download_v033(message: String) -> void:
	apk_download_in_progress_v033 = false
	apk_ready_v033 = false
	if not apk_local_path_v033.is_empty() and FileAccess.file_exists(apk_local_path_v033):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(apk_local_path_v033))
	_set_update_status_v021("%s. Tap Retry Download." % message)
	if update_button_v021 != null:
		update_button_v021.disabled = false
		update_button_v021.text = "Retry Download"


func _open_downloaded_apk_v033() -> void:
	if apk_local_path_v033.is_empty() or not FileAccess.file_exists(apk_local_path_v033):
		apk_ready_v033 = false
		_fail_apk_download_v033("Verified APK is no longer available")
		return
	var absolute_path: String = ProjectSettings.globalize_path(apk_local_path_v033)
	var err: Error = OS.shell_open(absolute_path)
	if err != OK:
		_set_update_status_v021("Android could not open the installer (%s). Tap Install to retry." % error_string(err))
		if update_button_v021 != null:
			update_button_v021.disabled = false
			update_button_v021.text = "Install v%s" % update_available_version_v021
		return
	_set_update_status_v021("Android installer opened for v%s. Confirm the update. If Android asks, allow Connex Lab to install unknown apps, then tap Install again." % update_available_version_v021)
	if update_button_v021 != null:
		update_button_v021.disabled = false
		update_button_v021.text = "Install v%s" % update_available_version_v021
