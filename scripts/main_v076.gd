extends "res://scripts/main_v075.gd"

const VERSION_076 := "0.5.16"
const AXLE_STACK_SEPARATION_V076 := AXLE_CONNECTOR_HALF_V070 * 2.0
const AXLE_STACK_PREDICT_MARGIN_V076 := 0.018
const AXLE_STACK_POSITION_EPS_V076 := 0.001
const AXLE_STACK_SOLVER_PASSES_V076 := 8

var axle_component_groups_v076: Array = []
var axle_component_commands_v076: Dictionary = {}
var axle_component_callback_bodies_v076: Array = []
var axle_guarded_hubs_v076: Dictionary = {}
var axle_component_guard_events_v076: int = 0
var axle_component_projection_events_v076: int = 0
var axle_component_invalid_groups_v076: int = 0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_076)
	_status("v0.5.16 test runtime — multi-hub O-Ring stacks are guarded outside the Jolt joint/contact graph.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_076, text]


# v075 showed that hard Y limits on the existing Generic6DOF AXLE can itself
# become an unstable closed-loop constraint under a loaded spoke assembly. Keep
# every normal AXLE's Y slide/rotation exactly as authored.
func _apply_native_rank_limits_v075() -> int:
	_restore_native_rank_limits_v075(false)
	return 0


func _component_mass_v076(component: Array) -> float:
	var total := 0.0
	for value in component:
		var body := value as RigidBody3D
		if is_instance_valid(body):
			total += maxf(body.mass, 0.001)
	return maxf(total, 0.001)


func _component_ids_v076(component: Array) -> Dictionary:
	var ids: Dictionary = {}
	for value in component:
		var body := value as RigidBody3D
		if is_instance_valid(body):
			ids[body.get_instance_id()] = true
	return ids


func _components_overlap_v076(a: Array, b: Array) -> bool:
	var ids := _component_ids_v076(a)
	for value in b:
		var body := value as RigidBody3D
		if is_instance_valid(body) and ids.has(body.get_instance_id()):
			return true
	return false


func _register_component_callback_v076(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return
	var body_id := body.get_instance_id()
	for value in axle_component_callback_bodies_v076:
		var existing := value as RigidBody3D
		if is_instance_valid(existing) and existing.get_instance_id() == body_id:
			return
	PhysicsServer3D.body_set_force_integration_callback(
		body.get_rid(),
		Callable(self, "_integrate_axle_component_v076"),
		body_id
	)
	axle_component_callback_bodies_v076.append(body)


func _clear_component_callbacks_v076() -> void:
	for value in axle_component_callback_bodies_v076:
		var body := value as RigidBody3D
		if is_instance_valid(body):
			PhysicsServer3D.body_set_force_integration_callback(body.get_rid(), Callable())
	axle_component_callback_bodies_v076.clear()
	axle_component_commands_v076.clear()


func _integrate_axle_component_v076(state: PhysicsDirectBodyState3D, body_id: int) -> void:
	if not axle_component_commands_v076.has(body_id):
		return
	var command := axle_component_commands_v076[body_id] as Dictionary
	var shift: Vector3 = command.get("shift", Vector3.ZERO) as Vector3
	var delta_velocity: Vector3 = command.get("delta_velocity", Vector3.ZERO) as Vector3
	if shift.length_squared() > 0.0000000001:
		var transform := state.transform
		transform.origin += shift
		state.transform = transform
	if delta_velocity.length_squared() > 0.0000000001:
		state.linear_velocity += delta_velocity


func _add_component_command_v076(component: Array, shift: Vector3, delta_velocity: Vector3) -> void:
	if shift.length_squared() <= 0.0000000001 and delta_velocity.length_squared() <= 0.0000000001:
		return
	for value in component:
		var body := value as RigidBody3D
		if not is_instance_valid(body) or body.freeze:
			continue
		var body_id := body.get_instance_id()
		var command: Dictionary = axle_component_commands_v076.get(body_id, {
			"shift": Vector3.ZERO,
			"delta_velocity": Vector3.ZERO,
		}) as Dictionary
		command["shift"] = (command.get("shift", Vector3.ZERO) as Vector3) + shift
		command["delta_velocity"] = (command.get("delta_velocity", Vector3.ZERO) as Vector3) + delta_velocity
		axle_component_commands_v076[body_id] = command


func _prepare_component_groups_v076() -> int:
	_clear_component_callbacks_v076()
	axle_component_groups_v076.clear()
	axle_guarded_hubs_v076.clear()
	axle_component_guard_events_v076 = 0
	axle_component_projection_events_v076 = 0
	axle_component_invalid_groups_v076 = 0
	axle_pair_guard_events_v074 = 0
	axle_pair_projection_events_v074 = 0
	axle_pair_collision_exception_count_v074 = 0
	var prepared_hubs := 0

	for group_value in axle_order_groups_v073:
		var source_group := group_value as Dictionary
		var rod := source_group.get("rod") as RigidBody3D
		var hubs: Array = source_group.get("hubs", []) as Array
		if not is_instance_valid(rod) or hubs.size() <= 1 or not _group_has_o_ring_v074(source_group):
			continue

		var guarded_hubs: Array = []
		var valid_group := true
		for hub_value in hubs:
			var hub_info := hub_value as Dictionary
			var connector := hub_info.get("connector") as RigidBody3D
			var stop := _find_stop_v074(rod, connector, int(source_group.get("segment", 0)))
			if not is_instance_valid(connector) or stop.is_empty():
				valid_group = false
				break
			var component: Array = _stop_component_v071(stop)
			if component.is_empty():
				component = [connector]
			for existing_value in guarded_hubs:
				if _components_overlap_v076(component, (existing_value as Dictionary).get("component", []) as Array):
					valid_group = false
					break
			if not valid_group:
				break
			guarded_hubs.append({
				"connector": connector,
				"component": component,
				"mass": _component_mass_v076(component),
				"uid": int(hub_info.get("uid", -1)),
			})

		if not valid_group or guarded_hubs.size() != hubs.size():
			axle_component_invalid_groups_v076 += 1
			continue
		var lower: float = float(source_group.get("lower", -INF))
		var upper: float = float(source_group.get("upper", INF))
		if lower > -INF and upper < INF and upper - lower < AXLE_STACK_SEPARATION_V076 * float(guarded_hubs.size() - 1):
			axle_component_invalid_groups_v076 += 1
			continue

		for i in range(guarded_hubs.size()):
			var guarded := guarded_hubs[i] as Dictionary
			var connector := guarded.get("connector") as RigidBody3D
			axle_guarded_hubs_v076[connector.get_instance_id()] = true
			for member_value in guarded.get("component", []) as Array:
				_register_component_callback_v076(member_value as RigidBody3D)
			prepared_hubs += 1

		# Jolt hub-on-hub contact is the source of the one-step order reversal. The
		# deterministic 1-D stack below replaces only that contact; all other
		# connector/spoke/ground collisions remain ordinary physics.
		for i in range(guarded_hubs.size()):
			for j in range(i + 1, guarded_hubs.size()):
				var a := (guarded_hubs[i] as Dictionary).get("connector") as RigidBody3D
				var b := (guarded_hubs[j] as Dictionary).get("connector") as RigidBody3D
				var before := simulation_collision_pairs.size()
				_add_simulation_collision_exception(a, b)
				if simulation_collision_pairs.size() > before:
					axle_pair_collision_exception_count_v074 += 1

		axle_component_groups_v076.append({
			"rod": rod,
			"hubs": guarded_hubs,
			"lower": lower,
			"upper": upper,
			"segment": int(source_group.get("segment", 0)),
		})

	return prepared_hubs


func _is_guarded_stop_v076(stop: Dictionary) -> bool:
	var connector := stop.get("connector") as RigidBody3D
	return is_instance_valid(connector) and axle_guarded_hubs_v076.has(connector.get_instance_id())


# Keep the released v0.5.15 predictor for all ordinary/single-hub stops. A
# multi-hub O-Ring segment is handled as one deterministic stack instead.
func _predict_axle_stops_v071(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		if _is_guarded_stop_v076(stop):
			continue
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


# Likewise, retain v0.5.15 post-step residual correction only for stops outside
# a guarded multi-hub group. Guarded components are never scene-tree teleported.
func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		if _is_guarded_stop_v076(stop):
			continue
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


func _solve_group_commands_v076(group: Dictionary, delta: float) -> bool:
	var rod := group.get("rod") as RigidBody3D
	var hubs: Array = group.get("hubs", []) as Array
	if not is_instance_valid(rod) or hubs.size() <= 1:
		return false
	var axis: Vector3 = _rod_axis_v020(rod).normalized()
	if axis.length_squared() < 0.5:
		return false
	var rod_axis_velocity := rod.linear_velocity.dot(axis)
	var positions: Array[float] = []
	var velocities: Array[float] = []
	var masses: Array[float] = []
	for hub_value in hubs:
		var hub := hub_value as Dictionary
		var connector := hub.get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			return false
		positions.append(_rod_local_along_v070(connector, rod))
		velocities.append(connector.linear_velocity.dot(axis) - rod_axis_velocity)
		masses.append(maxf(float(hub.get("mass", connector.mass)), 0.001))

	var target_positions := positions.duplicate()
	var target_velocities := velocities.duplicate()
	var lower: float = float(group.get("lower", -INF))
	var upper: float = float(group.get("upper", INF))
	var projected := false

	# Position solve. Because hub-vs-hub collision is excluded, these corrections
	# cannot fight a Jolt contact impulse. They are applied to every body in each
	# fixed component together through direct physics state before integration.
	for _pass in range(AXLE_STACK_SOLVER_PASSES_V076):
		var changed := false
		if lower > -INF and target_positions[0] < lower - AXLE_STACK_POSITION_EPS_V076:
			target_positions[0] = lower
			changed = true
		if upper < INF and target_positions[target_positions.size() - 1] > upper + AXLE_STACK_POSITION_EPS_V076:
			target_positions[target_positions.size() - 1] = upper
			changed = true
		for i in range(target_positions.size() - 1):
			var gap: float = target_positions[i + 1] - target_positions[i]
			if gap >= AXLE_STACK_SEPARATION_V076 - AXLE_STACK_POSITION_EPS_V076:
				continue
			var correction := AXLE_STACK_SEPARATION_V076 - gap
			var total_mass := masses[i] + masses[i + 1]
			target_positions[i] -= correction * masses[i + 1] / total_mass
			target_positions[i + 1] += correction * masses[i] / total_mass
			changed = true
		if not changed:
			break
		projected = true

	# Velocity solve. Use perfectly inelastic 1-D contact for adjacent hubs and
	# dissipative stops at the two segment boundaries. This never adds relative
	# axial energy; it only removes closing speed that would violate the next step.
	for _pass in range(AXLE_STACK_SOLVER_PASSES_V076):
		var changed := false
		if lower > -INF:
			var lower_guard := lower + AXLE_STACK_PREDICT_MARGIN_V076
			var predicted_lower := target_positions[0] + target_velocities[0] * delta
			if target_velocities[0] < 0.0 and predicted_lower < lower_guard:
				target_velocities[0] = maxf(0.0, (lower_guard - target_positions[0]) / maxf(delta, 0.000001))
				changed = true
		if upper < INF:
			var last := target_positions.size() - 1
			var upper_guard := upper - AXLE_STACK_PREDICT_MARGIN_V076
			var predicted_upper := target_positions[last] + target_velocities[last] * delta
			if target_velocities[last] > 0.0 and predicted_upper > upper_guard:
				target_velocities[last] = minf(0.0, (upper_guard - target_positions[last]) / maxf(delta, 0.000001))
				changed = true
		for i in range(target_positions.size() - 1):
			var gap: float = target_positions[i + 1] - target_positions[i]
			var relative: float = target_velocities[i + 1] - target_velocities[i]
			if relative >= 0.0 or gap + relative * delta >= AXLE_STACK_SEPARATION_V076 + AXLE_STACK_PREDICT_MARGIN_V076:
				continue
			var common := (masses[i] * target_velocities[i] + masses[i + 1] * target_velocities[i + 1]) / (masses[i] + masses[i + 1])
			target_velocities[i] = common
			target_velocities[i + 1] = common
			changed = true
		if not changed:
			break

	var guarded := false
	for i in range(hubs.size()):
		var position_delta := target_positions[i] - positions[i]
		var velocity_delta := target_velocities[i] - velocities[i]
		if absf(position_delta) <= AXLE_STACK_POSITION_EPS_V076 and absf(velocity_delta) <= 0.0001:
			continue
		var hub := hubs[i] as Dictionary
		_add_component_command_v076(
			hub.get("component", []) as Array,
			axis * position_delta,
			axis * velocity_delta
		)
		guarded = true
	if guarded:
		axle_component_guard_events_v076 += 1
		axle_pair_guard_events_v074 = axle_component_guard_events_v076
	if projected:
		axle_component_projection_events_v076 += 1
		axle_pair_projection_events_v074 = axle_component_projection_events_v076
	return guarded


func _prepare_axle_component_commands_v076(delta: float) -> void:
	axle_component_commands_v076.clear()
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_component_groups_v076:
		_solve_group_commands_v076(group_value as Dictionary, delta)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_prepare_axle_component_commands_v076(delta)


func _prepare_stable_simulation_graph() -> void:
	_clear_component_callbacks_v076()
	axle_component_groups_v076.clear()
	axle_guarded_hubs_v076.clear()
	super._prepare_stable_simulation_graph()
	axle_ranked_stop_count_v074 = _prepare_component_groups_v076()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_clear_component_callbacks_v076()
	axle_component_groups_v076.clear()
	axle_guarded_hubs_v076.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)


func _reset_pose() -> void:
	_clear_component_callbacks_v076()
	axle_component_groups_v076.clear()
	axle_guarded_hubs_v076.clear()
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_clear_component_callbacks_v076()
	axle_component_groups_v076.clear()
	axle_guarded_hubs_v076.clear()
	super._restore_state(snapshot)


func _restart_build() -> void:
	_clear_component_callbacks_v076()
	axle_component_groups_v076.clear()
	axle_guarded_hubs_v076.clear()
	super._restart_build()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d AXLE hub%s in multi-hub O-Ring segments use direct-state 1-D stacking; normal AXLE joints remain free." % [
		axle_ranked_stop_count_v074,
		"" if axle_ranked_stop_count_v074 == 1 else "s"
	])
