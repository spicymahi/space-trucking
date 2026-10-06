extends RefCounted
const State=preload("res://scripts/longhaul_flight_state.gd")
var passed:=0
var failed:=0

func check(value: bool, description: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("FLIGHT ",description,": ",value)

func prepare(s, id: String="tharsis", style: String="direct") -> void:
	s.command("engine","port on")
	s.command("engine","starboard on")
	s.command("chart","plot "+id+" "+style)
	s.command("nav","coords "+s.coords_text())
	s.command("nav","burn 6")
	s.command("nav","reserve 200")
	s.command("nav","load")
	s.command("comms","request")
	s.command("comms","code "+s.clearance)
	s.hatch_closed=true
	s.ramp_raised=true

func fly_departure(s) -> bool:
	s.depart()
	# New arrivals park nose-in; reverse out through the same open corridor.
	var departure_thrust: Vector3=Vector3.BACK if (-s.attitude.z).dot(Vector3.BACK)>0 else Vector3.FORWARD
	for i in 160:
		if s.safe_departure(): break
		s.tick(0.5,departure_thrust*0.25)
	s.engage_navigation()
	return s.autopilot

func arrive(s, fast:=false) -> bool:
	if fast: s.sleep_until_warning()
	for i in 1900:
		if s.phase=="approach": return true
		if s.fuel<=0: return false
		s.tick(1)
	return false

func automatic_dock(s) -> bool:
	s.command("comms","approach")
	s.command("comms","autodock")
	for i in 200:
		if s.phase=="docked": return true
		s.tick(0.5)
	return false

func manual_dock(s) -> bool:
	s.command("comms","approach")
	s.command("nav","manual")
	s.attitude=Basis.looking_at(Vector3.BACK,Vector3.UP)
	for i in 1500:
		var g: Dictionary=s.guidance()
		s.tick(0.1,(s.attitude.inverse()*g.dv/s.max_acceleration()*0.9).limit_length(1))
		if s.station_range()<12 and s.relative_speed()<1: break
	s.command("comms","dock")
	return s.phase=="docked"

func check_docking_aliases() -> void:
	var aliases: Array[String]=["auto dock","autodock","auto-dock"]
	var phases: Array[String]=["departure","injection","coast"]
	for i in aliases.size():
		var legacy=State.new()
		prepare(legacy)
		legacy.phase=phases[i]
		legacy.ship_position=legacy.station_position(legacy.destination,legacy.elapsed)+Vector3(0,0,-500)
		legacy.velocity=legacy.station_velocity(legacy.destination,legacy.elapsed)
		var terminal: String="nav" if i%2==0 else "comms"
		var clearance: String=legacy.command(terminal,"approach")
		check(legacy.approach_clearance and clearance.contains("K-01 AUTOMATICALLY ASSIGNED"),"%s phase: approach automatically assigns berth on %s" % [phases[i],terminal])
		# Preserve the legacy phase here to prove docking depends on real position.
		legacy.phase=phases[i]
		var reply: String=legacy.command(terminal,aliases[i])
		check(legacy.auto_docking and legacy.autopilot and reply.contains("engaged"),aliases[i]+" starts despite legacy phase")
		legacy.tick(1,Vector3.ONE,Vector3.ONE)
		check(legacy.auto_docking and legacy.autopilot,aliases[i]+" ignores stray flight keys")
		for frame in 220:
			if legacy.phase=="docked": break
			legacy.tick(0.5)
		check(legacy.phase=="docked",aliases[i]+" captures assigned berth")
	var legacy_manual=State.new()
	prepare(legacy_manual)
	legacy_manual.phase="injection"
	legacy_manual.ship_position=legacy_manual.station_position(legacy_manual.destination,legacy_manual.elapsed)+Vector3(0,0,-5)
	legacy_manual.velocity=legacy_manual.station_velocity(legacy_manual.destination,legacy_manual.elapsed)
	legacy_manual.approach_clearance=true
	check(not legacy_manual.command("nav","dock").contains("Docked") and legacy_manual.phase!="docked","Manual capture rejects the old stern-first heading")
	legacy_manual.attitude=Basis.looking_at(Vector3.BACK,Vector3.UP)
	check(legacy_manual.command("nav","dock").contains("Docked"),"Manual capture accepts a legacy phase at the nose-first berth heading")
	check((-legacy_manual.attitude.z).dot(Vector3.BACK)>0.999,"Manual capture keeps the nose pointed into the berth")

func check_nose_first_docking() -> void:
	var turning=State.new()
	prepare(turning)
	turning.phase="approach"
	turning.ship_position=turning.station_position(turning.destination,turning.elapsed)+Vector3(0,0,-500)
	turning.velocity=turning.station_velocity(turning.destination,turning.elapsed)
	turning.command("nav","approach")
	turning.command("nav","auto dock")
	var start_range: float=turning.station_range()
	turning.tick(1)
	check(turning.phase=="approach" and start_range-turning.station_range()<0.5,"Wrong-facing autodock turns before closing on the berth")
	var resumed=State.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(turning.snapshot()))) and resumed.auto_docking,"Mid-turn autodock survives JSON save and load")
	var old_docking: Dictionary=turning.snapshot()
	old_docking.flight_revision=3
	old_docking.erase("docking_stage")
	old_docking.autopilot=false
	var legacy_resume=State.new()
	check(legacy_resume.restore(JSON.parse_string(JSON.stringify(old_docking))) and legacy_resume.autopilot and legacy_resume.auto_docking,"Older docking saves migrate to engaged nose-first assistance")
	var no_reverse:=true
	var forward_samples:=0
	var capture_continuity:=false
	for frame in 1000:
		var before_nose: Vector3=-resumed.attitude.z
		resumed.tick(0.2)
		if resumed.phase=="docked":
			capture_continuity=before_nose.dot(-resumed.attitude.z)>cos(deg_to_rad(1))
			break
		var relative_velocity: Vector3=resumed.velocity-resumed.station_velocity(resumed.destination,resumed.elapsed)
		var to_berth: Vector3=(resumed.station_position(resumed.destination,resumed.elapsed)-resumed.ship_position).normalized()
		if relative_velocity.dot(to_berth)>0.5:
			forward_samples+=1
			if relative_velocity.dot(-resumed.attitude.z)<-0.1: no_reverse=false
	check(resumed.phase=="docked" and forward_samples>50 and no_reverse,"Resumed autodock flies toward the berth nose-first")
	check(capture_continuity and (-resumed.attitude.z).dot(Vector3.BACK)>0.999,"Berth capture preserves the inward heading without a rotation snap")
	var parked=State.new()
	check(parked.restore(JSON.parse_string(JSON.stringify(resumed.snapshot()))) and parked.attitude.is_equal_approx(resumed.attitude),"Nose-in parked orientation survives save and load")
	var old_parked: Dictionary=resumed.snapshot()
	old_parked.flight_revision=3
	old_parked.attitude=[1,0,0,0,1,0,0,0,1]
	check(parked.restore(old_parked) and parked.attitude.is_equal_approx(Basis.IDENTITY),"Older outward-facing docked saves keep their parked orientation")
	for offset in [Vector3(-280,0,-120),Vector3(0,0,450)]:
		var entry=State.new()
		prepare(entry)
		entry.phase="approach"
		entry.ship_position=entry.station_position(entry.destination,entry.elapsed)+offset
		entry.velocity=entry.station_velocity(entry.destination,entry.elapsed)
		entry.command("nav","approach")
		entry.command("nav","auto dock")
		var avoids_spine:=true
		var nose_first:=true
		var final_samples:=0
		for frame in 1800:
			entry.tick(0.2)
			if entry.phase=="docked": break
			var relative: Vector3=entry.ship_position-entry.station_position(entry.destination,entry.elapsed)
			if absf(relative.x)<35 and absf(relative.y)<12 and relative.z>25 and relative.z<65: avoids_spine=false
			if relative.z<0 and relative.length()<100:
				var closing_velocity: Vector3=entry.velocity-entry.station_velocity(entry.destination,entry.elapsed)
				if closing_velocity.dot(-relative.normalized())>0.5:
					final_samples+=1
					if closing_velocity.dot(-entry.attitude.z)<-0.1: nose_first=false
		var label: String="Rear" if offset.z>0 else "Side"
		check(entry.phase=="docked" and avoids_spine,label+" autodock entry routes around station structure")
		check(final_samples>10 and nose_first and (-entry.attitude.z).dot(Vector3.BACK)>0.999,label+" autodock entry finishes nose-first")

