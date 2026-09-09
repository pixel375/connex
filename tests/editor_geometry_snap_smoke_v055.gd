extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("EDITOR_055_SMOKE_FAIL: %s" % message)
	quit(1)


func _connector_index(defs: Array, wanted: String) -> int:
	for i in range(defs.size()):
		if str((defs[i] as Dictionary).get("name", "")) == wanted:
			return i
	return -1


func _count_live_meshes(node: Node, inside_highlight: bool = false) -> int:
	if node == null:
		return 0
	var total: int = 0
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null or child.is_queued_for_deletion():
			continue
		var now_highlight: bool = inside_highlight or str(child.name) == "SelectionHighlight"
		if child is MeshInstance3D and not now_highlight:
			total += 1
		total += _count_live_meshes(child, now_highlight)
	return total


func _count_highlight_meshes(node: Node, inside_highlight: bool = false) -> int:
	if node == null:
		return 0
	var total: int = 0
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null or child.is_queued_for_deletion():
			continue
		var now_highlight: bool = inside_highlight or str(child.name) == "SelectionHighlight"
		if child is MeshInstance3D and now_highlight:
			total += 1
		total += _count_highlight_meshes(child, now_highlight)
	return total


func _connect_socket(main: Node, connector: RigidBody3D, rod: RigidBody3D, slot: int, rod_end: int) -> void:
	var socket: Dictionary = main.call("_socket_world_v020", connector, slot) as Dictionary
	var rod_point: Vector3 = main.call("_rod_end_v020", rod, rod_end) as Vector3
	var point: Vector3 = ((socket.get("point", connector.global_position) as Vector3) + rod_point) * 0.5
	var joint: Generic6DOFJoint3D = main.call("_make_fixed_joint", connector, rod, point) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", joint, "socket", connector, rod, slot, rod_end, 0.0, null, false)
	main.call("_set_connector_occupied", connector, slot, true)
	main.call("_set_rod_end_occupied", rod, rod_end, true)


func _rotate_rod_about_endpoint(main: Node, rod: RigidBody3D, sign_value: int, axis: Vector3, angle: float) -> void:
	var pivot: Vector3 = main.call("_rod_end_v020", rod, sign_value) as Vector3
	var rotation_basis: Basis = Basis(axis.normalized(), angle)
	var old_axis: Vector3 = main.call("_rod_axis_v020", rod) as Vector3
	var xform: Transform3D = rod.global_transform
	xform.origin = pivot + rotation_basis * (xform.origin - pivot)
	xform.basis = (rotation_basis * xform.basis).orthonormalized()
	rod.global_transform = xform
	rod.set_meta("axis", (rotation_basis * old_axis).normalized())


