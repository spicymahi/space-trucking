class_name Station
extends Node3D
## A station built from voxel blocks: hangar with landing pad 07 and a cargo pallet,
## and a concourse with the commodity exchange and the (offline) contracts board.
## Local axes: +Y up, the hangar mouth faces +Z.

signal terminal_used(station: Station, kind: String)

const PAD_CENTER := Vector3(0, 0, 5)
const PAD_HALF := 15.0
const LANDED_HEIGHT := 2.0

var station_id := ""
var display_name := ""
var accent := Vox.ORANGE
var docking_granted := false
var pallet_slots: Array[Slot] = []
var hull: StaticBody3D


static func create(id: String) -> Station:
	var s := Station.new()
	s.station_id = id
	s.display_name = GameState.STATIONS[id]["name"]
	s.accent = GameState.STATIONS[id]["accent"]
	s.name = id
	s.position = GameState.STATIONS[id]["position"]
	s._build()
	return s


func _build() -> void:
	hull = StaticBody3D.new()
	hull.name = "Hull"
	hull.collision_layer = Vox.L_WORLD
	hull.collision_mask = 0
	add_child(hull)
	_build_shell()
	_build_hangar()
	_build_pad()
	_build_concourse()
	_build_exterior()


func _build_shell() -> void:
	var h := hull
	Vox.solid(h, Vector3(0, -5, -17), Vector3(112, 10, 166), Color("3a332d"))
	Vox.solid(h, Vector3(0, 40, 8), Vector3(112, 8, 116), Vox.BEIGE)
	for sx in [-1, 1]:
		Vox.solid(h, Vector3(53 * sx, 18, 8), Vector3(6, 36, 116), Vox.BEIGE)
		# Front wall around the 60 x 26 m hangar mouth
		Vox.solid(h, Vector3(40 * sx, 18, 63), Vector3(20, 36, 6), Vox.BEIGE)
		# Back wall around the 8 x 6 m concourse door
		Vox.solid(h, Vector3(27 * sx, 18, -53), Vector3(46, 36, 6), Vox.BEIGE2)
		# Concourse block
		Vox.solid(h, Vector3(24 * sx, 10, -78), Vector3(32, 20, 44), Vox.BEIGE2)
	Vox.solid(h, Vector3(0, 33, 63), Vector3(60, 6, 6), Vox.BEIGE)
	Vox.solid(h, Vector3(0, 2, 63), Vector3(60, 4, 6), Vox.DBROWN)
	Vox.solid(h, Vector3(0, 21, -53), Vector3(8, 30, 6), Vox.BEIGE2)
	Vox.solid(h, Vector3(0, 14.5, -78), Vector3(16, 11, 44), Color("2a221b"))
	Vox.solid(h, Vector3(0, 10, -102), Vector3(80, 20, 4), Vox.BEIGE2)

	# Keeps people on foot from walking out of the hangar mouth. Ships pass through.
	var barrier := StaticBody3D.new()
	barrier.collision_layer = Vox.L_BARRIER
	barrier.collision_mask = 0
	Vox.add_shape(barrier, Vector3(0, 18, 60.5), Vector3(60, 36, 1))
	add_child(barrier)


