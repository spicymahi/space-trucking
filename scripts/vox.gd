class_name Vox
extends RefCounted
## Helpers for building blocky voxel geometry and collision in code.
## Everything in the slice is placeholder art made from boxes in this palette.

const BEIGE := Color("d8cdb2")
const BEIGE2 := Color("c2b597")
const BEIGE3 := Color("a89a7c")
const BROWN := Color("4a3b2c")
const DBROWN := Color("2c241c")
const ORANGE := Color("e0662f")
const MUSTARD := Color("e3a92c")
const TEAL := Color("3d8c87")
const RED := Color("c8432f")
const CREAM := Color("efe6cf")
const PHOS_GREEN := Color("8cff9e")
const PHOS_AMBER := Color("ffb347")
const LAMP := Color("fff0cc")

# Physics layers (bit values)
const L_WORLD := 1
const L_SHIP := 2
const L_PLAYER := 4
const L_CRATE := 8
const L_BARRIER := 16
const L_SLOT := 32
const L_INTERACT := 64
const L_KEYPAD := 128

static var _mats := {}


static func mat(c: Color, emissive := false, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(), emissive, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.roughness = 0.9
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Visual-only box.
static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, emissive)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Box with a matching collision shape on `body` (positions are in body space).
static func solid(body: CollisionObject3D, pos: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mi := box(body, pos, size, color, emissive)
	add_shape(body, pos, size)
	return mi


static func add_shape(body: CollisionObject3D, pos: Vector3, size: Vector3, basis := Basis.IDENTITY) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = Transform3D(basis, pos)
	body.add_child(cs)
	return cs


static func label(parent: Node3D, text: String, pos: Vector3, px: float, color: Color, font: Font = null, outline := 0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = px
	l.modulate = color
	l.font_size = 96
	l.outline_size = outline
	l.shaded = false
	l.double_sided = false
	if font:
		l.font = font
	parent.add_child(l)
	return l


## Voxel sphere drawn as one MultiMesh. color_fn(x, y, z) -> Color.
static func sphere(parent: Node3D, center: Vector3, r: int, voxel: float, color_fn: Callable) -> MultiMeshInstance3D:
	var pts: Array[Vector3i] = []
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var d := x * x + y * y + z * z
				if d <= r * r + r * 0.5 and d > (r - 1.8) * (r - 1.8):
					pts.append(Vector3i(x, y, z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * voxel
	mm.mesh = bm
	mm.instance_count = pts.size()
	for i in pts.size():
		var p := pts[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p) * voxel))
		mm.set_instance_color(i, color_fn.call(p.x, p.y, p.z))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mmi.material_override = m
	mmi.position = center
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


static func hash3(x: int, y: int, z: int) -> float:
	var h := (x * 374761393 + y * 668265263 + z * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / float(0x7fffffff)
