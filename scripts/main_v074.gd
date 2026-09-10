extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"
const COMPLEX_ORING_PHYSICS_TPS_V074 := 120
const AXLE_HUB_ORDER_REPAIR_SPACING_V074 := 0.62

# Number of AXLE hubs participating in multi-hub segments on rods that contain
# at least one O-Ring. Kept under the old debug name for test compatibility.
var axle_ranked_stop_count_v074: int = 0
var o_ring_precision_ticks_active_v074: bool = false
var saved_physics_ticks_v074: int = -1
var axle_order_repair_events_v074: int = 0

# Compatibility/debug surfaces for abandoned experiments. They stay empty.
var axle_stack_shape_state_v074: Array = []
var o_ring_axle_stop_joints_v074: Array = []
var o_ring_sim_colliders_v074: Array = []


# -----------------------------------------------------------------------------
# Durable multi-hub O-Ring simulation
#
# Keep the released v0.5.15 O-Ring stop topology:
#
# - O-Rings are collisionless exact rod-local followers;
# - the normal AXLE joint remains free in axial slide and rotation;
# - the original outermost hub in each O-Ring segment owns the finite stop;
# - normal hub-to-hub collision remains the ordinary stacking mechanism.
#
# Rarely, Jolt can tunnel one AXLE hub completely through its neighbour. That is
# an impossible physical state. Transferring O-Ring ownership to the tunnelled
# hub was not safe: later snapping that hub to the O-Ring could place its attached
# assembly directly inside the previous owner and create an energy explosion.
#
# v0.5.16 therefore repairs only the impossible order inversion itself. When two
# adjacent hubs actually reverse their BUILD order, move only the hub whose
# relative axial velocity caused the crossing back to the correct side of its
# neighbour with physical hub spacing, and match only that component's axial
# velocity to the neighbour. The host rod and original O-Ring owner never move.
# This guard is dormant during normal contact and does not create hidden floors,
# replacement joints, O-Ring collision proxies, or persistent rank constraints.
#
# Multi-hub O-Ring builds additionally run at 120 Hz while SIMULATE is active to
# reduce one-step tunnelling distance. Ordinary simulations keep the project tick
# rate, and BUILD restores the exact prior value.
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
	# v073 builds the v0.5.15 outer-owner ranges and preserves the initial hub
	# order in axle_order_groups_v073. Keep those finite owners unchanged.
	super._build_axle_stop_ranges_v070()
	axle_ranked_stop_count_v074 = _count_complex_o_ring_hubs_v074()
	_enable_precision_ticks_v074()


func _repair_axle_hub_order_v074() -> bool:
	if not simulating:
		return false
	var repaired_any := false

	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		var expected: Array = group.get("hubs", []) as Array
		if not is_instance_valid(rod) or expected.size() <= 1:
			continue
		var segment: int = int(group.get("segment", 0))
		var axis: Vector3 = _rod_axis_v020(rod).normalized()

		# A single physics step can theoretically create more than one adjacent
		# inversion in a larger stack. Iterate only enough passes to restore the
		# original ordering; normal non-crossed contact is never touched.
		for _pass in range(expected.size()):
			var repaired_this_pass := false
			for i in range(expected.size() - 1):
				var lower_info := expected[i] as Dictionary
				var upper_info := expected[i + 1] as Dictionary
				var lower := lower_info.get("connector") as RigidBody3D
				var upper := upper_info.get("connector") as RigidBody3D
				if not is_instance_valid(lower) or not is_instance_valid(upper):
					continue
				var lower_along: float = _rod_local_along_v070(lower, rod)
				var upper_along: float = _rod_local_along_v070(upper, rod)
				if upper_along >= lower_along:
					continue

				var lower_speed: float = lower.linear_velocity.dot(axis)
				var upper_speed: float = upper.linear_velocity.dot(axis)
				var move_upper: bool = upper_speed - lower_speed <= 0.0
				if move_upper:
					# The upper hub moved downward through the lower hub. Restore it just
					# above the lower hub, then remove only the closing axial speed.
					var stop: Dictionary = _find_stop_v074(rod, upper, segment)
					if stop.is_empty():
						continue
					var target_along := lower_along + AXLE_HUB_ORDER_REPAIR_SPACING_V074
					_shift_stop_component_v071(stop, axis * (target_along - upper_along))
					var velocity_delta := lower_speed - upper_speed
					if velocity_delta > 0.0:
						_shift_component_velocity_v071(stop, axis * velocity_delta)
				else:
					# The lower hub moved upward through the upper hub. Restore it just
					# below the upper hub and match only its axial speed to the neighbour.
					var stop: Dictionary = _find_stop_v074(rod, lower, segment)
					if stop.is_empty():
						continue
					var target_along := upper_along - AXLE_HUB_ORDER_REPAIR_SPACING_V074
					_shift_stop_component_v071(stop, axis * (target_along - lower_along))
					var velocity_delta := upper_speed - lower_speed
					if velocity_delta < 0.0:
						_shift_component_velocity_v071(stop, axis * velocity_delta)

				axle_order_repair_events_v074 += 1
				axle_order_guard_events_v073 += 1
				repaired_any = true
				repaired_this_pass = true
			if not repaired_this_pass:
				break

	return repaired_any


# Disable v073's ownership-transfer recovery. The BUILD order remains the source
# of truth; v074 repairs impossible hub tunnelling instead of moving the O-Ring
# boundary to whichever hub happened to tunnel through.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return false


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return

	# Repair a genuine hub-through-hub inversion first. This keeps the original
	# finite stop owner outside the stack and avoids ever snapping a tunnelled hub
	# onto the O-Ring inside another connector.
	_repair_axle_hub_order_v074()

	# Then apply the released v0.5.15 outer-boundary correction exactly once.
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
	axle_order_repair_events_v074 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_restore_precision_ticks_v074()
	axle_ranked_stop_count_v074 = 0
	axle_stack_shape_state_v074.clear()
	o_ring_axle_stop_joints_v074.clear()
	o_ring_sim_colliders_v074.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
