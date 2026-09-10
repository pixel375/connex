extends "res://scripts/main_v079.gd"

const VERSION_080 := "0.5.16"
const AXLE_SUPPORT_MARGIN_V080 := 0.024


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_080)
	_status("v0.5.16 test runtime — O-Ring-supported AXLE hubs no longer receive pair-closing velocity.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_080, text]


func _pair_velocity_targets_v080(state: Dictionary, delta: float, predictive: bool) -> Dictionary:
	var hubs: Array = state.get("hubs", []) as Array
	var positions: Array = state.get("positions", []) as Array
	var source_velocities: Array = state.get("velocities", []) as Array
	var masses: Array = state.get("masses", []) as Array
	if hubs.size() <= 1 or positions.size() != hubs.size() or source_velocities.size() != hubs.size():
		return {"changed": false, "velocities": source_velocities}
	var velocities: Array = source_velocities.duplicate()
	var lower: float = float(state.get("lower", -INF))
	var upper: float = float(state.get("upper", INF))
	var last: int = hubs.size() - 1
	var contact_limit: float = AXLE_PAIR_SEPARATION_V079 + AXLE_PAIR_PREDICT_MARGIN_V079

	# A finite rod-end/O-Ring boundary is an infinite-mass support only along the
	# forbidden axial direction. This prevents the adjacent pair solver from
	# undoing the already-safe outer-stop velocity on the very same frame.
	var lower_supported: Array[bool] = []
	var upper_supported: Array[bool] = []
	lower_supported.resize(hubs.size())
	upper_supported.resize(hubs.size())
	for i in range(hubs.size()):
		lower_supported[i] = false
		upper_supported[i] = false
	if lower > -INF and float(positions[0]) <= lower + AXLE_SUPPORT_MARGIN_V080:
		lower_supported[0] = true
		if float(velocities[0]) < 0.0:
			velocities[0] = 0.0
	if upper < INF and float(positions[last]) >= upper - AXLE_SUPPORT_MARGIN_V080:
		upper_supported[last] = true
		if float(velocities[last]) > 0.0:
			velocities[last] = 0.0

	# Propagate support only through hubs that are actually touching/near-touching.
	for i in range(1, hubs.size()):
		var gap: float = float(positions[i]) - float(positions[i - 1])
		lower_supported[i] = lower_supported[i - 1] and gap <= contact_limit
	for i in range(last - 1, -1, -1):
		var gap: float = float(positions[i + 1]) - float(positions[i])
		upper_supported[i] = upper_supported[i + 1] and gap <= contact_limit

	var changed := false
	for _pass in range(AXLE_PAIR_SOLVER_PASSES_V079):
		var pass_changed := false
		for i in range(hubs.size() - 1):
			var gap: float = float(positions[i + 1]) - float(positions[i])
			var va: float = float(velocities[i])
			var vb: float = float(velocities[i + 1])
			var relative: float = vb - va
			if relative >= -0.000001:
				continue
			var contact_active: bool = gap <= contact_limit
			if predictive:
				contact_active = contact_active or gap + relative * delta < contact_limit
			if not contact_active:
				continue

			if lower_supported[i] and upper_supported[i + 1]:
				# A fully bracketed touching chain has no legal closing motion relative
				# to the host rod. Remove only the conflicting axial component.
				velocities[i] = 0.0
				velocities[i + 1] = 0.0
			elif lower_supported[i]:
				# Lower hub is supported by an O-Ring/rod end. Never push it back
				# into that boundary; make the incoming upper hub match it instead.
				velocities[i + 1] = va
			elif upper_supported[i + 1]:
				# Symmetric case for a stack pressing upward into its upper stop.
				velocities[i] = vb
			else:
				# Free-floating collision: preserve axial component momentum.
				var ma: float = maxf(float(masses[i]), 0.001)
				var mb: float = maxf(float(masses[i + 1]), 0.001)
				var common: float = (ma * va + mb * vb) / (ma + mb)
				velocities[i] = common
				velocities[i + 1] = common
			pass_changed = true
			changed = true
		if not pass_changed:
			break

	# Re-assert finite-bound directions after pair resolution. This is the key
	# invariant v079 violated by giving the supported hub a closing velocity.
	if lower_supported[0] and float(velocities[0]) < 0.0:
		velocities[0] = 0.0
		changed = true
	if upper_supported[last] and float(velocities[last]) > 0.0:
		velocities[last] = 0.0
		changed = true
	return {"changed": changed, "velocities": velocities}


func _apply_pair_velocity_targets_v080(state: Dictionary, targets: Array) -> bool:
	var hubs: Array = state.get("hubs", []) as Array
	var axis: Vector3 = state.get("axis", Vector3.ZERO) as Vector3
	var rod := state.get("rod") as RigidBody3D
	if not is_instance_valid(rod) or targets.size() != hubs.size():
		return false
	var changed := false
	for i in range(hubs.size()):
		var hub := hubs[i] as Dictionary
		var connector := hub.get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			continue
		var current: float = (connector.linear_velocity - rod.linear_velocity).dot(axis)
		var delta_relative: float = float(targets[i]) - current
		if absf(delta_relative) <= 0.0001:
			continue
		_shift_component_velocity_scene_v079(hub.get("component", []) as Array, axis * delta_relative)
		changed = true
	return changed


func _predict_axle_pairs_v079(delta: float) -> void:
	if not simulating or delta <= 0.000001:
		return
	for group_value in axle_component_groups_v076:
		var state: Dictionary = _group_state_v079(group_value as Dictionary)
		if state.is_empty():
			continue
		var result: Dictionary = _pair_velocity_targets_v080(state, delta, true)
		if not bool(result.get("changed", false)):
			continue
		if _apply_pair_velocity_targets_v080(state, result.get("velocities", []) as Array):
			axle_pair_scene_guard_events_v079 += 1
			axle_pair_guard_events_v074 = axle_pair_scene_guard_events_v079


func _remove_pair_closing_velocity_v079(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	var result: Dictionary = _pair_velocity_targets_v080(state, 0.0, false)
	if not bool(result.get("changed", false)):
		return false
	return _apply_pair_velocity_targets_v080(state, result.get("velocities", []) as Array)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — touching AXLE stacks inherit finite-stop support one-way; pair contact cannot feed velocity back through an O-Ring.")
