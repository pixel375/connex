extends "res://scripts/main_v012.gd"

const VERSION_013 := "0.1.3"
const PLATFORM_HALF := 250.0
const FUSE_DISTANCE := 0.30
const FUSE_ALIGN_DOT := 0.965
const CROSS_FUSE_DISTANCE := 0.16
const ROTATION_ALIGN_DOT := 0.985

var redo_button: Button
var tilt_button: Button
var state_history: Array = []
var state_index := -1
var restoring_state := false
var pinch_center_last := Vector2.ZERO
var pinch_center_valid := false
var mouse_pan_down := false
var mouse_pan_last := Vector2.ZERO

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
	var ground := get_node_or_null("Ground") as StaticBody3D
	if ground != null:
		ground.collision_layer = 1
		ground.collision_mask = 2 | 4
		for child in ground.get_children():
			if child is MeshInstance3D and child.mesh is BoxMesh:
				(child.mesh as BoxMesh).size = Vector3(PLATFORM_HALF * 2.0, 0.18, PLATFORM_HALF * 2.0)
			elif child is CollisionShape3D and child.shape is BoxShape3D:
				(child.shape as BoxShape3D).size = Vector3(PLATFORM_HALF * 2.0, 0.18, PLATFORM_HALF * 2.0)

func _build_grid() -> void:
	var grid := MeshInstance3D.new()
	grid.name = "HugeGrid"
	var im := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(-250, 251):
		var strength := 0.34 if i % 10 == 0 else (0.22 if i % 5 == 0 else 0.11)
		im.surface_set_color(Color(0.36, 0.40, 0.48, strength))
		im.surface_add_vertex(Vector3(float(i), 0.012, -PLATFORM_HALF))
		im.surface_add_vertex(Vector3(float(i), 0.012, PLATFORM_HALF))
		im.surface_add_vertex(Vector3(-PLATFORM_HALF, 0.012, float(i)))
		im.surface_add_vertex(Vector3(PLATFORM_HALF, 0.012, float(i)))
	im.surface_end()
	grid.mesh = im
	add_child(grid)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 10
	top.offset_bottom = 58
	layer.add_child(top)
	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 19)
	top_row.add_child(status_label)
	var help_button := _make_ui_button("?", _toggle_help)
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
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	bottom_panel.add_child(rows)

	var row1 := HBoxContainer.new()
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

	var row2 := HBoxContainer.new()
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

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	rows.add_child(row3)
	row3.add_child(_make_ui_button("Restart", _restart_build))
	row3.add_child(_make_ui_button("Restore Pose", _reset_pose))
	row3.add_child(_make_ui_button("Center View", _center_view))
	var hint := Label.new()
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
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	help_panel.add_child(margin)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 17)
	help.text = "CONNEX LAB v0.1.3\n\nThe first connector is already in the world. Select it and use Conn ◀/▶ to swap it exactly like any later connector. RESTART returns to that first editable point.\n\nSOCKET: tap a FREE socket to add one rod. Occupied sockets reject placement. Tap a free rod end to add or fuse a connector.\n\nROTATION: tap a connector hub to rotate 45° on its primary valid axis. TILT gives a second axis. A rotation is accepted only if every already-connected rod still lines up with a real socket and any axle still lines up with the hub.\n\nGeometry that lands on another valid free socket/end is auto-fused. Overlapping valid cross-snaps are also joined before simulation.\n\n1 finger orbits. 2 fingers pan and pinch-zoom across the large platform. Undo/Redo restore full build states. SIMULATE enables physical contact between otherwise-unconnected rods/connectors while jointed pairs remain collision-excluded."
	margin.add_child(help)
	_update_ui()

func _make_connector(def_index: int, xform: Transform3D) -> RigidBody3D:
	var body := super._make_connector(def_index, xform)
	body.collision_layer = 4
	body.collision_mask = 1 | 2 | 4
	body.set_meta("spin_step", 0)
	body.set_meta("tilt_step", 0)
	return body

func _make_rod(def_index: int, start: Vector3, finish: Vector3) -> RigidBody3D:
	var body := super._make_rod(def_index, start, finish)
	body.collision_layer = 2
	body.collision_mask = 1 | 2 | 4
	return body

