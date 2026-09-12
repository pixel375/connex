extends "res://scripts/main_v088.gd"

const VERSION_089 := "0.5.26"
const AUTOSAVE_IDLE_MS_089 := 2500
const AUTOSAVE_RETRY_MS_089 := 250
const MAX_AUTOSAVES_089 := 5
const SAVE_SCROLL_DEADZONE_089 := 10.0

var runtime_ready_v089: bool = false
var commit_ui_suppressed_v089: bool = false
var ui_refresh_count_v089: int = 0

var save_scroll_touch_v089: int = -1
var save_scroll_distance_v089: float = 0.0
var save_scroll_dragging_v089: bool = false

var autosave_thread_v089: Thread
var autosave_revision_v089: int = 0
var autosave_thread_revision_v089: int = -1
var autosave_force_sync_v089: bool = false


func _ready() -> void:
	super._ready()
	runtime_ready_v089 = true
	_install_save_list_touch_v089()
	_fix_left_deselect_v082()
	_sync_deselect_button_v083()
	_refresh_build_list_v050()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_089)
	_status("v0.5.26 ready — save, ATTACH, updater and Android latency fixes are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_089, text]


# -----------------------------------------------------------------------------
# Commit/UI hot path.
#
# The inherited history/graph chain legitimately has several _commit_state()
# layers, but older layers each called _update_ui() again. On Android that means
# rebuilding selection/ATTACH/editor UI multiple times for one edit. Preserve
# every ancestor side effect while collapsing those duplicate refreshes to one.
# -----------------------------------------------------------------------------

func _update_ui() -> void:
	if runtime_ready_v089 and commit_ui_suppressed_v089:
		return
	ui_refresh_count_v089 += 1
	super._update_ui()


func _commit_state() -> void:
	if not runtime_ready_v089:
		super._commit_state()
		return
	commit_ui_suppressed_v089 = true
	super._commit_state()
	commit_ui_suppressed_v089 = false
	_update_ui()


# -----------------------------------------------------------------------------
# ATTACH selection fixes.
# -----------------------------------------------------------------------------

# An occupied connector socket and its attached rod end occupy the same visual
# point. Expose only the rod end: the rod is the movable/reconnectable side and
# wins that location. This also removes the ambiguous double marker/pick target.
func _all_attach_points_v032() -> Array:
	var source: Array = super._all_attach_points_v032()
	var result: Array = []
	for point_value in source:
		var point := point_value as Dictionary
		if str(point.get("type", "")) == "socket":
			var connector := point.get("body") as RigidBody3D
			if is_instance_valid(connector):
				var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
				if occupied.has(int(point.get("slot", -1))):
					continue
		result.append(point)
	return result


# v0.5.0 introduced a dirty-cache around ATTACH markers. The base deselect helper
# cleared state and immediately requested a redraw, but that redraw could be
# ignored when the cache still said "clean". Dirty first so state and visuals
# are guaranteed to clear together.
func _deselect_attach_point_v032(report: bool = true) -> void:
	attach_overlay_dirty_v050 = true
	super._deselect_attach_point_v032(report)
	attach_overlay_dirty_v050 = true
	_refresh_attach_points_v032()
	_sync_deselect_button_v083()


func _deselect_context_v082(report: bool = true) -> void:
	if simulating:
		if report:
			_status("Return to BUILD before changing selection")
		return
	if not attach_point_selected_v032.is_empty():
		_deselect_attach_point_v032(report)
		_update_ui()
		return
	_deselect_piece_v039(report)
	_sync_deselect_button_v083()


# Rebind once at startup as well as through v0.5.23's setup. This guarantees the
# visible unified button owns the latest point-aware callback after all inherited
# UI construction/finalization has completed.
func _fix_left_deselect_v082() -> void:
	super._fix_left_deselect_v082()
	if deselect_piece_button_v039 != null:
		_replace_pressed_callback_v081(deselect_piece_button_v039, _deselect_context_v082)
		deselect_piece_button_v039.text = "Deselect"
	if deselect_point_button_v032 != null:
		deselect_point_button_v032.hide()
		deselect_point_button_v032.mouse_filter = Control.MOUSE_FILTER_IGNORE


# -----------------------------------------------------------------------------
# Saves: newest first + reliable ItemList touch dragging.
# -----------------------------------------------------------------------------

func _save_bundle_v050(name_value: String) -> Dictionary:
	var bundle: Dictionary = super._save_bundle_v050(name_value)
	bundle["app_version"] = VERSION_089
	return bundle


func _automatic_save_filename_v089(file_name: String) -> bool:
	var lower: String = file_name.to_lower()
	return (lower.begins_with("autosave_") or lower.begins_with("recovery_")) and lower.ends_with(".connex")


func _auto_file_stamp_v089(file_name: String) -> int:
	var stem: String = file_name.trim_suffix(".connex")
	var split_at: int = stem.find("_")
	if split_at < 0:
		return 0
	var raw: String = stem.substr(split_at + 1)
	if not raw.is_valid_int():
		return 0
	var stamp: int = int(raw)
	# Legacy Recovery_ files used Unix seconds; new Autosave_ files use millis.
	if stamp > 0 and stamp < 1000000000000:
		stamp *= 1000
	return stamp


func _prune_auto_saves_worker_v089() -> int:
	var dir := DirAccess.open(BUILDS_DIR_V050)
	if dir == null:
		return 0
	var entries: Array = []
	for file_name_value in dir.get_files():
		var file_name: String = str(file_name_value)
		if _automatic_save_filename_v089(file_name):
			entries.append({"name": file_name, "stamp": _auto_file_stamp_v089(file_name)})
	entries.sort_custom(func(a: Variant, b: Variant) -> bool:
		var aa := a as Dictionary
		var bb := b as Dictionary
		return int(aa.get("stamp", 0)) > int(bb.get("stamp", 0))
	)
	var removed: int = 0
	while entries.size() > MAX_AUTOSAVES_089:
		var old := entries.pop_back() as Dictionary
		if dir.remove(str(old.get("name", ""))) == OK:
			removed += 1
	return removed


func _refresh_build_list_v050() -> void:
	if builds_list_v050 == null:
		return
	_prune_auto_saves_worker_v089()
	builds_list_v050.clear()
	build_paths_v050.clear()
	_ensure_builds_dir_v050()
	var dir := DirAccess.open(BUILDS_DIR_V050)
	var entries: Array = []
	if dir != null:
		for file_name_value in dir.get_files():
			var file_name: String = str(file_name_value)
			if not file_name.to_lower().ends_with(".connex"):
				continue
			var path: String = "%s/%s" % [BUILDS_DIR_V050, file_name]
			var display_name: String = file_name.trim_suffix(".connex")
			var saved_unix: float = 0.0
			var value: Variant = _read_variant_file_v050(path)
			if value is Dictionary:
				var bundle := value as Dictionary
				display_name = str(bundle.get("name", display_name))
				saved_unix = float(bundle.get("saved_unix", 0.0))
			entries.append({"path": path, "name": display_name, "saved": saved_unix, "file": file_name})
	entries.sort_custom(func(a: Variant, b: Variant) -> bool:
		var aa := a as Dictionary
		var bb := b as Dictionary
		var at: float = float(aa.get("saved", 0.0))
		var bt: float = float(bb.get("saved", 0.0))
		if not is_equal_approx(at, bt):
			return at > bt
		return str(aa.get("file", "")) > str(bb.get("file", ""))
	)
	for entry_value in entries:
		var entry := entry_value as Dictionary
		builds_list_v050.add_item(str(entry.get("name", "Build")))
		build_paths_v050.append(str(entry.get("path", "")))
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
			recovery_label_v050.text = "Last autosave is available as an additional recovery point. Up to five rolling autosaves are kept in the list below."
		else:
			recovery_label_v050.text = "Autosave starts after the first build change. Up to five rolling autosaves are kept."


func _install_save_list_touch_v089() -> void:
	if builds_list_v050 == null:
		return
	var callback := Callable(self, "_on_build_list_gui_input_v089")
	if not builds_list_v050.gui_input.is_connected(callback):
		builds_list_v050.gui_input.connect(callback)


func _on_build_list_gui_input_v089(event: InputEvent) -> void:
	if builds_list_v050 == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if save_scroll_touch_v089 < 0:
				save_scroll_touch_v089 = touch.index
				save_scroll_distance_v089 = 0.0
				save_scroll_dragging_v089 = false
		elif touch.index == save_scroll_touch_v089:
			if save_scroll_dragging_v089:
				builds_list_v050.accept_event()
			save_scroll_touch_v089 = -1
			save_scroll_distance_v089 = 0.0
			save_scroll_dragging_v089 = false
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != save_scroll_touch_v089:
			return
		save_scroll_distance_v089 += absf(drag.relative.y)
		if save_scroll_distance_v089 >= SAVE_SCROLL_DEADZONE_089:
			save_scroll_dragging_v089 = true
		if not save_scroll_dragging_v089:
			return
		var bar: VScrollBar = builds_list_v050.get_v_scroll_bar()
		if bar != null:
			var max_scroll: float = maxf(bar.min_value, bar.max_value - bar.page)
			bar.value = clampf(bar.value - drag.relative.y, bar.min_value, max_scroll)
		builds_list_v050.accept_event()


# -----------------------------------------------------------------------------
# Autosave latency: keep crash recovery, but never stringify/flush a full build
# on the Android UI thread after every edit. Capture from the already-committed
# history snapshot after an idle debounce, then serialize/write on one worker.
# A fixed recovery file is retained and five rolling autosaves are kept.
# -----------------------------------------------------------------------------

func _schedule_autosave_v050() -> void:
	if not autosave_ready_v050 or not session_tracking_v050:
		return
	autosave_revision_v089 += 1
	autosave_pending_v050 = true
	autosave_due_ms_v050 = Time.get_ticks_msec() + AUTOSAVE_IDLE_MS_089


func _autosave_bundle_v089() -> Dictionary:
	var snapshot: Dictionary = {}
	if state_index >= 0 and state_index < state_history.size() and state_history[state_index] is Dictionary:
		snapshot = (state_history[state_index] as Dictionary).duplicate(true)
	else:
		snapshot = _capture_state()
	var now_unix: int = int(Time.get_unix_time_from_system())
	var stamp := Time.get_datetime_dict_from_unix_time(now_unix)
	var display_name: String = "Autosave %04d-%02d-%02d %02d:%02d:%02d" % [
		int(stamp.get("year", 0)), int(stamp.get("month", 0)), int(stamp.get("day", 0)),
		int(stamp.get("hour", 0)), int(stamp.get("minute", 0)), int(stamp.get("second", 0))
	]
	return {
		"format": SAVE_FORMAT_V050,
		"app_version": VERSION_089,
		"name": display_name,
		"saved_unix": now_unix,
		"automatic": true,
		"snapshot": snapshot,
		"camera_target": camera_target,
		"camera_distance": camera_distance,
		"camera_yaw": camera_yaw,
		"camera_pitch": camera_pitch,
		"attach_mode": attach_mode,
	}


func _write_text_file_worker_v089(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true


func _autosave_worker_v089(bundle: Dictionary, revision: int, rolling_path: String) -> Dictionary:
	var text: String = var_to_str(bundle)
	var recovery_ok: bool = _write_text_file_worker_v089(AUTOSAVE_PATH_V050, text)
	var rolling_ok: bool = false
	if recovery_ok and _ensure_builds_dir_worker_v089():
		rolling_ok = _write_text_file_worker_v089(rolling_path, text)
		_prune_auto_saves_worker_v089()
	return {"ok": recovery_ok, "rolling_ok": rolling_ok, "revision": revision}


func _ensure_builds_dir_worker_v089() -> bool:
	var root := DirAccess.open("user://")
	if root == null:
		return false
	if root.dir_exists("connex_builds"):
		return true
	return root.make_dir("connex_builds") == OK


func _consume_autosave_result_v089(result: Variant) -> bool:
	if not (result is Dictionary):
		return false
	var data := result as Dictionary
	var ok: bool = bool(data.get("ok", false))
	var revision: int = int(data.get("revision", -1))
	if ok and revision == autosave_revision_v089:
		autosave_pending_v050 = false
	elif autosave_pending_v050:
		autosave_due_ms_v050 = Time.get_ticks_msec() + AUTOSAVE_IDLE_MS_089
	if builds_panel_v050 != null and builds_panel_v050.visible:
		_refresh_build_list_v050()
	return ok


func _finish_autosave_thread_v089() -> bool:
	if autosave_thread_v089 == null:
		return true
	var result: Variant = null
	if autosave_thread_v089.is_started():
		result = autosave_thread_v089.wait_to_finish()
	autosave_thread_v089 = null
	autosave_thread_revision_v089 = -1
	if result == null:
		return true
	return _consume_autosave_result_v089(result)


func _write_autosave_v050() -> bool:
	if simulating:
		return false
	if autosave_thread_v089 != null and autosave_thread_v089.is_started():
		if autosave_thread_v089.is_alive():
			autosave_due_ms_v050 = Time.get_ticks_msec() + AUTOSAVE_RETRY_MS_089
			return true
		_finish_autosave_thread_v089()

	var revision: int = autosave_revision_v089
	var bundle: Dictionary = _autosave_bundle_v089()
	var stamp_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var rolling_path: String = "%s/Autosave_%d.connex" % [BUILDS_DIR_V050, stamp_ms]
	if autosave_force_sync_v089:
		return _consume_autosave_result_v089(_autosave_worker_v089(bundle, revision, rolling_path))

	autosave_thread_v089 = Thread.new()
	autosave_thread_revision_v089 = revision
	var err: Error = autosave_thread_v089.start(Callable(self, "_autosave_worker_v089").bind(bundle, revision, rolling_path))
	if err != OK:
		autosave_thread_v089 = null
		autosave_thread_revision_v089 = -1
		return false
	return true


func _process(delta: float) -> void:
	super._process(delta)
	if autosave_thread_v089 != null and autosave_thread_v089.is_started() and not autosave_thread_v089.is_alive():
		_finish_autosave_thread_v089()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_finish_autosave_thread_v089()
		autosave_force_sync_v089 = true
		super._notification(what)
		autosave_force_sync_v089 = false
		return
	super._notification(what)


# -----------------------------------------------------------------------------
# Updater: compare GitHub against the actual descendant runtime version, not the
# old v0.5.0 constant inherited by the save-system override.
# -----------------------------------------------------------------------------

func _reconcile_update_version_v089(latest: String) -> void:
	var clean: String = latest.strip_edges().trim_prefix("v")
	if clean.is_empty():
		return
	if _compare_versions_v021(clean, VERSION_089) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		pending_apk_uri_v021 = null
		waiting_unknown_sources_permission_v021 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_089)
		if update_button_v021 != null:
			update_button_v021.disabled = false
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_089, clean])
		if update_button_v021 != null and not update_available_url_v021.is_empty():
			update_button_v021.text = "Update to v%s" % clean


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", ""))
	_reconcile_update_version_v089(latest)
