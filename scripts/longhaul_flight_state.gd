extends RefCounted
## Flight in a compressed local system. Metres, seconds, kg; no velocity damping.
## Stations follow circular Kepler orbits; the ship integrates central gravity.
const System = preload("res://scripts/longhaul_system.gd")
const PLANET := System.PLANET
const MU := System.MU
const EXHAUST := 30000.0
const DRY_MASS := 18000.0
const CAPACITY := 3000.0
const RESERVE := 200.0
const WARNING_TIME := 90.0
const DEPARTURE_ALLOWANCE := 145.0
const ARRIVAL_ALLOWANCE := 40.0
const BERTH_FORWARD := Vector3.BACK # The pad entrance is on -Z; arrive nose-first toward +Z.
const IDS := System.IDS
const NAMES := System.NAMES
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
var docking_stage := ""
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
	return System.station_position(index,when)

func station_velocity(index: int, when: float) -> Vector3:
	return System.station_velocity(index,when)

func gravity(at: Vector3) -> Vector3:
	var offset := PLANET - at
	return offset.normalized() * MU / maxf(offset.length_squared(), System.PLANET_RADIUS*System.PLANET_RADIUS)

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

func _smooth_leg(leg: Dictionary, when: float) -> Dictionary:
	var duration: float=leg.duration
	var u:=clampf((when-float(leg.start))/duration,0,1)
	var u2:=u*u
	var u3:=u2*u
	var u4:=u3*u
	var u5:=u4*u
	var s:=10*u3-15*u4+6*u5
	var sd:=30*u2-60*u3+30*u4
	var sdd:=60*u-180*u2+120*u3
	var h0:=u-6*u3+8*u4-3*u5
	var h1:=-4*u3+7*u4-3*u5
	var h0d:=1-18*u2+32*u3-15*u4
	var h1d:=-12*u2+28*u3-15*u4
	var h0dd:=-36*u+96*u2-60*u3
	var h1dd:=-24*u+84*u2-60*u3
	var span: Vector3=leg.to-leg.from
	var result: Dictionary={"position":leg.from+span*s+leg.v0*duration*h0+leg.v1*duration*h1,"velocity":span*sd/duration+leg.v0*h0d+leg.v1*h1d,"acceleration":span*sdd/(duration*duration)+(leg.v0*h0dd+leg.v1*h1dd)/duration}
	var frame: int=leg.get("frame",-1)
	if frame>=0:
		var parent:=System.moon_position(frame,when)
		result.position+=parent
		result.velocity+=System.moon_velocity(frame,when)
		result.acceleration+=gravity(parent)
	return result

func route_sample(when: float) -> Dictionary:
	var legs: Array=plan.get("legs",[])
	if legs.is_empty(): return {"position":ship_position,"velocity":velocity,"acceleration":Vector3.ZERO}
	for leg in legs:
		if when<=float(leg.start)+float(leg.duration): return _smooth_leg(leg,when)
	return _smooth_leg(legs.back(),when)

func _make_legs(points: Array, start: float, duration: float, frame: int=-1) -> Array:
	var weights: Array[float]=[]
	var total:=0.0
	for i in points.size()-1:
		var weight:=sqrt(maxf(1,points[i].distance_to(points[i+1])))
		weights.append(weight)
		total+=weight
	var legs: Array=[]
	var velocities: Array[Vector3]=[velocity-(System.moon_velocity(frame,start) if frame>=0 else Vector3.ZERO)]
	for i in range(1,points.size()-1):
		var previous: Vector3=points[i]-points[i-1]
		var next: Vector3=points[i+1]-points[i]
		var corner_speed:=minf(previous.length()/(duration*weights[i-1]/total),next.length()/(duration*weights[i]/total))*0.8
		velocities.append((previous.normalized()+next.normalized()).normalized()*corner_speed)
	velocities.append(station_velocity(destination,start+duration)-(System.moon_velocity(frame,start+duration) if frame>=0 else Vector3.ZERO))
	var clock:=start
	for i in weights.size():
		var leg_duration:=duration*weights[i]/total
		legs.append({"from":points[i],"to":points[i+1],"start":clock,"duration":leg_duration,"v0":velocities[i],"v1":velocities[i+1],"frame":frame})
		clock+=leg_duration
	return legs

