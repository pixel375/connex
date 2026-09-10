extends "res://scripts/main_v072.gd"

const VERSION_073 := "0.5.16"
const STRUCTURE_FLEX_CURVE_POWER_V073 := 1.75
const STRUCTURE_FLEX_RIGID_THRESHOLD_V073 := 90.0
const AXLE_HUB_PASS_GUARD_SPACING_V073 := 0.62
const AXLE_HUB_ORDER_EPS_V073 := 0.001

var axle_order_groups_v073: Array = []
var axle_order_guard_events_v073: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_073)
	_status("v0.5.16 ready — durable O-Ring topology guard, stable closed-loop rigidity and progressive realistic flex below 90%.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_073, text]


# -----------------------------------------------------------------------------
# Structure Rigidity
# -----------------------------------------------------------------------------

func _structure_flex_angle_rad_v066() -> float:
	var rigidity: float = clampf(physics_structure_rigidity_v066, 0.0, 100.0)
	if rigidity >= STRUCTURE_FLEX_RIGID_THRESHOLD_V073:
		return 0.0
	var flexible01: float = 1.0 - rigidity / STRUCTURE_FLEX_RIGID_THRESHOLD_V073
	var degrees: float = STRUCTURE_FLEX_MAX_DEG_V072 * pow(flexible01, STRUCTURE_FLEX_CURVE_POWER_V073)
	return deg_to_rad(degrees)


func _structure_flex_angle_deg_v066() -> float:
	return rad_to_deg(_structure_flex_angle_rad_v066())


func _cycle_solver_relief_rad_v073() -> float:
	# A completely welded redundant edge makes a closed graph numerically
	# over-constrained in Jolt. Preserve the proven v0.5.11 micro-relief only on
	# that redundant edge while normal high-rigidity joints stay exactly rigid.
	var rigidity01: float = clampf(physics_structure_rigidity_v066 / 100.0, 0.0, 1.0)
	var loose01: float = pow(1.0 - rigidity01, 1.35)
	var degrees: float = lerpf(STRUCTURE_FLEX_MIN_DEG_V066, STRUCTURE_FLEX_MAX_DEG_V066, loose01)
	return deg_to_rad(degrees)


func _apply_structure_flex_all_v072() -> int:
	var global_flex: float = _structure_flex_angle_rad_v066()
	var high_end: bool = physics_structure_rigidity_v066 >= STRUCTURE_FLEX_RIGID_THRESHOLD_V073
	var cycle_relief: float = _cycle_solver_relief_rad_v073()
	var count := 0
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


# -----------------------------------------------------------------------------
# Durable O-Ring stops without artificial per-hub floors
#
# Keep the stable nearest-hub ownership used by v0.5.15: only the lowest hub in
# an O-Ring segment owns its lower boundary and only the highest owns its upper
# boundary. Interior hubs stack through normal connector collision.
#
# The missing case from larger device builds was tunnelling: an interior hub can
# pass completely through the current boundary owner in one physics step and is
# then free to continue through the O-Ring. Record the original hub order and
# prevent only an actual/predicted order reversal. This is a topological safety
# guard, not a continuously active hidden joint, so it does not fight normal hub
# collisions or force several connected assemblies onto artificial coordinates.
# -----------------------------------------------------------------------------

func _build_axle_stop_ranges_v070() -> void:
	axle_stop_ranges_v070.clear()
	axle_order_groups_v073.clear()
	_rebuild_connection_graph_v020()
	var groups: Dictionary = {}

	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "axle":
			continue
		var connector := record.get("connector") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var key: int = rod.get_instance_id()
		var group: Dictionary = groups.get(key, {"rod": rod, "axles": [], "rings": []}) as Dictionary
		var axles: Array = group.get("axles", []) as Array
		axles.append({
			"connector": connector,
			"uid": int(record.get("uid", -1)),
			"initial": _rod_local_along_v070(connector, rod),
		})
		group["axles"] = axles
		groups[key] = group

	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		var key: int = rod.get_instance_id()
		if not groups.has(key):
			continue
		var group: Dictionary = groups[key] as Dictionary
		var rings: Array = group.get("rings", []) as Array
		rings.append(_rod_local_along_v070(ring, rod))
		group["rings"] = rings
		groups[key] = group

	for key_value in groups.keys():
		var group: Dictionary = groups[key_value] as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var rings: Array = group.get("rings", []) as Array
		rings.sort()
		var by_segment: Dictionary = {}
		for axle_value in group.get("axles", []) as Array:
			var axle := axle_value as Dictionary
			var initial: float = float(axle.get("initial", 0.0))
			var segment := 0
			for ring_value in rings:
				if float(ring_value) < initial:
					segment += 1
			var segment_axles: Array = by_segment.get(segment, []) as Array
			segment_axles.append(axle)
			by_segment[segment] = segment_axles

		var rod_half: float = maxf(AXLE_CONNECTOR_HALF_V070, float(rod.get_meta("visual_length", 0.0)) * 0.5)
		for segment_value in by_segment.keys():
			var segment: int = int(segment_value)
			var segment_axles: Array = by_segment[segment] as Array
			segment_axles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("initial", 0.0)) < float(b.get("initial", 0.0)))
			if segment_axles.is_empty():
				continue
			var lower_boundary: float = -rod_half + AXLE_CONNECTOR_HALF_V070
			var upper_boundary: float = rod_half - AXLE_CONNECTOR_HALF_V070
			if segment > 0:
				lower_boundary = float(rings[segment - 1]) + O_RING_AXLE_CLEARANCE_V070
			if segment < rings.size():
				upper_boundary = float(rings[segment]) - O_RING_AXLE_CLEARANCE_V070

			var ordered_guards: Array = []
			for i in range(segment_axles.size()):
				var axle := segment_axles[i] as Dictionary
				var stop := {
					"connector": axle.get("connector"),
					"rod": rod,
					"uid": int(axle.get("uid", -1)),
					"lower": lower_boundary if i == 0 else -INF,
					"upper": upper_boundary if i == segment_axles.size() - 1 else INF,
					"ring_count": rings.size(),
					"segment": segment,
					"segment_index": i,
					"segment_size": segment_axles.size(),
				}
				axle_stop_ranges_v070.append(stop)
				ordered_guards.append({
					"connector": axle.get("connector"),
					"rod": rod,
					"uid": int(axle.get("uid", -1)),
				})
			if ordered_guards.size() > 1:
				axle_order_groups_v073.append({
					"rod": rod,
					"hubs": ordered_guards,
					"segment": segment,
					"lower": lower_boundary,
					"upper": upper_boundary,
				})


