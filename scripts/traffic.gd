class_name Traffic
extends Node3D
## The NPC traders working the system. They start parked on station roofs and
## leave at staggered times.

const FLEET := [
	["KITE-4", Color("3d8c87"), 8],
	["MARIGOLD", Color("e3a92c"), 6],
	["OX-11", Color("c8432f"), 10],
	["HERON-2", Color("4f7fb5"), 8],
	["BULWARK", Color("8a5fb0"), 10],
	["TANSY-9", Color("7fd36a"), 6],
]

var npcs: Array[NpcTrader] = []


func setup(stations: Array, seed_value: int) -> void:
	for st in stations:
		_mark_berths(st)
	for i in FLEET.size():
		var spec: Array = FLEET[i]
		var npc := NpcTrader.new()
		npc.build(spec[0], spec[1], spec[2])
		npc.stations = stations
		npc.rng.seed = seed_value + i
		add_child(npc)
		npcs.append(npc)
		# Spread the fleet over the stations, leaving at staggered times.
		var st: Station = stations[(i * 2) % stations.size()]
		if not npc.park_at(st, 4.0 + i * 5.0):
			npc.park_at(stations[(i * 2 + 1) % stations.size()], 4.0 + i * 5.0)


## Painted berth pads on the roof, so parked haulers have somewhere to sit.
func _mark_berths(st: Station) -> void:
	for b in Station.NPC_BERTHS:
		var p: Vector3 = b + Vector3(0, 0.02, 0)
		Vox.box(st, p, Vector3(9, 0.04, 15), Color("3a332d"))
		for sx in [-1, 1]:
			Vox.box(st, p + Vector3(4.4 * sx, 0.01, 0), Vector3(0.3, 0.04, 15), Vox.MUSTARD)
		Vox.box(st, p + Vector3(0, 0.01, 7.4), Vector3(9, 0.04, 0.3), Vox.MUSTARD)


func total_sales() -> int:
	var n := 0
	for npc in npcs:
		n += npc.sales
	return n
