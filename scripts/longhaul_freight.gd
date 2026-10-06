extends Node3D
## One retained hand-carried consignment connects every port to the freight loop.
const System=preload("res://scripts/longhaul_system.gd")
var host: Node3D
var credits:=600
var delivered:=0
var serial:=0
var contract: Dictionary={}
var case_available:=true
var pallet: Node3D
var pallet_bodies: Array[StaticBody3D]=[]
var station_label: Label3D

func build(ship: Node3D) -> void:
	host=ship
	var cargo=host.cargo_module
	pallet=cargo.group(Vector3(4.3,-1.12,18.5))
	pallet.name="StationFreightPallet"
	cargo.slots[2]=pallet.position+Vector3(0,0.33,0)
	cargo.box(Vector3.ZERO,Vector3(1.25,0.12,1.25),Color("535e55"),true,pallet)
	for x in [-0.58,0.58]: cargo.box(Vector3(x,0.07,0),Vector3(0.035,0.02,1.15),Color("c69b4d"),false,pallet)
	cargo.box(Vector3(-0.80,0.44,0),Vector3(0.12,0.88,0.12),Color("4e554e"),true,pallet)
	cargo.box(Vector3(-0.80,0.92,0),Vector3(0.42,0.25,0.16),Color("af753a"),false,pallet)
	cargo.collider(Vector3(-0.80,0.92,0),Vector3(0.44,0.27,0.18),pallet,"cargo_berth_2")
	station_label=cargo.label("STATION / FREIGHT",Vector3(0,0.96,0),0.0011,Color("e0c995"),pallet)
	station_label.rotation.y=PI
	for child in pallet.get_children():
		if child is StaticBody3D: pallet_bodies.append(child)
	refresh()

func refresh() -> void:
	if not is_instance_valid(host): return
	var cargo=host.cargo_module
	var docked: bool=host.flight.phase=="docked"
	pallet.visible=docked
	for body in pallet_bodies: body.collision_layer=1 if docked else 0
	station_label.text=System.NAMES[host.flight.dock_id].to_upper()+"\nFREIGHT / TRANSFER"
	if not cargo.carrying:
		var visible_case: bool=case_available and (cargo.crate_slot!=2 or docked)
		cargo.held_crate.visible=visible_case
		cargo.crate_body.collision_layer=1 if visible_case else 0
	for child in cargo.held_crate.get_children():
		if child is Label3D:
			child.text=("JOB %03d\n%s" % [serial,System.IDS[int(contract.destination)].to_upper()]) if not contract.is_empty() else "SERVICE / 35\nHAND CARRY"

func board(page: int=1) -> String:
	if host.flight.phase!="docked": return "Freight bookings require docking. Type contract for your active job."
	if page<1 or page>3: return "Use jobs 1, jobs 2, or jobs 3."
	var origin: int=host.flight.dock_id
	var choices: Array[int]=[]
	for i in System.IDS.size():
		if i!=origin: choices.append(i)
	var rows: Array[String]=["FREIGHT / %s / %d CR" % [System.IDS[origin].to_upper(),credits],"JOB BOARD %d/3 / NO DEADLINES" % page]
	for j in range((page-1)*5,mini(page*5,choices.size())):
		var i: int=choices[j]
		rows.append("%02d %-9s %4d CR" % [System.STATIONS[i].number,System.IDS[i].to_upper(),reward(origin,i)])
	rows.append("accept <station ID or number> / 35 kg case")
	rows.append("jobs 1|2|3 / contract / station <id>")
	return "\n".join(rows)

func reward(origin: int, destination: int) -> int:
	var distance:=System.station_position(origin,host.flight.elapsed).distance_to(System.station_position(destination,host.flight.elapsed))
	return 250+int(distance/850)+ (120 if System.STATIONS[destination].remote else 0)

func status() -> String:
	if contract.is_empty(): return "FREIGHT / %d CR\n%d DELIVERIES COMPLETED\nNo active consignment. COMMS: jobs\nEvery station offers onward freight.\nStation handling: crew load|unload / 25 CR" % [credits,delivered]
	var cargo=host.cargo_module
	var location: String="IN HAND" if cargo.carrying else ("STATION PALLET" if cargo.crate_slot==2 else "ABOARD / "+("SECURED" if cargo.locked else "CLAMPS OPEN"))
	return "JOB %03d / %s\n%s > %s\n35 KG / %s\nPAY %d CR / BALANCE %d CR\nNO DEADLINE\nLoad from the station pallet beside the ramp.\nSecure in either hold berth before plotting.\nAt destination: unload to pallet, then deliver.\nOptional crew load|unload / 25 CR each." % [serial,contract.cargo,System.IDS[int(contract.origin)].to_upper(),System.IDS[int(contract.destination)].to_upper(),location,contract.pay,credits]

