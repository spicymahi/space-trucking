class_name Cockpit
extends Node3D
## The Kestrel-9's cockpit art: CRT monitor housings, the gauge hood with analog dials, an LED
## course readout, toggles and lamps, the canopy frame, side consoles, the seat and wall trim.
## Static pieces go into a few Vox.Batch meshes (one draw call each). Every piece bigger than a
## knob has a matching collider on the ship; ColliderAudit checks that in the selftest.
## Ship space: forward is -Z, the cockpit floor top is y = 0.3, the canopy is at z = -13.75.

const CRT_X := [-1.95, 0.0, 1.95]
const CRT_Y := 0.85
const CRT_Z := -11.45
const CRT_TILT := -12.0
const SCREEN := Vector2(1.6, 1.2)
## The gauge hood's face, tilted back toward the pilot's eye.
const HOOD := Vector3(0, 1.72, -12.75)
const HOOD_TILT := -20.0
const BEZEL := Color("3a3029")
const BEZEL_HI := Color("564739")
const INK := Color("16130f")
const CHROME := Color("8a8070")
const LED_RED := Color("ff4a2e")
## Matte glareshield on top of the hood, dark so the sun does not flare off it.
const GLARE := Color("1c1612")

var ship: Ship
var lamps := {} # name -> MeshInstance3D, with meta "on" (lit colour)
var _needles := {} # gauge -> Node3D pivot
var _toggles := {} # name -> Node3D pivot
var _throttle: Node3D
var _led: Label3D
var _speed := 0.0
var _climb := 0.0


func build(p_ship: Ship) -> void:
	ship = p_ship
	name = "Cockpit"
	var b := Vox.Batch.new(ship)
	b.collider = ship.interior # only the canopy frame and its glass (in _canopy) face outside
	_dash(b)
	for x in CRT_X:
		_monitor(b, x)
	_hood(b)
	_canopy(b)
	_desk(b)
	_seat(b)
	_walls(b)
	b.commit("CockpitArt")
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.3, -11.6)
	glow.omni_range = 2.6
	glow.light_energy = 0.45
	glow.light_color = Color("ffc070")
	add_child(glow)


