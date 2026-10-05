class_name NavDirectory
extends Node3D
## The cockpit's station directory: a small green CRT with a dot-matrix printer.
## Pick a station and it prints a route slip with that station's grid. The slip
## clips next to the nav keypad, so you can read it while you key in the course.

signal printed(station_id: String)
signal exit_requested

const SLIP_SIZE := Vector2(0.6, 0.72)
const PAPER := Color("efe6cf")
const INK := Color("2a1d12")
const SLOT := Vector3(0, 0.065, 0.405) # printer slot on the front face

var screen: CrtScreen
var camera: Camera3D
var clip: Node3D # finished slips go here, next to the keypad
var active := false
var printing := false
var sel := 0
var status := ""
var slip: Node3D = null
var _keys := {} # "UP" / "DOWN" / "PRINT" -> MeshInstance3D


func build() -> void:
	# Low and flat, so it stays under the pilot's line of sight to the scanner CRT.
	Vox.box(self, Vector3(0, 0.13, 0), Vector3(0.9, 0.26, 0.8), Vox.BEIGE)
	Vox.box(self, Vector3(0, 0.22, 0.402), Vector3(0.9, 0.04, 0.01), Vox.ORANGE)
	Vox.box(self, SLOT, Vector3(0.7, 0.035, 0.02), Color("16130f"))
	var tag := Vox.label(self, "ROUTE PRINTER", Vector3(0, 0.162, 0.408), 0.0007, Vox.DBROWN, GameState.font_label)
	tag.outline_size = 0
	# Tube housing and screen, lying back toward the pilot
	Vox.box(self, Vector3(0, 0.31, -0.18), Vector3(0.84, 0.1, 0.42), Vox.BEIGE2)
	screen = CrtScreen.new(Vector2(0.7, 0.4), Vector2i(480, 274), Vox.PHOS_GREEN, 22)
	screen.position = Vector3(0, 0.4, -0.15)
	screen.rotation.x = deg_to_rad(-64)
	add_child(screen)
	# Keys on the top front edge
	for spec in [["UP", "UP", -0.3, 0.16], ["DOWN", "DN", -0.1, 0.16], ["PRINT", "PRINT", 0.2, 0.32]]:
		var body := StaticBody3D.new()
		body.collision_layer = Vox.L_KEYPAD
		body.collision_mask = 0
		body.position = Vector3(spec[2], 0.29, 0.25)
		body.set_meta("dir_key", spec[0])
		add_child(body)
		var size := Vector3(spec[3], 0.06, 0.16)
		Vox.add_shape(body, Vector3.ZERO, size)
		var col := Vox.ORANGE if spec[0] == "PRINT" else Vox.MUSTARD
		var mi := Vox.box(body, Vector3.ZERO, size, col)
		mi.set_meta("base", col)
		var l := Vox.label(body, spec[1], Vector3(0, 0.035, 0), 0.0012, Vox.DBROWN, GameState.font_label)
		l.rotation.x = -PI / 2
		_keys[spec[0]] = mi
	_refresh()


func station_ids() -> Array:
	return GameState.STATIONS.keys()


func set_active(v: bool) -> void:
	active = v
	if v:
		status = ""
	_highlight()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and camera:
		var from := camera.project_ray_origin(event.position)
		var q := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(event.position) * 4.0, Vox.L_KEYPAD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.collider.has_meta("dir_key"):
			press(hit.collider.get_meta("dir_key"))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		exit_requested.emit()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("nav_computer") or event.is_action_pressed("nav_directory"):
		exit_requested.emit()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		press("UP")
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		press("DOWN")
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		press("PRINT")
	else:
		return
	get_viewport().set_input_as_handled()


## Press a directory key by name: UP, DOWN or PRINT. Also used by tests.
func press(key: String) -> void:
	if printing:
		return
	if _keys.has(key):
		var mi: MeshInstance3D = _keys[key]
		var t := create_tween()
		t.tween_property(mi, "position:y", -0.03, 0.05)
		t.tween_property(mi, "position:y", 0.0, 0.08)
	var n := station_ids().size()
	match key:
		"UP":
			sel = posmod(sel - 1, n)
			status = ""
		"DOWN":
			sel = posmod(sel + 1, n)
			status = ""
		"PRINT":
			print_slip()
	_refresh()


