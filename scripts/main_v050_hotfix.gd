extends "res://scripts/main_v050.gd"

# GridContainer keeps queue_free() children until the end of the frame. A rapid
# tab switch therefore briefly counted both the old and new cards and could
# duplicate layout entries. Detach old cards synchronously, then let v0.5.0
# rebuild the requested tab normally.
func _refresh_parts_browser_v050() -> void:
	if parts_grid_v050 != null:
		for child_value in parts_grid_v050.get_children():
			var child: Node = child_value as Node
			parts_grid_v050.remove_child(child)
			child.queue_free()
	super._refresh_parts_browser_v050()
