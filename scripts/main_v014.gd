extends "res://scripts/main_v013.gd"

const VERSION_014 = "0.1.4"
const ROTATION_STEP_RAD = PI / 4.0

var rotate_y_button: Button
var rotate_x_button: Button
var reset_rotation_button: Button
var delete_button: Button
var mode_action_button: Button

var selection_material: StandardMaterial3D
var highlighted_body: RigidBody3D
var simulation_collision_pairs: Array = []
var simulation_collision_pair_keys: Dictionary = {}
var simulation_disabled_joint_count: int = 0


func _ready() -> void:
	setup_active = false
	selected_rod_type = 2
	selected_connector_type = 6
	_build_world()
	_build_ui()
	_create_fresh_seed()
	_commit_state()
	_status("Select a connector, then use Rotate Y / Rotate X. Reset Rotation returns it to its placement orientation.")


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	var top: PanelContainer = PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 10
	top.offset_bottom = 58
	layer.add_child(top)

	var top_row: HBoxContainer = HBoxContainer.new()
	top.add_child(top_row)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 19)
	top_row.add_child(status_label)

	var help_button: Button = _make_ui_button("?", _toggle_help)
	help_button.custom_minimum_size = Vector2(56, 42)
	top_row.add_child(help_button)

	bottom_panel = PanelContainer.new()
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 8
	bottom_panel.offset_right = -8
	bottom_panel.offset_top = -228
	bottom_panel.offset_bottom = -8
	bottom_panel.visible = true
	layer.add_child(bottom_panel)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	bottom_panel.add_child(rows)

	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	rows.add_child(row1)
	row1.add_child(_make_ui_button("◀ Rod", _prev_rod))
	rod_label = _make_ui_label()
	row1.add_child(rod_label)
	row1.add_child(_make_ui_button("Rod ▶", _next_rod))
	row1.add_child(_make_ui_button("◀ Conn", _prev_connector))
	connector_label = _make_ui_label()
	row1.add_child(connector_label)
	row1.add_child(_make_ui_button("Conn ▶", _next_connector))

	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	rows.add_child(row2)
	mode_button = _make_ui_button("SOCKET", _cycle_mode)
	row2.add_child(mode_button)
	rotate_y_button = _make_ui_button("Rotate Y", _rotate_selected_y)
	row2.add_child(rotate_y_button)
	rotate_x_button = _make_ui_button("Rotate X", _rotate_selected_x)
	row2.add_child(rotate_x_button)
	reset_rotation_button = _make_ui_button("Reset Rotation", _reset_selected_rotation)
	row2.add_child(reset_rotation_button)
	delete_button = _make_ui_button("Delete", _delete_selected)
	row2.add_child(delete_button)

	var row3: HBoxContainer = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	rows.add_child(row3)
	mode_action_button = _make_ui_button("Socket: tap point", _mode_action)
	row3.add_child(mode_action_button)
	row3.add_child(_make_ui_button("Undo", _undo))
	redo_button = _make_ui_button("Redo", _redo)
	row3.add_child(redo_button)
	simulate_button = _make_ui_button("SIMULATE", _toggle_simulation)
	row3.add_child(simulate_button)
	row3.add_child(_make_ui_button("Restart", _restart_build))
	row3.add_child(_make_ui_button("Restore Pose", _reset_pose))
	row3.add_child(_make_ui_button("Center View", _center_view))

	var hint: Label = Label.new()
	hint.text = "1 finger: orbit   •   2 fingers: pan + zoom   •   tap connector body/hub: select"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 14)
	rows.add_child(hint)

	help_panel = PanelContainer.new()
	help_panel.visible = false
	help_panel.anchor_left = 0.10
	help_panel.anchor_right = 0.90
	help_panel.anchor_top = 0.08
	help_panel.anchor_bottom = 0.76
	layer.add_child(help_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	help_panel.add_child(margin)

	var help: Label = Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 17)
	help.text = "CONNEX LAB v0.1.4\n\nSELECTION: tapping a connector body/hub selects it instead of rotating it. The selected piece gets a bright outline. In SOCKET mode, tapping an actual free outer socket still places a rod.\n\nROTATION: select a connector, then use Rotate Y or Rotate X. Both are local connector axes and rotate in 45° steps. Reset Rotation returns to the orientation that connector had when it was first placed. Any rotation that would break an existing rod/socket or axle alignment is rejected.\n\nDELETE removes the selected rod or connector and frees all connection points that depended on it. Undo/Redo includes deletions and rotations.\n\nAXLE mode now uses the Insert Axle action after selecting a connector, so tapping a connector remains a selection gesture. CROSS still acts by tapping a rod body.\n\nPHYSICS: no piece is pinned, including the first connector. Before simulation, redundant closed-loop fixed joints are removed from the active solver, rigidly connected components stop self-colliding, duplicate/redundant axle constraints are suppressed, and all pieces are released with the same gravity rules. This avoids the delayed shaking/exploding failure caused by an over-constrained joint graph while preserving collisions between unrelated pieces."
	margin.add_child(help)

	_update_ui()


