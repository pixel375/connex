extends "res://scripts/main_v012.gd"

const VERSION_013 = "0.1.3"
const PLATFORM_HALF = 250.0
const FUSE_DISTANCE = 0.30
const FUSE_ALIGN_DOT = 0.965
const CROSS_FUSE_DISTANCE = 0.18
const ROTATION_ALIGN_DOT = 0.985

var redo_button: Button
var tilt_button: Button
var state_history: Array = []
var state_index: int = -1
var restoring_state: bool = false
var pinch_center_last: Vector2 = Vector2.ZERO
var pinch_center_valid: bool = false
var mouse_pan_down: bool = false
var mouse_pan_last: Vector2 = Vector2.ZERO

func _ready() -> void:
	setup_active = false
	selected_rod_type = 2
	selected_connector_type = 6
	_build_world()
	_build_ui()
	_create_fresh_seed()
	_commit_state()
	_status("Tap a connector hub to rotate it. Tap a free socket to add a rod. Tilt gives the second rotation axis.")

func _build_world() -> void:
	super._build_world()
	camera.far = 1000.0
	camera_distance = 19.0
	camera_pitch = deg_to_rad(28.0)
	var ground: StaticBody3D = get_node_or_null("Ground") as StaticBody3D
	if ground != null:
		ground.collision_layer = 1
		ground.collision_mask = 2 | 4
		for child_value in ground.get_children():
			var child: Node = child_value as Node
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
				((child as MeshInstance3D).mesh as BoxMesh).size = Vector3(PLATFORM_HALF * 2.0, 0.18, PLATFORM_HALF * 2.0)
			elif child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
				((child as CollisionShape3D).shape as BoxShape3D).size = Vector3(PLATFORM_HALF * 2.0, 0.18, PLATFORM_HALF * 2.0)

func _build_grid() -> void:
	var grid: MeshInstance3D = MeshInstance3D.new()
	grid.name = "HugeGrid"
	var immediate: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(-250, 251):
		var strength: float = 0.34 if i % 10 == 0 else (0.22 if i % 5 == 0 else 0.11)
		immediate.surface_set_color(Color(0.36, 0.40, 0.48, strength))
		immediate.surface_add_vertex(Vector3(float(i), 0.012, -PLATFORM_HALF))
		immediate.surface_add_vertex(Vector3(float(i), 0.012, PLATFORM_HALF))
		immediate.surface_add_vertex(Vector3(-PLATFORM_HALF, 0.012, float(i)))
		immediate.surface_add_vertex(Vector3(PLATFORM_HALF, 0.012, float(i)))
	immediate.surface_end()
	grid.mesh = immediate
	add_child(grid)

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
	bottom_panel.offset_top = -210
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
	tilt_button = _make_ui_button("Tilt 45°", _tilt_selected_connector)
	row2.add_child(tilt_button)
	row2.add_child(_make_ui_button("Undo", _undo))
	redo_button = _make_ui_button("Redo", _redo)
	row2.add_child(redo_button)
	simulate_button = _make_ui_button("SIMULATE", _toggle_simulation)
	row2.add_child(simulate_button)

	var row3: HBoxContainer = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	rows.add_child(row3)
	row3.add_child(_make_ui_button("Restart", _restart_build))
	row3.add_child(_make_ui_button("Restore Pose", _reset_pose))
	row3.add_child(_make_ui_button("Center View", _center_view))
	var hint: Label = Label.new()
	hint.text = "1 finger: orbit   •   2 fingers: pan + zoom   •   tap connector hub: rotate"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 15)
	row3.add_child(hint)

	help_panel = PanelContainer.new()
	help_panel.visible = false
	help_panel.anchor_left = 0.10
	help_panel.anchor_right = 0.90
	help_panel.anchor_top = 0.10
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
	help.text = "CONNEX LAB v0.1.3\n\nThe first connector is already in the world and edits exactly like later connectors. Conn ◀/▶ swaps the selected connector. RESTART returns to this first editable point.\n\nSOCKET: tap a FREE outer socket to add one rod. Occupied sockets reject placement. Tap a free rod end to add or fuse a connector.\n\nROTATION: tap a connector HUB to rotate that connector 45° on its primary axis. TILT gives the second axis. Changes are accepted only if every existing rod still lines up with a real socket and an axle still lines up with the hub.\n\nCoincident compatible sockets, rod ends, and valid 90° rod-body crossings are auto-fused before simulation.\n\n1 finger orbits. 2 fingers pan and pinch-zoom. Undo/Redo store the whole build. SIMULATE restores physical contact between otherwise-unconnected pieces while connected joint pairs remain collision-excluded."
	margin.add_child(help)
	_update_ui()

