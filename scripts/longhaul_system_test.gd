extends SceneTree
const State=preload("res://scripts/longhaul_flight_state.gd")
const System=preload("res://scripts/longhaul_system.gd")
var failed:=0
var passed:=0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		print("SYSTEM FAIL ",label)

func prepare(s, origin: int, destination: int, when: float, style: String="direct") -> void:
	s.elapsed=when
	s.dock_id=origin
	s.ship_position=s.station_position(origin,when)
	s.velocity=s.station_velocity(origin,when)
	s.fuel=3000
	s.command("engine","port on")
	s.command("engine","starboard on")
	s.command("chart","plot "+System.IDS[destination]+" "+style)
	if s.plan.is_empty(): return
	s.entered_coords=s.plan.target
	s.entered_burn=6
	s.entered_reserve=200
	s.load_route()
	s.clearance_confirmed=true
	s.hatch_closed=true
	s.ramp_raised=true

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var all_pairs: bool="--all-pairs" in args
	var epoch:=0.0
	for arg in args:
		if arg.begins_with("--epoch="): epoch=float(arg.get_slice("=",1))
	var min_duration:=INF
	var max_duration:=0.0
	var max_fuel:=0.0
	for origin in System.IDS.size():
		for destination in System.IDS.size():
			if origin==destination: continue
			if not all_pairs and origin!=0 and destination!=(origin+1)%System.IDS.size(): continue
			var s=State.new()
			prepare(s,origin,destination,epoch,"economy" if "--economy" in args else "direct")
			var name: String="%s > %s" % [System.IDS[origin],System.IDS[destination]]
			check(not s.plan.is_empty(),name+" has safe plan")
			if s.plan.is_empty(): continue
			check(s.loaded and s.can_depart(),name+" affordable complete checklist")
			check(s._first_route_obstruction(s.plan.legs).is_empty(),name+" planned body clearances")
			max_fuel=maxf(max_fuel,s.plan.fuel)
			if "--plans-only" in args: continue
			var quoted_fuel: float=s.plan.fuel
			if "--budget-tank" in args: s.fuel=quoted_fuel+200
			var starting_fuel: float=s.fuel
			s.depart()
			for i in 200:
				if s.safe_departure(): break
				s.tick(0.5,Vector3.FORWARD*0.25)
			s.engage_navigation()
			check(s.autopilot,name+" engages NAV")
			var safe:=true
			for frame in 1750:
				if s.phase=="approach" or s.fuel<=0: break
				s.tick(1)
				for obstacle in s._route_obstacles(s.elapsed):
					if s.ship_position.distance_to(obstacle.position)<obstacle.radius-100: safe=false
			check(s.phase=="approach",name+" reaches arrival hold")
			check(safe,name+" actual trajectory clears bodies")
			s.command("nav","approach")
			s.command("nav","auto dock")
			for i in 260:
				if s.phase=="docked": break
				s.tick(0.5)
			check(s.phase=="docked" and s.dock_id==destination,name+" docks nose first")
			check(s.elapsed-epoch<1800 and s.fuel>=200,name+" within30min and spare fuel")
			check(starting_fuel-s.fuel<=quoted_fuel,name+" complete journey within quoted fuel")
			min_duration=minf(min_duration,s.elapsed-epoch)
			max_duration=maxf(max_duration,s.elapsed-epoch)
			print("SYSTEM ROUTE ",name," ",snapped(s.elapsed-epoch,0.1),"s / ",snapped(s.fuel,0.1),"kg remaining / ",s.plan.legs.size()," legs")
	check_catalog_and_migration()
	print("SYSTEM RANGE seconds ",min_duration," .. ",max_duration," maximum planned fuel ",max_fuel)
	print("AUREL SYSTEM CHECKS ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)

func check_catalog_and_migration() -> void:
	var s=State.new()
	var all_rows:=""
	for page in range(1,4):
		var page_text: String=s.command("chart","stations "+str(page))
		check(page_text.split("\n").size()<=13,"Directory page fits physical terminal")
		all_rows+=page_text
	for i in System.IDS.size():
		check(all_rows.contains(System.IDS[i].to_upper()),"Directory lists "+System.IDS[i])
		check(s.command("nav","station "+str(System.STATIONS[i].number)).contains(System.NAMES[i]),"Numeric station detail "+System.IDS[i])
	prepare(s,0,14,750)
	check(s.loaded,"Outer destination index loads")
	var saved: Dictionary=s.snapshot()
	var copy=State.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(saved))) and copy.destination==14,"Expanded destination survives save load")
	saved.plan.legs[0].v0=[1,"bad",0]
	check(not copy.restore(saved),"Malformed trajectory rejected")
	var legacy: Dictionary=s.snapshot()
	legacy.erase("system_revision")
	legacy.flight_revision=4
	legacy.phase="coast"
	legacy.autopilot=true
	legacy.fuel=1723.0
	legacy.completed_trips=7
	legacy.food=63.0
	legacy.rations=3
	legacy.attitude=[0,1,0,1,0,0,0,0,-1]
	legacy.plan.erase("legs")
	legacy.plan.erase("points")
	check(copy.restore(JSON.parse_string(JSON.stringify(legacy))),"Legacy orbital save migrates")
	check(copy.phase=="docked" and copy.ship_position.distance_to(copy.station_position(copy.dock_id,copy.elapsed))<1 and not copy.loaded,"Legacy geometry relocates to safe mooring and clears stale route")
	check(copy.fuel==1723 and copy.completed_trips==7 and copy.food==63 and copy.rations==3,"Legacy migration preserves fuel supplies needs and journeys")
	check(copy.attitude.is_equal_approx(Basis.looking_at(State.BERTH_FORWARD)) and copy.angular_velocity==Vector3.ZERO,"Legacy migration levels ship on station deck")
	check(copy.warning.contains("Aurel chart update"),"Legacy migration explains new position")
