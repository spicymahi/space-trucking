extends RefCounted
const State=preload("res://scripts/longhaul_flight_state.gd")
var passed:=0
var failed:=0
func check(value: bool, name: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("GUIDE ",name,": ",value)

func run(host) -> bool:
	var s=State.new()
	check(s.help_text("nav").contains("go engine") and s.help_text("nav").contains("power on"),"Help directs a new pilot to the correct first terminal and command")
	s.command("engine","power on")
	check(s.help_text("engine").contains("go fuel") and s.help_text("engine").contains("mixture 2.5"),"Guide advances to explicit mixture confirmation")
	check(s.depart().contains("CONFIRM FUEL MIXTURE"),"Blocked takeoff names the missing action")
	check(s.command("nav","mixture 2.5").contains("go fuel"),"Wrong terminal explains where the command belongs")
	s.command("fuel","mixture 2.5")
	s.command("chart","plot tharsis direct")
	var initial_fuel: float=s.fuel
	s.fuel=10
	check(s.help_text("nav").contains("refuel"),"Low-fuel help directs to refuelling instead of repeating route entry")
	s.fuel=initial_fuel
	var coords: String=s.coords_text()
	var epoch: float=s.plan.eta
	s.tick(7200)
	check(s.coords_text()==coords and s.plan.eta==epoch and s.elapsed==0,"Two hours of docked preparation do not expire the route or change the paper values")
	check(s.help_text("chart").contains("PRINT THE FLIGHT SHEET"),"Guide asks for the printed route")
	check(s.command("nav","plot").contains("Print"),"Guided NAV entry requests a sheet first")
	s.command("chart","print")
	check(s.paper_current() and s.printed_route.coords==coords,"Printed sheet matches the planned route")
	s.command("nav","plot")
	check(s.nav_stage==0 and s.help_text("nav").contains("1 OF 4"),"NAV explains the first entry step")
	s.command("nav","0 0 0")
	check(s.nav_stage==0 and not s.loaded,"Wrong coordinate readback does not advance or load")
	s.command("nav",coords)
	check(s.nav_stage==1 and s.help_text("nav").contains("BURN RATE"),"Coordinates advance the guide to burn rate")
	var restored=State.new()
	var save=JSON.parse_string(JSON.stringify(s.snapshot()))
	check(restored.restore(save) and restored.nav_stage==1 and restored.paper_current() and restored.entered_coords==s.entered_coords,"Partial entry and printed sheet survive JSON save/load")
	s.command("nav","6")
	s.command("nav","200")
	check(s.nav_stage==3 and s.help_text("nav").contains("Type: load"),"NAV confirms the three values before loading")
	s.command("nav","load")
	check(s.loaded and s.nav_stage==-1 and s.help_text("nav").contains("go comms"),"Loaded route advances to ATC")
	s.command("comms","request")
	check(s.help_text("comms").contains("code "+s.clearance),"ATC help gives the exact required readback")
	s.command("comms","code "+s.clearance)
	check(s.help_text("comms").contains("hatch close"),"Guide proceeds to the cargo hatch")
	s.hatch_closed=true
	s.closures_busy=true
	check(s.help_text("engine").contains("WAIT"),"Moving hardware has an explicit wait step")
	s.closures_busy=false
	check(s.help_text("engine").contains("ramp raise"),"Guide advances after hatch motion finishes")
	s.ramp_raised=true
	check(s.can_depart() and s.help_text("engine").contains("depart"),"Following help produces a takeoff-ready ship")
	var old_paper: Dictionary=s.printed_route.duplicate(true)
	s.command("chart","plot kepler direct")
	check(not s.paper_current() and s.printed_route==old_paper,"Replotting leaves the old paper unchanged and marks it superseded")
	s.command("chart","print")
	check(s.paper_current() and s.printed_route.id=="kepler","Reprinting creates the new destination sheet")
	var legacy: Dictionary=s.snapshot()
	for k in ["printed_route","entered_coords","route_serial","nav_stage"]: legacy.erase(k)
	legacy.elapsed=2000
	var migrated=State.new()
	check(migrated.restore(legacy) and migrated.plan.eta>migrated.elapsed+600,"Old saves migrate to an unhurried departure window")
	var corrupt: Dictionary=s.snapshot()
	corrupt.printed_route.erase("coords")
	check(not restored.restore(corrupt),"Invalid paper save is rejected safely")
	# Drive the physical terminals and real hardware using the new workflow.
	host.flight=State.new()
	host._take_seat()
	host.sync_hardware()
	var original_view: Transform3D=host.camera.transform
	host.open_terminal(host.terminals[1])
	host.active_terminal.submit("help")
	check(host.active_terminal.readout.text.contains("POWER THE ENGINES"),"Physical CRT displays contextual help")
	host.active_terminal.submit("go engine")
	check(host.active_terminal.kind=="engine","Go command moves the view to the physical engine terminal")
	host.active_terminal.submit("power on")
	host.active_terminal.submit("go fuel")
	host.active_terminal.submit("mixture 2.5")
	host.active_terminal.submit("go chart")
	host.active_terminal.submit("plot tharsis direct")
	host.active_terminal.submit("print")
	check(host.flight_sheet.feed.visible and host.flight.paper_current(),"Print produces a physical receipt at the chart printer")
	host.active_terminal.submit("go nav")
	host.flight_sheet.refresh()
	check(host.flight_sheet.held.visible,"Paper appears automatically beside NAV")
	var panel: Node3D=host.active_terminal.panel
	var extent: Vector2=panel.get_meta("display_size")
	var screen_bounds:=Rect2(host.camera.unproject_position(panel.to_global(Vector3(-extent.x/2,-extent.y/2,0.174))),Vector2.ZERO)
	for x in [-1,1]:
		for y in [-1,1]: screen_bounds=screen_bounds.expand(host.camera.unproject_position(panel.to_global(Vector3(x*extent.x/2,y*extent.y/2,0.174))))
	var paper: MeshInstance3D=host.flight_sheet.held
	var paper_size: Vector2=paper.mesh.size
	var paper_bounds:=Rect2(host.camera.unproject_position(paper.to_global(Vector3(-paper_size.x/2,-paper_size.y/2,0))),Vector2.ZERO)
	for x in [-1,1]:
		for y in [-1,1]: paper_bounds=paper_bounds.expand(host.camera.unproject_position(paper.to_global(Vector3(x*paper_size.x/2,y*paper_size.y/2,0))))
	print("GUIDE FRAMING screen ",screen_bounds," paper ",paper_bounds)
	var window:=Rect2(Vector2(8,8),host.get_viewport().get_visible_rect().size-Vector2(16,16))
	check(window.encloses(screen_bounds) and window.encloses(paper_bounds),"Both NAV and the paper fit in the viewport")
	check(screen_bounds.end.x+8<paper_bounds.position.x,"Paper does not obscure the NAV screen")
	host.active_terminal.submit("plot")
	host.active_terminal.submit(host.flight.coords_text())
	host.active_terminal.submit(str(host.flight.plan.burn))
	host.active_terminal.submit(str(host.flight.plan.reserve))
	host.active_terminal.submit("load")
	host.active_terminal.submit("go comms")
	host.active_terminal.submit("request")
	host.active_terminal.submit("code "+host.flight.clearance)
	host.active_terminal.submit("go engine")
	host.active_terminal.submit("hatch close")
	await host.get_tree().create_timer(0.8).timeout
	host.active_terminal.submit("ramp raise")
	await host.get_tree().create_timer(1.9).timeout
	host.active_terminal.submit("go comms")
	host.active_terminal.submit("depart")
	check(host.flight.phase=="departure","Paper and guided commands take off through real cockpit terminals")
	host.close_terminal()
	host.flight_sheet.refresh()
	check(not host.flight_sheet.held.visible and host.camera.transform.is_equal_approx(original_view),"Leaving terminal restores the pilot view after several terminal switches")
	print("LONGHAUL GUIDE ",passed," passed / ",failed," failed")
	return failed==0
