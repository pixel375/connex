extends Control

signal rotation_requested(axis_name: String, steps: int)

const STEP_ANGLE := PI / 4.0
const AXES := ["X", "Y", "Z"]
const RADII := [38.0, 58.0, 78.0]
const PICK_TOLERANCE := 12.0

var minus_valid := {"X": true, "Y": true, "Z": true}
var plus_valid := {"X": true, "Y": true, "Z": true}
var dragging := false
var drag_axis := ""
var drag_start_angle := 0.0
var drag_steps := 0

func _ready() -> void:
	custom_minimum_size = Vector2(190.0, 190.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func set_axis_validity(axis_name: String, can_minus: bool, can_plus: bool) -> void:
	minus_valid[axis_name] = can_minus
	plus_valid[axis_name] = can_plus
	queue_redraw()

func _axis_color(axis_name: String) -> Color:
	match axis_name:
		"X":
			return Color(1.0, 0.24, 0.28)
		"Y":
			return Color(0.22, 0.92, 0.38)
		_:
			return Color(0.22, 0.52, 1.0)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var font: Font = ThemeDB.fallback_font
	for i in range(AXES.size()):
		var axis_name: String = AXES[i]
		var radius: float = float(RADII[i])
		var active_color: Color = _axis_color(axis_name)
		var disabled_color := Color(0.29, 0.31, 0.35, 0.90)
		# Right half = positive; left half = negative. This control is pure HUD
		# geometry, so camera orientation cannot change the meaning of a gesture.
		draw_arc(center, radius, -PI * 0.5, PI * 0.5, 48, active_color if bool(plus_valid[axis_name]) else disabled_color, 6.0, true)
		draw_arc(center, radius, PI * 0.5, PI * 1.5, 48, active_color if bool(minus_valid[axis_name]) else disabled_color, 6.0, true)
		draw_string(font, center + Vector2(radius + 6.0, 5.0), axis_name + "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, active_color if bool(plus_valid[axis_name]) else disabled_color)
		draw_string(font, center + Vector2(-radius - 26.0, 5.0), axis_name + "−", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, active_color if bool(minus_valid[axis_name]) else disabled_color)
	draw_circle(center, 5.0, Color(0.88, 0.92, 0.96, 0.95))

func _pick_axis(local_pos: Vector2) -> String:
	var distance_value: float = local_pos.distance_to(size * 0.5)
	var best := ""
	var best_error := PICK_TOLERANCE
	for i in range(AXES.size()):
		var error := absf(distance_value - float(RADII[i]))
		if error <= best_error:
			best_error = error
			best = AXES[i]
	return best

func _angle_for(local_pos: Vector2) -> float:
	var vector_value: Vector2 = local_pos - size * 0.5
	return atan2(vector_value.y, vector_value.x)

func _direction_allowed(axis_name: String, steps: int) -> bool:
	if steps > 0:
		return bool(plus_valid.get(axis_name, false))
	if steps < 0:
		return bool(minus_valid.get(axis_name, false))
	return false

func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var local_pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		local_pos = event.position - global_position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		local_pos = event.position - global_position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		local_pos = event.position - global_position
	elif event is InputEventMouseMotion and dragging:
		local_pos = event.position - global_position
	else:
		return

	if pressed:
		var picked: String = _pick_axis(local_pos)
		if picked.is_empty():
			return
		dragging = true
		drag_axis = picked
		drag_start_angle = _angle_for(local_pos)
		drag_steps = 0
		accept_event()
		return

	if dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var current_angle: float = _angle_for(local_pos)
		var delta: float = wrapf(current_angle - drag_start_angle, -PI, PI)
		drag_steps = clampi(int(round(delta / STEP_ANGLE)), -4, 4)
		accept_event()
		return

	if released and dragging:
		var axis_name := drag_axis
		var steps := drag_steps
		if steps == 0:
			steps = 1 if local_pos.x >= size.x * 0.5 else -1
		dragging = false
		drag_axis = ""
		drag_steps = 0
		if _direction_allowed(axis_name, steps):
			rotation_requested.emit(axis_name, steps)
		accept_event()
