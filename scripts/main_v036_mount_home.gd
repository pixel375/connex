extends "res://scripts/main_v036.gd"

const MOUNT_HOME_RELATIVE_BASIS_036 := "mount_home_relative_basis_v036"


# Store the connector's placement orientation in the host rod's frame exactly
# once, when the connection is first created. Graph rebuilds call this tagging
# function again, so the has_meta guard is essential: a Roll must not overwrite
# its own reset target.
func _tag_connection_v020(joint: Joint3D, kind: String, connector: RigidBody3D, rod: RigidBody3D, slot: int = -1, rod_end: int = 0, host_along: float = 0.0, ring: RigidBody3D = null, primary: bool = false) -> int:
	var uid: int = super._tag_connection_v020(joint, kind, connector, rod, slot, rod_end, host_along, ring, primary)
	if kind in ["socket", "cross", "axle"] and is_instance_valid(connector) and is_instance_valid(rod) and not joint.has_meta(MOUNT_HOME_RELATIVE_BASIS_036):
		var rod_basis: Basis = rod.global_transform.basis.orthonormalized()
		var connector_basis: Basis = connector.global_transform.basis.orthonormalized()
		joint.set_meta(MOUNT_HOME_RELATIVE_BASIS_036, (rod_basis.inverse() * connector_basis).orthonormalized())
	return uid


func _reset_preview_v020() -> Dictionary:
	if simulating or _selected_kind() != "connector" or not is_instance_valid(selected_piece):
		return {"valid": false, "reason": "select a connector"}
	_rebuild_connection_graph_v020()
	var connector: RigidBody3D = selected_piece
	var current: Transform3D = connector.global_transform
	var pivot: Dictionary = _primary_record_for_connector_v020(connector)
	if pivot.is_empty():
		return super._reset_preview_v020()
	var kind: String = str(pivot.get("kind", ""))
	if not (kind in ["socket", "cross", "axle"]):
		return super._reset_preview_v020()
	var joint: Joint3D = pivot.get("joint") as Joint3D
	var rod: RigidBody3D = pivot.get("rod") as RigidBody3D
	if not is_instance_valid(joint) or not is_instance_valid(rod) or not joint.has_meta(MOUNT_HOME_RELATIVE_BASIS_036):
		return super._reset_preview_v020()

	var excluded_uid: int = int(pivot.get("uid", -1)) if _fixed_connection_kind_v020(kind) else -1
	var component: Array = _fixed_component_v020(connector, excluded_uid)
	if excluded_uid >= 0:
		var pivot_other: RigidBody3D = _other_body_v020(pivot, connector)
		if _component_has_piece_v020(component, pivot_other):
			return {"valid": false, "reason": "this mount is part of a closed rigid loop"}

	var rod_basis: Basis = rod.global_transform.basis.orthonormalized()
	var relative_home: Basis = joint.get_meta(MOUNT_HOME_RELATIVE_BASIS_036) as Basis
	var target_basis: Basis = (rod_basis * relative_home).orthonormalized()
	var target_origin: Vector3 = current.origin

	if kind == "socket":
		var socket_slot: int = int(pivot.get("slot", -1))
		var socket_anchor: Vector3 = _record_anchor_v020(pivot)
		var socket_dir: Vector3 = (target_basis * _slot_dir(socket_slot)).normalized()
		target_origin = socket_anchor - socket_dir * CONNECTOR_D
	elif kind == "cross":
		var cross_slot: int = int(pivot.get("slot", -1))
		var cross_anchor: Vector3 = _record_anchor_v020(pivot)
		var cross_dir: Vector3 = (target_basis * _slot_dir(cross_slot)).normalized()
		target_origin = cross_anchor - cross_dir * CONNECTOR_D
	elif kind == "axle":
		var rod_axis: Vector3 = _rod_axis_v020(rod)
		var axial: float = (current.origin - rod.global_position).dot(rod_axis)
		target_origin = rod.global_position + rod_axis * axial

	var target: Transform3D = Transform3D(target_basis, target_origin)
	var transforms: Dictionary = _rigid_delta_map_v020(component, current, target)
	var validation: Dictionary = _validate_transforms_v020(transforms)
	if not bool(validation.get("valid", false)):
		return validation
	return {"valid": true, "transforms": transforms, "component": component, "pivot": pivot}
