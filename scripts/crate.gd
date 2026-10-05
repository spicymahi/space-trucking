class_name Crate
extends StaticBody3D
## One cargo crate (2 SCU) of a single commodity.

var commodity := "water_ice"
var slot: Slot = null
var _shape: CollisionShape3D


static func create(commodity_id: String) -> Crate:
	var c := Crate.new()
	c.commodity = commodity_id
	c._build()
	return c


func _build() -> void:
	name = "Crate_" + commodity
	collision_layer = Vox.L_CRATE
	collision_mask = 0
	var s := Slot.CRATE_SIZE
	var col: Color = GameState.COMMODITIES[commodity]["color"]
	Vox.box(self, Vector3.ZERO, s, col)
	Vox.box(self, Vector3.ZERO, Vector3(s.x + 0.04, 0.22, s.z + 0.04), Vox.DBROWN)
	Vox.box(self, Vector3(s.x / 2, 0, 0), Vector3(0.06, s.y + 0.04, s.z + 0.04), Vox.DBROWN)
	Vox.box(self, Vector3(-s.x / 2, 0, 0), Vector3(0.06, s.y + 0.04, s.z + 0.04), Vox.DBROWN)
	var short: String = GameState.COMMODITIES[commodity]["short"]
	for side in [1, -1]:
		var l := Vox.label(self, short, Vector3(0, 0.45, side * (s.z / 2 + 0.02)), 0.006, Vox.DBROWN, GameState.font_label)
		if side < 0:
			l.rotation.y = PI
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = s
	cs.shape = sh
	add_child(cs)
	_shape = cs


func display_name() -> String:
	return GameState.COMMODITIES[commodity]["name"]


func set_carried(carried: bool) -> void:
	collision_layer = 0 if carried else Vox.L_CRATE
	_shape.disabled = carried


## Snap into a slot: reparent to the slot's owner (ship or station) at the slot transform.
func place_in(s: Slot) -> void:
	if slot:
		slot.occupant = null
	slot = s
	s.occupant = self
	if get_parent():
		get_parent().remove_child(self)
	s.get_parent().add_child(self)
	transform = s.transform
	set_carried(false)


func remove_from_slot() -> void:
	if slot:
		slot.occupant = null
		slot = null
