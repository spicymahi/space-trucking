extends RefCounted
## Flight in a compressed local system. Metres, seconds, kg; no velocity damping.
## Stations follow circular Kepler orbits; the ship integrates central gravity.
const PLANET := Vector3(0, 0, 500000)
const MU := 80000000000.0
const EXHAUST := 30000.0
const DRY_MASS := 18000.0
const CAPACITY := 3000.0
const RESERVE := 200.0
const WARNING_TIME := 75.0
const IDS := ["ceres", "tharsis", "kepler", "helios"]
const NAMES := ["Ceres Yard", "Tharsis Ring", "Kepler Depot", "Helios Anchorage"]
const ORIGINS := [Vector3(0,0,0), Vector3(60000,0,-80000), Vector3(-140000,15000,-260000), Vector3(360000,-15000,-520000)]
const TIMES := [240.0, 240.0, 620.0, 1050.0]
var elapsed := 0.0
var ship_position := Vector3.ZERO
var velocity := Vector3.ZERO
var attitude := Basis.IDENTITY
var angular_velocity := Vector3.ZERO
var phase := "docked"
var dock_id := 0
var destination := 1
var fuel := 2600.0
var cargo_mass := 595.0
var mixture_confirmed := true # Legacy save compatibility; mixture is automatic.
var mixture := 2.5
var flow := 6.0
var engine_on := false
var engines := [false, false]
var autopilot := false
var auto_docking := false
var arrival_hold := false
var nav_selected := false
var hold_offset := Vector3(0,0,-600)
var trail: Array[Vector3] = []
var trail_timer := 0.0
var papers: Array = []
var paper_serial := 0
var selected_paper := -1
var paper_visible := false
var coolant := 0.82
var hatch_closed := false
var ramp_raised := false
var closures_busy := false
var cargo_secured := true
var plan: Dictionary = {}
var printed_route: Dictionary = {}
var route_serial := 0
var nav_stage := -1
var loaded := false
var entered_coords := Vector3.INF
var entered_burn := -1.0
var entered_reserve := -1.0
var clearance := ""
var clearance_confirmed := false
var approach_clearance := false
var required_velocity := Vector3.ZERO
var desired_direction := Vector3.FORWARD
var acceleration := Vector3.ZERO
var last_thrust := 0.0
var warp := 1.0
var sleeping := false
var warning := ""
var warning_serial := 0
var notified := false
var solver_timer := 0.0
var matched_for := 0.0
var food := 85.0
var water := 85.0
var hygiene := 90.0
var rest := 80.0
var rations := 8
var drinks := 12
var completed_trips := 0
var misses := 0
var session_message := "Welcome aboard. Start at the CHECKLIST computer."

func _init() -> void:
	ship_position = station_position(0, 0)
	velocity = station_velocity(0, 0)

func station_position(index: int, when: float) -> Vector3:
	var radius: Vector3 = ORIGINS[index] - PLANET
	var axis := Vector3.UP
	if index >= 2: axis = Vector3(0.02,1,0.01).normalized()
	return PLANET + radius.rotated(axis, sqrt(MU / pow(radius.length(), 3)) * when)

func station_velocity(index: int, when: float) -> Vector3:
	var axis:=Vector3.UP if index<2 else Vector3(0.02,1,0.01).normalized()
	var radius: Vector3=ORIGINS[index]-PLANET
	return axis.cross(station_position(index,when)-PLANET)*sqrt(MU/pow(radius.length(),3))

func gravity(at: Vector3) -> Vector3:
	var offset := PLANET - at
	return offset.normalized() * MU / maxf(offset.length_squared(), 10000000000.0)

func propagate(at: Vector3, speed: Vector3, duration: float) -> Array[Vector3]:
	# Velocity Verlet also used for live flight; bounded steps during time acceleration.
	var count := maxi(1, ceili(duration / 5.0))
	var dt := duration / count
	var p := at
	var v := speed
	for i in count:
		var g := gravity(p)
		p += v * dt + g * dt * dt * 0.5
		v += (g + gravity(p)) * dt * 0.5
	return [p, v]

func solve_velocity(at: Vector3, target: Vector3, duration: float) -> Vector3:
	var t := maxf(duration, 5.0)
	var v := (target-at)/t - gravity(at)*t*0.5
	# Endpoint shooting converges rapidly for these short, non-singular transfers.
	for i in 7:
		var end := propagate(at,v,t)[0]
		var error := target-end
		if error.length() < 3.0: break
		v += error/t
	return v

func efficiency() -> float:
	return 1.0

func max_acceleration() -> float:
	return float(int(engines[0])+int(engines[1]))/2.0 * flow * EXHAUST * efficiency() * clampf(coolant/0.82,0.25,1) / (DRY_MASS+cargo_mass+fuel)

