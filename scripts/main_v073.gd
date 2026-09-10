extends "res://scripts/main_v072.gd"

const VERSION_073 := "0.5.16"
const STRUCTURE_FLEX_CURVE_POWER_V073 := 1.75
const STRUCTURE_FLEX_RIGID_THRESHOLD_V073 := 90.0
const AXLE_HUB_PHYSICAL_SPACING_V073 := 0.64


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_073)
	_status("v0.5.16 ready — durable O-Ring stops, rigid high-end structure settings and progressive realistic flex below 90%.")


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


# v0.5.16 originally ranked adjacent axle-stop floors 0.56 units apart while a
# connector's physical thickness along the axle is 0.60. Two falling hubs could
# therefore be constrained into permanent collider overlap and Jolt would inject
# energy trying to separate them. Use a small non-overlap margin instead. If a
# segment is physically too short to fit all hubs at that spacing, only its outer
# hubs own the O-Ring/rod-end boundaries and ordinary hub collision stacks the
# interior hubs; manufacturing impossible overlapping floors is never allowed.
func _build_axle_stop_ranges_v070() -> void:
	axle_stop_ranges_v070.clear()
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
		axles.append({"connector": connector, "uid": int(record.get("uid", -1)), "initial": _rod_local_along_v070(connector, rod)})
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
			var base_lower: float = -rod_half + AXLE_CONNECTOR_HALF_V070
			var base_upper: float = rod_half - AXLE_CONNECTOR_HALF_V070
			if segment > 0:
				base_lower = float(rings[segment - 1]) + O_RING_AXLE_CLEARANCE_V070
			if segment < rings.size():
				base_upper = float(rings[segment]) - O_RING_AXLE_CLEARANCE_V070
			if base_lower > base_upper:
				var midpoint: float = (base_lower + base_upper) * 0.5
				base_lower = midpoint
				base_upper = midpoint

			var n: int = segment_axles.size()
			var required_width: float = AXLE_HUB_PHYSICAL_SPACING_V073 * float(maxi(0, n - 1))
			var ranked_floors_fit: bool = base_upper - base_lower + 0.0001 >= required_width
			for i in range(n):
				var axle := segment_axles[i] as Dictionary
				var initial: float = float(axle.get("initial", 0.0))
				var lower: float
				var upper: float
				if ranked_floors_fit:
					lower = base_lower + AXLE_HUB_PHYSICAL_SPACING_V073 * float(i)
					upper = base_upper - AXLE_HUB_PHYSICAL_SPACING_V073 * float(n - 1 - i)
					# Preserve an already-valid BUILD pose without an immediate artificial
					# correction; future travel still cannot be driven into overlap.
					lower = minf(lower, initial)
					upper = maxf(upper, initial)
				else:
					lower = base_lower if i == 0 else -INF
					upper = base_upper if i == n - 1 else INF
				axle_stop_ranges_v070.append({
					"connector": axle.get("connector"),
					"rod": rod,
					"uid": int(axle.get("uid", -1)),
					"lower": lower,
					"upper": upper,
					"ring_count": rings.size(),
					"segment": segment,
					"segment_index": i,
					"segment_size": n,
					"stack_spacing_v072": AXLE_HUB_PHYSICAL_SPACING_V073 if ranked_floors_fit else 0.0,
					"ranked_floors_fit_v073": ranked_floors_fit,
				})
