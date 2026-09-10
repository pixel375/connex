extends "res://scripts/main_v074.gd"

const VERSION_075 := "0.5.16"
const AXLE_RANK_MIN_SEPARATION_V075 := AXLE_CONNECTOR_HALF_V070 * 2.0 + 0.08
const AXLE_RANK_LIMIT_PRIORITY_V075 := 16
const AXLE_RANK_EPS_V075 := 0.001

var axle_native_rank_limit_count_v075: int = 0
var axle_native_rank_invalid_groups_v075: int = 0
var axle_native_rank_restore_v075: Array = []


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_075)
	_status("v0.5.16 test runtime — multi-hub axle order is guarded inside each existing AXLE joint.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_075, text]


# v074 proved CCD cannot prevent an order reversal manufactured inside the same
# Jolt solve. Do not add another special CCD layer here. main_v068's normal
# simulation CCD policy remains untouched for construction bodies.
func _enable_axle_ccd_v074() -> int:
	return 0


func _axle_joint_for_rank_v075(rod: RigidBody3D, connector: RigidBody3D, uid: int) -> Generic6DOFJoint3D:
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		if int(record.get("uid", -1)) == uid or (record.get("rod") == rod and record.get("connector") == connector):
			var joint := record.get("joint") as Generic6DOFJoint3D
			if is_instance_valid(joint):
				return joint
	return null


func _save_native_rank_joint_v075(joint: Generic6DOFJoint3D) -> void:
	if not is_instance_valid(joint):
		return
	for value in axle_native_rank_restore_v075:
		if (value as Dictionary).get("joint") == joint:
			return
	axle_native_rank_restore_v075.append({
		"joint": joint,
		"enabled": bool(joint.get("linear_limit_y/enabled")),
		"lower": float(joint.get("linear_limit_y/lower_distance")),
		"upper": float(joint.get("linear_limit_y/upper_distance")),
		"softness": float(joint.get("linear_limit_y/softness")),
		"restitution": float(joint.get("linear_limit_y/restitution")),
		"damping": float(joint.get("linear_limit_y/damping")),
		"solver_priority": int(joint.solver_priority),
	})


func _restore_native_rank_limits_v075(rebind: bool = true) -> void:
	var restored := false
	for value in axle_native_rank_restore_v075:
		var state := value as Dictionary
		var joint := state.get("joint") as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			continue
		joint.set("linear_limit_y/enabled", bool(state.get("enabled", false)))
		joint.set("linear_limit_y/lower_distance", float(state.get("lower", 0.0)))
		joint.set("linear_limit_y/upper_distance", float(state.get("upper", 0.0)))
		joint.set("linear_limit_y/softness", float(state.get("softness", 0.7)))
		joint.set("linear_limit_y/restitution", float(state.get("restitution", 0.5)))
		joint.set("linear_limit_y/damping", float(state.get("damping", 1.0)))
		joint.solver_priority = int(state.get("solver_priority", 1))
		joint.remove_meta("sim_native_rank_limit_v075")
		joint.remove_meta("sim_native_rank_lower_v075")
		joint.remove_meta("sim_native_rank_upper_v075")
		restored = true
	axle_native_rank_restore_v075.clear()
	axle_native_rank_limit_count_v075 = 0
	axle_native_rank_invalid_groups_v075 = 0
	if restored and rebind:
		_rebind_all_joints()


func _apply_native_rank_limits_v075() -> int:
	# If this topology is rebuilt twice during one preflight, restore the true
	# BUILD joint state before deriving another set of limits.
	_restore_native_rank_limits_v075(false)
	var applied := 0
	var invalid_groups := 0

	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		var hubs: Array = group.get("hubs", []) as Array
		if not is_instance_valid(rod) or hubs.size() <= 1 or not _group_has_o_ring_v074(group):
			continue

		var positions: Array[float] = []
		var valid_group := true
		for hub_value in hubs:
			var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
			if not is_instance_valid(connector):
				valid_group = false
				break
			positions.append(_rod_local_along_v070(connector, rod))
		if not valid_group:
			invalid_groups += 1
			continue

		# A ranked native interval must contain the BUILD pose. If a BUILD already
		# overlaps adjacent hub centers more deeply than the intended physical
		# separation, leave that group on the released fallback instead of asking
		# Jolt to solve an impossible interval by teleporting it.
		for i in range(positions.size() - 1):
			if positions[i + 1] - positions[i] < AXLE_RANK_MIN_SEPARATION_V075 - AXLE_RANK_EPS_V075:
				valid_group = false
				break
		if not valid_group:
			invalid_groups += 1
			continue

		var group_lower: float = float(group.get("lower", -INF))
		var group_upper: float = float(group.get("upper", INF))
		for i in range(hubs.size()):
			var hub := hubs[i] as Dictionary
			var connector := hub.get("connector") as RigidBody3D
			var uid := int(hub.get("uid", -1))
			var joint := _axle_joint_for_rank_v075(rod, connector, uid)
			if not is_instance_valid(joint):
				continue

			var initial: float = positions[i]
			var rank_lower: float = group_lower
			var rank_upper: float = group_upper
			if i > 0:
				var lower_mid: float = (positions[i - 1] + positions[i]) * 0.5
				rank_lower = lower_mid + AXLE_RANK_MIN_SEPARATION_V075 * 0.5
			if i < hubs.size() - 1:
				var upper_mid: float = (positions[i] + positions[i + 1]) * 0.5
				rank_upper = upper_mid - AXLE_RANK_MIN_SEPARATION_V075 * 0.5

			# Keep the BUILD pose inside the native interval. This should already be
			# true after the separation validation above; the clamp only absorbs float
			# noise at exact contact.
			rank_lower = minf(rank_lower, initial)
			rank_upper = maxf(rank_upper, initial)
			if rank_lower > rank_upper + AXLE_RANK_EPS_V075:
				continue

			var connector_lower_rel: float = rank_lower - initial
			var connector_upper_rel: float = rank_upper - initial
			# _make_axle_joint binds A=connector, B=rod. Generic6DOF linear Y is B
			# relative to A, so connector-relative [Cmin,Cmax] maps to [-Cmax,-Cmin].
			var joint_lower: float = -connector_upper_rel
			var joint_upper: float = -connector_lower_rel

			_save_native_rank_joint_v075(joint)
			joint.set("linear_limit_y/lower_distance", joint_lower)
			joint.set("linear_limit_y/upper_distance", joint_upper)
			joint.set("linear_limit_y/restitution", 0.0)
			joint.set("linear_limit_y/damping", 1.0)
			joint.set("linear_limit_y/enabled", true)
			joint.solver_priority = maxi(joint.solver_priority, AXLE_RANK_LIMIT_PRIORITY_V075)
			joint.set_meta("sim_native_rank_limit_v075", true)
			joint.set_meta("sim_native_rank_lower_v075", rank_lower)
			joint.set_meta("sim_native_rank_upper_v075", rank_upper)
			applied += 1

	axle_native_rank_limit_count_v075 = applied
	axle_native_rank_invalid_groups_v075 = invalid_groups
	if applied > 0:
		# Toggling a Generic6DOF limit after creation did not reliably rebuild the
		# native Jolt mode in the old v0.5.14 experiment. Rebind exactly once after
		# every ranked interval is configured.
		_rebind_all_joints()
	return applied


func _build_axle_stop_ranges_v070() -> void:
	# v074 -> v073 builds the released outer-owner O-Ring ranges and immutable
	# BUILD order. v075 adds only per-rank native Y intervals for multi-hub
	# O-Ring segments; ordinary single-hub/no-ring AXLE joints stay fully free.
	super._build_axle_stop_ranges_v070()
	_apply_native_rank_limits_v075()


func _prepare_stable_simulation_graph() -> void:
	_restore_native_rank_limits_v075(false)
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_native_rank_limits_v075(false)
	super._restore_o_ring_followers_v068(restore_build_pose)


func _reset_pose() -> void:
	_restore_native_rank_limits_v075(false)
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_restore_native_rank_limits_v075(false)
	super._restore_state(snapshot)


func _restart_build() -> void:
	_restore_native_rank_limits_v075(false)
	super._restart_build()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d multi-hub AXLE rank%s guarded by native rod-axis limits; O-Rings remain collisionless followers." % [
		axle_native_rank_limit_count_v075,
		"" if axle_native_rank_limit_count_v075 == 1 else "s"
	])
