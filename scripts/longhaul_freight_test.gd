extends RefCounted
## Contracts, optional port crews, retained saves, and the actual hand-carry route.
const State=preload("res://scripts/longhaul_flight_state.gd")
const Freight=preload("res://scripts/longhaul_freight.gd")
const System=preload("res://scripts/longhaul_system.gd")
var passed:=0
var failed:=0
var host: Node3D
func check(value: bool, description: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("FREIGHT ",description,": ",value)

func command(value: String) -> String:
	return host.terminal_command("comms",value)

func run(ship: Node3D) -> bool:
	host=ship
	var original_flight=host.flight
	var original_freight: Dictionary=host.freight.snapshot()
	var original_slot: int=host.cargo_module.crate_slot
	var original_lock: bool=host.cargo_module.locked
	host.close_terminal()
	host.flight=State.new()
	host.seated=false
	host.hab_seated=false
	host.paused=false
	host.paper_pinned=false
	var cargo=host.cargo_module
	var freight=host.freight
	check(not cargo.carrying,"Freight checks start with an available pair of hands")
	freight.contract.clear()
	freight.credits=600
	freight.case_available=true
	var pages_ok:=true
	for origin in System.STATIONS.size():
		host.flight.dock_id=origin
		var directory: String=command("jobs 1")+command("jobs 2")+command("jobs 3")
		pages_ok=pages_ok and directory.count("NO DEADLINES")==3
		for destination in System.STATIONS.size():
			if destination!=origin: pages_ok=pages_ok and directory.contains("%02d %-9s" % [System.STATIONS[destination].number,System.IDS[destination].to_upper()])
	check(pages_ok,"Every port offers all fourteen onward destinations across three deadline-free pages")
	check(command("jobs 4").contains("jobs 1") and command("jobs nope").contains("jobs 1"),"Invalid job pages explain the available pages")
	var booking_ok:=true
	for destination in System.STATIONS.size():
		host.flight.dock_id=(destination+1)%System.STATIONS.size()
		freight.contract.clear()
		var response:=command("accept "+str(System.STATIONS[destination].number))
		booking_ok=booking_ok and response.contains("ACCEPTED") and int(freight.contract.get("destination",-1))==destination and cargo.crate_slot==2 and not cargo.locked
	check(booking_ok,"All fifteen station numbers book the intended physical consignment")
	host.flight.dock_id=0
	freight.contract.clear()
	check(command("accept ceres").contains("another station") and freight.contract.is_empty(),"Cannot book a delivery back to the same berth")
	check(command("accept nowhere").contains("another station") and freight.contract.is_empty(),"Unknown station does not create a contract")
	check(command("accept tharsis").contains("ACCEPTED"),"Station IDs also book freight")
	check(command("accept kepler").contains("One consignment") and freight.contract.destination==1,"Second booking preserves active cargo")
	host.sync_hardware()
	check(not host.flight.cargo_secured and is_equal_approx(host.flight.cargo_mass,560),"Waiting pallet cargo blocks departure and is excluded from ship mass")
	var pay: int=freight.contract.pay
	var before: int=freight.credits
	check(command("deliver").contains("belongs") and freight.credits==before,"Wrong station cannot pay a contract")
	host.ramp_up=true
	check(command("crew load").contains("Lower the ramp") and freight.credits==before,"Port crew requires a lowered ramp without charging a failed call")
	host.ramp_up=false
	host.loading_module.hatch_open=false
	check(command("crew load").contains("open the cargo hatch") and freight.credits==before,"Port crew requires an open cargo hatch")
	host.loading_module.hatch_open=true
	host.ramp_moving=true
	check(command("crew load").contains("Lower the ramp") and freight.credits==before,"Crew waits until ramp motion has finished")
	host.ramp_moving=false
	freight.credits=24
	check(command("crew load").contains("Manual handling remains free") and cargo.crate_slot==2 and freight.credits==24,"Insufficient credits preserve cargo and permit free manual loading")
	freight.credits=before
	check(command("crew load").contains("complete") and freight.credits==before-25 and cargo.crate_slot==0 and cargo.locked,"Optional crew loads and clamps the case for exactly 25 credits")
	host.sync_hardware()
	check(host.flight.cargo_secured and is_equal_approx(host.flight.cargo_mass,595),"Loaded freight contributes its 35 kg and satisfies cargo readiness")
	check(command("crew load").contains("origin pallet") and freight.credits==before-25,"Repeated crew load cannot charge twice")
	check(command("crew unload").contains("contracted destination") and freight.credits==before-25,"Crew refuses unloading the contract at the wrong station")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(freight.snapshot()))
	var restored=Freight.new()
	check(restored.restore(saved) and same_job(restored.contract,freight.contract) and restored.credits==freight.credits,"Contract destination, reward and credits survive JSON save/load")
	var bad:=saved.duplicate(true)
	bad.contract.destination=System.STATIONS.size()
	check(not restored.restore(bad) and same_job(restored.contract,freight.contract),"Malformed freight save is rejected without changing the current job")
	restored.free()
	check(host.save_session("/tmp/longhaul-freight-session-test.json").contains("saved"),"Full ship session saves active freight")
	freight.credits=999
	freight.contract.clear()
	cargo.crate_slot=1
	var loaded: String=host.load_session("/tmp/longhaul-freight-session-test.json")
	check(loaded.contains("restored") and freight.credits==before-25 and freight.contract.get("destination",-1)==1 and cargo.crate_slot==0 and cargo.locked,"Full session restores the job, balance and physical receiving berth together")
	host.close_terminal()
	host.seated=false
	host.flight.dock_id=1
	check(command("deliver").contains("station pallet first") and freight.credits==before-25,"Arrival alone cannot pay before cargo is unloaded")
	check(command("crew unload").contains("complete") and cargo.crate_slot==2 and freight.credits==before-50,"Destination crew unloads for exactly 25 credits")
	check(command("deliver").contains("DELIVERY COMPLETE") and freight.credits==before-50+pay and freight.contract.is_empty() and not cargo.held_crate.visible,"Delivery pays the agreed reward and removes the delivered case")
	var paid: int=freight.credits
	check(command("deliver").contains("No active") and freight.credits==paid,"Delivered contracts cannot pay twice")
	# All interaction and carrying below use the real F binding and collision geometry.
	host.flight=State.new()
	host.ramp_up=false
	host.ramp_pivot.rotation.x=atan(1.2/4.2)
	host.ramp_fold.rotation.x=0
	host.loading_module.hatch_open=true
	host.loading_module.hatch_moving=false
	for index in 2: host.loading_module.leaves[index].position.x=(-1 if index==0 else 1)*2.14
	command("accept tharsis")
	host.player.position=Vector3(0,0.05,5.68)
	host.player.velocity=Vector3.ZERO
	host.camera.position=Vector3(0,1.65,0)
	host.camera.rotation=Vector3.ZERO
	host.pitch=0
	host._update_flight_world()
	await host._frames(12)
	await walk(Vector3(0,0,16),"Walk from cargo hold down the open ramp")
	await walk(Vector3(2.2,0,18.5),"Reach station freight pallet on the landing deck")
	await use("cargo_berth_2")
	check(cargo.carrying and cargo.held_crate.get_parent()==host.player,"F lifts the booked consignment from the station pallet")
	if cargo.carrying:
		check(command("crew load").contains("Set the case down"),"Crew cannot move a case being carried by the player")
		await walk(Vector3(0,0,18.5),"Carry away from pallet into ramp approach")
		await walk(Vector3(0,0,16),"Align carried freight with the ramp")
		await walk(Vector3(0,0,9),"Carry freight up ramp through the cargo hatch")
		await walk(Vector3(0,0,5.68),"Carry freight into the receiving aisle")
		await use("cargo_berth_0")
		check(not cargo.carrying and cargo.crate_slot==0,"F places freight into its receiving berth")
		await walk(Vector3(0,0,0.30),"Reach receiving clamp control")
		await use("cargo_clamps")
		host.sync_hardware()
		check(cargo.locked and host.flight.cargo_secured,"Physical clamp control secures the contract cargo for departure")
		# Arrival is a fixture; loading and unloading remain entirely input-driven.
		host.flight.dock_id=1
		host.flight.ship_position=host.flight.station_position(1,host.flight.elapsed)
		host.flight.velocity=host.flight.station_velocity(1,host.flight.elapsed)
		host._update_flight_world()
		await use("cargo_clamps")
		await walk(Vector3(0,0,5.68),"Return to receiving berth for unloading")
		await use("cargo_berth_0")
		check(cargo.carrying,"F retrieves released contract freight at destination")
		if cargo.carrying:
			await walk(Vector3(0,0,9),"Carry delivery through engineering")
			await walk(Vector3(0,0,16),"Carry delivery down ramp to station")
			await walk(Vector3(0,0,18.5),"Clear ramp before approaching station pallet")
			await walk(Vector3(2.2,0,18.5),"Bring delivery alongside station pallet")
			await use("cargo_berth_2")
			check(not cargo.carrying and cargo.crate_slot==2,"F unloads the case to the destination pallet")
			check(command("deliver").contains("DELIVERY COMPLETE"),"Entire manual load, clamp, unload and payment loop completes")
	# Restore test host before later suites or shutdown; never touch the player's save.
	if cargo.carrying:
		cargo.carrying=false
		cargo.held_crate.reparent(cargo,false)
		if is_instance_valid(cargo.carry_shape): cargo.carry_shape.queue_free()
		cargo.carry_shape=null
	cargo.crate_slot=original_slot
	cargo.locked=original_lock
	cargo.held_crate.position=cargo.slots[original_slot]
	cargo.crate_body.collision_mask=1
	host.flight=original_flight
	freight.restore(original_freight)
	freight.refresh()
	cargo._update_manifest()
	print("LONGHAUL FREIGHT ",passed," passed / ",failed," failed")
	return failed==0

