class_name Slot
extends Area3D
## A snap-to-grid cargo position, in a ship's hold or on a station pallet.

const CRATE_SIZE := Vector3(2.2, 1.6, 2.2)

var occupant: Crate = null
var slot_label := ""
var kind := "hold" # "hold" or "pallet"


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


func describe() -> String:
	return ("hold slot " if kind == "hold" else "pallet slot ") + slot_label