func _hub_guard_axial_speed_v073(guard: Dictionary, axis: Vector3, rod: RigidBody3D) -> float:
	var connector := guard.get("connector") as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return 0.0
	return (connector.linear_velocity - rod.linear_velocity).dot(axis)


func _guard_component_contains_v073(guard: Dictionary, body: RigidBody3D) -> bool:
	if not is_instance_valid(body):
		return false
	for value in _stop_component_v071(guard):
		var member := value as RigidBody3D
		if is_instance_valid(member) and member == body:
			return true
	return false


func _predict_axle_order_v073(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		var hubs: Array = group.get("hubs", []) as Array
		for i in range(hubs.size() - 1):
			var low := hubs[i] as Dictionary
			var high := hubs[i + 1] as Dictionary
			var low_body := low.get("connector") as RigidBody3D
			var high_body := high.get("connector") as RigidBody3D
			if not is_instance_valid(low_body) or not is_instance_valid(high_body):
				continue
			if _guard_component_contains_v073(low, high_body) or _guard_component_contains_v073(high, low_body):
				continue
			var low_along: float = _rod_local_along_v070(low_body, rod)
			var high_along: float = _rod_local_along_v070(high_body, rod)
			var gap: float = high_along - low_along
			var low_speed: float = _hub_guard_axial_speed_v073(low, axis, rod)
			var high_speed: float = _hub_guard_axial_speed_v073(high, axis, rod)
			var relative: float = high_speed - low_speed
			if relative < 0.0 and gap > AXLE_HUB_ORDER_EPS_V073 and gap + relative * delta <= AXLE_HUB_ORDER_EPS_V073:
				# Match the two axial velocities for this step. Physical connector
				# collision remains responsible for the actual contact/stacking.
				_shift_component_velocity_v071(high, axis * -relative)
				axle_order_guard_events_v073 += 1


func _correct_axle_order_v073() -> void:
	if not simulating:
		return
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		var upper_boundary: float = float(group.get("upper", INF))
		var hubs: Array = group.get("hubs", []) as Array
		for i in range(hubs.size() - 1):
			var low := hubs[i] as Dictionary
			var high := hubs[i + 1] as Dictionary
			var low_body := low.get("connector") as RigidBody3D
			var high_body := high.get("connector") as RigidBody3D
			if not is_instance_valid(low_body) or not is_instance_valid(high_body):
				continue
			if _guard_component_contains_v073(low, high_body) or _guard_component_contains_v073(high, low_body):
				continue
			var low_along: float = _rod_local_along_v070(low_body, rod)
			var high_along: float = _rod_local_along_v070(high_body, rod)
			if high_along >= low_along - AXLE_HUB_ORDER_EPS_V073:
				continue
			# A center-order reversal means collision tunnelling already occurred.
			# Restore the upper hub just beyond physical overlap and match the lower
			# hub's axial speed. This path should be rare; unlike ranked floors it is
			# completely inactive during ordinary contact.
			var target: float = low_along + AXLE_HUB_PASS_GUARD_SPACING_V073
			if upper_boundary < INF:
				target = minf(target, upper_boundary)
			if target <= low_along:
				target = low_along + AXLE_HUB_ORDER_EPS_V073
			_shift_stop_component_v071(high, axis * (target - high_along))
			var low_speed: float = _hub_guard_axial_speed_v073(low, axis, rod)
			var high_speed: float = _hub_guard_axial_speed_v073(high, axis, rod)
			_shift_component_velocity_v071(high, axis * (low_speed - high_speed))
			axle_order_guard_events_v073 += 1


func _predict_axle_stops_v071(delta: float) -> void:
	super._predict_axle_stops_v071(delta)
	_predict_axle_order_v073(delta)


func _correct_axle_stop_positions_v071() -> void:
	super._correct_axle_stop_positions_v071()
	_correct_axle_order_v073()


func _prepare_stable_simulation_graph() -> void:
	axle_order_groups_v073.clear()
	axle_order_guard_events_v073 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_order_groups_v073.clear()
	axle_order_guard_events_v073 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