func _create_fresh_seed() -> void:
	var seed := _make_connector(6, Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0)))
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
	var local := connector.global_transform.affine_inverse() * hit_pos
	local.y = 0.0
	if local.length() < 0.70:
		return -2
	var def_index := int(connector.get_meta("connector_type"))
	var slots: Array = connector_defs[def_index]["slots"]
	var direction := local.normalized()
	var best_slot := -1
	var best_dot := 0.72
	for slot_value in slots:
		var slot := int(slot_value)
		var score := direction.dot(_slot_dir(slot))
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
	var direction := (connector.global_transform.basis * _slot_dir(slot)).normalized()
	return {"dir": direction, "point": connector.global_position + direction * CONNECTOR_D}

func _find_reachable_socket(start: Vector3, direction: Vector3, rod_len: float, source: RigidBody3D) -> Dictionary:
	var expected := start + direction * rod_len
	var best: Dictionary = {}
	var best_dist := FUSE_DISTANCE
	for body in bodies:
		if not is_instance_valid(body) or body == source or str(body.get_meta("kind", "")) != "connector":
			continue
		var connector := body as RigidBody3D
		var def_index := int(connector.get_meta("connector_type"))
		var occupied: Dictionary = connector.get_meta("occupied")
		for slot_value in connector_defs[def_index]["slots"]:
			var slot := int(slot_value)
			if occupied.has(slot):
				continue
			var socket := _connector_socket_world(connector, slot)
			if (socket["dir"] as Vector3).dot(-direction) < FUSE_ALIGN_DOT:
				continue
			var dist := (socket["point"] as Vector3).distance_to(expected)
			if dist < best_dist:
				best_dist = dist
				best = {"connector": connector, "slot": slot, "point": socket["point"]}
	return best

func _find_socket_for_rod_end(rod: RigidBody3D, sign_value: int) -> Dictionary:
	var point := _rod_end_world(rod, sign_value)
	var axis: Vector3 = rod.get_meta("axis")
	var outward := axis.normalized() * float(sign_value)
	var best: Dictionary = {}
	var best_dist := FUSE_DISTANCE
	for body in bodies:
		if not is_instance_valid(body) or str(body.get_meta("kind", "")) != "connector":
			continue
		var connector := body as RigidBody3D
		var def_index := int(connector.get_meta("connector_type"))
		var occupied: Dictionary = connector.get_meta("occupied")
		for slot_value in connector_defs[def_index]["slots"]:
			var slot := int(slot_value)
			if occupied.has(slot):
				continue
			var socket := _connector_socket_world(connector, slot)
			if (socket["dir"] as Vector3).dot(-outward) < FUSE_ALIGN_DOT:
				continue
			var dist := (socket["point"] as Vector3).distance_to(point)
			if dist < best_dist:
				best_dist = dist
				best = {"connector": connector, "slot": slot, "point": socket["point"]}
	return best

func _joint_nodes(joint: Joint3D) -> Array:
	var a := joint.get_node_or_null(joint.node_a)
	var b := joint.get_node_or_null(joint.node_b)
	if a == null:
		a = get_node_or_null(joint.node_a)
	if b == null:
		b = get_node_or_null(joint.node_b)
	return [a, b]

func _fixed_pair_exists(a: Node, b: Node) -> bool:
	for joint in joints:
		if not is_instance_valid(joint) or not (joint is Joint3D) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes := _joint_nodes(joint)
		if (nodes[0] == a and nodes[1] == b) or (nodes[0] == b and nodes[1] == a):
			return true
	return false

