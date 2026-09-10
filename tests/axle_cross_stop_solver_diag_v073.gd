extends "res://tests/axle_cross_stop_roundtrip_smoke_v072.gd"

# Diagnostic version of the four-post regression. It keeps the exact same
# fixture/save-load path but records the solver state after preflight so a
# visually identical restored build cannot hide a different disabled edge,
# drifting stop mount, or off-axis hub.

func _joint_for_pair_meta(main: Node, kind: String, connector: RigidBody3D, rod: RigidBody3D) -> Joint3D:
	var connector_uid := _uid(connector)
	var rod_uid := _uid(rod)
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint):
			continue
		if str(joint.get_meta("connection_kind_v020", "")) != kind:
			continue
		if int(joint.get_meta("connector_uid_v020", -1)) != connector_uid:
			continue
		if int(joint.get_meta("rod_uid_v020", -1)) != rod_uid:
			continue
		return joint
	return null


func _radial_error(main: Node, hub: RigidBody3D, rod: RigidBody3D) -> float:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	var delta := hub.global_position - rod.global_position
	return (delta - axis * delta.dot(axis)).length()


func _solver_signature(main: Node, fixture: Dictionary, label: String, stop_alongs: Array) -> bool:
	var hubs := fixture.get("hubs") as Array
	var rods := fixture.get("rods") as Array
	var stops := fixture.get("stops") as Array
	for i in range(4):
		var hub := hubs[i] as RigidBody3D
		var rod := rods[i] as RigidBody3D
		var stop := stops[i] as RigidBody3D
		var axle_joint := _joint_for_pair_meta(main, "axle", hub, rod)
		var cross_joint := _joint_for_pair_meta(main, "cross", stop, rod)
		if not is_instance_valid(axle_joint):
			_fail("%s: post-preflight AXLE joint metadata missing for hub %d" % [label, i])
			return false
		if not is_instance_valid(cross_joint):
			_fail("%s: post-preflight CROSS mount joint metadata missing for stop %d" % [label, i])
			return false
		var stop_now := _along(main, stop, rod)
		var stop_drift := absf(stop_now - float(stop_alongs[i]))
		var radial := _radial_error(main, hub, rod)
		var axle_disabled := bool(axle_joint.get_meta("sim_disabled", false))
		var cross_disabled := bool(cross_joint.get_meta("sim_disabled", false))
		print("AXLE_SOLVER_DIAG %s i=%d axle_disabled=%s cross_disabled=%s stop_drift=%.4f radial=%.4f hub_y=%.4f stop_y=%.4f" % [label, i, str(axle_disabled), str(cross_disabled), stop_drift, radial, hub.global_position.y, stop.global_position.y])
		if cross_disabled:
			_fail("%s: CROSS stop mount %d was solver-disabled by preflight" % [label, i])
			return false
		if stop_drift > 0.12:
			_fail("%s: CROSS stop %d drifted on its host before support (%.3f)" % [label, i, stop_drift])
			return false
		if radial > 0.20:
			_fail("%s: AXLE hub %d left its shaft radially after preflight (%.3f)" % [label, i, radial])
			return false
	return true


func _run_fixture(main: Node, fixture: Dictionary, label: String) -> Array:
	var hubs := fixture.get("hubs") as Array
	var rods := fixture.get("rods") as Array
	var stops := fixture.get("stops") as Array
	var start_gaps: Array = []
	var stop_alongs: Array = []
	for i in range(4):
		start_gaps.append(_along(main, hubs[i] as RigidBody3D, rods[i] as RigidBody3D) - _along(main, stops[i] as RigidBody3D, rods[i] as RigidBody3D))
		stop_alongs.append(_along(main, stops[i] as RigidBody3D, rods[i] as RigidBody3D))

	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("%s: simulation did not start" % label)
		return []
	if not _solver_signature(main, fixture, label, stop_alongs):
		return []

	for i in range(4):
		var rod := rods[i] as RigidBody3D
		rod.freeze = true
		rod.linear_velocity = Vector3.ZERO
		rod.angular_velocity = Vector3.ZERO
		var hub := hubs[i] as RigidBody3D
		hub.sleeping = false
		if hub.can_sleep:
			_fail("%s: AXLE hub/fixed frame can still sleep" % label)
			return []
		var stop := stops[i] as RigidBody3D
		if stop in hub.get_collision_exceptions():
			_fail("%s: AXLE hub is collision-excluded from its ordinary CROSS stop" % label)
			return []

	var min_gaps: Array = [INF, INF, INF, INF]
	for frame_index in range(240):
		await physics_frame
		for i in range(4):
			var hub := hubs[i] as RigidBody3D
			var rod := rods[i] as RigidBody3D
			var stop := stops[i] as RigidBody3D
			var gap := _along(main, hub, rod) - _along(main, stop, rod)
			min_gaps[i] = minf(float(min_gaps[i]), gap)
			if gap < 0.05:
				var axle_joint := _joint_for_pair_meta(main, "axle", hub, rod)
				var cross_joint := _joint_for_pair_meta(main, "cross", stop, rod)
				var axle_disabled := bool(axle_joint.get_meta("sim_disabled", false)) if is_instance_valid(axle_joint) else true
				var cross_disabled := bool(cross_joint.get_meta("sim_disabled", false)) if is_instance_valid(cross_joint) else true
				var stop_drift := absf(_along(main, stop, rod) - float(stop_alongs[i]))
				var radial := _radial_error(main, hub, rod)
				_fail("%s: AXLE hub %d passed through Gray 1-way CROSS stop at frame %d (gap %.3f; axle_disabled=%s cross_disabled=%s stop_drift=%.3f radial=%.3f)" % [label, i, frame_index, gap, str(axle_disabled), str(cross_disabled), stop_drift, radial])
				return []

	var end_gaps: Array = []
	for i in range(4):
		var end_gap := _along(main, hubs[i] as RigidBody3D, rods[i] as RigidBody3D) - _along(main, stops[i] as RigidBody3D, rods[i] as RigidBody3D)
		end_gaps.append(end_gap)
		var travel := float(start_gaps[i]) - end_gap
		if travel < 1.0:
			_fail("%s: AXLE hub %d remained stuck instead of sliding (travel %.3f)" % [label, i, travel])
			return []

	main.call("_toggle_simulation")
	for _i in range(5):
		await physics_frame
	if bool(main.get("simulating")):
		_fail("%s: failed to return to BUILD" % label)
		return []
	return end_gaps
