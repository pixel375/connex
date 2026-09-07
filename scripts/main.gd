extends Node3D

const VERSION := "0.1.1"
const CONNECTOR_D := 1.01
const ROD_RADIUS := 0.29
const CONNECTOR_THICKNESS := 0.60
const END_HIT_MARGIN := 0.80

var rod_defs: Array = [
	{"name":"Green 16", "actual_mm":17.5, "color":Color("2ca64b"), "mass":0.05},
	{"name":"White 32", "actual_mm":33.0, "color":Color("eeeeea"), "mass":0.08},
	{"name":"Blue 54", "actual_mm":55.0, "color":Color("1769c2"), "mass":0.13},
	{"name":"Yellow 86", "actual_mm":86.0, "color":Color("f2cf24"), "mass":0.20},
	{"name":"Red 128", "actual_mm":130.0, "color":Color("d93631"), "mass":0.30},
	{"name":"Gray 190", "actual_mm":192.0, "color":Color("9ba1a7"), "mass":0.45},
]

var connector_defs: Array = [
	{"name":"Gray 1-way", "slots":[0], "color":Color("4e5459"), "mass":0.055},
	{"name":"Orange straight", "slots":[0,180], "color":Color("ef7e25"), "mass":0.075},
	{"name":"Light gray 2-way", "slots":[0,45], "color":Color("c6c9cb"), "mass":0.085},
	{"name":"Red 3-way", "slots":[0,45,90], "color":Color("d93631"), "mass":0.12},
	{"name":"Green 4-way", "slots":[0,45,90,135], "color":Color("2ca64b"), "mass":0.16},
	{"name":"Yellow 5-way", "slots":[0,45,90,135,180], "color":Color("f2cf24"), "mass":0.20},
	{"name":"White 8-way", "slots":[0,45,90,135,180,225,270,315], "color":Color("eeeeea"), "mass":0.30},
]

var selected_rod_type := 2
var selected_connector_type := 6
var attach_mode := 0
var twist_step := 0
var simulating := false
var selected_piece: RigidBody3D

var camera: Camera3D
var camera_target := Vector3(0, 4.0, 0)
var camera_distance := 19.0
var camera_yaw := deg_to_rad(35.0)
var camera_pitch := deg_to_rad(-18.0)

var status_label: Label
var rod_label: Label
var connector_label: Label
var mode_button: Button
var twist_button: Button
var simulate_button: Button
var help_panel: PanelContainer

var bodies: Array = []
var joints: Array = []
var history: Array = []
var piece_counter := 0
var material_cache: Dictionary = {}

var touches: Dictionary = {}
var touch_start: Dictionary = {}
var touch_moved: Dictionary = {}
var pinch_last := -1.0
var mouse_down := false
var mouse_start := Vector2.ZERO
var mouse_moved := false

func _ready() -> void:
	_build_world()
	_build_ui()
	var seed_basis := Basis(Vector3.RIGHT, deg_to_rad(90.0))
	var seed := _make_connector(6, Transform3D(seed_basis, Vector3(0, 4.0, 0)))
	seed.set_meta("seed", true)
	_set_selected(seed)
	_status("Tap a connector socket to add a rod. Tap the free rod end to add a connector.")

func _process(_delta: float) -> void:
	_update_camera()

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.62, 0.70)
	env.ambient_light_energy = 0.62
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -35, 0)
	light.light_energy = 1.55
	light.shadow_enabled = true
	add_child(light)

	camera = Camera3D.new()
	camera.fov = 55.0
	camera.near = 0.08
	camera.far = 150.0
	add_child(camera)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)
	var mesh_instance := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(60, 0.18, 60)
	mesh_instance.mesh = ground_mesh
	mesh_instance.position.y = -0.09
	mesh_instance.material_override = _mat(Color(0.065, 0.075, 0.09))
	ground.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(60, 0.18, 60)
	collision.shape = ground_shape
	collision.position.y = -0.09
	ground.add_child(collision)
	_build_grid()
	_update_camera()

