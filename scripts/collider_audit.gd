class_name ColliderAudit
extends RefCounted
## Checks that what you see on a body is what you bump into.
## Forward: every visible box bigger than a knob sits inside the body's colliders.
## Reverse: every collider is filled by something visible, so nothing invisible blocks you.
## Both allow TOL of slack, so flush trim, decals and recessed glass pass.

const TOL := 0.08
const SMALL := 0.15 # boxes under this on every side (knobs, levers, needles) need no collider
const INSET := 0.03


## Returns a list of problems (empty when clean). Skips crates and the subtrees in `skip`.
static func run(body: CollisionObject3D, skip: Array = []) -> PackedStringArray:
	var inv := body.global_transform.affine_inverse()
	var visuals: Array = [] # [Transform3D, half extents, AABB, label]
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Crate or n in skip:
			continue
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or not (n as MeshInstance3D).is_visible_in_tree():
			continue
		var mi := n as MeshInstance3D
		if mi.has_meta("vox_boxes"):
			for e in mi.get_meta("vox_boxes"):
				visuals.append(_entry(e[0], e[1], "%s box at %s" % [mi.name, _v(e[0].origin)]))
		elif mi.mesh is BoxMesh:
			var t: Transform3D = inv * mi.global_transform
			visuals.append(_entry(t, (mi.mesh as BoxMesh).size, "%s at %s" % [mi.get_path(), _v(t.origin)]))
	var shapes: Array = []
	for c in body.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D and not c.disabled:
			shapes.append(_entry(c.transform, (c.shape as BoxShape3D).size, "collider at %s size %s" % [_v(c.transform.origin), _v((c.shape as BoxShape3D).size)]))
	var out := PackedStringArray()
	for v in visuals:
		if v[1].x * 2 < SMALL and v[1].y * 2 < SMALL and v[1].z * 2 < SMALL:
			continue
		var p = _uncovered(v, shapes, 3)
		if p != null:
			out.append("no collider under visible %s (point %s)" % [v[3], _v(p)])
	for s in shapes:
		var p = _uncovered(s, visuals, 4)
		if p != null:
			out.append("nothing visible fills %s (point %s)" % [s[3], _v(p)])
	return out


static func _entry(t: Transform3D, size: Vector3, label: String) -> Array:
	var h := size / 2
	var aabb := t * AABB(-h, size)
	return [t, h, aabb.grow(TOL), label]


## The first sample point of `a` that lies in none of `others` (grown by TOL), or null.
static func _uncovered(a: Array, others: Array, n: int):
	var t: Transform3D = a[0]
	var h: Vector3 = a[1]
	var near: Array = others.filter(func(o): return (o[2] as AABB).intersects(a[2]))
	var invs: Array = near.map(func(o): return (o[0] as Transform3D).affine_inverse())
	for i in n:
		for j in n:
			for k in n:
				var f := Vector3(i, j, k) / float(n - 1) * 2.0 - Vector3.ONE
				var q := Vector3(maxf(h.x - INSET, 0.0) * f.x, maxf(h.y - INSET, 0.0) * f.y, maxf(h.z - INSET, 0.0) * f.z)
				var p := t * q
				var inside := false
				for m in near.size():
					var l: Vector3 = invs[m] * p
					var oh: Vector3 = near[m][1] + Vector3.ONE * TOL
					if absf(l.x) <= oh.x and absf(l.y) <= oh.y and absf(l.z) <= oh.z:
						inside = true
						break
				if not inside:
					return p
	return null


static func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
