extends RefCounted
const State=preload("res://scripts/longhaul_flight_state.gd")
var passed:=0
var failed:=0

func check(value: bool, description: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("FLIGHT ",description,": ",value)

func prepare(s, id: String="tharsis", style: String="direct") -> void:
	s.command("engine","power on")
	s.command("fuel","mixture 2.5")
	s.command("chart","plot "+id+" "+style)
	s.command("nav","coords "+s.coords_text())
	s.command("nav","burn %.2f" % s.plan.burn)
	s.command("nav","reserve 200")
	s.command("nav","load")
	s.command("comms","request")
	s.command("comms","code "+s.clearance)
	s.hatch_closed=true
	s.ramp_raised=true

func fly_burn(s, max_seconds:=240.0) -> bool:
	# Test pilot follows the same displayed vector, using finite-rate turning and thrust.
	var start: float=s.elapsed
	while s.elapsed-start<max_seconds and s.phase in ["departure","injection"]:
		var g: Dictionary=s.guidance()
		var dir: Vector3=g.direction
		var desired:=Basis.looking_at(dir,Vector3.UP)
		s.attitude=s.attitude.slerp(desired,minf(1,0.12))
		s.angular_velocity=Vector3.ZERO
		var aligned: bool=(-s.attitude.z).dot(dir)>0.998
		var throttle: float=clampf(g.dv.length()/s.max_acceleration()/1.1,0,1) if aligned and g.dv.length()>1.3 else 0.0
		if g.dv.length()<3: throttle=0
		s.tick(0.1,Vector3(0,0,-throttle))
	return s.phase=="coast"

func fly_arrival(s) -> bool:
	var start: float=s.elapsed
	while s.elapsed-start<260 and s.phase=="brake":
		var g: Dictionary=s.guidance()
		var desired:=Basis.looking_at(g.direction,Vector3.UP)
		s.attitude=s.attitude.slerp(desired,0.18)
		var throttle: float=clampf(g.dv.length()/s.max_acceleration()/1.5,0,1) if (-s.attitude.z).dot(g.direction)>0.998 else 0
		s.tick(0.1,Vector3(0,0,-throttle))
	if s.phase!="approach": return false
	s.command("comms","approach")
	start=s.elapsed
	while s.elapsed-start<450 and s.ship_position.distance_to(s.station_position(s.destination,s.elapsed))>12:
		var g: Dictionary=s.guidance()
		# RCS translation axes let the pilot keep the berth heading while closing.
		s.attitude=Basis.IDENTITY
		var thrust: Vector3=g.dv/s.max_acceleration()*0.9
		s.tick(0.1,thrust.limit_length(1))
	# Match station drift at the berth before capture.
	for i in 60:
		var dv: Vector3=s.station_velocity(s.destination,s.elapsed)-s.velocity
		s.tick(0.1,dv/s.max_acceleration())
	s.command("comms","dock")
	return s.phase=="docked"

func run(host) -> bool:
	var s=State.new()
	check(s.command("comms","depart").contains("interlock"),"Incomplete startup blocked")
	check(s.command("nav","load").contains("CHART"),"Navigation requires a plotted route")
	check(s.command("fuel","flow nan").contains("Unknown"),"Nonfinite CLI input rejected")
	check(s.command("nav","coords 1 wrong 3").contains("finite"),"Malformed coordinates rejected")
	prepare(s)
	check(s.loaded and s.can_depart(),"Route handoff, fuel and ATC readback complete")
	s.command("comms","code WRONG")
	check(not s.can_depart(),"Wrong ATC readback blocks departure")
	s.command("comms","code "+s.clearance)
	s.hatch_closed=false
	check(not s.can_depart(),"Open hatch blocks departure")
	s.hatch_closed=true
	s.ramp_raised=false
	check(not s.can_depart(),"Lowered ramp blocks departure")
	s.ramp_raised=true
	s.cargo_secured=false
	check(not s.can_depart(),"Unrestrained cargo blocks departure")
	s.cargo_secured=true
	s.command("fuel","flow 7")
	check(s.stale_plan() and not s.can_depart(),"Changed fuel setup requires a new calculation")
	s=State.new()
	prepare(s)
	s.fuel=10
	check(not s.can_depart(),"Arrival fuel and reserve are included")
	s=State.new()
	prepare(s)
	s.command("comms","depart")
	var p0: Vector3=s.ship_position
	var v0: Vector3=s.velocity
	var expected: Array=s.propagate(p0,v0,10)
	s.tick(10)
	check(s.velocity.length()>v0.length()*0.95 and s.ship_position.distance_to(expected[0])<5,"No thrust preserves momentum; gravity integrates consistently")
	var fuel_before: float=s.fuel
	s.tick(1,Vector3.FORWARD)
	check(s.fuel<fuel_before and s.last_thrust>0,"Manual thrust consumes fuel")
	s.angular_velocity=Vector3(0,0.2,0)
	v0=s.velocity
	var predicted: Array=s.propagate(s.ship_position,v0,1)
	s.tick(1,Vector3.ZERO,Vector3.ZERO,true)
	check(s.angular_velocity.length()<0.001 and s.velocity.distance_to(predicted[1])<0.2,"X cancels rotation without braking translation")
	s=State.new()
	prepare(s)
	s.command("comms","depart")
	check(fly_burn(s),"Manual injection establishes a coast")
	check(s.warning.contains("Safe to leave"),"Safe-to-leave confirmation follows a real trajectory match")
	var coast_state: Dictionary=s.snapshot()
	check(s.set_warp(20).contains("20x"),"Fast time available on established coast")
	s.sleep_until_warning()
	var before_rest: float=s.rest
	for i in 1000:
		if s.warp==1: break
		s.tick(0.5)
	check(s.warp==1 and not s.sleeping and absf(s.time_to_burn()-75)<0.1,"Sleep and time acceleration stop exactly before maneuver warning")
	check(s.rest>before_rest,"Bunk sleep restores rest")
	check(s.warning.contains("75 seconds"),"Advance maneuver warning delivered")
	check(s.set_warp(20).contains("needs"),"Cannot skip required burn with fast time")
	while s.phase=="coast": s.tick(0.5)
	check(s.phase=="brake","Coast hands back manual arrival burn")
	check(s.dock().contains("berth"),"Docking requires ATC approach clearance")
	check(fly_arrival(s),"Manual braking, approach and docking complete a full trip")
	check(s.dock_id==1 and s.completed_trips==1 and s.fuel>200,"Destination and fuel reserve preserved after arrival")
	print("JOURNEY finished at ",s.elapsed,"s; fuel ",s.fuel,"; phase ",s.phase)
	prepare(s,"ceres")
	check(s.can_depart(),"A return trip can be prepared from the destination")
	var recovery=State.new()
	check(recovery.restore(coast_state),"Flight snapshot restores actual position and velocity")
	check(recovery.warp==1 and not recovery.sleeping,"Loading always restores normal time")
	var invalid:=coast_state.duplicate(true)
	invalid.velocity=[0,"invalid",0]
	var old: Vector3=recovery.velocity
	check(not recovery.restore(invalid) and recovery.velocity==old,"Malformed save rejected without mutating flight")
	while recovery.phase=="coast": recovery.tick(1)
	for i in 245: recovery.tick(1)
	check(recovery.misses>0 and recovery.warning.contains("recalc"),"Missed burn warns and offers recovery")
	var previous_position: Vector3=recovery.ship_position
	recovery.recalculate()
	check(recovery.phase=="injection" and not recovery.loaded and recovery.ship_position==previous_position,"Recalculation preserves physical state and requires new NAV handoff")
	recovery.command("nav","coords "+recovery.coords_text())
	recovery.command("nav","burn %.2f" % recovery.plan.burn)
	recovery.command("nav","reserve 200")
	recovery.command("nav","load")
	check(recovery.loaded,"Recovery route can be entered")
	check(fly_burn(recovery,300),"A missed burn can be recovered with manual thrust")
	var tug=State.new()
	prepare(tug)
	tug.depart()
	tug.fuel=0
	tug.rescue()
	check(tug.phase=="docked" and tug.fuel>=600,"Fuel exhaustion has a nonpunitive tug recovery")
	for id in ["tharsis","kepler","helios"]:
		for style in ["direct","economy"]:
			var route=State.new()
			prepare(route,id,style)
			check(route.can_depart(),"%s %s route is fuel-feasible" % [id,style])
			check(route.plan.eta<1800,"%s %s nominal travel budget below 30 real minutes" % [id,style])
			var result: Array=route.propagate(route.ship_position,route.plan.velocity,route.plan.eta)
			check(result[0].distance_to(route.plan.target)<20,"%s %s numerical intercept solves to <20m" % [id,style])
			route.depart()
			check(fly_burn(route,300),"%s %s injection achievable" % [id,style])
			while route.phase=="coast": route.tick(1)
			check(fly_arrival(route),"%s %s full journey docks" % [id,style])
			print("ROUTE TIME ",id," ",style,": ",route.elapsed,"s / ",route.phase)
			check(route.elapsed<1800,"%s %s full journey under 30 real minutes" % [id,style])
			if style=="direct":
				route.command("comms","refuel")
				prepare(route,"ceres")
				check(route.can_depart(),"%s return leg is fuel-feasible" % id)
				var return_start: float=route.elapsed
				route.depart()
				check(fly_burn(route,300),"%s return injection achievable" % id)
				while route.phase=="coast": route.tick(1)
				check(fly_arrival(route),"%s round trip docks at Ceres" % id)
				check(route.elapsed-return_start<1800,"%s return under 30 real minutes" % id)
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
	host.terminal_command("engine","power on")
	host.terminal_command("fuel","mixture 2.5")
	check(host.set_ramp(true).contains("hatch"),"Physical ramp refuses to raise with an open hatch")
	host.terminal_command("engine","hatch close")
	await host.get_tree().create_timer(0.8).timeout
	check(not host.loading_module.hatch_open and not host.loading_module.hatch_moving,"ENGINE terminal closes real loading hatch")
	host.set_ramp(true)
	await host.get_tree().create_timer(1.9).timeout
	host.sync_hardware()
	check(host.flight.ramp_raised and not host.ramp_moving,"ENGINE terminal raises real ramp and waits for completion")
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
	host.terminal_command("engine","hatch open")
	await host.get_tree().create_timer(0.8).timeout
	check(await host._walk_to(Vector3(0,0,9)),"Walk through cargo into engineering with flight installed")
	check(await host._walk_to(Vector3(0,0,17)),"Walk down the deployed folding ramp onto the station berth")
	check(await host._walk_to(Vector3(0,0,9)),"Walk back up the ramp into engineering")
	print("LONGHAUL FLIGHT CHECKS ",passed," passed / ",failed," failed")
	return failed==0