func _build_grid() -> void:
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(-30, 31):
		var strength := 0.34 if i % 5 == 0 else 0.16
		im.surface_set_color(Color(0.36, 0.40, 0.48, strength))
		im.surface_add_vertex(Vector3(float(i), 0.012, -30))
		im.surface_add_vertex(Vector3(float(i), 0.012, 30))
		im.surface_add_vertex(Vector3(-30, 0.012, float(i)))
		im.surface_add_vertex(Vector3(30, 0.012, float(i)))
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
	status_label.add_theme_font_size_override("font_size", 20)
	top_row.add_child(status_label)
	var help_button := Button.new()
	help_button.text = "?"
	help_button.custom_minimum_size = Vector2(56, 42)
	help_button.add_theme_font_size_override("font_size", 22)
	help_button.mouse_filter = Control.MOUSE_FILTER_STOP
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.pressed.connect(_toggle_help)
	top_row.add_child(help_button)

	var bottom := PanelContainer.new()
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_top = -150
	bottom.offset_bottom = -8
	layer.add_child(bottom)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	bottom.add_child(rows)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	rows.add_child(row1)
	_add_button(row1, "◀ Rod", _prev_rod)
	rod_label = _add_label(row1)
	_add_button(row1, "Rod ▶", _next_rod)
	_add_button(row1, "◀ Conn", _prev_connector)
	connector_label = _add_label(row1)
	_add_button(row1, "Conn ▶", _next_connector)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 5)
	rows.add_child(row2)
	mode_button = _add_button(row2, "SOCKET", _cycle_mode)
	twist_button = _add_button(row2, "Rotate 0°", _cycle_twist)
	_add_button(row2, "Undo", _undo)
	_add_button(row2, "Reset", _reset_pose)
	simulate_button = _add_button(row2, "SIMULATE", _toggle_simulation)

	help_panel = PanelContainer.new()
	help_panel.visible = false
	help_panel.anchor_left = 0.12
	help_panel.anchor_right = 0.88
	help_panel.anchor_top = 0.12
	help_panel.anchor_bottom = 0.73
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
	help.add_theme_font_size_override("font_size", 18)
	help.text = "CONNEX LAB v%s\n\nSOCKET: tap a connector socket to create ONLY a rod. Tap the free end of that rod to create a connector.\n\nTap a rod body or connector hub to select it. Rod arrows change the selected rod length while it still has a free end. Connector arrows change the selected connector type. ROTATE turns a newly attached connector in 45° steps.\n\nAXLE: tap a connector hub to insert a rod through it. CROSS remains an explicit special K'NEX-style cross-snap mode.\n\nDrag empty space to orbit. Pinch to zoom. SIMULATE releases physics; BUILD restores the construction pose." % VERSION
	margin.add_child(help)

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(90, 54)
	button.add_theme_font_size_override("font_size", 18)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_label(parent: Control) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(150, 54)
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label

func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material_cache[key] = material
	return material

func _slot_dir(angle_deg: int) -> Vector3:
	var angle := deg_to_rad(float(angle_deg))
	return Vector3(cos(angle), 0.0, -sin(angle)).normalized()

func _make_connector(def_index: int, xform: Transform3D) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Connector_%d" % piece_counter
	piece_counter += 1
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.linear_damp = 0.12
	body.angular_damp = 0.18
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	body.global_transform = xform
	body.set_meta("kind", "connector")
	body.set_meta("connector_type", def_index)
	body.set_meta("occupied", {})
	body.set_meta("axle_occupied", false)
	body.set_meta("mount_slot", -1)
	body.set_meta("mount_target_dir", Vector3.ZERO)
	body.set_meta("twist", 0)
	_rebuild_connector(body, def_index)
	body.set_meta("build_transform", body.global_transform)
	bodies.append(body)
	return body

func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	for child in body.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()
	var definition: Dictionary = connector_defs[def_index]
	body.mass = float(definition["mass"])
	body.set_meta("connector_type", def_index)
	var color: Color = definition["color"]
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.62
	torus.rings = 16
	torus.ring_segments = 10
	ring.mesh = torus
	ring.material_override = _mat(color)
	body.add_child(ring)
	for slot_value in definition["slots"]:
		_add_socket_visual(body, int(slot_value), color)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.46
	shape.height = CONNECTOR_THICKNESS
	col.shape = shape
	body.add_child(col)