func _make_connector(def_index: int, xform: Transform3D) -> RigidBody3D:
	var body: RigidBody3D = super._make_connector(def_index, xform)
	body.set_meta("rotation_home_basis", body.global_transform.basis)
	body.set_meta("seed", false)
	body.linear_damp = 0.20
	body.angular_damp = 0.34
	return body


func _make_rod(def_index: int, start: Vector3, finish: Vector3) -> RigidBody3D:
	var body: RigidBody3D = super._make_rod(def_index, start, finish)
	body.linear_damp = 0.20
	body.angular_damp = 0.34
	return body


func _create_fresh_seed() -> void:
	super._create_fresh_seed()
	if is_instance_valid(selected_piece):
		selected_piece.set_meta("seed", false)
		if str(selected_piece.get_meta("kind", "")) == "connector":
			selected_piece.set_meta("rotation_home_basis", selected_piece.global_transform.basis)
		selected_piece.set_meta("build_transform", selected_piece.global_transform)


func _selection_mat() -> StandardMaterial3D:
	if selection_material != null:
		return selection_material
	selection_material = StandardMaterial3D.new()
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.albedo_color = Color(0.78, 0.92, 1.0, 0.42)
	selection_material.emission_enabled = true
	selection_material.emission = Color(0.72, 0.90, 1.0)
	selection_material.cull_mode = BaseMaterial3D.CULL_FRONT
	return selection_material


func _clear_selection_highlight() -> void:
	if not is_instance_valid(highlighted_body):
		highlighted_body = null
		return
	var old_highlight: Node = highlighted_body.get_node_or_null("SelectionHighlight")
	if old_highlight != null:
		highlighted_body.remove_child(old_highlight)
		old_highlight.queue_free()
	highlighted_body = null


func _refresh_selection_highlight() -> void:
	_clear_selection_highlight()
	if not is_instance_valid(selected_piece):
		return
	var body: RigidBody3D = selected_piece
	var highlight: Node3D = Node3D.new()
	highlight.name = "SelectionHighlight"
	highlighted_body = body
	body.add_child(highlight)
	for child_value in body.get_children():
		var source: MeshInstance3D = child_value as MeshInstance3D
		if source == null or source.is_queued_for_deletion() or source.mesh == null:
			continue
		var outline: MeshInstance3D = MeshInstance3D.new()
		outline.mesh = source.mesh
		outline.position = source.position
		outline.rotation = source.rotation
		outline.scale = source.scale * 1.075
		outline.material_override = _selection_mat()
		highlight.add_child(outline)


func _set_selected(body: RigidBody3D) -> void:
	_clear_selection_highlight()
	super._set_selected(body)
	_refresh_selection_highlight()


func _change_connector_type(delta: int) -> void:
	super._change_connector_type(delta)
	_refresh_selection_highlight()


func _change_rod_type(delta: int) -> void:
	super._change_rod_type(delta)
	_refresh_selection_highlight()


