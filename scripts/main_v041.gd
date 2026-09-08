extends "res://scripts/main_v040.gd"

const VERSION_041 := "0.3.11"
const TOP_ARC_SLOTS_041 := [1001, 1002, 1003]
const BOTTOM_ARC_SLOTS_041 := [2001, 2002, 2003]


func _ready() -> void:
	# Add the new spatial connectors before v0.1.5 appends O-Ring Stop, so the
	# inherited O-Ring index remains the final connector-list entry.
	if not _has_connector_named_v041("11-point 3D"):
		connector_defs.append({
			"name": "11-point 3D",
			"slots": [0, 45, 90, 135, 180, 225, 270, 315, 1001, 1002, 1003],
			"color": Color("d7edf7"),
			"mass": 0.42,
			"spatial_3d": true,
			"arc_top": true,
			"arc_bottom": false
		})
	if not _has_connector_named_v041("14-point 3D"):
		connector_defs.append({
			"name": "14-point 3D",
			"slots": [0, 45, 90, 135, 180, 225, 270, 315, 1001, 1002, 1003, 2001, 2002, 2003],
			"color": Color("ded8f4"),
			"mass": 0.54,
			"spatial_3d": true,
			"arc_top": true,
			"arc_bottom": true
		})

	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_041)
	_status("Added 11-point and 14-point 3D connectors. Their top/bottom arc sockets are real functional SOCKET ports, not decorative geometry.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_041, text]


func _has_connector_named_v041(name_value: String) -> bool:
	for def_value in connector_defs:
		var definition: Dictionary = def_value as Dictionary
		if str(definition.get("name", "")) == name_value:
			return true
	return false


# -----------------------------------------------------------------------------
# Spatial socket geometry
#
# Existing connectors use integer degrees in the connector's flat X/Z plane.
# The new pieces retain those eight IDs and add reserved integer IDs for sockets
# in the perpendicular X/Y plane. Keeping integer port IDs means the existing
# occupancy, history, Undo/Redo, attachment graph and reseat logic can continue
# to store a socket as one stable integer.
# -----------------------------------------------------------------------------

func _slot_dir(slot: int) -> Vector3:
	match slot:
		1001:
			return Vector3(1.0, 1.0, 0.0).normalized()
		1002:
			return Vector3.UP
		1003:
			return Vector3(-1.0, 1.0, 0.0).normalized()
		2001:
			return Vector3(1.0, -1.0, 0.0).normalized()
		2002:
			return Vector3.DOWN
		2003:
			return Vector3(-1.0, -1.0, 0.0).normalized()
	return super._slot_dir(slot)


func _is_spatial_slot_v041(slot: int) -> bool:
	return slot in TOP_ARC_SLOTS_041 or slot in BOTTOM_ARC_SLOTS_041


func _spatial_socket_basis_v041(direction_value: Vector3) -> Basis:
	var x_axis: Vector3 = direction_value.normalized()
	# The arc lives in local X/Y, so local Y is its thickness/normal axis (Z).
	var y_axis: Vector3 = Vector3.BACK
	if absf(x_axis.dot(y_axis)) > 0.98:
		y_axis = Vector3.UP
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _add_spatial_socket_visual_v041(parent: Node3D, slot: int, color: Color) -> void:
	var direction: Vector3 = _slot_dir(slot)
	var root: Node3D = Node3D.new()
	root.name = "SpatialSocket_%d" % slot
	root.basis = _spatial_socket_basis_v041(direction)
	parent.add_child(root)

	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.055))
	# Same jaw proportions as the ordinary planar sockets, expressed in the
	# socket's local frame so the whole assembly can point out of the flat plane.
	_add_box_visual(root, Vector3(0.66, 0.28, 0.34), Vector3(0.77, 0.0, 0.0), 0.0, main_mat)
	for side in [-1.0, 1.0]:
		var sidef: float = float(side)
		_add_box_visual(root, Vector3(0.78, 0.34, 0.14), Vector3(1.10, 0.0, 0.235 * sidef), 0.0, main_mat)
		_add_cylinder_visual(root, 0.12, 0.34, Vector3(1.47, 0.0, 0.235 * sidef), edge_mat, 10)
	_add_box_visual(root, Vector3(0.14, 0.36, 0.56), Vector3(1.33, 0.0, 0.0), 0.0, edge_mat)


func _add_segment_box_v041(parent: Node3D, a: Vector3, b: Vector3, thickness: float, material: Material) -> void:
	var delta: Vector3 = b - a
	var length: float = delta.length()
	if length < 0.001:
		return
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(length, thickness, thickness)
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	var x_axis: Vector3 = delta / length
	var y_axis: Vector3 = Vector3.BACK
	if absf(x_axis.dot(y_axis)) > 0.98:
		y_axis = Vector3.UP
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	mesh_instance.basis = Basis(x_axis, y_axis, z_axis).orthonormalized()
	mesh_instance.position = (a + b) * 0.5
	parent.add_child(mesh_instance)


