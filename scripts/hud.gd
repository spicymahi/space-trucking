class_name Hud
extends CanvasLayer
## Screen overlays: crosshair and prompts on foot, the green on-glass flight HUD in the cockpit,
## toasts, the objective line, the wrist computer, the trade terminal and the pause panel.

var main: Node
var terminal: TradeTerminalUI
var _prompt: Label
var _toast: Label
var _objective: Label
var _wrist: Label
var _hints: Label
var _cross: Control
var _overlay: FlightOverlay
var _pause: Control
var _toast_time := 0.0


class FlightOverlay extends Control:
	var hud: Hud

	func _process(_d: float) -> void:
		queue_redraw()

	## Screen area of the speed and mode text, left of the crosshair at c.
	func _speed_rect(c: Vector2) -> Rect2:
		return Rect2(c + Vector2(-430, -20), Vector2(200, 70))

	func _draw() -> void:
		var ship: Ship = hud.main.ship
		if not ship.piloted or ship.nav_mode:
			return
		var cam := ship.cam
		var g := Vox.PHOS_GREEN
		var f: Font = GameState.font_crt
		var c := size / 2 + Vector2(0, -97)
		draw_arc(c, 12, 0, TAU, 24, g, 2)
		draw_line(c + Vector2(-34, 0), c + Vector2(-18, 0), g, 2)
		draw_line(c + Vector2(18, 0), c + Vector2(34, 0), g, 2)
		# Speed and mode sit left of the crosshair (inside _speed_rect), above the gauge hood and clear of the pad label.
		draw_string(f, c + Vector2(-430, 11), "%03d M/S" % int(ship.velocity.length()), HORIZONTAL_ALIGNMENT_RIGHT, 200, 34, g)
		draw_string(f, c + Vector2(-430, 41), ship.mode_text(), HORIZONTAL_ALIGNMENT_RIGHT, 200, 26, g)
		# Stations
		for st in ship.stations:
			if st == ship.landed_at:
				continue
			var p: Vector3 = st.global_position
			var d := ship.global_position.distance_to(p)
			if d < 30000 and not cam.is_position_behind(p):
				var s := cam.unproject_position(p)
				var b := 26.0
				for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					draw_line(s + k * b, s + k * b - Vector2(k.x * 10, 0), g, 2)
					draw_line(s + k * b, s + k * b - Vector2(0, k.y * 10), g, 2)
				draw_string(f, s + Vector2(34, -10), st.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, g)
				draw_string(f, s + Vector2(34, 14), "%.1f KM" % (d / 1000.0) + ("  PAD 07 CLEARED" if st.docking_granted else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, g)
			if st.docking_granted and d < 1200:
				var pad := st.to_global(Station.PAD_CENTER)
				if not cam.is_position_behind(pad):
					var ps := cam.unproject_position(pad)
					draw_arc(ps, 30, 0, TAU, 32, Vox.PHOS_AMBER, 2)
					# Left of the circle, unless that would cover the speed block; then under it
					# (right of it is where the station's name and distance go).
					if Rect2(ps + Vector2(-136, -16), Vector2(100, 30)).intersects(_speed_rect(c)):
						draw_string(f, ps + Vector2(-50, 56), "PAD 07", HORIZONTAL_ALIGNMENT_CENTER, 100, 24, Vox.PHOS_AMBER)
					else:
						draw_string(f, ps + Vector2(-136, 8), "PAD 07", HORIZONTAL_ALIGNMENT_RIGHT, 100, 24, Vox.PHOS_AMBER)
		# Course marker (amber diamond, or an edge arrow when off screen)
		if ship.course_target != null:
			var t: Vector3 = ship.course_target
			var a := Vox.PHOS_AMBER
			var label := "%s %.1f KM" % [GameState.station_name(ship.course_station).to_upper() if ship.course_station != "" else "WAYPOINT", ship.global_position.distance_to(t) / 1000.0]
			var behind := cam.is_position_behind(t)
			var s := cam.unproject_position(t)
			var on := not behind and Rect2(Vector2(40, 40), size - Vector2(80, 80)).has_point(s)
			if on and ship.global_position.distance_to(t) < 3000 and ship.course_station != "":
				pass  # the station bracket already marks it up close
			elif on:
				var pts := PackedVector2Array([s + Vector2(0, -16), s + Vector2(16, 0), s + Vector2(0, 16), s + Vector2(-16, 0), s + Vector2(0, -16)])
				draw_polyline(pts, a, 3)
				if ship.course_station == "":
					draw_string(f, s + Vector2(22, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, a)
			else:
				var dir := (s - size / 2)
				if behind:
					dir = -dir
				if dir.length() < 1:
					dir = Vector2(0, 1)
				dir = dir.normalized()
				var e := size / 2 + dir * Vector2(size.x * 0.42, size.y * 0.38)
				var n := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([e + dir * 22, e + n * 12, e - n * 12]), a)
				draw_string(f, e - dir * 30 + Vector2(-80, 0), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, a)


func setup(p_main: Node) -> void:
	main = p_main
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_overlay = FlightOverlay.new()
	_overlay.hud = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay)

	_cross = ColorRect.new()
	(_cross as ColorRect).color = Vox.CREAM
	_cross.size = Vector2(6, 6)
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.position = -_cross.size / 2
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cross)

	_prompt = _panel_label(root, 24, Vox.CREAM, GameState.font_label)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position.y = -190

	_toast = _panel_label(root, 22, Vox.CREAM, GameState.font_label)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(760, 0)
	_toast.position.y = 70

	_objective = _panel_label(root, 20, Vox.CREAM, GameState.font_label)
	_objective.position = Vector2(20, 20)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(420, 0)

	_wrist = _panel_label(root, 28, Vox.PHOS_GREEN, GameState.font_crt, Color("0d2414"))
	_wrist.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_wrist.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wrist.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_wrist.position = Vector2(-20, -20)

	_hints = _panel_label(root, 19, Vox.CREAM, GameState.font_label)
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints.position = Vector2(20, -20)

	terminal = TradeTerminalUI.new()
	add_child(terminal)

	_pause = _build_pause()
	add_child(_pause)
	GameState.toast.connect(show_toast)


