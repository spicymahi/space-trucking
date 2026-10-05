class_name NavComputer
extends Node3D
## The cockpit nav computer: a physical keypad and an amber CRT.
## You key in a destination grid (X, Y, Z in units of 100 m) and press ENT to set a course.

signal course_set(target: Vector3, station_id: String)
signal exit_requested
signal key_pressed(label: String)

const ROWS := [["7", "8", "9", "DIR"], ["4", "5", "6", "+/-"], ["1", "2", "3", "CLR"], ["<", "0", "ENT"]]
const PITCH := 0.27

var screen: CrtScreen
var camera: Camera3D
var active := false

var fields: Array[String] = ["", "", ""]
var signs: Array[int] = [1, 1, 1]
var cur := 0
var show_dir := false
var status := "ENTER DESTINATION GRID"
var course_station := ""
var course_target = null # Vector3 or null
var sel := Vector2i(0, 0)
var _keys := {} # label -> MeshInstance3D
var _key_cells := {} # Vector2i -> label
var _blink := 0.0


func build(p_screen: CrtScreen) -> void:
	screen = p_screen
	Vox.box(self, Vector3(0, -0.05, 0.03), Vector3(1.25, 0.08, 1.2), Vox.DBROWN)
	for r in ROWS.size():
		var row: Array = ROWS[r]
		for c in row.size():
			var lbl: String = row[c]
			var wide := lbl == "ENT"
			var x := (c - 1.5) * PITCH + (PITCH * 0.5 if wide else 0.0)
			var pos := Vector3(x, 0.03, (r - 1.5) * PITCH)
			var size := Vector3(PITCH * 2 - 0.05 if wide else 0.22, 0.08, 0.22)
			var body := StaticBody3D.new()
			body.collision_layer = Vox.L_KEYPAD
			body.collision_mask = 0
			body.position = pos
			body.set_meta("key", lbl)
			add_child(body)
			Vox.add_shape(body, Vector3.ZERO, size)
			var col := Vox.ORANGE if lbl == "ENT" else (Vox.MUSTARD if lbl in ["DIR", "CLR", "+/-", "<"] else Vox.BEIGE)
			var mi := Vox.box(body, Vector3.ZERO, size, col)
			mi.set_meta("base", col)
			var l := Vox.label(body, lbl, Vector3(0, 0.045, 0), 0.0011 if lbl.length() > 1 else 0.0016, Vox.DBROWN, GameState.font_label)
			l.rotation.x = -PI / 2
			_keys[lbl] = mi
			_key_cells[Vector2i(c, r)] = lbl
	_refresh()


func set_active(v: bool) -> void:
	active = v
	_highlight()
	_refresh()