func plan_route(id: String, style := "direct") -> String:
	var index := IDS.find(id)
	if index < 0: return "Unknown destination. Type destinations."
	if style not in ["direct","economy"]: return "Use plot <station> direct|economy."
	if phase == "docked" and index == dock_id: return "Already docked there. Choose another station."
	if phase in ["coast","brake","approach"]: return "Use NAV recalc to replace an active transfer."
	destination = index
	nav_selected = false
	route_serial += 1
	nav_stage = -1
	var leg_time: float = maxf(TIMES[index], TIMES[dock_id] if phase=="docked" else 150+ship_position.distance_to(station_position(index,elapsed))/650)
	var duration: float = minf(1050,leg_time) * (1.23 if style=="economy" else 1.0)
	# Budget acceleration, then a coast to the arrival braking waypoint.
	var eta := elapsed + duration + 60.0
	var target := station_position(index,eta)
	var v := solve_velocity(ship_position,target,duration+60)
	var arrival_v := propagate(ship_position,v,duration+60)[1]
	var arrival_dv := (arrival_v-station_velocity(index,eta)).length()
	var brake_distance := arrival_dv*arrival_dv/(2*maxf(planning_acceleration(),1.0)) + arrival_dv*12 + 1000
	var approach_dir := (arrival_v-station_velocity(index,eta)).normalized()
	target -= approach_dir * brake_distance
	v = solve_velocity(ship_position,target,duration+60)
	arrival_v = propagate(ship_position,v,duration+60)[1]
	var dv := (v-velocity).length() + (arrival_v-station_velocity(index,eta)).length() + 70
	var estimate := dv*(DRY_MASS+cargo_mass+fuel)/(EXHAUST*efficiency()*clampf(coolant/0.82,0.25,1))
	plan = {"destination":index,"style":style,"eta":eta,"target":target,"velocity":v,"fuel":ceilf(estimate*1.12+30),"burn":flow,"reserve":RESERVE,"mixture":mixture,"mass":cargo_mass,"coolant":coolant,"coast":duration}
	loaded = false
	entered_coords = Vector3.INF
	entered_burn = -1
	entered_reserve = -1
	notified = false
	return route_card()

func coords_text() -> String:
	if plan.is_empty(): return "---"
	var p: Vector3 = plan.target / 1000.0
	return "%.3f %.3f %.3f" % [p.x,p.y,p.z]

func route_card() -> String:
	if plan.is_empty(): return "NO ROUTE SELECTED\nStation directory available: stations"
	return "TO %s / %s\nCOORDS %s km\nBURN %.2f kg/s | SPARE FUEL %.0f kg\nTrip estimate %.0f kg + %.0f kg spare\nTransfer ~%.0f min + departure / approach\nSpare fuel covers docking and corrections.\nRoute sheet available at this printer." % [NAMES[destination],plan.style,coords_text(),plan.burn,plan.reserve,plan.fuel,plan.reserve,(plan.coast+120)/60]

func stale_plan() -> bool:
	return not plan.is_empty() and (absf(plan.burn-flow)>0.01 or absf(plan.mass-cargo_mass)>0.1 or absf(plan.coolant-coolant)>0.01)

func load_route() -> String:
	if plan.is_empty(): return "Get a route from CHART first."
	if phase not in ["docked","departure","injection"]: return "Use recalc for an active journey."
	if stale_plan(): return "Ship setup changed. Replot on CHART for a fresh fuel estimate."
	if entered_coords.distance_to(plan.target) > 2.0: return "Coordinates differ from CHART. Use km, including minus signs."
	if absf(entered_burn-plan.burn)>0.01: return "Burn rate differs from CHART. Enter burn <kg/s>."
	if absf(entered_reserve-plan.reserve)>0.1: return "Enter the reserve shown on CHART."
	if fuel < plan.fuel+plan.reserve: return "Insufficient fuel including arrival and reserve. COMMS: refuel."
	loaded = true
	required_velocity = plan.velocity
	nav_stage = -1
	nav_selected = true
	return "Route loaded / destination selected: " + NAMES[destination]

func checklist() -> String:
	return "DEPARTURE / LIVE READINESS\n[%s] PORT / STARBOARD ENGINES\n[%s] ROUTE ENTERED AND FUEL CHECKED\n[%s] ATC TAKEOFF CODE CONFIRMED\n[%s] CARGO HATCH SEALED\n[%s] LOADING RAMP RAISED\n[%s] CARGO CLAMPS SECURED\n[%s] COOLANT AVAILABLE\n%s\nprint: paper command checklist" % [mark(engines[0] and engines[1]),mark(loaded and not stale_plan() and fuel>=plan.get("fuel",INF)+RESERVE),mark(clearance_confirmed),mark(hatch_closed and not closures_busy),mark(ramp_raised and not closures_busy),mark(cargo_secured),mark(coolant>0),"READY FOR TAKEOFF" if can_depart() else "DEPARTURE LOCKED / CHECK OPEN ITEMS"]

func mark(value: bool) -> String:
	return "OK" if value else "--"

func can_depart() -> bool:
	return engines[0] and engines[1] and loaded and not stale_plan() and clearance_confirmed and hatch_closed and ramp_raised and not closures_busy and cargo_secured and coolant>0 and fuel>=plan.get("fuel",INF)+RESERVE

func depart() -> String:
	if phase != "docked": return "Already in flight."
	if not can_depart(): return "Departure interlock. Review CHECKLIST readiness.\n"+checklist()
	phase="departure"
	autopilot=false
	arrival_hold=false
	warp=1
	trail.clear()
	alert("Berth released. Fly forward through the green corridor. NAV available beyond 300 m.")
	return warning

func alert(message: String) -> void:
	warning = message
	warning_serial += 1
	session_message = message

func time_to_burn() -> float:
	return maxf(0, float(plan.get("eta",elapsed))-elapsed)