func _fuse_rod_end(rod: RigidBody3D, sign_value: int, target_info: Dictionary) -> bool:
	if target_info.is_empty():
		return false
	var end_occupied: Dictionary = rod.get_meta("end_occupied")
	if end_occupied.has(sign_value):
		return false
	var connector := target_info["connector"] as RigidBody3D
	var slot := int(target_info["slot"])
	var occupied: Dictionary = connector.get_meta("occupied")
	if occupied.has(slot):
		return false
	if _fixed_pair_exists(rod, connector):
		return false
	var anchor := _rod_end_world(rod, sign_value)
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
	var changed := false
	var def_index := int(connector.get_meta("connector_type"))
	var slot_values: Array = connector_defs[def_index]["slots"]
	for slot_value in slot_values:
		var slot := int(slot_value)
		var occupied: Dictionary = connector.get_meta("occupied")
		if occupied.has(slot):
			continue
		var socket := _connector_socket_world(connector, slot)
		var mouth := socket["point"] as Vector3
		var slot_dir := socket["dir"] as Vector3
		var endpoint_done := false
		for body in bodies:
			if not is_instance_valid(body) or str(body.get_meta("kind", "")) != "rod":
				continue
			var rod := body as RigidBody3D
			if _fixed_pair_exists(rod, connector):
				continue
			var rod_occ: Dictionary = rod.get_meta("end_occupied")
			var rod_axis: Vector3 = rod.get_meta("axis")
			rod_axis = rod_axis.normalized()
			for sign_value in [-1, 1]:
				if rod_occ.has(sign_value):
					continue
				var end_point := _rod_end_world(rod, sign_value)
				var outward := rod_axis * float(sign_value)
				if mouth.distance_to(end_point) <= FUSE_DISTANCE and slot_dir.dot(-outward) >= FUSE_ALIGN_DOT:
					_make_fixed_joint(rod, connector, end_point)
					_set_rod_end_occupied(rod, sign_value, true)
					_set_connector_occupied(connector, slot, true)
					changed = true
					endpoint_done = true
					break
			if endpoint_done:
				break
		if endpoint_done:
			continue
		for body in bodies:
			if not is_instance_valid(body) or str(body.get_meta("kind", "")) != "rod":
				continue
			var rod := body as RigidBody3D
			if _fixed_pair_exists(rod, connector):
				continue
			var rod_axis: Vector3 = rod.get_meta("axis")
			rod_axis = rod_axis.normalized()
			if absf(rod_axis.dot(slot_dir)) > 0.22:
				continue
			var half_len := maxf(0.0, float(rod.get_meta("visual_length")) * 0.5 - 0.50)
			var along := clampf((mouth - rod.global_position).dot(rod_axis), -half_len, half_len)
			var closest := rod.global_position + rod_axis * along
			if closest.distance_to(mouth) <= CROSS_FUSE_DISTANCE:
				_make_fixed_joint(rod, connector, closest)
				_set_connector_occupied(connector, slot, true)
				changed = true
				break
	return changed

func _auto_fuse_all() -> bool:
	var any_changed := false
	for _pass in range(3):
		var changed := false
		for body in bodies:
			if not is_instance_valid(body):
				continue
			if str(body.get_meta("kind", "")) == "rod":
				var rod := body as RigidBody3D
				changed = _auto_fuse_rod_end(rod, -1) or changed
				changed = _auto_fuse_rod_end(rod, 1) or changed
		for body in bodies:
			if is_instance_valid(body) and str(body.get_meta("kind", "")) == "connector":
				changed = _auto_fuse_connector(body as RigidBody3D) or changed
		any_changed = any_changed or changed
		if not changed:
			break
	return any_changed