func _highlight() -> void:
	var lit := "PRINT" if active and GameState.using_gamepad else ""
	for k in _keys:
		var mi: MeshInstance3D = _keys[k]
		mi.material_override = Vox.mat(Vox.PHOS_AMBER, true) if k == lit else Vox.mat(mi.get_meta("base"))


func _distance_km(id: String) -> float:
	var st: Vector3 = GameState.STATIONS[id]["position"]
	return st.distance_to(global_position if is_inside_tree() else Vector3.ZERO) / 1000.0


func _refresh() -> void:
	if not screen:
		return
	var g := GameState.using_gamepad
	var t := "STATION DIRECTORY" + ("   * JOB" if not GameState.jobs.is_empty() else "") + "\n"
	var ids := station_ids()
	for i in ids.size():
		var km := _distance_km(ids[i])
		var where := "HERE" if km < 1.5 else "%.1f KM" % km
		var job := "*" if GameState.jobs_to(ids[i]) > 0 else " "
		t += "%s%s%-14s%8s\n" % [">" if i == sel else " ", job, GameState.station_name(ids[i]).to_upper(), where]
	var grid := GameState.station_grid(ids[sel])
	t += "-------------------------\nGRID %s %s %s\n" % [GameState.format_grid(grid.x), GameState.format_grid(grid.y), GameState.format_grid(grid.z)]
	if status != "":
		t += status + "\n"
	elif active:
		t += ("D-PAD PICK · A PRINT · B BACK" if g else "W/S PICK · F PRINT · ESC BACK") + "\n"
	screen.set_text(t)


## Prints a route slip for the selected station: it feeds out of the slot line by
## line, tears off and clips next to the keypad, replacing any older slip.
func print_slip() -> void:
	if printing:
		return
	var id: String = station_ids()[sel]
	printing = true
	status = "PRINTING..."
	_refresh()
	var s := make_slip(id, _distance_km(id))
	add_child(s)
	var start := SLOT + Vector3(0, 0, -SLIP_SIZE.y / 2 - 0.02)
	var end := SLOT + Vector3(0, 0, SLIP_SIZE.y / 2 - 0.04)
	s.position = start
	var t := create_tween()
	for i in 8:
		t.tween_interval(0.09)
		t.tween_property(s, "position", start.lerp(end, (i + 1) / 8.0), 0.03)
	t.tween_interval(0.35)
	t.tween_callback(_tear_off.bind(s, id))


func _tear_off(s: Node3D, id: String) -> void:
	if slip and is_instance_valid(slip):
		slip.queue_free()
	slip = s
	s.reparent(clip)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(s, "transform", Transform3D.IDENTITY, 0.6)
	t.tween_callback(func():
		printing = false
		status = "PRINTED: " + GameState.station_name(id).to_upper()
		_refresh()
		printed.emit(id))


## The text printed on a route slip, one line per row.
static func slip_lines(id: String, km: float) -> PackedStringArray:
	var g := GameState.station_grid(id)
	return PackedStringArray([
		"ROUTE SLIP",
		GameState.station_name(id).to_upper(),
		"X " + GameState.format_grid(g.x),
		"Y " + GameState.format_grid(g.y),
		"Z " + GameState.format_grid(g.z),
		"%.1f KM" % km,
	])


## A paper slip lying flat (face up, top edge toward -Z), centred on its origin.
static func make_slip(id: String, km: float) -> Node3D:
	var s := Node3D.new()
	s.name = "RouteSlip"
	s.set_meta("station", id)
	Vox.box(s, Vector3.ZERO, Vector3(SLIP_SIZE.x, 0.006, SLIP_SIZE.y), PAPER)
	# Centred lines, scaled down if a long station name would run off the paper.
	var lines := slip_lines(id, km)
	var widest := 1.0
	for line in lines:
		widest = maxf(widest, GameState.font_crt.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x)
	var px := minf(0.0012, (SLIP_SIZE.x - 0.12) / widest)
	var l := Vox.label(s, "\n".join(lines), Vector3(0, 0.005, 0.02), px, INK, GameState.font_crt)
	l.rotation.x = -PI / 2
	l.name = "Text"
	# Tear edge
	for i in 6:
		Vox.box(s, Vector3(-SLIP_SIZE.x / 2 + 0.05 + i * 0.1, 0.004, -SLIP_SIZE.y / 2 + 0.015), Vector3(0.05, 0.002, 0.012), Color("c9bb98"))
	return s