func guidance() -> Dictionary:
	var dv := Vector3.ZERO
	if phase in ["departure","injection"]: dv = required_velocity-velocity
	elif phase == "brake": dv = station_velocity(destination,elapsed)-velocity
	elif phase == "approach":
		var relative := station_position(destination,elapsed)-ship_position
		var wanted := relative.normalized()*minf(40,maxf(0,relative.length()-5)*0.09)
		dv = station_velocity(destination,elapsed)+wanted-velocity
	var direction := dv.normalized() if dv.length()>0.5 else -attitude.z
	if phase in ["departure","injection"] and dv.length()<3:
		direction=required_velocity.normalized()
	if phase=="approach" and ship_position.distance_to(station_position(destination,elapsed))<20 and (velocity-station_velocity(destination,elapsed)).length()<2:
		direction=Vector3.FORWARD
	var local := attitude.inverse()*direction
	var yaw := rad_to_deg(atan2(-local.x,-local.z))
	var pitch_error := rad_to_deg(atan2(local.y,Vector2(local.x,local.z).length()))
	return {"dv":dv,"direction":direction,"yaw":yaw,"pitch":pitch_error,"seconds":dv.length()/maxf(max_acceleration(),0.1)}

func set_warp(value: float) -> String:
	if value not in [1.0,5.0,20.0]: return "Use warp 1, 5 or 20."
	if value>1 and (not autopilot or phase not in ["injection","coast","brake"]): return "Fast time requires NAV automatic transfer."
	warp=value
	return "Time rate %dx. Normal time resumes at station arrival." % int(warp)

func sleep_until_warning() -> String:
	var result:=set_warp(20)
	if warp==20:
		sleeping=true
		return "Resting. NAV handles burns and wakes you at station arrival."
	return result

func recalculate() -> String:
	if phase=="docked": return "Choose a route at CHART while docked."
	if plan.is_empty(): return "No destination selected."
	if phase=="approach": return "At destination. Use manual approach or docking assistance."
	autopilot=false
	phase="injection"
	plan_route(IDS[destination],str(plan.get("style","direct")))
	entered_coords=plan.target
	entered_burn=plan.burn
	entered_reserve=plan.reserve
	load_route()
	if not loaded: return "Recovery fuel insufficient. COMMS rescue available."
	return engage_navigation()

func tick(delta: float, thrust := Vector3.ZERO, rotation_input := Vector3.ZERO, stop_rotation := false) -> void:
	if phase=="docked": return
	if thrust.length()>0 or rotation_input.length()>0:
		if autopilot or auto_docking or arrival_hold: release_controls()
		warp=1
		sleeping=false
	var dt:=delta*warp
	var count:=maxi(1,ceili(dt/0.2))
	var simulated:=0.0
	var was_sleeping:=sleeping
	for i in count:
		var old_phase:=phase
		_step(dt/count,thrust,rotation_input,stop_rotation)
		simulated+=dt/count
		if (old_phase!="approach" and phase=="approach") or phase=="docked": break
	food=maxf(0,food-simulated*0.009)
	water=maxf(0,water-simulated*0.014)
	hygiene=maxf(0,hygiene-simulated*0.007)
	rest=clampf(rest+simulated*(0.10 if was_sleeping else -0.008),0,100)

func _step(dt: float, thrust: Vector3, rotation_input: Vector3, stop_rotation: bool) -> void:
	if (autopilot or auto_docking or arrival_hold) and (not engines[0] or not engines[1] or coolant<=0 or fuel<=0):
		release_controls()
		alert("NAV interrupted: propulsion unavailable. Restore engines / coolant; COMMS rescue available.")
	angular_velocity=(angular_velocity+rotation_input*0.38*dt).limit_length(0.65)
	if stop_rotation: angular_velocity=angular_velocity.move_toward(Vector3.ZERO,1.8*dt)
	if angular_velocity.length()>0.00001:
		attitude=(attitude*Basis(angular_velocity.normalized(),angular_velocity.length()*dt)).orthonormalized()
	var applied:=thrust.limit_length(1)
	if autopilot or auto_docking or arrival_hold:
		applied=automatic_thrust(dt)
	if not engine_on or coolant<=0 or fuel<=0: applied=Vector3.ZERO
	last_thrust=applied.length()
	acceleration=attitude*applied*max_acceleration()
	var use:=flow*last_thrust*dt*float(int(engines[0])+int(engines[1]))/2.0
	if use>fuel: acceleration*=fuel/use
	fuel=maxf(0,fuel-use)
	var g:=gravity(ship_position)
	ship_position+=velocity*dt+(g+acceleration)*dt*dt*0.5
	velocity+=(g+gravity(ship_position))*dt*0.5+acceleration*dt
	elapsed+=dt
	trail_timer+=dt
	if trail_timer>=2:
		trail_timer=0
		trail.append(ship_position)
		if trail.size()>1200: trail.pop_front()
	if autopilot:
		if phase in ["injection","coast"]:
			if phase=="injection" and (required_velocity-velocity).length()<1.5:
				phase="coast"
			if time_to_burn()<=WARNING_TIME and not notified:
				notified=true
				alert("Arrival braking in 75 seconds. NAV will perform the maneuver.")
			if time_to_burn()<=0:
				phase="brake"
				alert("NAV performing arrival braking. Station approach follows.")
		elif phase=="brake":
			var error:=ship_position.distance_to(station_position(destination,elapsed)+hold_offset)
			if error<8 and relative_speed()<0.5:
				phase="approach"
				autopilot=false
				arrival_hold=true
				warp=1
				sleeping=false
				alert("Station arrival. Holding 600 m from the berth. Return when ready; manual approach or COMMS autodock.")
	if auto_docking and station_range()<12 and relative_speed()<0.5:
		if (-attitude.z).dot(Vector3.FORWARD)>cos(deg_to_rad(5)):
			dock()

