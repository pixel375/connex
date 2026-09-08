extends "res://scripts/main_v052.gd"

const VERSION_053 := "0.5.1-dev3"


func _ready() -> void:
	super._ready()
	_status("v0.5.1 validation build: item-aware transforms, open-jaw connectors, restored camera pan and spatial socket fixes active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_053, text]


# Keep every out-of-plane socket in the same named assembly-root contract used
# by v0.4.1. Besides satisfying cleanup/rebuild behavior, this prevents stale
# 11/14-point geometry when a connector changes type.
func _add_spatial_socket_visual_v041(parent: Node3D, slot: int, color: Color) -> void:
	var root: Node3D = Node3D.new()
	root.name = "SpatialSocket_%d" % slot
	parent.add_child(root)

	var direction: Vector3 = _slot_dir(slot).normalized()
	var normal: Vector3 = Vector3.BACK
	if absf(direction.dot(normal)) > 0.95:
		normal = Vector3.RIGHT
	var tangent: Vector3 = direction.cross(normal).normalized()
	var main_mat: Material = _mat(color)
	var edge_mat: Material = _mat(color.lightened(0.055))
	_add_capsule_between_v052(root, direction * 0.48, direction * 0.94, 0.17, main_mat, 12)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var offset: Vector3 = tangent * (0.235 * side)
		_add_capsule_between_v052(root, direction * 0.82 + offset, direction * 1.48 + offset, 0.105, main_mat, 12)
		_add_cylinder_visual(root, 0.125, 0.30, direction * 1.49 + offset, edge_mat, 14)