## A Node3D in ship space at the frame, for moving parts and labels.
func _node(frame: Transform3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.transform = frame * Transform3D(Basis.IDENTITY, pos)
	add_child(n)
	return n


## A black Dymo-style tape label with cream letters, in frame space.
func _dymo(b: Vox.Batch, text: String, pos: Vector3, px := 0.0011) -> void:
	var w := 0.035 + text.length() * 96 * px * 0.42
	b.box(pos + Vector3(0, 0, -0.004), Vector3(w, 96 * px * 0.75, 0.008), INK)
	var l := Vox.label(_node(b.frame, pos + Vector3(0, -0.003, 0.002)), text, Vector3.ZERO, px, Vox.CREAM, GameState.font_label)
	l.outline_size = 0


## Pixel-circle disc facing +Z in frame space.
func _disc(b: Vox.Batch, c: Vector3, r: float, depth: float, color: Color, v := 0.035) -> void:
	var y := -r + v / 2
	while y < r:
		var w := snappedf(sqrt(maxf(r * r - y * y, 0.0)) * 2.0, v)
		if w > 0.0:
			b.box(c + Vector3(0, y, 0), Vector3(w, v, depth), color)
		y += v


# ---------------------------------------------------------------- dash and monitors

func _dash(b: Vox.Batch) -> void:
	b.frame = Transform3D.IDENTITY
	b.solid(Vector3(0, 0.9, -12.4), Vector3(9.6, 1.2, 1.6), Vox.BEIGE)
	b.box(Vector3(0, 1.515, -12.4), Vector3(9.6, 0.03, 1.6), Vox.BEIGE2)
	b.box(Vector3(0, 1.49, -11.6), Vector3(9.6, 0.1, 0.04), Vox.DBROWN)
	b.box(Vector3(0, 0.38, -11.6), Vector3(9.6, 0.16, 0.04), Vox.DBROWN)
	# Hazard chevrons along the front of the dash top
	for i in 16:
		b.box(Vector3(-2.25 + i * 0.3, 1.535, -11.85), Vector3(0.3, 0.02, 0.2), Vox.MUSTARD if i % 2 == 0 else Vox.DBROWN)
	# Side consoles, flush with the monitor fronts
	for sx in [-1, 1]:
		var x: float = 3.875 * sx
		b.solid(Vector3(x, 0.9, -11.4), Vector3(1.85, 1.2, 0.4), Vox.BEIGE)
		b.box(Vector3(x, 1.44, -11.19), Vector3(1.85, 0.12, 0.02), Vox.BEIGE2)
		b.box(Vector3(x, 1.26, -11.19), Vector3(1.85, 0.08, 0.02), Vox.ORANGE)
		b.box(Vector3(x, 1.17, -11.19), Vector3(1.85, 0.04, 0.02), Vox.MUSTARD)
		for c in [Vector2(-0.85, 1.36), Vector2(0.85, 1.36), Vector2(-0.85, 0.45), Vector2(0.85, 0.45)]:
			b.box(Vector3(x + c.x, c.y, -11.19), Vector3(0.04, 0.04, 0.03), CHROME)
	# Left: comms speaker grille and knobs
	b.frame = Transform3D(Basis.IDENTITY, Vector3(-3.875, 0, -11.2))
	for i in 6:
		b.box(Vector3(0.25, 0.98 - i * 0.07, 0.005), Vector3(0.9, 0.03, 0.02), INK)
	for k in [Vector3(-0.55, 0.92, 0.03), Vector3(-0.55, 0.66, 0.03)]:
		b.box(k, Vector3(0.12, 0.12, 0.06), Vox.CREAM)
		b.box(k + Vector3(0, 0.035, 0.035), Vector3(0.02, 0.05, 0.01), INK)
	_dymo(b, "COMMS", Vector3(0.25, 1.06, 0.012))
	# Right: systems push-buttons with telltales over them
	b.frame = Transform3D(Basis.IDENTITY, Vector3(3.875, 0, -11.2))
	var cols := [Vox.ORANGE, Vox.MUSTARD, Vox.BEIGE2, Vox.TEAL]
	for i in 4:
		var x := -0.54 + i * 0.36
		b.box(Vector3(x, 0.78, 0.01), Vector3(0.26, 0.2, 0.02), INK)
		b.box(Vector3(x, 0.78, 0.04), Vector3(0.2, 0.14, 0.05), cols[i])
		var tell := Vox.box(_node(b.frame, Vector3(x, 0.98, 0.015)), Vector3.ZERO, Vector3(0.08, 0.05, 0.02), Vox.PHOS_AMBER if i < 3 else Color("3a3029"), i < 3)
		tell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dymo(b, "SYSTEMS", Vector3(0, 1.07, 0.012))


## A chunky monitor housing around one CRT, with stepped (voxel-rounded) corners.
func _monitor(b: Vox.Batch, x: float) -> void:
	b.frame = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(CRT_TILT)), Vector3(x, CRT_Y, CRT_Z))
	var w := SCREEN.x / 2
	var h := SCREEN.y / 2
	var t := 0.14
	b.shape(Vector3(0, 0, -0.12), Vector3(SCREEN.x + 2 * t, SCREEN.y + 2 * t, 0.36))
	b.box(Vector3(0, 0, -0.17), Vector3(SCREEN.x, SCREEN.y, 0.3), Color("0d0a08"))
	for sy in [-1, 1]:
		b.box(Vector3(0, sy * (h + t / 2), -0.12), Vector3(SCREEN.x + 2 * t, t, 0.36), BEZEL)
	for sx in [-1, 1]:
		b.box(Vector3(sx * (w + t / 2), 0, -0.12), Vector3(t, SCREEN.y, 0.36), BEZEL)
		for sy in [-1, 1]:
			b.box(Vector3(sx * (w - 0.035), sy * (h - 0.035), 0.03), Vector3(0.07, 0.07, 0.06), BEZEL)
			b.box(Vector3(sx * (w - 0.0875), sy * (h - 0.0175), 0.03), Vector3(0.035, 0.035, 0.06), BEZEL)
			b.box(Vector3(sx * (w - 0.0175), sy * (h - 0.0875), 0.03), Vector3(0.035, 0.035, 0.06), BEZEL)
	b.box(Vector3(0, h + t - 0.015, 0.062), Vector3(SCREEN.x + 2 * t, 0.03, 0.004), BEZEL_HI)
	# Brightness and contrast knobs, a power lamp, and the Dymo tag
	for k in [w - 0.08, w - 0.2]:
		b.box(Vector3(k, -h - t / 2, 0.08), Vector3(0.07, 0.07, 0.05), Vox.CREAM)
	var led := Vox.box(_node(b.frame, Vector3(-w + 0.06, -h - t / 2, 0.07)), Vector3.ZERO, Vector3(0.04, 0.04, 0.03), Color("7dff8a"), true)
	led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tag: String = ["NAV SCANNER", "NAV COMPUTER", "CARGO"][CRT_X.find(x)]
	_dymo(b, tag, Vector3(0, -h - t / 2, 0.066), 0.0014)
	b.frame = Transform3D.IDENTITY