func _add_socket_visual(parent: Node3D, angle_deg: int, color: Color) -> void:
	var direction := _slot_dir(angle_deg)
	var tangent := Vector3(-direction.z, 0, direction.x)
	var angle := deg_to_rad(float(angle_deg))
	var web := MeshInstance3D.new()
	var web_box := BoxMesh.new()
	web_box.size = Vector3(0.58, 0.34, 0.34)
	web.mesh = web_box
	web.material_override = _mat(color)
	web.position = direction * 0.73
	web.rotation.y = angle
	parent.add_child(web)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_box := BoxMesh.new()
		arm_box.size = Vector3(0.76, CONNECTOR_THICKNESS, 0.16)
		arm.mesh = arm_box
		arm.material_override = _mat(color)
		arm.position = direction * 1.08 + tangent * (0.21 * float(side))
		arm.rotation.y = angle
		parent.add_child(arm)
	var lip := MeshInstance3D.new()
	var lip_box := BoxMesh.new()
	lip_box.size = Vector3(0.15, CONNECTOR_THICKNESS, 0.55)
	lip.mesh = lip_box
	lip.material_override = _mat(color.lightened(0.04))
	lip.position = direction * 1.42
	lip.rotation.y = angle
	parent.add_child(lip)

func _make_rod(def_index: int, start: Vector3, finish: Vector3) -> RigidBody3D:
	var axis := (finish - start).normalized()
	var length := start.distance_to(finish)
	var basis := Basis(Quaternion(Vector3.UP, axis))
	var body := RigidBody3D.new()
	body.name = "Rod_%d" % piece_counter
	piece_counter += 1
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.linear_damp = 0.10
	body.angular_damp = 0.16
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	body.global_transform = Transform3D(basis, (start + finish) * 0.5)
	body.set_meta("kind", "rod")
	body.set_meta("rod_type", def_index)
	body.set_meta("axis", axis)
	body.set_meta("visual_length", length)
	body.set_meta("end_occupied", {})
	body.set_meta("axle_connector", null)
	_rebuild_rod(body, def_index, length)
	body.set_meta("build_transform", body.global_transform)
	bodies.append(body)
	return body

func _rebuild_rod(body: RigidBody3D, def_index: int, length: float) -> void:
	for child in body.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()
	var definition: Dictionary = rod_defs[def_index]
	body.mass = float(definition["mass"])
	body.set_meta("rod_type", def_index)
	body.set_meta("visual_length", length)
	var color: Color = definition["color"]
	var shaft_length: float = maxf(0.20, length - 0.76)
	for rotation in [45.0, -45.0]:
		var rib := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.42, shaft_length, 0.105)
		rib.mesh = box
		rib.material_override = _mat(color)
		rib.rotation.y = deg_to_rad(float(rotation))
		body.add_child(rib)
	for sign_value in [-1.0, 1.0]:
		var signf := float(sign_value)
		var grip := MeshInstance3D.new()
		var grip_mesh := CylinderMesh.new()
		grip_mesh.top_radius = ROD_RADIUS
		grip_mesh.bottom_radius = ROD_RADIUS
		grip_mesh.height = 0.42
		grip_mesh.radial_segments = 12
		grip.mesh = grip_mesh
		grip.material_override = _mat(color)
		grip.position.y = signf * (length * 0.5 - 0.28)
		body.add_child(grip)
		var flange := MeshInstance3D.new()
		var flange_mesh := CylinderMesh.new()
		flange_mesh.top_radius = 0.36
		flange_mesh.bottom_radius = 0.36
		flange_mesh.height = 0.13
		flange_mesh.radial_segments = 12
		flange.mesh = flange_mesh
		flange.material_override = _mat(color)
		flange.position.y = signf * (length * 0.5 - 0.055)
		body.add_child(flange)
		var groove := MeshInstance3D.new()
		var groove_mesh := TorusMesh.new()
		groove_mesh.inner_radius = 0.235
		groove_mesh.outer_radius = 0.285
		groove_mesh.rings = 10
		groove_mesh.ring_segments = 8
		groove.mesh = groove_mesh
		groove.material_override = _mat(color.darkened(0.16))
		groove.position.y = signf * (length * 0.5 - 0.17)
		body.add_child(groove)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = ROD_RADIUS
	capsule.height = maxf(length, ROD_RADIUS * 2.0)
	col.shape = capsule
	body.add_child(col)