func _route_obstacles(when: float) -> Array:
	# Rings use their circumscribing sphere as a conservative route exclusion zone.
	var obstacles: Array=[{"position":PLANET,"radius":System.RING_OUTER+1200.0,"name":"Aurel rings"}]
	for i in System.MOONS.size():
		var moon: Dictionary=System.MOONS[i]
		obstacles.append({"position":System.moon_position(i,when),"radius":float(moon.body_radius_km)/System.REAL_KM_PER_UNIT+650.0,"name":moon.name})
	return obstacles

func _first_route_obstruction(legs: Array) -> Dictionary:
	for i in legs.size():
		var leg: Dictionary=legs[i]
		var samples:=maxi(20,ceili(float(leg.duration)/2.0))
		for sample in samples+1:
			var when:=float(leg.start)+float(leg.duration)*sample/samples
			var point: Vector3=_smooth_leg(leg,when).position
			for obstacle in _route_obstacles(when):
				if point.distance_to(obstacle.position)<float(obstacle.radius):
					return {"leg":i,"obstacle":obstacle,"point":point,"when":when}
	return {}

func _flight_plan(style: String, duration: float) -> Dictionary:
	var target:=station_position(destination,elapsed+duration)+hold_offset
	# Launches near a moon use its moving frame for smooth clearance.
	# This avoids detours chasing the parent moon during the initial burn.
	var frame: int=System.STATIONS[dock_id].moon
	if frame<0 or ship_position.distance_to(System.moon_position(frame,elapsed))>15000: frame=-1
	var points: Array=[ship_position-(System.moon_position(frame,elapsed) if frame>=0 else Vector3.ZERO),target-(System.moon_position(frame,elapsed+duration) if frame>=0 else Vector3.ZERO)]
	var legs:=_make_legs(points,elapsed,duration,frame)
	var clear:=false
	for attempt in 18:
		var collision:=_first_route_obstruction(legs)
		if collision.is_empty():
			clear=true
			break
		var index: int=collision.leg
		var obstacle: Dictionary=collision.obstacle
		var segment: Vector3=points[index+1]-points[index]
		var normal: Vector3=Vector3.UP-segment.normalized()*segment.normalized().dot(Vector3.UP)
		if normal.length()<0.2: normal=Vector3.RIGHT-segment.normalized()*segment.normalized().dot(Vector3.RIGHT)
		normal=normal.normalized()
		# Each miss increases stand-off to account for an orbit moving during the detour.
		var waypoint: Vector3=obstacle.position+normal*float(obstacle.radius)*(1.7+attempt*0.15)
		if frame>=0: waypoint-=System.moon_position(frame,float(collision.when))
		points.insert(index+1,waypoint)
		legs=_make_legs(points,elapsed,duration,frame)
	if not clear: return {}
	var delta_v:=0.0
	var peak:=0.0
	for leg in legs:
		var samples:=maxi(20,ceili(float(leg.duration)/2.0))
		var dt:=float(leg.duration)/samples
		for i in samples:
			var sample:=_smooth_leg(leg,float(leg.start)+(i+0.5)*dt)
			var required: Vector3=sample.acceleration-gravity(sample.position)
			delta_v+=required.length()*dt
			peak=maxf(peak,required.length())
	var world_points: Array=[]
	for leg in legs: world_points.append(_smooth_leg(leg,float(leg.start)).position)
	world_points.append(_smooth_leg(legs.back(),elapsed+duration).position)
	var mass:=DRY_MASS+cargo_mass+fuel
	var estimate:=mass*(1-exp(-delta_v/(EXHAUST*clampf(coolant/0.82,0.25,1))))
	return {"destination":destination,"style":style,"start":elapsed,"eta":elapsed+duration,"target":target,"velocity":velocity,"fuel":ceilf(estimate*1.16+DEPARTURE_ALLOWANCE+ARRIVAL_ALLOWANCE),"burn":flow,"reserve":RESERVE,"mixture":mixture,"mass":cargo_mass,"coolant":coolant,"coast":duration,"points":world_points,"legs":legs,"peak":peak}

