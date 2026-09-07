extends "res://scripts/main_v030.gd"

const VERSION_031 := "0.3.1"
const DOWNLOAD_STATUS_POLL_031 := 0.65
const DOWNLOAD_ROW_GRACE_031 := 8.0

var download_status_poll_031: float = 0.0
var download_elapsed_031: float = 0.0
var download_missing_row_031: float = 0.0
var download_failure_count_031: int = 0
var download_last_progress_031: int = -1


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_031)
	var help_label: Label = _find_label_v030(help_panel) if help_panel != null else null
	if help_label != null:
		help_label.text = help_label.text.replace("v0.3.0", "v0.3.1")
	_status("Updater reliability fix active. Android download state and failures are now reported instead of hanging forever.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_031, text]


# v0.3.0 overrides the release parser so it compares against its own version.
# v0.3.1 must do the same or an installed v0.3.1 would offer v0.3.1 to itself.
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
	var assets: Array = release.get("assets", []) as Array
	for asset_value in assets:
		var asset: Dictionary = asset_value as Dictionary
		var asset_name: String = str(asset.get("name", ""))
		if asset_name.to_lower().ends_with(".apk"):
			apk_url = str(asset.get("browser_download_url", ""))
			apk_name = asset_name
			break

	if _compare_versions_v021(latest, VERSION_031) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_031)
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
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_031, latest])
		if update_button_v021 != null:
			update_button_v021.text = "Update to v%s" % latest


# Store updater payloads in the app-specific external Downloads directory instead
# of the shared public Downloads directory. This avoids stale-file/name collisions
# under scoped storage and still lets DownloadManager provide an installable URI.
func _start_android_download_v021() -> void:
	var android_runtime: Variant = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		OS.shell_open(update_available_url_v021)
		_set_update_status_v021("Android updater unavailable; opened the APK in your browser.")
		return

	var activity: Variant = android_runtime.getActivity()
	var Uri: Variant = JavaClassWrapper.wrap("android.net.Uri")
	var DownloadRequest: Variant = JavaClassWrapper.wrap("android.app.DownloadManager$Request")
	var Environment: Variant = JavaClassWrapper.wrap("android.os.Environment")
	var uri: Variant = Uri.parse(update_available_url_v021)
	var java_error: Variant = JavaClassWrapper.get_exception()
	if java_error != null or uri == null:
		_fail_download_start_031("Android could not parse the update URL")
		return

	var request: Variant = DownloadRequest.Request(uri)
	java_error = JavaClassWrapper.get_exception()
	if java_error != null or request == null:
		_fail_download_start_031("Android could not create the download request")
		return

	var unique_name: String = "Connex-update-v%s-%d.apk" % [update_available_version_v021, int(Time.get_unix_time_from_system())]
	request.setTitle("Connex Lab v%s" % update_available_version_v021)
	request.setDescription("Downloading Connex Lab update")
	request.setMimeType(APK_MIME_021)
	request.setNotificationVisibility(1)
	request.setAllowedOverMetered(true)
	request.setAllowedOverRoaming(true)
	request.addRequestHeader("User-Agent", "Connex-Lab-Updater-v%s" % VERSION_031)
	request.addRequestHeader("Accept", "application/octet-stream")
	request.setDestinationInExternalFilesDir(activity, Environment.DIRECTORY_DOWNLOADS, unique_name)
	java_error = JavaClassWrapper.get_exception()
	if java_error != null:
		_fail_download_start_031("Android rejected the update destination")
		return

	android_download_manager_v021 = activity.getSystemService("download")
	if android_download_manager_v021 == null:
		_fail_download_start_031("Android DownloadManager is unavailable")
		return

	var queued_id: Variant = android_download_manager_v021.enqueue(request)
	java_error = JavaClassWrapper.get_exception()
	if java_error != null:
		_fail_download_start_031("Android failed to enqueue the update")
		return
	android_download_id_v021 = int(queued_id)
	if android_download_id_v021 <= 0:
		_fail_download_start_031("Android returned an invalid download job")
		return

	android_download_poll_v021 = 0.0
	download_status_poll_031 = 0.0
	download_elapsed_031 = 0.0
	download_missing_row_031 = 0.0
	download_last_progress_031 = -1
	pending_apk_uri_v021 = null
	waiting_unknown_sources_permission_v021 = false
	_set_update_status_v021("Starting download of v%s…" % update_available_version_v021)
	if update_button_v021 != null:
		update_button_v021.disabled = true
		update_button_v021.text = "Starting…"


