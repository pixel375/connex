extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
# Base construction collision channels are ground=1, rods=2, connectors=4.
# O-Ring stopping uses two simulation-only channels so the ring can hit only
# axle hubs on its own guide without colliding with rods/spokes/ground.
const O_RING_STOP_LAYER_V069 := 8
const AXLE_STOP_TARGET_LAYER_V069 := 16

var o_ring_stop_pair_count_v069: int = 0
var o_ring_stop_connector_restore_v069: Array = []
var o_ring_stop_ring_restore_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops now use a dedicated kinematic stopper collision against axle hubs.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# v0.5.13 copied the O-Ring shape into the axle rod. That could never stop the
# axle hub because the axle joint intentionally excludes hub-vs-host-rod
# collision. Keep that broken proxy path permanently disabled.
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


func _restore_o_ring_followers_v068(restore_build_pose: bool = true) -> void:
	# Restore axle-hub channels before inherited BUILD restoration. Preserve the
	# ring's original freeze mode/CCD because v0.5.14 temporarily turns the frozen
	# visual follower into a kinematic collision body during SIMULATE.
	_restore_o_ring_stop_connectors_v069()
	var ring_states: Array = o_ring_stop_ring_restore_v069.duplicate()
	o_ring_stop_ring_restore_v069.clear()
	super._restore_o_ring_followers_v068(restore_build_pose)
	for value in ring_states:
		var state := value as Dictionary
		var ring := state.get("ring") as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.freeze_mode = int(state.get("freeze_mode", RigidBody3D.FREEZE_MODE_STATIC)) as RigidBody3D.FreezeMode
		ring.continuous_cd = bool(state.get("continuous_cd", false))


func _configure_o_ring_stoppers_v069() -> int:
	_restore_o_ring_stop_connectors_v069()
	o_ring_stop_ring_restore_v069.clear()
	var configured_pairs := 0
	var configured_connectors: Dictionary = {}

	# v0.5.13 has already detached each O-Ring's hard 6DOF weld and reparented the
	# visible ring to its host axle as a frozen follower. FREEZE_MODE_KINEMATIC is
	# specifically intended for a frozen RigidBody moved by code: unlike STATIC it
	# collides with bodies along its path. Reuse the real O-Ring cylinder collider
	# rather than manufacturing another rigid body or another constraint.
	for follower_value in o_ring_followers_v068:
		var follower := follower_value as Dictionary
		var ring := follower.get("ring") as RigidBody3D
		var rod := follower.get("rod") as RigidBody3D
		if not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		o_ring_stop_ring_restore_v069.append({
			"ring": ring,
			"freeze_mode": ring.freeze_mode,
			"continuous_cd": ring.continuous_cd,
		})
		ring.freeze = true
		ring.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		ring.collision_layer = O_RING_STOP_LAYER_V069
		ring.collision_mask = AXLE_STOP_TARGET_LAYER_V069
		ring.continuous_cd = false
		ring.sleeping = false

		# Only connectors that are actually axle-mounted on this same host rod get
		# the target layer/mask. Fixed spokes and rods never see the stop collider,
		# eliminating the v0.5.13 collision impulse that kicked entire frames.
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


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	_configure_o_ring_stoppers_v069()


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — %d O-Ring/axle-hub stopper pair%s active; O-Rings are kinematic followers, not solver welds" % [
		o_ring_stop_pair_count_v069,
		"" if o_ring_stop_pair_count_v069 == 1 else "s"
	])


func _reset_pose() -> void:
	# super() reaches our overridden _restore_o_ring_followers_v068(), which also
	# restores all temporary collision channels/freeze modes.
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_restore_o_ring_stop_connectors_v069()
	super._restore_state(snapshot)


func _restart_build() -> void:
	_restore_o_ring_stop_connectors_v069()
	super._restart_build()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.14 O-RING STOPPER: the v0.5.13 host-rod collision proxy is removed. During SIMULATE the real O-Ring collider becomes a frozen KINEMATIC follower of its axle and is placed on a dedicated collision channel that only axle-mounted connector hubs use. The hub therefore hits the O-Ring cylinder directly (physical clearance = connector half-thickness + ring half-thickness), while rods, spokes and the floor cannot strike the stopper collider. No extra live rigid body weld and no frame teleport/correction are used."


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