func _find_socket_record(main: Node, rod: RigidBody3D, rod_end: int) -> Dictionary:
	var records: Array = main.get("connections_v020") as Array
	for value in records:
		var record: Dictionary = value as Dictionary
		if str(record.get("kind", "")) == "socket" and record.get("rod") == rod and int(record.get("rod_end", 0)) == rod_end:
			return record
	return {}


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v063.gd"):
		_fail("Main is not using a descendant runtime with v0.5.5 geometry behavior")
		return

	var defs: Array = main.get("connector_defs") as Array
	var index_14: int = _connector_index(defs, "14-point 3D")
	var index_2: int = _connector_index(defs, "Light gray 2-way")
	var index_8: int = _connector_index(defs, "White 8-way")
	if index_14 < 0 or index_2 < 0 or index_8 < 0:
		_fail("required connector definitions missing")
		return

	# -------------------------------------------------------------------------
	# Phantom-highlight regression: old 14-point meshes must not be cloned into
	# the new selected 2-way outline during the same rebuild frame.
	# -------------------------------------------------------------------------
	var spatial: RigidBody3D = main.call("_make_connector", index_14, Transform3D(Basis.IDENTITY, Vector3(35.0, 8.0, 0.0))) as RigidBody3D
	main.call("_set_selected", spatial)
	main.call("_refresh_selection_highlight")
	main.call("_rebuild_connector", spatial, index_2)
	var real_meshes: int = _count_live_meshes(spatial, false)
	var highlight_meshes: int = _count_highlight_meshes(spatial, false)
	if real_meshes <= 0:
		_fail("rebuilt 2-way connector has no live meshes")
		return
	if highlight_meshes != real_meshes:
		_fail("phantom highlight mesh count mismatch immediately after 14->2 rebuild: live=%d highlight=%d" % [real_meshes, highlight_meshes])
		return
	await process_frame
	if _count_highlight_meshes(spatial, false) != _count_live_meshes(spatial, false):
		_fail("highlight diverged from live geometry after queued deletions flushed")
		return

	# -------------------------------------------------------------------------
	# Wider capture regression: a free rod end 2.6 units from the mathematical
	# socket (beyond v0.5.4's 2.0 shell) must still snap when direction/lateral
	# geometry clearly identifies one port.
	# -------------------------------------------------------------------------
	var far_connector: RigidBody3D = main.call("_make_connector", index_8, Transform3D(Basis.IDENTITY, Vector3(100.0, 8.0, 0.0))) as RigidBody3D
	var far_rod: RigidBody3D = main.call("_make_rod", 2, Vector3(110.0, 8.0, 0.0), Vector3(103.61, 8.0, 0.0)) as RigidBody3D
	main.call("_rebuild_connection_graph_v020")
	var far_before: Dictionary = main.call("_best_socket_for_end_v020", far_rod, 1) as Dictionary
	if far_before.is_empty() or far_before.get("connector") != far_connector:
		_fail("wider proximity matcher did not find the unambiguous 2.6-unit socket target")
		return
	var wide_fused: int = int(main.call("_auto_connect_all_v020"))
	if wide_fused < 1:
		_fail("wider proximity candidate was not auto-attached")
		return
	main.call("_rebuild_connection_graph_v020")
	var far_record: Dictionary = _find_socket_record(main, far_rod, 1)
	if far_record.is_empty() or far_record.get("connector") != far_connector:
		_fail("wider proximity auto-attach did not create the expected record")
		return
	if float(main.call("_connection_gap_v059", far_record)) > 0.06:
		_fail("separate-island wide capture did not visibly close")
		return

	# -------------------------------------------------------------------------
	# Same-island loop closure. Three square edges + one anchored fourth rod make
	# the free end and final connector already part of one fixed component. Rotate
	# that fourth rod about its attached end to create the exact failure mode from
	# device builds: valid nearby closure, but a visible gap stored in the loop.
	# -------------------------------------------------------------------------
	var d: float = 1.01
	var rod_len: float = 5.40
	var span: float = rod_len + d * 2.0
	var origin: Vector3 = Vector3(10.0, 14.0, 40.0)
	var a: RigidBody3D = main.call("_make_connector", index_8, Transform3D(Basis.IDENTITY, origin)) as RigidBody3D
	var b: RigidBody3D = main.call("_make_connector", index_8, Transform3D(Basis.IDENTITY, origin + Vector3(span, 0.0, 0.0))) as RigidBody3D
	var c: RigidBody3D = main.call("_make_connector", index_8, Transform3D(Basis.IDENTITY, origin + Vector3(span, 0.0, span))) as RigidBody3D
	var d_conn: RigidBody3D = main.call("_make_connector", index_8, Transform3D(Basis.IDENTITY, origin + Vector3(0.0, 0.0, span))) as RigidBody3D
	a.set_meta("root_piece_v020", true)

	var ab_start: Vector3 = (main.call("_socket_world_v020", a, 0) as Dictionary).get("point") as Vector3
	var ab_finish: Vector3 = (main.call("_socket_world_v020", b, 180) as Dictionary).get("point") as Vector3
	var ab: RigidBody3D = main.call("_make_rod", 2, ab_start, ab_finish) as RigidBody3D
	_connect_socket(main, a, ab, 0, -1)
	_connect_socket(main, b, ab, 180, 1)

	var bc_start: Vector3 = (main.call("_socket_world_v020", b, 270) as Dictionary).get("point") as Vector3
	var bc_finish: Vector3 = (main.call("_socket_world_v020", c, 90) as Dictionary).get("point") as Vector3
	var bc: RigidBody3D = main.call("_make_rod", 2, bc_start, bc_finish) as RigidBody3D
	_connect_socket(main, b, bc, 270, -1)
	_connect_socket(main, c, bc, 90, 1)

	var cd_start: Vector3 = (main.call("_socket_world_v020", c, 180) as Dictionary).get("point") as Vector3
	var cd_finish: Vector3 = (main.call("_socket_world_v020", d_conn, 0) as Dictionary).get("point") as Vector3
	var cd: RigidBody3D = main.call("_make_rod", 2, cd_start, cd_finish) as RigidBody3D
	_connect_socket(main, c, cd, 180, -1)
	_connect_socket(main, d_conn, cd, 0, 1)

	var da_start: Vector3 = (main.call("_socket_world_v020", d_conn, 90) as Dictionary).get("point") as Vector3
	var da_finish: Vector3 = (main.call("_socket_world_v020", a, 270) as Dictionary).get("point") as Vector3
	var da: RigidBody3D = main.call("_make_rod", 2, da_start, da_finish) as RigidBody3D
	_connect_socket(main, d_conn, da, 90, -1)
	main.call("_rebuild_connection_graph_v020")

	_rotate_rod_about_endpoint(main, da, -1, Vector3.UP, deg_to_rad(4.0))
	main.call("_refresh_joint_frames_v020")
	main.call("_rebuild_connection_graph_v020")
	var gap_before: float = (main.call("_rod_end_v020", da, 1) as Vector3).distance_to((main.call("_socket_world_v020", a, 270) as Dictionary).get("point") as Vector3)
	if gap_before < 0.30 or gap_before > 2.0:
		_fail("same-island test gap is outside intended close range: %.3f" % gap_before)
		return
	var da_component: Array = main.call("_fixed_component_v020", da, -1) as Array
	if not bool(main.call("_component_has_piece_v020", da_component, a)):
		_fail("same-island fixture is not actually one fixed component before closure")
		return

	var loop_fused: int = int(main.call("_auto_connect_all_v020"))
	if loop_fused < 1:
		_fail("same-island close endpoint was not auto-attached")
		return
	main.call("_rebuild_connection_graph_v020")
	var closure: Dictionary = _find_socket_record(main, da, 1)
	if closure.is_empty() or closure.get("connector") != a or int(closure.get("slot", -1)) != 270:
		_fail("same-island closure attached to the wrong connector/socket")
		return
	var closure_gap: float = float(main.call("_connection_gap_v059", closure))
	if closure_gap > 0.08:
		_fail("same-island closure remained visibly open after projection: %.3f" % closure_gap)
		return

	var square_bodies: Dictionary = {
		a.get_instance_id(): true,
		b.get_instance_id(): true,
		c.get_instance_id(): true,
		d_conn.get_instance_id(): true,
		ab.get_instance_id(): true,
		bc.get_instance_id(): true,
		cd.get_instance_id(): true,
		da.get_instance_id(): true,
	}
	var square_records: int = 0
	var max_square_gap: float = 0.0
	for value in (main.get("connections_v020") as Array):
		var record: Dictionary = value as Dictionary
		if str(record.get("kind", "")) != "socket":
			continue
		var con: RigidBody3D = record.get("connector") as RigidBody3D
		var rr: RigidBody3D = record.get("rod") as RigidBody3D
		if is_instance_valid(con) and is_instance_valid(rr) and square_bodies.has(con.get_instance_id()) and square_bodies.has(rr.get_instance_id()):
			square_records += 1
			max_square_gap = maxf(max_square_gap, float(main.call("_connection_gap_v059", record)))
	if square_records != 8:
		_fail("square should contain 8 socket records after closure, got %d" % square_records)
		return
	if max_square_gap > 0.34:
		_fail("loop projection left another square attachment visibly open: max %.3f" % max_square_gap)
		return

	# v0.5.8 deliberately changes only the last part of the old preflight behavior:
	# the legacy v0.1.4 pass still identifies a redundant fixed-cycle edge, but if
	# that edge is a real SOCKET it is immediately restored so the physical socket
	# cannot open under gravity. Verify the legacy path was exercised and that no
	# SOCKET remains disabled afterward.
	main.call("_prepare_stable_simulation_graph")
	if int(main.get("restored_socket_loop_constraints_v063")) < 1:
		_fail("loop fixture did not exercise and restore legacy redundant SOCKET suppression")
		return
	for joint_value in (main.get("joints") as Array):
		var joint: Joint3D = joint_value as Joint3D
		if is_instance_valid(joint) and str(joint.get_meta("connection_kind_v020", "")) == "socket" and bool(joint.get_meta("sim_disabled", false)):
			_fail("a real socket connection remained suppressed after simulation preflight")
			return
	var after_prepare_gap: float = float(main.call("_connection_gap_v059", closure))
	if after_prepare_gap > 0.08:
		_fail("simulation preflight reopened the snapped loop: %.3f" % after_prepare_gap)
		return
	main.call("_restore_simulation_joint_graph")

	print("EDITOR_055_SMOKE_OK: no queued phantom highlight + >2.0 capture + same-island closed-loop projection + loop SOCKET preserved through preflight")
	main.queue_free()
	await process_frame
	quit(0)