func _extend_socket(connector: RigidBody3D, slot: int) -> void:
	if simulating or slot < 0:
		return
	var occupied: Dictionary = connector.get_meta("occupied")
	if occupied.has(slot):
		_status("That connector socket already has a rod")
		return
	var rod_len := float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var source_socket := _connector_socket_world(connector, slot)
	var start := source_socket["point"] as Vector3
	var direction := source_socket["dir"] as Vector3
	var target := _find_reachable_socket(start, direction, rod_len, connector)
	var finish := start + direction * rod_len
	if not target.is_empty():
		finish = target["point"] as Vector3
	var rod := _make_rod(selected_rod_type, start, finish)
	_make_fixed_joint(connector, rod, start)
	_set_connector_occupied(connector, slot, true)
	_set_rod_end_occupied(rod, -1, true)
	if not target.is_empty():
		var target_connector := target["connector"] as RigidBody3D
		var target_slot := int(target["slot"])
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
	var existing := _find_socket_for_rod_end(rod, sign_value)
	if not existing.is_empty():
		if _fuse_rod_end(rod, sign_value, existing):
			var target := existing["connector"] as RigidBody3D
			_auto_fuse_connector(target)
			_set_selected(target)
			_status("Rod fused to the existing matching connector")
			_commit_state()
		return
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var outward := axis * float(sign_value)
	var end_pos := _rod_end_world(rod, sign_value)
	var slot := int(connector_defs[selected_connector_type]["slots"][0])
	var basis := _connector_basis(slot, -outward, 0)
	var connector := _make_connector(selected_connector_type, Transform3D(basis, end_pos + outward * CONNECTOR_D))
	connector.set_meta("mount_slot", slot)
	connector.set_meta("mount_target_dir", -outward)
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
	var rod_len := float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var axis := (connector.global_transform.basis * Vector3.UP).normalized()
	var rod := _make_rod(selected_rod_type, connector.global_position - axis * rod_len * 0.5, connector.global_position + axis * rod_len * 0.5)
	_make_axle_joint(connector, rod)
	connector.set_meta("axle_occupied", true)
	_auto_fuse_rod_end(rod, -1)
	_auto_fuse_rod_end(rod, 1)
	_set_selected(rod)
	_status("Axle inserted. Unconnected cross pieces will physically collide with it in simulation.")
	_commit_state()

func _cross_snap(rod: RigidBody3D, hit_pos: Vector3) -> void:
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var slot := int(connector_defs[selected_connector_type]["slots"][0])
	var local_slot := _slot_dir(slot)
	var base := Basis(Quaternion(Vector3.UP, axis))
	var radial_now := (base * local_slot).normalized()
	var preferred := camera.global_transform.basis.x
	preferred -= axis * preferred.dot(axis)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.UP)
	if preferred.length_squared() < 0.02:
		preferred = axis.cross(Vector3.RIGHT)
	preferred = preferred.normalized()
	var angle := radial_now.signed_angle_to(preferred, axis)
	var basis := Basis(axis, angle) * base
	var radial := (basis * local_slot).normalized()
	var half_len := float(rod.get_meta("visual_length")) * 0.5 - 0.42
	var along := clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var snap_point := rod.global_position + axis * along
	var connector := _make_connector(selected_connector_type, Transform3D(basis, snap_point - radial * CONNECTOR_D))
	_set_connector_occupied(connector, slot, true)
	_make_fixed_joint(rod, connector, snap_point)
	last_placed_connector = connector
	_auto_fuse_connector(connector)
	_set_selected(connector)
	_status("Cross connector snapped and overlapping valid geometry fused")
	_commit_state()

func _connector_fixed_attachments(connector: RigidBody3D) -> Array:
	var result: Array = []
	for joint in joints:
		if not is_instance_valid(joint) or not (joint is Joint3D) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes := _joint_nodes(joint)
		if nodes[0] != connector and nodes[1] != connector:
			continue
		var delta := joint.global_position - connector.global_position
		if delta.length_squared() < 0.15:
			continue
		result.append({"joint": joint, "dir": delta.normalized()})
	return result

func _map_attachments_to_slots(basis: Basis, def_index: int, attachments: Array) -> Dictionary:
	var used: Dictionary = {}
	for attachment in attachments:
		var target_dir := attachment["dir"] as Vector3
		var best_slot := -1
		var best_dot := ROTATION_ALIGN_DOT
		for slot_value in connector_defs[def_index]["slots"]:
			var slot := int(slot_value)
			if used.has(slot):
				continue
			var world_dir := (basis * _slot_dir(slot)).normalized()
			var score := world_dir.dot(target_dir)
			if score > best_dot:
				best_dot = score
				best_slot = slot
		if best_slot < 0:
			return {"valid": false}
		used[best_slot] = true
	return {"valid": true, "occupied": used}

func _axle_basis_valid(connector: RigidBody3D, basis: Basis) -> bool:
	for joint in joints:
		if not is_instance_valid(joint) or not (joint is Joint3D) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes := _joint_nodes(joint)
		if nodes[0] != connector and nodes[1] != connector:
			continue
		var other = nodes[1] if nodes[0] == connector else nodes[0]
		if other == null or not (other is RigidBody3D):
			continue
		var rod_axis := ((other as RigidBody3D).global_transform.basis * Vector3.UP).normalized()
		var hub_axis := (basis * Vector3.UP).normalized()
		if absf(rod_axis.dot(hub_axis)) < ROTATION_ALIGN_DOT:
			return false
	return true

