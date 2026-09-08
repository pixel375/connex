extends Node


func _ready() -> void:
	# Parent builds the Physics panel during its own _ready(). Run immediately
	# afterward so the 9.81 m/s² default is representable by the visible slider.
	call_deferred("_apply_fix")


func _apply_fix() -> void:
	var main: Node = get_parent()
	if main == null:
		return
	var sliders_value: Variant = main.get("physics_sliders_v054")
	if not (sliders_value is Dictionary):
		return
	var sliders: Dictionary = sliders_value as Dictionary
	var gravity: HSlider = sliders.get("Gravity") as HSlider
	if gravity == null:
		return
	gravity.step = 0.01
	gravity.set_value_no_signal(float(main.get("physics_gravity_v050")))
