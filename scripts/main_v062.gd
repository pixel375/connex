extends "res://scripts/main_v061.gd"

const VERSION_062 := "0.5.7"

func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_062)
	_status("v0.5.7 active — a newly placed rod immediately attaches its aligned far end to a free connector socket.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_062, text]


func _extend_socket(connector: RigidBody3D, slot: int) -> void:
	if simulating or slot < 0 or not is_instance_valid(connector):
		return
	_rebuild_connection_graph_v020()
	var occupied: Dictionary = connector.get_meta("occupied", {}) as Dictionary
	if occupied.has(slot):
		_status("That connector socket already has a rod")
		return

	var rod_len: float = float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var socket: Dictionary = _socket_world_v020(connector, slot)
	var start: Vector3 = socket.get("point", connector.global_position) as Vector3
	var direction: Vector3 = (socket.get("dir", Vector3.RIGHT) as Vector3).normalized()
	var finish: Vector3 = start + direction * rod_len
	var rod: RigidBody3D = _make_rod(selected_rod_type, start, finish)

	# Attach the end the user tapped first.
	var source_joint: Generic6DOFJoint3D = _make_fixed_joint(connector, rod, start)
	_tag_connection_v020(source_joint, "socket", connector, rod, slot, -1, 0.0, null, false)
	_set_connector_occupied(connector, slot, true)
	_set_rod_end_occupied(rod, -1, true)
	rod.set_meta("build_transform", rod.global_transform)

	# v0.5.7 bug fix: immediately test and attach the new rod's opposite end BEFORE
	# the placement state is committed. This does not depend on ATTACH mode or on a
	# later SIMULATE scan. If the far end lines up with a compatible free socket,
	# it becomes a real SOCKET graph connection now.
	_rebuild_connection_graph_v020()
	var far_attached: bool = _auto_connect_end_v020(rod, 1)
	if far_attached:
		_rebuild_connection_graph_v020()
		_relax_connection_geometry_v059(SNAP_RELAX_PASSES_V059)
		_update_build_transforms_v059()
		_refresh_joint_frames_v020()
		_rebuild_connection_graph_v020()

	_set_selected(rod)
	_commit_state()
	if far_attached:
		_status("Rod added — both ends automatically attached to aligned connector sockets.")
	else:
		_status("Rod added — far end is free because no compatible aligned socket is present.")


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_062) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_062)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
