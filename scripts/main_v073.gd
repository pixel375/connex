extends "res://scripts/main_v072.gd"

const VERSION_073 := "0.5.16"
const STRUCTURE_FLEX_CURVE_POWER_V073 := 1.75
const STRUCTURE_FLEX_RIGID_THRESHOLD_V073 := 90.0

var axle_stop_segment_by_uid_v073: Dictionary = {}
var axle_stop_ownership_refreshes_v073: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_073)
	_status("v0.5.16 ready — live O-Ring stop ownership, rigid high-end structure settings and progressive realistic flex below 90%.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_073, text]


func _structure_flex_angle_rad_v066() -> float:
	var rigidity: float = clampf(physics_structure_rigidity_v066, 0.0, 100.0)
	# Jolt treats a tiny non-zero angular allowance as a materially different
	# constraint from a true fixed joint. Keep the upper end exactly rigid so the
	# default 92% physics remains stable, then ramp compliance through the lower
	# slider range where the user actually wants visible structure flex.
	if rigidity >= STRUCTURE_FLEX_RIGID_THRESHOLD_V073:
		return 0.0
	var flexible01: float = 1.0 - rigidity / STRUCTURE_FLEX_RIGID_THRESHOLD_V073
	var degrees: float = STRUCTURE_FLEX_MAX_DEG_V072 * pow(flexible01, STRUCTURE_FLEX_CURVE_POWER_V073)
	return deg_to_rad(degrees)


func _structure_flex_angle_deg_v066() -> float:
	return rad_to_deg(_structure_flex_angle_rad_v066())


# O-Ring boundaries belong to rod segments, not permanently to the connector
# that happened to be nearest when SIMULATE started. Keep each AXLE's original
# O-Ring segment so a hub can never change sides by crossing a ring, but refresh
# which hub is currently the lower/upper boundary owner inside that segment.
# Interior hubs remain ordinary physical hubs and stack by normal collision.
# This prevents stale ownership without adding artificial hidden floors between
# adjacent connectors (which caused solver energy when loaded constructions hit).
func _build_axle_stop_ranges_v070() -> void:
	axle_stop_ranges_v070.clear()
	if axle_stop_segment_by_uid_v073.is_empty():
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
			"along": _rod_local_along_v070(connector, rod),
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
			var uid: int = int(axle.get("uid", -1))
			var current_along: float = float(axle.get("along", 0.0))
			var segment: int
			if axle_stop_segment_by_uid_v073.has(uid):
				segment = clampi(int(axle_stop_segment_by_uid_v073[uid]), 0, rings.size())
			else:
				segment = 0
				for ring_value in rings:
					if float(ring_value) < current_along:
						segment += 1
				axle_stop_segment_by_uid_v073[uid] = segment
			var segment_axles: Array = by_segment.get(segment, []) as Array
			segment_axles.append(axle)
			by_segment[segment] = segment_axles

		var rod_half: float = maxf(AXLE_CONNECTOR_HALF_V070, float(rod.get_meta("visual_length", 0.0)) * 0.5)
		for segment_value in by_segment.keys():
			var segment: int = int(segment_value)
			var segment_axles: Array = by_segment[segment] as Array
			segment_axles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("along", 0.0)) < float(b.get("along", 0.0)))
			if segment_axles.is_empty():
				continue

			var lower_boundary: float = -rod_half + AXLE_CONNECTOR_HALF_V070
			var upper_boundary: float = rod_half - AXLE_CONNECTOR_HALF_V070
			if segment > 0:
				lower_boundary = float(rings[segment - 1]) + O_RING_AXLE_CLEARANCE_V070
			if segment < rings.size():
				upper_boundary = float(rings[segment]) - O_RING_AXLE_CLEARANCE_V070
			if lower_boundary > upper_boundary:
				var midpoint: float = (lower_boundary + upper_boundary) * 0.5
				lower_boundary = midpoint
				upper_boundary = midpoint

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
					"dynamic_owner_v073": true,
				})
	axle_stop_ownership_refreshes_v073 += 1


func _prepare_stable_simulation_graph() -> void:
	axle_stop_segment_by_uid_v073.clear()
	axle_stop_ownership_refreshes_v073 = 0
	super._prepare_stable_simulation_graph()


func _predict_axle_stops_v071(delta: float) -> void:
	if simulating:
		_build_axle_stop_ranges_v070()
	super._predict_axle_stops_v071(delta)


func _correct_axle_stop_positions_v071() -> void:
	if simulating:
		_build_axle_stop_ranges_v070()
	super._correct_axle_stop_positions_v071()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_stop_segment_by_uid_v073.clear()
	axle_stop_ownership_refreshes_v073 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)