func plan_route(id: String, style := "direct") -> String:
	var index:=System.station_index(id)
	if index<0: return "Unknown destination. Type destinations."
	if style not in ["direct","economy"]: return "Use plot <station> direct|economy."
	if phase=="docked" and index==dock_id: return "Already docked there. Choose another station."
	if phase in ["coast","brake","approach"]: return "Use NAV recalc to replace an active transfer."
	if destination!=index: approach_clearance=false
	destination=index
	nav_selected=false
	route_serial+=1
	nav_stage=-1
	var distance:=ship_position.distance_to(station_position(index,elapsed))
	var duration:=clampf(260.0+distance/650.0,260.0,1320.0)*(1.12 if style=="economy" else 1.0)
	plan={}
	for attempt in 10:
		var candidate:=_flight_plan(style,duration)
		if not candidate.is_empty() and candidate.peak<=planning_acceleration()*0.7 and candidate.fuel+RESERVE<=CAPACITY:
			plan=candidate
			break
		duration=minf(1600,duration*1.16)
	loaded=false
	entered_coords=Vector3.INF
	entered_burn=-1
	entered_reserve=-1
	notified=false
	if plan.is_empty(): return "No safe transfer solution at this epoch. Choose another route or request station assistance."
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
	var exit_instruction: String="Back out with S through the green corridor." if (-attitude.z).dot(BERTH_FORWARD)>0.5 else "Fly forward through the green corridor."
	alert("Berth released. %s NAV available beyond 300 m." % exit_instruction)
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
	if phase=="approach":
		# The approach cue points the nose into the berth, including while braking.
		direction=(station_position(destination,elapsed)-ship_position).normalized() if station_range()>30 else BERTH_FORWARD
	var local := attitude.inverse()*direction
	var yaw := rad_to_deg(atan2(-local.x,-local.z))
	var pitch_error := rad_to_deg(atan2(local.y,Vector2(local.x,local.z).length()))
	return {"dv":dv,"direction":direction,"yaw":yaw,"pitch":pitch_error,"seconds":dv.length()/maxf(max_acceleration(),0.1)}

func set_warp(value: float) -> String:
	if value not in [1.0,5.0,20.0]: return "Use warp 1, 5 or 20."
	if value>1 and (not autopilot or phase not in ["injection","coast","brake"]): return "Fast time requires NAV automatic transfer."
	if value>1 and time_to_burn()<=WARNING_TIME+0.000001:
		warp=1
		sleeping=false
		return "Arrival watch has begun. Stay awake; NAV remains engaged at normal time."
	warp=value
	return "Time rate %dx. Normal time resumes 90 seconds before arrival braking." % int(warp)

func arrival_wake_in() -> float:
	return maxf(0,time_to_burn()-WARNING_TIME)

func sleep_until_warning() -> String:
	var result:=set_warp(20)
	if warp==20:
		sleeping=true
		return "Resting. NAV wakes you 90 seconds before arrival braking and stays engaged."
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
	# Walking, returning to the chair and accidental control keys never cancel NAV.
	# Only the explicit manual command (or a propulsion fault) releases control.
	if autopilot or auto_docking or arrival_hold:
		thrust=Vector3.ZERO
		rotation_input=Vector3.ZERO
		stop_rotation=false
	elif thrust.length()>0 or rotation_input.length()>0:
		warp=1
		sleeping=false
	if autopilot and phase in ["injection","coast","brake"] and time_to_burn()<=WARNING_TIME+0.000001 and (sleeping or warp>1):
		wake_for_arrival()
	var remaining:=delta*warp
	var simulated:=0.0
	var rested:=0.0
	while remaining>0.000001:
		var dt:=minf(0.2,remaining)
		var was_sleeping:=sleeping
		var was_accelerated:=warp>1
		if autopilot and (not notified or sleeping or warp>1) and phase in ["injection","coast","brake"] and arrival_wake_in()>0.000001:
			dt=minf(dt,arrival_wake_in())
		var old_phase:=phase
		_step(dt,thrust,rotation_input,stop_rotation)
		simulated+=dt
		rested+=dt*(0.10 if was_sleeping else -0.008)
		remaining-=dt
		# Discard accelerated frame time after waking: never carry it across the alarm.
		if (was_accelerated and warp==1) or (old_phase!="approach" and phase=="approach") or phase=="docked": break
	food=maxf(0,food-simulated*0.009)
	water=maxf(0,water-simulated*0.014)
	hygiene=maxf(0,hygiene-simulated*0.007)
	rest=clampf(rest+rested,0,100)

