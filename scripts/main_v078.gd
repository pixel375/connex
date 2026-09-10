extends "res://scripts/main_v077.gd"

const VERSION_078 := "0.5.16"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_078)
	_status("v0.5.16 test runtime — guarded AXLE stacks retain v0.5.15 outer O-Ring residual correction.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_078, text]


# v076 skipped every guarded stop here, which left a timing hole: the direct
# pre-step clamp could be followed by a Jolt constraint/contact impulse that put
# the outer hub beyond its O-Ring before the frame was observed. Restore the
# proven v0.5.15 post-step correction for finite outer bounds. Interior guarded
# hubs still have +/-INF bounds, so this does not become a second hub-stack
# solver and cannot reorder or directly separate the pair.
func _correct_axle_stop_positions_v071() -> void:
	if not simulating:
		return
	for value in axle_stop_ranges_v070:
		var stop := value as Dictionary
		var connector := stop.get("connector") as RigidBody3D
		var rod := stop.get("rod") as RigidBody3D
		if not is_instance_valid(connector) or not is_instance_valid(rod):
			continue
		var axis: Vector3 = _rod_axis_v020(rod).normalized()
		var along: float = _rod_local_along_v070(connector, rod)
		var lower: float = float(stop.get("lower", -INF))
		var upper: float = float(stop.get("upper", INF))
		if lower > -INF and along < lower - AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (lower - along))
			var lower_speed: float = _relative_axial_speed_v071(stop)
			if lower_speed < 0.0:
				_shift_component_velocity_v071(stop, axis * -lower_speed)
		elif upper < INF and along > upper + AXLE_STOP_POSITION_EPS_V071:
			_shift_stop_component_v071(stop, axis * (upper - along))
			var upper_speed: float = _relative_axial_speed_v071(stop)
			if upper_speed > 0.0:
				_shift_component_velocity_v071(stop, axis * -upper_speed)


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	_status("Physics running — multi-hub AXLE stacking is direct-state; finite O-Ring/rod-end bounds retain v0.5.15 residual correction.")
