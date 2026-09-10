extends "res://scripts/main_v078.gd"

const VERSION_079 := "0.5.16"
const AXLE_PAIR_SEPARATION_V079 := AXLE_CONNECTOR_HALF_V070 * 2.0
const AXLE_PAIR_PREDICT_MARGIN_V079 := 0.016
const AXLE_PAIR_POSITION_EPS_V079 := 0.001
const AXLE_PAIR_SOLVER_PASSES_V079 := 12

var axle_pair_scene_guard_events_v079: int = 0
var axle_pair_scene_projection_events_v079: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_079)
	_status("v0.5.16 test runtime — multi-hub O-Ring stacks use synchronous component-safe separation.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_079, text]


# -----------------------------------------------------------------------------
# Retire failed asynchronous/constraint experiments for this candidate.
# -----------------------------------------------------------------------------

func _register_component_callback_v076(_body: RigidBody3D) -> void:
	# v076/v078 direct-state transform projection was temporally split from the
	# scene-tree Joint3D frames and became energetic late in the loaded fixture.
	# v079 performs no transform work through force-integration callbacks.
	pass


func _add_component_command_v076(_component: Array, _shift: Vector3, _delta_velocity: Vector3) -> void:
	pass


func _prepare_axle_component_commands_v076(_delta: float) -> void:
	pass


func _enable_axle_ccd_v074() -> int:
	# CCD did not prevent the original hub-through-hub event. The deterministic
	# pair guard below owns that one-dimensional contact, so restore normal state.
	_restore_axle_ccd_v074()
	return 0


# -----------------------------------------------------------------------------
# Synchronous connector-side component helpers.
# -----------------------------------------------------------------------------

func _translate_component_scene_v079(component: Array, delta: Vector3) -> void:
	if delta.length_squared() <= 0.0000000001:
		return
	var ids: Dictionary = _component_ids_v076(component)
	for value in component:
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		var tf: Transform3D = body.global_transform
		tf.origin += delta
		body.global_transform = tf
		body.sleeping = false

	# Exactly the invariant already proven by v0.5.15: internal fixed-joint
	# frames travel in the same operation as their whole component. AXLE joints
	# remain untouched so rod-axis slide and rotation stay free.
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


func _shift_component_velocity_scene_v079(component: Array, delta_velocity: Vector3) -> void:
	if delta_velocity.length_squared() <= 0.0000000001:
		return
	for value in component:
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		body.linear_velocity += delta_velocity
		body.sleeping = false


func _group_state_v079(group: Dictionary) -> Dictionary:
	var rod := group.get("rod") as RigidBody3D
	var hubs: Array = group.get("hubs", []) as Array
	if not is_instance_valid(rod) or hubs.size() <= 1:
		return {}
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	if axis.length_squared() < 0.5:
		return {}
	var rod_speed: float = rod.linear_velocity.dot(axis)
	var positions: Array[float] = []
	var velocities: Array[float] = []
	var masses: Array[float] = []
	for hub_value in hubs:
		var hub := hub_value as Dictionary
		var connector := hub.get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			return {}
		positions.append(_rod_local_along_v070(connector, rod))
		velocities.append(connector.linear_velocity.dot(axis) - rod_speed)
		masses.append(maxf(float(hub.get("mass", connector.mass)), 0.001))
	return {
		"rod": rod,
		"hubs": hubs,
		"axis": axis,
		"positions": positions,
		"velocities": velocities,
		"masses": masses,
		"lower": float(group.get("lower", -INF)),
		"upper": float(group.get("upper", INF)),
	}


# -----------------------------------------------------------------------------
# Pre-step velocity-only pair guard.
#
# This never moves a transform. It only removes one-dimensional closing speed
# when the immutable BUILD-order pair would penetrate before the next physics
# step. Because same-segment hub connector collision is excluded by v076 group
# preparation, this does not fight a second Jolt contact response.
# -----------------------------------------------------------------------------

func _predict_axle_pairs_v079(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_component_groups_v076:
		var state: Dictionary = _group_state_v079(group_value as Dictionary)
		if state.is_empty():
			continue
		var hubs: Array = state.get("hubs", []) as Array
		var axis: Vector3 = state.get("axis", Vector3.ZERO) as Vector3
		var positions: Array = state.get("positions", []) as Array
		var velocities: Array = state.get("velocities", []) as Array
		var masses: Array = state.get("masses", []) as Array
		var changed := false

		for _pass in range(AXLE_PAIR_SOLVER_PASSES_V079):
			var pass_changed := false
			for i in range(hubs.size() - 1):
				var gap: float = float(positions[i + 1]) - float(positions[i])
				var relative: float = float(velocities[i + 1]) - float(velocities[i])
				if relative >= 0.0:
					continue
				if gap + relative * delta >= AXLE_PAIR_SEPARATION_V079 + AXLE_PAIR_PREDICT_MARGIN_V079:
					continue
				var total_mass: float = float(masses[i]) + float(masses[i + 1])
				var common: float = (float(masses[i]) * float(velocities[i]) + float(masses[i + 1]) * float(velocities[i + 1])) / total_mass
				velocities[i] = common
				velocities[i + 1] = common
				pass_changed = true
				changed = true
			if not pass_changed:
				break

		if not changed:
			continue
		for i in range(hubs.size()):
			var hub := hubs[i] as Dictionary
			var connector := hub.get("connector") as RigidBody3D
			if not is_instance_valid(connector):
				continue
			var current_relative: float = (connector.linear_velocity - (state.get("rod") as RigidBody3D).linear_velocity).dot(axis)
			var delta_relative: float = float(velocities[i]) - current_relative
			if absf(delta_relative) > 0.0001:
				_shift_component_velocity_scene_v079(hub.get("component", []) as Array, axis * delta_relative)
		axle_pair_scene_guard_events_v079 += 1
		axle_pair_guard_events_v074 = axle_pair_scene_guard_events_v079


# Restore the exact released v0.5.15 outer-bound predictor for every stop,
# including the first/last hubs in a protected multi-hub segment.
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


# -----------------------------------------------------------------------------
# Post-step synchronous pair projection.
# -----------------------------------------------------------------------------

func _project_group_positions_v079(state: Dictionary) -> Array:
	var positions: Array = (state.get("positions", []) as Array).duplicate()
	var masses: Array = state.get("masses", []) as Array
	var lower: float = float(state.get("lower", -INF))
	var upper: float = float(state.get("upper", INF))
	if positions.size() <= 1:
		return positions

	for _pass in range(AXLE_PAIR_SOLVER_PASSES_V079):
		var changed := false
		if lower > -INF and float(positions[0]) < lower:
			positions[0] = lower
			changed = true
		var last: int = positions.size() - 1
		if upper < INF and float(positions[last]) > upper:
			positions[last] = upper
			changed = true
		for i in range(positions.size() - 1):
			var gap: float = float(positions[i + 1]) - float(positions[i])
			if gap >= AXLE_PAIR_SEPARATION_V079 - AXLE_PAIR_POSITION_EPS_V079:
				continue
			var correction: float = AXLE_PAIR_SEPARATION_V079 - gap
			var total_mass: float = float(masses[i]) + float(masses[i + 1])
			positions[i] = float(positions[i]) - correction * float(masses[i + 1]) / total_mass
			positions[i + 1] = float(positions[i + 1]) + correction * float(masses[i]) / total_mass
			changed = true
		if not changed:
			break

	# Deterministic feasibility sweeps remove the tiny residual that iterative
	# mass weighting leaves when an outer hub is resting directly on a boundary.
	if lower > -INF:
		positions[0] = maxf(float(positions[0]), lower)
	for i in range(1, positions.size()):
		positions[i] = maxf(float(positions[i]), float(positions[i - 1]) + AXLE_PAIR_SEPARATION_V079)
	if upper < INF:
		var last: int = positions.size() - 1
		positions[last] = minf(float(positions[last]), upper)
		for i in range(last - 1, -1, -1):
			positions[i] = minf(float(positions[i]), float(positions[i + 1]) - AXLE_PAIR_SEPARATION_V079)
	if lower > -INF:
		positions[0] = maxf(float(positions[0]), lower)
		for i in range(1, positions.size()):
			positions[i] = maxf(float(positions[i]), float(positions[i - 1]) + AXLE_PAIR_SEPARATION_V079)
	return positions


func _remove_pair_closing_velocity_v079(state: Dictionary) -> bool:
	var hubs: Array = state.get("hubs", []) as Array
	var axis: Vector3 = state.get("axis", Vector3.ZERO) as Vector3
	var rod := state.get("rod") as RigidBody3D
	if not is_instance_valid(rod):
		return false
	var changed := false
	for _pass in range(AXLE_PAIR_SOLVER_PASSES_V079):
		var pass_changed := false
		for i in range(hubs.size() - 1):
			var low := hubs[i] as Dictionary
			var high := hubs[i + 1] as Dictionary
			var a := low.get("connector") as RigidBody3D
			var b := high.get("connector") as RigidBody3D
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var gap: float = _rod_local_along_v070(b, rod) - _rod_local_along_v070(a, rod)
			if gap > AXLE_PAIR_SEPARATION_V079 + AXLE_PAIR_PREDICT_MARGIN_V079:
				continue
			var va: float = (a.linear_velocity - rod.linear_velocity).dot(axis)
			var vb: float = (b.linear_velocity - rod.linear_velocity).dot(axis)
			if vb >= va:
				continue
			var ma: float = maxf(float(low.get("mass", a.mass)), 0.001)
			var mb: float = maxf(float(high.get("mass", b.mass)), 0.001)
			var common: float = (ma * va + mb * vb) / (ma + mb)
			_shift_component_velocity_scene_v079(low.get("component", []) as Array, axis * (common - va))
			_shift_component_velocity_scene_v079(high.get("component", []) as Array, axis * (common - vb))
			pass_changed = true
			changed = true
		if not pass_changed:
			break
	return changed


func _correct_axle_pairs_v079() -> bool:
	if not simulating:
		return false
	var any_changed := false
	for group_value in axle_component_groups_v076:
		var state: Dictionary = _group_state_v079(group_value as Dictionary)
		if state.is_empty():
			continue
		var hubs: Array = state.get("hubs", []) as Array
		var axis: Vector3 = state.get("axis", Vector3.ZERO) as Vector3
		var original: Array = state.get("positions", []) as Array
		var target: Array = _project_group_positions_v079(state)
		var projected := false
		for i in range(hubs.size()):
			var delta_along: float = float(target[i]) - float(original[i])
			if absf(delta_along) <= AXLE_PAIR_POSITION_EPS_V079:
				continue
			var hub := hubs[i] as Dictionary
			_translate_component_scene_v079(hub.get("component", []) as Array, axis * delta_along)
			projected = true
			any_changed = true
		if projected:
			axle_pair_scene_projection_events_v079 += 1
			axle_pair_projection_events_v074 = axle_pair_scene_projection_events_v079
			# Re-read actual body velocities after the synchronous transform update,
			# then make contact perfectly inelastic only along the axle direction.
			state = _group_state_v079(group_value as Dictionary)
		if _remove_pair_closing_velocity_v079(state):
			any_changed = true
	return any_changed


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_predict_axle_pairs_v079(delta)


func _sync_o_ring_followers_v068() -> void:
	# Inherited v0.5.15 sync first follows the rod and applies finite outer-stop
	# correction. Then repair only adjacent hub penetration synchronously. The
	# projection itself respects the same finite boundaries, so the host rod and
	# O-Rings never need to move.
	super._sync_o_ring_followers_v068()
	_correct_axle_pairs_v079()


func _prepare_stable_simulation_graph() -> void:
	axle_pair_scene_guard_events_v079 = 0
	axle_pair_scene_projection_events_v079 = 0
	super._prepare_stable_simulation_graph()
	# No force callback should survive preparation in this candidate.
	_clear_component_callbacks_v076()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	axle_pair_scene_guard_events_v079 = 0
	axle_pair_scene_projection_events_v079 = 0
	super._restore_o_ring_followers_v068(restore_build_pose)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — protected AXLE hubs stack synchronously outside Jolt contact; O-Ring/rod-end stops and AXLE freedom retain v0.5.15 behavior.")