func dock() -> String:
	if phase not in ["approach","brake"]: return "Finish the transfer before docking."
	if not approach_clearance: return "COMMS: approach to request a berth."
	var d := ship_position.distance_to(station_position(destination,elapsed))
	var s := (velocity-station_velocity(destination,elapsed)).length()
	if d>20 or s>2: return "Berth capture requires <20m and <2m/s relative. Now %.0fm / %.1fm/s." % [d,s]
	if (-attitude.z).dot(Vector3.FORWARD)<cos(deg_to_rad(8)) or angular_velocity.length()>0.02: return "Align berth heading 000 / pitch 000 and stop rotation [X]."
	dock_id=destination
	autopilot=false
	auto_docking=false
	arrival_hold=false
	sleeping=false
	phase="docked"
	ship_position=station_position(dock_id,elapsed)
	velocity=station_velocity(dock_id,elapsed)
	attitude=Basis.IDENTITY
	angular_velocity=Vector3.ZERO
	completed_trips+=1
	loaded=false
	clearance=""
	clearance_confirmed=false
	approach_clearance=false
	warp=1
	alert("Docked at %s. Engines safe; ramp can be lowered. No deadline." % NAMES[dock_id])
	return warning

func rescue() -> String:
	release_controls()
	phase="docked"
	ship_position=station_position(dock_id,elapsed)
	velocity=station_velocity(dock_id,elapsed)
	attitude=Basis.IDENTITY
	angular_velocity=Vector3.ZERO
	fuel=maxf(fuel,600)
	loaded=false
	clearance_confirmed=false
	approach_clearance=false
	warp=1
	sleeping=false
	alert("Station tug returned you to %s. Refuel and replot when ready." % NAMES[dock_id])
	return warning

func command(terminal: String, line: String) -> String:
	var words := line.strip_edges().to_lower().split(" ",false)
	if words.is_empty(): return ""
	var op := words[0]
	if op=="papers": return paper_list()
	if op=="paper" and words.size()==2:
		if words[1]=="hide":
			paper_visible=false
			return "Paper stowed."
		if words[1].is_valid_int(): return select_paper(int(words[1]))
	if op=="discard" and words.size()==2: return discard_paper(words[1])
	if op in ["help","next"]:
		return command_reference(terminal)
	if op=="commands": return command_reference(terminal)
	if op=="status": return status(terminal)
	if op=="checklist": return checklist()
	if terminal in ["chart","nav"] and op in ["stations","destinations"]:
		return station_directory()
	match terminal:
		"chart":
			if op=="print": return print_route()
			if op=="plot" and words.size() in [2,3]:
				var previous_revision:=route_serial
				var result := plan_route(words[1],words[2] if words.size()==3 else "direct")
				return result + ("\nNext: print  (your paper route sheet)" if route_serial!=previous_revision else "")
			if op=="route": return route_card()
		"nav":
			if op=="coords" and words.size()==4:
				for i in range(1,4):
					if not valid_number(words[i]): return "Use three finite coordinates in km."
				entered_coords=Vector3(float(words[1]),float(words[2]),float(words[3]))*1000
				return "Coordinates recorded."
			if op in ["burn","reserve"] and words.size()==2 and valid_number(words[1]):
				if op=="burn": entered_burn=float(words[1])
				else: entered_reserve=float(words[1])
				return "%s recorded: %s" % [op,words[1]]
			if op=="load": return load_route()
			if op=="recalc": return recalculate()
			if op=="engage": return engage_navigation()
			if op=="manual":
				release_controls()
				return "Manual controls. Momentum is preserved."
			if op=="warp" and words.size()==2 and valid_number(words[1]): return set_warp(float(words[1]))
		"checklist":
			if op=="print": return print_checklist()
		"engine":
			if op in ["port","starboard"] and words.size()==2 and words[1] in ["on","off"]:
				engines[0 if op=="port" else 1]=words[1]=="on"
				engine_on=engines[0] or engines[1]
				return engine_diagram()
		"comms":
			if op=="request":
				if phase!="docked": return "Use approach for arrival clearance."
				clearance="%s-%03d" % [IDS[dock_id].left(3).to_upper(),100+completed_trips%900]
				return "ATC: takeoff code %s. Read back: code %s\nNo expiry; depart when your ship is ready." % [clearance,clearance]
			if op=="code" and words.size()==2:
				clearance_confirmed=not clearance.is_empty() and words[1].to_upper()==clearance
				return "ATC readback accepted. Clearance remains valid." if clearance_confirmed else "Incorrect code. COMMS: request"
			if op=="depart": return depart()
			if op=="approach":
				if phase not in ["brake","approach"]: return "Request a berth during arrival."
				approach_clearance=true
				return "Berth K-01 reserved. Capture <20m, <2m/s. Heading 000 / pitch 000. No hurry."
			if op=="dock": return dock()
			if op=="autodock": return engage_docking()
			if op=="rescue": return rescue()
			if op=="refuel":
				if phase!="docked": return "Refuel at a station; rescue is available."
				fuel=CAPACITY
				return "Station test supply: tanks filled to 3000 kg."
	var destination_terminal: String={"port":"engine","starboard":"engine","hatch":"checklist","ramp":"checklist","request":"comms","code":"comms","depart":"comms","print":"chart"}.get(op,"")
	if op=="plot" and words.size()>1: destination_terminal="chart"
	if not destination_terminal.is_empty() and destination_terminal!=terminal:
		return "That command belongs at %s.\nType: go %s\nThen: %s" % [destination_terminal.to_upper(),destination_terminal,line]
	return "Unknown or incomplete command. Type commands for syntax."

