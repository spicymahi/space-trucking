extends RefCounted
## Small, explicit state model for the two-station playable slice.
## All money/cargo mutations are checked here, so UI and persistence agree.

const STATIONS := ["Ceres Yard", "Tharsis Ring"]
const GRIDS := [Vector3i(0, 0, 0), Vector3i(24, 3, -68)]
const SAVE_PATH := "user://life_slice_v1.json"
const GOODS := ["ICE", "FOOD"]
const BUY := [80, 100]
const SELL := [155, 175]
var credits := 600
var fuel := 72.0
var food := 62.0
var water := 55.0
var hygiene := 48.0
var rations := 3
var drinks := 4
var pump := 58.0
var drive := 89.0
var patched := false
var fault_seen := false
var dock := 0
var destination := 1
var route_set := false
var flight := "docked" # docked, manual, transit, arrival
var position := Vector3(0, 0, 180)
var heading := Vector3(0, PI, 0)
var transit_start := Vector3.ZERO
var transit_end := Vector3.ZERO
var transit_progress := 0.0
var contract: Dictionary = {}
var cargo: Array = [] # id, good, job, location, slot. Hand counts as one location.
var next_id := 1
var delivered := 0
var traded := 0
var completed: Dictionary = {}
var earnings := 0
var spent := 0
var message := ""


func mark(step: String) -> void:
	completed[step] = true


func pay(cost: int) -> bool:
	if credits < cost:
		message = "You need %d CR; you have %d CR." % [cost, credits]
		return false
	credits -= cost
	spent += cost
	return true


func count_at(location: String, jobs_only := false) -> int:
	return cargo.filter(func(c): return c.location == location and (not jobs_only or c.job)).size()


func first_slot(location: String) -> int:
	for i in 8:
		if not cargo.any(func(c): return c.location == location and c.slot == i):
			return i
	return -1


func add_crate(good: String, job: bool, location: String) -> void:
	cargo.append({"id": next_id, "good": good, "job": job, "location": location, "slot": first_slot(location)})
	next_id += 1


func sign_contract() -> bool:
	if flight != "docked" or not contract.is_empty():
		message = "Deliver your current job before signing another." if not contract.is_empty() else "Visit a station to sign a job."
		return false
	var pad := "pad_%d" % dock
	if count_at(pad) > 6:
		message = "Clear two spaces on the station pallet first."
		return false
	contract = {"origin": dock, "dest": 1 - dock, "reward": 520, "good": GOODS[dock], "crates": 2}
	for i in 2:
		add_crate(GOODS[dock], true, pad)
	mark("contract")
	message = "Signed: two crates to %s. 520 CR on delivery. Cargo is on the pallet." % STATIONS[1 - dock]
	return true


func buy_cargo() -> bool:
	if flight != "docked":
		return false
	var pad := "pad_%d" % dock
	if first_slot(pad) < 0:
		message = "Station pallet is full."
		return false
	if not pay(BUY[dock]):
		return false
	add_crate(GOODS[dock], false, pad)
	mark("buy")
	message = "Bought one %s crate for %d CR. Delivered to this station's pallet." % [GOODS[dock], BUY[dock]]
	return true


func hand() -> Dictionary:
	for c in cargo:
		if c.location == "hand":
			return c
	return {}


func pick(id: int) -> bool:
	if not hand().is_empty():
		message = "Set down the crate you are carrying first."
		return false
	for c in cargo:
		if c.id == id and (c.location == "hold" or (flight == "docked" and c.location == "pad_%d" % dock)):
			c.location = "hand"
			c.slot = -1
			message = "Crate lifted. Aim at an empty hold or pallet space to place it."
			return true
	return false


func place(location: String, slot: int) -> bool:
	var held := hand()
	if held.is_empty() or slot < 0 or slot >= 8:
		return false
	if location != "hold" and (flight != "docked" or location != "pad_%d" % dock):
		return false
	if cargo.any(func(c): return c.location == location and c.slot == slot):
		message = "That space is occupied."
		return false
	held.location = location
	held.slot = slot
	mark("load" if location == "hold" else "unload")
	message = "Cargo secured in %s." % ("the hold" if location == "hold" else "the station pallet")
	return true


