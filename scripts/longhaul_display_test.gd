extends RefCounted
## Exercise the same physical CRT as each terminal and verify cockpit telemetry signs.
const State=preload("res://scripts/longhaul_flight_state.gd")
var passed:=0
var failed:=0

func check(value: bool, description: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("DISPLAY ",description,": ",value)

func run(host) -> bool:
	var original_state=host.flight
	var original_roles: Array[String]=[]
	for item in host.terminals: original_roles.append(item.kind)
	host.flight=State.new()
	host.close_terminal()
	var terminal=host.terminals[0]
	terminal.set_role("map")
	var map=terminal.chart_map
	var child_count: int=terminal.viewport.get_child_count()
	var switches_ok:=true
	var headers_ok:=true
	var children_ok:=true
	for from_role in terminal.VALID_ROLES:
		for to_role in terminal.VALID_ROLES:
			terminal.set_role(from_role)
			switches_ok=terminal.set_role(to_role) and terminal.kind==to_role and switches_ok
			headers_ok=terminal.header.text.contains("/ "+to_role.to_upper()) and headers_ok
			children_ok=terminal.viewport.get_child_count()==child_count and terminal.chart_map==map and children_ok
			if to_role not in ["chart","map"]: switches_ok=not terminal.chart_map.visible and switches_ok
	check(switches_ok,"Every role can replace every display without a stale map")
	check(headers_ok,"Every display keeps its terminal name in the header")
	check(children_ok,"Repeated role changes reuse the map instead of duplicating nodes")
	check(not terminal.set_role("bogus") and terminal.kind=="radar","Invalid display name preserves the existing terminal")
	terminal.set_role("velocity")
	host.flight.phase="departure"
	host.flight.velocity=host.flight.station_velocity(0,0)+Vector3(-3,2,-12)
	terminal.refresh()
	check(terminal.readout.text.contains("LEFT") and terminal.readout.text.contains("UP") and terminal.readout.text.contains("FORWARD") and terminal.header.text.contains("CERES"),"Velocity labels show local movement relative to the departure station")
	host.flight.phase="approach"
	host.flight.destination=1
	host.flight.nav_selected=true
	host.flight.attitude=Basis(Vector3.UP,PI/2)
	host.flight.velocity=host.flight.station_velocity(1,0)+host.flight.attitude*Vector3(4,-2,7)
	terminal.refresh()
	check(terminal.readout.text.contains("RIGHT") and terminal.readout.text.contains("DOWN") and terminal.readout.text.contains("BACK") and terminal.header.text.contains("THARSIS"),"Velocity display follows ship orientation and switches reference at arrival")
	terminal.set_role("radar")
	host.flight.attitude=Basis.IDENTITY
	host.flight.ship_position=host.flight.station_position(1,0)-Vector3(30,20,-100)
	host.flight.velocity=host.flight.station_velocity(1,0)+Vector3(0,0,-5)
	terminal.refresh()
	check(terminal.readout.text.contains("O") and terminal.telemetry_note.text.contains("X RIGHT 30.0 m") and terminal.telemetry_note.text.contains("Y UP 20.0 m") and terminal.telemetry_note.text.contains("CLOSING"),"Forward radar places station target and reports right/up offsets with closing speed")
	host.flight.ship_position=host.flight.station_position(1,0)-Vector3(-30,-20,100)
	terminal.refresh()
	check(terminal.header.text.contains("TARGET BEHIND") and terminal.readout.text.contains("!") and terminal.telemetry_note.text.contains("X LEFT 30.0 m") and terminal.telemetry_note.text.contains("Y DOWN 20.0 m"),"Radar distinguishes a station behind the ship and reports left/down offsets")
	host.open_terminal(terminal)
	for role in ["map","distance","velocity","radar"]:
		terminal.set_role(role)
		terminal.submit("nonsense")
		var error: String=terminal.readout.text
		terminal.refresh()
		check(error.contains("Unknown") and terminal.readout.text==error and not terminal.chart_map.visible and terminal.prompt.text.begins_with(role.to_upper()+">"),role.to_upper()+" retains command errors and an active CLI")
		terminal.submit("status")
		check(terminal.show_live and not terminal.readout.text.contains("Unknown"),role.to_upper()+" returns to live data with status")
	terminal.set_role("distance")
	host.flight.nav_selected=false
	terminal.refresh()
	check(terminal.readout.text.is_empty() and terminal.header.text.contains("DISTANCE") and terminal.prompt.text.begins_with("DISTANCE>"),"Unselected distance meter hides the value while retaining its name and CLI")
	# Two NAV terminals: DISPLAY must change only the one that received the command.
	terminal.set_role("nav")
	var second=host.terminals[1]
	second.set_role("nav")
	host.open_terminal(second)
	second.submit("display radar")
	check(second.kind=="radar" and terminal.kind=="nav" and second.show_live,"DISPLAY targets the physical focused screen when roles are duplicated")
	host.close_terminal()
	host.flight=original_state
	for i in host.terminals.size(): host.terminals[i].set_role(original_roles[i])
	print("LONGHAUL DISPLAYS ",passed," passed / ",failed," failed")
	return failed==0
