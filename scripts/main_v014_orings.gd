extends "res://scripts/main_v014.gd"

const O_RING_RADIUS = 0.62
const O_RING_HEIGHT = 0.26

var o_ring_button: Button
var o_ring_armed: bool = false
var o_ring_stops: Array = []


func _ready() -> void:
	super._ready()
	_status("v0.1.4 ready — select pieces normally; use Place O-Ring Connector for axle stops")


func _build_ui() -> void:
	super._build_ui()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	o_ring_button = _make_ui_button("Place O-Ring Connector", _toggle_o_ring_placement)
	o_ring_button.anchor_left = 1.0
	o_ring_button.anchor_right = 1.0
	o_ring_button.anchor_top = 1.0
	o_ring_button.anchor_bottom = 1.0
	o_ring_button.offset_left = -280.0
	o_ring_button.offset_right = -10.0
	o_ring_button.offset_top = -286.0
	o_ring_button.offset_bottom = -232.0
	o_ring_button.custom_minimum_size = Vector2(270, 50)
	layer.add_child(o_ring_button)
	_update_o_ring_ui()


func _toggle_o_ring_placement() -> void:
	if simulating:
		return
	o_ring_armed = not o_ring_armed
	_update_o_ring_ui()
	if o_ring_armed:
		_status("O-Ring Connector armed — tap an AXLE rod where the stop should sit")
	else:
		_status("O-Ring Connector placement cancelled")


func _update_o_ring_ui() -> void:
	if o_ring_button == null:
		return
	o_ring_button.disabled = simulating
	o_ring_button.text = "O-RING: tap axle" if o_ring_armed else "Place O-Ring Connector"


func _rod_is_axle(rod: RigidBody3D) -> bool:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or not str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] == rod or nodes[1] == rod:
			return true
	return false


func _make_o_ring_body(transform: Transform3D) -> RigidBody3D:
	var ring: RigidBody3D = RigidBody3D.new()
	ring.name = "O_Ring_Stop_%d" % piece_counter
	piece_counter += 1
	_configure_piece_body(ring)
	ring.mass = 0.035
	ring.linear_damp = 0.20
	ring.angular_damp = 0.34
	ring.collision_layer = 4
	ring.collision_mask = 1 | 2 | 4
	add_child(ring)
	ring.global_transform = transform
	ring.set_meta("kind", "o_ring")

	var visual: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = O_RING_RADIUS
	torus.rings = 18
	torus.ring_segments = 12
	visual.mesh = torus
	visual.material_override = _mat(Color("353b42"))
	ring.add_child(visual)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = O_RING_RADIUS
	cylinder.height = O_RING_HEIGHT
	collision.shape = cylinder
	ring.add_child(collision)

	ring.set_meta("build_transform", ring.global_transform)
	o_ring_stops.append(ring)
	return ring


func _place_o_ring_on_rod(rod: RigidBody3D, hit_pos: Vector3) -> void:
	if not _rod_is_axle(rod):
		_status("O-Ring Connectors can only be placed on rods being used as axles")
		return

	var axis: Vector3 = rod.get_meta("axis")
	axis = axis.normalized()
	var half_len: float = maxf(0.10, float(rod.get_meta("visual_length")) * 0.5 - 0.45)
	var along: float = clampf((hit_pos - rod.global_position).dot(axis), -half_len, half_len)
	var center: Vector3 = rod.global_position + axis * along
	var basis: Basis = Basis(Quaternion(Vector3.UP, axis))
	var ring: RigidBody3D = _make_o_ring_body(Transform3D(basis, center))
	_make_fixed_joint(rod, ring, center)
	ring.set_meta("host_rod", rod)
	ring.set_meta("build_transform", ring.global_transform)
	o_ring_armed = false
	_set_selected(ring)
	_commit_state()
	_update_o_ring_ui()
	_status("O-Ring Connector placed — sliding axle connectors will physically stop at it")


