extends "res://scripts/main_v083.gd"

const VERSION_084 := "0.5.24-dev"
const ROTATION_INDICATOR_SEGMENTS_084 := 96
const ROTATION_INDICATOR_RADIUS_PAD_084 := 0.62
const ROTATION_INDICATOR_BASE_WIDTH_084 := 0.13
const ROTATION_INDICATOR_ACTIVE_WIDTH_084 := 0.28
const ROTATION_INDICATOR_POINTER_WIDTH_084 := 0.40

var rotation_indicator_root_v084: Node3D
var rotation_indicator_base_v084: MeshInstance3D
var rotation_indicator_ticks_v084: MeshInstance3D
var rotation_indicator_fill_v084: MeshInstance3D
var rotation_indicator_pointer_v084: MeshInstance3D
var rotation_indicator_label_v084: Label3D

var rotation_indicator_base_material_v084: StandardMaterial3D
var rotation_indicator_tick_material_v084: StandardMaterial3D
var rotation_indicator_pointer_material_v084: StandardMaterial3D
var rotation_indicator_axis_materials_v084: Dictionary = {}
var rotation_indicator_blocked_material_v084: StandardMaterial3D


func _ready() -> void:
	super._ready()
	_build_rotation_indicator_v084()
	_status("v0.5.24 staging — live rotation progress ring is active while dragging the rotate gizmo.")


# -----------------------------------------------------------------------------
# Live rotation indicator
#
# While a world-axis rotate gizmo is held, draw a second circular progress ring
# outside the gizmo. The filled arc shows the ACTUAL snapped rotation preview;
# a bright narrow marker tracks the continuous finger drag between 45° snaps.
# This makes symmetric connectors/assemblies much easier to orient deliberately.
# -----------------------------------------------------------------------------

