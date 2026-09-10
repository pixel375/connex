extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"

# v0.5.16 O-Ring durability state. Multi-hub O-Ring segments keep the released
# v0.5.15 stop topology; only their AXLE connector hubs opt into Godot/Jolt CCD
# while SIMULATE is active.
var axle_ranked_stop_count_v074: int = 0
var axle_ccd_enabled_count_v074: int = 0
var axle_ccd_state_v074: Array = []

# Compatibility/debug surfaces retained for the follow-up test while abandoned
# experiments remain deliberately inactive.
var axle_pair_guard_events_v074: int = 0
var axle_pair_projection_events_v074: int = 0
var axle_pair_collision_exception_count_v074: int = 0
var o_ring_precision_ticks_active_v074: bool = false
var saved_physics_ticks_v074: int = -1
var axle_order_repair_events_v074: int = 0
var axle_stack_shape_state_v074: Array = []
var axle_pair_stop_joints_v074: Array = []
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring simulation
#
# Preserve the released v0.5.15 behavior:
# - O-Rings are collisionless exact rod-local followers;
# - normal AXLE joints keep free axial slide and axle rotation;
# - only the BUILD-order outer hubs own finite O-Ring / rod-end boundaries;
# - interior hubs stack through their normal connector collision;
# - the host rod is never translated by an O-Ring stop;
# - no extra joint, collision shape, rank floor, tick-rate change, or scripted
#   hub-to-hub transform correction is introduced.
#
# The follow-up failure is high-speed connector-through-connector tunnelling.
# Godot exposes Continuous CD specifically for fast RigidBody impacts that can be
# missed by discrete collision detection. Enable it only for AXLE connector hubs
# in multi-hub segments that contain at least one O-Ring, and restore each hub's
# original CCD state when returning to BUILD. Ordinary connector collision then
# remains the single source of hub stacking/contact response.
# -----------------------------------------------------------------------------

func _find_stop_v074(rod: RigidBody3D, connector: RigidBody3D, segment: int) -> Dictionary:
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		if stop.get("rod") == rod and stop.get("connector") == connector and int(stop.get("segment", -999)) == segment:
			return stop
	return {}


func _group_has_o_ring_v074(group: Dictionary) -> bool:
	var rod := group.get("rod") as RigidBody3D
	var segment: int = int(group.get("segment", 0))
	if not is_instance_valid(rod):
		return false
	for hub_value in group.get("hubs", []) as Array:
		var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
		var stop: Dictionary = _find_stop_v074(rod, connector, segment)
		if not stop.is_empty() and int(stop.get("ring_count", 0)) > 0:
			return true
	return false


func _count_complex_o_ring_hubs_v074() -> int:
	var count := 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var hubs: Array = group.get("hubs", []) as Array
		if hubs.size() > 1 and _group_has_o_ring_v074(group):
			count += hubs.size()
	return count


func _enable_axle_ccd_v074() -> int:
	var saved_ids: Dictionary = {}
	for value in axle_ccd_state_v074:
		var entry := value as Dictionary
		var body := entry.get("body") as RigidBody3D
		if is_instance_valid(body):
			saved_ids[body.get_instance_id()] = true

	var count := 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var hubs: Array = group.get("hubs", []) as Array
		if hubs.size() <= 1 or not _group_has_o_ring_v074(group):
			continue
		for hub_value in hubs:
			var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
			if not is_instance_valid(connector):
				continue
			var id := connector.get_instance_id()
			if not saved_ids.has(id):
				axle_ccd_state_v074.append({
					"body": connector,
					"continuous_cd": connector.continuous_cd,
				})
				saved_ids[id] = true
			connector.continuous_cd = true
			count += 1
	return count


func _restore_axle_ccd_v074() -> void:
	for value in axle_ccd_state_v074:
		var entry := value as Dictionary
		var body := entry.get("body") as RigidBody3D
		if is_instance_valid(body):
			body.continuous_cd = bool(entry.get("continuous_cd", false))
	axle_ccd_state_v074.clear()
	axle_ccd_enabled_count_v074 = 0


func _build_axle_stop_ranges_v070() -> void:
	# v073 constructs the same outer-owner ranges as v0.5.15 plus immutable BUILD
	# hub order. CCD changes detection quality only; it does not change topology.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()
	axle_ccd_enabled_count_v074 = _enable_axle_ccd_v074()


# Do not add a second scripted hub-contact solver. CCD + ordinary collision gets
# the complete responsibility for interior hub stacking.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


# A tunnel remains a regression failure. Never redefine it as a valid order by
# handing the finite O-Ring boundary to whichever hub happened to pass through.
func _correct_axle_order_v073() -> bool:
	return false


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return
	# Exact v0.5.15 finite O-Ring / rod-end residual correction. Interior hub
	# contact is left entirely to Jolt with CCD enabled on the relevant hubs.
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		var connector := stop.get("connector") as RigidBody3D
		var rod := stop.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		var along: float = _rod_local_along_v070(connector, rod)
		var lower: float = float(stop.get("lower", -INF))
		var upper: float = float(stop.get("upper", INF))
		if lower > -INF and along < lower - AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (lower - along))
			var lower_speed: float = _relative_axial_speed_v071(stop)
			if lower_speed < 0.0:
				_shift_component_velocity_v071(stop, axis * -lower_speed)
		elif upper < INF and along > upper + AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (upper - along))
			var upper_speed: float = _relative_axial_speed_v071(stop)
			if upper_speed > 0.0:
				_shift_component_velocity_v071(stop, axis * -upper_speed)


func _prepare_stable_simulation_graph() -> void:
	# Defensive restoration makes repeated SIMULATE preparation idempotent even if
	# a previous attempt ended before the normal BUILD restoration path.
	_restore_axle_ccd_v074()
	axle_ranked_stop_count_v074 = 0
	axle_pair_guard_events_v074 = 0
	axle_pair_projection_events_v074 = 0
	axle_pair_collision_exception_count_v074 = 0
	axle_order_repair_events_v074 = 0
	o_ring_precision_ticks_active_v074 = false
	saved_physics_ticks_v074 = -1
	axle_stack_shape_state_v074.clear()
	axle_pair_stop_joints_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_axle_ccd_v074()
	axle_ranked_stop_count_v074 = 0
	axle_pair_guard_events_v074 = 0
	axle_pair_projection_events_v074 = 0
	axle_pair_collision_exception_count_v074 = 0
	axle_order_repair_events_v074 = 0
	axle_stack_shape_state_v074.clear()
	axle_pair_stop_joints_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
