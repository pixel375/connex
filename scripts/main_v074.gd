extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const COMPLEX_ORING_PHYSICS_TPS_V074 := 120

# Number of AXLE hubs participating in multi-hub segments on rods that contain
# at least one O-Ring. Kept under the old debug name for test compatibility.
var axle_ranked_stop_count_v074: int = 0
var o_ring_precision_ticks_active_v074: bool = false
var saved_physics_ticks_v074: int = -1

# Compatibility/debug surfaces for abandoned experiments. They stay empty.
var axle_stack_shape_state_v074: Array = []
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring simulation
#
# Keep the released v0.5.15 physical behavior and the v0.5.16 v073 ownership
# handoff intact:
#
# - O-Rings are collisionless exact rod-local followers;
# - the normal AXLE joint remains free in axial slide and rotation;
# - only the outermost hub in a segment owns each finite O-Ring/rod-end stop;
# - ordinary hub-to-hub collision gets first chance to preserve stacking;
# - if Jolt genuinely tunnels one hub through another, v073 changes ONLY stop
#   ownership metadata/ranges to the hub that is physically outermost now;
# - the handoff itself never changes a body transform or velocity; after the
#   handoff, the same proven v0.5.15 stop correction is applied to the new owner.
#
# Larger multi-hub O-Ring builds also run at 120 Hz while SIMULATE is active.
# This reduces one-step tunnelling distance without adding hidden joints,
# collision proxies, enlarged shapes, interior rank floors or velocity clamps.
# Ordinary simulations stay at the existing project tick rate, and BUILD restores
# the exact prior value.
# -----------------------------------------------------------------------------

func _find_stop_v074(rod: RigidBody3D, connector: RigidBody3D, segment: int) -> Dictionary:
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		if stop.get("rod") == rod and stop.get("connector") == connector and int(stop.get("segment", -999)) == segment:
			return stop
	return {}


func _count_complex_o_ring_hubs_v074() -> int:
	var count := 0
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var hubs: Array = group.get("hubs", []) as Array
		if hubs.size() <= 1:
			continue
		var rod := group.get("rod") as RigidBody3D
		var segment: int = int(group.get("segment", 0))
		if not is_instance_valid(rod):
			continue
		var has_ring := false
		for hub_value in hubs:
			var connector := (hub_value as Dictionary).get("connector") as RigidBody3D
			var stop: Dictionary = _find_stop_v074(rod, connector, segment)
			if not stop.is_empty() and int(stop.get("ring_count", 0)) > 0:
				has_ring = true
				break
		if has_ring:
			count += hubs.size()
	return count


func _enable_precision_ticks_v074() -> void:
	if axle_ranked_stop_count_v074 <= 0 or o_ring_precision_ticks_active_v074:
		return
	saved_physics_ticks_v074 = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = maxi(saved_physics_ticks_v074, COMPLEX_ORING_PHYSICS_TPS_V074)
	o_ring_precision_ticks_active_v074 = Engine.physics_ticks_per_second > saved_physics_ticks_v074


func _restore_precision_ticks_v074() -> void:
	if saved_physics_ticks_v074 > 0:
		Engine.physics_ticks_per_second = saved_physics_ticks_v074
	saved_physics_ticks_v074 = -1
	o_ring_precision_ticks_active_v074 = false


func _build_axle_stop_ranges_v070() -> void:
	# v073 builds the stable outer-owner ranges and zero-motion ownership groups.
	# Do not rewrite those ranges or disable the handoff. Only decide whether this
	# run benefits from finer temporal resolution.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()
	_enable_precision_ticks_v074()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_precision_ticks_v074()
	axle_ranked_stop_count_v074 = 0
	axle_stack_shape_state_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