func walk(target: Vector3, description: String) -> void:
	var reached: bool=await host._walk_to(target)
	check(reached and host.player.is_on_floor(),description)

func use(action: String) -> void:
	var cargo=host.cargo_module
	var body: Node3D=cargo.use_targets[action]
	var direction: Vector3=(body.global_position-host.camera.global_position).normalized()
	host.player.rotation.y=atan2(-direction.x,-direction.z)
	host.pitch=asin(direction.y)
	host.camera.rotation=Vector3(host.pitch,0,0)
	await host._frames(2)
	var hit: Dictionary=cargo.interaction(host.camera,host.player)
	var reachable: bool=not hit.is_empty() and hit.get("action","")==action
	check(reachable,"Raycast reaches "+action)
	if not reachable:
		print("FREIGHT interaction miss ",hit," player=",host.player.position," target=",body.global_position)
		return
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_F
	event.keycode=KEY_F
	event.pressed=true
	Input.parse_input_event(event)
	await host._frames(2)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await host._frames(3)

func same_job(a: Dictionary, b: Dictionary) -> bool:
	# JSON represents integral values as floats; compare the gameplay values.
	return int(a.get("origin",-1))==int(b.get("origin",-2)) and int(a.get("destination",-1))==int(b.get("destination",-2)) and int(a.get("pay",-1))==int(b.get("pay",-2)) and a.get("cargo","")==b.get("cargo","missing")