func _fail_download_start_031(message: String) -> void:
	android_download_id_v021 = -1
	android_download_manager_v021 = null
	download_failure_count_031 += 1
	_set_update_status_v021("%s. Tap Retry Download, or download the APK from Releases." % message)
	if update_button_v021 != null:
		update_button_v021.disabled = false
		update_button_v021.text = "Retry Download"


func _process(delta: float) -> void:
	# Parent keeps its completion-URI check. v0.3.1 adds the missing status query.
	super._process(delta)
	if android_download_id_v021 < 0 or android_download_manager_v021 == null or not OS.has_feature("android"):
		return

	download_elapsed_031 += delta
	download_status_poll_031 += delta
	if download_status_poll_031 < DOWNLOAD_STATUS_POLL_031:
		return
	download_status_poll_031 = 0.0
	_poll_android_download_031()


func _poll_android_download_031() -> void:
	if android_download_id_v021 < 0 or android_download_manager_v021 == null:
		return

	var DownloadManager: Variant = JavaClassWrapper.wrap("android.app.DownloadManager")
	var DownloadQuery: Variant = JavaClassWrapper.wrap("android.app.DownloadManager$Query")
	var query: Variant = DownloadQuery.Query()
	var java_error: Variant = JavaClassWrapper.get_exception()
	if java_error != null or query == null:
		_handle_download_query_error_031("Could not create DownloadManager status query")
		return

	# Query without setFilterById so we don't depend on JNI vararg/long[] conversion.
	# We scan the app-visible DownloadManager rows for our exact job ID instead.
	var cursor: Variant = android_download_manager_v021.query(query)
	java_error = JavaClassWrapper.get_exception()
	if java_error != null or cursor == null:
		_handle_download_query_error_031("Could not read Android download status")
		return

	var found: bool = false
	var has_row: bool = bool(cursor.moveToFirst())
	while has_row:
		var id_index: int = int(cursor.getColumnIndex(DownloadManager.COLUMN_ID))
		if id_index >= 0:
			var row_id: int = int(cursor.getLong(id_index))
			if row_id == android_download_id_v021:
				found = true
				_read_download_row_031(cursor, DownloadManager)
				break
		has_row = bool(cursor.moveToNext())
	cursor.close()
	java_error = JavaClassWrapper.get_exception()
	if java_error != null:
		# Closing a cursor should not strand a valid download. Report only if the
		# row itself was not found and the grace period expires.
		pass

	if found:
		download_missing_row_031 = 0.0
		return

	download_missing_row_031 += DOWNLOAD_STATUS_POLL_031
	if download_missing_row_031 >= DOWNLOAD_ROW_GRACE_031:
		_handle_download_failure_031(-1, "Android no longer reports this download job")
	else:
		_set_update_status_v021("Waiting for Android DownloadManager…")


