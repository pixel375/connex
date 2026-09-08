extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("SELECTION_SMOKE_FAIL: %s" % message)
	quit(1)


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var bodies_value: Variant = main.get("bodies")
	if not (bodies_value is Array) or (bodies_value as Array).is_empty():
		_fail("runtime did not create the seed piece")
		return
	var bodies: Array = bodies_value as Array
	var seed: RigidBody3D = bodies[0] as RigidBody3D
	if not is_instance_valid(seed):
		_fail("seed connector is invalid")
		return
	var seed_type_before: int = int(seed.get_meta("connector_type", -1))

	var o_ring_index: int = int(main.get("o_ring_index"))
	var defs_value: Variant = main.get("connector_defs")
	if not (defs_value is Array):
		_fail("connector definitions missing")
		return
	var defs: Array = defs_value as Array
	if o_ring_index < 0 or o_ring_index >= defs.size():
		_fail("O-Ring index is not present in the connector list")
		return
	var ring_def: Dictionary = defs[o_ring_index] as Dictionary
	if str(ring_def.get("name", "")) != "O-Ring Stop":
		_fail("O-Ring connector-list entry has the wrong name")
		return

	main.call("_deselect_piece_v039", false)
	await process_frame
	var selected_value: Variant = main.get("selected_piece")
	if selected_value != null and is_instance_valid(selected_value):
		_fail("explicit Deselect Piece did not clear selected_piece")
		return

	# With nothing selected, cycling Conn must change only the future choice and
	# must be able to reach the special O-Ring Stop entry without mutating the seed.
	var reached_o_ring: bool = false
	for _i in range(defs.size() + 1):
		if int(main.get("selected_connector_type")) == o_ring_index:
			reached_o_ring = true
			break
		main.call("_change_connector_type", 1)
		await process_frame
	if not reached_o_ring and int(main.get("selected_connector_type")) == o_ring_index:
		reached_o_ring = true
	if not reached_o_ring:
		_fail("Conn selector could not reach O-Ring Stop while nothing was selected")
		return
	if int(seed.get_meta("connector_type", -1)) != seed_type_before:
		_fail("future connector selection changed the existing seed connector")
		return
	selected_value = main.get("selected_piece")
	if selected_value != null and is_instance_valid(selected_value):
		_fail("cycling future connector choices re-selected an existing piece")
		return

	var connector_label_value: Variant = main.get("connector_label")
	if connector_label_value is Label:
		var connector_label: Label = connector_label_value as Label
		if connector_label.text.find("O-Ring Stop") < 0 or connector_label.text.find("NEXT") < 0:
			_fail("bottom connector label does not clearly show NEXT O-Ring Stop")
			return

	# Prove the selected future O-Ring can actually be created on axle geometry.
	main.call("_set_selected", seed)
	main.call("_insert_axle", seed)
	await process_frame
	bodies_value = main.get("bodies")
	bodies = bodies_value as Array
	if bodies.is_empty():
		_fail("axle insertion produced no rod")
		return
	var axle_rod: RigidBody3D = bodies[bodies.size() - 1] as RigidBody3D
	if not is_instance_valid(axle_rod) or str(axle_rod.get_meta("kind", "")) != "rod":
		_fail("axle insertion did not create a rod")
		return
	main.call("_deselect_piece_v039", false)
	main.set("selected_connector_type", o_ring_index)
	main.call("_place_o_ring_on_rod", axle_rod, axle_rod.global_position)
	await process_frame
	var rings_value: Variant = main.get("o_ring_stops")
	if not (rings_value is Array) or (rings_value as Array).is_empty():
		_fail("O-Ring Stop did not place on a valid axle rod")
		return

	print("SELECTION_SMOKE_OK: deselect + future palette + O-Ring Stop")
	main.queue_free()
	await process_frame
	quit(0)