func _make_connector(def_index: int, xform: Transform3D) -> RigidBody3D:
	var body: RigidBody3D = super._make_connector(def_index, xform)
	body.collision_layer = 4
	body.collision_mask = 1 | 2 | 4
	return body

func _make_rod(def_index: int, start: Vector3, finish: Vector3) -> RigidBody3D:
	var body: RigidBody3D = super._make_rod(def_index, start, finish)
	body.collision_layer = 2
	body.collision_mask = 1 | 2 | 4
	return body

func _create_fresh_seed() -> void:
	var seed: RigidBody3D = _make_connector(6, Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0)))
	seed.set_meta("seed", true)
	seed.set_meta("build_transform", seed.global_transform)
	selected_connector_type = 6
	selected_rod_type = 2
	last_placed_connector = seed
	_set_selected(seed)
	camera_target = Vector3(0, 4.0, 0)

func _center_view() -> void:
	camera_target = Vector3(0, 4.0, 0)
	camera_distance = 19.0
	camera_yaw = deg_to_rad(35.0)
	camera_pitch = deg_to_rad(28.0)
	_status("View centered")

func _select_slot_strict(connector: RigidBody3D, hit_pos: Vector3) -> int:
	var local: Vector3 = connector.global_transform.affine_inverse() * hit_pos
	local.y = 0.0
	if local.length() < 0.70:
		return -2
	var def_index: int = int(connector.get_meta("connector_type"))
	var slots: Array = connector_defs[def_index]["slots"]
	var direction: Vector3 = local.normalized()
	var best_slot: int = -1
	var best_dot: float = 0.72
	for slot_value in slots:
		var slot: int = int(slot_value)
		var score: float = direction.dot(_slot_dir(slot))
		if score > best_dot:
			best_dot = score
			best_slot = slot
	if best_slot < 0:
		return -1
	var occupied: Dictionary = connector.get_meta("occupied")
	if occupied.has(best_slot):
		return -3
	return best_slot

func _connector_socket_world(connector: RigidBody3D, slot: int) -> Dictionary:
	var direction: Vector3 = (connector.global_transform.basis * _slot_dir(slot)).normalized()
	return {"dir": direction, "point": connector.global_position + direction * CONNECTOR_D}

func _find_reachable_socket(start: Vector3, direction: Vector3, rod_len: float, source: RigidBody3D) -> Dictionary:
	var expected: Vector3 = start + direction * rod_len
	var best: Dictionary = {}
	var best_dist: float = FUSE_DISTANCE
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body) or body == source or str(body.get_meta("kind", "")) != "connector":
			continue
		var def_index: int = int(body.get_meta("connector_type"))
		var occupied: Dictionary = body.get_meta("occupied")
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			if occupied.has(slot):
				continue
			var socket: Dictionary = _connector_socket_world(body, slot)
			var socket_dir: Vector3 = socket["dir"]
			if socket_dir.dot(-direction) < FUSE_ALIGN_DOT:
				continue
			var socket_point: Vector3 = socket["point"]
			var dist: float = socket_point.distance_to(expected)
			if dist < best_dist:
				best_dist = dist
				best = {"connector": body, "slot": slot, "point": socket_point}
	return best

func _find_socket_for_rod_end(rod: RigidBody3D, sign_value: int) -> Dictionary:
	var point: Vector3 = _rod_end_world(rod, sign_value)
	var axis: Vector3 = rod.get_meta("axis")
	var outward: Vector3 = axis.normalized() * float(sign_value)
	var best: Dictionary = {}
	var best_dist: float = FUSE_DISTANCE
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body) or str(body.get_meta("kind", "")) != "connector":
			continue
		var def_index: int = int(body.get_meta("connector_type"))
		var occupied: Dictionary = body.get_meta("occupied")
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			if occupied.has(slot):
				continue
			var socket: Dictionary = _connector_socket_world(body, slot)
			var socket_dir: Vector3 = socket["dir"]
			if socket_dir.dot(-outward) < FUSE_ALIGN_DOT:
				continue
			var socket_point: Vector3 = socket["point"]
			var dist: float = socket_point.distance_to(point)
			if dist < best_dist:
				best_dist = dist
				best = {"connector": body, "slot": slot, "point": socket_point}
	return best

