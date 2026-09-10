extends "res://scripts/main_v072.gd"

const VERSION_073 := "0.5.16"
const STRUCTURE_FLEX_CURVE_POWER_V073 := 1.75
const STRUCTURE_FLEX_RIGID_THRESHOLD_V073 := 90.0

var axle_order_groups_v073: Array = []
var axle_order_guard_events_v073: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_073)
	_status("v0.5.16 ready — durable O-Ring ownership handoff, stable closed-loop rigidity and progressive realistic flex below 90%.")


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
		# Preserve the stable v0.5.15 high-end path: ordinary fixed joints do not
		# get rewritten merely to set their already-zero angular limits to zero.
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


# -----------------------------------------------------------------------------
# v0.5.15-compatible stop component traversal
# -----------------------------------------------------------------------------

func _stop_component_v071(stop: Dictionary) -> Array:
	var connector := stop.get("connector") as RigidBody3D
	var host_rod := stop.get("rod") as RigidBody3D
	if not is_instance_valid(connector):
		return []
	_rebuild_connection_graph_v020(false)
	var excluded_uid: int = int(stop.get("uid", -1))
	var legacy_component: Array = _fixed_component_v020(connector, excluded_uid)
	if legacy_component.is_empty():
		legacy_component = [connector]
	if not is_instance_valid(host_rod) or not (host_rod in legacy_component):
		return legacy_component

	# Only a complex fixed loop can put the host axle into the connector-side
	# component. In that case traverse the same fixed graph but stop at host_rod.
	var result: Array = []
	var queue: Array = [connector]
	var seen: Dictionary = {connector.get_instance_id(): true}
	while not queue.is_empty():
		var current := queue.pop_front() as RigidBody3D
		if not is_instance_valid(current) or current == host_rod:
			continue
		result.append(current)
		for record_value in connections_v020:
			var record := record_value as Dictionary
			if int(record.get("uid", -1)) == excluded_uid or str(record.get("kind", "")) not in ["socket", "cross", "o_ring"]:
				continue
			if record.get("a") != current and record.get("b") != current:
				continue
			var other := _other_body_v020(record, current) as RigidBody3D
			if not is_instance_valid(other) or other == host_rod or seen.has(other.get_instance_id()):
				continue
			seen[other.get_instance_id()] = true
			queue.append(other)
	if result.is_empty():
		result = [connector]
	return result


# -----------------------------------------------------------------------------
# Durable O-Ring stops with event-driven boundary ownership
#
# The proven v0.5.15 model gives only the outer AXLE hubs in an O-Ring segment
# finite O-Ring/rod-end bounds; interior hubs stack by ordinary connector
# collision. Rare high-energy Jolt steps can tunnel one hub through another.
# Do not fight that by moving bodies or injecting velocity. If actual hub order
# changes, hand the finite boundaries to the hubs that are now outermost. The
# normal v0.5.15 stop solver then catches whichever hub reaches the O-Ring.
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

			var ordered_hubs: Array = []
			for i in range(segment_axles.size()):
				var axle := segment_axles[i] as Dictionary
				axle_stop_ranges_v070.append({
					"connector": axle.get("connector"),
					"rod": rod,
					"uid": int(axle.get("uid", -1)),
					"lower": lower_boundary if i == 0 else -INF,
					"upper": upper_boundary if i == segment_axles.size() - 1 else INF,
					"ring_count": rings.size(),
					"segment": segment,
					"segment_index": i,
					"segment_size": segment_axles.size(),
				})
				ordered_hubs.append({
					"connector": axle.get("connector"),
					"rod": rod,
					"uid": int(axle.get("uid", -1)),
				})
			if ordered_hubs.size() > 1:
				axle_order_groups_v073.append({
					"rod": rod,
					"hubs": ordered_hubs,
					"segment": segment,
					"lower": lower_boundary,
					"upper": upper_boundary,
				})


func _current_hub_order_v073(group: Dictionary) -> Array:
	var rod := group.get("rod") as RigidBody3D
	var ordered: Array = (group.get("hubs", []) as Array).duplicate()
	if not is_instance_valid(rod):
		return ordered
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var body_a := a.get("connector") as RigidBody3D
		var body_b := b.get("connector") as RigidBody3D
		if not is_instance_valid(body_a):
			return false
		if not is_instance_valid(body_b):
			return true
		return _rod_local_along_v070(body_a, rod) < _rod_local_along_v070(body_b, rod)
	)
	return ordered


func _same_hub_order_v073(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if (a[i] as Dictionary).get("connector") != (b[i] as Dictionary).get("connector"):
			return false
	return true


func _handoff_axle_stop_ownership_v073() -> bool:
	if not simulating:
		return false
	var any_changed := false
	for group_value in axle_order_groups_v073:
		var group := group_value as Dictionary
		var rod := group.get("rod") as RigidBody3D
		if not is_instance_valid(rod):
			continue
		var previous: Array = group.get("hubs", []) as Array
		var current: Array = _current_hub_order_v073(group)
		if _same_hub_order_v073(previous, current):
			continue
		var segment: int = int(group.get("segment", 0))
		var lower_boundary: float = float(group.get("lower", -INF))
		var upper_boundary: float = float(group.get("upper", INF))

		# Clear only this rod/segment's old finite ownership.
		for stop_value in axle_stop_ranges_v070:
			var stop := stop_value as Dictionary
			if stop.get("rod") == rod and int(stop.get("segment", -999)) == segment:
				stop["lower"] = -INF
				stop["upper"] = INF
				stop["segment_index"] = -1

		# Reassign boundaries to the hubs that are physically outermost now.
		for i in range(current.size()):
			var hub_info := current[i] as Dictionary
			var connector := hub_info.get("connector") as RigidBody3D
			for stop_value in axle_stop_ranges_v070:
				var stop := stop_value as Dictionary
				if stop.get("rod") != rod or stop.get("connector") != connector or int(stop.get("segment", -999)) != segment:
					continue
				stop["segment_index"] = i
				if i == 0:
					stop["lower"] = lower_boundary
				if i == current.size() - 1:
					stop["upper"] = upper_boundary
				break
		group["hubs"] = current
		axle_order_guard_events_v073 += 1
		any_changed = true
	return any_changed


# There is deliberately no pre-step hub-order intervention. Normal connector
# collision gets the first and only chance to resolve ordinary hub contact.
func _predict_axle_order_v073(_delta: float) -> void:
	pass


func _correct_axle_order_v073() -> bool:
	return _handoff_axle_stop_ownership_v073()


func _predict_axle_stops_v071(delta: float) -> void:
	super._predict_axle_stops_v071(delta)
	_predict_axle_order_v073(delta)


func _correct_axle_stop_positions_v071() -> void:
	# First enforce whichever hubs currently own the two O-Ring/rod-end edges.
	super._correct_axle_stop_positions_v071()
	# If Jolt actually tunnelled hubs through each other, transfer ownership
	# without touching body transforms or velocities, then immediately enforce
	# the same proven stop once for the newly outer hub.
	if _correct_axle_order_v073():
		super._correct_axle_stop_positions_v071()


func _prepare_stable_simulation_graph() -> void:
	axle_order_groups_v073.clear()
	axle_order_guard_events_v073 = 0
	super._prepare_stable_simulation_graph()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_order_groups_v073.clear()
	axle_order_guard_events_v073 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
