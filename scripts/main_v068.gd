extends "res://scripts/main_v067.gd"

const VERSION_068 := "0.5.13-dev"
const RUNAWAY_LINEAR_TRIGGER_V068 := 42.0
const RUNAWAY_ANGULAR_TRIGGER_V068 := 55.0
const RUNAWAY_LINEAR_RECOVER_V068 := 18.0
const RUNAWAY_ANGULAR_RECOVER_V068 := 24.0

var runaway_guard_events_v068: int = 0
var runaway_guard_last_status_ms_v068: int = 0


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_068)
	_status("O-Ring Stops now release with the rest of the build in SIMULATE; mixed-joint stability guard is active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_068, text]


func _release_o_rings_v068() -> int:
	var released := 0
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		ring.freeze = false
		ring.sleeping = false
		ring.can_sleep = false
		released += 1
	return released


func _restore_o_rings_build_v068() -> void:
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.can_sleep = true
		ring.freeze = true
		ring.sleeping = false
		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		if ring.has_meta("build_transform"):
			ring.global_transform = ring.get_meta("build_transform") as Transform3D


# A circular O-Ring needs all translation and tilt constrained, but axial spin is
# physically irrelevant. Align its 6DOF frame to the host rod and remove that
# redundant sixth weld constraint.
func _prepare_o_ring_joints_v068() -> int:
	_rebuild_connection_graph_v020()
	var tuned := 0
	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "o_ring":
			continue
		var joint := record.get("joint") as Generic6DOFJoint3D
		var ring := record.get("ring") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		if not is_instance_valid(joint) or not is_instance_valid(ring) or not is_instance_valid(rod):
			continue
		var axis := _rod_axis_v020(rod).normalized()
		if axis.length_squared() < 0.5:
			continue
		var basis := Basis(Quaternion(Vector3.UP, axis)).orthonormalized()
		joint.global_transform = Transform3D(basis, ring.global_position)
		for axis_name in ["x", "y", "z"]:
			joint.set("linear_limit_%s/enabled" % axis_name, true)
			joint.set("linear_limit_%s/lower_distance" % axis_name, 0.0)
			joint.set("linear_limit_%s/upper_distance" % axis_name, 0.0)
		for axis_name in ["x", "z"]:
			joint.set("angular_limit_%s/enabled" % axis_name, true)
			joint.set("angular_limit_%s/lower_angle" % axis_name, 0.0)
			joint.set("angular_limit_%s/upper_angle" % axis_name, 0.0)
		joint.set("angular_limit_y/enabled", false)
		joint.exclude_nodes_from_collision = true
		joint.set_meta("sim_o_ring_axis_joint_v068", true)
		tuned += 1
	if tuned > 0:
		_rebind_all_joints()
	return tuned


func _prepare_o_ring_collision_groups_v068() -> void:
	_rebuild_connection_graph_v020()
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		var component: Array = _fixed_component_v020(ring, -1)
		for other_value in component:
			var other := other_value as RigidBody3D
			if is_instance_valid(other) and other != ring:
				_add_simulation_collision_exception(ring, other)


# Long thin rods can move farther than their radius in one 60 Hz step during a
# fall. Continuous collision detection prevents a ground impact from beginning as
# a deep penetration which the joint solver then has to correct explosively.
func _set_simulation_ccd_v068(enabled: bool) -> void:
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			body.continuous_cd = enabled
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if is_instance_valid(ring):
			ring.continuous_cd = enabled


func _prepare_stable_simulation_graph() -> void:
	super._prepare_stable_simulation_graph()
	_prepare_o_ring_joints_v068()
	_prepare_o_ring_collision_groups_v068()
	_set_simulation_ccd_v068(true)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	var ring_count: int = _release_o_rings_v068()
	_status("Physics running — Structure Rigidity %d%%; %d axle slides awake; %d O-Ring Stop%s dynamic" % [
		int(round(active_structure_rigidity_v067)),
		_wake_axle_rods_v067(),
		ring_count,
		"" if ring_count == 1 else "s"
	])


func _reset_pose() -> void:
	_set_simulation_ccd_v068(false)
	super._reset_pose()
	_restore_o_rings_build_v068()


func _restore_state(snapshot: Dictionary) -> void:
	_set_simulation_ccd_v068(false)
	super._restore_state(snapshot)
	_restore_o_rings_build_v068()


func _restart_build() -> void:
	_set_simulation_ccd_v068(false)
	super._restart_build()
	_restore_o_rings_build_v068()


func _guard_body_energy_v068(body: RigidBody3D) -> bool:
	if not is_instance_valid(body) or body.freeze:
		return false
	var linear_speed := body.linear_velocity.length()
	var angular_speed := body.angular_velocity.length()
	if linear_speed <= RUNAWAY_LINEAR_TRIGGER_V068 and angular_speed <= RUNAWAY_ANGULAR_TRIGGER_V068:
		return false
	if linear_speed > RUNAWAY_LINEAR_RECOVER_V068:
		body.linear_velocity = body.linear_velocity.normalized() * RUNAWAY_LINEAR_RECOVER_V068
	if angular_speed > RUNAWAY_ANGULAR_RECOVER_V068:
		body.angular_velocity = body.angular_velocity.normalized() * RUNAWAY_ANGULAR_RECOVER_V068
	body.sleeping = false
	return true


func _guard_simulation_energy_v068() -> bool:
	if not simulating:
		return false
	var tripped := false
	for body_value in bodies:
		tripped = _guard_body_energy_v068(body_value as RigidBody3D) or tripped
	for ring_value in o_ring_stops:
		tripped = _guard_body_energy_v068(ring_value as RigidBody3D) or tripped
	if not tripped:
		return false
	runaway_guard_events_v068 += 1
	var now := Time.get_ticks_msec()
	if now - runaway_guard_last_status_ms_v068 > 700:
		runaway_guard_last_status_ms_v068 = now
		_status("Stability guard damped a pathological solver-energy spike; build connections remain intact.")
	return true


func _physics_process(_delta: float) -> void:
	_guard_simulation_energy_v068()


func _process(delta: float) -> void:
	super._process(delta)


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.13 O-RINGS / STABILITY: O-Ring Stops are no longer left frozen when SIMULATE begins. They release with their host construction and return to their saved BUILD pose on Restore. Their joint is aligned to the host rod and leaves only physically irrelevant axial spin free. O-Rings participate in fixed-component self-collision suppression. SIMULATE enables continuous collision detection for the thin construction pieces, and the project uses higher constraint-solver iteration counts so hard ground impacts are resolved without injecting runaway energy. A physics-tick stability guard remains as a last resort for pathological solver spikes."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_068) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_068)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
