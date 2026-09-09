extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CHUNK2_SMOKE_FAIL: %s" % message)
	quit(1)


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var runtime_path: String = str(main.get_script().resource_path)
	if not (runtime_path.ends_with("main_v050_hotfix.gd") or runtime_path.ends_with("main_v051.gd") or runtime_path.ends_with("main_v052.gd") or runtime_path.ends_with("main_v053.gd") or runtime_path.ends_with("main_v054.gd") or runtime_path.ends_with("main_v055.gd") or runtime_path.ends_with("main_v056.gd")):
		_fail("Main scene is not using a validated v0.5.x runtime")
		return
	if main.get("parts_panel_v050") == null or main.get("builds_panel_v050") == null:
		_fail("parts or saves modal was not created")
		return
	if main.get("parts_button_v050") == null:
		_fail("bottom PARTS button missing")
		return

	# Parts browser should expose every rod as a visible card when the Rod tab is active.
	main.call("_set_parts_tab_v050", 0)
	var parts_grid: GridContainer = main.get("parts_grid_v050") as GridContainer
	var rod_defs: Array = main.get("rod_defs") as Array
	if parts_grid == null or parts_grid.get_child_count() != rod_defs.size():
		_fail("parts browser rod card count mismatch")
		return

	# Primitive meshes of the same dimensions must share the exact same resource.
	var cache_parent: Node3D = Node3D.new()
	main.add_child(cache_parent)
	var material: Material = main.call("_mat", Color(0.4, 0.5, 0.6)) as Material
	var box_a: MeshInstance3D = main.call("_add_box_visual", cache_parent, Vector3(1.25, 0.33, 0.44), Vector3.ZERO, 0.0, material) as MeshInstance3D
	var box_b: MeshInstance3D = main.call("_add_box_visual", cache_parent, Vector3(1.25, 0.33, 0.44), Vector3.ONE, 0.0, material) as MeshInstance3D
	if box_a == null or box_b == null or box_a.mesh != box_b.mesh:
		_fail("identical box visuals did not reuse cached mesh resource")
		return

	# Physics controls must propagate to existing construction bodies.
	var bodies: Array = main.get("bodies") as Array
	if bodies.is_empty():
		_fail("seed body missing")
		return
	var seed: RigidBody3D = bodies[0] as RigidBody3D
	main.set("physics_gravity_v050", 4.905)
	main.set("physics_friction_v050", 0.33)
	main.set("physics_bounce_v050", 0.12)
	main.call("_apply_physics_settings_v050")
	if absf(seed.gravity_scale - 0.5) > 0.01:
		_fail("gravity control did not update body gravity scale")
		return
	if seed.physics_material_override == null or absf(seed.physics_material_override.friction - 0.33) > 0.01:
		_fail("friction control did not propagate to body")
		return

	# Save format must round-trip the complete Variant snapshot without JSON loss.
	var smoke_path: String = "user://connex_v050_smoke.connex"
	var before_count: int = bodies.size()
	var bundle: Dictionary = main.call("_save_bundle_v050", "Smoke") as Dictionary
	if not bool(main.call("_write_variant_file_v050", smoke_path, bundle)):
		_fail("could not write save bundle")
		return
	var loaded_value: Variant = main.call("_read_variant_file_v050", smoke_path)
	if not (loaded_value is Dictionary):
		_fail("saved bundle did not parse back into a Dictionary")
		return
	var loaded: Dictionary = loaded_value as Dictionary
	if int(loaded.get("format", 0)) != 2 or not (loaded.get("snapshot") is Dictionary):
		_fail("save bundle format/snapshot missing after round trip")
		return

	# Mutate construction, then prove load restores the saved body count.
	main.call("_extend_socket", seed, 0)
	await process_frame
	if (main.get("bodies") as Array).size() <= before_count:
		_fail("test mutation did not add a rod")
		return
	if not bool(main.call("_restore_bundle_v050", loaded, "Smoke")):
		_fail("save bundle restore failed")
		return
	await process_frame
	if (main.get("bodies") as Array).size() != before_count:
		_fail("save bundle did not restore original body count")
		return

	# ATTACH index should map the seed body to its connector points and clear dirty state.
	main.set("attach_spatial_dirty_v050", true)
	main.call("_ensure_attach_spatial_index_v050")
	if bool(main.get("attach_spatial_dirty_v050")):
		_fail("attachment spatial index stayed dirty after rebuild")
		return
	bodies = main.get("bodies") as Array
	seed = bodies[0] as RigidBody3D
	var by_body: Dictionary = main.get("attach_points_by_body_v050") as Dictionary
	if not by_body.has(seed.get_instance_id()) or (by_body[seed.get_instance_id()] as Array).is_empty():
		_fail("attachment index has no connector points for seed")
		return

	# Dirty overlay rebuild must settle after one requested refresh.
	main.call("_set_editor_mode_v032", 2, false)
	main.set("attach_overlay_dirty_v050", true)
	main.call("_refresh_attach_points_v032")
	if bool(main.get("attach_overlay_dirty_v050")):
		_fail("attachment overlay did not settle its dirty flag")
		return

	if FileAccess.file_exists(smoke_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(smoke_path))
	cache_parent.queue_free()
	print("CHUNK2_SMOKE_OK: parts browser + save roundtrip + physics + mesh cache + spatial index + dirty overlay")
	main.queue_free()
	await process_frame
	quit(0)
