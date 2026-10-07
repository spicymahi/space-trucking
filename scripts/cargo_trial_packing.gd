extends RefCounted
## Shared cargo-grid rules. Coordinates are cells: X across, Y up, Z along.
## Racks open on low X; floor grids can be accessed from all four sides.
const GRID := Vector3i(2, 3, 4)
const CELL := 0.45
const BIN_COUNT := 2
const MAX_PARCEL_VOLUME := 8

var grid := GRID
var bin_count := BIN_COUNT
var open_sides: Array[Vector3i] = [Vector3i.LEFT]
var area_name := "rack"

var placements: Dictionary = {}
var manifest: Dictionary = {}
var solution_order: Array[int] = []

func reset() -> void:
	placements.clear()

func generate(seed_value: int, full: bool = true) -> Array:
	reset()
	manifest.clear()
	solution_order.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var solved: Array = []
	var small_bin := rng.randi_range(0, BIN_COUNT - 1)
	for bin_index in BIN_COUNT:
		if not full and bin_index != small_bin:
			continue
		var bin_parcels := _tiled_bin(rng, bin_index)
		solved.append_array(bin_parcels)
	for index in solved.size():
		var parcel: Dictionary = solved[index]
		parcel.id = index + 1
		parcel.size = _random_orientation(parcel.solution_size, rng)
		manifest[parcel.id] = parcel.duplicate(true)
	# Validate the same loading rules the player uses, rather than assuming that
	# matching volume makes a tiling physically loadable.
	solution_order = _find_solution_order(solved)
	assert(solution_order.size() == solved.size(), "Generated rack must have a supported, accessible loading order")
	reset()
	_shuffle(solved, rng)
	return solved

func get_solution_order() -> Array[int]:
	return solution_order.duplicate()

func can_place(id: int, bin_index: int, cell: Vector3i, size: Vector3i) -> String:
	if not manifest.has(id):
		return "Unknown parcel."
	if placements.has(id):
		return "Pick this parcel up before moving it."
	if bin_index < 0 or bin_index >= bin_count:
		return "Choose a cargo %s." % area_name
	if not _same_shape(size, manifest[id].size):
		return "Parcel dimensions cannot change; rotate the case instead."
	if size.x <= 0 or size.y <= 0 or size.z <= 0:
		return "Parcel dimensions must be positive."
	if cell.x < 0 or cell.y < 0 or cell.z < 0 or cell.x + size.x > grid.x or cell.y + size.y > grid.y or cell.z + size.z > grid.z:
		return "Outside the %s. Rotate the case or choose another cell." % area_name
	for other in placements.values():
		if other.bin == bin_index and _overlaps(cell, size, other.cell, other.size):
			return "Blocked by another parcel."
	if cell.y > 0:
		for x in range(cell.x, cell.x + size.x):
			for z in range(cell.z, cell.z + size.z):
				if not _occupied(bin_index, Vector3i(x, cell.y - 1, z)):
					return "Unsupported: support the entire bottom of this case."
	if not _access_clear(bin_index, cell, size):
		return "Access blocked: load the rear case before the case in front."
	return ""

func place(id: int, bin_index: int, cell: Vector3i, size: Vector3i) -> String:
	var reason := can_place(id, bin_index, cell, size)
	if reason.is_empty():
		placements[id] = {"bin": bin_index, "cell": cell, "size": size}
	return reason

func can_remove(id: int) -> String:
	if not placements.has(id):
		return "That parcel is not in this cargo grid."
	var current: Dictionary = placements[id]
	var top: int = current.cell.y + current.size.y
	for other_id in placements:
		if other_id == id:
			continue
		var other: Dictionary = placements[other_id]
		if other.bin != current.bin:
			continue
		if other.cell.y == top and _footprints_overlap(current.cell, current.size, other.cell, other.size):
			return "Supporting another parcel: remove the upper case first."
	if not _access_clear(current.bin, current.cell, current.size, id):
		return "Access blocked: remove the case in front first."
	return ""

func remove(id: int) -> bool:
	if not can_remove(id).is_empty():
		return false
	placements.erase(id)
	return true

func occupied_volume() -> int:
	var total := 0
	for placement in placements.values():
		total += _volume(placement.size)
	return total

static func rotated_size(size: Vector3i, axis: int = 1) -> Vector3i:
	match axis:
		0: return Vector3i(size.x, size.z, size.y)
		2: return Vector3i(size.y, size.x, size.z)
		_: return Vector3i(size.z, size.y, size.x)

func _tiled_bin(rng: RandomNumberGenerator, bin_index: int) -> Array:
	# Each layer is a complete 2 x 4 floor, so the initial tiling is supported.
	# Repeat one cut on adjacent layers to offer a valid vertical merge. Merging
	# reduces six cases per bin to four, five, or six while keeping volume <= 8.
	var common_cut := rng.randi_range(0, 3)
	var cuts: Array[int] = [common_cut, common_cut, rng.randi_range(0, 3)]
	if rng.randf() < 0.5:
		cuts.reverse()
	var pieces: Array = []
	for y in GRID.y:
		var cut: int = cuts[y]
		if cut == 0:
			pieces.append(_piece(bin_index, Vector3i(0, y, 0), Vector3i(1, 1, 4)))
			pieces.append(_piece(bin_index, Vector3i(1, y, 0), Vector3i(1, 1, 4)))
		else:
			pieces.append(_piece(bin_index, Vector3i(0, y, 0), Vector3i(2, 1, cut)))
			pieces.append(_piece(bin_index, Vector3i(0, y, cut), Vector3i(2, 1, GRID.z - cut)))
	var attempts := rng.randi_range(0, 2)
	for _attempt in attempts:
		var candidates: Array = []
		for first in pieces.size():
			for second in range(first + 1, pieces.size()):
				var a: Dictionary = pieces[first]
				var b: Dictionary = pieces[second]
				var ac: Vector3i = a.solution_cell
				var bc: Vector3i = b.solution_cell
				var az: Vector3i = a.solution_size
				var bz: Vector3i = b.solution_size
				if ac.x != bc.x or ac.z != bc.z or az.x != bz.x or az.z != bz.z:
					continue
				if ac.y + az.y != bc.y and bc.y + bz.y != ac.y:
					continue
				if _volume(az) + _volume(bz) <= MAX_PARCEL_VOLUME:
					candidates.append(Vector2i(first, second))
		if candidates.is_empty():
			break
		var selected: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var a: Dictionary = pieces[selected.x]
		var b: Dictionary = pieces[selected.y]
		a.solution_cell.y = mini(a.solution_cell.y, b.solution_cell.y)
		a.solution_size.y += b.solution_size.y
		pieces.remove_at(selected.y)
	return pieces