func _process(delta: float) -> void:
	_blink += delta
	if active and fmod(_blink, 0.5) < delta:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.physical_keycode
		var handled := ""
		if k >= KEY_0 and k <= KEY_9:
			handled = str(k - KEY_0)
		elif k >= KEY_KP_0 and k <= KEY_KP_9:
			handled = str(k - KEY_KP_0)
		else:
			match k:
				KEY_ENTER, KEY_KP_ENTER: handled = "ENT"
				KEY_BACKSPACE: handled = "<"
				KEY_DELETE, KEY_X: handled = "CLR"
				KEY_MINUS, KEY_EQUAL, KEY_KP_SUBTRACT, KEY_KP_ADD: handled = "+/-"
				KEY_TAB: handled = "DIR"
		if handled != "":
			press(handled)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and camera:
		var from := camera.project_ray_origin(event.position)
		var q := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(event.position) * 4.0, Vox.L_KEYPAD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.collider.has_meta("key"):
			press(hit.collider.get_meta("key"))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("nav_computer"):
		exit_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_left"):
		_move(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		_move(Vector2i(1, 0))
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		press(_key_cells.get(sel, "ENT"))
	else:
		return
	get_viewport().set_input_as_handled()


func _move(d: Vector2i) -> void:
	var n := sel + d
	n.y = clampi(n.y, 0, ROWS.size() - 1)
	n.x = clampi(n.x, 0, ROWS[n.y].size() - 1)
	sel = n
	_highlight()


func _highlight() -> void:
	for cell in _key_cells:
		var mi: MeshInstance3D = _keys[_key_cells[cell]]
		var base: Color = mi.get_meta("base")
		mi.material_override = Vox.mat(Vox.PHOS_AMBER, true) if (active and cell == sel and GameState.using_gamepad) else Vox.mat(base)


## Press a keypad key by its label. Also used by tests.
func press(key: String) -> void:
	key_pressed.emit(key)
	if _keys.has(key):
		var mi: MeshInstance3D = _keys[key]
		var t := create_tween()
		t.tween_property(mi, "position:y", -0.04, 0.05)
		t.tween_property(mi, "position:y", 0.0, 0.08)
	if key.is_valid_int():
		show_dir = false
		if fields[cur].length() < 3:
			fields[cur] += key
		if fields[cur].length() == 3 and cur < 2:
			cur += 1
	else:
		match key:
			"+/-":
				signs[cur] *= -1
			"<":
				if fields[cur] == "" and cur > 0:
					cur -= 1
				fields[cur] = fields[cur].substr(0, maxi(0, fields[cur].length() - 1))
			"CLR":
				fields.assign(["", "", ""])
				signs.assign([1, 1, 1])
				cur = 0
				status = "ENTER DESTINATION GRID"
			"DIR":
				show_dir = not show_dir
			"ENT":
				_enter()
	_refresh()


func _enter() -> void:
	for i in 3:
		if fields[i] == "":
			cur = i
			status = "GRID INCOMPLETE"
			return
	var g := Vector3i(int(fields[0]) * signs[0], int(fields[1]) * signs[1], int(fields[2]) * signs[2])
	course_target = Vector3(g) * 100.0
	course_station = GameState.station_at_grid(g)
	status = "COURSE SET" if course_station != "" else "WAYPOINT SET · NO BEACON"
	course_set.emit(course_target, course_station)


func clear_course() -> void:
	course_target = null
	course_station = ""
	status = "ENTER DESTINATION GRID"
	_refresh()


func _field_text(i: int) -> String:
	var s := ("+" if signs[i] > 0 else "-") + fields[i]
	var pad := 3 - fields[i].length()
	var cursor := active and i == cur and fmod(_blink, 1.0) < 0.5
	for p in pad:
		s += "_" if not (cursor and p == 0) else "█"
	return s


func _refresh() -> void:
	if not screen:
		return
	var t := "NAV COMPUTER  MK-II\n"
	if show_dir:
		t += "STATION DIRECTORY\n------------------------------\n"
		for id in GameState.STATIONS:
			var g := GameState.station_grid(id)
			t += "%-13s\n   X%s Y%s Z%s\n" % [GameState.station_name(id).to_upper(), GameState.format_grid(g.x), GameState.format_grid(g.y), GameState.format_grid(g.z)]
		t += "------------------------------\nPRESS DIR TO GO BACK"
	else:
		t += "------------------------------\nDESTINATION GRID (x100 M)\n"
		for i in 3:
			t += ("> " if i == cur and active else "  ") + ["X", "Y", "Z"][i] + "  " + _field_text(i) + "\n"
		t += "------------------------------\n" + status + "\n"
		if course_target != null:
			t += "TO  " + (GameState.station_name(course_station).to_upper() if course_station != "" else "DEEP SPACE") + "\n"
			var ship := get_parent()
			if ship is Node3D:
				t += "DIST %.2f KM\n" % [(course_target - (ship as Node3D).global_position).length() / 1000.0]
		else:
			t += "DIR = STATION LIST\n"
	screen.set_text(t)


func refresh_distance() -> void:
	if course_target != null and not show_dir:
		_refresh()
