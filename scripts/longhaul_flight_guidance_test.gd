extends RefCounted
const State=preload("res://scripts/longhaul_flight_state.gd")
var passed:=0
var failed:=0
func check(value: bool, description: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("PAPER ",description,": ",value)

func screen_rect(host, mesh: MeshInstance3D) -> Rect2:
	var extent: Vector2=mesh.mesh.size
	var points: Array[Vector2]=[]
	for x in [-1,1]:
		for y in [-1,1]: points.append(host.camera.unproject_position(mesh.to_global(Vector3(x*extent.x/2,y*extent.y/2,0))))
	var result:=Rect2(points[0],Vector2.ZERO)
	for point in points: result=result.expand(point)
	return result

func run(host) -> bool:
	var s=State.new()
	check(s.command("nav","help")==s.command_reference("nav") and not s.command("nav","help").contains("NEXT STEP"),"Help is static reference, not a next-step guide")
	check(s.checklist().contains("PORT / STARBOARD") and s.checklist().contains("CARGO CLAMPS"),"Checklist shows all outstanding readiness items")
	s.command("checklist","print")
	check(s.papers.size()==1 and s.current_paper().kind=="checklist","Checklist creates a retained paper")
	s.command("engine","port on")
	s.command("engine","starboard on")
	s.command("chart","plot tharsis direct")
	check(not s.nav_selected,"Station meter remains inactive before NAV selection")
	s.command("chart","print")
	check(s.papers.size()==2 and s.current_paper().kind=="route","Route printing keeps the checklist")
	var route_number: int=s.selected_paper
	var old_coords: String=s.current_paper().data.coords
	s.command("nav","coords 1 2 3")
	s.command("nav","burn 6")
	s.command("nav","reserve 200")
	check(s.command("nav","load").contains("differ") and not s.loaded,"Mismatched typed coordinates rejected")
	s.command("nav","coords "+old_coords)
	s.command("nav","load")
	check(s.loaded and s.nav_selected,"Manual coordinates and fuel entries select NAV destination")
	s.command("nav","discard "+str(route_number))
	check(s.loaded and s.papers.size()==1,"Discarding route paper preserves navigation")
	s.command("chart","print")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
	var restored=State.new()
	check(restored.restore(saved) and restored.papers.size()==2 and restored.selected_paper==s.selected_paper,"Paper stack and selection survive save/load")
	s.command("chart","plot kepler direct")
	check(s.current_paper().data.coords==old_coords,"Replot does not rewrite existing paper")
	s.command("nav","coords "+old_coords)
	check(not s.load_route().contains("Route loaded"),"Old paper cannot load a different route")
	var invalid:=saved.duplicate(true)
	invalid.papers[0].number="bad"
	check(not restored.restore(invalid),"Malformed paper save rejected")
	var legacy:=saved.duplicate(true)
	for key in ["flight_revision","engines","autopilot","auto_docking","arrival_hold","nav_selected","papers","trail","paper_serial","selected_paper","paper_visible"]: legacy.erase(key)
	check(restored.restore(legacy) and restored.engines==[true,true] and restored.loaded,"Previous build save migrates with engines and route intact")
	s.command("nav","discard all")
	check(s.papers.is_empty() and not s.paper_visible,"All paper can be recycled")
	for i in 12: s.print_checklist()
	check(s.print_checklist().contains("full") and s.papers.size()==12,"Paper rack capacity is explicit; existing sheets are retained")
	# Real scene: print animation, terminal layout and physical input isolation.
	host.flight=State.new()
	host.flight.paper_visible=false
	host.flight_sheet.refresh()
	host._take_seat()
	var camera_before: Transform3D=host.camera.transform
	host.terminal_command("nav","go checklist")
	check(host.active_terminal.kind=="checklist","Checklist is an accessible physical terminal")
	host.active_terminal.submit("print")
	check(host.flight_sheet.printing and host.flight.papers.size()==1,"Print command starts motor feed")
	check(host.terminal_command("chart","print").contains("busy"),"Busy printer preserves current sheet")
	await host.get_tree().create_timer(0.6).timeout
	check(host.flight_sheet.progress>0 and host.flight_sheet.progress<1 and host.flight_sheet.feed.scale==Vector3.ONE,"Printing translates rigid paper through slot without scaling")
	await host.get_tree().create_timer(1.8).timeout
	host.flight_sheet.refresh()
	check(not host.flight_sheet.printing and host.flight_sheet.held.visible,"Completed print becomes readable copy")
	var body: Label=host.flight_sheet.body
	check(body.position.y+body.get_minimum_size().y<=1280,"Entire checklist fits printed page")
	print("PAGE HEIGHT ",body.get_minimum_size()," at ",body.position)
	host.terminal_command("checklist","go engine")
	host.active_terminal.submit("port on")
	host.active_terminal.submit("starboard on")
	check(host.active_terminal.readout.text.contains("STARBOARD: ON"),"Physical ASCII diagram responds to CLI")
	host.terminal_command("engine","go chart")
	host.active_terminal.submit("plot tharsis direct")
	host.active_terminal.submit("print")
	await host.get_tree().create_timer(2.4).timeout
	host.terminal_command("chart","go nav")
	host.flight_sheet.refresh()
	await host._frames(4)
	check(host.flight_sheet.body.position.y+host.flight_sheet.body.get_minimum_size().y<=1280,"Entire route and command text fit printed page")
	var details: Label=host.flight_sheet.viewport.get_node("Details")
	check(details.position.y+details.get_minimum_size().y<1280,"Fuel notes and paper controls fit below the enlarged commands")
	var paper_rect:=screen_rect(host,host.flight_sheet.held)
	var screen_mesh: MeshInstance3D=host.active_terminal.panel.get_meta("screen_mesh")
	var nav_rect:=screen_rect(host,screen_mesh)
	var view: Rect2=host.get_viewport().get_visible_rect()
	check(view.encloses(paper_rect) and view.encloses(nav_rect) and not paper_rect.intersects(nav_rect),"NAV and reference paper fit side by side")
	check(host.flight_sheet.viewport.get_node("Commands").text.contains("coords "+host.flight.coords_text()) and host.flight_sheet.viewport.get_node("Commands").text.contains("reserve 200"),"Route paper prints exact NAV commands")
	for line in ["coords "+host.flight.coords_text(),"burn 6","reserve 200","load"]: host.active_terminal.submit(line)
	check(host.flight.loaded,"Commands from physical printed sheet load NAV")
	var distance_terminal=null
	var map_terminal=null
	for terminal in host.terminals:
		if terminal.kind=="distance": distance_terminal=terminal
		if terminal.kind=="map": map_terminal=terminal
	distance_terminal.refresh()
	check(distance_terminal.panel.position.x>0 and distance_terminal.panel.position.y>2 and distance_terminal.readout.text.contains("THARSIS"),"Upper-right meter displays selected station distance")
	check(map_terminal.panel.position.x==0 and map_terminal.panel.position.y>2 and map_terminal.chart_map!=null,"Live map occupies upper-middle screen")
	host.flight.nav_selected=false
	distance_terminal.refresh()
	check(distance_terminal.readout.text.is_empty(),"Distance value is hidden without NAV destination")
	host.close_terminal()
	check(host.camera.transform.is_equal_approx(camera_before),"Visiting several terminals and printer restores seat view")
	host.flight_sheet.refresh()
	await host._frames(2)
	check(view.encloses(screen_rect(host,host.flight_sheet.held)),"Full-page paper reader fits viewport")
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_DELETE
	event.keycode=KEY_DELETE
	event.pressed=true
	host._unhandled_input(event)
	check(host.flight.papers.size()==1,"Delete recycles held route sheet")
	event.physical_keycode=KEY_P
	event.keycode=KEY_P
	host._unhandled_input(event)
	check(not host.flight.paper_visible,"P stows paper to clear view")
	print("LONGHAUL PAPER CHECKS ",passed," passed / ",failed," failed")
	return failed==0