func wake_for_arrival() -> void:
	warp=1
	sleeping=false
	notified=true
	alert("Arrival watch: braking begins in 90 seconds. You are awake; NAV remains engaged. Return to the cockpit when ready.")

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
			if time_to_burn()<=WARNING_TIME+0.000001 and (not notified or sleeping or warp>1):
				wake_for_arrival()
			if time_to_burn()<=0:
				phase="brake"
				alert("NAV performing arrival braking. Station approach follows.")
		elif phase=="brake":
			var error:=ship_position.distance_to(station_position(destination,elapsed)+hold_offset)
			if error<8 and relative_speed()<0.5:
				phase="approach"
				arrival_hold=true
				warp=1
				sleeping=false
				alert("Station arrival. NAV remains engaged, holding 600 m from the berth. Type approach for berth K-01, then auto dock; or manual to fly yourself.")
	if auto_docking and docking_stage=="final" and station_range()<12 and relative_speed()<0.5:
		if (-attitude.z).dot(BERTH_FORWARD)>cos(deg_to_rad(5)):
			dock()

func dock() -> String:
	if phase=="docked": return "Already docked at %s / berth K-01." % NAMES[dock_id]
	if not approach_clearance: return "Type approach on NAV or COMMS to receive berth K-01 automatically."
	var d := ship_position.distance_to(station_position(destination,elapsed))
	var s := (velocity-station_velocity(destination,elapsed)).length()
	if d>20 or s>2: return "Berth K-01 capture needs <20 m / <2 m/s. Now %.0f m / %.1f m/s.\nUse auto dock within 1000 m / 15 m/s, or manual to fly closer." % [d,s]
	if (-attitude.z).dot(BERTH_FORWARD)<cos(deg_to_rad(8)) or angular_velocity.length()>0.02: return "Align nose-first to berth heading 180 / pitch 000 and stop rotation [X]."
	dock_id=destination
	autopilot=false
	auto_docking=false
	docking_stage=""
	arrival_hold=false
	sleeping=false
	phase="docked"
	ship_position=station_position(dock_id,elapsed)
	velocity=station_velocity(dock_id,elapsed)
	attitude=Basis.looking_at(BERTH_FORWARD)
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
	if op=="manual":
		release_controls()
		return "Manual controls. NAV disengaged; momentum is preserved. Type engage at NAV to resume."
	if terminal in ["nav","comms"]:
		if op=="approach": return request_approach()
		if op=="dock": return dock()
		if op in ["autodock","auto-dock"] or (op=="auto" and words.size()==2 and words[1]=="dock"):
			return engage_docking()
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
		return station_directory(int(words[1]) if words.size()==2 and words[1].is_valid_int() else 1)
	if terminal in ["chart","nav"] and op=="station" and words.size()==2:
		return station_details(words[1])
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

func station_directory(page: int=1) -> String:
	if page<1 or page>3: return "Use stations 1, stations 2, or stations 3."
	var ordered: Array=[]
	for number in range((page-1)*5+1,page*5+1): ordered.append(System.station_index(str(number)))
	var rows: Array[String]=["AUREL STATIONS / PAGE %d OF 3" % page]
	for i in ordered:
		var here: String=" *HERE" if phase=="docked" and i==dock_id else ""
		rows.append("%02d %s / %s%s" % [System.STATIONS[i].number,IDS[i].to_upper(),System.region(i),here])
	rows.append("stations 1|2|3 / station <id> for details")
	rows.append("CHART: plot <id or number> direct|economy")
	rows.append("Example: plot %s direct" % IDS[(dock_id+1)%IDS.size()])
	return "\n".join(rows)

func station_details(id: String) -> String:
	var index:=System.station_index(id)
	if index<0: return "Unknown station. Type stations 1, 2, or 3."
	var station: Dictionary=System.STATIONS[index]
	return "%02d / %s\nREGION: %s\n%s\nEXPORTS: %s\nIMPORTS: %s\n\nCHART: plot %s direct|economy\nAll stations have a berth, supplies and service." % [station.number,station.name,System.region(index),station.purpose,station.exports,station.imports,station.id]

