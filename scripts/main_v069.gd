extends "res://scripts/main_v068.gd"

const VERSION_069 := "0.5.14"
const O_RING_STOP_COLLIDER_HEIGHT_V069 := 0.32

# v0.5.14 deliberately returns to the original O-Ring model: the ring is a real
# rigid body fixed to its host rod. The axle joint remains the normal free-slide,
# free-rotation AXLE joint and the ring itself is what physically stops the hub.
# These compatibility/debug arrays must stay empty so old proxy/bounded-joint
# experiments cannot silently return.
var o_ring_stop_pair_count_v069: int = 0
var o_ring_axle_replacements_v069: Array = []
var o_ring_stop_proxies_v069: Array = []


func _ready() -> void:
	super._ready()
	_update_help_text_v030()
	if update_status_v021 != null:
		_set_update_status_v021("Current version: v%s" % VERSION_069)
	_status("O-Ring Stops are physical rod-mounted stops again.")


func _status(text: String) -> void:
	if status_label != null:
		status_label.text = "Connex Lab v%s  •  %s" % [VERSION_069, text]


# Keep the legacy 0.035 O-Ring body and visual geometry. Only make its stopper
# collider slightly thicker (0.26 -> 0.32) so loaded contact begins about 0.03
# units earlier on each face. This absorbs normal Jolt contact/joint compliance
# without changing the visible part, AXLE joint, rod, or global solver settings.
func _make_o_ring_body(transform: Transform3D) -> RigidBody3D:
	var ring := super._make_o_ring_body(transform)
	for child in ring.get_children():
		if child is CollisionShape3D:
			var collision := child as CollisionShape3D
			if collision.shape is CylinderShape3D:
				var cylinder := collision.shape as CylinderShape3D
				cylinder.height = O_RING_STOP_COLLIDER_HEIGHT_V069
	return ring


# Never copy O-Ring collision into the host rod. AXLE joints intentionally
# exclude connector-vs-rod collision, so a rod-owned proxy cannot stop an axle.
func _add_o_ring_proxy_shapes_v068(_ring: RigidBody3D, _rod: RigidBody3D) -> int:
	return 0


# v0.5.13 converted the ring to a collisionless visual follower. Do not do that.
# The legacy O-Ring body already has exactly the desired semantics:
#   * a FixedJoint3D-style Generic6DOF mount keeps it attached to the rod,
#   * the mount excludes only ring-vs-host-rod self collision,
#   * the ring remains a real collider for axle connectors and other pieces,
#   * when the rod falls/rotates, the fixed mount carries the ring with it.
#
# Deliberately do not enable CCD on the ring. The old behavior used ordinary
# contact, and testing showed CCD made no measurable difference to this stop.
func _prepare_o_ring_followers_v068() -> int:
	o_ring_followers_v068.clear()
	o_ring_proxy_shapes_v068.clear()
	o_ring_stop_proxies_v069.clear()
	o_ring_axle_replacements_v069.clear()
	o_ring_stop_pair_count_v069 = 0
	_rebuild_connection_graph_v020()

	for record_value in connections_v020:
		var record := record_value as Dictionary
		if str(record.get("kind", "")) != "o_ring":
			continue
		var ring := record.get("ring") as RigidBody3D
		var rod := record.get("rod") as RigidBody3D
		var joint := record.get("joint") as Joint3D
		if not is_instance_valid(ring) or not is_instance_valid(rod) or not is_instance_valid(joint):
			continue

		ring.continuous_cd = false
		ring.sleeping = false
		o_ring_stop_pair_count_v069 += 1

	return o_ring_stop_pair_count_v069


func _release_physical_o_rings_v069() -> void:
	for ring_value in o_ring_stops:
		var ring := ring_value as RigidBody3D
		if not is_instance_valid(ring):
			continue
		ring.linear_velocity = Vector3.ZERO
		ring.angular_velocity = Vector3.ZERO
		ring.continuous_cd = false
		ring.freeze = false
		ring.sleeping = false


func _release_physics() -> void:
	await super._release_physics()
	if not simulating:
		return
	# Later editor runtimes no longer release O-Rings through the old v0.1.4 path,
	# so explicitly release these physical mounts alongside the ordinary pieces.
	_release_physical_o_rings_v069()
	_status("Physics running — %d physical O-Ring Stop%s fixed to host rod%s; axle slide/rotation remain free until contact" % [
		o_ring_stop_pair_count_v069,
		"" if o_ring_stop_pair_count_v069 == 1 else "s",
		"" if o_ring_stop_pair_count_v069 == 1 else "s"
	])


func _update_help_text_v030() -> void:
	super._update_help_text_v030()
	if help_panel == null:
		return
	var label: Label = _find_label_v030(help_panel)
	if label != null:
		label.text += "\n\nv0.5.14 O-RING STOPPER: restored the simple physical behavior from the older implementation. An O-Ring Stop is a real collision body fixed directly to its host rod. It moves and falls with that rod, while the normal AXLE joint keeps sliding and rotating freely until the axle connector physically reaches the ring. No host-rod proxy collider, moving proxy body, replacement axle joint, rewritten AXLE travel limit, or O-Ring CCD is used. The visible ring and legacy mass are unchanged; its stopper collider is only slightly thicker to tolerate loaded contact. BUILD keeps the O-Ring editable on the rod; SIMULATE releases the rod and ring together."


func _on_update_request_completed_v021(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	super._on_update_request_completed_v021(result, response_code, headers, body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var latest: String = str((parsed as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not latest.is_empty() and _compare_versions_v021(latest, VERSION_069) <= 0:
		update_available_version_v021 = ""
		update_available_url_v021 = ""
		update_available_filename_v021 = ""
		_set_update_status_v021("Up to date — v%s is the latest release." % VERSION_069)
		if update_button_v021 != null:
			update_button_v021.text = "Check Again"