func handling(load_ship: bool) -> bool:
	if flight != "docked":
		return false
	var src := "pad_%d" % dock if load_ship else "hold"
	var dst := "hold" if load_ship else "pad_%d" % dock
	var count := count_at(src)
	if count == 0:
		message = "There is no cargo to %s." % ("load" if load_ship else "unload")
		return false
	if count + count_at(dst) > 8:
		message = "Not enough space for this transfer. Make room first."
		return false
	if not pay(count * 15):
		return false
	for c in cargo:
		if c.location == src:
			c.slot = first_slot(dst)
			c.location = dst
	mark("crew_load" if load_ship else "crew_unload")
	message = "Dock crew %s %d crates for %d CR." % ["loaded" if load_ship else "unloaded", count, count * 15]
	return true


func accessible(c: Dictionary) -> bool:
	return flight == "docked" and c.location in ["hold", "hand", "pad_%d" % dock]


func deliver() -> bool:
	if contract.is_empty() or flight != "docked" or dock != contract.dest:
		message = "Bring the job to its destination station."
		return false
	var crates := cargo.filter(func(c): return c.job and accessible(c))
	if crates.size() != contract.crates:
		message = "Both job crates must be here before you can deliver."
		return false
	var hold := crates.filter(func(c): return c.location == "hold").size()
	var fee := hold * 26 # 10% of each crate's half of a 520 CR job.
	var reward: int = contract.reward - fee
	for c in crates:
		cargo.erase(c)
	credits += reward
	earnings += reward
	contract = {}
	delivered += 1
	mark("deliver")
	message = "Delivery complete: +%d CR. Dock-crew fee: %d CR. A return job is available." % [reward, fee]
	return true


func sell_cargo() -> bool:
	if flight != "docked":
		return false
	var crates := cargo.filter(func(c): return not c.job and accessible(c))
	if crates.is_empty():
		message = "No personal cargo here to sell. Job cargo belongs to the client."
		return false
	var total := 0
	for c in crates:
		var value: int = SELL[1 - dock] if c.good != GOODS[dock] else int(BUY[dock] * 0.75)
		if c.location == "hold":
			value = int(value * 0.9)
		total += value
		cargo.erase(c)
	credits += total
	earnings += total
	traded += crates.size()
	mark("sell")
	message = "Sold %d personal crates for %d CR (hold unloading fees included)." % [crates.size(), total]
	return true


func consume(kind: String) -> bool:
	match kind:
		"eat":
			if rations <= 0:
				message = "Food locker empty. Buy provisions at a station."
				return false
			if food >= 98:
				message = "You have already eaten."
				return false
			rations -= 1
			food = minf(100, food + 42)
			message = "Meal finished. Food restored."
		"drink":
			if drinks <= 0:
				message = "Water supply empty. Refill at a station."
				return false
			if water >= 98:
				message = "You are hydrated."
				return false
			drinks -= 1
			water = minf(100, water + 48)
			message = "A drink of water. Hydration restored."
		"wash":
			if drinks <= 0:
				message = "Washing needs one water unit. Refill at a station."
				return false
			drinks -= 1
			hygiene = 100
			message = "Washed and refreshed. Used one water unit."
		"rest":
			message = "A quiet moment in your bunk. The ship keeps its course."
	mark(kind)
	return true


func service(kind: String) -> bool:
	if flight != "docked":
		return false
	match kind:
		"refuel":
			var cost := ceili((100 - fuel) * 2)
			if not pay(cost): return false
			fuel = 100
			message = "Tanks filled for %d CR." % cost
		"provisions":
			if not pay(35): return false
			rations += 3
			drinks += 5
			message = "Stocked 3 meals and 5 water units for 35 CR."
		"technician":
			if not pay(120): return false
			pump = 100
			drive = 100
			patched = false
			message = "Technician replaced worn parts. Both systems restored for 120 CR."
	mark(kind)
	return true


