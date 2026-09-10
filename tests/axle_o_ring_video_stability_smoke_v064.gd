extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("AXLE_ORING_VIDEO_064_SMOKE_FAIL: %s" % message)
	quit(1)


func _along(main: Node, body: Node3D, rod: RigidBody3D) -> float:
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	return (body.global_position - rod.global_position).dot(axis)


func _find_ring_mount(main: Node, ring: RigidBody3D) -> Generic6DOFJoint3D:
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("o_ring_mount", false)):
			continue
		var nodes := main.call("_joint_nodes", joint) as Array
		if nodes[0] == ring or nodes[1] == ring:
			return joint
	return null


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v071.gd"):
		_fail("Main is not using the current runtime")
		return

	var rod := main.call("_make_rod", 4, Vector3(16, 12, 0), Vector3(16, 28, 0)) as RigidBody3D
	var hub := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(16, 22, 0))) as RigidBody3D
	var axle_joint := main.call("_make_axle_joint", hub, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", axle_joint, "axle", hub, rod, -1, 0, 2.0, null, false)
	hub.set_meta("axle_occupied", true)
	hub.set_meta("axle_host_rod", rod)

	# Choose AXLE deliberately. O-Ring placement must still be the same fixed
	# CROSS-style mount and never turn into an AXLE joint itself.
	main.set("attach_mode", 1)
	main.call("_place_o_ring_on_rod", rod, Vector3(16, 18.5, 0))
	var rings := main.get("o_ring_stops") as Array
	if rings.is_empty():
		_fail("O-Ring was not created while AXLE mode was selected")
		return
	var ring := rings[rings.size() - 1] as RigidBody3D
	var mount := _find_ring_mount(main, ring)
	if not is_instance_valid(mount):
		_fail("O-Ring has no fixed CROSS-style host mount")
		return
	if str(mount.get_meta("connection_kind_v020", "")) != "o_ring":
		_fail("O-Ring mount was converted into another connection topology")
		return
	if str(mount.name).begins_with("AxleJoint"):
		_fail("O-Ring incorrectly received an AXLE joint")
		return

	main.call("_rebuild_connection_graph_v020")
	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	if mount.node_a.is_empty() or mount.node_b.is_empty():
		_fail("reported-video fixture detached the O-Ring mount")
		return
	if not (main.get("o_ring_followers_v068") as Array).is_empty() or not (main.get("axle_stop_ranges_v070") as Array).is_empty():
		_fail("reported-video fixture still uses a follower or coordinate stop")
		return
	if ring.freeze or ring.collision_layer == 0 or ring.collision_mask == 0:
		_fail("reported-video fixture made O-Ring collisionless/kinematic")
		return
	if bool(axle_joint.get("linear_limit_y/enabled")) or bool(axle_joint.get("angular_limit_y/enabled")):
		_fail("normal AXLE slide/rotation was modified")
		return

	# Reverse-motion regression: hold the AXLE connector in world space and drive
	# the rod (with its fixed O-Ring) through it. Real contact must stop the rod
	# before the O-Ring can cross the connector. This catches the old proxy/follower
	# bug from the opposite relative-motion direction.
	hub.freeze = true
	hub.linear_velocity = Vector3.ZERO
	hub.angular_velocity = Vector3.ZERO
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	rod.freeze = false
	rod.linear_velocity = axis * 7.0
	rod.angular_velocity = Vector3.ZERO
	rod.sleeping = false
	ring.linear_velocity = rod.linear_velocity
	ring.angular_velocity = Vector3.ZERO
	ring.sleeping = false
	var ring_local_start := rod.global_transform.affine_inverse() * ring.global_transform
	var min_gap := INF
	var max_mount_drift := 0.0
	for frame_index in range(180):
		await physics_frame
		var gap := _along(main, hub, rod) - _along(main, ring, rod)
		min_gap = minf(min_gap, gap)
		var expected := rod.global_transform * ring_local_start
		var drift := ring.global_position.distance_to(expected.origin)
		max_mount_drift = maxf(max_mount_drift, drift)
		if gap < -0.10:
			_fail("moving rod carried O-Ring through AXLE connector at frame %d (gap %.3f)" % [frame_index, gap])
			return
		if drift > 0.18:
			_fail("O-Ring stopped being pinned to moving rod at frame %d (drift %.3f)" % [frame_index, drift])
			return

	main.call("_toggle_simulation")
	for _i in range(4):
		await physics_frame
	if mount.node_a.is_empty() or mount.node_b.is_empty():
		_fail("fixed O-Ring mount disappeared after simulation")
		return
	if not ring.freeze:
		_fail("O-Ring did not return to BUILD freeze state")
		return

	print("AXLE_ORING_VIDEO_064_SMOKE_OK: moving host rod and physical O-Ring could not pass through a stationary AXLE hub; min_gap=%.3f mount_drift=%.3f" % [min_gap, max_mount_drift])
	main.queue_free()
	await process_frame
	quit(0)
