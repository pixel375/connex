extends "res://scripts/main_v066.gd"

const VERSION_067 := "0.5.12-dev"

var active_structure_rigidity_v067: float = STRUCTURE_RIGIDITY_DEFAULT_V066
var rigidity_pending_for_next_run_v067: bool = false


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_067)
	_status("Rigidity changes are solver-safe: changes made during SIMULATE apply on the next run; axle slides stay awake under gravity.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_067, text]


func _on_structure_rigidity_v066(value: float) -> void:
	physics_structure_rigidity_v066 = clampf(value, 0.0, 100.0)
	if simulating:
		rigidity_pending_for_next_run_v067 = absf(physics_structure_rigidity_v066 - active_structure_rigidity_v067) > 0.01
	else:
		_apply_structure_rigidity_to_softened_v066()
		rigidity_pending_for_next_run_v067 = false
	_refresh_physics_labels_v050()
	_save_settings()
	if simulating:
		_status("Structure Rigidity set to %d%% — applies next SIMULATE; current run remains %d%%" % [int(round(physics_structure_rigidity_v066)), int(round(active_structure_rigidity_v067))])


func _refresh_physics_labels_v050() -> void:
	super._refresh_physics_labels_v050()
	if physics_structure_rigidity_label_v066 == null:
		return
	if simulating and rigidity_pending_for_next_run_v067:
		physics_structure_rigidity_label_v066.text += " — NEXT RUN (current %d%%)" % int(round(active_structure_rigidity_v067))


func _reset_physics_v050() -> void:
	if not simulating:
		super._reset_physics_v050()
		rigidity_pending_for_next_run_v067 = false
		return
	physics_gravity_v050 = 9.81
	physics_friction_v050 = 0.72
	physics_bounce_v050 = 0.04
	physics_linear_damp_v050 = 0.20
	physics_angular_damp_v050 = 0.34
	physics_structure_rigidity_v066 = STRUCTURE_RIGIDITY_DEFAULT_V066
	_apply_physics_settings_v050()
	var slider: HSlider = physics_sliders_v054.get("Structure rigidity") as HSlider
	if slider != null:
		slider.set_value_no_signal(physics_structure_rigidity_v066)
	rigidity_pending_for_next_run_v067 = absf(physics_structure_rigidity_v066 - active_structure_rigidity_v067) > 0.01
	_refresh_physics_labels_v050()
	_save_settings()
	_status("Physics defaults restored; Structure Rigidity %d%% applies next SIMULATE" % int(round(physics_structure_rigidity_v066)))


func _is_axle_rod_v067(body: RigidBody3D) -> bool:
	if not is_instance_valid(body) or str(body.get_meta("kind", "")) != "rod" or not body.has_meta("axle_connector"):
		return false
	var connector := body.get_meta("axle_connector") as RigidBody3D
	return is_instance_valid(connector)


func _wake_axle_rods_v067() -> int:
	var count := 0
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not _is_axle_rod_v067(body):
			continue
		body.can_sleep = false
		body.freeze = false
		body.sleeping = false
		count += 1
	return count


func _restore_body_sleep_policy_v067() -> void:
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if is_instance_valid(body):
			body.can_sleep = true


func _release_physics() -> void:
	active_structure_rigidity_v067 = physics_structure_rigidity_v066
	rigidity_pending_for_next_run_v067 = false
	await super._release_physics()
	if not simulating:
		return
	var axle_count: int = _wake_axle_rods_v067()
	_refresh_physics_labels_v050()
	_status("Physics running — Structure Rigidity %d%%; %d stabilized closed-loop sockets; %d axle slides awake" % [int(round(active_structure_rigidity_v067)), softened_socket_loop_count_v064, axle_count])


func _reset_pose() -> void:
	_restore_body_sleep_policy_v067()
	rigidity_pending_for_next_run_v067 = false
	super._reset_pose()
	_refresh_physics_labels_v050()


func _restore_state(snapshot: Dictionary) -> void:
	_restore_body_sleep_policy_v067()
	rigidity_pending_for_next_run_v067 = false
	super._restore_state(snapshot)


func _restart_build() -> void:
	_restore_body_sleep_policy_v067()
	rigidity_pending_for_next_run_v067 = false
	super._restart_build()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.12 PHYSICS SAFETY: Structure Rigidity is applied when SIMULATE begins. Moving the rigidity slider while physics is already running saves the value for the next run and does not rewrite active joint limits. This prevents the live-limit lock/freeze seen in v0.5.11. Axle rods are also kept awake during simulation so the intentionally free slide axis continues responding to gravity and support/contact changes."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_067) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_067)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