func _piece(bin_index: int, cell: Vector3i, size: Vector3i) -> Dictionary:
	return {"solution_bin": bin_index, "solution_cell": cell, "solution_size": size}

func _find_solution_order(solved: Array) -> Array[int]:
	var pending := solved.duplicate()
	var result: Array[int] = []
	reset()
	pending.sort_custom(_solution_before)
	while not pending.is_empty():
		var found := false
		for index in pending.size():
			var parcel: Dictionary = pending[index]
			if _blocks_pending_access(parcel, pending):
				continue
			if place(parcel.id, parcel.solution_bin, parcel.solution_cell, parcel.solution_size).is_empty():
				result.append(parcel.id)
				pending.remove_at(index)
				found = true
				break
		if not found:
			break
	reset()
	return result

func _blocks_pending_access(parcel: Dictionary, pending: Array) -> bool:
	for other in pending:
		if parcel.id == other.id or parcel.solution_bin != other.solution_bin or other.solution_cell.x == 0:
			continue
		var access_cell := Vector3i(0, other.solution_cell.y, other.solution_cell.z)
		var access_size := Vector3i(other.solution_cell.x, other.solution_size.y, other.solution_size.z)
		if _overlaps(parcel.solution_cell, parcel.solution_size, access_cell, access_size):
			return true
	return false

func _solution_before(a: Dictionary, b: Dictionary) -> bool:
	if a.solution_bin != b.solution_bin:
		return a.solution_bin < b.solution_bin
	if a.solution_cell.y != b.solution_cell.y:
		return a.solution_cell.y < b.solution_cell.y
	if a.solution_cell.x != b.solution_cell.x:
		return a.solution_cell.x > b.solution_cell.x
	return a.solution_cell.z < b.solution_cell.z

func _access_clear(bin_index: int, cell: Vector3i, size: Vector3i, ignored_id: int = -1) -> bool:
	for side in open_sides:
		var corridor_cell := cell
		var corridor_size := size
		match side:
			Vector3i.LEFT:
				corridor_cell.x = 0
				corridor_size.x = cell.x
			Vector3i.RIGHT:
				corridor_cell.x = cell.x + size.x
				corridor_size.x = grid.x - corridor_cell.x
			Vector3i.FORWARD:
				corridor_cell.z = 0
				corridor_size.z = cell.z
			Vector3i.BACK:
				corridor_cell.z = cell.z + size.z
				corridor_size.z = grid.z - corridor_cell.z
		if corridor_size.x == 0 or corridor_size.z == 0:
			return true
		var clear := true
		for id in placements:
			if id == ignored_id:
				continue
			var other: Dictionary = placements[id]
			if other.bin == bin_index and _overlaps(corridor_cell, corridor_size, other.cell, other.size):
				clear = false
				break
		if clear:
			return true
	return false

func _occupied(bin_index: int, cell: Vector3i) -> bool:
	for placement in placements.values():
		if placement.bin != bin_index:
			continue
		var start: Vector3i = placement.cell
		var end: Vector3i = start + placement.size
		if cell.x >= start.x and cell.x < end.x and cell.y >= start.y and cell.y < end.y and cell.z >= start.z and cell.z < end.z:
			return true
	return false

static func _overlaps(a: Vector3i, a_size: Vector3i, b: Vector3i, b_size: Vector3i) -> bool:
	return a.x < b.x + b_size.x and a.x + a_size.x > b.x and a.y < b.y + b_size.y and a.y + a_size.y > b.y and a.z < b.z + b_size.z and a.z + a_size.z > b.z

static func _footprints_overlap(a: Vector3i, a_size: Vector3i, b: Vector3i, b_size: Vector3i) -> bool:
	return a.x < b.x + b_size.x and a.x + a_size.x > b.x and a.z < b.z + b_size.z and a.z + a_size.z > b.z

static func _volume(size: Vector3i) -> int:
	return size.x * size.y * size.z

static func _same_shape(a: Vector3i, b: Vector3i) -> bool:
	var a_axes: Array[int] = [a.x, a.y, a.z]
	var b_axes: Array[int] = [b.x, b.y, b.z]
	a_axes.sort()
	b_axes.sort()
	return a_axes == b_axes

func _random_orientation(size: Vector3i, rng: RandomNumberGenerator) -> Vector3i:
	# Keep a long 4-cell case lengthways for hand-carry clearance through doors.
	# Players can still rotate it, and the placement rule checks the destination.
	if size.z == GRID.z:
		return Vector3i(size.y, size.x, size.z) if rng.randf() < 0.5 else size
	var axes: Array = [size.x, size.y, size.z]
	_shuffle(axes, rng)
	return Vector3i(axes[0], axes[1], axes[2])

func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[other]
		values[other] = value