func _joint_nodes(joint: Joint3D) -> Array:
	var node_a: Node = joint.get_node_or_null(joint.node_a)
	var node_b: Node = joint.get_node_or_null(joint.node_b)
	if node_a == null:
		node_a = get_node_or_null(joint.node_a)
	if node_b == null:
		node_b = get_node_or_null(joint.node_b)
	return [node_a, node_b]

func _fixed_pair_exists(a: Node, b: Node) -> bool:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if (nodes[0] == a and nodes[1] == b) or (nodes[0] == b and nodes[1] == a):
			return true
	return false

func _fuse_rod_end(rod: RigidBody3D, sign_value: int, target_info: Dictionary) -> bool:
	if target_info.is_empty():
		return false
	var rod_occupied: Dictionary = rod.get_meta("end_occupied")
	if rod_occupied.has(sign_value):
		return false
	var connector: RigidBody3D = target_info["connector"] as RigidBody3D
	var slot: int = int(target_info["slot"])
	var connector_occupied: Dictionary = connector.get_meta("occupied")
	if connector_occupied.has(slot) or _fixed_pair_exists(rod, connector):
		return false
	var anchor: Vector3 = _rod_end_world(rod, sign_value)
	_make_fixed_joint(rod, connector, anchor)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	return true

func _auto_fuse_rod_end(rod: RigidBody3D, sign_value: int) -> bool:
	var occupied: Dictionary = rod.get_meta("end_occupied")
	if occupied.has(sign_value):
		return false
	return _fuse_rod_end(rod, sign_value, _find_socket_for_rod_end(rod, sign_value))

func _auto_fuse_connector(connector: RigidBody3D) -> bool:
	var changed: bool = false
	var def_index: int = int(connector.get_meta("connector_type"))
	var slot_values: Array = connector_defs[def_index]["slots"]
	for slot_value in slot_values:
		var slot: int = int(slot_value)
		var occupied: Dictionary = connector.get_meta("occupied")
		if occupied.has(slot):
			continue
		var socket: Dictionary = _connector_socket_world(connector, slot)
		var mouth: Vector3 = socket["point"]
		var slot_dir: Vector3 = socket["dir"]
		var endpoint_done: bool = false
		for body_value in bodies:
			var rod: RigidBody3D = body_value as RigidBody3D
			if not is_instance_valid(rod) or str(rod.get_meta("kind", "")) != "rod" or _fixed_pair_exists(rod, connector):
				continue
			var rod_occ: Dictionary = rod.get_meta("end_occupied")
			var rod_axis: Vector3 = rod.get_meta("axis")
			rod_axis = rod_axis.normalized()
			for sign_value in [-1, 1]:
				if rod_occ.has(sign_value):
					continue
				var end_point: Vector3 = _rod_end_world(rod, int(sign_value))
				var outward: Vector3 = rod_axis * float(sign_value)
				if mouth.distance_to(end_point) <= FUSE_DISTANCE and slot_dir.dot(-outward) >= FUSE_ALIGN_DOT:
					_make_fixed_joint(rod, connector, end_point)
					_set_rod_end_occupied(rod, int(sign_value), true)
					_set_connector_occupied(connector, slot, true)
					changed = true
					endpoint_done = true
					break
			if endpoint_done:
				break
		if endpoint_done:
			continue
		for body_value in bodies:
			var cross_rod: RigidBody3D = body_value as RigidBody3D
			if not is_instance_valid(cross_rod) or str(cross_rod.get_meta("kind", "")) != "rod" or _fixed_pair_exists(cross_rod, connector):
				continue
			var cross_axis: Vector3 = cross_rod.get_meta("axis")
			cross_axis = cross_axis.normalized()
			if absf(cross_axis.dot(slot_dir)) > 0.22:
				continue
			var half_len: float = maxf(0.0, float(cross_rod.get_meta("visual_length")) * 0.5 - 0.50)
			var along: float = clampf((mouth - cross_rod.global_position).dot(cross_axis), -half_len, half_len)
			var closest: Vector3 = cross_rod.global_position + cross_axis * along
			if closest.distance_to(mouth) <= CROSS_FUSE_DISTANCE:
				_make_fixed_joint(cross_rod, connector, closest)
				_set_connector_occupied(connector, slot, true)
				changed = true
				break
	return changed