func command(words: PackedStringArray) -> String:
	var cargo=host.cargo_module
	match words[0]:
		"jobs":
			if words.size()>2 or (words.size()==2 and not words[1].is_valid_int()): return "Use jobs 1, jobs 2, or jobs 3."
			return board(int(words[1]) if words.size()==2 else 1)
		"contract": return status()
		"accept":
			if host.flight.phase!="docked": return "Dock before accepting freight."
			if not contract.is_empty(): return "One consignment at a time. Type contract."
			if cargo.carrying: return "Set the service case down before accepting freight."
			if words.size()!=2: return "Use accept <station ID or number>."
			var target:=System.station_index(words[1])
			if target<0 or target==host.flight.dock_id: return "Choose another station from jobs."
			serial+=1
			contract={"origin":host.flight.dock_id,"destination":target,"pay":reward(host.flight.dock_id,target),"cargo":System.STATIONS[target].imports}
			case_available=true
			cargo.crate_slot=2
			cargo.locked=false
			cargo.held_crate.position=cargo.slots[2]
			cargo._update_manifest()
			refresh()
			return "JOB %03d ACCEPTED / %s\nCase ready on station pallet beside the ramp.\nLower ramp, open hatch, carry aboard and clamp.\nThen plot %s at CHART.\nNo deadline. Type contract for details." % [serial,contract.cargo,System.IDS[target]]
		"crew":
			if words.size()!=2 or words[1] not in ["load","unload"]: return "Use crew load or crew unload / 25 CR."
			if host.flight.phase!="docked" or contract.is_empty(): return "A docked ship and active consignment are required."
			if cargo.carrying: return "Set the case down before calling the crew."
			if host.ramp_up or host.ramp_moving or not host.loading_module.hatch_open or host.loading_module.hatch_moving: return "Lower the ramp and open the cargo hatch for the crew."
			if credits<25: return "Crew fee is 25 CR. Manual handling remains free."
			var loading: bool=words[1]=="load"
			if loading and (cargo.crate_slot!=2 or host.flight.dock_id!=int(contract.origin)): return "Load the booked case at its origin pallet."
			if not loading and (cargo.crate_slot==2 or host.flight.dock_id!=int(contract.destination)): return "Unload aboard cargo at its contracted destination."
			credits-=25
			cargo.crate_slot=0 if loading else 2
			cargo.locked=loading
			cargo.held_crate.position=cargo.slots[cargo.crate_slot]
			cargo._update_manifest()
			refresh()
			return "Crew %s complete / 25 CR. %s" % [words[1],"Case aboard and clamped." if loading else "Case on pallet. Type deliver for payment."]
		"deliver":
			if contract.is_empty(): return "No active consignment. Type jobs."
			if host.flight.phase!="docked" or host.flight.dock_id!=int(contract.destination): return "Delivery belongs at "+System.NAMES[int(contract.destination)]+"."
			if cargo.carrying or cargo.crate_slot!=2: return "Carry the case to the station pallet first, or use crew unload."
			var pay: int=contract.pay
			credits+=pay
			delivered+=1
			contract.clear()
			case_available=false
			cargo.locked=true
			refresh()
			return "DELIVERY COMPLETE / +%d CR\nBalance %d CR / %d deliveries\nCOMMS: jobs for onward freight." % [pay,credits,delivered]
	return "Use jobs, accept <id>, contract, crew load|unload, or deliver."

func snapshot() -> Dictionary:
	return {"credits":credits,"delivered":delivered,"serial":serial,"contract":contract.duplicate(true),"case_available":case_available}

func restore(data: Dictionary) -> bool:
	for key in ["credits","delivered","serial"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])) or data[key]<0 or data[key]!=int(data[key]): return false
	if not data.get("case_available") is bool or not data.get("contract") is Dictionary: return false
	var job: Dictionary=data.contract
	if not job.is_empty():
		for key in ["origin","destination","pay"]:
			if not (job.get(key) is int or job.get(key) is float) or not is_finite(float(job[key])) or job[key]!=int(job[key]): return false
		if job.origin<0 or job.origin>=System.IDS.size() or job.destination<0 or job.destination>=System.IDS.size() or job.origin==job.destination or job.pay<0 or not job.get("cargo") is String or not data.case_available: return false
	credits=int(data.credits)
	delivered=int(data.delivered)
	serial=int(data.serial)
	contract=job.duplicate(true)
	case_available=data.case_available
	return true