func _panel_label(parent: Control, size: int, color: Color, font: Font, bg := Color(0.08, 0.06, 0.045, 0.85)) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	l.add_theme_stylebox_override("normal", sb)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_pause() -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(dim)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameState.font_crt)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Vox.PHOS_GREEN)
	l.text = """PAUSED

ON FOOT                  KEYBOARD / MOUSE      GAMEPAD
Walk / look              WASD / mouse          LS / RS
Sprint                   Shift                 L3
Use, lift, place crate   F                     A

IN THE COCKPIT
Throttle fwd / back      W / S                 RT / LT
Strafe, up / down        A D, Space / Z        RS
Pitch / yaw              Mouse or arrows       LS
Roll                     Q / E                 LB / RB
Request dock / land      L                     X
Nav computer             N                     Y
Cruise                   C                     L3
Leave seat (landed)      F                     A

Resume: Esc / P / Start        Quit: Q / Back"""
	p.add_child(l)
	return p


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 6.0


func _unhandled_input(event: InputEvent) -> void:
	# The HUD keeps running while the tree is paused, so it owns resume and quit.
	if not get_tree().paused:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("cancel"):
		main._set_paused(false)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
		get_tree().quit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
		get_tree().quit()
	else:
		return
	get_viewport().set_input_as_handled()


func set_paused(v: bool) -> void:
	_pause.visible = v


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	for l in [_toast, _objective, _wrist, _hints, _prompt]:
		l.reset_size()
	_toast.size.x = 760
	_objective.position = Vector2(20, 20)
	var ty := 74.0
	if _objective.visible and _objective.position.x + _objective.size.x > (vs.x - 760) / 2:
		ty = _objective.position.y + _objective.size.y + 14
	if main.ship.nav_mode:
		ty = vs.y - _toast.size.y - 90  # keep the nav CRT clear
	_toast.position = Vector2((vs.x - 760) / 2, ty)
	_hints.position = Vector2(20, vs.y - _hints.size.y - 20)
	_wrist.position = vs - _wrist.size - Vector2(20, 20)
	_prompt.position = Vector2((vs.x - _prompt.size.x) / 2, vs.y - 200)
	_cross.position = vs / 2 - _cross.size / 2


func _process(delta: float) -> void:
	_toast_time -= delta
	_toast.visible = _toast_time > 0.0
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	var mode: String = main.mode
	var ship: Ship = main.ship
	var g := GameState.using_gamepad
	_cross.visible = mode == "foot"
	_wrist.visible = mode == "foot"
	_objective.text = main.objective()
	_objective.visible = mode != "terminal" and not ship.nav_mode and _objective.text != ""
	var player: Player = main.player
	_prompt.visible = mode == "foot" and player.prompt != ""
	if _prompt.visible:
		var key := "A" if g else "F"
		_prompt.text = ("[%s]  " % key) + player.prompt if not player.prompt.begins_with("Aim") and not player.prompt.ends_with("full") else player.prompt
	if _wrist.visible:
		var where := "IN TRANSIT"
		if ship.landed_at:
			where = ship.landed_at.display_name.to_upper()
		_wrist.text = "CR %s\nHOLD %02d/32 SCU\n%s · PAD 07" % [GameState.money(GameState.credits), ship.hold_count() * GameState.CRATE_SCU, where]
	_hints.visible = mode != "terminal"
	if mode == "foot":
		_hints.text = "LS walk · RS look · A use · Start pause" if g else "WASD walk · Mouse look · F use · Esc pause"
	elif mode == "pilot" and ship.dir_mode:
		_hints.text = "D-pad choose station · A print slip · B back to keypad" if g else "W/S choose station · F print route slip · Esc back to keypad"
	elif mode == "pilot" and ship.nav_mode:
		_hints.text = "D-pad pick key · A press · B close" if g else "Type digits · Enter = ENT · Tab = DIR (route slip) · X = CLR · Backspace · Esc close"
	elif mode == "pilot":
		var land := ship.state == Ship.State.LANDED
		if g:
			_hints.text = ("RT / RS up to lift off · Y nav · A leave seat" if land else "RT/LT throttle · LS pitch/yaw · LB/RB roll · RS strafe · X dock · Y nav · L3 cruise")
		else:
			_hints.text = ("W or Space to lift off · N nav · M route slip · F leave seat" if land else "W/S throttle · Mouse pitch/yaw · Q/E roll · A/D strafe · Space/Z up/down · L dock · N nav · C cruise")
	_layout()