func _auto_fuse_all() -> bool:
	var any_changed: bool = false
	for _pass in range(3):
		var changed: bool = false
		for body_value in bodies:
			var body: RigidBody3D = body_value as RigidBody3D
			if is_instance_valid(body) and str(body.get_meta("kind", "")) == "rod":
				if _auto_fuse_rod_end(body, -1):
					changed = true
				if _auto_fuse_rod_end(body, 1):
					changed = true
		for body_value in bodies:
			var connector: RigidBody3D = body_value as RigidBody3D
			if is_instance_valid(connector) and str(connector.get_meta("kind", "")) == "connector":
				if _auto_fuse_connector(connector):
					changed = true
		if changed:
			any_changed = true
		else:
			break
	return any_changed

func _extend_socket(connector: RigidBody3D, slot: int) -> void:
	if simulating or slot < 0:
		return
	var occupied: Dictionary = connector.get_meta("occupied")
	if occupied.has(slot):
		_status("That connector socket already has a rod")
		return
	var rod_len: float = float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var source_socket: Dictionary = _connector_socket_world(connector, slot)
	var start: Vector3 = source_socket["point"]
	var direction: Vector3 = source_socket["dir"]
	var target: Dictionary = _find_reachable_socket(start, direction, rod_len, connector)
	var finish: Vector3 = start + direction * rod_len
	if not target.is_empty():
		finish = target["point"]
	var rod: RigidBody3D = _make_rod(selected_rod_type, start, finish)
	_make_fixed_joint(connector, rod, start)
	_set_connector_occupied(connector, slot, true)
	_set_rod_end_occupied(rod, -1, true)
	if not target.is_empty():
		var target_connector: RigidBody3D = target["connector"] as RigidBody3D
		var target_slot: int = int(target["slot"])
		_make_fixed_joint(rod, target_connector, finish)
		_set_rod_end_occupied(rod, 1, true)
		_set_connector_occupied(target_connector, target_slot, true)
		_set_selected(target_connector)
		_status("Rod auto-fused into the matching free connector socket")
	else:
		_set_selected(rod)
		_status("Rod added. Tap its free end to add or fuse a connector.")
	_commit_state()

func _attach_connector_to_rod_end(rod: RigidBody3D, sign_value: int) -> void:
	var end_occupied: Dictionary = rod.get_meta("end_occupied")
	if end_occupied.has(sign_value):
		_status("That rod end is already connected")
		return
	var existing: Dictionary = _find_socket_for_rod_end(rod, sign_value)
	if not existing.is_empty() and _fuse_rod_end(rod, sign_value, existing):
		var target: RigidBody3D = existing["connector"] as RigidBody3D
		_auto_fuse_connector(target)
		_set_selected(target)
		_status("Rod fused to the existing matching connector")
		_commit_state()
		return
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var outward: Vector3 = axis * float(sign_value)
	var end_pos: Vector3 = _rod_end_world(rod, sign_value)
	var slot: int = int(connector_defs[selected_connector_type]["slots"][0])
	var basis: Basis = _connector_basis(slot, -outward, 0)
	var connector: RigidBody3D = _make_connector(selected_connector_type, Transform3D(basis, end_pos + outward * CONNECTOR_D))
	_make_fixed_joint(rod, connector, end_pos)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	last_placed_connector = connector
	_auto_fuse_connector(connector)
	_set_selected(connector)
	_status("Connector placed and any coincident valid connections were fused")
	_commit_state()

func _insert_axle(connector: RigidBody3D) -> void:
	if bool(connector.get_meta("axle_occupied", false)):
		_status("That connector hub already contains an axle")
		return
	var rod_len: float = float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var axis: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
	var rod: RigidBody3D = _make_rod(selected_rod_type, connector.global_position - axis * rod_len * 0.5, connector.global_position + axis * rod_len * 0.5)
	_make_axle_joint(connector, rod)
	connector.set_meta("axle_occupied", true)
	_auto_fuse_rod_end(rod, -1)
	_auto_fuse_rod_end(rod, 1)
	_set_selected(rod)
	_status("Axle inserted. Unconnected cross pieces physically collide with it in simulation.")
	_commit_state()