func _build_hangar() -> void:
	# Floor grid
	for i in range(-48, 49, 8):
		Vox.box(self, Vector3(i, 0.01, 5), Vector3(0.2, 0.02, 110), Color("2f2924"))
	for i in range(-48, 61, 8):
		Vox.box(self, Vector3(0, 0.01, i), Vector3(100, 0.02, 0.2), Color("2f2924"))
	for sx in [-1, 1]:
		Vox.box(self, Vector3(49.8 * sx, 6, 5), Vector3(0.4, 1.6, 110), accent)
		Vox.box(self, Vector3(49.8 * sx, 4.4, 5), Vector3(0.4, 0.6, 110), Vox.MUSTARD)
		Vox.solid(hull, Vector3(49.8 * sx, 1.2, 5), Vector3(0.4, 2.4, 110), Vox.DBROWN)
		for z in range(-44, 60, 12):
			Vox.solid(hull, Vector3(49.4 * sx, 18, z), Vector3(1.2, 36, 1.6), Vox.BEIGE3)
	# Back wall trim, split around the concourse door
	for sx in [-1, 1]:
		Vox.solid(hull, Vector3(27.4 * sx, 6, -49.8), Vector3(45.2, 1.6, 0.4), accent)
		Vox.solid(hull, Vector3(27.4 * sx, 1.2, -49.8), Vector3(45.2, 2.4, 0.4), Vox.DBROWN)
	# Door frame and signs
	Vox.box(self, Vector3(-4.4, 3.2, -49.7), Vector3(0.8, 6.4, 0.6), Vox.MUSTARD)
	Vox.box(self, Vector3(4.4, 3.2, -49.7), Vector3(0.8, 6.4, 0.6), Vox.MUSTARD)
	Vox.box(self, Vector3(0, 6.4, -49.7), Vector3(9.6, 0.8, 0.6), Vox.MUSTARD)
	Vox.label(self, "CONCOURSE · MARKET", Vector3(0, 8.6, -49.6), 0.012, Vox.CREAM, GameState.font_label)
	Vox.label(self, "PAD 07", Vector3(0, 20, -49.6), 0.07, Vox.MUSTARD, GameState.font_label)
	# Ceiling lamps
	for x in [-30, -10, 10, 30]:
		Vox.box(self, Vector3(x, 35.7, 5), Vector3(2, 0.3, 100), Vox.LAMP, true)
	for p in [Vector3(-22, 28, -20), Vector3(22, 28, -20), Vector3(-22, 28, 30), Vector3(22, 28, 30)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 70
		l.light_energy = 1.4
		l.light_color = Color("ffe2b8")
		add_child(l)
	# Docking lights on the mouth
	Vox.box(self, Vector3(-30.6, 17, 60.2), Vector3(0.8, 26, 0.6), Color("7dff8a"), true)
	Vox.box(self, Vector3(30.6, 17, 60.2), Vector3(0.8, 26, 0.6), Color("ff4a2e"), true)
	for i in range(-5, 6):
		Vox.box(self, Vector3(i * 5, 30.8, 66.2), Vector3(2.4, 1, 0.4), Vox.PHOS_AMBER, true)
	# Some parked clutter
	for p in [Vector3(-38, 0, -40), Vector3(-34, 0, -40), Vector3(-38, 0, -36)]:
		Vox.solid(hull, p + Vector3(0, 0.8, 0), Slot.CRATE_SIZE, Vox.BEIGE3)
	Vox.solid(hull, Vector3(40, 4, -38), Vector3(1, 8, 1), Vox.DBROWN)
	Vox.box(self, Vector3(37, 8, -38), Vector3(6, 0.8, 0.8), Vox.MUSTARD)


func _build_pad() -> void:
	var c := PAD_CENTER
	Vox.box(self, c + Vector3(0, 0.05, 0), Vector3(30, 0.1, 30), Color("2a2420"))
	for i in range(-15, 15, 2):
		var col := Vox.MUSTARD if (i / 2) % 2 == 0 else Color("1a1612")
		Vox.box(self, c + Vector3(i + 1, 0.12, -15), Vector3(2, 0.1, 1), col)
		Vox.box(self, c + Vector3(i + 1, 0.12, 15), Vector3(2, 0.1, 1), col)
		Vox.box(self, c + Vector3(-15, 0.12, i + 1), Vector3(1, 0.1, 2), col)
		Vox.box(self, c + Vector3(15, 0.12, i + 1), Vector3(1, 0.1, 2), col)
	for i in range(-14, 15, 4):
		Vox.box(self, c + Vector3(-16.5, 0.3, i), Vector3(0.5, 0.5, 0.5), Color("7dff8a"), true)
		Vox.box(self, c + Vector3(16.5, 0.3, i), Vector3(0.5, 0.5, 0.5), Color("7dff8a"), true)
	var num := Vox.label(self, "07", c + Vector3(0, 0.14, 0), 0.1, Vox.MUSTARD, GameState.font_label)
	num.rotation.x = -PI / 2
	# Cargo pallet 07-B beside the pad: 3 x 3 slots, two layers high.
	var pc := Vector3(24, 0, 2.6)
	Vox.solid(hull, pc + Vector3(0, 0.1, 0), Vector3(8.4, 0.2, 8.4), Color("6a5038"))
	var tag := Vox.label(self, "PALLET 07-B", pc + Vector3(0, 0.05, 5.2), 0.012, Vox.MUSTARD, GameState.font_label)
	tag.rotation.x = -PI / 2
	var n := 0
	for layer in 2:
		for row in 3:
			for col in 3:
				n += 1
				var s := Slot.new("P%d" % n, "pallet")
				s.position = pc + Vector3((col - 1) * 2.6, 1.0 + layer * 1.62, (row - 1) * 2.6)
				add_child(s)
				pallet_slots.append(s)


func _build_concourse() -> void:
	for x in range(-8, 8, 2):
		for z in range(-100, -56, 2):
			var dark := ((x + z) / 2) % 2 == 0
			Vox.box(self, Vector3(x + 1, 0.01, z + 1), Vector3(2, 0.02, 2), Color("5a4a3a") if dark else Color("c9bb98"))
	for sx in [-1, 1]:
		Vox.box(self, Vector3(7.9 * sx, 0.6, -78), Vector3(0.2, 1.2, 44), Vox.DBROWN)
		Vox.box(self, Vector3(7.9 * sx, 1.5, -78), Vector3(0.2, 0.35, 44), accent)
		Vox.box(self, Vector3(7.9 * sx, 1.95, -78), Vector3(0.2, 0.18, 44), Vox.MUSTARD)
		for z in range(-58, -100, -8):
			Vox.box(self, Vector3(7.6 * sx, 4.5, z), Vector3(0.8, 9, 1.2), Vox.BROWN)
	for z in range(-58, -100, -4):
		Vox.box(self, Vector3(0, 8.9, z), Vector3(10, 0.15, 1.2), Vox.LAMP, true)
	for z in [-62, -76, -92]:
		var l := OmniLight3D.new()
		l.position = Vector3(0, 7, z)
		l.omni_range = 16
		l.light_energy = 1.3
		l.light_color = Color("ffe2b8")
		add_child(l)
	Vox.box(self, Vector3(0, 6.8, -60.2), Vector3(9.4, 1.6, 0.3), Vox.DBROWN)
	Vox.label(self, "COMMODITY EXCHANGE  >", Vector3(0, 6.8, -60.0), 0.011, Vox.MUSTARD, GameState.font_label)

	_terminal(Vector3(6.6, 0, -68), "trade", "COMMODITY EXCHANGE", Vox.PHOS_GREEN, "Use commodity exchange")
	_terminal(Vector3(6.6, 0, -80), "contracts", "CONTRACT BOARD", Vox.PHOS_AMBER, "Read contract board")
	# Bench, plant, directory
	Vox.solid(hull, Vector3(-6.5, 0.5, -72), Vector3(1.2, 1, 4), Vox.BROWN)
	Vox.solid(hull, Vector3(-6.5, 0.5, -86), Vector3(1.4, 1, 1.4), Color("3d6b45"))
	Vox.box(self, Vector3(-6.5, 1.6, -86), Vector3(1.8, 1.4, 1.8), Color("5aa060"))
	var dir := Vox.label(self, display_name.to_upper() + "\n" + GameState.STATIONS[station_id]["blurb"].to_upper(), Vector3(-7.75, 4.6, -78), 0.009, Vox.CREAM, GameState.font_label)
	dir.rotation.y = PI / 2


func _terminal(pos: Vector3, kind: String, title: String, screen: Color, prompt: String) -> void:
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = -PI / 2 # screen faces -X, into the corridor
	add_child(t)
	Vox.box(t, Vector3(0, 1.1, 0), Vector3(1.8, 2.2, 1.0), Vox.BEIGE)
	Vox.box(t, Vector3(0, 2.35, -0.1), Vector3(1.9, 0.5, 1.2), Vox.ORANGE if kind == "trade" else Vox.MUSTARD)
	Vox.box(t, Vector3(0, 1.45, 0.51), Vector3(1.4, 1.0, 0.04), Vox.DBROWN)
	Vox.box(t, Vector3(0, 1.45, 0.53), Vector3(1.2, 0.84, 0.02), screen.darkened(0.82), true)
	for i in 5:
		Vox.box(t, Vector3(-0.5 + i * 0.25, 0.8, 0.55), Vector3(0.18, 0.12, 0.1), Vox.ORANGE if i == 0 else Vox.BEIGE3)
	var txt := "> " + title + "\n" + ("BUY · SELL · PRICES" if kind == "trade" else "5 JOBS POSTED")
	Vox.label(t, txt, Vector3(0, 1.5, 0.56), 0.0024, screen, GameState.font_crt)
	Vox.label(t, title, Vector3(0, 2.36, 0.51), 0.0045, Vox.DBROWN, GameState.font_label)
	var it := Interactable.new(prompt, Vector3(1.9, 2.4, 1.1), true)
	it.position = Vector3(0, 1.2, 0)
	t.add_child(it)
	it.used.connect(func(_by): terminal_used.emit(self, kind))


func _build_exterior() -> void:
	for sx in [-1, 1]:
		Vox.box(self, Vector3(56.2 * sx, 22, 8), Vector3(0.4, 4, 116), accent)
		Vox.box(self, Vector3(56.2 * sx, 18.5, 8), Vector3(0.4, 1, 116), Vox.MUSTARD)
		# Solar wings
		Vox.solid(hull, Vector3(100 * sx, 20, 8), Vector3(80, 1, 30), Color("2e3d4a"))
		Vox.solid(hull, Vector3(66 * sx, 20, 8), Vector3(20, 2, 2), Vox.DBROWN)
		for i in range(-3, 4):
			Vox.box(self, Vector3(100 * sx + i * 10, 20.6, 8), Vector3(0.4, 0.2, 30), Color("1a2530"))
	Vox.box(self, Vector3(0, 34, 66.2), Vector3(112, 4, 0.4), accent)
	var r := RandomNumberGenerator.new()
	r.seed = hash(station_id)
	for i in 60:
		var side := 1 if i % 2 == 0 else -1
		Vox.box(self, Vector3(56.3 * side, r.randi_range(4, 32), r.randi_range(-46, 62)), Vector3(0.3, 1, 2), Color("ffd98a") if r.randf() < 0.7 else Color("9fd6ff"), true)
	Vox.solid(hull, Vector3(20, 56, 20), Vector3(1.5, 24, 1.5), Vox.DBROWN)
	Vox.box(self, Vector3(20, 68.5, 20), Vector3(2, 2, 2), Color("ff4a2e"), true)
	Vox.solid(hull, Vector3(-24, 46, -10), Vector3(14, 4, 14), Vox.BEIGE3)
	Vox.solid(hull, Vector3(-24, 50, -10), Vector3(8, 4, 8), Vox.BEIGE2)
	Vox.label(self, display_name.to_upper(), Vector3(0, 39, 66.5), 0.07, Vox.MUSTARD, GameState.font_label, 8)


# ---------------------------------------------------------------- queries

func pad_transform() -> Transform3D:
	var t := Transform3D(Basis(Vector3.UP, PI), PAD_CENTER + Vector3(0, LANDED_HEIGHT, 0))
	return global_transform * t


func in_landing_zone(world_pos: Vector3) -> bool:
	var p := to_local(world_pos) - PAD_CENTER
	return absf(p.x) < PAD_HALF and absf(p.z) < PAD_HALF and p.y > 0.0 and p.y < 28.0


func free_pallet_slots() -> Array[Slot]:
	var out: Array[Slot] = []
	for s in pallet_slots:
		if s.is_free():
			out.append(s)
	return out


func pallet_count(commodity: String) -> int:
	var n := 0
	for s in pallet_slots:
		if s.occupant and s.occupant.commodity == commodity:
			n += 1
	return n


## Removes up to qty crates of a commodity from the pallet. Returns how many were removed.
func take_from_pallet(commodity: String, qty: int) -> int:
	var n := 0
	for s in pallet_slots:
		if n >= qty:
			break
		if s.occupant and s.occupant.commodity == commodity:
			var c := s.occupant
			c.remove_from_slot()
			c.queue_free()
			n += 1
	return n


func spawn_on_pallet(commodity: String, qty: int) -> int:
	var free := free_pallet_slots()
	var n := mini(qty, free.size())
	for i in n:
		var c := Crate.create(commodity)
		c.place_in(free[i])
	return n
