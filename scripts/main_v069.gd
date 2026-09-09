extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
# Base construction collision channels are ground=1, rods=2, connectors=4.
# O-Ring stopping uses two simulation-only channels so a stop can contact only
# axle-mounted connector hubs on its own guide rod. Rods, spokes and the floor
# never see the stopper collider.
const O_RING_STOP_LAYER_V069 := 8
const AXLE_STOP_TARGET_LAYER_V069 := 16

var o_ring_stop_pair_count_v069: int = 0
var o_ring_stop_connector_restore_v069: Array = []
var o_ring_stop_proxies_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops now use dedicated moving stopper bodies for axle hubs.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# v0.5.13 copied the O-Ring collision shape into the host axle rod. Axle joints
# intentionally exclude connector-vs-host-rod collision, so that shape could
# never stop the hub. Keep the broken host-rod proxy path permanently disabled.
func _add_o_ring_proxy_shapes_v068(_ring: RigidBody3D, _rod: RigidBody3D) -> int:
	return 0


func _restore_o_ring_stop_connectors_v069() -> void:
	for value in o_ring_stop_connector_restore_v069:
		var state := value as Dictionary
		var connector := state.get("connector") as RigidBody3D
		if not is_instance_valid(connector):
			continue
		connector.collision_layer = int(state.get("collision_layer", connector.collision_layer))
		connector.collision_mask = int(state.get("collision_mask", connector.collision_mask))
	o_ring_stop_connector_restore_v069.clear()
	o_ring_stop_pair_count_v069 = 0


func _clear_o_ring_stop_proxies_v069() -> void:
	for value in o_ring_stop_proxies_v069:
		var state := value as Dictionary
		var proxy := state.get("proxy") as AnimatableBody3D
		if is_instance_valid(proxy):
			# Remove collision immediately; queue_free itself is deferred.
			proxy.collision_layer = 0
			proxy.collision_mask = 0
			proxy.queue_free()
	o_ring_stop_proxies_v069.clear()


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	_clear_o_ring_stop_proxies_v069()
	_restore_o_ring_stop_connectors_v069()
	super._restore_o_ring_followers_v068(restore_build_pose)


func _copy_o_ring_shape_to_proxy_v069(ring: RigidBody3D, proxy: AnimatableBody3D) -> int:
	var copied := 0
	for child_value in ring.get_children():
		var source := child_value as CollisionShape3D
		if source == null or source.shape == null or source.disabled:
			continue
		var collision := CollisionShape3D.new()
		collision.name = "O_Ring_Stop_Shape_%d" % copied
		collision.shape = source.shape.duplicate(true)
		collision.transform = source.transform
		proxy.add_child(collision)
		copied += 1
	return copied


func _create_o_ring_stop_proxy_v069(ring: RigidBody3D, rod: RigidBody3D, local_transform: Transform3D) -> AnimatableBody3D:
	var proxy := AnimatableBody3D.new()
	proxy.name = "O_Ring_Stop_Physics_%d" % o_ring_stop_proxies_v069.size()
	proxy.sync_to_physics = true
	proxy.collision_layer = O_RING_STOP_LAYER_V069
	proxy.collision_mask = AXLE_STOP_TARGET_LAYER_V069
	proxy.set_meta("sim_o_ring_stop_proxy_v069", true)
	add_child(proxy)
	proxy.global_transform = rod.global_transform * local_transform
	if _copy_o_ring_shape_to_proxy_v069(ring, proxy) == 0:
		proxy.queue_free()
		return null
	return proxy


