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
var mixture_confirmed := false
var mixture := 2.5
var flow := 6.0
var engine_on := false
var coolant := 0.82
var hatch_closed := false
var ramp_raised := false
var closures_busy := false
var cargo_secured := true
var plan: Dictionary = {}
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
var session_message := "Welcome aboard. CHART: destinations > plot tharsis direct."

func _init() -> void:
	ship_position = station_position(0, 0)
	velocity = station_velocity(0, 0)

func station_position(index: int, when: float) -> Vector3:
	var radius: Vector3 = ORIGINS[index] - PLANET
	var axis := Vector3.UP
	if index >= 2: axis = Vector3(0.02,1,0.01).normalized()
	return PLANET + radius.rotated(axis, sqrt(MU / pow(radius.length(), 3)) * when)

func station_velocity(index: int, when: float) -> Vector3:
	return (station_position(index, when + 0.1) - station_position(index, when - 0.1)) / 0.2

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
	return 1.0 / (1.0 + absf(mixture-2.5)*0.3)

func max_acceleration() -> float:
	return flow * EXHAUST * efficiency() * clampf(coolant/0.82,0.25,1) / (DRY_MASS+cargo_mass+fuel)

func plan_route(id: String, style := "direct") -> String:
	var index := IDS.find(id)
	if index < 0: return "Unknown destination. Type destinations."
	if style not in ["direct","economy"]: return "Use plot <station> direct|economy."
	if phase == "docked" and index == dock_id: return "Already docked there. Choose another station."
	if phase in ["coast","brake","approach"]: return "Use NAV recalc to replace an active transfer."
	destination = index
	var leg_time: float = maxf(TIMES[index], TIMES[dock_id] if phase=="docked" else 150+ship_position.distance_to(station_position(index,elapsed))/650)
	var duration: float = minf(1050,leg_time) * (1.23 if style=="economy" else 1.0)
	# Leave room for the manually executed departure burn, then a coast.
	var eta := elapsed + duration + 60.0
	var target := station_position(index,eta)
	var v := solve_velocity(ship_position,target,duration+60)
	var arrival_v := propagate(ship_position,v,duration+60)[1]
	var arrival_dv := (arrival_v-station_velocity(index,eta)).length()
	var brake_distance := arrival_dv*arrival_dv/(2*maxf(max_acceleration(),1.0)) + arrival_dv*12 + 1000
	var approach_dir := (arrival_v-station_velocity(index,eta)).normalized()
	target -= approach_dir * brake_distance
	v = solve_velocity(ship_position,target,duration+60)
	arrival_v = propagate(ship_position,v,duration+60)[1]
	var dv := (v-velocity).length() + (arrival_v-station_velocity(index,eta)).length() + 70
	var estimate := dv*(DRY_MASS+cargo_mass+fuel)/(EXHAUST*efficiency()*clampf(coolant/0.82,0.25,1))
	plan = {"destination":index,"style":style,"eta":eta,"target":target,"velocity":v,"fuel":ceilf(estimate),"burn":flow,"reserve":RESERVE,"mixture":mixture,"mass":cargo_mass,"coolant":coolant,"coast":duration}
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
	if plan.is_empty(): return "No route. CHART: plot tharsis direct"
	return "ROUTE %s / %s\nNAV: coords %s\nNAV: burn %.2f  |  reserve %.0f\nNAV: load\nFuel estimate %.0f kg + %.0f reserve\nCoast ends in ~%.0f min / %.1f hr ship\nAllow 3–7 min for manual arrival. Compressed distances." % [IDS[destination].to_upper(),plan.style,coords_text(),plan.burn,plan.reserve,plan.fuel,plan.reserve,(plan.eta-elapsed)/60,(plan.eta-elapsed)/60]

func stale_plan() -> bool:
	return not plan.is_empty() and (absf(plan.mixture-mixture)>0.01 or absf(plan.burn-flow)>0.01 or absf(plan.mass-cargo_mass)>0.1 or absf(plan.coolant-coolant)>0.01)

