extends "res://scripts/main_v037.gd"

const VERSION_038 := "0.3.8"
const MOUNT_HOME_META_038 := "mount_home_relative_basis_v036"
const SNAPSHOT_MOUNT_HOME_038 := "v038_mount_home"


func _ready() -> void:
	super._ready()
	_apply_piece_collision_policy_v038()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_038)
	_status("Audit fixes active: mount-reset homes survive history, disconnected constructions collide in simulation, and signing metadata is guarded by CI.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_038, text]


# -----------------------------------------------------------------------------
# Collision policy
#
# Layer 1 = ground/world, layer 2 = construction pieces. Older code put pieces
# on layer 2 but gave them mask 1 only, which meant disconnected mechanisms and
# loose parts passed through each other. The simulation-preflight code already
# installs collision exceptions for bodies in the same rigid fixed component;
# direct Godot joints also exclude their connected bodies from collision. The
# intended policy is therefore ground + unrelated construction collisions.
# -----------------------------------------------------------------------------

func _configure_piece_body(body: RigidBody3D) -> void:
	super._configure_piece_body(body)
	body.collision_layer = 2
	body.collision_mask = 3


func _apply_piece_collision_policy_v038() -> void:
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			body.collision_layer = 2
			body.collision_mask = 3
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.collision_layer = 2
			ring.collision_mask = 3


# -----------------------------------------------------------------------------
# Undo/Redo preservation for mount-relative Reset Placement Rotation.
#
# v0.3.6 introduced a home orientation stored on the live connection joint.
# History snapshots predated that field, so a restore recreated the joint and
# accidentally learned the restored/rolled orientation as the new home. Save it
# by stable connection UID and put it back after the inherited graph restore.
# -----------------------------------------------------------------------------

func _capture_state() -> Dictionary:
	var snapshot: Dictionary = super._capture_state()
	_rebuild_connection_graph_v020()
	var mount_homes: Array = []
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var joint: Joint3D = record.get("joint") as Joint3D
		if not is_instance_valid(joint) or not joint.has_meta(MOUNT_HOME_META_038):
			continue
		mount_homes.append({
			"uid": int(record.get("uid", -1)),
			"basis": joint.get_meta(MOUNT_HOME_META_038),
		})
	snapshot[SNAPSHOT_MOUNT_HOME_038] = mount_homes
	return snapshot


func _restore_state(snapshot: Dictionary) -> void:
	var saved_homes: Array = snapshot.get(SNAPSHOT_MOUNT_HOME_038, []) as Array
	super._restore_state(snapshot)
	if saved_homes.is_empty():
		_apply_piece_collision_policy_v038()
		return

	var by_uid: Dictionary = {}
	for saved_value in saved_homes:
		var saved: Dictionary = saved_value as Dictionary
		var uid: int = int(saved.get("uid", -1))
		if uid >= 0 and saved.has("basis"):
			by_uid[uid] = saved["basis"]

	_rebuild_connection_graph_v020()
	for record_value in connections_v020:
		var record: Dictionary = record_value as Dictionary
		var uid: int = int(record.get("uid", -1))
		if not by_uid.has(uid):
			continue
		var joint: Joint3D = record.get("joint") as Joint3D
		if is_instance_valid(joint):
			joint.set_meta(MOUNT_HOME_META_038, by_uid[uid])

	_apply_piece_collision_policy_v038()
	_refresh_selection_highlight()
	_update_ui()


func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nROTATE: X/Y/Z is a fixed-world transform gizmo. It rotates the selected connected construction island rigidly around the selected piece and snaps to exact 45° steps. Camera angle never defines those axes.\n\nROLL / RESET: Roll changes a mounted connector around its real connection axis. Reset Placement Rotation returns to the recorded mount-relative home. That home now survives Undo/Redo, Delete/Undo and other history restores.\n\nPHYSICS: disconnected pieces and disconnected assemblies collide with each other and the ground. Self-collision remains suppressed inside rigid fixed components, while real axle/sliding joints keep their intended degrees of freedom.\n\nRIGHT PANELS: Rotate and Move remain a one-open-at-a-time accordion.\n\nATTACH: SOCKET uses rod ends ↔ sockets. AXLE uses hub/O-Ring ↔ exact rod shaft. CROSS uses side socket ↔ rod shaft with the rod perpendicular to the connector face.\n\nCamera: one finger orbit, two fingers pan/zoom." % VERSION_038


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
	if _compare_versions_v021(latest, VERSION_038) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_038)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_038, latest])