func _cross_snap(rod: RigidBody3D, hit_pos: Vector3) -> void:
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var slot: int = int(connector_defs[selected_connector_type]["slots"][0])
	var local_slot: Vector3 = _slot_dir(slot)
	var base: Basis = Basis(Quaternion(Vector3.UP, axis))
	var radial_now: Vector3 = (base * local_slot).normalized()
	var preferred: Vector3 = camera.global_transform.basis.x
	preferred -= axis * preferred.dot(axis)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.UP)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.RIGHT)
	preferred = preferred.normalized()
	var angle: float = radial_now.signed_angle_to(preferred, axis)
	var basis: Basis = Basis(axis, angle) * base
	var radial: Vector3 = (basis * local_slot).normalized()
	var half_len: float = float(rod.get_meta("visual_length")) * 0.5 - 0.42
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var snap_point: Vector3 = rod.global_position + axis * along
	var connector: RigidBody3D = _make_connector(selected_connector_type, Transform3D(basis, snap_point - radial * CONNECTOR_D))
	_set_connector_occupied(connector, slot, true)
	_make_fixed_joint(rod, connector, snap_point)
	last_placed_connector = connector
	_auto_fuse_connector(connector)
	_set_selected(connector)
	_status("Cross connector snapped and overlapping valid geometry fused")
	_commit_state()

func _connector_fixed_attachments(connector: RigidBody3D) -> Array:
	var result: Array = []
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] != connector and nodes[1] != connector:
			continue
		var delta: Vector3 = joint.global_position - connector.global_position
		if delta.length_squared() >= 0.15:
			result.append({"joint": joint, "dir": delta.normalized()})
	return result

func _map_attachments_to_slots(basis: Basis, def_index: int, attachments: Array) -> Dictionary:
	var used: Dictionary = {}
	for attachment_value in attachments:
		var attachment: Dictionary = attachment_value as Dictionary
		var target_dir: Vector3 = attachment["dir"]
		var best_slot: int = -1
		var best_dot: float = ROTATION_ALIGN_DOT
		for slot_value in connector_defs[def_index]["slots"]:
			var slot: int = int(slot_value)
			if used.has(slot):
				continue
			var world_dir: Vector3 = (basis * _slot_dir(slot)).normalized()
			var score: float = world_dir.dot(target_dir)
			if score > best_dot:
				best_dot = score
				best_slot = slot
		if best_slot < 0:
			return {"valid": false}
		used[best_slot] = true
	return {"valid": true, "occupied": used}

func _axle_basis_valid(connector: RigidBody3D, basis: Basis) -> bool:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] != connector and nodes[1] != connector:
			continue
		var other: RigidBody3D = (nodes[1] if nodes[0] == connector else nodes[0]) as RigidBody3D
		if not is_instance_valid(other):
			continue
		var rod_axis: Vector3 = (other.global_transform.basis * Vector3.UP).normalized()
		var hub_axis: Vector3 = (basis * Vector3.UP).normalized()
		if absf(rod_axis.dot(hub_axis)) < ROTATION_ALIGN_DOT:
			return false
	return true

func _update_axle_frames(connector: RigidBody3D) -> void:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] == connector or nodes[1] == connector:
			joint.global_transform = connector.global_transform

func _try_connector_basis(connector: RigidBody3D, candidate: Basis, label: String) -> bool:
	var def_index: int = int(connector.get_meta("connector_type"))
	var attachments: Array = _connector_fixed_attachments(connector)
	var mapping: Dictionary = _map_attachments_to_slots(candidate, def_index, attachments)
	if not bool(mapping.get("valid", false)) or not _axle_basis_valid(connector, candidate):
		_status("%s blocked: it would disconnect an existing rod or misalign an axle" % label)
		return false
	connector.global_transform.basis = candidate.orthonormalized()
	connector.set_meta("occupied", mapping.get("occupied", {}))
	connector.set_meta("build_transform", connector.global_transform)
	_update_axle_frames(connector)
	_rebind_all_joints()
	_auto_fuse_connector(connector)
	_commit_state()
	_status("%s accepted; all connected rods remain on valid sockets" % label)
	return true

func _spin_connector(connector: RigidBody3D) -> void:
	if simulating:
		return
	var attachments: Array = _connector_fixed_attachments(connector)
	var axis: Vector3 = (connector.global_transform.basis * Vector3.UP).normalized()
	if attachments.size() == 1:
		var one_attachment: Dictionary = attachments[0]
		axis = one_attachment["dir"]
	var candidate: Basis = Basis(axis.normalized(), deg_to_rad(45.0)) * connector.global_transform.basis
	_try_connector_basis(connector, candidate, "Rotate 45°")

func _tilt_selected_connector() -> void:
	if simulating or _selected_kind() != "connector":
		_status("Select a connector first")
		return
	var connector: RigidBody3D = selected_piece
	var axis: Vector3 = (connector.global_transform.basis * Vector3.RIGHT).normalized()
	var candidate: Basis = Basis(axis, deg_to_rad(45.0)) * connector.global_transform.basis
	_try_connector_basis(connector, candidate, "Tilt 45°")