func load_route() -> String:
	if plan.is_empty(): return "Get a route from CHART first."
	if phase not in ["docked","departure","injection"]: return "Use recalc for an active journey."
	if stale_plan(): return "Ship setup changed. Replot on CHART for a fresh fuel estimate."
	if entered_coords.distance_to(plan.target) > 2.0: return "Coordinates differ from CHART. Use km, including minus signs."
	if absf(entered_burn-plan.burn)>0.01: return "Burn rate differs from CHART. Enter burn <kg/s>."
	if absf(entered_reserve-plan.reserve)>0.1: return "Enter the reserve shown on CHART."
	if fuel < plan.fuel+plan.reserve: return "Insufficient fuel including arrival and reserve. COMMS: refuel."
	if plan.eta-elapsed < plan.coast*0.65: return "Departure slipped. Replot for a fresh intercept; no penalty."
	loaded = true
	required_velocity = plan.velocity
	return "Route loaded. ENGINE checklist, then COMMS request."

func checklist() -> String:
	return "DEPARTURE CHECKLIST\n[%s] ENGINE power on\n[%s] FUEL mixture 2.5 / flow %.2f\n[%s] CHART plotted / NAV loaded\n[%s] COMMS takeoff code confirmed\n[%s] ENGINE hatch close\n[%s] ENGINE ramp raise\n[%s] Cargo restrained / machinery ready" % [mark(engine_on),mark(mixture_confirmed and absf(mixture-2.5)<0.01),flow,mark(loaded and not stale_plan()),mark(clearance_confirmed),mark(hatch_closed and not closures_busy),mark(ramp_raised and not closures_busy),mark(cargo_secured and coolant>0)]

func mark(value: bool) -> String:
	return "OK" if value else "--"

func can_depart() -> bool:
	return engine_on and mixture_confirmed and absf(mixture-2.5)<0.01 and loaded and not stale_plan() and clearance_confirmed and hatch_closed and ramp_raised and not closures_busy and cargo_secured and coolant>0 and fuel>=plan.get("fuel",INF)+RESERVE

func depart() -> String:
	if phase != "docked": return "Already in flight."
	if not can_depart(): return "Departure interlock. ENGINE: checklist"
	if plan.eta-elapsed < plan.coast*0.65: return "Refresh CHART and NAV: intercept needs updating. No deadline."
	phase = "departure"
	warp = 1
	alert("Dock released. Manual flight. Follow NAV burn guidance.")
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
	if value>1 and (phase!="coast" or time_to_burn()<=WARNING_TIME or last_thrust>0.001 or angular_velocity.length()>0.002): return "Fast time needs a stable coast and >75s to the burn."
	warp = value
	return "Time rate %dx. Auto-stop 75 seconds before burn." % int(warp)

func sleep_until_warning() -> String:
	var result := set_warp(20)
	if warp == 20:
		sleeping = true
		return "Resting in bunk. Alarm will wake you before the burn."
	return result

func recalculate() -> String:
	if phase == "docked": return "CHART: plot a destination first."
	if plan.is_empty(): return "No destination loaded."
	warp = 1
	sleeping = false
	phase = "injection"
	var result := plan_route(IDS[destination],"direct")
	if plan.fuel+RESERVE > fuel:
		alert("Recovery needs more fuel. COMMS: rescue is available.")
		return warning
	alert("Recovery calculated. Copy fresh CHART coordinates into NAV and load.")
	return result