func valid_number(value: String) -> bool:
	return value.is_valid_float() and is_finite(float(value)) and absf(float(value))<10000000

func station_directory() -> String:
	var rows: Array[String] = ["STATION DIRECTORY / ROUTE IDs"]
	for i in IDS.size():
		var here := " [HERE]" if phase=="docked" and i==dock_id else ""
		rows.append("%s / %s%s" % [IDS[i].to_upper(),NAMES[i],here])
	rows.append("Plan at CHART: plot <id> direct|economy")
	rows.append("Example: plot %s direct" % IDS[(dock_id+1)%IDS.size()])
	rows.append("Then copy the route coordinates into NAV.")
	return "\n".join(rows)

func command_reference(terminal: String) -> String:
	var reference: String={
		"chart":"stations | plot <station> direct|economy\nroute | print | map",
		"nav":"coords <x> <y> <z>  (km)\nburn <kg/s> | reserve <kg> | load\nengage | manual | recalc | warp 1|5|20\nstations | status",
		"checklist":"status | print\nhatch close|open | ramp raise|lower\nPhysical cargo clamps must also be secured.",
		"fuel":"status  (fuel and spare-fuel monitor)",
		"engine":"port on|off\nstarboard on|off\nstatus  (live engine diagram)",
		"comms":"request | code <takeoff-code> | depart\napproach | dock | autodock\nrefuel | service | rescue | save | load",
		"map":"Live journey map / automatic approach zoom",
		"distance":"Distance to the destination loaded at NAV"
	}.get(terminal,"")
	return reference+"\n\npapers | paper <id>|hide | discard <id>|all\ngo <terminal> | clear | help"

func status(terminal: String) -> String:
	match terminal:
		"checklist": return checklist()
		"chart": return route_card()
		"fuel": return "FUEL %.0f / %.0f kg\nSPARE FUEL %.0f kg\nCURRENT BURN %.2f kg/s\n\nSpare fuel is kept for docking\nand unexpected corrections.\nCoolant %.0f%%" % [fuel,CAPACITY,RESERVE,flow*last_thrust,coolant*100]
		"engine": return engine_diagram()
		"comms": return "%s\n%s\nTAKEOFF CODE: %s\nARRIVAL BERTH: %s\nCompleted journeys: %d" % [NAMES[dock_id],phase.to_upper(),clearance if not clearance.is_empty() else "NOT REQUESTED","RESERVED" if approach_clearance else "NOT REQUESTED",completed_trips]
	if phase=="docked": return "NAV / BERTH K-01\n%s\n\nCoordinates: %s\nBurn: %s / spare fuel: %s\nDeparture readiness at CHECKLIST." % ["ROUTE LOADED" if loaded else "AWAITING ROUTE ENTRY", "ACCEPTED" if not plan.is_empty() and entered_coords.distance_to(plan.target)<2 else "NOT ENTERED",str(entered_burn) if entered_burn>=0 else "--",str(entered_reserve) if entered_reserve>=0 else "--"]
	if phase=="departure": return "MANUAL DEPARTURE\nSTATION RANGE %.0f m\nRELATIVE SPEED %.1f m/s\nCLEARANCE: %s\n\n%s" % [ship_position.distance_to(station_position(dock_id,elapsed)),(velocity-station_velocity(dock_id,elapsed)).length(),"CLEAR" if safe_departure() else "INSIDE STATION ZONE","SAFE TO ENGAGE NAVIGATION" if safe_departure() else "FOLLOW GREEN CORRIDOR / 300 m"]
	if phase=="approach":
		var g:=guidance()
		return "%s\nRANGE %.0f m / REL SPEED %.1f m/s\nYAW %+.1f / PITCH %+.1f\nBERTH CAPTURE <20 m / <2 m/s\nAUTODOCK <1000 m / <15 m/s\n%s" % ["AUTODOCK" if auto_docking else ("ARRIVAL HOLD" if arrival_hold else "MANUAL APPROACH"),station_range(),relative_speed(),g.yaw,g.pitch,"TAKE CONTROLS WHEN READY" if arrival_hold else "BERTH HEADING 000 / X STOPS SPIN"]
	return "%s / %s\n%s\nARRIVAL BRAKING IN %.0f s\nDESTINATION RANGE %.1f km\nTIME %dx / FUEL %.0f kg\n%s" % [NAMES[destination],phase.to_upper(),"NAV AUTOMATIC TRANSFER" if autopilot else "MANUAL / NAV DISENGAGED",time_to_burn(),station_range()/1000,int(warp),fuel,"SAFE TO LEAVE CONTROLS" if autopilot else "NAV engage TO RESUME"]

