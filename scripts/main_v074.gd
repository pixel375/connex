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
# Keep the released v0.5.15 O-Ring stop behavior exactly: only the physically
# outer AXLE hub at each O-Ring/rod-end boundary owns that stop, interior hubs
# stack through ordinary connector collision, and O-Rings themselves are
# collisionless exact rod-local followers. The normal AXLE joint remains free in
# Y translation/rotation and is never replaced or limited.
#
# Larger builds exposed a temporal-resolution problem: at 60 Hz an interior hub
# can occasionally tunnel through the outer hub in one Jolt integration step.
# Earlier attempts to add rank limits, ownership swaps, extra constraints or
# collision proxies either injected energy or still tunnelled. v0.5.16 instead
# leaves the proven mechanics alone and raises physics resolution to 120 Hz ONLY
# while a rod with an O-Ring has more than one AXLE hub in the same segment.
# This halves per-step travel and gives existing CCD/contact + v0.5.15 prediction
# a second opportunity to resolve the stack. Ordinary simulations stay at the
# project-default tick rate and BUILD restores the previous rate exactly.
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
	# main_v073 builds the v0.5.15 outer-owner ranges plus segment metadata. Do
	# not rewrite those ranges. Only decide whether this run needs finer temporal
	# resolution for multi-hub O-Ring contact.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()
	_enable_precision_ticks_v074()


# Disable all abandoned ownership/order interventions from main_v073. The
# v0.5.15 predictor/corrector remains authoritative for the outer stop owners.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_precision_ticks_v074()
	axle_ranked_stop_count_v074 = 0
	axle_stack_shape_state_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