func tick(delta: float, thrust := Vector3.ZERO, rotation_input := Vector3.ZERO, stop_rotation := false) -> void:
	var accelerated := warp
	var was_sleeping := sleeping
	var dt := delta*accelerated
	if phase == "coast" and time_to_burn()>WARNING_TIME:
		dt = minf(dt,time_to_burn()-WARNING_TIME)
	if thrust.length()>0 or rotation_input.length()>0:
		warp = 1
		sleeping = false
		was_sleeping = false
		dt = delta
	var steps := maxi(1,ceili(dt/0.25))
	for i in steps: _step(dt/steps,thrust,rotation_input,stop_rotation)
	if phase == "coast" and time_to_burn()<=WARNING_TIME+0.001 and not notified:
		warp = 1
		sleeping = false
		notified = true
		alert("Maneuver in 75 seconds. Return to the cockpit. Fast time stopped.")
	food = maxf(0,food-dt*0.009)
	water = maxf(0,water-dt*0.014)
	hygiene = maxf(0,hygiene-dt*0.007)
	rest = clampf(rest+dt*(0.10 if was_sleeping else -0.008),0,100)

func _step(dt: float, thrust: Vector3, rotation_input: Vector3, stop_rotation: bool) -> void:
	elapsed += dt
	if phase == "docked":
		ship_position = station_position(dock_id,elapsed)
		velocity = station_velocity(dock_id,elapsed)
		angular_velocity = Vector3.ZERO
		return
	angular_velocity += rotation_input*0.38*dt
	angular_velocity = angular_velocity.limit_length(0.65)
	if stop_rotation: angular_velocity = angular_velocity.move_toward(Vector3.ZERO,1.8*dt)
	if angular_velocity.length()>0.00001:
		attitude = (attitude * Basis(angular_velocity.normalized(),angular_velocity.length()*dt)).orthonormalized()
	var applied := thrust.limit_length(1)
	if not engine_on or coolant<=0 or fuel<=0: applied = Vector3.ZERO
	last_thrust = applied.length()
	acceleration = attitude*applied*max_acceleration()
	var use := flow*last_thrust*dt
	if use > fuel:
		acceleration *= fuel/use
	fuel = maxf(0,fuel-use)
	var g := gravity(ship_position)
	ship_position += velocity*dt + (g+acceleration)*dt*dt*0.5
	velocity += (g+gravity(ship_position))*dt*0.5 + acceleration*dt
	solver_timer -= dt
	if phase in ["departure","injection"] and loaded:
		if solver_timer <= 0:
			required_velocity = solve_velocity(ship_position,plan.target,maxf(5,plan.eta-elapsed))
			solver_timer = 0.5
		var forward_match := (-attitude.z).dot(required_velocity.normalized())>cos(deg_to_rad(6))
		if (required_velocity-velocity).length()<3.0 and forward_match and last_thrust<0.001 and angular_velocity.length()<0.005:
			matched_for += dt
			if matched_for>=1:
				phase = "coast"
				alert("Course established. Safe to leave controls.")
		else: matched_for = 0
		if time_to_burn()<10:
			misses += 1
			loaded = false
			alert("Intercept slipped. NAV: recalc for a fresh route. No penalty.")
	if phase=="coast":
		if last_thrust>0.001:
			phase="injection"
			alert("Course changed. Follow NAV to re-establish the coast.")
		elif time_to_burn()<=0:
			phase="brake"
			warp=1
			alert("Arrival burn due. Point at NAV guidance and brake manually.")
	if phase=="brake":
		var distance := ship_position.distance_to(station_position(destination,elapsed))
		var relative_speed := (velocity-station_velocity(destination,elapsed)).length()
		if relative_speed<22:
			phase="approach"
			alert("Relative speed matched. COMMS: approach. Fly to the berth.")
		elif elapsed>float(plan.get("eta",elapsed))+240 and not warning.begins_with("Burn missed"):
			misses+=1
			alert("Burn missed. NAV: recalc when ready; COMMS: rescue if fuel is low.")
		if distance<50 and relative_speed>22:
			# Soft recovery instead of a destructive collision or game over.
			ship_position += (ship_position-station_position(destination,elapsed)).normalized()*100
			alert("Berth proximity warning. Brake; use recalc if you overshoot.")