func _indicator_material_v084(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material


func _build_rotation_indicator_v084() -> void:
	if rotation_indicator_root_v084 != null:
		return
	rotation_indicator_base_material_v084 = _indicator_material_v084(Color(0.88, 0.93, 1.0, 0.18))
	rotation_indicator_tick_material_v084 = _indicator_material_v084(Color(0.92, 0.96, 1.0, 0.50))
	rotation_indicator_pointer_material_v084 = _indicator_material_v084(Color(1.0, 1.0, 1.0, 0.98))
	rotation_indicator_blocked_material_v084 = _indicator_material_v084(Color(1.0, 0.30, 0.15, 0.94))
	rotation_indicator_axis_materials_v084 = {
		"X": _indicator_material_v084(Color(1.0, 0.26, 0.22, 0.94)),
		"Y": _indicator_material_v084(Color(0.24, 1.0, 0.42, 0.94)),
		"Z": _indicator_material_v084(Color(0.24, 0.58, 1.0, 0.94)),
	}

	rotation_indicator_root_v084 = Node3D.new()
	rotation_indicator_root_v084.name = "RotationProgressIndicatorV084"
	rotation_indicator_root_v084.visible = false
	add_child(rotation_indicator_root_v084)

	rotation_indicator_base_v084 = MeshInstance3D.new()
	rotation_indicator_base_v084.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rotation_indicator_root_v084.add_child(rotation_indicator_base_v084)

	rotation_indicator_ticks_v084 = MeshInstance3D.new()
	rotation_indicator_ticks_v084.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rotation_indicator_root_v084.add_child(rotation_indicator_ticks_v084)

	rotation_indicator_fill_v084 = MeshInstance3D.new()
	rotation_indicator_fill_v084.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rotation_indicator_root_v084.add_child(rotation_indicator_fill_v084)

	rotation_indicator_pointer_v084 = MeshInstance3D.new()
	rotation_indicator_pointer_v084.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rotation_indicator_root_v084.add_child(rotation_indicator_pointer_v084)

	rotation_indicator_label_v084 = Label3D.new()
	rotation_indicator_label_v084.font_size = 44
	rotation_indicator_label_v084.outline_size = 8
	rotation_indicator_label_v084.outline_modulate = Color(0.01, 0.02, 0.03, 0.96)
	rotation_indicator_label_v084.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotation_indicator_label_v084.no_depth_test = true
	rotation_indicator_label_v084.fixed_size = true
	rotation_indicator_label_v084.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotation_indicator_root_v084.add_child(rotation_indicator_label_v084)


func _append_indicator_quad_v084(mesh: ImmediateMesh, axis: Vector3, inner_radius: float, outer_radius: float, a0: float, a1: float) -> void:
	var normal_axis: Vector3 = axis.normalized()
	var u: Vector3 = _world_perpendicular_v035(normal_axis)
	var v: Vector3 = normal_axis.cross(u).normalized()
	var p0_inner: Vector3 = (u * cos(a0) + v * sin(a0)) * inner_radius
	var p0_outer: Vector3 = (u * cos(a0) + v * sin(a0)) * outer_radius
	var p1_inner: Vector3 = (u * cos(a1) + v * sin(a1)) * inner_radius
	var p1_outer: Vector3 = (u * cos(a1) + v * sin(a1)) * outer_radius
	mesh.surface_add_vertex(p0_inner)
	mesh.surface_add_vertex(p0_outer)
	mesh.surface_add_vertex(p1_outer)
	mesh.surface_add_vertex(p0_inner)
	mesh.surface_add_vertex(p1_outer)
	mesh.surface_add_vertex(p1_inner)


func _make_indicator_arc_v084(axis: Vector3, radius: float, width: float, start_angle: float, end_angle: float, material: Material, minimum_segments: int = 1) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var span: float = end_angle - start_angle
	var segment_count: int = maxi(minimum_segments, int(ceil(absf(span) / TAU * float(ROTATION_INDICATOR_SEGMENTS_084))))
	var inner_radius: float = maxf(0.01, radius - width * 0.5)
	var outer_radius: float = radius + width * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for i in range(segment_count):
		var t0: float = float(i) / float(segment_count)
		var t1: float = float(i + 1) / float(segment_count)
		var a0: float = lerpf(start_angle, end_angle, t0)
		var a1: float = lerpf(start_angle, end_angle, t1)
		_append_indicator_quad_v084(mesh, axis, inner_radius, outer_radius, a0, a1)
	mesh.surface_end()
	return mesh


func _make_indicator_ticks_v084(axis: Vector3, radius: float, scale_value: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var half_angle: float = deg_to_rad(1.35)
	var inner_radius: float = radius - 0.22 * scale_value
	var outer_radius: float = radius + 0.22 * scale_value
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, rotation_indicator_tick_material_v084)
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		_append_indicator_quad_v084(mesh, axis, inner_radius, outer_radius, angle - half_angle, angle + half_angle)
	mesh.surface_end()
	return mesh


func _axis_color_v084(axis_name: String) -> Color:
	match axis_name:
		"X":
			return Color(1.0, 0.30, 0.26)
		"Y":
			return Color(0.30, 1.0, 0.48)
		"Z":
			return Color(0.30, 0.64, 1.0)
	return Color.WHITE


func _signed_degrees_text_v084(value: int) -> String:
	if value > 0:
		return "+%d°" % value
	return "%d°" % value


func _show_rotation_indicator_v084() -> void:
	if rotation_indicator_root_v084 == null or not gizmo_drag_active_v030:
		return
	rotation_indicator_root_v084.visible = true
	_refresh_rotation_indicator_v084()


func _hide_rotation_indicator_v084() -> void:
	if rotation_indicator_root_v084 != null:
		rotation_indicator_root_v084.visible = false


func _refresh_rotation_indicator_v084() -> void:
	if rotation_indicator_root_v084 == null or not gizmo_drag_active_v030:
		return
	var axis: Vector3 = gizmo_drag_axis_v030.normalized()
	if axis.length_squared() < 0.5:
		_hide_rotation_indicator_v084()
		return
	var axis_name: String = gizmo_drag_axis_name_v030
	var scale_value: float = gizmo_root_v030.scale.x if gizmo_root_v030 != null else clampf(camera_distance / 19.0, 0.62, 2.25)
	var radius: float = (GIZMO_RADIUS_030 + ROTATION_INDICATOR_RADIUS_PAD_084) * scale_value
	var base_width: float = ROTATION_INDICATOR_BASE_WIDTH_084 * scale_value
	var active_width: float = ROTATION_INDICATOR_ACTIVE_WIDTH_084 * scale_value
	var pointer_width: float = ROTATION_INDICATOR_POINTER_WIDTH_084 * scale_value

	rotation_indicator_root_v084.global_basis = Basis.IDENTITY
	rotation_indicator_root_v084.global_position = gizmo_drag_center_v030
	rotation_indicator_base_v084.mesh = _make_indicator_arc_v084(axis, radius, base_width, 0.0, TAU, rotation_indicator_base_material_v084, ROTATION_INDICATOR_SEGMENTS_084)
	rotation_indicator_ticks_v084.mesh = _make_indicator_ticks_v084(axis, radius, scale_value)

	var snapped_degrees: int = gizmo_drag_steps_v030 * 45
	var snapped_radians: float = deg_to_rad(float(snapped_degrees))
	var preview_valid: bool = bool(gizmo_drag_preview_v030.get("valid", true))
	var active_material: Material = rotation_indicator_axis_materials_v084.get(axis_name, rotation_indicator_pointer_material_v084) as Material
	if not preview_valid:
		active_material = rotation_indicator_blocked_material_v084
	if snapped_degrees == 0:
		rotation_indicator_fill_v084.mesh = null
	else:
		rotation_indicator_fill_v084.mesh = _make_indicator_arc_v084(axis, radius, active_width, 0.0, snapped_radians, active_material)

	# The white marker follows raw drag continuously, even before the next 45°
	# threshold is reached. This gives tactile-looking progress between snaps.
	var raw_degrees: float = clampf(gizmo_drag_accum_px_v035 / WORLD_GIZMO_STEP_PIXELS_035 * 45.0, -315.0, 315.0)
	var pointer_angle: float = deg_to_rad(raw_degrees)
	var pointer_half_angle: float = deg_to_rad(2.1)
	rotation_indicator_pointer_v084.mesh = _make_indicator_arc_v084(
		axis,
		radius,
		pointer_width,
		pointer_angle - pointer_half_angle,
		pointer_angle + pointer_half_angle,
		rotation_indicator_pointer_material_v084,
		2
	)

	rotation_indicator_label_v084.text = "%s  %s" % [axis_name, _signed_degrees_text_v084(snapped_degrees)]
	if not preview_valid and snapped_degrees != 0:
		rotation_indicator_label_v084.text += "  BLOCKED"
	rotation_indicator_label_v084.modulate = rotation_indicator_blocked_material_v084.albedo_color if not preview_valid else _axis_color_v084(axis_name)
	rotation_indicator_label_v084.position = Vector3.UP * (radius + 0.48 * scale_value)


func _begin_gizmo_drag_v030(screen_pos: Vector2) -> bool:
	var started: bool = super._begin_gizmo_drag_v030(screen_pos)
	if started:
		_show_rotation_indicator_v084()
	return started


func _update_gizmo_drag_v030(screen_pos: Vector2) -> void:
	super._update_gizmo_drag_v030(screen_pos)
	if gizmo_drag_active_v030:
		_refresh_rotation_indicator_v084()


func _finish_gizmo_drag_v030() -> void:
	super._finish_gizmo_drag_v030()
	_hide_rotation_indicator_v084()


func _process(delta: float) -> void:
	super._process(delta)
	if rotation_indicator_root_v084 == null:
		return
	if not gizmo_drag_active_v030:
		rotation_indicator_root_v084.visible = false
		return
	if rotation_indicator_root_v084.visible:
		rotation_indicator_root_v084.global_position = gizmo_drag_center_v030