func _make_fixed_joint(a: PhysicsBody3D, b: PhysicsBody3D, anchor: Vector3) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	joint.name = "FixedJoint_%d" % joints.size()
	add_child(joint)
	joint.global_position = anchor
	joint.node_a = a.get_path()
	joint.node_b = b.get_path()
	joint.exclude_nodes_from_collision = true
	for axis_name in ["x", "y", "z"]:
		joint.set("linear_limit_%s/enabled" % axis_name, true)
		joint.set("linear_limit_%s/lower_distance" % axis_name, 0.0)
		joint.set("linear_limit_%s/upper_distance" % axis_name, 0.0)
		joint.set("angular_limit_%s/enabled" % axis_name, true)
		joint.set("angular_limit_%s/lower_angle" % axis_name, 0.0)
		joint.set("angular_limit_%s/upper_angle" % axis_name, 0.0)
	joints.append(joint)
	return joint

func _make_axle_joint(connector: PhysicsBody3D, rod: PhysicsBody3D) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	joint.name = "AxleJoint_%d" % joints.size()
	add_child(joint)
	joint.global_transform = connector.global_transform
	joint.node_a = connector.get_path()
	joint.node_b = rod.get_path()
	joint.exclude_nodes_from_collision = true
	for axis_name in ["x", "z"]:
		joint.set("linear_limit_%s/enabled" % axis_name, true)
		joint.set("linear_limit_%s/lower_distance" % axis_name, 0.0)
		joint.set("linear_limit_%s/upper_distance" % axis_name, 0.0)
		joint.set("angular_limit_%s/enabled" % axis_name, true)
		joint.set("angular_limit_%s/lower_angle" % axis_name, 0.0)
		joint.set("angular_limit_%s/upper_angle" % axis_name, 0.0)
	joint.set("linear_limit_y/enabled", false)
	joint.set("angular_limit_y/enabled", false)
	joints.append(joint)
	return joint

func _set_connector_occupied(connector: RigidBody3D, slot: int, value: bool) -> void:
	var occupied: Dictionary = connector.get_meta("occupied")
	if value:
		occupied[slot] = true
	else:
		occupied.erase(slot)
	connector.set_meta("occupied", occupied)

func _set_rod_end_occupied(rod: RigidBody3D, sign_value: int, value: bool) -> void:
	var occupied: Dictionary = rod.get_meta("end_occupied")
	if value:
		occupied[sign_value] = true
	else:
		occupied.erase(sign_value)
	rod.set_meta("end_occupied", occupied)

func _rod_end_world(rod: RigidBody3D, sign_value: int) -> Vector3:
	var axis: Vector3 = rod.get_meta("axis")
	var length := float(rod.get_meta("visual_length"))
	return rod.global_position + axis.normalized() * (length * 0.5 * float(sign_value))

func _select_slot(connector: RigidBody3D, hit_pos: Vector3) -> int:
	var local := connector.global_transform.affine_inverse() * hit_pos
	local.y = 0.0
	if local.length() < 0.68:
		return -2
	var def_index := int(connector.get_meta("connector_type"))
	var occupied: Dictionary = connector.get_meta("occupied")
	var direction := local.normalized()
	var best := -1
	var best_dot := 0.60
	for slot_value in connector_defs[def_index]["slots"]:
		var slot := int(slot_value)
		if occupied.has(slot):
			continue
		var score := direction.dot(_slot_dir(slot))
		if score > best_dot:
			best_dot = score
			best = slot
	return best

func _rod_end_hit(rod: RigidBody3D, hit_pos: Vector3) -> int:
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var half_len := float(rod.get_meta("visual_length")) * 0.5
	var along := (hit_pos - rod.global_position).dot(axis)
	if abs(abs(along) - half_len) <= END_HIT_MARGIN:
		return 1 if along >= 0.0 else -1
	return 0

func _connector_basis(slot: int, target_dir: Vector3, twist: int) -> Basis:
	var local_dir := _slot_dir(slot)
	var target := target_dir.normalized()
	var align := Basis(Quaternion(local_dir, target))
	var spin := Basis(target, deg_to_rad(float(twist * 45)))
	return spin * align

func _extend_socket(connector: RigidBody3D, slot: int) -> void:
	if slot < 0:
		_set_selected(connector)
		_status("Connector selected. Tap one of its free outer sockets to add a rod.")
		return
	var rod_len := float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var direction := (connector.global_transform.basis * _slot_dir(slot)).normalized()
	var start := connector.global_position + direction * CONNECTOR_D
	var finish := start + direction * rod_len
	var rod := _make_rod(selected_rod_type, start, finish)
	var joint := _make_fixed_joint(connector, rod, start)
	_set_connector_occupied(connector, slot, true)
	_set_rod_end_occupied(rod, -1, true)
	history.append({"created":[rod, joint], "slots":[[connector, slot]], "rod_ends":[[rod, -1]]})
	_set_selected(rod)
	_status("Rod added. Tap its FREE END to add a connector, or use Rod ◀/▶ to change its length.")