func _rotate_selected_y() -> void:
	_rotate_selected_local_axis(Vector3.UP, "Rotate Y 45°")


func _rotate_selected_x() -> void:
	_rotate_selected_local_axis(Vector3.RIGHT, "Rotate X 45°")


func _rotate_selected_local_axis(local_axis: Vector3, label: String) -> void:
	if simulating or _selected_kind() != "connector":
		_status("Select a connector first")
		return
	var connector: RigidBody3D = selected_piece
	var world_axis: Vector3 = (connector.global_transform.basis * local_axis).normalized()
	var candidate: Basis = Basis(world_axis, ROTATION_STEP_RAD) * connector.global_transform.basis
	if _try_connector_basis(connector, candidate, label):
		_refresh_selection_highlight()


func _reset_selected_rotation() -> void:
	if simulating or _selected_kind() != "connector":
		_status("Select a connector first")
		return
	var connector: RigidBody3D = selected_piece
	var home_basis: Basis = connector.get_meta("rotation_home_basis", connector.global_transform.basis)
	if _try_connector_basis(connector, home_basis, "Reset Rotation"):
		_refresh_selection_highlight()


func _mode_action() -> void:
	if simulating:
		return
	if attach_mode == 1:
		if _selected_kind() != "connector":
			_status("Select a connector, then press Insert Axle")
			return
		_insert_axle(selected_piece)
	elif attach_mode == 0:
		_status("SOCKET: tap a free outer socket on the selected connector")
	else:
		_status("CROSS: tap the rod body where the cross connector should snap")


func _handle_tap(screen_pos: Vector2) -> void:
	if simulating or help_panel.visible:
		return
	var now: int = Time.get_ticks_msec()
	if now - last_world_tap_ms < WORLD_TAP_DEBOUNCE_MS and last_world_tap_pos.distance_to(screen_pos) < 36.0:
		return
	last_world_tap_ms = now
	last_world_tap_pos = screen_pos

	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 800.0)
	query.collision_mask = 2 | 4
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var body: RigidBody3D = hit.get("collider") as RigidBody3D
	if not is_instance_valid(body):
		return

	var kind: String = str(body.get_meta("kind", ""))
	if kind == "connector":
		_set_selected(body)
		if attach_mode == 0:
			var slot: int = _select_slot_strict(body, hit["position"])
			if slot >= 0:
				_extend_socket(body, slot)
			elif slot == -3:
				_status("Connector selected — that socket is already occupied")
			else:
				_status("Connector selected — use Rotate Y / Rotate X / Reset Rotation")
		elif attach_mode == 1:
			_status("Connector selected — press Insert Axle")
		else:
			_status("Connector selected")
		return

	if kind != "rod":
		return

	_set_selected(body)
	if attach_mode == 0:
		var end_sign: int = _rod_end_hit(body, hit["position"])
		if end_sign != 0:
			_attach_connector_to_rod_end(body, end_sign)
		else:
			_status("Rod selected")
	elif attach_mode == 2:
		_cross_snap(body, hit["position"])
	else:
		_status("Rod selected")


func _connector_slot_from_anchor(connector: RigidBody3D, anchor: Vector3) -> int:
	var delta: Vector3 = anchor - connector.global_position
	if delta.length_squared() < 0.10:
		return -1
	var world_dir: Vector3 = delta.normalized()
	var local_dir: Vector3 = (connector.global_transform.basis.inverse() * world_dir).normalized()
	var def_index: int = int(connector.get_meta("connector_type"))
	var best_slot: int = -1
	var best_dot: float = 0.72
	for slot_value in connector_defs[def_index]["slots"]:
		var slot: int = int(slot_value)
		var score: float = local_dir.dot(_slot_dir(slot))
		if score > best_dot:
			best_dot = score
			best_slot = slot
	return best_slot