# ---------------------------------------------------------------- gauge hood

func _hood(b: Vox.Batch) -> void:
	b.frame = Transform3D.IDENTITY
	b.solid(Vector3(0, 1.71, -13.5), Vector3(7.6, 0.42, 1.4), GLARE)
	b.solid(Vector3(0, 1.95, -12.95), Vector3(7.8, 0.06, 0.36), GLARE)
	var hf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(HOOD_TILT)), HOOD)
	b.frame = hf
	b.solid(Vector3.ZERO, Vector3(7.6, 0.5, 0.08), BEZEL)
	b.box(Vector3(0, -0.235, 0.042), Vector3(7.6, 0.03, 0.004), Vox.ORANGE)
	_gauge(b, "speed", -1.35, "M/S", ["0", "40", "80"], true)
	_gauge(b, "climb", 1.35, "CLIMB", ["-", "0", "+"], false)
	# Course distance on a red LED readout
	b.box(Vector3(0, 0.05, 0.05), Vector3(0.86, 0.26, 0.03), Color("1a1410"))
	b.box(Vector3(0, 0.05, 0.068), Vector3(0.76, 0.18, 0.006), Color("0a0605"))
	var ghost := Vox.label(_node(hf, Vector3(0, 0.045, 0.073)), "88.8", Vector3.ZERO, 0.0026, Color("260806"), GameState.font_crt)
	ghost.font_size = 64
	ghost.outline_size = 0
	_led = Vox.label(_node(hf, Vector3(0, 0.045, 0.075)), "--.-", Vector3.ZERO, 0.0026, LED_RED, GameState.font_crt)
	_led.font_size = 64
	_led.outline_size = 0
	_dymo(b, "COURSE KM", Vector3(0, -0.16, 0.05))
	# Toggles mirror the ship: engines, ramp, gear
	var names := ["ENG", "RAMP", "GEAR"]
	for i in 3:
		var x := -2.85 + i * 0.3
		b.box(Vector3(x, 0.06, 0.045), Vector3(0.12, 0.12, 0.012), CHROME)
		b.box(Vector3(x, 0.06, 0.055), Vector3(0.07, 0.07, 0.012), Color("4a4238"))
		var pivot := _node(hf, Vector3(x, 0.06, 0.06))
		Vox.box(pivot, Vector3(0, 0, 0.055), Vector3(0.03, 0.03, 0.11), Color("e8e0d0"))
		Vox.box(pivot, Vector3(0, 0, 0.11), Vector3(0.045, 0.045, 0.03), Color("e8e0d0"))
		_toggles[names[i]] = pivot
		_dymo(b, names[i], Vector3(x, -0.12, 0.05), 0.0009)
	# Status lamps
	var specs := [["GEAR", Color("7dff8a")], ["DOCK", Vox.PHOS_AMBER], ["CRUISE", Color("7dff8a")]]
	for i in 3:
		var x := 2.25 + i * 0.3
		b.box(Vector3(x, 0.02, 0.05), Vector3(0.28, 0.18, 0.03), Color("1a1410"))
		var lm := Vox.box(_node(hf, Vector3(x, 0.02, 0.07)), Vector3.ZERO, Vector3(0.24, 0.14, 0.03), Color("3a3029"))
		lm.set_meta("on", specs[i][1])
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamps[specs[i][0]] = lm
		var l := Vox.label(lm, specs[i][0], Vector3(0, 0, 0.016), 0.00085, Vox.DBROWN, GameState.font_label)
		l.outline_size = 0
	_dymo(b, "STATUS", Vector3(2.55, 0.17, 0.05), 0.0009)
	b.frame = Transform3D.IDENTITY


