extends "res://scripts/main_v065.gd"

const VERSION_066 := "0.5.11-dev"
const STRUCTURE_RIGIDITY_DEFAULT_V066 := 92.0
const STRUCTURE_FLEX_MAX_DEG_V066 := 18.0
const STRUCTURE_FLEX_MIN_DEG_V066 := 0.35

var physics_structure_rigidity_v066: float = STRUCTURE_RIGIDITY_DEFAULT_V066
var physics_structure_rigidity_label_v066: Label


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_066)
	_status("Structure rigidity control is active; closed-loop sockets keep a small stable angular flex range instead of becoming hinges.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_066, text]


# -----------------------------------------------------------------------------
# Persistent physics setting.
# -----------------------------------------------------------------------------

func _load_settings() -> void:
	super._load_settings()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	physics_structure_rigidity_v066 = clampf(float(cfg.get_value("physics", "structure_rigidity", STRUCTURE_RIGIDITY_DEFAULT_V066)), 0.0, 100.0)


func _save_settings() -> void:
	super._save_settings()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("physics", "structure_rigidity", physics_structure_rigidity_v066)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		_status("Could not save Structure Rigidity (%s)" % error_string(err))


func _structure_flex_angle_rad_v066() -> float:
	if physics_structure_rigidity_v066 <= 0.0:
		return -1.0
	var rigidity01 := clampf(physics_structure_rigidity_v066 / 100.0, 0.0, 1.0)
	# Non-linear mapping gives useful control through the middle of the slider,
	# while the high end quickly approaches a nearly rigid joint without ever
	# returning to the exact zero-slack redundant weld that caused explosions.
	var loose01 := pow(1.0 - rigidity01, 1.35)
	var degrees := lerpf(STRUCTURE_FLEX_MIN_DEG_V066, STRUCTURE_FLEX_MAX_DEG_V066, loose01)
	return deg_to_rad(degrees)


func _structure_flex_angle_deg_v066() -> float:
	var radians := _structure_flex_angle_rad_v066()
	return 180.0 if radians < 0.0 else rad_to_deg(radians)


# -----------------------------------------------------------------------------
# Physics UI.
# -----------------------------------------------------------------------------

func _add_options_sections_v050() -> void:
	super._add_options_sections_v050()
	if options_panel == null:
		return
	var box := _find_first_vbox_v050(options_panel)
	if box == null:
		return
	box.add_child(HSeparator.new())
	box.add_child(_section_label("STRUCTURE RIGIDITY"))
	physics_structure_rigidity_label_v066 = _physics_slider_row_v050(
		box,
		"Structure rigidity",
		0.0,
		100.0,
		1.0,
		physics_structure_rigidity_v066,
		_on_structure_rigidity_v066
	)
	var explanation := Label.new()
	explanation.text = "Controls closed-loop SOCKET flex during SIMULATE. 100% is nearly rigid; 0% restores the loose v0.5.9 cycle behavior."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 12)
	box.add_child(explanation)
	_refresh_physics_labels_v050()


func _on_structure_rigidity_v066(value: float) -> void:
	physics_structure_rigidity_v066 = clampf(value, 0.0, 100.0)
	_apply_structure_rigidity_to_softened_v066()
	_refresh_physics_labels_v050()
	_save_settings()


func _reset_physics_v050() -> void:
	super._reset_physics_v050()
	physics_structure_rigidity_v066 = STRUCTURE_RIGIDITY_DEFAULT_V066
	var slider: HSlider = physics_sliders_v054.get("Structure rigidity") as HSlider
	if slider != null:
		slider.set_value_no_signal(physics_structure_rigidity_v066)
	_apply_structure_rigidity_to_softened_v066()
	_refresh_physics_labels_v050()
	_save_settings()
	_status("Physics reset to Connex defaults — Structure Rigidity %d%%" % int(round(physics_structure_rigidity_v066)))


func _refresh_physics_labels_v050() -> void:
	super._refresh_physics_labels_v050()
	if physics_structure_rigidity_label_v066 != null:
		if physics_structure_rigidity_v066 <= 0.0:
			physics_structure_rigidity_label_v066.text = "Structure rigidity: 0% — loose cycle joints"
		else:
			physics_structure_rigidity_label_v066.text = "Structure rigidity: %d%% — ±%.2f° cycle flex" % [int(round(physics_structure_rigidity_v066)), _structure_flex_angle_deg_v066()]


# -----------------------------------------------------------------------------
# Closed-loop SOCKET rigidity.
#
# v0.5.9 prevented delayed solver explosions by completely freeing all angular
# axes on the redundant socket edge of each rigid cycle. That keeps the socket's
# position closed but effectively inserts a ball/hinge into a flat frame, which
# is why larger constructions can sag into a bowl.
#
# v0.5.11 keeps the same cycle-breaking architecture but re-enables a SMALL,
# tunable angular limit on only those redundant SOCKET edges. The limit is never
# exactly zero, even at 100%, so the solver still has compliance and does not
# return to the unstable mathematically perfect redundant weld from v0.5.8.
# -----------------------------------------------------------------------------

func _apply_structure_rigidity_to_softened_v066() -> void:
	var flex := _structure_flex_angle_rad_v066()
	for joint_value in joints:
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta("sim_soft_socket_cycle_v064", false)):
			continue
		for axis_name in ["x", "y", "z"]:
			if flex < 0.0:
				joint.set("angular_limit_%s/enabled" % axis_name, false)
			else:
				joint.set("angular_limit_%s/enabled" % axis_name, true)
				joint.set("angular_limit_%s/lower_angle" % axis_name, -flex)
				joint.set("angular_limit_%s/upper_angle" % axis_name, flex)
		joint.set_meta("sim_structure_rigidity_v066", physics_structure_rigidity_v066)
		joint.set_meta("sim_structure_flex_rad_v066", flex)


func _soften_redundant_socket_loops_v064() -> int:
	var softened := super._soften_redundant_socket_loops_v064()
	_apply_structure_rigidity_to_softened_v066()
	return softened


func _restore_softened_socket_loops_v064() -> void:
	# The inherited restore puts each authoritative build SOCKET back to exact
	# zero-angle locking and removes the v0.5.9 softened marker.
	super._restore_softened_socket_loops_v064()
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if is_instance_valid(joint):
			joint.remove_meta("sim_structure_rigidity_v066")
			joint.remove_meta("sim_structure_flex_rad_v066")


func _release_physics() -> void:
	_prepare_stable_simulation_graph()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not simulating:
		return
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.set_meta("seed", false)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = false
		body.sleeping = false
	_update_ui()
	_status("Physics running — Structure Rigidity %d%%; %d stabilized closed-loop socket constraints" % [int(round(physics_structure_rigidity_v066)), softened_socket_loop_count_v064])


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label := _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.11 STRUCTURE RIGIDITY: closed-loop SOCKET edges no longer become completely free angular hinges during SIMULATE. Physics > Structure Rigidity controls their permitted angular flex. Default 92% is about ±%.2f° per stabilized cycle edge; 100%% remains slightly compliant to avoid the old redundant-weld explosion." % _structure_flex_angle_deg_v066()


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed := JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest := str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_066) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_066)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
