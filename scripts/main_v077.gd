extends "res://scripts/main_v076.gd"

const VERSION_077 := "0.5.16"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_077)
	_status("v0.5.16 test runtime — direct-state AXLE stacking keeps fixed-component joint frames aligned.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_077, text]


# v0.5.15 already established an important invariant: if a whole fixed component
# is translated, every internal fixed-joint frame must move by exactly the same
# world-space delta. Otherwise Jolt sees stale anchors on the next solve and can
# manufacture a large restoring impulse. v076 moved the bodies through direct
# state but forgot those Joint3D frames.
func _shift_component_joint_frames_v077(component: Array, delta: Vector3) -> void:
	if delta.length_squared() <= 0.0000000001:
		return
	var ids: Dictionary = _component_ids_v076(component)
	if ids.is_empty():
		return
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		if joint.node_a.is_empty() or joint.node_b.is_empty():
			continue
		var nodes: Array = _joint_nodes(joint)
		var a := nodes[0] as RigidBody3D
		var b := nodes[1] as RigidBody3D
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if ids.has(a.get_instance_id()) and ids.has(b.get_instance_id()):
			var joint_tf: Transform3D = joint.global_transform
			joint_tf.origin += delta
			joint.global_transform = joint_tf


func _add_component_command_v076(component: Array, shift: Vector3, delta_velocity: Vector3) -> void:
	# Queue the same body-state correction as v076, then keep all internal fixed
	# constraint frames coincident with that pending translation. AXLE joints are
	# intentionally excluded: their free rod-axis degree of freedom is unchanged.
	super._add_component_command_v076(component, shift, delta_velocity)
	_shift_component_joint_frames_v077(component, shift)


func _prepare_component_groups_v076() -> int:
	var count: int = super._prepare_component_groups_v076()

	# Do not depend on the duplicated bounds stored on axle_order_groups_v073.
	# Re-source each protected stack directly from the first/last released
	# axle_stop_ranges_v070 records. Those records are authoritative for physical
	# rod ends and O-Ring clearance (ring coordinate +/- O_RING_AXLE_CLEARANCE).
	for group_value in axle_component_groups_v076:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		var hubs: Array = group.get("hubs", []) as Array
		var segment: int = int(group.get("segment", 0))
		if not is_instance_valid(rod) or hubs.is_empty():
			continue
		var first_connector := (hubs[0] as Dictionary).get("connector") as RigidBody3D
		var last_connector := (hubs[hubs.size() - 1] as Dictionary).get("connector") as RigidBody3D
		var first_stop: Dictionary = _find_stop_v074(rod, first_connector, segment)
		var last_stop: Dictionary = _find_stop_v074(rod, last_connector, segment)
		if not first_stop.is_empty():
			group["lower"] = float(first_stop.get("lower", group.get("lower", -INF)))
		if not last_stop.is_empty():
			group["upper"] = float(last_stop.get("upper", group.get("upper", INF)))

	return count


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d protected AXLE hub%s use direct-state stacking with aligned fixed-joint frames; normal AXLE joints remain free." % [
		axle_ranked_stop_count_v074,
		"" if axle_ranked_stop_count_v074 == 1 else "s"
	])