## A round analog dial with ticks and a needle, on the hood face.
func _gauge(b: Vox.Batch, id: String, x: float, title: String, marks: Array, red_end: bool) -> void:
	var c := Vector3(x, 0.0, 0.0)
	_disc(b, c + Vector3(0, 0, 0.05), 0.235, 0.03, CHROME)
	_disc(b, c + Vector3(0, 0, 0.06), 0.2, 0.03, Vox.CREAM)
	for i in 9:
		var a := deg_to_rad(-135.0 + i * 33.75)
		var dir := Vector3(sin(a), cos(a), 0)
		var red := red_end and i >= 7
		b.box(c + dir * 0.16 + Vector3(0, 0, 0.078), Vector3(0.014, 0.045 if i % 4 == 0 else 0.03, 0.006), Vox.RED if red else Vox.DBROWN, Basis(Vector3.BACK, -a))
	for i in marks.size():
		var a := deg_to_rad(-135.0 + i * 135.0)
		var l := Vox.label(_node(b.frame, c + Vector3(sin(a), cos(a), 0) * 0.105 + Vector3(0, 0, 0.078)), marks[i], Vector3.ZERO, 0.0007, Vox.DBROWN, GameState.font_label)
		l.outline_size = 0
	var t := Vox.label(_node(b.frame, c + Vector3(0, -0.12, 0.078)), title, Vector3.ZERO, 0.0008, Vox.DBROWN, GameState.font_label)
	t.outline_size = 0
	var pivot := _node(b.frame, c + Vector3(0, 0, 0.082))
	Vox.box(pivot, Vector3(0, 0.065, 0), Vector3(0.018, 0.16, 0.008), Vox.RED)
	Vox.box(pivot, Vector3(0, 0, 0.006), Vector3(0.045, 0.045, 0.012), Vox.DBROWN)
	_needles[id] = pivot


# ---------------------------------------------------------------- canopy

## The window glass seals the opening between pillars, hood and brow on the ship body, so
## nothing outside reaches the fittings on the interior body. A visible pane fills the collider.
func _glass(b: Vox.Batch) -> void:
	var pos := Vector3(0, 3.05, -13.85)
	var size := Vector3(7.6, 3.1, 0.7)
	b.collider = ship
	b.shape(pos, size)
	var pane := Vox.box(ship, pos, size, Vox.CREAM)
	pane.name = "CanopyGlass"
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.8, 0.85, 0.07)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	pane.material_override = m


func _canopy(b: Vox.Batch) -> void:
	b.frame = Transform3D.IDENTITY
	for sx in [-1, 1]:
		b.collider = ship # the window frame can meet the outside world
		b.solid(Vector3(4.35 * sx, 3.9, -13.75), Vector3(1.1, 5.0, 0.5), Vox.DBROWN)
		b.collider = ship.interior
		b.solid(Vector3(4.7 * sx, 1.8, -12.0), Vector3(0.5, 0.5, 4), Vox.DBROWN)
		# Pillars lean in toward the brow in voxel steps.
		for i in 10:
			var inner := 3.74 - (i + 1) * 0.055
			var w := 3.8 - inner
			b.solid(Vector3((inner + w / 2) * sx, 2.11 + i * 0.26, -13.75), Vector3(w, 0.26, 0.5), Vox.DBROWN)
			b.box(Vector3((inner + 0.02) * sx, 2.11 + i * 0.26, -13.49), Vector3(0.04, 0.26, 0.02), Vox.BROWN)
	b.collider = ship
	b.solid(Vector3(0, 6.15, -13.75), Vector3(9, 0.6, 0.5), Vox.DBROWN)
	# Brow over the canopy, with the livery stripes facing the pilot
	b.solid(Vector3(0, 5.2, -13.75), Vector3(7.6, 1.3, 0.5), Vox.DBROWN)
	b.box(Vector3(0, 4.74, -13.49), Vector3(7.6, 0.12, 0.02), Vox.ORANGE)
	b.box(Vector3(0, 4.635, -13.49), Vector3(7.6, 0.05, 0.02), Vox.MUSTARD)
	_glass(b)
	b.collider = ship.interior
	# Overhead panel from the brow back over the pilot
	b.solid(Vector3(0, 6.2, -12.2), Vector3(3.2, 0.6, 2.6), Vox.BEIGE2)
	b.box(Vector3(0, 5.89, -12.2), Vector3(3.0, 0.02, 2.4), BEZEL)
	for i in 6:
		b.box(Vector3(-1.1 + i * 0.44, 5.86, -12.6), Vector3(0.12, 0.04, 0.12), CHROME)
		b.box(Vector3(-1.1 + i * 0.44, 5.86, -11.7), Vector3(0.2, 0.04, 0.1), Vox.MUSTARD if i % 2 == 0 else Vox.ORANGE)


