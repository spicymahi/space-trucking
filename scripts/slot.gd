class_name Slot
extends Area3D
## A snap-to-grid cargo position, in a ship's hold or on a station pallet.

const CRATE_SIZE := Vector3(2.2, 1.6, 2.2)

var occupant: Crate = null
var slot_label := ""
var kind := "hold" # "hold" or "pallet"
var below: Slot = null
var above: Slot = null


func _init(p_label := "", p_kind := "hold") -> void:
	slot_label = p_label
	kind = p_kind
	collision_layer = Vox.L_SLOT
	collision_mask = 0
	monitoring = false
	monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = CRATE_SIZE * 0.95
	cs.shape = sh
	add_child(cs)


func is_free() -> bool:
	return occupant == null


## Upper slots need a crate underneath, so nothing floats in mid-air.
func is_supported() -> bool:
	return below == null or below.occupant != null


func can_take() -> bool:
	return is_free() and is_supported()


## Links each slot to the one stacked directly on top of it.
static func link_stacks(slots: Array[Slot]) -> void:
	for a in slots:
		for b in slots:
			var d := b.position - a.position
			if absf(d.x) < 0.1 and absf(d.z) < 0.1 and d.y > 0.1 and d.y < CRATE_SIZE.y + 0.2:
				a.above = b
				b.below = a


func describe() -> String:
	return ("hold slot " if kind == "hold" else "pallet slot ") + slot_label


## Lowers any crate left hanging over an emptied slot.
static func settle(slots: Array[Slot]) -> void:
	for s in slots:
		var c := s.occupant
		if c == null:
			continue
		var to := s
		while to.below and to.below.is_free():
			to = to.below
		if to != s:
			c.place_in(to)
