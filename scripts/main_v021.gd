extends "res://scripts/main_v020.gd"

const VERSION_021 := "0.2.1"
const UPDATE_API_URL_021 := "https://api.github.com/repos/pixel375/connex/releases/latest"
const UPDATE_REPO_URL_021 := "https://github.com/pixel375/connex/releases/latest"
const APK_MIME_021 := "application/vnd.android.package-archive"

var update_http_v021: HTTPRequest
var update_button_v021: Button
var update_status_v021: Label
var auto_check_updates_v021: bool = true
var auto_check_checkbox_v021: CheckButton
var update_check_in_progress_v021: bool = false
var update_available_version_v021: String = ""
var update_available_url_v021: String = ""
var update_available_filename_v021: String = ""

var android_download_manager_v021 = null
var android_download_id_v021: int = -1
var android_download_poll_v021: float = 0.0
var pending_apk_uri_v021 = null
var waiting_unknown_sources_permission_v021: bool = false


func _ready() -> void:
	super._ready()
	if update_http_v021 == null:
		_setup_update_request_v021()
	if auto_check_updates_v021:
		call_deferred("_check_for_updates_v021", true)
	else:
		_set_update_status_v021("Current version: v%s" % VERSION_021)


func _build_ui() -> void:
	super._build_ui()
	_add_update_options_v021()


func _load_settings() -> void:
	super._load_settings()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		auto_check_updates_v021 = bool(cfg.get_value("updates", "auto_check_on_launch", true))


func _save_settings() -> void:
	super._save_settings()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("updates", "auto_check_on_launch", auto_check_updates_v021)
	cfg.save(SETTINGS_PATH)


func _add_update_options_v021() -> void:
	if options_panel == null or options_panel.get_child_count() == 0:
		return
	var margin := options_panel.get_child(0)
	if margin == null or margin.get_child_count() == 0:
		return
	var options_box := margin.get_child(0) as VBoxContainer
	if options_box == null:
		return

	var divider := HSeparator.new()
	options_box.add_child(divider)
	var title := _section_label("APP UPDATES")
	options_box.add_child(title)

	update_status_v021 = Label.new()
	update_status_v021.text = "Current version: v%s" % VERSION_021
	update_status_v021.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_status_v021.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_status_v021.add_theme_color_override("font_color", Color(0.70, 0.80, 0.88))
	options_box.add_child(update_status_v021)

	auto_check_checkbox_v021 = CheckButton.new()
	auto_check_checkbox_v021.text = "Check for updates automatically at launch"
	auto_check_checkbox_v021.set_pressed_no_signal(auto_check_updates_v021)
	auto_check_checkbox_v021.toggled.connect(_on_auto_check_updates_v021)
	options_box.add_child(auto_check_checkbox_v021)

	update_button_v021 = _ui_button("Check for Updates", _on_update_button_v021, true)
	options_box.add_child(update_button_v021)

	var note := Label.new()
	note.text = "Updates come from the official Connex GitHub Release APK. Android will always show its normal install confirmation. The first permanent-signed build requires one reinstall; later releases update in place."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.58, 0.66, 0.74))
	options_box.add_child(note)

	_setup_update_request_v021()


func _setup_update_request_v021() -> void:
	if update_http_v021 != null:
		return
	update_http_v021 = HTTPRequest.new()
	update_http_v021.name = "UpdateHTTPRequest"
	add_child(update_http_v021)
	update_http_v021.request_completed.connect(_on_update_request_completed_v021)


func _on_auto_check_updates_v021(enabled: bool) -> void:
	auto_check_updates_v021 = enabled
	_save_settings()


func _set_update_status_v021(text: String) -> void:
	if update_status_v021 != null:
		update_status_v021.text = text


func _on_update_button_v021() -> void:
	if update_check_in_progress_v021:
		return
	if update_available_url_v021.is_empty():
		_check_for_updates_v021(false)
	else:
		_begin_update_v021()


func _check_for_updates_v021(silent: bool = false) -> void:
	if update_check_in_progress_v021:
		return
	_setup_update_request_v021()
	update_check_in_progress_v021 = true
	if update_button_v021 != null:
		update_button_v021.disabled = true
		update_button_v021.text = "Checking…"
	if not silent:
		_set_update_status_v021("Checking GitHub Releases…")
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: Connex-Lab-Updater-v%s" % VERSION_021,
		"X-GitHub-Api-Version: 2022-11-28"
	])
	var err := update_http_v021.request(UPDATE_API_URL_021, headers)
	if err != OK:
		update_check_in_progress_v021 = false
		_set_update_status_v021("Could not start update check: %s" % error_string(err))
		if update_button_v021 != null:
			update_button_v021.disabled = false
			update_button_v021.text = "Check for Updates"


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

	var release := parsed as Dictionary
	var tag := str(release.get("tag_name", ""))
	var latest := tag.trim_prefix("v")
	if latest.is_empty():
		_set_update_status_v021("Latest release has no version tag.")
		if update_button_v021 != null:
			update_button_v021.text = "Retry Update Check"
		return

	var apk_url := ""
	var apk_name := ""
	var assets := release.get("assets", []) as Array
	for asset_value in assets:
		var asset := asset_value as Dictionary
		var name := str(asset.get("name", ""))
		if name.to_lower().ends_with(".apk"):
			apk_url = str(asset.get("browser_download_url", ""))
			apk_name = name
			break

	if _compare_versions_v021(latest, VERSION_021) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_021)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
		return

	if apk_url.is_empty():
		_set_update_status_v021("v%s is available, but its APK asset was not found." % latest)
		if update_button_v021 != null:
			update_button_v021.text = "Open Releases"
		update_available_version_v021 = latest
		update_available_url_v021 = UPDATE_REPO_URL_021
		update_available_filename_v021 = ""
		return

	update_available_version_v021 = latest
	update_available_url_v021 = apk_url
	update_available_filename_v021 = apk_name
	_set_update_status_v021("Update available: v%s → v%s" % [VERSION_021, latest])
	if update_button_v021 != null:
		update_button_v021.text = "Update to v%s" % latest