func command_reference(terminal: String) -> String:
	var reference: String={
		"chart":"stations 1|2|3 | station <id>\nplot <station> direct|economy\nroute | print\nmap system|route|local | show <body>",
		"nav":"coords <x> <y> <z>  (km)\nburn <kg/s> | reserve <kg> | load\nengage | manual | recalc | warp 1|5|20\napproach | auto dock | dock\nstations 1|2|3 | station <id> | status",
		"checklist":"status | print\nhatch close|open | ramp raise|lower\nPhysical cargo clamps must also be secured.",
		"fuel":"status  (fuel and spare-fuel monitor)",
		"engine":"port on|off\nstarboard on|off\nstatus  (live engine diagram)",
		"comms":"request | code <takeoff-code> | depart\napproach (assign berth K-01) | auto dock | dock\nrefuel | service | rescue | save | load",
		"map":"map system|route|local | show <body>\nstation <id or number>\nplot <station> direct|economy | print",
		"distance":"Distance to the destination loaded at NAV"
	}.get(terminal,"")
	return reference+"\n\nTab: pin/stow paper | Shift+Tab: next sheet\nDelete: discard sheet | P: read outside CLI\nreturn: previous screen\ngo <terminal> | display <role> | manual | clear | help"

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
		return "%s\nRANGE %.0f m / REL SPEED %.1f m/s\nYAW %+.1f / PITCH %+.1f\nBERTH K-01: %s\n%s\nMANUAL: disengage NAV to fly yourself" % ["NAV / AUTO DOCK" if auto_docking else ("NAV / ARRIVAL HOLD" if arrival_hold else "MANUAL APPROACH"),station_range(),relative_speed(),g.yaw,g.pitch,"ASSIGNED" if approach_clearance else "TYPE approach TO REQUEST","auto dock: assistance within 1000 m / 15 m/s" if approach_clearance else "approach assigns your berth automatically"]
	return "%s / %s\n%s\nARRIVAL BRAKING IN %.0f s\nDESTINATION RANGE %.1f km\nTIME %dx / FUEL %.0f kg\n%s" % [NAMES[destination],phase.to_upper(),"NAV AUTOMATIC TRANSFER" if autopilot else "MANUAL / NAV DISENGAGED",time_to_burn(),station_range()/1000,int(warp),fuel,"SAFE TO LEAVE CONTROLS" if autopilot else "NAV engage TO RESUME"]

func snapshot() -> Dictionary:
	var result := {"version":1}
	for key in ["autopilot","auto_docking","docking_stage","arrival_hold","nav_selected","paper_serial","selected_paper","paper_visible","route_serial","nav_stage","elapsed","phase","dock_id","destination","fuel","cargo_mass","mixture_confirmed","mixture","flow","engine_on","coolant","hatch_closed","ramp_raised","cargo_secured","loaded","entered_burn","entered_reserve","clearance","clearance_confirmed","approach_clearance","notified","food","water","hygiene","rest","rations","drinks","completed_trips","misses","warning","session_message"]:
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
	result["flight_revision"]=5
	result["system_revision"]=1
	if not plan.is_empty():
		result.plan["points"]=[]
		for point in plan.get("points",[]): result.plan.points.append([point.x,point.y,point.z])
		for leg in result.plan.get("legs",[]):
			for key in ["from","to","v0","v1"]:
				var point: Vector3=leg[key]
				leg[key]=[point.x,point.y,point.z]
	return result