func dock() -> String:
	if phase not in ["approach","brake"]: return "Finish the transfer before docking."
	if not approach_clearance: return "COMMS: approach to request a berth."
	var d := ship_position.distance_to(station_position(destination,elapsed))
	var s := (velocity-station_velocity(destination,elapsed)).length()
	if d>20 or s>2: return "Berth capture requires <20m and <2m/s relative. Now %.0fm / %.1fm/s." % [d,s]
	if (-attitude.z).dot(Vector3.FORWARD)<cos(deg_to_rad(8)) or angular_velocity.length()>0.02: return "Align berth heading 000 / pitch 000 and stop rotation [X]."
	dock_id=destination
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
	if op=="help": return help_text(terminal)
	if op=="status": return status(terminal)
	if op=="checklist": return checklist()
	if terminal in ["chart","nav"] and op in ["stations","destinations"]:
		return station_directory()
	match terminal:
		"chart":
			if op=="plot" and words.size() in [2,3]: return plan_route(words[1],words[2] if words.size()==3 else "direct")
			if op=="route": return route_card()
		"nav":
			if op=="coords" and words.size()==4:
				for i in range(1,4):
					if not valid_number(words[i]): return "Use three finite coordinates in km."
				entered_coords=Vector3(float(words[1]),float(words[2]),float(words[3]))*1000
				return "Coordinates entered. Next: burn <kg/s>, reserve <kg>, load."
			if op in ["burn","reserve"] and words.size()==2 and valid_number(words[1]):
				if op=="burn": entered_burn=float(words[1])
				else: entered_reserve=float(words[1])
				return "%s recorded: %s" % [op,words[1]]
			if op=="load": return load_route()
			if op=="recalc": return recalculate()
			if op=="warp" and words.size()==2 and valid_number(words[1]): return set_warp(float(words[1]))
		"fuel":
			if op in ["mixture","flow"] and words.size()==2 and valid_number(words[1]):
				var value := float(words[1])
				if phase!="docked": return "Set mixture and flow while docked, before plotting the burn schedule."
				if op=="mixture":
					if value<1.5 or value>3.5: return "Mixture range 1.5–3.5. Nominal 2.5."
					mixture=value
					mixture_confirmed=true
				else:
					if value<3 or value>8: return "Flow range 3–8 kg/s. Nominal 6."
					flow=value
				return "Fuel setting recorded. Replot if your departure setup changed."
		"engine":
			if op=="power" and words.size()==2 and words[1] in ["on","off"]:
				engine_on=words[1]=="on"
				return "Engine power " + words[1].to_upper()
		"comms":
			if op=="request":
				if phase!="docked": return "Use approach for arrival clearance."
				clearance="%s-%03d" % [IDS[dock_id].left(3).to_upper(),100+completed_trips%900]
				return "ATC: takeoff code %s. Read back: code %s\nNo expiry; depart when your ship is ready." % [clearance,clearance]
			if op=="code" and words.size()==2:
				clearance_confirmed=not clearance.is_empty() and words[1].to_upper()==clearance
				return "ATC readback accepted. ENGINE checklist, then depart." if clearance_confirmed else "Incorrect code. COMMS: request"
			if op=="depart": return depart()
			if op=="approach":
				if phase not in ["brake","approach"]: return "Request a berth during arrival."
				approach_clearance=true
				return "Berth K-01 reserved. Capture <20m, <2m/s. Heading 000 / pitch 000. No hurry."
			if op=="dock": return dock()
			if op=="rescue": return rescue()
			if op=="refuel":
				if phase!="docked": return "Refuel at a station; rescue is available."
				fuel=CAPACITY
				return "Station test supply: tanks filled to 3000 kg."
	return "Unknown or incomplete command. Type help."

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

