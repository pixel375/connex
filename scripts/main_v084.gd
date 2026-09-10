extends "res://scripts/main_v083.gd"

const VERSION_084 := "0.5.16"
const AXLE_MOUNT_FLEX_CAP_DEG_V084 := 3.0

var axle_mount_flex_capped_v084: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_084)
	_status("v0.5.16 candidate — low Structure Rigidity remains flexible while AXLE-mounted hub sockets use a bounded stability cap.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_084, text]


func _connector_has_axle_mount_v084(connector: RigidBody3D) -> bool:
	if not is_instance_valid(connector):
		return false
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) == "axle" and record.get("connector") == connector:
			return true
	return false


# Very loose SOCKET/CROSS angular limits directly on a connector that is itself
# sliding on an AXLE create a long lever around an under-constrained body. Jolt
# can pump that coupled angular motion into the free axle translation until two
# otherwise-colliding hubs snap through one another. 50% rigidity (~2.9 deg)
# remains stable; the failure begins only in the much looser range.
#
# Keep the user's requested global flex everywhere else. Only the immediate
# SOCKET/CROSS mounts on an AXLE connector are capped to +/-3 deg. This preserves
# the free AXLE Y slide/rotation and does not add a constraint, collision proxy,
# solver priority or hidden joint. At 50..100% this changes nothing at all.
func _apply_structure_flex_all_v072() -> int:
	var global_flex: float = _structure_flex_angle_rad_v066()
	var high_end: bool = physics_structure_rigidity_v066 >= STRUCTURE_FLEX_RIGID_THRESHOLD_V073
	var cycle_relief: float = _cycle_solver_relief_rad_v073()
	var axle_cap: float = deg_to_rad(AXLE_MOUNT_FLEX_CAP_DEG_V084)
	var count := 0
	axle_mount_flex_capped_v084 = 0
	_rebuild_connection_graph_v020(false)

	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) not in ["socket", "cross"]:
			continue
		var joint := record.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			continue
		var is_cycle: bool = bool(joint.get_meta("sim_soft_socket_cycle_v064", false))
		var applied_flex: float = cycle_relief if high_end and is_cycle else global_flex
		var connector := record.get("connector") as RigidBody3D
		if not high_end and _connector_has_axle_mount_v084(connector) and applied_flex > axle_cap:
			applied_flex = axle_cap
			axle_mount_flex_capped_v084 += 1
			joint.set_meta("sim_axle_mount_flex_cap_v084", true)
		else:
			joint.remove_meta("sim_axle_mount_flex_cap_v084")

		var prior_flex: float = float(joint.get_meta("sim_structure_flex_rad_v066", 0.0))
		var must_write: bool = not high_end or is_cycle or absf(prior_flex) > 0.000001
		if must_write:
			for axis_name in ["x", "y", "z"]:
				joint.set("angular_limit_%s/enabled" % axis_name, true)
				joint.set("angular_limit_%s/lower_angle" % axis_name, -applied_flex)
				joint.set("angular_limit_%s/upper_angle" % axis_name, applied_flex)
		joint.set_meta("sim_rigidity_all_v072", true)
		joint.set_meta("sim_structure_rigidity_v066", physics_structure_rigidity_v066)
		joint.set_meta("sim_structure_flex_rad_v066", applied_flex)
		joint.set_meta("sim_cycle_relief_v073", high_end and is_cycle)
		count += 1
	return count


func _restore_structure_flex_all_v072() -> void:
	axle_mount_flex_capped_v084 = 0
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if is_instance_valid(joint):
			joint.remove_meta("sim_axle_mount_flex_cap_v084")
	super._restore_structure_flex_all_v072()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — Structure Rigidity %d%%; AXLE-mounted socket flex is capped at +/-%.1f deg only when needed for solver stability." % [int(round(active_structure_rigidity_v067)), AXLE_MOUNT_FLEX_CAP_DEG_V084])
