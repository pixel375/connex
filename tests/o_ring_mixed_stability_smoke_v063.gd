extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ORING_STABILITY_063_SMOKE_FAIL: %s" % message)
	quit(1)


func _along(main: Node, body: Node3D, rod: RigidBody3D) -> float:
	var axis := main.call("_rod_axis_v020", rod) as Vector3
	return (body.global_position - rod.global_position).dot(axis.normalized())


func _find_ring_mount(main: Node, ring: RigidBody3D) -> Generic6DOFJoint3D:
	for joint_value in (main.get("joints") as Array):
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint):
			continue
		if not bool(joint.get_meta("o_ring_mount", false)):
			continue
		var nodes := main.call("_joint_nodes", joint) as Array
		if nodes[0] == ring or nodes[1] == ring:
			return joint
	return null


func _has_live_collision_shape(body: RigidBody3D) -> bool:
	for child_value in body.get_children():
		var shape := child_value as CollisionShape3D
		if shape != null and shape.shape != null and not shape.disabled:
			return true
	return false


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

	var rod := main.call("_make_rod", 4, Vector3(0, 12, 0), Vector3(0, 28, 0)) as RigidBody3D
	var hub := main.call("_make_connector", 6, Transform3D(Basis.IDENTITY, Vector3(0, 22, 0))) as RigidBody3D
	var axle_joint := main.call("_make_axle_joint", hub, rod) as Generic6DOFJoint3D
	main.call("_tag_connection_v020", axle_joint, "axle", hub, rod, -1, 0, 2.0, null, false)
	hub.set_meta("axle_occupied", true)
	hub.set_meta("axle_host_rod", rod)

	# O-Ring placement is intentionally independent of the selected mode. Use
	# SOCKET here to prove the placement helper still creates the CROSS-only mount.
	main.set("attach_mode", 0)
	main.call("_place_o_ring_on_rod", rod, Vector3(0, 18.5, 0))
	var rings := main.get("o_ring_stops") as Array
	if rings.is_empty():
		_fail("O-Ring was not created")
		return
	var ring := rings[rings.size() - 1] as RigidBody3D
	var mount := _find_ring_mount(main, ring)
	if not is_instance_valid(mount):
		_fail("O-Ring does not have its normal fixed mount")
		return
	if mount.node_a.is_empty() or mount.node_b.is_empty():
		_fail("O-Ring fixed mount started detached")
		return
	if not bool(ring.get_meta("cross_mount", false)) or ring.get_meta("cross_host_rod", null) != rod:
		_fail("O-Ring is not tagged as a hard-coded CROSS mount")
		return
	if ring.collision_layer != 2 or ring.collision_mask != 3 or not _has_live_collision_shape(ring):
		_fail("O-Ring real collision body is not active in BUILD")
		return
	if bool(axle_joint.get("linear_limit_y/enabled")) or bool(axle_joint.get("angular_limit_y/enabled")):
		_fail("normal AXLE freedom was changed before simulation")
		return

	# BUILD movement must move the O-Ring and its fixed-joint anchor together.
	main.call("_set_selected", ring)
	var before_along := _along(main, ring, rod)
	main.call("_slide_selected_on_axle", 0.50)
	var after_along := _along(main, ring, rod)
	if absf((after_along - before_along) - 0.50) > 0.04:
		_fail("O-Ring did not move 0.50 along its host shaft")
		return
	if absf(float(mount.get_meta("host_along_v020", after_along)) - after_along) > 0.04:
		_fail("O-Ring joint metadata did not move with the ring")
		return

	main.call("_rebuild_connection_graph_v020")
	main.call("_toggle_simulation")
	for _i in range(12):
		await physics_frame
	if not bool(main.get("simulating")):
		_fail("simulation did not start")
		return
	if not (main.get("o_ring_followers_v068") as Array).is_empty():
		_fail("legacy O-Ring follower machinery is still active")
		return
	if not (main.get("axle_stop_ranges_v070") as Array).is_empty():
		_fail("legacy coordinate AXLE-stop solver is still active")
		return
	if mount.node_a.is_empty() or mount.node_b.is_empty():
		_fail("SIMULATE detached the O-Ring fixed CROSS-style mount")
		return
	if ring.freeze:
		_fail("O-Ring is not participating as a normal physical body")
		return
	if ring.collision_layer != 2 or ring.collision_mask != 3 or not _has_live_collision_shape(ring):
		_fail("SIMULATE disabled the real O-Ring collider")
		return
	if bool(axle_joint.get("linear_limit_y/enabled")) or bool(axle_joint.get("angular_limit_y/enabled")):
		_fail("O-Ring fix rewrote the normal free AXLE joint")
		return

	# Direct regression for the reported failure: hold the host rod, drive a free
	# AXLE hub down its shaft, and require the hub to stop on physical O-Ring contact
	# rather than crossing to the other side. There is no coordinate clamp here.
	rod.freeze = true
	rod.linear_velocity = Vector3.ZERO
	rod.angular_velocity = Vector3.ZERO
	ring.sleeping = false
	var axis := (main.call("_rod_axis_v020", rod) as Vector3).normalized()
	hub.global_position = ring.global_position + axis * 2.0
	hub.linear_velocity = axis * -7.0
	hub.angular_velocity = Vector3.ZERO
	hub.sleeping = false
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
			_fail("AXLE connector phased through physical O-Ring at frame %d (gap %.3f)" % [frame_index, gap])
			return
		if drift > 0.16:
			_fail("O-Ring pulled away from its fixed host mount at frame %d (drift %.3f)" % [frame_index, drift])
			return

	main.call("_toggle_simulation")
	for _i in range(4):
		await physics_frame
	if mount.node_a.is_empty() or mount.node_b.is_empty():
		_fail("O-Ring mount was not preserved on return to BUILD")
		return
	if not ring.freeze:
		_fail("O-Ring did not return to editable BUILD state")
		return

	print("ORING_STABILITY_063_SMOKE_OK: simple CROSS-style O-Ring mount stayed pinned and its real collider stopped a free AXLE hub; min_gap=%.3f mount_drift=%.3f" % [min_gap, max_mount_drift])
	main.queue_free()
	await process_frame
	quit(0)
