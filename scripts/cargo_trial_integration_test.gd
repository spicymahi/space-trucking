extends RefCounted
## Exercises the actual trial controller and its CharacterBody without saves.
const Packing = preload("res://scripts/cargo_trial_packing.gd")
var host: Node3D
var passed := 0
var failed := 0

func check(value: bool, description: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("CARGO INTEGRATION: " + description)
	print("CARGO INTEGRATION ", description, ": ", value)

func run(trial: Node3D) -> bool:
	host = trial
	var save_path := "user://longhaul_flight_v1.json"
	var save_before := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else "ABSENT"
	await _frames(3)
	host.panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check(not host.depart() and not host.toggle_lock() and not host.complete_delivery(), "An empty new trial cannot depart, secure nonexistent cargo, or pay a delivery")
	check(not host.accept_job(-1) and not host.accept_job(999), "Invalid contract choices leave the dock untouched")
	await _test_aim_usability()
	await _test_full_outbound()
	await _test_collection_return()
	_release_walk()
	var save_after := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else "ABSENT"
	check(save_before == save_after, "The live flight save remains byte-for-byte unchanged throughout both test contracts")
	print("CARGO INTEGRATION TOTAL: %d passed, %d failed" % [passed, failed])
	return failed == 0

func _test_aim_usability() -> void:
	await _reset()
	# This is the real initial spawn and computer, not a fabricated interaction.
	await _aim_from(Vector3(-3,-1.13,20.7), host.dock.terminal.global_position + Vector3(0,1.47,0.2))
	host._update_aim()
	var terminal_hit: bool = not host.current_hit.is_empty() and host.current_hit.collider.get_meta("action", "") == "contract"
	check(terminal_hit and host.prompt.text.contains("CONTRACTS"), "The dock computer is reachable by the real aim ray from the starting position")
	host._use()
	check(host.panel.visible and host.terminal_mode == "contract" and host.readout.text.contains("CONTRACT BOARD"), "F opens the actual contract terminal through its interaction body")
	var full_index := _find_job("outbound", true)
	host._command("accept %d" % (full_index + 1))
	check(not host.economy.active.is_empty() and not host.parcels.is_empty(), "The terminal's typed accept command produces the physical manifest")
	host.panel.hide()
	await _frames(2)
	var id: int = host.packing.get_solution_order()[0]
	var parcel: Dictionary = host.parcels[id]
	var source_slot: int = parcel.slot
	var pickup: Vector3 = host.dock.pickup_positions[source_slot]
	await _aim_from(pickup + Vector3(0,0.08,2.05), host.cases[id].global_position)
	host._update_aim()
	var case_hit: bool = not host.current_hit.is_empty() and host.current_hit.collider.get_meta("parcel", -1) == id
	check(case_hit and host.prompt.text.contains("LIFT"), "A collection parcel can be targeted by the actual camera ray")
	host._use()
	check(host.held == id and host.cases[id].get_parent() == host.walker, "F lifts the aimed parcel and attaches it to the player's hand tool")
	if host.held != id:
		return
	var solved: Dictionary = host.packing.manifest[id]
	_orient_held(solved.solution_size)
	var rack: Node3D = host.racks[solved.solution_bin]
	var cell: Vector3i = solved.solution_cell
	var rack_target := rack.to_global(Vector3(-0.015, (cell.y + 0.25) * Packing.CELL, (cell.z + 0.25) * Packing.CELL))
	var aisle := rack.to_global(Vector3(-1.5, 0, (cell.z + 0.25) * Packing.CELL))
	host.depth_mode = 1 if cell.x > 0 else 2
	if host.held_size.y < Packing.GRID.y:
		var floating_target := rack.to_global(Vector3(-0.015, 1.25 * Packing.CELL, (cell.z + 0.25) * Packing.CELL))
		await _aim_from(aisle, floating_target)
		host._update_aim()
		var unsupported: bool = not host.candidate.is_empty() and host.candidate.reason.contains("Unsupported")
		host._use()
		check(unsupported and host.ghost.visible and host.held == id and host.packing.placements.is_empty(), "An unsupported rack ghost explains the failure and F cannot place a floating parcel")
	await _aim_from(aisle, rack_target)
	host._update_aim()
	var rack_aim: bool = not host.candidate.is_empty() and host.candidate.kind == "rack" and host.candidate.bin == solved.solution_bin and host.candidate.cell == cell
	var valid_ghost: bool = rack_aim and host.candidate.reason.is_empty() and host.ghost.visible and not host._placement_blocked(host.candidate)
	if not valid_ghost:
		print("RACK AIM DEBUG ", host.candidate, " / eye=", host.camera.global_position, " desired=", cell)
	check(valid_ghost, "Aiming through the open rack face produces the correct valid bottom-cell ghost without frame occlusion")
	host._use()
	check(host.held == -1 and host.packing.placements.has(id) and host.parcels[id].location == "rack", "F places the valid rack ghost through the same path as player input")
	if host.held == -1:
		var center: Vector3 = host.cases[id].global_position
		await _aim_from(aisle, center)
		host._update_aim()
		check(not host.current_hit.is_empty() and host.current_hit.collider.get_meta("parcel", -1) == id, "A placed case can be aimed at for retrieval through the rack opening")
		host._use()
	check(host.held == id and not host.packing.placements.has(id), "F retrieves an accessible racked case without leaving occupied cells")
	if host.held != id:
		return
	var staging_ok := true
	for index in host.stage_positions.size():
		var at: Vector3 = host.stage_positions[index]
		await _aim_from(Vector3(0,0.08,at.z + (1.3 if at.z < 2 else -1.3)), at + Vector3(0,0.012,0))
		host._update_aim()
		var stage_aim: bool = not host.candidate.is_empty() and host.candidate.kind == "stage" and host.candidate.index == index
		var valid: bool = stage_aim and host.candidate.reason.is_empty() and host.ghost.visible and not host._placement_blocked(host.candidate)
		if not valid:
			print("STAGE AIM DEBUG ",index," ",host.candidate," eye=",host.camera.global_position)
		staging_ok = valid and staging_ok
		if valid:
			host._use()
			staging_ok = staging_ok and host.staging[index] == id and host.held == -1
			host.pick_case(id)
	check(staging_ok, "All four staging floor targets produce valid ghosts and accept F placement")
	var pad: Vector3 = host.stage_positions[0]
	await _aim_from(pad + Vector3(0.15,0.03,0.15),pad)
	host._update_aim()
	var overlaps_player: bool = not host.candidate.is_empty() and host.candidate.kind == "stage" and host.candidate.reason.contains("your body")
	host._use()
	check(overlaps_player and host.held == id and host.stage_count() == 0, "Aiming at a pad occupied by the player shows a blocked ghost and F preserves the held case")
	var overlap := {"kind":"stage", "transform":Transform3D(Basis.IDENTITY,host.walker.global_position + Vector3(0,0.6,0))}
	check(host._placement_blocked(overlap), "Placement refuses a parcel volume overlapping the player's own body")
	await _aim_from(Vector3(0,0.08,3.5),Vector3(4,0.7,3.5))
	var behind_wall := {"kind":"stage", "transform":Transform3D(Basis.IDENTITY,Vector3(4,0.7,3.5))}
	check(host._placement_blocked(behind_wall), "A physical ship wall occludes placement through it")
	var delivery: Vector3 = host.dock.drop_positions[0]
	await _aim_from(delivery + Vector3(0,0.08,2.05), delivery + Vector3(0,0.04,0))
	host._update_aim()
	check(host.candidate.is_empty() or host.candidate.kind != "drop", "Delivery spots do not accept cargo before the contract reaches its destination")
	# Restore this trial before the complete contract tests below.
	host.place_held(_apron_target("pickup", source_slot))
	host.depth_mode = 0

func _aim_from(position: Vector3, target: Vector3) -> void:
	_release_walk()
	host.panel.hide()
	host.walker.position = position
	host.walker.velocity = Vector3.ZERO
	var horizontal: Vector3 = target - position
	host.walker.rotation = Vector3(0,atan2(-horizontal.x,-horizontal.z),0)
	host.camera.look_at(target,Vector3.UP)
	await _frames(3)
	host.camera.look_at(target,Vector3.UP)

func _orient_held(size: Vector3i) -> void:
	host.held_size = size
	host.parcels[host.held].size = size
	host._replace_case_visual(host.held,size)
	host._update_carry()

func _test_full_outbound() -> void:
	await _reset()
	var full_index := _find_job("outbound", true)
	check(full_index >= 0, "Initial station offers a full outbound consignment")
	if full_index < 0:
		return
	var before: int = host.economy.credits
	check(host.accept_job(full_index), "Dock computer accepts a full contract")
	var contract: Dictionary = host.economy.active.duplicate(true)
	var count: int = host.parcels.size()
	check(count >= 8 and count <= 12 and host.cases.size() == count and int(host.economy.active.box_count) == count, "Acceptance spawns every assigned physical case and records the manifest count")
	check(host.economy.credits == before + contract.advance, "Fuel advance is credited on acceptance")
	check(not host.accept_job(full_index) and host.parcels.size() == count, "A second contract cannot replace active cases")
	check(not host.depart() and not host.toggle_lock(), "Unloaded consignment blocks departure and cargo locking")
	check(host.dock.pickup_positions.size() >= count and host.dock.drop_positions.size() >= count, "Both collection and delivery aprons have a dedicated position for every case")
	var pickup_geometry_ok := true
	for id in host.parcels:
		var data: Dictionary = host.parcels[id]
		var expected: Vector3 = host.dock.pickup_positions[data.slot] + Vector3(0, data.size.y * Packing.CELL * 0.5 + 0.04, 0)
		pickup_geometry_ok = pickup_geometry_ok and host.cases[id].get_parent() == host and host.cases[id].global_position.is_equal_approx(expected)
		pickup_geometry_ok = pickup_geometry_ok and host._case_body(id).collision_layer == 1
	check(pickup_geometry_ok, "Spawned pickup cases have correct world positions and solid collision bodies")
	await _test_walk_route()
	# Each of the four pads gets a real parcel, independently blocking departure.
	var ids: Array = host.parcels.keys()
	var stage_ok := true
	for index in 4:
		var id: int = ids[index]
		stage_ok = host.pick_case(id) and stage_ok
		stage_ok = stage_ok and host.cases[id].get_parent() == host.walker and host.carry_shape.disabled == false
		stage_ok = stage_ok and host._case_body(id).collision_layer == 0 and host.parcels[id].location == "hand"
		stage_ok = host.place_held(_stage_target(index)) and stage_ok
		stage_ok = stage_ok and host.staging[index] == id and host.held == -1 and host.cases[id].get_parent() == host
		stage_ok = stage_ok and host.load_readiness().contains("staging") and not host.depart() and not host.toggle_lock()
	check(stage_ok and host.stage_count() == 4, "All four staging pads accept cases, restore collision, and individually block departure")
	var spare: int = ids[4]
	check(host.pick_case(spare), "Another case can be held while all staging positions are occupied")
	check(not host.place_held(_stage_target(0)) and host.held == spare and host.stage_count() == 4, "An occupied staging position rejects a second parcel without losing either case")
	var spare_slot := _free_slot("pickup")
	check(host.place_held(_apron_target("pickup", spare_slot)), "A held case can be returned to a free collection position")
	var arranged := _load_solution()
	check(arranged and host.packing.occupied_volume() == 48, "The whole consignment can be placed using the optional plan through real controller actions")
	check(host.stage_count() == 0 and host.held == -1 and host.load_readiness().is_empty(), "Loading the racks clears all four temporary positions and the hand tool")
	check(not host.depart() and not host.locked and host.economy.active.phase == "loading", "A complete but unsecured load still cannot depart")
	var blocked_bottom := -1
	for id in host.packing.placements:
		if host.packing.can_remove(id).contains("Supporting"):
			blocked_bottom = id
			break
	check(blocked_bottom >= 0 and not host.pick_case(blocked_bottom) and host.held == -1, "The actual pickup action cannot pull out a lower supporting case")
	check(host.toggle_lock() and host.locked and host.economy.active.phase == "delivery", "Cargo-lock button secures the complete rack load and advances the contract")
	var top_id: int = host.packing.get_solution_order().back()
	check(not host.pick_case(top_id) and host.held == -1 and host.packing.placements.size() == count, "Locked cargo cannot be lifted even when a case is otherwise accessible")
	var money_before_arrival: int = host.economy.credits
	check(host.depart() and host.economy.station == contract.destination and host.economy.active.phase == "unloading", "Departure transfers the secured consignment to its contracted destination")
	check(host.economy.credits == money_before_arrival - int(contract.legs[0].fuel_cost), "Transfer charges exactly the quoted leg fuel")
	check(host.parcels.size() == count and host.cases.size() == count and host.packing.placements.size() == count, "Arrival preserves every physical racked case without duplicates")
	check(not host.complete_delivery() and host.economy.credits == money_before_arrival - int(contract.legs[0].fuel_cost), "Arrival alone cannot claim payment before unloading")
	check(not host.depart(), "An arrived consignment cannot charge fuel for a repeated departure")
	check(host.toggle_lock() and not host.locked, "The same cargo-lock button releases the load for unloading")
	await _unload_and_complete(before, contract)

func _test_collection_return() -> void:
	await _reset()
	var collection_index := _find_job("collection", false)
	check(collection_index >= 0, "Initial station offers a supply-collection contract")
	if collection_index < 0:
		return
	var before: int = host.economy.credits
	check(host.accept_job(collection_index), "Employer's collection contract can be accepted")
	var contract: Dictionary = host.economy.active.duplicate(true)
	check(host.parcels.is_empty() and host.cases.is_empty() and host.economy.active.phase == "to_pickup", "A collection job starts empty; its goods do not appear at the employer")
	check(not host.toggle_lock() and not host.complete_delivery(), "The empty outward leg neither fabricates a load nor completes a delivery")
	check(host.depart() and host.economy.station == contract.source and host.economy.active.phase == "loading", "Collection job allows the empty trip to the reserved supplier")
	check(host.parcels.size() >= 4 and host.parcels.size() <= 6 and host.cases.size() == host.parcels.size(), "Reserved collection cases appear only on arrival at the supplier")
	check(host.economy.credits == before + contract.advance - int(contract.legs[0].fuel_cost), "Collection fuel advance covers the first leg without spending the starting balance")
	var count: int = host.parcels.size()
	check(not host.depart() and host.parcels.size() == count, "Supplier departure is blocked until the newly spawned consignment is loaded")
	check(_load_solution() and host.packing.occupied_volume() == 24 and host.toggle_lock(), "The smaller collection load can be packed and secured with the same tools")
	check(host.depart() and host.economy.station == contract.employer and host.economy.active.phase == "unloading", "Loaded collection leg returns to the original employer")
	check(host.economy.active.fuel_spent == contract.fuel_cost and host.economy.active.legs_completed == 2, "Both collection legs consume exactly the total quoted fuel")
	check(host.economy.credits == before, "Advance pays both legs, preserving the player's starting credits before the delivery fee")
	host.toggle_lock()
	await _unload_and_complete(before, contract)

func _unload_and_complete(starting_credits: int, contract: Dictionary) -> void:
	var sequence: Array[int] = host.packing.get_solution_order()
	sequence.reverse()
	var unload_ok := true
	var refused_partial := false
	var count: int = sequence.size()
	var old_nodes: Array = []
	for node in host.cases.values():
		old_nodes.append(weakref(node))
	for index in sequence.size():
		var id: int = sequence[index]
		unload_ok = host.pick_case(id) and unload_ok
		var target := _apron_target("drop", index)
		if index == 0:
			var at: Vector3 = host.dock.drop_positions[index]
			await _aim_from(at + Vector3(0,0.08,2.05),at + Vector3(0,0.04,0))
			host._update_aim()
			var delivery_aim: bool = not host.candidate.is_empty() and host.candidate.kind == "drop" and host.candidate.index == index and host.candidate.reason.is_empty()
			if not delivery_aim:
				print("DELIVERY AIM DEBUG ",host.candidate)
			check(delivery_aim and host.ghost.visible, "The destination's delivery floor produces a valid unloading ghost")
			host._use()
			unload_ok = host.held == -1 and unload_ok
		else:
			unload_ok = host.place_held(target) and unload_ok
		unload_ok = unload_ok and host.parcels[id].location == "drop" and host.delivered_count() == index + 1
		unload_ok = unload_ok and host.cases[id].global_transform.is_equal_approx(target.transform)
		if index == 0 and count > 1:
			var wallet: int = host.economy.credits
			refused_partial = not host.complete_delivery() and host.economy.credits == wallet
	check(unload_ok and host.packing.placements.is_empty() and host.delivered_count() == count, "Every case can be manually unloaded into independent destination positions")
	check(refused_partial, "Completion refuses a partially unloaded consignment without changing payment")
	check(host.complete_delivery(), "Delivery button accepts the complete unloaded consignment")
	check(host.economy.credits == starting_credits + contract.payout - contract.fuel_cost, "Final credits equal the agreed payout minus the fuel already covered by the advance")
	var wallet: int = host.economy.credits
	check(not host.complete_delivery() and host.economy.credits == wallet, "Repeated completion cannot pay the same contract twice")
	await _frames(3)
	var removed_all := true
	for weak in old_nodes:
		removed_all = removed_all and weak.get_ref() == null
	check(host.parcels.is_empty() and host.cases.is_empty() and host.packing.placements.is_empty() and host.stage_count() == 0 and host.held == -1 and host.carry_shape.disabled and removed_all, "Receipt removes the delivered physical cargo and leaves no hidden cases, carried collider, or staging occupancy")
	check(host.economy.receipts.size() == 1 and host.economy.active.paid and host.economy.active.phase == "complete", "The economy records exactly one completed receipt")

func _load_solution() -> bool:
	var result := true
	for id in host.packing.get_solution_order():
		var data: Dictionary = host.packing.manifest[id]
		if not host.pick_case(id):
			result = false
			continue
		# The pure model tests rotations. Here orient in open air to isolate the
		# physical parenting, placement, and contract flow from input aiming.
		host.held_size = data.solution_size
		host.parcels[id].size = data.solution_size
		host._replace_case_visual(id, data.solution_size)
		host._update_carry()
		var target := _rack_target(data.solution_bin, data.solution_cell, data.solution_size)
		result = host.place_held(target) and result
		result = result and host.cases[id].get_parent() == host and host.cases[id].global_transform.is_equal_approx(target.transform)
		result = result and host._case_body(id).collision_layer == 1 and host.parcels[id].location == "rack"
	return result

func _rack_target(bin_index: int, cell: Vector3i, size: Vector3i) -> Dictionary:
	return {"kind":"rack", "bin":bin_index, "cell":cell, "reason":"", "transform":host.racks[bin_index].global_transform * Transform3D(Basis.IDENTITY, (Vector3(cell) + Vector3(size) * 0.5) * Packing.CELL)}

func _stage_target(index: int) -> Dictionary:
	return {"kind":"stage", "index":index, "reason":"", "transform":Transform3D(Basis.IDENTITY, host.stage_positions[index] + Vector3(0, host.held_size.y * Packing.CELL * 0.5, 0))}

func _apron_target(kind: String, index: int) -> Dictionary:
	var positions: Array = host.dock.drop_positions if kind == "drop" else host.dock.pickup_positions
	return {"kind":kind, "index":index, "reason":"", "transform":Transform3D(Basis.IDENTITY, positions[index] + Vector3(0, host.held_size.y * Packing.CELL * 0.5 + 0.04, 0))}

func _free_slot(kind: String) -> int:
	for index in host.dock.pickup_positions.size():
		var available := true
		for parcel in host.parcels.values():
			if parcel.location == kind and parcel.slot == index:
				available = false
		if available:
			return index
	return -1

func _find_job(kind: String, full: bool) -> int:
	for index in host.jobs.size():
		if host.jobs[index].kind == kind and host.jobs[index].full == full:
			return index
	return -1

func _reset() -> void:
	_release_walk()
	host._clear_cases()
	host.locked = false
	host.economy.setup()
	host.economy_timer = 0
	host.jobs = host.economy.offers(0)
	host.panel.hide()
	host.walker.position = Vector3(0,-1.13,18)
	host.walker.velocity = Vector3.ZERO
	host.walker.rotation = Vector3.ZERO
	host.camera.rotation = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(3)

func _test_walk_route() -> void:
	host.walker.position = Vector3(0,-1.13,18)
	host.walker.velocity = Vector3.ZERO
	await _frames(3)
	check(await _walk_to(Vector3(0,0.08,5.7)), "Actual WASD CharacterBody walks from dock, up the ramp, through engineering into the cargo bay")
	check(await _walk_to(Vector3(0,-1.13,18)), "Actual walking route returns from the cargo bay to the dock")
	# Carry the longest case in its initial lengthwise orientation along the
	# same collision route; all cases use the player's hand tool.
	var long_id := -1
	var longest := 0
	for id in host.parcels:
		var size: Vector3i = host.parcels[id].size
		if size.z > longest:
			longest = size.z
			long_id = id
	if long_id >= 0:
		var pickup_slot: int = host.parcels[long_id].slot
		check(host.pick_case(long_id) and host.cases[long_id].get_parent() == host.walker, "The hand tool carries the longest assigned case with the player")
		check(await _walk_to(Vector3(0,0.08,5.7)), "A carried long case fits the real ramp, cargo hatch, engineering passage and cargo approach")
		# A collision-aware turn cannot happen within the narrow passage; clear
		# its length before facing out for the return walk.
		host.place_held(_apron_target("pickup", pickup_slot))
		await _walk_to(Vector3(0,-1.13,18))

func _walk_to(target: Vector3) -> bool:
	host.panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var offset: Vector3 = target - host.walker.position
	host.walker.rotation.y = atan2(-offset.x, -offset.z)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	host.test_walk_input = Vector3(0, 0, -1)
	var reached := false
	var last: Vector3 = host.walker.position
	var stalled := 0
	for _frame in 800:
		await host.get_tree().physics_frame
		var position: Vector3 = host.walker.position
		var horizontal := Vector2(position.x-target.x,position.z-target.z).length()
		if horizontal < 0.14:
			reached = absf(position.y-target.y) < 0.30
			break
		if position.distance_to(last) < 0.001:
			stalled += 1
		else:
			stalled = 0
		if stalled >= 90:
			break
		last = position
	_release_walk()
	if not reached:
		print("WALK STOP position=", host.walker.position, " target=", target, " key_seen=", Input.is_physical_key_pressed(KEY_W))
	await _frames(2)
	return reached

func _release_walk() -> void:
	if host:
		host.test_walk_input = Vector3.ZERO
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = false
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _index in count:
		await host.get_tree().process_frame