func _rod_end_sign_from_anchor(rod: RigidBody3D, anchor: Vector3) -> int:
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var half_length: float = float(rod.get_meta("visual_length")) * 0.5
	var along: float = (anchor - rod.global_position).dot(axis)
	if absf(absf(along) - half_length) <= END_HIT_MARGIN:
		return 1 if along >= 0.0 else -1
	return 0


func _recalculate_occupancy_from_joints() -> void:
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if str(body.get_meta("kind", "")) == "connector":
			body.set_meta("occupied", {})
			body.set_meta("axle_occupied", false)
		else:
			body.set_meta("end_occupied", {})

	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		var nodes: Array = _joint_nodes(joint)
		var body_a: RigidBody3D = nodes[0] as RigidBody3D
		var body_b: RigidBody3D = nodes[1] as RigidBody3D
		if not is_instance_valid(body_a) or not is_instance_valid(body_b):
			continue

		if str(joint.name).begins_with("AxleJoint"):
			var axle_connector: RigidBody3D = body_a if str(body_a.get_meta("kind", "")) == "connector" else body_b
			if is_instance_valid(axle_connector) and str(axle_connector.get_meta("kind", "")) == "connector":
				axle_connector.set_meta("axle_occupied", true)
			continue

		var anchor: Vector3 = joint.global_position
		_mark_fixed_joint_occupancy(body_a, anchor)
		_mark_fixed_joint_occupancy(body_b, anchor)


func _mark_fixed_joint_occupancy(body: RigidBody3D, anchor: Vector3) -> void:
	if not is_instance_valid(body):
		return
	if str(body.get_meta("kind", "")) == "connector":
		var slot: int = _connector_slot_from_anchor(body, anchor)
		if slot >= 0:
			_set_connector_occupied(body, slot, true)
	elif str(body.get_meta("kind", "")) == "rod":
		var sign_value: int = _rod_end_sign_from_anchor(body, anchor)
		if sign_value != 0:
			_set_rod_end_occupied(body, sign_value, true)


func _delete_selected() -> void:
	if simulating or not is_instance_valid(selected_piece):
		_status("Select a rod or connector to delete")
		return

	var target: RigidBody3D = selected_piece
	var fallback: RigidBody3D = null
	for joint_value in joints.duplicate():
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] != target and nodes[1] != target:
			continue
		var other: RigidBody3D = (nodes[1] if nodes[0] == target else nodes[0]) as RigidBody3D
		if fallback == null and is_instance_valid(other):
			fallback = other
		joints.erase(joint)
		joint.queue_free()

	_clear_selection_highlight()
	bodies.erase(target)
	target.collision_layer = 0
	target.collision_mask = 0
	target.queue_free()
	selected_piece = null

	_recalculate_occupancy_from_joints()
	_refresh_last_connector()
	_rebind_all_joints()

	if bodies.is_empty():
		_create_fresh_seed()
		_status("Deleted last piece — a fresh starting connector was created")
	elif is_instance_valid(fallback):
		_set_selected(fallback)
		_status("Deleted selected piece")
	else:
		_update_ui()
		_status("Deleted selected piece")

	_commit_state()


func _capture_state() -> Dictionary:
	var snapshot: Dictionary = super._capture_state()
	var saved_bodies: Array = snapshot["bodies"]
	var saved_index: int = 0
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if saved_index >= saved_bodies.size():
			break
		var state: Dictionary = saved_bodies[saved_index] as Dictionary
		if str(body.get_meta("kind", "")) == "connector":
			state["rotation_home_basis"] = body.get_meta("rotation_home_basis", body.global_transform.basis)
		saved_index += 1
	return snapshot


func _restore_state(snapshot: Dictionary) -> void:
	_restore_simulation_joint_graph()
	_clear_simulation_collision_exceptions()
	_clear_selection_highlight()
	super._restore_state(snapshot)

	var saved_bodies: Array = snapshot["bodies"]
	var restored_index: int = 0
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		if restored_index >= saved_bodies.size():
			break
		var state: Dictionary = saved_bodies[restored_index] as Dictionary
		if str(body.get_meta("kind", "")) == "connector":
			var home_basis: Basis = state.get("rotation_home_basis", body.global_transform.basis)
			body.set_meta("rotation_home_basis", home_basis)
			body.set_meta("seed", false)
		restored_index += 1
	_refresh_selection_highlight()