# ---------------------------------------------------------------- desk, keypad, printer

func _desk(b: Vox.Batch) -> void:
	b.frame = Transform3D.IDENTITY
	b.solid(Vector3(-0.45, 0.37, -10.2), Vector3(4.0, 0.14, 1.7), Vox.BEIGE3)
	b.box(Vector3(-0.45, 0.43, -9.34), Vector3(4.0, 0.03, 0.02), Vox.ORANGE)
	b.box(Vector3(-0.45, 0.37, -9.34), Vector3(4.0, 0.06, 0.02), Vox.DBROWN)
	# The instruments on the desk are solid too (the keys only take the keypad's mouse ray).
	b.frame = ship.nav.transform
	b.shape(Vector3(0, -0.01, 0.03), Vector3(1.25, 0.16, 1.2))
	b.frame = ship.directory.transform
	b.shape(Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.8))
	b.frame = ship.directory.transform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-64)), Vector3(0, 0.4, -0.15))
	b.shape(Vector3(0, 0, -0.06), Vector3(0.94, 0.64, 0.14))
	b.frame = ship.slip_clip.transform
	b.shape(Vector3(0, -0.01, 0), Vector3(0.68, 0.05, 0.8))
	b.shape(Vector3(0, -0.15, -0.12), Vector3(0.4, 0.25, 0.35))
	b.frame = Transform3D.IDENTITY


# ---------------------------------------------------------------- seat

func _seat(b: Vox.Batch) -> void:
	b.frame = Transform3D(Basis.IDENTITY, Vector3(0, 0, -8))
	b.box(Vector3(0, 0.31, 0), Vector3(0.9, 0.02, 0.9), Vox.DBROWN)
	b.solid(Vector3(0, 0.43, 0.05), Vector3(0.45, 0.26, 0.45), Vox.DBROWN)
	b.solid(Vector3(0, 0.66, 0), Vector3(1.24, 0.2, 1.24), Vox.BROWN)
	b.solid(Vector3(0, 0.83, -0.03), Vector3(1.1, 0.14, 1.1), Vox.ORANGE)
	b.box(Vector3(0, 0.83, -0.59), Vector3(1.12, 0.1, 0.03), Color("b14f22"))
	# Back and headrest (the back's rear face stays at z -7.22, inside the seat's use box)
	b.solid(Vector3(0, 1.6, 0.65), Vector3(1.24, 1.5, 0.26), Vox.BROWN)
	b.box(Vector3(0, 1.6, 0.51), Vector3(1.04, 1.36, 0.04), Vox.ORANGE)
	for i in 3:
		b.box(Vector3(0, 1.2 + i * 0.4, 0.488), Vector3(1.04, 0.04, 0.008), Color("b14f22"))
	b.solid(Vector3(0, 2.55, 0.66), Vector3(0.74, 0.4, 0.24), Vox.BROWN)
	b.box(Vector3(0, 2.55, 0.535), Vector3(0.6, 0.28, 0.02), Vox.ORANGE)
	# Armrests on posts
	for sx in [-1, 1]:
		b.solid(Vector3(0.68 * sx, 1.18, 0.05), Vector3(0.18, 0.12, 0.9), Vox.DBROWN)
		b.solid(Vector3(0.68 * sx, 0.92, 0.4), Vector3(0.1, 0.4, 0.1), Vox.DBROWN)
	# Throttle quadrant on the right, its lever follows the throttle
	b.solid(Vector3(0.98, 0.6, -0.3), Vector3(0.22, 0.6, 0.44), Vox.BEIGE2)
	b.box(Vector3(0.98, 0.91, -0.3), Vector3(0.18, 0.02, 0.36), INK)
	_throttle = _node(b.frame, Vector3(0.98, 0.92, -0.3))
	Vox.box(_throttle, Vector3(0, 0.07, 0), Vector3(0.035, 0.14, 0.035), CHROME)
	Vox.box(_throttle, Vector3(0, 0.16, 0), Vector3(0.1, 0.08, 0.1), Vox.ORANGE)
	b.frame = Transform3D.IDENTITY