func _attach_connector_to_rod_end(rod: RigidBody3D, sign_value: int) -> void:
	var end_occupied: Dictionary = rod.get_meta("end_occupied")
	if end_occupied.has(sign_value):
		_set_selected(rod)
		_status("That rod end is already connected")
		return
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var outward := axis * float(sign_value)
	var end_pos := _rod_end_world(rod, sign_value)
	var slot := int(connector_defs[selected_connector_type]["slots"][0])
	var target_dir := -outward
	var basis := _connector_basis(slot, target_dir, twist_step)
	var center := end_pos + outward * CONNECTOR_D
	var connector := _make_connector(selected_connector_type, Transform3D(basis, center))
	connector.set_meta("mount_slot", slot)
	connector.set_meta("mount_target_dir", target_dir)
	connector.set_meta("twist", twist_step)
	connector.set_meta("build_transform", connector.global_transform)
	var joint := _make_fixed_joint(rod, connector, end_pos)
	_set_rod_end_occupied(rod, sign_value, true)
	_set_connector_occupied(connector, slot, true)
	history.append({"created":[connector, joint], "slots":[[connector, slot]], "rod_ends":[[rod, sign_value]]})
	_set_selected(connector)
	_status("Connector added. Conn ◀/▶ changes its type; Rotate turns it around the rod.")

func _insert_axle(connector: RigidBody3D) -> void:
	if bool(connector.get_meta("axle_occupied", false)):
		_status("That hub already contains an axle")
		return
	var rod_len := float(rod_defs[selected_rod_type]["actual_mm"]) / 10.0
	var axis := (connector.global_transform.basis * Vector3.UP).normalized()
	var rod := _make_rod(selected_rod_type, connector.global_position - axis * rod_len * 0.5, connector.global_position + axis * rod_len * 0.5)
	var joint := _make_axle_joint(connector, rod)
	connector.set_meta("axle_occupied", true)
	rod.set_meta("axle_connector", connector)
	history.append({"created":[rod, joint], "axle":connector})
	_set_selected(rod)
	_status("Axle inserted — free slide + rotation")

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
	var center := snap_point - radial * CONNECTOR_D
	var connector := _make_connector(selected_connector_type, Transform3D(basis, center))
	_set_connector_occupied(connector, slot, true)
	var joint := _make_fixed_joint(rod, connector, snap_point)
	history.append({"created":[connector, joint], "slots":[[connector, slot]]})
	_set_selected(connector)
	_status("Cross-snapped connector at 90°")

func _set_selected(body: RigidBody3D) -> void:
	selected_piece = body
	if not is_instance_valid(body):
		_update_ui()
		return
	var kind := str(body.get_meta("kind", ""))
	if kind == "rod":
		selected_rod_type = int(body.get_meta("rod_type"))
	elif kind == "connector":
		selected_connector_type = int(body.get_meta("connector_type"))
		twist_step = int(body.get_meta("twist", twist_step))
	_update_ui()

func _selected_kind() -> String:
	if not is_instance_valid(selected_piece):
		return ""
	return str(selected_piece.get_meta("kind", ""))

func _change_rod_type(delta: int) -> void:
	if simulating:
		return
	var target := wrapi(selected_rod_type + delta, 0, rod_defs.size())
	if _selected_kind() != "rod":
		selected_rod_type = target
		_update_ui()
		_status("Next rod: %s" % rod_defs[selected_rod_type]["name"])
		return
	var rod := selected_piece
	var occupied: Dictionary = rod.get_meta("end_occupied")
	if occupied.size() >= 2:
		_status("Rod length is locked between two connectors. Undo one end first.")
		return
	var old_len := float(rod.get_meta("visual_length"))
	var new_len := float(rod_defs[target]["actual_mm"]) / 10.0
	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	if occupied.size() == 1:
		var anchor_sign := int(occupied.keys()[0])
		var anchor := rod.global_position + axis * old_len * 0.5 * float(anchor_sign)
		rod.global_position = anchor - axis * new_len * 0.5 * float(anchor_sign)
	_rebuild_rod(rod, target, new_len)
	rod.set_meta("build_transform", rod.global_transform)
	selected_rod_type = target
	_update_ui()
	_status("Selected rod changed to %s" % rod_defs[target]["name"])