func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	if _selected_kind() != "connector":
		selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
		_update_ui()
		_status("Connector choice: %s" % connector_defs[selected_connector_type]["name"])
		return
	var connector: RigidBody3D = selected_piece
	var current: int = int(connector.get_meta("connector_type"))
	var attachments: Array = _connector_fixed_attachments(connector)
	var candidate: int = current
	for _i in range(connector_defs.size() - 1):
		candidate = wrapi(candidate + delta, 0, connector_defs.size())
		var mapping: Dictionary = _map_attachments_to_slots(connector.global_transform.basis, candidate, attachments)
		if bool(mapping.get("valid", false)):
			_rebuild_connector(connector, candidate)
			connector.set_meta("occupied", mapping.get("occupied", {}))
			connector.set_meta("build_transform", connector.global_transform)
			selected_connector_type = candidate
			_rebind_all_joints()
			_auto_fuse_connector(connector)
			_update_ui()
			_commit_state()
			_status("Connector swapped to %s without breaking existing rods" % connector_defs[candidate]["name"])
			return
	_status("No other connector type fits all currently connected rod directions")

func _change_rod_type(delta: int) -> void:
	var rod: RigidBody3D = selected_piece if _selected_kind() == "rod" else null
	var before_type: int = int(rod.get_meta("rod_type")) if is_instance_valid(rod) else -1
	var before_len: float = float(rod.get_meta("visual_length")) if is_instance_valid(rod) else -1.0
	super._change_rod_type(delta)
	if is_instance_valid(rod):
		var changed: bool = before_type != int(rod.get_meta("rod_type")) or not is_equal_approx(before_len, float(rod.get_meta("visual_length")))
		if changed:
			_auto_fuse_rod_end(rod, -1)
			_auto_fuse_rod_end(rod, 1)
			_commit_state()

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
	if attach_mode == 0:
		if kind == "connector":
			_set_selected(body)
			var slot: int = _select_slot_strict(body, hit["position"])
			if slot >= 0:
				_extend_socket(body, slot)
			elif slot == -3:
				_status("That socket is occupied — no second rod can be placed there")
			else:
				_spin_connector(body)
		elif kind == "rod":
			var end_sign: int = _rod_end_hit(body, hit["position"])
			if end_sign != 0:
				_attach_connector_to_rod_end(body, end_sign)
			else:
				_set_selected(body)
				_status("Rod selected")
	elif attach_mode == 1:
		if kind == "connector":
			_set_selected(body)
			_insert_axle(body)
		else:
			_set_selected(body)
	elif attach_mode == 2:
		if kind == "rod":
			_cross_snap(body, hit["position"])
		else:
			_set_selected(body)

func _pinch_center() -> Vector2:
	var keys: Array = touches.keys()
	if keys.size() < 2:
		return Vector2.ZERO
	var first: Vector2 = touches[keys[0]]
	var second: Vector2 = touches[keys[1]]
	return (first + second) * 0.5

