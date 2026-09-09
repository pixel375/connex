extends "res://scripts/main_v062.gd"

const VERSION_063 := "0.5.8"

var restored_socket_loop_constraints_v063: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_063)
	_status("v0.5.8 active — real SOCKET attachments remain active in simulation even when they close a rigid loop.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_063, text]


# v0.1.4 intentionally removed every fixed-joint cycle edge before simulation.
# That made the solver graph a tree, but it also meant the visibly closed socket
# at the removed edge had no physical constraint. Under gravity the tree flexed
# and that rod end opened up exactly as seen on-device.
#
# Keep the inherited preflight for collision exceptions and duplicate axle
# suppression, then restore only real SOCKET joints that it classified as a
# redundant fixed-cycle edge. This changes no BUILD placement or auto-attach
# behavior; it only prevents an already-recorded socket connection from being
# discarded when SIMULATE starts.
func _restore_suppressed_socket_loops_v063() -> int:
	var restored: int = 0
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("sim_disabled", false)):
			continue
		if str(joint.get_meta("connection_kind_v020", "")) != "socket":
			continue
		var saved_a: NodePath = joint.get_meta("sim_saved_node_a", NodePath())
		var saved_b: NodePath = joint.get_meta("sim_saved_node_b", NodePath())
		if saved_a.is_empty() or saved_b.is_empty():
			continue
		joint.node_a = saved_a
		joint.node_b = saved_b
		joint.remove_meta("sim_saved_node_a")
		joint.remove_meta("sim_saved_node_b")
		joint.remove_meta("sim_disabled")
		restored += 1
	if restored > 0:
		simulation_disabled_joint_count = maxi(0, simulation_disabled_joint_count - restored)
		_rebind_all_joints()
	return restored


func _prepare_stable_simulation_graph() -> void:
	# Preserve every inherited preflight step first: final close-attachment scan,
	# geometry normalization, fixed-component self-collision suppression, and
	# duplicate axle filtering.
	super._prepare_stable_simulation_graph()
	restored_socket_loop_constraints_v063 = _restore_suppressed_socket_loops_v063()


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_063) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_063)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