func _connector_type_compatible(connector: RigidBody3D, def_index: int) -> bool:
	var slots: Array = connector_defs[def_index]["slots"]
	var occupied: Dictionary = connector.get_meta("occupied")
	for key in occupied.keys():
		if not slots.has(int(key)):
			return false
	return true

func _change_connector_type(delta: int) -> void:
	if simulating:
		return
	if _selected_kind() != "connector":
		selected_connector_type = wrapi(selected_connector_type + delta, 0, connector_defs.size())
		_update_ui()
		_status("Next connector: %s" % connector_defs[selected_connector_type]["name"])
		return
	var connector := selected_piece
	var candidate := selected_connector_type
	for _i in range(connector_defs.size()):
		candidate = wrapi(candidate + delta, 0, connector_defs.size())
		if _connector_type_compatible(connector, candidate):
			_rebuild_connector(connector, candidate)
			connector.set_meta("build_transform", connector.global_transform)
			selected_connector_type = candidate
			_update_ui()
			_status("Selected connector changed to %s" % connector_defs[candidate]["name"])
			return
	_status("No other connector type can keep the currently occupied sockets")

func _rotate_selected_connector() -> void:
	if simulating:
		return
	if _selected_kind() != "connector":
		twist_step = (twist_step + 1) % 8
		_update_ui()
		_status("Next connector rotation: %d°" % (twist_step * 45))
		return
	var connector := selected_piece
	var occupied: Dictionary = connector.get_meta("occupied")
	var mount_slot := int(connector.get_meta("mount_slot", -1))
	if mount_slot >= 0:
		if occupied.size() > 1:
			_status("Connector rotation is locked after additional rods are attached")
			return
		twist_step = (int(connector.get_meta("twist", 0)) + 1) % 8
		var target_dir: Vector3 = connector.get_meta("mount_target_dir")
		connector.global_transform.basis = _connector_basis(mount_slot, target_dir, twist_step)
		connector.set_meta("twist", twist_step)
		connector.set_meta("build_transform", connector.global_transform)
		_update_ui()
		_status("Selected connector rotated to %d°" % (twist_step * 45))
		return
	if occupied.is_empty():
		var normal := (connector.global_transform.basis * Vector3.UP).normalized()
		connector.global_transform.basis = Basis(normal, deg_to_rad(45.0)) * connector.global_transform.basis
		twist_step = (twist_step + 1) % 8
		connector.set_meta("twist", twist_step)
		connector.set_meta("build_transform", connector.global_transform)
		_update_ui()
		_status("Connector rotated 45°")
	else:
		_status("This connector is already structurally locked")