func _add_arc_bridge_v041(parent: Node3D, slots: Array, color: Color) -> void:
	var bridge_mat: Material = _mat(color.darkened(0.035))
	var arc_points: Array = []
	for slot_value in slots:
		arc_points.append(_slot_dir(int(slot_value)) * 0.86)
	for i in range(arc_points.size() - 1):
		var a: Vector3 = arc_points[i]
		var b: Vector3 = arc_points[i + 1]
		_add_segment_box_v041(parent, a, b, 0.19, bridge_mat)


func _add_spatial_collision_v041(body: RigidBody3D, slot: int) -> void:
	var direction: Vector3 = _slot_dir(slot)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.02, 0.48, 0.66)
	collision.shape = shape
	collision.transform = Transform3D(_spatial_socket_basis_v041(direction), direction * 1.03)
	body.add_child(collision)


func _clear_spatial_socket_roots_v041(body: RigidBody3D) -> void:
	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child != null and str(child.name).begins_with("SpatialSocket_"):
			child.queue_free()


func _rebuild_connector(body: RigidBody3D, def_index: int) -> void:
	if def_index < 0 or def_index >= connector_defs.size() or def_index == o_ring_index:
		return
	var definition: Dictionary = connector_defs[def_index] as Dictionary
	if not bool(definition.get("spatial_3d", false)):
		# Inherited planar rebuilds only remove direct Mesh/Collision children; clear
		# our nested socket roots first when converting 11/14-point -> planar.
		_clear_spatial_socket_roots_v041(body)
		super._rebuild_connector(body, def_index)
		return

	for child_value in body.get_children():
		var child: Node = child_value as Node
		if child is MeshInstance3D or child is CollisionShape3D or str(child.name).begins_with("SpatialSocket_"):
			child.queue_free()
	body.mass = float(definition["mass"])
	body.set_meta("connector_type", def_index)
	var color: Color = definition["color"]
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.06))

	# Standard open hub/collar, shared with the existing flat connectors.
	var hub: MeshInstance3D = MeshInstance3D.new()
	var hub_mesh: TorusMesh = TorusMesh.new()
	hub_mesh.inner_radius = 0.30
	hub_mesh.outer_radius = 0.61
	hub_mesh.rings = 20
	hub_mesh.ring_segments = 12
	hub.mesh = hub_mesh
	hub.material_override = main_mat
	body.add_child(hub)

	var collar: MeshInstance3D = MeshInstance3D.new()
	var collar_mesh: TorusMesh = TorusMesh.new()
	collar_mesh.inner_radius = 0.285
	collar_mesh.outer_radius = 0.43
	collar_mesh.rings = 16
	collar_mesh.ring_segments = 10
	collar.mesh = collar_mesh
	collar.scale.y = 0.72
	collar.material_override = edge_mat
	body.add_child(collar)

	for slot_value in definition["slots"]:
		var slot: int = int(slot_value)
		if _is_spatial_slot_v041(slot):
			_add_spatial_socket_visual_v041(body, slot, color)
		else:
			super._add_real_socket_visual(body, slot, color)

	if bool(definition.get("arc_top", false)):
		_add_arc_bridge_v041(body, TOP_ARC_SLOTS_041, color)
	if bool(definition.get("arc_bottom", false)):
		_add_arc_bridge_v041(body, BOTTOM_ARC_SLOTS_041, color)

	# Existing central collision plus extra collision volumes for the out-of-plane
	# sockets so simulation/contact is not visually disconnected from the mesh.
	var central_collision: CollisionShape3D = CollisionShape3D.new()
	var central_shape: CylinderShape3D = CylinderShape3D.new()
	central_shape.radius = 1.46
	central_shape.height = 0.52
	central_collision.shape = central_shape
	body.add_child(central_collision)
	for slot_value in definition["slots"]:
		var slot: int = int(slot_value)
		if _is_spatial_slot_v041(slot):
			_add_spatial_collision_v041(body, slot)


# -----------------------------------------------------------------------------
# Help / updater version awareness
# -----------------------------------------------------------------------------

func _update_help_text_v030() -> void:
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label == null:
		return
	label.text = "CONNEX LAB v%s\n\nNEW 3D CONNECTORS: 11-point 3D = the normal 8-way flat connector plus a three-socket arc over the top (45° up, straight up, 45° up on the other side). 14-point 3D adds the mirrored three-socket arc underneath. All 11/14 points are real SOCKET ports and participate in occupancy, ATTACH, Undo/Redo, rotation and physics.\n\nO-RING STOP: O-Ring is in Conn, has a tighter center hole, and can be placed on ANY existing rod. O-Ring placement always uses axle-style semantics regardless of SOCKET / AXLE / CROSS.\n\nROTATE: X/Y/Z is the fixed-world 45° gizmo over the entire connected island; Roll remains mount-relative.\n\nATTACH: SOCKET uses rod ends ↔ any connector socket, including the new out-of-plane arc ports. AXLE uses hubs/O-Rings ↔ rod shaft. CROSS uses connector sockets ↔ rod shaft.\n\nCamera: one finger orbit, two fingers pan/zoom." % VERSION_041


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
	if _compare_versions_v021(latest, VERSION_041) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		apk_expected_sha256_v033 = ""
		apk_ready_v033 = false
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_041)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
	else:
		_set_update_status_v021("Update available: v%s → v%s" % [VERSION_041, latest])