func restore(data: Dictionary) -> bool:
	if data.get("version")!=1: return false
	data=data.duplicate(true)
	var migrate_system:=int(data.get("system_revision",0))<1
	data["system_revision"]=1
	for key in ["printed_route","entered_coords","route_serial","nav_stage"]:
		if not data.has(key): data[key]={"printed_route":{},"entered_coords":null,"route_serial":0,"nav_stage":-1}[key]
	var defaults := snapshot()
	if not data.has("docking_stage"): data.docking_stage=""
	for key in ["autopilot","auto_docking","arrival_hold","nav_selected","paper_serial","selected_paper","paper_visible","papers","trail","engines"]:
		if not data.has(key): data[key]=defaults[key]
	if not data.has("flight_revision"):
		data.engines=[data.get("engine_on",false),data.get("engine_on",false)]
		data.nav_selected=data.get("loaded",false)
	# Previous builds treated hold / docking as NAV being off. They are engaged modes.
	if data.arrival_hold or data.auto_docking: data.autopilot=true
	data.flight_revision=5
	for key in defaults:
		if not data.has(key): return false
	# Validate into a candidate before changing the live model.
	if data.phase not in ["docked","departure","injection","coast","brake","approach"]: return false
	if not valid_number(str(data.dock_id)) or not valid_number(str(data.destination)): return false
	if data.dock_id!=int(data.dock_id) or data.destination!=int(data.destination) or int(data.dock_id)<0 or int(data.dock_id)>=IDS.size() or int(data.destination)<0 or int(data.destination)>=IDS.size(): return false
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
	if data.autopilot and (not data.loaded or data.phase not in ["injection","coast","brake","approach"]): return false
	if data.autopilot and data.phase=="approach" and not (data.auto_docking or data.arrival_hold): return false
	if (data.auto_docking or data.arrival_hold) and data.phase!="approach": return false
	if data.auto_docking and not data.approach_clearance: return false
	if data.docking_stage not in ["","clearance","overhead","entry","final"]: return false
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
		if int(data.plan.destination)!=int(data.destination): return false
		if not migrate_system:
			if not data.plan.get("legs") is Array or data.plan.legs.is_empty() or data.plan.legs.size()>24: return false
			if not data.plan.get("points") is Array or data.plan.points.size()!=data.plan.legs.size()+1: return false
			for point in data.plan.points:
				if not _valid_vector_array(point): return false
			for leg in data.plan.legs:
				if not leg is Dictionary: return false
				for key in ["from","to","v0","v1"]:
					if not _valid_vector_array(leg.get(key)): return false
				for key in ["start","duration"]:
					if not (leg.get(key) is float or leg.get(key) is int) or not is_finite(float(leg[key])): return false
				if leg.duration<=0: return false
				if not (leg.get("frame",-1) is int or leg.get("frame",-1) is float): return false
				if int(leg.get("frame",-1))!=leg.get("frame",-1) or int(leg.get("frame",-1))< -1 or int(leg.get("frame",-1))>=System.MOONS.size(): return false
	elif data.loaded or data.phase in ["coast","brake","approach"]: return false
	if data.fuel<0 or data.fuel>CAPACITY or data.flow<3 or data.flow>8 or data.mixture<1.5 or data.mixture>3.5: return false
	for key in defaults:
		if key in ["version","flight_revision","system_revision","trail","ship_position","velocity","angular_velocity","required_velocity","attitude","plan","entered_coords"]: continue
		set(key,data[key])
	for key in ["ship_position","velocity","angular_velocity","required_velocity"]:
		set(key,Vector3(data[key][0],data[key][1],data[key][2]))
	var a: Array=data.attitude
	attitude=Basis(Vector3(a[0],a[1],a[2]),Vector3(a[3],a[4],a[5]),Vector3(a[6],a[7],a[8])).orthonormalized()
	plan=data.plan.duplicate(true)
	if not plan.is_empty():
		for key in ["target","velocity"]: plan[key]=Vector3(plan[key][0],plan[key][1],plan[key][2])
		for i in plan.get("points",[]).size():
			var point: Array=plan.points[i]
			plan.points[i]=Vector3(point[0],point[1],point[2])
		for leg in plan.get("legs",[]):
			for key in ["from","to","v0","v1"]:
				var point: Array=leg[key]
				leg[key]=Vector3(point[0],point[1],point[2])
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
	if migrate_system:
		# Geometry changed: a tug transfers the existing ship to its last known home berth.
		# Inventory, supplies, needs, papers, upgrades and completed journeys are retained.
		release_controls()
		phase="docked"
		attitude=Basis.looking_at(BERTH_FORWARD)
		ship_position=station_position(dock_id,elapsed)
		velocity=station_velocity(dock_id,elapsed)
		angular_velocity=Vector3.ZERO
		plan={}
		loaded=false
		nav_selected=false
		entered_coords=Vector3.INF
		entered_burn=-1
		entered_reserve=-1
		clearance=""
		clearance_confirmed=false
		approach_clearance=false
		trail.clear()
		printed_route={}
		alert("Aurel chart update installed. Station tug has moored Longhaul at %s. Your supplies and progress are preserved; plot a fresh route." % NAMES[dock_id])
		return true
	# Older saves used a live departure epoch. Refresh once when migrating at berth.
	if phase=="docked" and not plan.is_empty() and plan.eta-elapsed<plan.coast-0.1:
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