func _version_parts_v021(version: String) -> Array:
	var clean := version.strip_edges().trim_prefix("v")
	var core := clean.split("-", false, 1)[0]
	var raw := core.split(".")
	var result: Array = []
	for i in range(3):
		result.append(int(raw[i]) if i < raw.size() and str(raw[i]).is_valid_int() else 0)
	return result


func _compare_versions_v021(a: String, b: String) -> int:
	var aa := _version_parts_v021(a)
	var bb := _version_parts_v021(b)
	for i in range(3):
		var av := int(aa[i])
		var bv := int(bb[i])
		if av < bv:
			return -1
		if av > bv:
			return 1
	return 0


func _begin_update_v021() -> void:
	if update_available_url_v021.is_empty():
		_check_for_updates_v021(false)
		return
	if not OS.has_feature("android"):
		OS.shell_open(update_available_url_v021)
		_set_update_status_v021("Opened the latest APK in your browser.")
		return
	_start_android_download_v021()


func _start_android_download_v021() -> void:
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		OS.shell_open(update_available_url_v021)
		_set_update_status_v021("Android updater unavailable; opened Releases in browser.")
		return

	var activity = android_runtime.getActivity()
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var DownloadRequest = JavaClassWrapper.wrap("android.app.DownloadManager$Request")
	var Environment = JavaClassWrapper.wrap("android.os.Environment")
	var uri = Uri.parse(update_available_url_v021)
	var request = DownloadRequest.Request(uri)
	var filename := update_available_filename_v021
	if filename.is_empty():
		filename = "Connex-v%s.apk" % update_available_version_v021
	request.setTitle("Connex Lab v%s" % update_available_version_v021)
	request.setDescription("Downloading Connex Lab update")
	request.setMimeType(APK_MIME_021)
	request.setNotificationVisibility(1)
	request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
	android_download_manager_v021 = activity.getSystemService("download")
	android_download_id_v021 = int(android_download_manager_v021.enqueue(request))
	android_download_poll_v021 = 0.0
	pending_apk_uri_v021 = null
	waiting_unknown_sources_permission_v021 = false
	_set_update_status_v021("Downloading v%s… Check Android notifications for progress." % update_available_version_v021)
	if update_button_v021 != null:
		update_button_v021.disabled = true
		update_button_v021.text = "Downloading…"


func _process(delta: float) -> void:
	super._process(delta)
	if android_download_id_v021 < 0 or android_download_manager_v021 == null:
		return
	android_download_poll_v021 += delta
	if android_download_poll_v021 < 0.75:
		return
	android_download_poll_v021 = 0.0
	var uri = android_download_manager_v021.getUriForDownloadedFile(android_download_id_v021)
	if uri == null:
		return
	pending_apk_uri_v021 = uri
	android_download_id_v021 = -1
	if update_button_v021 != null:
		update_button_v021.disabled = false
		update_button_v021.text = "Install v%s" % update_available_version_v021
	_prepare_android_install_v021()


func _prepare_android_install_v021() -> void:
	if pending_apk_uri_v021 == null:
		return
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		return
	var activity = android_runtime.getActivity()
	var BuildVersion = JavaClassWrapper.wrap("android.os.Build$VERSION")
	if int(BuildVersion.SDK_INT) >= 26:
		var package_manager = activity.getPackageManager()
		if not bool(package_manager.canRequestPackageInstalls()):
			waiting_unknown_sources_permission_v021 = true
			_set_update_status_v021("Allow Connex Lab to install unknown apps, then return here. Installation will continue automatically.")
			var Settings = JavaClassWrapper.wrap("android.provider.Settings")
			var Intent = JavaClassWrapper.wrap("android.content.Intent")
			var Uri = JavaClassWrapper.wrap("android.net.Uri")
			var settings_intent = Intent.Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
			settings_intent.setData(Uri.parse("package:%s" % str(activity.getPackageName())))
			activity.startActivity(settings_intent)
			return
	_install_downloaded_apk_v021()


func _install_downloaded_apk_v021() -> void:
	if pending_apk_uri_v021 == null:
		return
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		return
	var activity = android_runtime.getActivity()
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var install_intent = Intent.Intent()
	install_intent.setAction(Intent.ACTION_VIEW)
	install_intent.setDataAndType(pending_apk_uri_v021, APK_MIME_021)
	install_intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	install_intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
	_set_update_status_v021("Android installer opened for v%s. Confirm the update to finish." % update_available_version_v021)
	activity.startActivity(install_intent)


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	if not waiting_unknown_sources_permission_v021 or pending_apk_uri_v021 == null or not OS.has_feature("android"):
		return
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		return
	var activity = android_runtime.getActivity()
	var BuildVersion = JavaClassWrapper.wrap("android.os.Build$VERSION")
	if int(BuildVersion.SDK_INT) < 26 or bool(activity.getPackageManager().canRequestPackageInstalls()):
		waiting_unknown_sources_permission_v021 = false
		_install_downloaded_apk_v021()


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_021, text]