func check_sleep_boundary(coast_state: Dictionary) -> void:
	var boundary=State.new()
	boundary.restore(coast_state)
	boundary.plan.eta=boundary.elapsed+90.37
	boundary.sleep_until_warning()
	var started: float=boundary.elapsed
	boundary.tick(60)
	check(absf(boundary.elapsed-started-0.37)<0.0001 and not boundary.sleeping and boundary.warp==1,"Large accelerated frame stops at the precise wake boundary")
	check(boundary.autopilot and boundary.warning.contains("90 seconds") and boundary.phase!="brake","Wake alarm leaves NAV engaged before braking")
	boundary.tick(0.5)
	check(absf(boundary.time_to_burn()-89.5)<0.001,"Simulation resumes at normal time after alarm")

func check_reference_axes() -> void:
	var readout=State.new()
	prepare(readout)
	readout.phase="departure"
	check(readout.reference_station_id()==readout.dock_id,"Departure velocity uses origin station reference")
	readout.phase="coast"
	check(readout.reference_station_id()==readout.destination,"Transfer velocity uses destination station reference")
	readout.attitude=Basis(Vector3.UP,PI/2)
	readout.velocity=readout.station_velocity(readout.destination,readout.elapsed)+readout.attitude*Vector3(3,4,-5)
	readout.ship_position=readout.station_position(readout.destination,readout.elapsed)-readout.attitude*Vector3(5,6,-7)
	check(readout.relative_velocity_local().distance_to(Vector3(3,4,-5))<0.001,"Relative velocity follows ship right/up/forward axes")
	check(readout.station_offset_local().distance_to(Vector3(5,6,-7))<0.05,"Station radar offset follows the same ship axes")