func reference_station_id() -> int:
	return dock_id if phase in ["docked","departure"] else destination

func relative_velocity_local() -> Vector3:
	# Godot ship-body axes: +X right, +Y up, +Z backward (-Z forward).
	return attitude.inverse()*(velocity-station_velocity(reference_station_id(),elapsed))

func station_offset_local() -> Vector3:
	return attitude.inverse()*(station_position(reference_station_id(),elapsed)-ship_position)

func safe_departure() -> bool:
	var relative:=ship_position-station_position(dock_id,elapsed)
	return (relative.z < -300 and absf(relative.x)<500 and absf(relative.y)<500) or relative.length()>1000

func engage_navigation() -> String:
	if phase=="docked": return "Docked. Fly out through the departure corridor first."
	if not loaded: return "No validated route loaded."
	if autopilot: return "NAV already engaged%s. Safe to leave controls. Only manual releases control." % (" / station hold" if arrival_hold else "")
	if phase=="departure" and not safe_departure(): return "Inside station zone. Clear the green corridor beyond 300 m."
	if not engines[0] or not engines[1] or coolant<=0: return "NAV requires both engines and available coolant."
	if fuel<RESERVE+30: return "Insufficient maneuver fuel. COMMS rescue available."
	if phase=="approach" or station_range()<1000:
		autopilot=true
		auto_docking=false
		arrival_hold=true
		phase="approach"
		warp=1
		sleeping=false
		alert("NAV station hold engaged at the 600 m waiting point. Type approach for berth K-01, then auto dock.")
		return warning
	# Rebase the planned intercept to departure time. Coordinates are still entered manually;
	# station motion and delayed launches are handled by the navigation computer.
	var rebased: Dictionary={}
	var duration: float=plan.coast
	for attempt in 12:
		var candidate:=_flight_plan(str(plan.style),duration)
		# The departure allowance has already served its purpose outside the berth.
		if not candidate.is_empty() and candidate.peak<=planning_acceleration()*0.7 and candidate.fuel-DEPARTURE_ALLOWANCE+RESERVE<=fuel:
			rebased=candidate
			break
		duration=minf(1600,duration*1.12)
	if rebased.is_empty(): return "The safe route now needs more fuel. Return to the station for fuel, or use COMMS rescue. NAV has not engaged."
	plan=rebased
	required_velocity=velocity
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
	docking_stage=""
	arrival_hold=false
	warp=1
	sleeping=false

func request_approach() -> String:
	if phase=="docked": return "Already docked at %s / berth K-01. Use request for a takeoff code." % NAMES[dock_id]
	if not nav_selected and not loaded: return "No arrival station selected. Plot at CHART and load the coordinates at NAV."
	approach_clearance=true
	# A manual or older saved flight may be beside the station in an earlier phase.
	# Recognize the physical approach without taking control from an engaged NAV.
	if not autopilot and not auto_docking and not arrival_hold and station_range()<=5000:
		phase="approach"
	return "ATC / %s\nBERTH K-01 AUTOMATICALLY ASSIGNED / CLEARANCE CONFIRMED\nType auto dock within 1000 m and below 15 m/s.\nOr manual, then dock nose-first within 20 m / 2 m/s, heading 180 / pitch 000.\nNo berth selection command is needed; clearance has no expiry." % NAMES[destination]