func _pan_camera(screen_delta: Vector2) -> void:
	if camera == null:
		return
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.001:
		right = right.normalized()
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()
	var move_scale: float = camera_distance * 0.0027
	camera_target += (-right * screen_delta.x + forward * screen_delta.y) * move_scale
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.y = 4.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		touch_mouse_guard_until = Time.get_ticks_msec() + 350
		if touch.pressed:
			touches[touch.index] = touch.position
			touch_start[touch.index] = touch.position
			touch_moved[touch.index] = false
			if touches.size() >= 2:
				pinch_last = _pinch_distance()
				pinch_center_last = _pinch_center()
				pinch_center_valid = true
		else:
			var moved: bool = bool(touch_moved.get(touch.index, false))
			var start: Vector2 = touch_start.get(touch.index, touch.position)
			touches.erase(touch.index)
			touch_start.erase(touch.index)
			touch_moved.erase(touch.index)
			if touches.size() < 2:
				pinch_last = -1.0
				pinch_center_valid = false
			if not moved and start.distance_to(touch.position) < 18.0:
				_handle_tap(touch.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		touch_mouse_guard_until = Time.get_ticks_msec() + 350
		touches[drag.index] = drag.position
		if drag.relative.length() > 2.0:
			touch_moved[drag.index] = true
		if touches.size() >= 2:
			var distance: float = _pinch_distance()
			if pinch_last > 0.0:
				camera_distance = clampf(camera_distance - (distance - pinch_last) * 0.030, 5.0, 220.0)
			pinch_last = distance
			var center: Vector2 = _pinch_center()
			if pinch_center_valid:
				_pan_camera(center - pinch_center_last)
			pinch_center_last = center
			pinch_center_valid = true
		else:
			camera_yaw -= drag.relative.x * 0.006
			camera_pitch = clampf(camera_pitch - drag.relative.y * 0.005, deg_to_rad(8.0), deg_to_rad(82.0))
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if Time.get_ticks_msec() < touch_mouse_guard_until:
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				mouse_down = true
				mouse_start = mouse_button.position
				mouse_moved = false
			else:
				if mouse_down and not mouse_moved and mouse_start.distance_to(mouse_button.position) < 10.0:
					_handle_tap(mouse_button.position)
				mouse_down = false
		elif mouse_button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			mouse_pan_down = mouse_button.pressed
			mouse_pan_last = mouse_button.position
		elif mouse_button.pressed and mouse_button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera_distance = clampf(camera_distance + (-2.0 if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0), 5.0, 220.0)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if Time.get_ticks_msec() < touch_mouse_guard_until:
			return
		if mouse_pan_down:
			_pan_camera(motion.position - mouse_pan_last)
			mouse_pan_last = motion.position
		elif mouse_down and motion.relative.length() > 1.0:
			mouse_moved = true
			camera_yaw -= motion.relative.x * 0.006
			camera_pitch = clampf(camera_pitch - motion.relative.y * 0.005, deg_to_rad(8.0), deg_to_rad(82.0))

func _update_camera() -> void:
	if camera == null:
		return
	camera_pitch = clampf(camera_pitch, deg_to_rad(8.0), deg_to_rad(82.0))
	var cp: float = cos(camera_pitch)
	var offset: Vector3 = Vector3(cos(camera_yaw) * cp, sin(camera_pitch), sin(camera_yaw) * cp) * camera_distance
	camera.global_position = camera_target + offset
	camera.look_at(camera_target, Vector3.UP)

func _capture_state() -> Dictionary:
	var body_states: Array = []
	var index_by_id: Dictionary = {}
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		var body_index: int = body_states.size()
		index_by_id[body.get_instance_id()] = body_index
		var kind: String = str(body.get_meta("kind", ""))
		var state: Dictionary = {"kind": kind, "transform": body.get_meta("build_transform", body.global_transform), "seed": bool(body.get_meta("seed", false))}
		if kind == "connector":
			var connector_occ: Dictionary = body.get_meta("occupied")
			state["type"] = int(body.get_meta("connector_type"))
			state["occupied"] = connector_occ.duplicate(true)
			state["axle_occupied"] = bool(body.get_meta("axle_occupied", false))
		else:
			var end_occ: Dictionary = body.get_meta("end_occupied")
			state["type"] = int(body.get_meta("rod_type"))
			state["length"] = float(body.get_meta("visual_length"))
			state["end_occupied"] = end_occ.duplicate(true)
		body_states.append(state)
	var joint_states: Array = []
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		var nodes: Array = _joint_nodes(joint)
		var node_a: Node = nodes[0] as Node
		var node_b: Node = nodes[1] as Node
		if not is_instance_valid(node_a) or not is_instance_valid(node_b):
			continue
		if not index_by_id.has(node_a.get_instance_id()) or not index_by_id.has(node_b.get_instance_id()):
			continue
		joint_states.append({"type": "axle" if str(joint.name).begins_with("AxleJoint") else "fixed", "a": int(index_by_id[node_a.get_instance_id()]), "b": int(index_by_id[node_b.get_instance_id()]), "transform": joint.global_transform})
	var selected_index: int = -1
	if is_instance_valid(selected_piece) and index_by_id.has(selected_piece.get_instance_id()):
		selected_index = int(index_by_id[selected_piece.get_instance_id()])
	return {"bodies": body_states, "joints": joint_states, "selected": selected_index, "rod_type": selected_rod_type, "connector_type": selected_connector_type}

func _clear_build_nodes() -> void:
	for joint_value in joints.duplicate():
		var joint: Joint3D = joint_value as Joint3D
		if is_instance_valid(joint):
			joint.queue_free()
	for body_value in bodies.duplicate():
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			body.collision_layer = 0
			body.collision_mask = 0
			body.queue_free()
	joints.clear()
	bodies.clear()
	history.clear()
	selected_piece = null
	last_placed_connector = null
	piece_counter = 0

func _restore_state(snapshot: Dictionary) -> void:
	restoring_state = true
	simulating = false
	_clear_build_nodes()
	var restored: Array = []
	var saved_bodies: Array = snapshot["bodies"]
	for state_value in saved_bodies:
		var state: Dictionary = state_value as Dictionary
		var transform: Transform3D = state["transform"]
		var body: RigidBody3D
		if str(state["kind"]) == "connector":
			body = _make_connector(int(state["type"]), transform)
			var restored_occ: Dictionary = state["occupied"]
			body.set_meta("occupied", restored_occ.duplicate(true))
			body.set_meta("axle_occupied", bool(state["axle_occupied"]))
		else:
			var length: float = float(state["length"])
			var axis: Vector3 = (transform.basis * Vector3.UP).normalized()
			body = _make_rod(int(state["type"]), transform.origin - axis * length * 0.5, transform.origin + axis * length * 0.5)
			body.global_transform = transform
			body.set_meta("axis", axis)
			var restored_ends: Dictionary = state["end_occupied"]
			body.set_meta("end_occupied", restored_ends.duplicate(true))
		body.set_meta("seed", bool(state["seed"]))
		body.set_meta("build_transform", transform)
		restored.append(body)
	var saved_joints: Array = snapshot["joints"]
	for joint_value in saved_joints:
		var joint_state: Dictionary = joint_value as Dictionary
		var body_a: RigidBody3D = restored[int(joint_state["a"])] as RigidBody3D
		var body_b: RigidBody3D = restored[int(joint_state["b"])] as RigidBody3D
		var joint: Joint3D
		if str(joint_state["type"]) == "axle":
			var connector: RigidBody3D = body_a if str(body_a.get_meta("kind", "")) == "connector" else body_b
			var rod: RigidBody3D = body_b if connector == body_a else body_a
			joint = _make_axle_joint(connector, rod)
		else:
			var joint_transform: Transform3D = joint_state["transform"]
			joint = _make_fixed_joint(body_a, body_b, joint_transform.origin)
		joint.global_transform = joint_state["transform"]
	selected_rod_type = int(snapshot.get("rod_type", 2))
	selected_connector_type = int(snapshot.get("connector_type", 6))
	var selected_index: int = int(snapshot.get("selected", -1))
	if selected_index >= 0 and selected_index < restored.size():
		_set_selected(restored[selected_index] as RigidBody3D)
	else:
		selected_piece = null
	_refresh_last_connector()
	_rebind_all_joints()
	restoring_state = false
	_update_ui()

func _commit_state() -> void:
	if restoring_state or simulating:
		return
	history.clear()
	if state_index < state_history.size() - 1:
		state_history = state_history.slice(0, state_index + 1)
	state_history.append(_capture_state())
	if state_history.size() > 80:
		state_history.pop_front()
	state_index = state_history.size() - 1
	_update_ui()

func _undo() -> void:
	if simulating or state_index <= 0:
		return
	state_index -= 1
	_restore_state(state_history[state_index])
	_status("Undo")

func _redo() -> void:
	if simulating or state_index < 0 or state_index >= state_history.size() - 1:
		return
	state_index += 1
	_restore_state(state_history[state_index])
	_status("Redo")

func _restart_build() -> void:
	simulating = false
	_clear_build_nodes()
	state_history.clear()
	state_index = -1
	selected_connector_type = 6
	selected_rod_type = 2
	_create_fresh_seed()
	_commit_state()
	_center_view()
	_status("Restarted at the first editable connector. Use Conn ◀/▶ to change it or tap its hub to rotate.")

func _toggle_simulation() -> void:
	if simulating:
		_reset_pose()
		return
	if _auto_fuse_all():
		_commit_state()
	_rebind_all_joints()
	super._toggle_simulation()

func _release_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not simulating:
		return
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		if bool(body.get_meta("seed", false)):
			body.freeze = true
		else:
			body.freeze = false
			body.sleeping = false
	_update_ui()
	_status("Physics running — unjointed pieces collide; valid overlaps were fused first")

func _update_ui() -> void:
	if rod_label != null:
		rod_label.text = str(rod_defs[selected_rod_type]["name"])
	if connector_label != null:
		connector_label.text = str(connector_defs[selected_connector_type]["name"])
	if mode_button != null:
		mode_button.text = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	if tilt_button != null:
		tilt_button.disabled = simulating or _selected_kind() != "connector"
	if redo_button != null:
		redo_button.disabled = simulating or state_index < 0 or state_index >= state_history.size() - 1
	if simulate_button != null:
		simulate_button.text = "BUILD" if simulating else "SIMULATE"

func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_013, text]
