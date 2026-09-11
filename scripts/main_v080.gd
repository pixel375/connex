extends "res://scripts/main_v079.gd"

const VERSION_080 := "0.5.21"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_080)
	_status("v0.5.21 ready — analog navigation and elevation now retain the established high-zoom pan bounds.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_080, text]


# v0.5.21 keeps two-finger pan horizontal so using the dedicated UP/DOWN camera
# controls is never undone by a later pan. Retain v0.5.6's crucial distance cap,
# though, so a small finger motion cannot throw the camera across the build while
# zoomed far out.
func _pan_camera(screen_delta: Vector2) -> void:
	if camera == null:
		return
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.001:
		right = right.normalized()
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()
	var x_factor: float = -1.0 if reverse_pan_x else 1.0
	var y_factor: float = -1.0 if reverse_pan_y else 1.0
	var effective_distance: float = clampf(camera_distance, 5.0, CAMERA_PAN_DISTANCE_CAP_V061)
	var move_scale: float = effective_distance * CAMERA_PAN_SCALE_V061 * camera_sensitivity
	var keep_y: float = camera_target.y
	camera_target += (-right * screen_delta.x * x_factor + forward * screen_delta.y * y_factor) * move_scale
	camera_target.x = clampf(camera_target.x, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.z = clampf(camera_target.z, -PLATFORM_HALF + 5.0, PLATFORM_HALF - 5.0)
	camera_target.y = keep_y