func _handle_tap(screen_pos: Vector2) -> void:
	if simulating or help_panel.visible:
		return
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0)
	query.collision_mask = 1
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
			var slot := _select_slot(body, hit["position"])
			if slot >= 0:
				_extend_socket(body, slot)
			else:
				_set_selected(body)
				_status("Connector selected")
		elif kind == "rod":
			var end_sign := _rod_end_hit(body, hit["position"])
			if end_sign != 0:
				_attach_connector_to_rod_end(body, end_sign)
			else:
				_set_selected(body)
				_status("Rod selected. Use Rod ◀/▶ to change length if one end is free.")
	elif attach_mode == 1:
		if kind == "connector":
			_insert_axle(body)
		else:
			_set_selected(body)
	elif attach_mode == 2:
		if kind == "rod":
			_cross_snap(body, hit["position"])
		else:
			_set_selected(body)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			touch_start[event.index] = event.position
			touch_moved[event.index] = false
			if touches.size() == 2:
				pinch_last = _pinch_distance()
		else:
			var moved := bool(touch_moved.get(event.index, false))
			var start: Vector2 = touch_start.get(event.index, event.position)
			touches.erase(event.index)
			touch_start.erase(event.index)
			touch_moved.erase(event.index)
			pinch_last = _pinch_distance() if touches.size() >= 2 else -1.0
			if not moved and start.distance_to(event.position) < 18.0:
				_handle_tap(event.position)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if event.relative.length() > 2.0:
			touch_moved[event.index] = true
		if touches.size() >= 2:
			var distance := _pinch_distance()
			if pinch_last > 0.0:
				camera_distance = clampf(camera_distance - (distance - pinch_last) * 0.025, 5.0, 46.0)
			pinch_last = distance
		else:
			camera_yaw -= event.relative.x * 0.006
			camera_pitch = clampf(camera_pitch - event.relative.y * 0.005, deg_to_rad(-72.0), deg_to_rad(58.0))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_down = true
			mouse_start = event.position
			mouse_moved = false
		else:
			if mouse_down and not mouse_moved and mouse_start.distance_to(event.position) < 10.0:
				_handle_tap(event.position)
			mouse_down = false
	elif event is InputEventMouseMotion and mouse_down:
		if event.relative.length() > 1.0:
			mouse_moved = true
			camera_yaw -= event.relative.x * 0.006
			camera_pitch = clampf(camera_pitch - event.relative.y * 0.005, deg_to_rad(-72.0), deg_to_rad(58.0))
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		camera_distance = clampf(camera_distance + (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 5.0, 46.0)

func _pinch_distance() -> float:
	var keys := touches.keys()
	if keys.size() < 2:
		return -1.0
	var first: Vector2 = touches[keys[0]]
	var second: Vector2 = touches[keys[1]]
	return first.distance_to(second)

func _update_camera() -> void:
	if camera == null:
		return
	var cp := cos(camera_pitch)
	var offset := Vector3(cos(camera_yaw) * cp, sin(camera_pitch), sin(camera_yaw) * cp) * camera_distance
	camera.global_position = camera_target + offset
	camera.look_at(camera_target, Vector3.UP)

func _prev_rod() -> void:
	_change_rod_type(-1)

func _next_rod() -> void:
	_change_rod_type(1)

func _prev_connector() -> void:
	_change_connector_type(-1)

func _next_connector() -> void:
	_change_connector_type(1)

func _cycle_mode() -> void:
	if simulating:
		return
	attach_mode = (attach_mode + 1) % 3
	_update_ui()
	_status(["SOCKET: socket → rod, rod end → connector", "AXLE: tap connector hub", "CROSS: tap rod body"][attach_mode])

func _cycle_twist() -> void:
	_rotate_selected_connector()

func _toggle_simulation() -> void:
	if simulating:
		_reset_pose()
		return
	simulating = true
	for body in bodies:
		if is_instance_valid(body):
			if bool(body.get_meta("seed", false)):
				body.freeze = true
			else:
				body.freeze = false
				body.sleeping = false
	_update_ui()
	_status("Physics running — tap BUILD to restore")

func _reset_pose() -> void:
	simulating = false
	for body in bodies:
		if not is_instance_valid(body):
			continue
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.global_transform = body.get_meta("build_transform")
	_update_ui()
	_status("Build pose restored")

func _undo() -> void:
	if simulating or history.is_empty():
		return
	var action: Dictionary = history.pop_back()
	if action.has("slots"):
		for pair in action["slots"]:
			if pair.size() >= 2 and is_instance_valid(pair[0]):
				_set_connector_occupied(pair[0], int(pair[1]), false)
	if action.has("rod_ends"):
		for pair in action["rod_ends"]:
			if pair.size() >= 2 and is_instance_valid(pair[0]):
				_set_rod_end_occupied(pair[0], int(pair[1]), false)
	if action.has("axle") and is_instance_valid(action["axle"]):
		action["axle"].set_meta("axle_occupied", false)
	var created: Array = action.get("created", [])
	for node in created:
		if is_instance_valid(node):
			if node is RigidBody3D:
				bodies.erase(node)
			if node is Joint3D:
				joints.erase(node)
			node.queue_free()
	selected_piece = null
	_update_ui()
	_status("Undid last connection")

func _update_ui() -> void:
	if rod_label != null:
		rod_label.text = str(rod_defs[selected_rod_type]["name"])
	if connector_label != null:
		connector_label.text = str(connector_defs[selected_connector_type]["name"])
	if mode_button != null:
		mode_button.text = ["SOCKET", "AXLE", "CROSS"][attach_mode]
	if twist_button != null:
		twist_button.text = "Rotate %d°" % (twist_step * 45)
	if simulate_button != null:
		simulate_button.text = "BUILD" if simulating else "SIMULATE"

func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION, text]