func patch_pump() -> void:
	pump = maxf(pump, 78)
	patched = true
	mark("repair")
	message = "Coolant circuit bypassed. Pump restored to 78%. Temporary patch; book a station technician."


func tick(delta: float) -> void:
	food = maxf(0, food - delta * 0.018)
	water = maxf(0, water - delta * 0.026)
	hygiene = maxf(0, hygiene - delta * 0.012)


func to_dict() -> Dictionary:
	return {"version": 1, "credits": credits, "fuel": fuel, "food": food, "water": water, "hygiene": hygiene,
		"rations": rations, "drinks": drinks, "pump": pump, "drive": drive, "patched": patched, "fault_seen": fault_seen,
		"dock": dock, "destination": destination, "route_set": route_set, "flight": flight,
		"position": [position.x, position.y, position.z], "heading": [heading.x, heading.y, heading.z],
		"transit_start": [transit_start.x, transit_start.y, transit_start.z], "transit_end": [transit_end.x, transit_end.y, transit_end.z],
		"transit_progress": transit_progress, "contract": contract, "cargo": cargo, "next_id": next_id,
		"delivered": delivered, "traded": traded, "completed": completed, "earnings": earnings, "spent": spent}


func save_game(path := SAVE_PATH) -> bool:
	# Write a sibling temporary file first; an interrupted write preserves the last save.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		message = "Could not save this session."
		return false
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	message = "Session saved." if err == OK else "Could not replace the previous save."
	return err == OK


func load_game(path := SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		message = "No saved slice yet."
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1:
		message = "This save cannot be read. Start a fresh session."
		return false
	var defaults := to_dict()
	for key in defaults:
		if not data.has(key):
			message = "The save is incomplete."
			return false
	for key in ["position", "heading", "transit_start", "transit_end"]:
		if not data[key] is Array or data[key].size() != 3 or not data[key].all(func(v): return v is float or v is int): return false
	for key in ["credits", "fuel", "food", "water", "hygiene", "pump", "drive", "rations", "drinks", "dock", "destination", "next_id", "delivered", "traded", "earnings", "spent", "transit_progress"]:
		if not (data[key] is float or data[key] is int) or not is_finite(float(data[key])): return false
	if int(data.dock) not in [0, 1] or int(data.destination) not in [0, 1] or data.flight not in ["docked", "manual", "transit", "arrival"]: return false
	if not data.cargo is Array or not data.contract is Dictionary or not data.completed is Dictionary: return false
	var occupied := {}
	var ids := {}
	for c in data.cargo:
		if not c is Dictionary: return false
		for key in ["id", "good", "job", "location", "slot"]:
			if not c.has(key): return false
		if c.location not in ["hold", "hand", "pad_0", "pad_1"] or c.good not in GOODS or not c.job is bool: return false
		if not (c.slot is float or c.slot is int) or not (c.id is float or c.id is int): return false
		if c.location != "hand" and (int(c.slot) < 0 or int(c.slot) > 7): return false
		var space: String = c.location + str(int(c.slot))
		if occupied.has(space) or ids.has(int(c.id)): return false
		occupied[space] = true
		ids[int(c.id)] = true
	if not data.contract.is_empty():
		for key in ["origin", "dest", "reward", "good", "crates"]:
			if not data.contract.has(key): return false
		if data.contract.origin not in [0, 1] or data.contract.dest not in [0, 1] or data.contract.crates != 2 or data.contract.reward != 520: return false
	for key in defaults:
		if key == "version": continue
		if key in ["position", "heading", "transit_start", "transit_end"]:
			set(key, Vector3(data[key][0], data[key][1], data[key][2]))
		else:
			set(key, data[key])
	for key in ["fuel", "food", "water", "hygiene", "pump", "drive"]:
		set(key, clampf(get(key), 0, 100))
	message = "Saved session restored."
	return true
