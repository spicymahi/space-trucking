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
	for i in 160:
		if s.safe_departure(): break
		s.tick(0.5,Vector3.FORWARD*0.25)
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
	s.attitude=Basis.IDENTITY
	for i in 1500:
		var g: Dictionary=s.guidance()
		s.tick(0.1,(g.dv/s.max_acceleration()*0.9).limit_length(1))
		if s.station_range()<12 and s.relative_speed()<1: break
	s.command("comms","dock")
	return s.phase=="docked"

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
	check(not restored.autopilot and restored.warp==1,"Manual thrust takes control without teleporting")
	var before: Vector3=restored.ship_position
	restored.recalculate()
	check(restored.autopilot and restored.ship_position==before,"Recalculation resumes from real position")
	restored.command("engine","port off")
	restored.tick(0.1)
	check(not restored.autopilot and not restored.sleeping and restored.warning.contains("unavailable"),"Engine loss interrupts NAV and wakes sleeper")
	var start_rest: float=s.rest
	s.sleep_until_warning()
	var slept_through_burn:=false
	for i in 1900:
		if s.phase=="approach": break
		s.tick(0.5)
		if s.phase=="brake" and s.sleeping: slept_through_burn=true
	check(slept_through_burn,"Sleep continues through automatic arrival burn")
	check(s.phase=="approach" and s.arrival_hold and not s.sleeping and s.warp==1,"Sleep wakes at safe station arrival")
	check(s.rest>start_rest,"Sleep restores rest")
	check(s.station_range()>580 and s.station_range()<620 and s.relative_speed()<1,"Arrival holds outside the station with matched velocity")
	for i in 120: s.tick(1)
	check(absf(s.station_range()-600)<8 and s.relative_speed()<0.6,"Arrival hold follows a moving station while player is away")
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
