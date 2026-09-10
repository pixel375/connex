extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_074)
	_status("v0.5.16 ready — O-Ring tunnelling correction acts only on actual hub pass-through events.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_074, text]


# Do not pre-empt normal Jolt connector contact. The v0.5.16 order guard remains
# as a post-step safety net in _correct_axle_order_v073(), where it runs only if
# two hub centers have genuinely reversed order (a real tunnelling event).
func _predict_axle_order_v073(_delta: float) -> void:
	pass
