extends SceneTree
## Standalone, save-free headless tests for the cargo rack's physical rules.
const Packing = preload("res://scripts/cargo_trial_packing.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	_test_generated_manifests()
	_test_placement_rules()
	_test_access_and_removal()
	_test_rotations_and_state()
	_test_floor_grids()
	print("CARGO PACKING: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(message)

func _test_generated_manifests() -> void:
	var valid_all := true
	var orders_all := true
	var reverse_all := true
	var parcel_counts := {}
	var shapes := {}
	for seed_value in 300:
		for full in [true, false]:
			var model = Packing.new()
			var parcels: Array = model.generate(seed_value, full)
			var volume := 0
			parcel_counts[parcels.size()] = true
			for parcel in parcels:
				var dimensions: Vector3i = parcel.solution_size
				var piece_volume: int = dimensions.x * dimensions.y * dimensions.z
				volume += piece_volume
				valid_all = valid_all and piece_volume > 0 and piece_volume <= 8
				valid_all = valid_all and dimensions.x <= 3 and dimensions.y <= 3 and dimensions.z <= 4
				shapes[str(dimensions)] = true
			valid_all = valid_all and volume == (48 if full else 24)
			valid_all = valid_all and parcels.size() >= (8 if full else 4) and parcels.size() <= (12 if full else 6)
			var sequence: Array[int] = model.get_solution_order()
			orders_all = orders_all and sequence.size() == parcels.size() and model.placements.is_empty()
			for id in sequence:
				var parcel: Dictionary = model.manifest[id]
				var reason: String = model.place(id, parcel.solution_bin, parcel.solution_cell, parcel.solution_size)
				if not reason.is_empty():
					orders_all = false
					push_error("Seed %d, parcel %d: %s" % [seed_value, id, reason])
			orders_all = orders_all and model.occupied_volume() == volume
			sequence.reverse()
			for id in sequence:
				reverse_all = model.remove(id) and reverse_all
			reverse_all = reverse_all and model.placements.is_empty()
	check(valid_all, "Every generated parcel fits the declared limits; full and small jobs use exactly 48 and 24 cells")
	check(orders_all, "600 manifests can be loaded in their documented physically accessible, supported order")
	check(reverse_all, "Every generated solution can be unloaded in reverse order without trapping any parcel")
	check(parcel_counts.size() >= 5 and shapes.size() >= 8, "Seeds create varied parcel counts and meaningful shape variety")
	var first = Packing.new()
	var repeat = Packing.new()
	check(first.generate(137) == repeat.generate(137), "Identical seeds reproduce a contract's manifest")
	check(first.generate(137) != repeat.generate(138), "Different seeds vary manifests")

func _fixture(sizes: Array[Vector3i]):
	var model = Packing.new()
	for index in sizes.size():
		model.manifest[index + 1] = {"id": index + 1, "size": sizes[index]}
	return model

func _test_placement_rules() -> void:
	var model = _fixture([Vector3i(1, 1, 1), Vector3i(2, 1, 1), Vector3i(1, 1, 1), Vector3i(1, 1, 1)])
	check(model.can_place(1, 0, Vector3i(0, 1, 0), Vector3i.ONE).contains("Unsupported"), "A case cannot float above an empty floor")
	check(model.place(1, 0, Vector3i.ZERO, Vector3i.ONE).is_empty(), "A floor cell supports a case")
	check(model.can_place(2, 0, Vector3i(0, 1, 0), Vector3i(2, 1, 1)).contains("Unsupported"), "A wide case cannot balance with half its bottom unsupported")
	check(model.place(3, 0, Vector3i(1, 0, 1), Vector3i.ONE).is_empty(), "Another longitudinal lane remains accessible")
	check(model.can_place(4, 0, Vector3i.ZERO, Vector3i.ONE).contains("Blocked"), "Cases cannot overlap")
	check(model.place(4, 1, Vector3i.ZERO, Vector3i.ONE).is_empty(), "The other rack has independent cells")
	check(not model.can_place(2, -1, Vector3i.ZERO, Vector3i(2, 1, 1)).is_empty(), "Negative rack index is rejected")
	check(not model.can_place(2, 2, Vector3i.ZERO, Vector3i(2, 1, 1)).is_empty(), "Staging is not treated as a flight-safe rack")
	check(model.can_place(2, 0, Vector3i(-1, 0, 0), Vector3i(2, 1, 1)).contains("Outside"), "Negative cells are rejected")
	check(model.can_place(2, 0, Vector3i(1, 0, 2), Vector3i(2, 1, 1)).contains("Outside"), "Cases extending through the back wall are rejected")
	check(model.can_place(2, 0, Vector3i(0, 3, 0), Vector3i(2, 1, 1)).contains("Outside"), "Cases extending above the rack are rejected")
	check(model.can_place(2, 0, Vector3i(0, 0, 4), Vector3i(2, 1, 1)).contains("Outside"), "Cases extending beyond the end of the rack are rejected")

func _test_access_and_removal() -> void:
	var model = _fixture([Vector3i.ONE, Vector3i.ONE, Vector3i.ONE, Vector3i.ONE])
	model.place(1, 0, Vector3i.ZERO, Vector3i.ONE)
	check(model.can_place(2, 0, Vector3i(1, 0, 0), Vector3i.ONE).contains("Access blocked"), "A rear case cannot teleport through a front case")
	model.remove(1)
	check(model.place(2, 0, Vector3i(1, 0, 0), Vector3i.ONE).is_empty(), "Rear case can be inserted before front case")
	model.place(1, 0, Vector3i.ZERO, Vector3i.ONE)
	check(model.can_remove(2).contains("Access blocked") and not model.remove(2), "A rear case cannot be pulled through the front case")
	model.place(3, 0, Vector3i(0, 1, 0), Vector3i.ONE)
	check(model.can_remove(1).contains("Supporting") and not model.remove(1), "Cannot remove the bottom of a stack")
	check(model.remove(3) and model.remove(1) and model.remove(2), "Top, front, then rear cases unload successfully")
	var bridge = _fixture([Vector3i.ONE, Vector3i.ONE, Vector3i(2, 1, 1)])
	bridge.place(2, 0, Vector3i(1, 0, 0), Vector3i.ONE)
	bridge.place(1, 0, Vector3i.ZERO, Vector3i.ONE)
	check(bridge.place(3, 0, Vector3i(0, 1, 0), Vector3i(2, 1, 1)).is_empty(), "Two lower parcels can jointly support a wide upper parcel")
	check(not bridge.remove(1) and not bridge.remove(2), "Neither half of a jointly supported stack can be removed")

func _test_rotations_and_state() -> void:
	var model = _fixture([Vector3i(1, 2, 3), Vector3i(1, 1, 4)])
	var shape := Vector3i(1, 2, 3)
	for axis in 3:
		var rotated: Vector3i = Packing.rotated_size(shape, axis)
		check(Packing.rotated_size(rotated, axis) == shape, "Two dimension swaps return the same box extents on axis %d" % axis)
		check(rotated.x * rotated.y * rotated.z == 6, "Rotation preserves volume on axis %d" % axis)
	check(model.can_place(1, 0, Vector3i.ZERO, Vector3i(1, 2, 2)).contains("dimensions"), "A smaller same-looking replacement shape is rejected")
	check(model.can_place(1, 0, Vector3i.ZERO, Vector3i(3, 1, 2)).contains("Outside"), "A valid rotation that exceeds rack width is rejected")
	check(model.place(1, 0, Vector3i.ZERO, Vector3i(2, 1, 3)).is_empty(), "A fitting ninety-degree orientation can be placed")
	check(not model.place(1, 1, Vector3i.ZERO, Vector3i(2, 1, 3)).is_empty() and model.placements.size() == 1, "The same parcel cannot occupy two racks")
	check(not model.place(99, 1, Vector3i.ZERO, Vector3i.ONE).is_empty(), "Unmanifested cargo cannot be created by placement")
	model.reset()
	check(model.placements.is_empty() and model.manifest.size() == 2, "Reset clears rack positions while retaining parcel identity")
	check(model.place(2, 0, Vector3i.ZERO, Vector3i(1, 1, 4)).is_empty(), "Longest supported hand-carried case fits the full rack length")
	check(not model.remove(88), "Removing an absent parcel is a harmless failure")

func _test_floor_grids() -> void:
	var model = _fixture([Vector3i(2,1,2),Vector3i(2,1,2),Vector3i(2,1,2),Vector3i(2,1,2)])
	model.grid=Vector3i(4,3,4)
	model.bin_count=28
	model.area_name="floor grid"
	model.open_sides.assign([Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK])
	check(model.place(1,27,Vector3i.ZERO,Vector3i(2,1,2)).is_empty(),"Floor grids have their own dimensions and support all dock and staging indices")
	check(model.place(2,27,Vector3i(0,1,0),Vector3i(2,1,2)).is_empty(),"Floor boxes stack with exactly the same full-support rule as rack boxes")
	check(not model.can_remove(1).is_empty(),"Floor stacks protect their supporting bottom cases")
	check(model.place(3,27,Vector3i(2,0,0),Vector3i(2,1,2)).is_empty(),"Open floor grids allow side access that a walled rack cannot")
	check(model.can_place(4,27,Vector3i(2,1,1),Vector3i(2,1,2)).contains("Unsupported"),"A partly supported floor stack is rejected")
	check(model.can_place(4,27,Vector3i(0,3,0),Vector3i(2,1,2)).contains("Outside"),"Floor grid height is limited to three layers")
	check(model.can_place(4,27,Vector3i.ZERO,Vector3i(2,1,2)).contains("Blocked"),"Floor cases cannot overlap even when a pad accepts multiple boxes")
	check(model.remove(2) and model.remove(1) and model.remove(3),"Floor cases unload safely top first without leaving occupancy")