func _read_download_row_031(cursor: Variant, DownloadManager: Variant) -> void:
	var status_index: int = int(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS))
	if status_index < 0:
		_handle_download_query_error_031("Android download status column is unavailable")
		return

	var status: int = int(cursor.getInt(status_index))
	var reason: int = 0
	var reason_index: int = int(cursor.getColumnIndex(DownloadManager.COLUMN_REASON))
	if reason_index >= 0:
		reason = int(cursor.getInt(reason_index))

	if status == int(DownloadManager.STATUS_PENDING):
		_set_update_status_v021("Download queued — waiting for Android to start v%s." % update_available_version_v021)
		if update_button_v021 != null:
			update_button_v021.text = "Queued…"
		return

	if status == int(DownloadManager.STATUS_RUNNING):
		var bytes_done: int = 0
		var bytes_total: int = -1
		var done_index: int = int(cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
		var total_index: int = int(cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
		if done_index >= 0:
			bytes_done = int(cursor.getLong(done_index))
		if total_index >= 0:
			bytes_total = int(cursor.getLong(total_index))
		if bytes_total > 0:
			var percent: int = clampi(int(round(float(bytes_done) * 100.0 / float(bytes_total))), 0, 100)
			if percent != download_last_progress_031:
				download_last_progress_031 = percent
				_set_update_status_v021("Downloading v%s — %d%% (%.1f / %.1f MB)" % [update_available_version_v021, percent, float(bytes_done) / 1048576.0, float(bytes_total) / 1048576.0])
			if update_button_v021 != null:
				update_button_v021.text = "Downloading %d%%" % percent
		else:
			_set_update_status_v021("Downloading v%s — %.1f MB received…" % [update_available_version_v021, float(bytes_done) / 1048576.0])
			if update_button_v021 != null:
				update_button_v021.text = "Downloading…"
		return

	if status == int(DownloadManager.STATUS_PAUSED):
		_set_update_status_v021("Download paused — %s" % _download_reason_text_031(reason, true))
		if update_button_v021 != null:
			update_button_v021.text = "Paused…"
		return

	if status == int(DownloadManager.STATUS_FAILED):
		_handle_download_failure_031(reason, _download_reason_text_031(reason, false))
		return

	if status == int(DownloadManager.STATUS_SUCCESSFUL):
		_complete_download_from_manager_031()
		return

	_set_update_status_v021("Android reports unknown download state %d." % status)


func _complete_download_from_manager_031() -> void:
	if android_download_id_v021 < 0 or android_download_manager_v021 == null:
		return
	var uri: Variant = android_download_manager_v021.getUriForDownloadedFile(android_download_id_v021)
	var java_error: Variant = JavaClassWrapper.get_exception()
	if java_error != null or uri == null:
		_handle_download_failure_031(-2, "Download completed but Android did not provide an installable file URI")
		return
	pending_apk_uri_v021 = uri
	android_download_id_v021 = -1
	download_failure_count_031 = 0
	if update_button_v021 != null:
		update_button_v021.disabled = false
		update_button_v021.text = "Install v%s" % update_available_version_v021
	_set_update_status_v021("Download complete — preparing Android installer for v%s." % update_available_version_v021)
	_prepare_android_install_v021()


func _handle_download_query_error_031(message: String) -> void:
	# A transient Java/JNI read failure should not immediately cancel a live OS
	# download. After a short grace interval, recover the UI instead of hanging.
	download_missing_row_031 += DOWNLOAD_STATUS_POLL_031
	if download_missing_row_031 >= DOWNLOAD_ROW_GRACE_031:
		_handle_download_failure_031(-3, message)
	else:
		_set_update_status_v021("%s; retrying status read…" % message)


func _handle_download_failure_031(reason: int, detail: String) -> void:
	android_download_id_v021 = -1
	android_download_manager_v021 = null
	pending_apk_uri_v021 = null
	waiting_unknown_sources_permission_v021 = false
	download_failure_count_031 += 1
	var reason_suffix: String = "" if reason < 0 else " (Android reason %d)" % reason
	_set_update_status_v021("Download failed: %s%s. Tap Retry Download." % [detail, reason_suffix])
	if update_button_v021 != null:
		update_button_v021.disabled = false
		update_button_v021.text = "Retry Download"


func _download_reason_text_031(reason: int, paused: bool) -> String:
	if paused:
		match reason:
			1:
				return "waiting to retry"
			2:
				return "waiting for a network connection"
			3:
				return "queued for Wi-Fi"
			4:
				return "paused for an unspecified Android reason"
			_:
				return "Android paused the download (reason %d)" % reason

	match reason:
		1000:
			return "unknown Android download error"
		1001:
			return "file-system error"
		1002:
			return "GitHub returned an HTTP response Android could not handle"
		1004:
			return "HTTP data-transfer error"
		1005:
			return "too many HTTP redirects"
		1006:
			return "not enough storage space"
		1007:
			return "download storage is unavailable"
		1008:
			return "Android could not resume the download"
		1009:
			return "a file already exists at the requested destination"
		1010:
			return "the download was blocked by Android policy"
		_:
			if reason >= 400 and reason <= 599:
				return "HTTP %d from the download server" % reason
			return "Android download error %d" % reason
