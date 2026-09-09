extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CAMERA_059_SMOKE_FAIL: %s" % message)
	quit(1)


func _touch(index: int, pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	return event


func _drag(index: int, position: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	return event


func _run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not str(main.get_script().resource_path).ends_with("main_v064.gd"):
		_fail("Main is not using v0.5.9 runtime")
		return

	# One finger has exactly one job: orbit. It must not pan or zoom.
	var yaw0: float = float(main.get("camera_yaw"))
	var target0: Vector3 = main.get("camera_target") as Vector3
	var distance0: float = float(main.get("camera_distance"))
	main.call("_unhandled_input", _touch(0, true, Vector2(420, 320)))
	main.call("_unhandled_input", _drag(0, Vector2(540, 320), Vector2(120, 0)))
	var yaw1: float = float(main.get("camera_yaw"))
	if absf(yaw1 - yaw0) < 0.03:
		_fail("one-finger drag did not orbit")
		return
	if (main.get("camera_target") as Vector3).distance_to(target0) > 0.001:
		_fail("one-finger orbit changed camera target/pan")
		return
	if absf(float(main.get("camera_distance")) - distance0) > 0.001:
		_fail("one-finger orbit changed zoom")
		return
	main.call("_unhandled_input", _touch(0, false, Vector2(540, 320)))

	# Two fingers have exactly two camera jobs: pan and zoom. They must not orbit.
	main.call("_unhandled_input", _touch(0, true, Vector2(320, 320)))
	main.call("_unhandled_input", _touch(1, true, Vector2(520, 320)))
	var multi_yaw: float = float(main.get("camera_yaw"))
	var multi_target: Vector3 = main.get("camera_target") as Vector3
	var multi_distance: float = float(main.get("camera_distance"))
	main.call("_unhandled_input", _drag(0, Vector2(280, 345), Vector2(-40, 25)))
	main.call("_unhandled_input", _drag(1, Vector2(570, 345), Vector2(50, 25)))
	if absf(float(main.get("camera_yaw")) - multi_yaw) > 0.0001:
		_fail("two-finger gesture changed orbit yaw")
		return
	if (main.get("camera_target") as Vector3).distance_to(multi_target) < 0.01:
		_fail("two-finger drag did not pan")
		return
	if absf(float(main.get("camera_distance")) - multi_distance) < 0.05:
		_fail("two-finger spread did not zoom")
		return

	# The critical Android hand-off regression: after one finger of a pinch lifts,
	# the remaining finger is inert until it also lifts. No surprise orbit/tap.
	main.call("_unhandled_input", _touch(1, false, Vector2(570, 345)))
	var handoff_yaw: float = float(main.get("camera_yaw"))
	var handoff_target: Vector3 = main.get("camera_target") as Vector3
	main.call("_unhandled_input", _drag(0, Vector2(500, 500), Vector2(220, 155)))
	if absf(float(main.get("camera_yaw")) - handoff_yaw) > 0.0001:
		_fail("remaining finger after pinch unexpectedly started orbiting")
		return
	if (main.get("camera_target") as Vector3).distance_to(handoff_target) > 0.0001:
		_fail("remaining finger after pinch unexpectedly kept panning")
		return
	main.call("_unhandled_input", _touch(0, false, Vector2(500, 500)))

	# Once all fingers are clear, a fresh one-finger gesture works immediately.
	var fresh_yaw: float = float(main.get("camera_yaw"))
	main.call("_unhandled_input", _touch(0, true, Vector2(440, 340)))
	main.call("_unhandled_input", _drag(0, Vector2(500, 340), Vector2(60, 0)))
	if absf(float(main.get("camera_yaw")) - fresh_yaw) < 0.015:
		_fail("fresh orbit stayed blocked after all fingers were lifted")
		return
	main.call("_unhandled_input", _touch(0, false, Vector2(500, 340)))

	print("CAMERA_059_SMOKE_OK: deterministic one-finger orbit + two-finger pan/zoom + no 2->1 handoff jump")
	main.queue_free()
	await process_frame
	quit(0)