func _update_axle_frames(connector: RigidBody3D) -> void:
	for joint in joints:
		if not is_instance_valid(joint) or not (joint is Joint3D) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes := _joint_nodes(joint)
		if nodes[0] == connector or nodes[1] == connector:
			joint.global_transform = connector.global_transform

func _try_connector_basis(connector: RigidBody3D, candidate: Basis, label: String) -> bool:
	var def_index := int(connector.get_meta("connector_type"))
	var mapping := _map_attachments_to_slots(candidate, def_index, _connector_fixed_attachments(connector))
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
	var attachments := _connector_fixed_attachments(connector)
	var axis := (connector.global_transform.basis * Vector3.UP).normalized()
	if attachments.size() == 1:
		axis = attachments[0]["dir"] as Vector3
	var candidate := Basis(axis.normalized(), deg_to_rad(45.0)) * connector.global_transform.basis
	if _try_connector_basis(connector, candidate, "Rotate 45°"):
		connector.set_meta("spin_step", (int(connector.get_meta("spin_step", 0)) + 1) % 8)
		connector.set_meta("build_transform", connector.global_transform)

func _tilt_selected_connector() -> void:
	if simulating or _selected_kind() != "connector":
		_status("Select a connector first")
		return
	var connector := selected_piece
	var axis := (connector.global_transform.basis * Vector3.RIGHT).normalized()
	var candidate := Basis(axis, deg_to_rad(45.0)) * connector.global_transform.basis
	if _try_connector_basis(connector, candidate, "Tilt 45°"):
		connector.set_meta("tilt_step", (int(connector.get_meta("tilt_step", 0)) + 1) % 8)
		connector.set_meta("build_transform", connector.global_transform)

func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	if _selected_kind() != "connector":
		selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
		_update_ui()
		_status("Connector choice: %s" % connector_defs[selected_connector_type]["name"])
		return
	var connector := selected_piece
	var current := int(connector.get_meta("connector_type"))
	var attachments := _connector_fixed_attachments(connector)
	var candidate := current
	for _i in range(connector_defs.size() - 1):
		candidate = wrapi(candidate + delta, 0, connector_defs.size())
		var mapping := _map_attachments_to_slots(connector.global_transform.basis, candidate, attachments)
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
	var was_rod := _selected_kind() == "rod"
	var rod: RigidBody3D = selected_piece if was_rod else null
	var before_type := int(rod.get_meta("rod_type")) if is_instance_valid(rod) else -1
	var before_len := float(rod.get_meta("visual_length")) if is_instance_valid(rod) else -1.0
	super._change_rod_type(delta)
	if is_instance_valid(rod):
		var changed := before_type != int(rod.get_meta("rod_type")) or not is_equal_approx(before_len, float(rod.get_meta("visual_length")))
		if changed:
			_auto_fuse_rod_end(rod, -1)
			_auto_fuse_rod_end(rod, 1)
			_commit_state()

func _handle_tap(screen_pos: Vector2) -> void:
	if simulating or help_panel.visible:
		return
	var now := Time.get_ticks_msec()
	if now - last_world_tap_ms < WORLD_TAP_DEBOUNCE_MS and last_world_tap_pos.distance_to(screen_pos) < 36.0:
		return
	last_world_tap_ms = now
	last_world_tap_pos = screen_pos
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 800.0)
	query.collision_mask = 2 | 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider == null or not (collider is RigidBody3D):
		return
	var body := collider as RigidBody3D
	var kind := str(body.get_meta("kind", ""))
	if attach_mode == 0:
		if kind == "connector":
			_set_selected(body)
			var slot := _select_slot_strict(body, hit["position"])
			if slot >= 0:
				_extend_socket(body, slot)
			elif slot == -3:
				_status("That socket is occupied — no second rod can be placed there")
			else:
				_spin_connector(body)
		elif kind == "rod":
			var end_sign := _rod_end_hit(body, hit["position"])
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
	var keys := touches.keys()
	if keys.size() < 2:
		return Vector2.ZERO
	return ((touches[keys[0]] as Vector2) + (touches[keys[1]] as Vector2)) * 0.5

