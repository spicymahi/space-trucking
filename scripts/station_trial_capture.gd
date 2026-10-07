extends RefCounted
## Actual Godot viewport captures of the imported station. No save writes.
func run(host: Node3D) -> void:
	host.set_process(false)
	host.set_physics_process(false)
	host.panel.hide()
	host.prompt.hide()
	host.hud.hide()
	host.toast.hide()
	if host.aim_dot: host.aim_dot.hide()
	host.tool.hide()
	host.daily_paper.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.current = true
	camera.fov = 65
	camera.far = 10000
	camera.global_position = Vector3(-10.4, 4.7, 28.5)
	camera.look_at(Vector3(0.8, 0.7, 4.5), Vector3.UP)
	await _capture(host, "/tmp/station-trial-hangar.png")
	await _performance_sample(host, "hangar")
	camera.fov = 73
	camera.global_position = Vector3(4.0, 0.31, 18.2)
	camera.look_at(Vector3(9.7, 0.35, 9.5), Vector3.UP)
	await _capture(host, "/tmp/station-trial-dispatch.png")
	camera.fov = 62
	camera.global_position = Vector3(8, 2.8, 27)
	camera.look_at(Vector3(-3.2, 0.2, 15), Vector3.UP)
	await _capture(host, "/tmp/station-trial-loading.png")
	camera.fov = 62
	camera.global_position = Vector3(9.3, 0.305, 7.5)
	camera.look_at(Vector3(11.048, 0.205, 7.5), Vector3.UP)
	await _capture(host, "/tmp/station-trial-terminal.png")
	camera.fov = 55
	camera.global_position = Vector3(160, 100, 200)
	camera.look_at(Vector3(27, 18, -30), Vector3.UP)
	await _capture(host, "/tmp/station-trial-exterior.png")
	await _performance_sample(host, "exterior")
	camera.queue_free()
	print("STATION CAPTURE: wrote actual viewport images to /tmp/station-trial-{hangar,dispatch,loading,terminal,exterior}.png")
	host.get_tree().quit()

func _capture(host: Node3D, path: String) -> void:
	for frame in 8: await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	host.get_viewport().get_texture().get_image().save_png(path)

func _performance_sample(host: Node3D, label: String) -> void:
	for frame in 60: await host.get_tree().process_frame
	var intervals: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 60:
		await host.get_tree().process_frame
		var now := Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
	intervals.sort()
	var median_ms: float = intervals[intervals.size() / 2]
	print("STATION RENDER DIAGNOSTIC ", label, " viewport=", host.get_viewport().get_visible_rect().size, " median_frame_ms=", median_ms, " measured_fps=", 1000.0 / maxf(median_ms, 0.001), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " triangles=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