# ---------------------------------------------------------------- walls

func _walls(b: Vox.Batch) -> void:
	b.frame = Transform3D.IDENTITY
	# Rubber floor mat with a grid
	b.box(Vector3(0, 0.31, -8.8), Vector3(9.6, 0.02, 9.2), Color("2e2722"))
	for i in 7:
		b.box(Vector3(0, 0.322, -4.6 - i * 1.4), Vector3(9.6, 0.004, 0.04), Color("3d342d"))
	for sx in [-1, 1]:
		var x: float = 4.9 * sx
		b.box(Vector3(x - 0.01 * sx, 0.85, -8.9), Vector3(0.02, 1.1, 9.4), Vox.BEIGE2)
		b.box(Vector3(x - 0.01 * sx, 1.46, -8.9), Vector3(0.02, 0.1, 9.4), Vox.ORANGE)
		b.box(Vector3(x - 0.01 * sx, 1.36, -8.9), Vector3(0.02, 0.05, 9.4), Vox.MUSTARD)
		for z in [-5.6, -8.0, -10.4]:
			b.solid(Vector3(x - 0.06 * sx, 3.4, z), Vector3(0.12, 6.2, 0.26), Vox.BROWN)
		for z in [-6.8, -9.2]:
			var lamp := Vox.box(self, Vector3(x - 0.05 * sx, 4.8, z), Vector3(0.1, 0.36, 0.7), Vox.LAMP, true)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Vox.add_shape(ship.interior, lamp.position, Vector3(0.1, 0.36, 0.7))
	# Hazard trim round the hold door (outside its 2.6 m opening)
	b.frame = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -4.21)) # facing into the cockpit
	for sx in [-1, 1]:
		for i in 10:
			b.box(Vector3(1.39 * sx, 0.43 + i * 0.26, 0), Vector3(0.16, 0.26, 0.02), Vox.MUSTARD if i % 2 == 0 else Vox.DBROWN)
	for i in 11:
		b.box(Vector3(-1.3 + i * 0.26, 2.98, 0), Vector3(0.26, 0.16, 0.02), Vox.MUSTARD if i % 2 == 0 else Vox.DBROWN)
	_dymo(b, "HOLD", Vector3(0, 3.25, 0.012), 0.0016)
	b.frame = Transform3D.IDENTITY


# ---------------------------------------------------------------- live instruments

func _process(delta: float) -> void:
	if ship == null:
		return
	var k := minf(1.0, delta * 6.0)
	var speed := ship.velocity.length()
	_speed = lerpf(_speed, minf(speed, 100.0), k)
	var a := -135.0 + _speed / 100.0 * 270.0
	if ship.cruise:
		a = 128.0 + sin(Time.get_ticks_msec() * 0.02) * 2.0 # pinned
	_needles["speed"].rotation.z = -deg_to_rad(a)
	var climb := clampf(ship.velocity.dot(ship.global_basis.y), -30.0, 30.0)
	_climb = lerpf(_climb, climb, k)
	_needles["climb"].rotation.z = -deg_to_rad(_climb / 30.0 * 135.0)
	var flying := ship.state == Ship.State.FLYING
	_toggles["ENG"].rotation.x = -0.6 if flying else 0.6
	_toggles["RAMP"].rotation.x = -0.6 if ship.state == Ship.State.LANDED else 0.6
	_toggles["GEAR"].rotation.x = -0.6 if not flying else 0.6
	var thr := 0.0
	if ship.piloted and not ship.nav_mode and flying:
		thr = Input.get_action_strength("throttle_up") - Input.get_action_strength("throttle_down")
	_throttle.rotation.x = lerpf(_throttle.rotation.x, -thr * 0.6, k)
	if ship.course_target == null:
		_led.text = "--.-"
	else:
		_led.text = "%4.1f" % minf(ship.global_position.distance_to(ship.course_target) / 1000.0, 99.9)