func _restart_build() -> void:
	_restore_simulation_joint_graph()
	_clear_simulation_collision_exceptions()
	_clear_selection_highlight()
	super._restart_build()
	if is_instance_valid(selected_piece):
		selected_piece.set_meta("seed", false)
	_refresh_selection_highlight()
	_status("Restarted at one editable, unpinned connector")


func _uf_find(parent: Array, value: int) -> int:
	var root: int = value
	while int(parent[root]) != root:
		root = int(parent[root])
	var current: int = value
	while int(parent[current]) != current:
		var next_value: int = int(parent[current])
		parent[current] = root
		current = next_value
	return root


func _uf_union(parent: Array, a: int, b: int) -> void:
	var root_a: int = _uf_find(parent, a)
	var root_b: int = _uf_find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a


func _disable_joint_for_simulation(joint: Joint3D) -> void:
	if bool(joint.get_meta("sim_disabled", false)):
		return
	joint.set_meta("sim_saved_node_a", joint.node_a)
	joint.set_meta("sim_saved_node_b", joint.node_b)
	joint.set_meta("sim_disabled", true)
	joint.node_a = NodePath()
	joint.node_b = NodePath()
	simulation_disabled_joint_count += 1


func _restore_simulation_joint_graph() -> void:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("sim_disabled", false)):
			continue
		var saved_a: NodePath = joint.get_meta("sim_saved_node_a", NodePath())
		var saved_b: NodePath = joint.get_meta("sim_saved_node_b", NodePath())
		joint.node_a = saved_a
		joint.node_b = saved_b
		joint.remove_meta("sim_saved_node_a")
		joint.remove_meta("sim_saved_node_b")
		joint.remove_meta("sim_disabled")
	simulation_disabled_joint_count = 0
	_rebind_all_joints()


func _collision_pair_key(a: RigidBody3D, b: RigidBody3D) -> String:
	var id_a: int = a.get_instance_id()
	var id_b: int = b.get_instance_id()
	return "%d:%d" % [mini(id_a, id_b), maxi(id_a, id_b)]


func _add_simulation_collision_exception(a: RigidBody3D, b: RigidBody3D) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b) or a == b:
		return
	var key: String = _collision_pair_key(a, b)
	if simulation_collision_pair_keys.has(key):
		return
	a.add_collision_exception_with(b)
	b.add_collision_exception_with(a)
	simulation_collision_pairs.append([a, b])
	simulation_collision_pair_keys[key] = true


func _clear_simulation_collision_exceptions() -> void:
	for pair_value in simulation_collision_pairs:
		var pair: Array = pair_value as Array
		if pair.size() < 2:
			continue
		var body_a: RigidBody3D = pair[0] as RigidBody3D
		var body_b: RigidBody3D = pair[1] as RigidBody3D
		if is_instance_valid(body_a) and is_instance_valid(body_b):
			body_a.remove_collision_exception_with(body_b)
			body_b.remove_collision_exception_with(body_a)
	simulation_collision_pairs.clear()
	simulation_collision_pair_keys.clear()


