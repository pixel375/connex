extends "res://scripts/main_v073.gd"

const VERSION_074 := "0.5.16"


# Resolve any genuine hub-order change before the inherited v0.5.15-style stop
# correction runs. main_v073's correction then sees the already-current owner,
# performs exactly one physical boundary correction, and its second handoff
# check is a no-op. This avoids correcting two attached assemblies in one sync.
func _sync_o_ring_followers_v068() -> void:
	if simulating:
		_handoff_axle_stop_ownership_v073()
	super._sync_o_ring_followers_v068()