func _configure_o_ring_stoppers_v069() -> int:
	_clear_o_ring_stop_proxies_v069()
	_restore_o_ring_stop_connectors_v069()
	var configured_pairs := 0
	var configured_connectors: Dictionary = {}

	# Keep v0.5.13's visible O-Ring exactly as a collisionless frozen child of the
	# host rod. A separate root-level AnimatableBody3D carries only the real ring
	# collision shape. AnimatableBody3D is designed for code-driven moving
	# colliders, so it can follow a dynamic axle without becoming another solver
	# mass or another hard weld in the construction graph.
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		var local_transform := follower.get("local_transform", Transform3D.IDENTITY) as Transform3D
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			continue

		var proxy := _create_o_ring_stop_proxy_v069(ring, rod, local_transform)
		if not is_instance_valid(proxy):
			continue
		o_ring_stop_proxies_v069.append({
			"proxy": proxy,
			"ring": ring,
			"rod": rod,
			"local_transform": local_transform,
		})

		# Only connector hubs actually mounted as AXLE on this same rod get the
		# simulation-only target channel. The attached fixed frame remains on its
		# normal channels and therefore cannot smack the O-Ring proxy sideways.
		for record_value in connections_v020:
			var record := record_value as Dictionary
			if str(record.get("kind", "")) != "axle" or record.get("rod") != rod:
				continue
			var connector := record.get("connector") as RigidBody3D
			if not is_instance_valid(connector):
				continue
			var key := connector.get_instance_id()
			if not configured_connectors.has(key):
				configured_connectors[key] = true
				o_ring_stop_connector_restore_v069.append({
					"connector": connector,
					"collision_layer": connector.collision_layer,
					"collision_mask": connector.collision_mask,
				})
				connector.collision_layer |= AXLE_STOP_TARGET_LAYER_V069
				connector.collision_mask |= O_RING_STOP_LAYER_V069
				connector.continuous_cd = true
				connector.sleeping = false
			configured_pairs += 1

	o_ring_stop_pair_count_v069 = configured_pairs
	return configured_pairs


func _sync_o_ring_stop_proxies_v069() -> void:
	if not simulating:
		return
	for value in o_ring_stop_proxies_v069:
		var state := value as Dictionary
		var proxy := state.get("proxy") as AnimatableBody3D
		var rod := state.get("rod") as RigidBody3D
		if not is_instance_valid(proxy) or not is_instance_valid(rod):
			continue
		var local_transform := state.get("local_transform", Transform3D.IDENTITY) as Transform3D
		proxy.global_transform = rod.global_transform * local_transform


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	_configure_o_ring_stoppers_v069()
	_sync_o_ring_stop_proxies_v069()


func _physics_process(delta: float) -> void:
	# Move the kinematic stop to the current host-rod pose before the next physics
	# solve. AnimatableBody3D derives motion from these physics-tick transforms, so
	# the stopper carries the axle's motion instead of acting like a world anchor.
	_sync_o_ring_stop_proxies_v069()
	super._physics_process(delta)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_sync_o_ring_stop_proxies_v069()
	_status("Physics running — %d O-Ring/axle-hub stopper pair%s active; no O-Ring weld or host-rod collision proxy" % [
		o_ring_stop_pair_count_v069,
		"" if o_ring_stop_pair_count_v069 == 1 else "s"
	])


func _reset_pose() -> void:
	_clear_o_ring_stop_proxies_v069()
	_restore_o_ring_stop_connectors_v069()
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_clear_o_ring_stop_proxies_v069()
	_restore_o_ring_stop_connectors_v069()
	super._restore_state(snapshot)


func _restart_build() -> void:
	_clear_o_ring_stop_proxies_v069()
	_restore_o_ring_stop_connectors_v069()
	super._restart_build()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.14 O-RING STOPPER: the broken v0.5.13 host-rod collision proxy is removed. The visible O-Ring remains a collisionless frozen follower of its axle. During SIMULATE, a root-level AnimatableBody3D duplicates only the O-Ring's real cylinder collision shape and follows the axle every physics tick. A dedicated collision channel lets that moving stop contact only connector hubs mounted on the same axle; rods, spokes and the floor cannot hit it. This restores a real physical stopper without adding another rigid body mass, another hard weld, joint teleporting, or frame correction."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_069) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_069)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
