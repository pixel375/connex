extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const O_RING_SIM_COLLIDER_HEIGHT_V074 := 0.50

# Compatibility/debug surfaces retained for the v0.5.16 regression suite.
var axle_ranked_stop_count_v074: int = 0
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Physical O-Ring stop model
#
# Keep the released v0.5.15 AXLE joint completely untouched. During SIMULATE an
# O-Ring is still an exact rod-local frozen/kinematic follower, but it now gains
# one invisible, slightly thicker collision collar on the connector-only layer.
# The visible ring remains the original 0.20-high part. The 0.50-high simulation
# collar deliberately makes contact early enough to absorb Jolt contact slop in
# loaded constructions without any script-side connector teleport or extra AXLE
# constraint. Rods never receive the connector-only layer, so the host axle
# cannot collide with its own O-Ring.
#
# Script-side v0.5.15 bounds remain active only for physical rod ends. Ring-side
# bounds are removed from axle_stop_ranges_v070 because collision owns those
# boundaries; this prevents collision and deterministic correction from fighting
# each other in the same frame.
# -----------------------------------------------------------------------------

func _remove_o_ring_sim_colliders_v074() -> void:
	for value in o_ring_sim_colliders_v074:
		var collider := value as CollisionShape3D
		if is_instance_valid(collider):
			collider.queue_free()
	o_ring_sim_colliders_v074.clear()


func _add_o_ring_sim_collider_v074(ring: RigidBody3D) -> void:
	if not is_instance_valid(ring):
		return
	var collider := CollisionShape3D.new()
	collider.name = "O_Ring_Sim_Collar_V074"
	collider.set_meta("sim_o_ring_collar_v074", true)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = O_RING_OUTER_RADIUS
	cylinder.height = O_RING_SIM_COLLIDER_HEIGHT_V074
	collider.shape = cylinder
	ring.add_child(collider)
	o_ring_sim_colliders_v074.append(collider)


func _prepare_o_ring_followers_v068() -> int:
	_remove_o_ring_sim_colliders_v074()
	var prepared: int = super._prepare_o_ring_followers_v068()
	if prepared <= 0:
		return prepared

	# Reuse the proven v0.5.14 dedicated collision-layer split: connectors gain
	# the temporary target bit, while rods never do. main_v070 intentionally made
	# followers collisionless; v0.5.16 enables only this connector-facing collar.
	_enable_o_ring_connector_collision_v069()
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.collision_layer = O_RING_SIM_LAYER_V069
		ring.collision_mask = O_RING_SIM_CONNECTOR_LAYER_V069
		_add_o_ring_sim_collider_v074(ring)
	_rebind_all_joints()
	return prepared


func _build_axle_stop_ranges_v070() -> void:
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = 0
	# The base range builder knows which segment each hub started in. Keep only
	# real rod-end limits in the deterministic solver. O-Ring-side limits become
	# unbounded because the connector-only collision collar owns those stops.
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		var ring_count: int = int(stop.get("ring_count", 0))
		if ring_count <= 0:
			continue
		var segment: int = int(stop.get("segment", 0))
		if segment > 0:
			stop["lower"] = -INF
			stop["lower_collision_owned_v074"] = true
		if segment < ring_count:
			stop["upper"] = INF
			stop["upper_collision_owned_v074"] = true


# Disable the abandoned dynamic ownership/order experiments from main_v073.
# Physical connector collision determines hub order; the O-Ring collar handles
# the ring boundary and the released v0.5.15 solver handles only rod ends.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_remove_o_ring_sim_colliders_v074()
	o_ring_axle_stop_joints_v074.clear()
	axle_ranked_stop_count_v074 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