func engage_docking() -> String:
	if phase=="docked": return "Already docked at %s / berth K-01." % NAMES[dock_id]
	if not approach_clearance: return "Arrival clearance required. Type approach on NAV or COMMS; berth K-01 is assigned automatically. Then type auto dock."
	if station_range()>1000 or relative_speed()>15: return "Berth K-01 is assigned. Auto dock needs <1000 m / <15 m/s; now %.0f m / %.1f m/s.\nWait for NAV station hold, or use manual to approach and brake. Then type auto dock again." % [station_range(),relative_speed()]
	if not engines[0] or not engines[1] or coolant<=0 or fuel<20: return "Autodock requires both engines, coolant and 20 kg fuel."
	phase="approach"
	autopilot=true
	arrival_hold=false
	auto_docking=true
	docking_stage=""
	warp=1
	sleeping=false
	alert("NAV auto dock engaged for berth K-01. Aligning for a nose-first approach. Safe to leave controls; only the manual command cancels assistance.")
	return warning

func docking_target() -> Vector3:
	var station:=station_position(destination,elapsed)
	var relative:=ship_position-station
	if docking_stage=="":
		# Use the open end of the pad even when assistance starts beside or behind it.
		var in_lane:=relative.z<=0 and Vector2(relative.x,relative.y).length()<maxf(3,-relative.z*0.1)
		docking_stage="final" if in_lane else ("clearance" if relative.z>-60 else "entry")
	if docking_stage=="clearance":
		if relative.y<50: return station+Vector3(relative.x,60,relative.z)
		docking_stage="overhead"
	if docking_stage=="overhead":
		var overhead:=Vector3(0,60,-100)
		if relative.distance_to(overhead)>5 or relative_speed()>1: return station+overhead
		docking_stage="entry"
	if docking_stage=="entry":
		var entrance:=Vector3(0,0,-100)
		if relative.distance_to(entrance)>3 or relative_speed()>0.5: return station+entrance
		docking_stage="final"
	return station

func automatic_thrust(dt: float) -> Vector3:
	var dv:=Vector3.ZERO
	var docking_direction:=BERTH_FORWARD
	var transfer_acceleration:=Vector3.ZERO
	var transferring:=autopilot and phase in ["injection","coast"]
	if transferring:
		var reference:=route_sample(elapsed)
		required_velocity=reference.velocity
		dv=required_velocity-velocity
		transfer_acceleration=reference.acceleration-gravity(ship_position)+(reference.position-ship_position)*0.12+dv*0.7
	else:
		var target:=docking_target() if auto_docking else station_position(destination,elapsed)+hold_offset
		var offset:=target-ship_position
		var max_speed:=12.0 if auto_docking else 400.0
		var closing:=minf(max_speed,minf(offset.length()*0.16,sqrt(2*maxf(max_acceleration(),0.1)*0.50*offset.length())))
		if auto_docking:
			docking_direction=BERTH_FORWARD if docking_stage=="final" else offset.normalized()
			# Brake and turn first. Translation must not back the ship into its approach.
			if (-attitude.z).dot(docking_direction)<cos(deg_to_rad(15)): closing=0
		required_velocity=station_velocity(destination,elapsed)+offset.normalized()*closing
		dv=required_velocity-velocity
	var wanted_direction:=dv.normalized() if dv.length()>1 else -attitude.z
	if arrival_hold: wanted_direction=(station_position(destination,elapsed)-ship_position).normalized()
	if auto_docking: wanted_direction=docking_direction
	if wanted_direction.length()>0.1:
		var up:=Vector3.UP if absf(wanted_direction.dot(Vector3.UP))<0.99 else Vector3.RIGHT
		attitude=attitude.slerp(Basis.looking_at(wanted_direction,up),minf(1,dt*0.9)).orthonormalized()
	angular_velocity=Vector3.ZERO
	# The six-axis thrusters apply real acceleration and use the same fuel model as manual flight.
	var desired_acceleration: Vector3=transfer_acceleration if transferring else dv/1.4
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
	return "SHEET %02d PRINTED / %s\nPaper collected into the cockpit rack.\nTab: pin/stow beside this display\nShift+Tab: next sheet | Delete: discard\nP: full-page reader outside the CLI" % [paper_serial,kind.to_upper()]

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

func _valid_vector_array(value: Variant) -> bool:
	if not value is Array or value.size()!=3: return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)): return false
	return true