func snapshot() -> Dictionary:
	var result := {"version":1}
	for key in ["autopilot","auto_docking","arrival_hold","nav_selected","paper_serial","selected_paper","paper_visible","route_serial","nav_stage","elapsed","phase","dock_id","destination","fuel","cargo_mass","mixture_confirmed","mixture","flow","engine_on","coolant","hatch_closed","ramp_raised","cargo_secured","loaded","entered_burn","entered_reserve","clearance","clearance_confirmed","approach_clearance","notified","food","water","hygiene","rest","rations","drinks","completed_trips","misses","warning","session_message"]:
		result[key]=get(key)
	for key in ["ship_position","velocity","angular_velocity","required_velocity"]:
		var v: Vector3 = get(key)
		result[key]=[v.x,v.y,v.z]
	result["attitude"]=[attitude.x.x,attitude.x.y,attitude.x.z,attitude.y.x,attitude.y.y,attitude.y.z,attitude.z.x,attitude.z.y,attitude.z.z]
	result["engines"]=engines.duplicate()
	result["papers"]=papers.duplicate(true)
	result["trail"]=[]
	for point in trail: result.trail.append([point.x,point.y,point.z])
	result["printed_route"]=printed_route.duplicate(true)
	result["entered_coords"]=[entered_coords.x,entered_coords.y,entered_coords.z] if entered_coords.is_finite() else null
	result["plan"]=plan.duplicate(true)
	if not plan.is_empty():
		for key in ["target","velocity"]:
			var v: Vector3=plan[key]
			result.plan[key]=[v.x,v.y,v.z]
	result["flight_revision"]=2
	return result

func restore(data: Dictionary) -> bool:
	if data.get("version")!=1: return false
	data=data.duplicate(true)
	for key in ["printed_route","entered_coords","route_serial","nav_stage"]:
		if not data.has(key): data[key]={"printed_route":{},"entered_coords":null,"route_serial":0,"nav_stage":-1}[key]
	var defaults := snapshot()
	for key in ["autopilot","auto_docking","arrival_hold","nav_selected","paper_serial","selected_paper","paper_visible","papers","trail","engines"]:
		if not data.has(key): data[key]=defaults[key]
	if not data.has("flight_revision"):
		data.engines=[data.get("engine_on",false),data.get("engine_on",false)]
		data.nav_selected=data.get("loaded",false)
	data.flight_revision=2
	for key in defaults:
		if not data.has(key): return false
	# Validate into a candidate before changing the live model.
	if data.phase not in ["docked","departure","injection","coast","brake","approach"]: return false
	if not valid_number(str(data.dock_id)) or not valid_number(str(data.destination)): return false
	if data.dock_id!=int(data.dock_id) or data.destination!=int(data.destination) or int(data.dock_id) not in [0,1,2,3] or int(data.destination) not in [0,1,2,3]: return false
	for key in defaults:
		if defaults[key] is float or defaults[key] is int:
			if not (data[key] is float or data[key] is int) or not is_finite(float(data[key])): return false
		elif defaults[key] is bool:
			if not data[key] is bool: return false
		elif defaults[key] is String:
			if not data[key] is String: return false
	for key in ["ship_position","velocity","angular_velocity","required_velocity","attitude"]:
		if not data[key] is Array or data[key].size()!=(9 if key=="attitude" else 3): return false
		for v in data[key]:
			if not (v is float or v is int) or not is_finite(float(v)): return false
	if not data.engines is Array or data.engines.size()!=2: return false
	for value in data.engines:
		if not value is bool: return false
	if not data.papers is Array or data.papers.size()>12: return false
	var paper_ids: Array=[]
	for sheet in data.papers:
		if not sheet is Dictionary or not sheet.get("kind") in ["route","checklist"]: return false
		if not (sheet.get("number") is int or sheet.get("number") is float) or sheet.number<1 or sheet.number!=int(sheet.number) or sheet.number>data.paper_serial or sheet.number in paper_ids: return false
		paper_ids.append(sheet.number)
		if not sheet.get("data") is Dictionary: return false
		if sheet.kind=="route" and (sheet.data.is_empty() or not valid_paper(sheet.data)): return false
	if not data.trail is Array or data.trail.size()>1200: return false
	for point in data.trail:
		if not point is Array or point.size()!=3: return false
		for v in point:
			if not (v is int or v is float) or not is_finite(float(v)): return false
	if data.autopilot and (not data.loaded or data.phase not in ["injection","coast","brake"]): return false
	if (data.auto_docking or data.arrival_hold) and data.phase!="approach": return false
	if data.auto_docking and not data.approach_clearance: return false
	if not data.printed_route is Dictionary or not valid_paper(data.printed_route): return false
	if int(data.nav_stage) not in [-1,0,1,2,3] or data.route_serial<0: return false
	if data.entered_coords!=null:
		if not data.entered_coords is Array or data.entered_coords.size()!=3: return false
		for v in data.entered_coords:
			if not (v is int or v is float) or not is_finite(float(v)): return false
	if not data.plan is Dictionary: return false
	if not data.plan.is_empty():
		for key in ["target","velocity"]:
			if not data.plan.get(key) is Array or data.plan[key].size()!=3: return false
			for v in data.plan[key]:
				if not (v is float or v is int) or not is_finite(float(v)): return false
		for key in ["destination","eta","fuel","burn","reserve","mixture","mass","coolant","coast"]:
			if not (data.plan.get(key) is float or data.plan.get(key) is int) or not is_finite(float(data.plan[key])): return false
		if data.plan.get("style") not in ["direct","economy"]: return false
	elif data.loaded or data.phase in ["coast","brake","approach"]: return false
	if data.fuel<0 or data.fuel>CAPACITY or data.flow<3 or data.flow>8 or data.mixture<1.5 or data.mixture>3.5: return false
	for key in defaults:
		if key in ["version","flight_revision","trail","ship_position","velocity","angular_velocity","required_velocity","attitude","plan","entered_coords"]: continue
		set(key,data[key])
	for key in ["ship_position","velocity","angular_velocity","required_velocity"]:
		set(key,Vector3(data[key][0],data[key][1],data[key][2]))
	var a: Array=data.attitude
	attitude=Basis(Vector3(a[0],a[1],a[2]),Vector3(a[3],a[4],a[5]),Vector3(a[6],a[7],a[8])).orthonormalized()
	plan=data.plan.duplicate(true)
	if not plan.is_empty():
		for key in ["target","velocity"]: plan[key]=Vector3(plan[key][0],plan[key][1],plan[key][2])
	engine_on=engines[0] or engines[1]
	mixture=2.5
	mixture_confirmed=true
	trail.clear()
	for point in data.trail: trail.append(Vector3(point[0],point[1],point[2]))
	warp=1
	sleeping=false
	solver_timer=0
	matched_for=0
	nav_stage=-1
	entered_coords=Vector3(data.entered_coords[0],data.entered_coords[1],data.entered_coords[2]) if data.entered_coords!=null else (plan.get("target",Vector3.INF) if loaded else Vector3.INF)
	# Older saves used a live departure epoch. Refresh once when migrating at berth.
	if phase=="docked" and not plan.is_empty() and plan.eta-elapsed<plan.coast+59:
		plan_route(IDS[destination],plan.style)
	return true