func _handle_tap(screen_pos: Vector2) -> void:
	if simulating or help_panel.visible:
		return
	if o_ring_armed:
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
		if is_instance_valid(body) and str(body.get_meta("kind", "")) == "rod":
			_place_o_ring_on_rod(body, hit["position"])
		else:
			_status("O-Ring Connector armed — tap an axle rod")
		return

	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 800.0)
	query.collision_mask = 2 | 4
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_body: RigidBody3D = hit.get("collider") as RigidBody3D
		if is_instance_valid(hit_body) and str(hit_body.get_meta("kind", "")) == "o_ring":
			_set_selected(hit_body)
			_status("O-Ring Connector selected — Delete removes it")
			return

	super._handle_tap(screen_pos)


func _find_o_ring_host(ring: RigidBody3D) -> RigidBody3D:
	for joint_value in joints:
		var joint: Joint3D = joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes[0] != ring and nodes[1] != ring:
			continue
		var other: RigidBody3D = (nodes[1] if nodes[0] == ring else nodes[0]) as RigidBody3D
		if is_instance_valid(other) and str(other.get_meta("kind", "")) == "rod":
			return other
	return null


func _capture_state() -> Dictionary:
	var snapshot: Dictionary = super._capture_state()
	var ring_states: Array = []
	var selected_ring_index: int = -1
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		var host: RigidBody3D = _find_o_ring_host(ring)
		var host_index: int = bodies.find(host)
		if host_index < 0:
			continue
		if selected_piece == ring:
			selected_ring_index = ring_states.size()
		ring_states.append({
			"transform": ring.get_meta("build_transform", ring.global_transform),
			"host": host_index,
			"anchor": ring.global_position
		})
	snapshot["o_rings"] = ring_states
	snapshot["selected_o_ring"] = selected_ring_index
	return snapshot


func _clear_o_ring_bodies() -> void:
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.collision_layer = 0
			ring.collision_mask = 0
			ring.queue_free()
	o_ring_stops.clear()


func _restore_state(snapshot: Dictionary) -> void:
	_clear_o_ring_bodies()
	o_ring_armed = false
	super._restore_state(snapshot)
	var saved_rings: Array = snapshot.get("o_rings", []) as Array
	for ring_state_value in saved_rings:
		var ring_state: Dictionary = ring_state_value as Dictionary
		var host_index: int = int(ring_state.get("host", -1))
		if host_index < 0 or host_index >= bodies.size():
			continue
		var host: RigidBody3D = bodies[host_index] as RigidBody3D
		if not is_instance_valid(host):
			continue
		var transform: Transform3D = ring_state["transform"]
		var anchor: Vector3 = ring_state.get("anchor", transform.origin)
		var ring: RigidBody3D = _make_o_ring_body(transform)
		_make_fixed_joint(host, ring, anchor)
		ring.set_meta("host_rod", host)
		ring.set_meta("build_transform", transform)
	var selected_ring_index: int = int(snapshot.get("selected_o_ring", -1))
	if selected_ring_index >= 0 and selected_ring_index < o_ring_stops.size():
		_set_selected(o_ring_stops[selected_ring_index] as RigidBody3D)
	_update_o_ring_ui()


func _restart_build() -> void:
	_clear_o_ring_bodies()
	o_ring_armed = false
	super._restart_build()
	_update_o_ring_ui()


func _delete_selected() -> void:
	if is_instance_valid(selected_piece) and str(selected_piece.get_meta("kind", "")) == "o_ring":
		o_ring_stops.erase(selected_piece)
	super._delete_selected()
	_update_o_ring_ui()


func _release_physics() -> void:
	_prepare_stable_simulation_graph()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not simulating:
		return
	for body_value in bodies:
		var body: RigidBody3D = body_value as RigidBody3D
		if is_instance_valid(body):
			body.set_meta("seed", false)
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.freeze = false
			body.sleeping = false
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.linear_velocity = Vector3.ZERO
			ring.angular_velocity = Vector3.ZERO
			ring.freeze = false
			ring.sleeping = false
	_update_ui()
	_update_o_ring_ui()
	_status("Physics running — all pieces free; O-Ring axle stops active; %d redundant constraints suppressed" % simulation_disabled_joint_count)


func _reset_pose() -> void:
	super._reset_pose()
	for ring_value in o_ring_stops:
		var ring: RigidBody3D = ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.freeze = true
		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		ring.global_transform = ring.get_meta("build_transform", ring.global_transform)
	_update_o_ring_ui()


func _update_ui() -> void:
	super._update_ui()
	_update_o_ring_ui()
