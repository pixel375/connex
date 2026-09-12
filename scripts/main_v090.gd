extends "res://scripts/main_v089.gd"

const VERSION_090 := "0.5.27"

var legacy_commit_autofuse_bypasses_v090: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_090)
	_status("v0.5.27 ready — obsolete whole-build commit auto-fuse removed.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_090, text]


# v0.1.7 put a six-pass whole-construction auto-fuse scan inside every commit.
# v0.2.0 later replaced that matcher with _auto_connect_all_v020(), and the
# current runtime already runs the modern targeted matcher before it descends
# through the v0.1.7 commit layer. The old scan was nevertheless still running
# a second time after every edit. On Android that O(n^2)-ish duplicate is the
# dominant large-build click stall.
#
# Bypass it only while the authoritative v0.2+ commit is in progress. Keeping
# the inherited implementation available outside that commit makes this a
# surgical latency fix rather than a physics/connection behavior change.
func _auto_fuse_all_v017() -> int:
	if committing_v020:
		legacy_commit_autofuse_bypasses_v090 += 1
		return 0
	return super._auto_fuse_all_v017()


# Keep persisted metadata and updater comparisons on the actual running version
# instead of inheriting v0.5.26's literal version string.
func _save_bundle_v050(name_value: String) -> Dictionary:
	var bundle: Dictionary = super._save_bundle_v050(name_value)
	bundle["app_version"] = VERSION_090
	return bundle


func _autosave_bundle_v089() -> Dictionary:
	var bundle: Dictionary = super._autosave_bundle_v089()
	bundle["app_version"] = VERSION_090
	return bundle


func _reconcile_update_version_v089(latest: String) -> void:
	var clean: String = latest.strip_edges().trim_prefix("v")
	if clean.is_empty():
		return
	if _compare_versions_v021(clean, VERSION_090) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		pending_apk_uri_v021 = null
		waiting_unknown_sources_permission_v021 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_090)
		if update_button_v021 != null:
			update_button_v021.disabled = false
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_090, clean])
		if update_button_v021 != null and not update_available_url_v021.is_empty():
			update_button_v021.text = "Update to v%s" % clean
