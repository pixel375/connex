extends "res://scripts/main_v072.gd"

const VERSION_073 := "0.5.16"
const STRUCTURE_FLEX_CURVE_POWER_V073 := 1.75
const STRUCTURE_FLEX_RIGID_THRESHOLD_V073 := 90.0


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_073)
	_status("v0.5.16 ready — rigid high-end structure settings with progressive realistic flex below 90%.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_073, text]


func _structure_flex_angle_rad_v066() -> float:
	var rigidity: float = clampf(physics_structure_rigidity_v066, 0.0, 100.0)
	# Jolt treats a tiny non-zero angular allowance as a materially different
	# constraint from a true fixed joint. Keep the upper end exactly rigid so the
	# default 92% physics remains as stable as the original fixed construction,
	# then ramp compliance progressively through the lower slider range.
	if rigidity >= STRUCTURE_FLEX_RIGID_THRESHOLD_V073:
		return 0.0
	var flexible01: float = 1.0 - rigidity / STRUCTURE_FLEX_RIGID_THRESHOLD_V073
	var degrees: float = STRUCTURE_FLEX_MAX_DEG_V072 * pow(flexible01, STRUCTURE_FLEX_CURVE_POWER_V073)
	return deg_to_rad(degrees)


func _structure_flex_angle_deg_v066() -> float:
	return rad_to_deg(_structure_flex_angle_rad_v066())
