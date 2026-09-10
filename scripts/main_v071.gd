extends "res://scripts/main_v070.gd"

const VERSION_071 := "0.5.15"
const AXLE_STOP_PREDICT_MARGIN_V071 := 0.012
const AXLE_STOP_POSITION_EPS_V071 := 0.001


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_071)
	_status("v0.5.15 ready — stable rod-local O-Ring/rod-end stops plus socket workflow fixes.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_071, text]


# v0.5.15's first deterministic pass projected every axle hub toward the same
# ring boundary. Two hubs in one interval could therefore be forced into each
# other. Build one-dimensional stop ownership per interval instead: only the
# lowest hub can reach the lower stop and only the highest hub can reach the
# upper stop. Hub-to-hub stacking remains ordinary physical collision.
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
		for axle_value in (group.get("axles", []) as Array):
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


# Disable v0.5.15's first mass-weighted position solver. v0.5.15.1 below uses
# velocity prediction plus connector-side correction only; it never moves the
# host rod merely because an axle hub touched a stop.
func _enforce_axle_stops_v070() -> void:
	pass


func _stop_component_v071(stop: Dictionary) -> Array:
	var connector := stop.get("connector") as RigidBody3D
	if not is_instance_valid(connector):
		return []
	var component: Array = _fixed_component_v020(connector, int(stop.get("uid", -1)))
	if component.is_empty():
		component = [connector]
	return component


func _component_ids_v071(component: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in component:
		var body := value as RigidBody3D
		if is_instance_valid(body):
			result[body.get_instance_id()] = true
	return result


func _shift_stop_component_v071(stop: Dictionary, delta: Vector3) -> void:
	if delta.length_squared() < 0.000000001:
		return
	var component: Array = _stop_component_v071(stop)
	var ids: Dictionary = _component_ids_v071(component)
	for value in component:
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		var transform: Transform3D = body.global_transform
		transform.origin += delta
		body.global_transform = transform
		body.sleeping = false

	# Joint3D nodes live under Main, not under their bodies. Move every active
	# fixed-joint frame whose two endpoints are inside the translated component,
	# otherwise the next Jolt solve would pull the translated assembly back toward
	# stale world anchors and manufacture energy.
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or str(joint.name).begins_with("AxleJoint"):
			continue
		if joint.node_a.is_empty() or joint.node_b.is_empty():
			continue
		var nodes: Array = _joint_nodes(joint)
		var a := nodes[0] as RigidBody3D
		var b := nodes[1] as RigidBody3D
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if ids.has(a.get_instance_id()) and ids.has(b.get_instance_id()):
			var joint_tf: Transform3D = joint.global_transform
			joint_tf.origin += delta
			joint.global_transform = joint_tf


func _shift_component_velocity_v071(stop: Dictionary, delta_velocity: Vector3) -> void:
	if delta_velocity.length_squared() < 0.000000001:
		return
	for value in _stop_component_v071(stop):
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		body.linear_velocity += delta_velocity
		body.sleeping = false


func _relative_axial_speed_v071(stop: Dictionary) -> float:
	var connector := stop.get("connector") as RigidBody3D
	var rod := stop.get("rod") as RigidBody3D
	if not is_instance_valid(connector) or not is_instance_valid(rod):
		return 0.0
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	return (connector.linear_velocity - rod.linear_velocity).dot(axis)


func _predict_axle_stops_v071(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		var connector := stop.get("connector") as RigidBody3D
		var rod := stop.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod) or connector.freeze:
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		var along: float = _rod_local_along_v070(connector, rod)
		var relative_speed: float = _relative_axial_speed_v071(stop)
		var lower: float = float(stop.get("lower", -INF))
		var upper: float = float(stop.get("upper", INF))

		if lower > -INF:
			var lower_guard: float = lower + AXLE_STOP_PREDICT_MARGIN_V071
			if relative_speed < 0.0 and along + relative_speed * delta < lower_guard:
				var allowed_speed: float = minf(0.0, (lower_guard - along) / delta)
				_shift_component_velocity_v071(stop, axis * (allowed_speed - relative_speed))
				relative_speed = allowed_speed
		if upper < INF:
			var upper_guard: float = upper - AXLE_STOP_PREDICT_MARGIN_V071
			if relative_speed > 0.0 and along + relative_speed * delta > upper_guard:
				var allowed_speed: float = maxf(0.0, (upper_guard - along) / delta)
				_shift_component_velocity_v071(stop, axis * (allowed_speed - relative_speed))


func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return
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
			var speed: float = _relative_axial_speed_v071(stop)
			if speed < 0.0:
				_shift_component_velocity_v071(stop, axis * -speed)
		elif upper < INF and along > upper + AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (upper - along))
			var speed: float = _relative_axial_speed_v071(stop)
			if speed > 0.0:
				_shift_component_velocity_v071(stop, axis * -speed)


func _physics_process(delta: float) -> void:
	# v0.5.13's process still performs follower sync and runaway guarding. Since
	# _enforce_axle_stops_v070 is overridden to a no-op, there is no position
	# projection inside that inherited sync. Apply the predictive velocity clamp
	# once, immediately before the next physics integration.
	super._physics_process(delta)
	_predict_axle_stops_v071(delta)


func _sync_o_ring_followers_v068() -> void:
	# v0.5.15 base sync keeps the collisionless O-Ring exactly on the host rod;
	# its old deterministic solver is now a no-op. Correct only genuine post-step
	# boundary violations, then resync the ring in case the connector correction
	# caused other rigid-body transforms to update.
	super._sync_o_ring_followers_v068()
	_correct_axle_stop_positions_v071()
	super._sync_o_ring_followers_v068()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — O-Ring/rod-end stops constrain only the nearest AXLE hub in each rod segment; hub stacking and axle rotation remain physical/free.")


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.15 STOP STABILITY: when several axle connectors share one rod segment, only the connector physically nearest each O-Ring/rod end owns that boundary. Other axle connectors remain freely sliding and stack through normal connector collision, so the stopper never projects multiple hubs into the same coordinate. Inward relative velocity is predicted before each physics step; any residual post-step crossing is corrected only on the connector-side rigid component while its active internal joint anchors move with it. The host rod is never teleported by the O-Ring stop."
