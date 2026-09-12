extends "res://scripts/main_v093.gd"

const VERSION_094 := "0.5.29"


func _ready() -> void:
	super._ready()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_094)
	_status("v0.5.29 ready — instant placement retained; fast Undo/Redo restores BUILD collision policy.")


func _try_fast_history_restore_v093(source: Dictionary, target: Dictionary) -> bool:
	var restored: bool = super._try_fast_history_restore_v093(source, target)
	if restored:
		_restore_build_collision_policy_v094()
	return restored


func _restore_build_collision_policy_v094() -> void:
	# Full historical restore recreated every RigidBody3D, which implicitly reset
	# these constructor-owned values. The in-place history path must do that
	# explicitly so transient simulation/test masks never leak back into BUILD.
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.collision_layer = 2
		body.collision_mask = 3
		_apply_physics_to_body_v050(body)
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.collision_layer = 2
		ring.collision_mask = 3
		_apply_physics_to_body_v050(ring)


func _save_bundle_v050(name_value: String) -> Dictionary:
	var bundle: Dictionary = super._save_bundle_v050(name_value)
	bundle["app_version"] = VERSION_094
	return bundle


func _autosave_bundle_v089() -> Dictionary:
	var bundle: Dictionary = super._autosave_bundle_v089()
	bundle["app_version"] = VERSION_094
	return bundle