func _pan_camera(screen_delta: Vector2) -> void:
	if camera == null:
		return
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.001:
		right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()
	var scale := camera_distance * 0.0027
	camera_target += (-right * screen_delta.x + forward * screen_delta.y) * scale
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.y = 4.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_mouse_guard_until = Time.get_ticks_msec() + 350
		if event.pressed:
			touches[event.index] = event.position
			touch_start[event.index] = event.position
			touch_moved[event.index] = false
			if touches.size() >= 2:
				pinch_last = _pinch_distance()
				pinch_center_last = _pinch_center()
				pinch_center_valid = true
		else:
			var moved := bool(touch_moved.get(event.index, false))
			var start: Vector2 = touch_start.get(event.index, event.position)
			touches.erase(event.index)
			touch_start.erase(event.index)
			touch_moved.erase(event.index)
			if touches.size() < 2:
				pinch_last = -1.0
				pinch_center_valid = false
			if not moved and start.distance_to(event.position) < 18.0:
				_handle_tap(event.position)
	elif event is InputEventScreenDrag:
		touch_mouse_guard_until = Time.get_ticks_msec() + 350
		touches[event.index] = event.position
		if event.relative.length() > 2.0:
			touch_moved[event.index] = true
		if touches.size() >= 2:
			var distance := _pinch_distance()
			if pinch_last > 0.0:
				camera_distance = clampf(camera_distance - (distance - pinch_last) * 0.030, 5.0, 220.0)
			pinch_last = distance
			var center := _pinch_center()
			if pinch_center_valid:
				_pan_camera(center - pinch_center_last)
			pinch_center_last = center
			pinch_center_valid = true
		else:
			camera_yaw -= event.relative.x * 0.006
			camera_pitch = clampf(camera_pitch - event.relative.y * 0.005, deg_to_rad(8.0), deg_to_rad(82.0))
	elif event is InputEventMouseButton:
		if Time.get_ticks_msec() < touch_mouse_guard_until:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down = true
				mouse_start = event.position
				mouse_moved = false
			else:
				if mouse_down and not mouse_moved and mouse_start.distance_to(event.position) < 10.0:
					_handle_tap(event.position)
				mouse_down = false
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			mouse_pan_down = event.pressed
			mouse_pan_last = event.position
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera_distance = clampf(camera_distance + (-2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0), 5.0, 220.0)
	elif event is InputEventMouseMotion:
		if Time.get_ticks_msec() < touch_mouse_guard_until:
			return
		if mouse_pan_down:
			_pan_camera(event.position - mouse_pan_last)
			mouse_pan_last = event.position
		elif mouse_down:
			if event.relative.length() > 1.0:
				mouse_moved = true
				camera_yaw -= event.relative.x * 0.006
				camera_pitch = clampf(camera_pitch - event.relative.y * 0.005, deg_to_rad(8.0), deg_to_rad(82.0))

func _update_camera() -> void:
	if camera == null:
		return
	camera_pitch = clampf(camera_pitch, deg_to_rad(8.0), deg_to_rad(82.0))
	var cp := cos(camera_pitch)
	var offset := Vector3(cos(camera_yaw) * cp, sin(camera_pitch), sin(camera_yaw) * cp) * camera_distance
	camera.global_position = camera_target + offset
	camera.look_at(camera_target, Vector3.UP)