func help_text(terminal: String) -> String:
	match terminal:
		"chart": return "stations | destinations  (list all stations)\nmap | plot <station> direct|economy\nroute\nCalculate here; copy coordinates and fuel to NAV."
		"nav": return "stations | destinations  (list all stations)\ncoords <x> <y> <z>  (km)\nburn <kg/s> | reserve <kg> | load\nrecalc | warp 1|5|20\nstatus | checklist\nSteer with arrows/Q/E. W thrust, S reverse.\nA/D lateral; R/V vertical. Shift fine. X stops spin."
		"fuel": return "mixture 2.5  (oxidizer : fuel)\nflow 6       (kg/s)\nstatus\nSet before plotting. Both affect fuel estimates."
		"engine": return "power on|off\nhatch close|open\nramp raise|lower\nchecklist | status\nClose hatch and raise ramp before departure."
		"comms": return "request | code <takeoff-code> | depart\napproach | dock\nrefuel | service | rescue\nsave | load\nATC never imposes a delivery deadline."
	return "help | status | checklist"

func status(terminal: String) -> String:
	match terminal:
		"chart": return route_card()
		"fuel": return "FUEL %.1f / %.0f kg\nMixture %.2f / flow %.2f kg/s\nCurrent burn %.2f kg/s\nCoolant %.0f%% / cargo %.0f kg\nFood %.0f / water %.0f / rest %.0f" % [fuel,CAPACITY,mixture,flow,flow*last_thrust,coolant*100,cargo_mass,food,water,rest]
		"engine": return checklist()
		"comms": return "%s\n%s\nCompleted journeys: %d\n%s" % [NAMES[dock_id],phase.to_upper(),completed_trips,session_message]
	var g := guidance()
	var relative := (velocity-station_velocity(destination,elapsed)).length()
	return "%s > %s\n%s\nDelta-V %.1f m/s | burn %.1fs\nYaw %+.1f / Pitch %+.1f deg\nRelative %.1f m/s | range %.0f m\nBurn in %.0fs | time %dx\n%s" % [phase.to_upper(),IDS[destination].to_upper(),"MATCH VELOCITY / CUT THRUST" if phase in ["departure","injection"] else ("COAST / THRUST OFF" if phase=="coast" else "MANUAL APPROACH"),g.dv.length(),g.seconds,g.yaw,g.pitch,relative,ship_position.distance_to(station_position(destination,elapsed)),time_to_burn(),int(warp),warning]

func snapshot() -> Dictionary:
	var result := {"version":1}
	for key in ["elapsed","phase","dock_id","destination","fuel","cargo_mass","mixture_confirmed","mixture","flow","engine_on","coolant","hatch_closed","ramp_raised","cargo_secured","loaded","entered_burn","entered_reserve","clearance","clearance_confirmed","approach_clearance","notified","food","water","hygiene","rest","rations","drinks","completed_trips","misses","warning","session_message"]:
		result[key]=get(key)
	for key in ["ship_position","velocity","angular_velocity","required_velocity"]:
		var v: Vector3 = get(key)
		result[key]=[v.x,v.y,v.z]
	result["attitude"]=[attitude.x.x,attitude.x.y,attitude.x.z,attitude.y.x,attitude.y.y,attitude.y.z,attitude.z.x,attitude.z.y,attitude.z.z]
	result["plan"]=plan.duplicate(true)
	if not plan.is_empty():
		for key in ["target","velocity"]:
			var v: Vector3=plan[key]
			result.plan[key]=[v.x,v.y,v.z]
	return result

func restore(data: Dictionary) -> bool:
	if data.get("version")!=1: return false
	var defaults := snapshot()
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
		if key in ["version","ship_position","velocity","angular_velocity","required_velocity","attitude","plan"]: continue
		set(key,data[key])
	for key in ["ship_position","velocity","angular_velocity","required_velocity"]:
		set(key,Vector3(data[key][0],data[key][1],data[key][2]))
	var a: Array=data.attitude
	attitude=Basis(Vector3(a[0],a[1],a[2]),Vector3(a[3],a[4],a[5]),Vector3(a[6],a[7],a[8])).orthonormalized()
	plan=data.plan.duplicate(true)
	if not plan.is_empty():
		for key in ["target","velocity"]: plan[key]=Vector3(plan[key][0],plan[key][1],plan[key][2])
	warp=1
	sleeping=false
	solver_timer=0
	matched_for=0
	entered_coords=plan.get("target",Vector3.INF) if loaded else Vector3.INF
	return true