func _prepare_stable_simulation_graph() -> void:
	_restore_simulation_joint_graph()
	_clear_simulation_collision_exceptions()
	simulation_disabled_joint_count = 0

	var live_bodies: Array = []
	var index_by_id: Dictionary = {}
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		index_by_id[body.get_instance_id()] = live_bodies.size()
		live_bodies.append(body)

	var parent: Array = []
	for i in range(live_bodies.size()):
		parent.append(i)

	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		var body_a: RigidBody3D = nodes[0] as RigidBody3D
		var body_b: RigidBody3D = nodes[1] as RigidBody3D
		if not is_instance_valid(body_a) or not is_instance_valid(body_b):
			continue
		if not index_by_id.has(body_a.get_instance_id()) or not index_by_id.has(body_b.get_instance_id()):
			continue
		var index_a: int = int(index_by_id[body_a.get_instance_id()])
		var index_b: int = int(index_by_id[body_b.get_instance_id()])
		var root_a: int = _uf_find(parent, index_a)
		var root_b: int = _uf_find(parent, index_b)
		if root_a == root_b:
			_disable_joint_for_simulation(joint)
		else:
			_uf_union(parent, root_a, root_b)

	for i in range(live_bodies.size()):
		parent[i] = _uf_find(parent, i)

	for i in range(live_bodies.size()):
		var body_a: RigidBody3D = live_bodies[i] as RigidBody3D
		for j in range(i + 1, live_bodies.size()):
			if int(parent[i]) != int(parent[j]):
				continue
			var body_b: RigidBody3D = live_bodies[j] as RigidBody3D
			_add_simulation_collision_exception(body_a, body_b)

	var axle_pairs_seen: Dictionary = {}
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		var body_a: RigidBody3D = nodes[0] as RigidBody3D
		var body_b: RigidBody3D = nodes[1] as RigidBody3D
		if not is_instance_valid(body_a) or not is_instance_valid(body_b):
			continue
		if not index_by_id.has(body_a.get_instance_id()) or not index_by_id.has(body_b.get_instance_id()):
			continue
		var root_a: int = int(parent[int(index_by_id[body_a.get_instance_id()])])
		var root_b: int = int(parent[int(index_by_id[body_b.get_instance_id()])])
		if root_a == root_b:
			_disable_joint_for_simulation(joint)
			_add_simulation_collision_exception(body_a, body_b)
			continue
		var low_root: int = mini(root_a, root_b)
		var high_root: int = maxi(root_a, root_b)
		var pair_key: String = "%d:%d" % [low_root, high_root]
		if axle_pairs_seen.has(pair_key):
			_disable_joint_for_simulation(joint)
			_add_simulation_collision_exception(body_a, body_b)
		else:
			axle_pairs_seen[pair_key] = true


func _release_physics() -> void:
	_prepare_stable_simulation_graph()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not simulating:
		return

	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.set_meta("seed", false)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = false
		body.sleeping = false

	_update_ui()
	_status("Physics running — all pieces free; %d redundant constraints suppressed" % simulation_disabled_joint_count)


func _reset_pose() -> void:
	_restore_simulation_joint_graph()
	_clear_simulation_collision_exceptions()
	super._reset_pose()
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			body.set_meta("seed", false)
	_refresh_selection_highlight()


func _update_ui() -> void:
	if rod_label != null:
		rod_label.text = str(rod_defs[selected_rod_type]["name"])
	if connector_label != null:
		connector_label.text = str(connector_defs[selected_connector_type]["name"])
	if mode_button != null:
		mode_button.text = ["SOCKET", "AXLE", "CROSS"][attach_mode]

	var connector_selected: bool = _selected_kind() == "connector"
	if rotate_y_button != null:
		rotate_y_button.disabled = simulating or not connector_selected
	if rotate_x_button != null:
		rotate_x_button.disabled = simulating or not connector_selected
	if reset_rotation_button != null:
		reset_rotation_button.disabled = simulating or not connector_selected
	if delete_button != null:
		delete_button.disabled = simulating or not is_instance_valid(selected_piece)

	if mode_action_button != null:
		if attach_mode == 0:
			mode_action_button.text = "Socket: tap point"
			mode_action_button.disabled = true
		elif attach_mode == 1:
			mode_action_button.text = "Insert Axle"
			mode_action_button.disabled = simulating or not connector_selected
		else:
			mode_action_button.text = "Cross: tap rod"
			mode_action_button.disabled = true

	if redo_button != null:
		redo_button.disabled = simulating or state_index < 0 or state_index >= state_history.size() - 1
	if simulate_button != null:
		simulate_button.text = "BUILD" if simulating else "SIMULATE"


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_014, text]