func run(host) -> bool:
	var s=State.new()
	check(s.command("comms","depart").contains("interlock"),"Incomplete startup blocked")
	check(s.command("nav","load").contains("CHART"),"NAV requires plotted route")
	check(s.command("nav","coords 1 nan 3").contains("finite"),"Nonfinite coordinate rejected")
	s.command("engine","port on")
	check(s.engines==[true,false] and s.engine_diagram().contains("STARBOARD: OFF"),"Engine switches and ASCII diagram are independent")
	var one: float=s.max_acceleration()
	s.command("engine","starboard on")
	check(is_equal_approx(s.max_acceleration(),2*one),"Each engine contributes to actual thrust")
	prepare(s)
	check(s.can_depart(),"Departure needs no mixture setting")
	s.command("engine","starboard off")
	check(not s.can_depart(),"One engine off blocks takeoff")
	s.command("engine","starboard on")
	for field in ["hatch_closed","ramp_raised","cargo_secured","clearance_confirmed"]:
		s.set(field,false)
		check(not s.can_depart(),"Readiness gate: "+field)
		s.set(field,true)
	s.closures_busy=true
	check(not s.can_depart(),"Moving hardware blocks takeoff")
	s.closures_busy=false
	s.command("comms","code WRONG")
	check(not s.can_depart(),"Wrong takeoff code rejected")
	s.command("comms","code "+s.clearance)
	var original_fuel: float=s.fuel
	s.fuel=s.plan.fuel+199
	check(not s.can_depart(),"Spare fuel included in departure validation")
	s.fuel=original_fuel
	var stamp: float=s.elapsed
	s.tick(7200)
	check(s.elapsed==stamp and s.can_depart(),"Reading paperwork has no ticking launch deadline")
	s.depart()
	check(not s.engage_navigation().contains("engaged"),"Autopilot cannot engage inside station corridor")
	var predicted: Array=s.propagate(s.ship_position,s.velocity,10)
	s.tick(10)
	check(s.ship_position.distance_to(predicted[0])<5,"Momentum and gravity preserved without thrust")
	s.angular_velocity=Vector3(0,0.2,0)
	predicted=s.propagate(s.ship_position,s.velocity,1)
	s.tick(1,Vector3.ZERO,Vector3.ZERO,true)
	check(s.angular_velocity.length()<0.001 and s.velocity.distance_to(predicted[1])<0.2,"X stops spin without stopping translation")
	s=State.new()
	prepare(s)
	check(fly_departure(s),"Manual departure hands over to automatic transfer")
	var coast_state: Dictionary=s.snapshot()
	var restored=State.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(coast_state))) and restored.autopilot,"Automatic journey survives JSON save/load")
	var invalid:=coast_state.duplicate(true)
	invalid.velocity=[0,"bad",0]
	check(not restored.restore(invalid),"Invalid save rejected before mutation")
	restored.tick(0.2,Vector3.RIGHT*0.1)
	check(restored.autopilot,"Thrust key does not cancel engaged NAV")
	var control=State.new()
	control.restore(coast_state)
	control.tick(0.2,Vector3.ZERO,Vector3(1,1,1),true)
	check(control.autopilot and control.angular_velocity==Vector3.ZERO and control.attitude.is_equal_approx(restored.attitude),"Rotation and spin-stop keys leave NAV heading under automatic control")
	restored.command("engine","manual")
	check(not restored.autopilot and restored.warp==1,"Explicit manual works from every terminal")
	var before: Vector3=restored.ship_position
	restored.recalculate()
	check(restored.autopilot and restored.ship_position==before,"Recalculation resumes from real position")
	restored.command("engine","port off")
	restored.tick(0.1)
	check(not restored.autopilot and not restored.sleeping and restored.warning.contains("unavailable"),"Engine loss interrupts NAV and wakes sleeper")
	var start_rest: float=s.rest
	s.sleep_until_warning()
	for i in 1900:
		if not s.sleeping: break
		s.tick(0.5)
	check(not s.sleeping and s.warp==1 and s.autopilot and absf(s.time_to_burn()-90)<0.001,"Sleep wakes exactly 90 seconds before braking with NAV still engaged")
	check(s.sleep_until_warning().contains("awake") and not s.sleeping and s.warp==1,"Cannot sleep again after arrival watch starts")
	check(s.set_warp(20).contains("watch") and s.warp==1,"Cannot accelerate through arrival watch")
	for i in 1900:
		if s.phase=="approach": break
		s.tick(0.5)
	check(s.phase=="approach" and s.arrival_hold and s.autopilot and not s.sleeping and s.warp==1,"NAV stays engaged at safe station arrival")
	check(s.rest>start_rest,"Sleep restores rest")
	check(s.station_range()>580 and s.station_range()<620 and s.relative_speed()<1,"Arrival holds outside the station with matched velocity")
	for i in 120: s.tick(1)
	check(absf(s.station_range()-600)<8 and s.relative_speed()<0.6,"Arrival hold follows a moving station while player is away")
	var hold_save:=s.snapshot()
	hold_save.flight_revision=2
	hold_save.autopilot=false
	var old_hold=State.new()
	check(old_hold.restore(hold_save) and old_hold.autopilot and old_hold.arrival_hold,"Older arrival-hold saves migrate to engaged NAV")
	old_hold.tick(5,Vector3.FORWARD,Vector3.ONE)
	check(old_hold.autopilot and old_hold.arrival_hold and absf(old_hold.station_range()-600)<8,"Control keys cannot accidentally release station hold")
	check(s.engage_docking().contains("clearance"),"Auto docking requires arrival clearance")
	s.command("comms","approach")
	var place: Vector3=s.ship_position
	s.ship_position+=Vector3(2000,0,0)
	check(s.engage_docking().contains("1000"),"Distant auto docking rejected")
	s.ship_position=place
	var speed: Vector3=s.velocity
	s.velocity+=Vector3(40,0,0)
	check(s.engage_docking().contains("15"),"Fast auto docking rejected")
	s.velocity=speed
	check(manual_dock(s),"Manual station approach and capture remain available")
	check_docking_aliases()
	check_nose_first_docking()
	check_sleep_boundary(coast_state)
	check_reference_axes()
	for id in ["tharsis","kepler","helios"]:
		for style in ["direct","economy"]:
			var route=State.new()
			route.coolant=0.70
			prepare(route,id,style)
			check(route.can_depart(),"%s %s fuel feasible" % [id,style])
			check(fly_departure(route),"%s %s manual corridor" % [id,style])
			check(arrive(route),"%s %s automatic transfer and braking" % [id,style])
			check(automatic_dock(route),"%s %s docking assistance completes capture" % [id,style])
			check(route.elapsed<1800 and route.fuel>200,"%s %s under 30 minutes with spare fuel" % [id,style])
			print("ROUTE TIME ",id," ",style,": ",route.elapsed,"s / fuel ",route.fuel)
			if style=="direct":
				route.command("comms","refuel")
				var start: float=route.elapsed
				prepare(route,"ceres")
				check(fly_departure(route) and arrive(route) and automatic_dock(route),id+" return journey")
				check(route.elapsed-start<1800 and route.dock_id==0,id+" return budget")
	var tug=State.new()
	prepare(tug)
	fly_departure(tug)
	tug.fuel=0
	tug.tick(1)
	tug.rescue()
	check(tug.phase=="docked" and tug.fuel>=600 and not tug.autopilot,"Fuel exhaustion has tug recovery")
	# Exercise live terminals, hardware animations, save/restore and focus isolation.
	host._take_seat()
	var chart=host.terminals[0]
	host.camera.look_at(chart.panel.to_global(Vector3(0,0,0.174)),Vector3.UP)
	check(host.aimed_terminal()==chart,"Physical screen can be selected by looking at its glass")
	host.open_terminal(chart)
	check(host.active_terminal==chart,"F interaction focuses the physical CRT")
	for c in "destinations":
		var event:=InputEventKey.new()
		event.pressed=true
		event.unicode=c.unicode_at(0)
		chart.handle_key(event)
	var enter:=InputEventKey.new()
	enter.keycode=KEY_ENTER
	enter.pressed=true
	chart.handle_key(enter)
	check(chart.lines.any(func(line): return line.contains("THARSIS")),"Typed CLI command executes on the physical display")
	host.close_terminal()
	check(host.active_terminal==null and is_equal_approx(host.camera.fov,76),"Escape restores the pilot view")
	host.terminal_command("engine","port on")
	host.terminal_command("engine","starboard on")
	check(host.set_ramp(true).contains("hatch"),"Physical ramp refuses to raise with an open hatch")
	host.terminal_command("checklist","hatch close")
	await host.get_tree().create_timer(0.8).timeout
	check(not host.loading_module.hatch_open and not host.loading_module.hatch_moving,"CHECKLIST terminal closes real loading hatch")
	host.set_ramp(true)
	await host.get_tree().create_timer(1.9).timeout
	host.sync_hardware()
	check(host.flight.ramp_raised and not host.ramp_moving,"CHECKLIST terminal raises real ramp and waits for completion")
	host.terminal_command("chart","plot tharsis direct")
	host.terminal_command("nav","coords "+host.flight.coords_text())
	host.terminal_command("nav","burn 6")
	host.terminal_command("nav","reserve 200")
	host.terminal_command("nav","load")
	host.terminal_command("comms","request")
	host.terminal_command("comms","code "+host.flight.clearance)
	check(host.flight.can_depart(),"Actual ship hardware satisfies startup interlocks")
	host.terminal_command("comms","depart")
	host.sync_hardware()
	host.loading_module.use("load_inner")
	check(not host.loading_module.hatch_open,"Local cargo control cannot open hatch in space")
	check(host.save_session("/tmp/longhaul-flight-test.json").contains("saved"),"Flight session saves with room state")
	host.flight.fuel=10
	var load_result: String=host.load_session("/tmp/longhaul-flight-test.json")
	check(load_result.contains("restored") and host.flight.fuel>10,"Session reload restores fuel, route and hardware")

	host.flight.restore(coast_state)
	host.camera.rotation=Vector3.ZERO
	host.player.rotation=Vector3.ZERO
	var use_key:=InputEventKey.new()
	use_key.physical_keycode=KEY_F
	use_key.keycode=KEY_F
	use_key.pressed=true
	Input.parse_input_event(use_key)
	await host._frames(3)
	check(not host.seated,"Pilot can stand during an established coast")
	check(await host._walk_to(Vector3(0,0,-7.1)),"Actual walking reaches living hab during flight")
	for target in host.life_targets:
		var near_z: float=target.position.z
		check(await host._walk_to(Vector3(0,0,near_z)),"Walk beside "+str(target.get_meta("life_action")))
		host.camera.look_at(target.global_position,Vector3.UP)
		var selected: Dictionary=host.aimed_life()
		check(not selected.is_empty() and selected.action==target.get_meta("life_action"),"Physical interaction ray reaches "+str(target.get_meta("life_action")))
		if not selected.is_empty(): host.use_life(selected.action)
		if target.get_meta("life_action")=="sleep":
			check(host.flight.sleeping and host.flight.warp==20,"Bunk interaction starts interruptible sleep")
			host.flight.sleeping=false
			host.flight.warp=1
	check(host.flight.food>90 and host.flight.water>90,"Galley interactions restore survival needs")
	host.flight.rescue()
	host.sync_hardware()
	host.set_ramp(false)
	await host.get_tree().create_timer(1.9).timeout
	host.terminal_command("checklist","hatch open")
	await host.get_tree().create_timer(0.8).timeout
	check(await host._walk_to(Vector3(0,0,9)),"Walk through cargo into engineering with flight installed")
	check(await host._walk_to(Vector3(0,0,17)),"Walk down the deployed folding ramp onto the station berth")
	check(await host._walk_to(Vector3(0,0,9)),"Walk back up the ramp into engineering")
	print("LONGHAUL FLIGHT CHECKS ",passed," passed / ",failed," failed")
	return failed==0
