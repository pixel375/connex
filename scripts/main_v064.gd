extends "res://scripts/main_v063.gd"

const VERSION_064 := "0.5.9"

# Camera gesture tuning is viewport-relative so the same physical gesture feels
# similar on phones/tablets with different resolutions.
const CAMERA_ORBIT_FULL_WIDTH_RAD_V064 := PI * 1.15
const CAMERA_ORBIT_FULL_HEIGHT_RAD_V064 := deg_to_rad(105.0)
const CAMERA_PITCH_MIN_V064 := deg_to_rad(6.0)
const CAMERA_PITCH_MAX_V064 := deg_to_rad(84.0)

const SOFT_SOCKET_META_V064 := "sim_soft_socket_cycle_v064"

var camera_multitouch_active_v064: bool = false
var camera_block_single_touch_v064: bool = false
var camera_multitouch_center_v064: Vector2 = Vector2.ZERO
var camera_multitouch_span_v064: float = -1.0
var softened_socket_loop_count_v064: int = 0


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_064)
	_status("Deterministic orbit/pan/zoom gestures and stable closed-loop socket constraints are active.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_064, text]


# -----------------------------------------------------------------------------
# Camera: explicit gesture ownership.
#
# Old input accumulated state through several inherited generations. During a
# two-finger gesture, lifting one finger could immediately hand the remaining
# finger back to one-finger orbit/tap logic. That made the camera jump, drift, or
# unexpectedly select/build. v0.5.9 owns the touch gesture state explicitly:
# one finger = orbit, two fingers = pan+zoom, and after any two-finger gesture
# single-finger behavior stays blocked until every finger is lifted.
# -----------------------------------------------------------------------------

func _camera_tool_drag_active_v064() -> bool:
	return move_drag_active_v042 or gizmo_drag_active_v030 or attach_drag_active_v030


func _camera_touch_center_v064() -> Vector2:
	if touches.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var count := 0
	for value in touches.values():
		sum += value as Vector2
		count += 1
	return sum / float(maxi(count, 1))


func _camera_touch_span_v064() -> float:
	var keys := touches.keys()
	if keys.size() < 2:
		return -1.0
	var a: Vector2 = touches[keys[0]] as Vector2
	var b: Vector2 = touches[keys[1]] as Vector2
	return a.distance_to(b)


func _begin_multitouch_camera_v064() -> void:
	camera_multitouch_active_v064 = true
	camera_block_single_touch_v064 = true
	_mark_all_camera_touches_moved_v061()
	camera_multitouch_center_v064 = _camera_touch_center_v064()
	camera_multitouch_span_v064 = _camera_touch_span_v064()
	pinch_last = camera_multitouch_span_v064
	pinch_center_last = camera_multitouch_center_v064
	pinch_center_valid = true


func _reset_camera_touch_state_v064() -> void:
	camera_multitouch_active_v064 = false
	camera_block_single_touch_v064 = false
	camera_multitouch_center_v064 = Vector2.ZERO
	camera_multitouch_span_v064 = -1.0
	pinch_last = -1.0
	pinch_center_valid = false


func _orbit_camera_v064(screen_delta: Vector2) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0:
		return
	var x_factor: float = -1.0 if reverse_orbit_x else 1.0
	var y_factor: float = -1.0 if reverse_orbit_y else 1.0
	var yaw_step: float = (screen_delta.x / size.x) * CAMERA_ORBIT_FULL_WIDTH_RAD_V064 * camera_sensitivity * x_factor
	var pitch_step: float = (screen_delta.y / size.y) * CAMERA_ORBIT_FULL_HEIGHT_RAD_V064 * camera_sensitivity * y_factor
	camera_yaw -= yaw_step
	camera_pitch = clampf(camera_pitch - pitch_step, CAMERA_PITCH_MIN_V064, CAMERA_PITCH_MAX_V064)


func _update_multitouch_camera_v064(drag: InputEventScreenDrag) -> void:
	touches[drag.index] = drag.position
	_mark_all_camera_touches_moved_v061()
	var new_center: Vector2 = _camera_touch_center_v064()
	var new_span: float = _camera_touch_span_v064()
	if camera_multitouch_span_v064 > 1.0 and new_span > 1.0:
		_apply_pinch_zoom_v061(camera_multitouch_span_v064, new_span)
	if camera_multitouch_active_v064:
		_pan_camera(new_center - camera_multitouch_center_v064)
	camera_multitouch_center_v064 = new_center
	camera_multitouch_span_v064 = new_span
	pinch_last = new_span
	pinch_center_last = new_center
	pinch_center_valid = true


func _unhandled_input(event: InputEvent) -> void:
	if _any_modal_open_v054():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		last_pointer_screen_v042 = touch.position

		# Let editor gizmos and the inherited touch registry see the press first.
		if touch.pressed:
			super._unhandled_input(event)
			if _camera_tool_drag_active_v064():
				return
			if touches.size() >= 2:
				_begin_multitouch_camera_v064()
				get_viewport().set_input_as_handled()
			return

		# A release after multi-touch is always marked moved before the inherited
		# release path sees it, so it can never become an accidental tap.
		if camera_multitouch_active_v064 or camera_block_single_touch_v064:
			touch_moved[touch.index] = true
			super._unhandled_input(event)
			_mark_all_camera_touches_moved_v061()
			if touches.is_empty():
				_reset_camera_touch_state_v064()
			else:
				camera_multitouch_active_v064 = touches.size() >= 2
				camera_block_single_touch_v064 = true
				camera_multitouch_center_v064 = _camera_touch_center_v064()
				camera_multitouch_span_v064 = _camera_touch_span_v064()
			get_viewport().set_input_as_handled()
			return

		super._unhandled_input(event)
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		last_pointer_screen_v042 = drag.position

		if _camera_tool_drag_active_v064():
			super._unhandled_input(event)
			return

		# Once two touches are present the gesture has one owner. There is no
		# inherited per-finger pan/zoom update and therefore no double application.
		if camera_multitouch_active_v064 or touches.size() >= 2:
			if not camera_multitouch_active_v064:
				_begin_multitouch_camera_v064()
			_update_multitouch_camera_v064(drag)
			get_viewport().set_input_as_handled()
			return

		# After a pinch, the remaining finger is inert until it is lifted. This
		# removes the common camera jump when transitioning 2 fingers -> 1 finger.
		if camera_block_single_touch_v064:
			touches[drag.index] = drag.position
			touch_moved[drag.index] = true
			get_viewport().set_input_as_handled()
			return

		# Ordinary one-finger orbit. We own it instead of passing it down to the old
		# fixed-pixel formula, so sensitivity is resolution-independent.
		touches[drag.index] = drag.position
		if drag.relative.length() > 1.0:
			touch_moved[drag.index] = true
			_orbit_camera_v064(drag.relative)
		get_viewport().set_input_as_handled()
		return

	# Mouse controls are still useful for desktop testing and retain the inherited
	# behavior, including wheel zoom and right/middle-button pan.
	super._unhandled_input(event)


# -----------------------------------------------------------------------------
# Physics: preserve closed SOCKETs without restoring redundant 6DOF welds.
#
# v0.1.4 removed redundant fixed-cycle joints because complete hard 6DOF loops
# inject energy into the iterative solver and eventually shake/explode. v0.5.8
# correctly proved that simply removing a real SOCKET edge is not acceptable.
# v0.5.9 keeps the socket's three positional constraints but frees its redundant
# angular constraints during SIMULATE. The rest of the fixed path already owns
# orientation; this edge only has to keep the physical rod end in the socket.
# BUILD restores the authoritative full fixed SOCKET joint.
# -----------------------------------------------------------------------------

func _restore_softened_socket_loops_v064() -> void:
	for joint_value in joints:
		var joint := joint_value as Generic6DOFJoint3D
		if not is_instance_valid(joint) or not bool(joint.get_meta(SOFT_SOCKET_META_V064, false)):
			continue
		for axis_name in ["x", "y", "z"]:
			joint.set("angular_limit_%s/enabled" % axis_name, true)
			joint.set("angular_limit_%s/lower_angle" % axis_name, 0.0)
			joint.set("angular_limit_%s/upper_angle" % axis_name, 0.0)
		joint.remove_meta(SOFT_SOCKET_META_V064)
	softened_socket_loop_count_v064 = 0


func _soften_redundant_socket_loops_v064() -> int:
	var live_bodies: Array = []
	var index_by_id: Dictionary = {}
	for body_value in bodies:
		var body := body_value as RigidBody3D
		if not is_instance_valid(body):
			continue
		index_by_id[body.get_instance_id()] = live_bodies.size()
		live_bodies.append(body)

	var parent: Array = []
	for i in range(live_bodies.size()):
		parent.append(i)

	var softened := 0
	for joint_value in joints:
		var joint := joint_value as Joint3D
		if not is_instance_valid(joint) or bool(joint.get_meta("sim_disabled", false)) or str(joint.name).begins_with("AxleJoint"):
			continue
		var nodes: Array = _joint_nodes(joint)
		if nodes.size() < 2:
			continue
		var body_a := nodes[0] as RigidBody3D
		var body_b := nodes[1] as RigidBody3D
		if not is_instance_valid(body_a) or not is_instance_valid(body_b):
			continue
		if not index_by_id.has(body_a.get_instance_id()) or not index_by_id.has(body_b.get_instance_id()):
			continue
		var ia: int = int(index_by_id[body_a.get_instance_id()])
		var ib: int = int(index_by_id[body_b.get_instance_id()])
		var ra: int = _uf_find(parent, ia)
		var rb: int = _uf_find(parent, ib)
		if ra == rb:
			if str(joint.get_meta("connection_kind_v020", "")) == "socket" and joint is Generic6DOFJoint3D:
				var socket_joint := joint as Generic6DOFJoint3D
				for axis_name in ["x", "y", "z"]:
					socket_joint.set("angular_limit_%s/enabled" % axis_name, false)
				socket_joint.set_meta(SOFT_SOCKET_META_V064, true)
				softened += 1
			continue
		_uf_union(parent, ra, rb)
	return softened


func _prepare_stable_simulation_graph() -> void:
	# If a previous preflight was interrupted, put build constraints back before
	# the inherited graph analysis runs again.
	_restore_softened_socket_loops_v064()
	super._prepare_stable_simulation_graph()
	# v0.5.8 has now restored real SOCKET cycle edges. Convert only the redundant
	# ones from hard 6DOF welds to positional loop closures.
	softened_socket_loop_count_v064 = _soften_redundant_socket_loops_v064()


func _reset_pose() -> void:
	_restore_softened_socket_loops_v064()
	super._reset_pose()


func _restore_state(snapshot: Dictionary) -> void:
	_restore_softened_socket_loops_v064()
	super._restore_state(snapshot)


func _restart_build() -> void:
	_restore_softened_socket_loops_v064()
	super._restart_build()


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.9 CAMERA: one finger owns orbit; two fingers own pan+pinch zoom. After any two-finger gesture, the remaining finger is intentionally inert until all fingers are lifted, preventing hand-off jumps and accidental taps. Orbit speed is viewport-relative rather than raw-pixel based.\n\nv0.5.9 PHYSICS: real closed-loop SOCKETs remain physically closed, but redundant cycle edges no longer run as complete hard 6DOF welds. Their redundant angular locks are released during SIMULATE while positional socket closure remains active, preventing the old delayed over-constraint energy buildup. BUILD restores the full authoritative socket joints."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_064) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_064)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