func _capture_state() -> Dictionary:
	var states: Array = []
	var index_by_id: Dictionary = {}
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var index := states.size()
		index_by_id[body.get_instance_id()] = index
		var kind := str(body.get_meta("kind", ""))
		var state: Dictionary = {
			"kind": kind,
			"transform": body.get_meta("build_transform", body.global_transform),
			"seed": bool(body.get_meta("seed", false))
		}
		if kind == "connector":
			state["type"] = int(body.get_meta("connector_type"))
			state["occupied"] = (body.get_meta("occupied") as Dictionary).duplicate(true)
			state["axle_occupied"] = bool(body.get_meta("axle_occupied", false))
			state["spin_step"] = int(body.get_meta("spin_step", 0))
			state["tilt_step"] = int(body.get_meta("tilt_step", 0))
		else:
			state["type"] = int(body.get_meta("rod_type"))
			state["length"] = float(body.get_meta("visual_length"))
			state["end_occupied"] = (body.get_meta("end_occupied") as Dictionary).duplicate(true)
		states.append(state)
	var joint_states: Array = []
	for joint in joints:
		if not is_instance_valid(joint) or not (joint is Joint3D):
			continue
		var nodes := _joint_nodes(joint)
		if nodes[0] == null or nodes[1] == null:
			continue
		var id_a := (nodes[0] as Node).get_instance_id()
		var id_b := (nodes[1] as Node).get_instance_id()
		if not index_by_id.has(id_a) or not index_by_id.has(id_b):
			continue
		joint_states.append({
			"type": "axle" if str(joint.name).begins_with("AxleJoint") else "fixed",
			"a": int(index_by_id[id_a]),
			"b": int(index_by_id[id_b]),
			"transform": joint.global_transform
		})
	var selected_index := -1
	if is_instance_valid(selected_piece) and index_by_id.has(selected_piece.get_instance_id()):
		selected_index = int(index_by_id[selected_piece.get_instance_id()])
	return {"bodies": states, "joints": joint_states, "selected": selected_index, "rod_type": selected_rod_type, "connector_type": selected_connector_type}

func _clear_build_nodes() -> void:
	for joint in joints.duplicate():
		if is_instance_valid(joint):
			if joint.get_parent() == self:
				remove_child(joint)
			joint.queue_free()
	for body in bodies.duplicate():
		if is_instance_valid(body):
			body.collision_layer = 0
			body.collision_mask = 0
			if body.get_parent() == self:
				remove_child(body)
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
	for state_value in snapshot["bodies"]:
		var state := state_value as Dictionary
		var transform := state["transform"] as Transform3D
		var body: RigidBody3D
		if str(state["kind"]) == "connector":
			body = _make_connector(int(state["type"]), transform)
			body.set_meta("occupied", (state["occupied"] as Dictionary).duplicate(true))
			body.set_meta("axle_occupied", bool(state["axle_occupied"]))
			body.set_meta("spin_step", int(state.get("spin_step", 0)))
			body.set_meta("tilt_step", int(state.get("tilt_step", 0)))
		else:
			var length := float(state["length"])
			var axis := (transform.basis * Vector3.UP).normalized()
			body = _make_rod(int(state["type"]), transform.origin - axis * length * 0.5, transform.origin + axis * length * 0.5)
			body.global_transform = transform
			body.set_meta("axis", axis)
			body.set_meta("end_occupied", (state["end_occupied"] as Dictionary).duplicate(true))
		body.set_meta("seed", bool(state["seed"]))
		body.set_meta("build_transform", transform)
		restored.append(body)
	for joint_value in snapshot["joints"]:
		var joint_state := joint_value as Dictionary
		var a := restored[int(joint_state["a"])] as RigidBody3D
		var b := restored[int(joint_state["b"])] as RigidBody3D
		var joint: Joint3D
		if str(joint_state["type"]) == "axle":
			var connector := a if str(a.get_meta("kind", "")) == "connector" else b
			var rod := b if connector == a else a
			joint = _make_axle_joint(connector, rod)
		else:
			joint = _make_fixed_joint(a, b, (joint_state["transform"] as Transform3D).origin)
		joint.global_transform = joint_state["transform"] as Transform3D
	selected_rod_type = int(snapshot.get("rod_type", 2))
	selected_connector_type = int(snapshot.get("connector_type", 6))
	var selected_index := int(snapshot.get("selected", -1))
	if selected_index >= 0 and selected_index < restored.size():
		_set_selected(restored[selected_index])
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
	else:
		state_index += 1
	if state_history.size() > 80:
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
	_status("Restarted at the first editable connector. Use Conn ◀/▶ or tap it to rotate.")

func _toggle_simulation() -> void:
	if simulating:
		_reset_pose()
		return
	if _auto_fuse_all():
		_commit_state()
		_status("Coincident valid geometry fused before simulation")
	super._toggle_simulation()

func _release_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not simulating:
		return
	for body in bodies:
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
