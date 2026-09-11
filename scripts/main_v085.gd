extends "res://scripts/main_v084.gd"

const VERSION_085 := "0.5.24-dev"


# -----------------------------------------------------------------------------
# Undo selection cleanup
#
# Undo may restore/remove geometry while leaving the affected piece selected.
# That makes the bottom Rod / Conn arrows act on the selected piece rather than
# choosing the NEXT part, and a fully-attached rod may correctly reject such an
# edit. Clear every selection after Undo so palette behavior is deterministic.
# -----------------------------------------------------------------------------

func _undo() -> void:
	super._undo()
	if simulating:
		return
	# This clears the selected piece, any ATTACH source point, one-shot Select,
	# active editor tools/gizmos, highlights and attachment overlays together.
	_deselect_piece_v039(false)
	_sync_deselect_button_v083()