func print_route() -> String:
	if plan.is_empty(): return "No route to print. Choose a station at CHART."
	if stale_plan(): return "Ship setup changed. Replot before printing a fresh sheet."
	printed_route={"revision":route_serial,"station":NAMES[destination],"id":IDS[destination],"style":str(plan.style),"coords":coords_text(),"burn":float(plan.burn),"reserve":float(plan.reserve),"fuel":float(plan.fuel),"coast":float(plan.coast)}
	return add_paper("route",printed_route)

func paper_current() -> bool:
	return not printed_route.is_empty() and int(printed_route.revision)==route_serial and printed_route.coords==coords_text() and not stale_plan()

func valid_paper(paper: Dictionary) -> bool:
	if paper.is_empty(): return true
	for key in ["station","id","style","coords"]:
		if not paper.get(key) is String: return false
	for key in ["revision","burn","reserve","fuel","coast"]:
		if not (paper.get(key) is float or paper.get(key) is int) or not is_finite(float(paper[key])): return false
	var parts: PackedStringArray=paper.coords.split(" ",false)
	if parts.size()!=3: return false
	for part in parts:
		if not valid_number(part): return false
	return paper.id in IDS and paper.style in ["direct","economy"]

func planning_acceleration() -> float:
	return flow*EXHAUST*clampf(coolant/0.82,0.25,1)/(DRY_MASS+cargo_mass+fuel)

func station_range() -> float:
	return ship_position.distance_to(station_position(destination,elapsed))

func relative_speed() -> float:
	return (velocity-station_velocity(destination,elapsed)).length()

func safe_departure() -> bool:
	var relative:=ship_position-station_position(dock_id,elapsed)
	return (relative.z < -300 and absf(relative.x)<500 and absf(relative.y)<500) or relative.length()>1000

func engage_navigation() -> String:
	if phase=="docked": return "Docked. Fly out through the departure corridor first."
	if phase=="approach": return "At destination. Use manual approach or COMMS autodock."
	if not loaded: return "No validated route loaded."
	if autopilot: return "NAV already engaged. Safe to leave controls."
	if phase=="departure" and not safe_departure(): return "Inside station zone. Clear the green corridor beyond 300 m."
	if not engines[0] or not engines[1] or coolant<=0: return "NAV requires both engines and available coolant."
	if fuel<RESERVE+30: return "Insufficient maneuver fuel. COMMS rescue available."
	# Rebase the planned intercept to departure time. Coordinates are still entered manually;
	# station motion and delayed launches are handled by the navigation computer.
	var old_eta: float=plan.eta
	plan.eta=elapsed+plan.coast+60
	plan.target+=station_position(destination,plan.eta)-station_position(destination,old_eta)
	required_velocity=solve_velocity(ship_position,plan.target,plan.eta-elapsed)
	plan.velocity=required_velocity
	autopilot=true
	auto_docking=false
	arrival_hold=false
	phase="injection"
	notified=false
	solver_timer=0
	alert("NAV engaged. Automatic alignment, burns and arrival braking. Safe to leave controls.")
	return warning

func release_controls() -> void:
	autopilot=false
	auto_docking=false
	arrival_hold=false
	warp=1
	sleeping=false

func engage_docking() -> String:
	if phase!="approach": return "Docking assistance is available during station approach."
	if not approach_clearance: return "Request arrival clearance with COMMS approach."
	if station_range()>1000 or relative_speed()>15: return "Autodock requires <1000 m and <15 m/s relative."
	if not engines[0] or not engines[1] or coolant<=0 or fuel<20: return "Autodock requires both engines, coolant and 20 kg fuel."
	arrival_hold=false
	auto_docking=true
	warp=1
	alert("Docking assistance engaged. Manual thrust cancels assistance.")
	return warning

func automatic_thrust(dt: float) -> Vector3:
	var dv:=Vector3.ZERO
	if autopilot and phase in ["injection","coast"]:
		solver_timer-=dt
		if solver_timer<=0:
			required_velocity=solve_velocity(ship_position,plan.target,maxf(5,plan.eta-elapsed))
			solver_timer=1.0
		dv=required_velocity-velocity
	else:
		var target:=station_position(destination,elapsed)+(Vector3.ZERO if auto_docking else hold_offset)
		var offset:=target-ship_position
		var max_speed:=12.0 if auto_docking else 400.0
		var closing:=minf(max_speed,minf(offset.length()*0.16,sqrt(2*maxf(max_acceleration(),0.1)*0.50*offset.length())))
		required_velocity=station_velocity(destination,elapsed)+offset.normalized()*closing
		dv=required_velocity-velocity
	var wanted_direction:=dv.normalized() if dv.length()>1 else -attitude.z
	if arrival_hold: wanted_direction=(station_position(destination,elapsed)-ship_position).normalized()
	if auto_docking: wanted_direction=Vector3.FORWARD
	if wanted_direction.length()>0.1:
		var up:=Vector3.UP if absf(wanted_direction.dot(Vector3.UP))<0.99 else Vector3.RIGHT
		attitude=attitude.slerp(Basis.looking_at(wanted_direction,up),minf(1,dt*0.9)).orthonormalized()
	angular_velocity=Vector3.ZERO
	# The six-axis thrusters apply real acceleration and use the same fuel model as manual flight.
	var desired_acceleration:=dv/1.4
	if arrival_hold or auto_docking or phase=="brake":
		desired_acceleration+=gravity(station_position(destination,elapsed))-gravity(ship_position)
	return (attitude.inverse()*desired_acceleration/maxf(max_acceleration(),0.01)).limit_length(1)

func engine_diagram() -> String:
	return "       LONGHAUL / PROPULSION\n              / NOSE \\\n         +----+----+\n         |   K-01  |\n    +----+         +----+\n    |PORT|         |STBD|\n    | %s |         | %s |\n    +----+---------+----+\n\nPORT: %s     STARBOARD: %s\nCOOLANT %02d%%  /  THRUST %02d%%" % ["ON" if engines[0] else "--","ON" if engines[1] else "--","ON" if engines[0] else "OFF","ON" if engines[1] else "OFF",coolant*100,last_thrust*100]

func print_checklist() -> String:
	return add_paper("checklist",{})

func add_paper(kind: String, payload: Dictionary) -> String:
	if papers.size()>=12: return "Paper rack full (12). Discard unwanted sheets first."
	paper_serial+=1
	papers.append({"number":paper_serial,"kind":kind,"data":payload.duplicate(true)})
	selected_paper=paper_serial
	paper_visible=true
	return "SHEET %02d PRINTED / %s\nPaper retained in the cockpit rack.\npapers: list sheets | paper <id>: read\ndiscard <id>: recycle a sheet\nOutside terminals: P read/stow, Tab next, Delete discard." % [paper_serial,kind.to_upper()]

func paper_list() -> String:
	var rows: Array[String]=["COCKPIT PAPER RACK"]
	for sheet in papers:
		rows.append("%02d / %s%s" % [sheet.number,str(sheet.kind).to_upper()," / SELECTED" if int(sheet.number)==selected_paper else ""])
	rows.append("paper <id> / paper hide / discard <id>|all")
	return "\n".join(rows)

func current_paper() -> Dictionary:
	for sheet in papers:
		if int(sheet.number)==selected_paper: return sheet
	return {}

func select_paper(number: int) -> String:
	for sheet in papers:
		if int(sheet.number)==number:
			selected_paper=number
			paper_visible=true
			return "Reading sheet %02d." % number
	return "No sheet with that number."

func cycle_paper() -> void:
	if papers.is_empty(): return
	for i in papers.size():
		if int(papers[i].number)==selected_paper:
			selected_paper=int(papers[(i+1)%papers.size()].number)
			return
	selected_paper=int(papers[0].number)

func discard_paper(id: String) -> String:
	if id=="all": papers.clear()
	elif id.is_valid_int():
		var found:=false
		for i in range(papers.size()-1,-1,-1):
			if int(papers[i].number)==int(id):
				papers.remove_at(i)
				found=true
		if not found: return "No sheet with that number."
	else: return "Use discard <id> or discard all."
	if current_paper().is_empty(): selected_paper=-1 if papers.is_empty() else int(papers.back().number)
	if papers.is_empty(): paper_visible=false
	return "Paper recycled. Loaded navigation remains in memory."
