extends RefCounted
const State=preload("res://scripts/longhaul_flight_state.gd")
var passed:=0
var failed:=0
func check(value: bool, description: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("PAPER ",description,": ",value)

func screen_rect(host, mesh: MeshInstance3D) -> Rect2:
	var points: Array[Vector2]=[]
	# Imported screens have baked mesh coordinates rather than QuadMesh.size.
	for surface in mesh.mesh.get_surface_count():
		for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			points.append(host.camera.unproject_position(mesh.to_global(vertex)))
	var result:=Rect2(points[0],Vector2.ZERO)
	for point in points: result=result.expand(point)
	return result

func press(host, code: Key, shift:=false) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	event.shift_pressed=shift
	host._unhandled_input(event)

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
	check(not host.flight_sheet.printing and not host.flight_sheet.feed.visible,"Collected print leaves the tray empty")
	check(not host.flight_sheet.held.visible,"Collected sheet waits in rack until pinned")
	host.active_terminal.entry="port "
	press(host,KEY_TAB)
	check(host.paper_pinned and host.flight_sheet.held.visible and host.active_terminal.entry=="port ","Tab pins paper without altering CLI input")
	press(host,KEY_TAB)
	check(not host.paper_pinned and not host.flight_sheet.held.visible,"Tab stows paper without CLI command")
	press(host,KEY_TAB)
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
	press(host,KEY_TAB)
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
	var velocity_terminal=null
	var radar_terminal=null
	for terminal in host.terminals:
		if terminal.kind=="distance": distance_terminal=terminal
		if terminal.kind=="velocity": velocity_terminal=terminal
		if terminal.kind=="radar": radar_terminal=terminal
	distance_terminal.refresh()
	check(distance_terminal.panel.position.x>0 and distance_terminal.panel.position.y>2 and distance_terminal.readout.text.contains("THARSIS"),"Upper-right meter displays selected station distance")
	check(velocity_terminal.panel.position.x==0 and velocity_terminal.panel.position.y>2,"Relative velocity occupies upper-middle screen")
	check(radar_terminal.panel.position.x<0 and radar_terminal.panel.position.y>2,"Station radar occupies upper-left screen")
	check(host.terminals[0].kind=="chart" and host.terminals[0].chart_map!=null,"Journey map remains in lower-left CHART")
	host.flight.nav_selected=false
	distance_terminal.refresh()
	check(distance_terminal.readout.text.is_empty(),"Distance value is hidden without NAV destination")
	host.close_terminal()
	check(host.camera.transform.is_equal_approx(camera_before),"Visiting several terminals and printer restores seat view")
	press(host,KEY_P)
	host.flight_sheet.refresh()
	await host._frames(2)
	check(view.encloses(screen_rect(host,host.flight_sheet.held)),"Full-page paper reader fits viewport")
	press(host,KEY_DELETE)
	check(host.flight.papers.size()==1,"Delete recycles held route sheet")
	press(host,KEY_P)
	check(not host.flight.paper_visible,"P stows paper to clear view")
	# Display assignment targets the exact physical screen, even with duplicate roles.
	var target=host.terminals[6]
	host.open_terminal(target)
	target.submit("display NAV")
	check(target.kind=="nav" and host.terminals[1].kind=="nav","Case-insensitive display NAV remaps selected screen only")
	target.submit("display RADAR")
	check(target.kind=="radar" and host.terminals[5].kind=="radar","Duplicate roles are allowed")
	target.submit("display bogus")
	check(target.kind=="radar" and target.readout.text.contains("Unknown display"),"Bad display name is visible and preserves role")
	press(host,KEY_TAB)
	await host._frames(2)
	check(host.flight_sheet.held.visible,"Paper can be pinned at overhead radar too")
	var overhead_rect:=screen_rect(host,target.panel.get_meta("screen_mesh"))
	paper_rect=screen_rect(host,host.flight_sheet.held)
	check(view.encloses(overhead_rect) and view.encloses(paper_rect) and not paper_rect.intersects(overhead_rect),"Paper and reassigned overhead screen fit together")
	check(host.save_session("/tmp/longhaul-display-layout-test.json").contains("saved"),"Screen assignments save with flight")
	target.set_role("fuel")
	host.paper_pinned=false
	check(host.load_session("/tmp/longhaul-display-layout-test.json").contains("restored") and target.kind=="radar" and host.paper_pinned,"Screen assignments and paper pin restore")
	var stored=JSON.parse_string(FileAccess.get_file_as_string("/tmp/longhaul-display-layout-test.json"))
	stored.display_roles[0]="invalid"
	var file:=FileAccess.open("/tmp/longhaul-display-layout-bad.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(stored))
	file.close()
	check(host.load_session("/tmp/longhaul-display-layout-bad.json").contains("invalid") and target.kind=="radar","Malformed display layout does not mutate live state")
	# Real keyboard events drive vertical flight using Space and Control.
	host.paper_pinned=false
	host.flight.paper_visible=false
	host.flight=State.new()
	host.flight.command("engine","port on")
	host.flight.command("engine","starboard on")
	host.flight.phase="departure"
	host._take_seat()
	host.test_running=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var input:=InputEventKey.new()
	input.keycode=KEY_SPACE
	input.physical_keycode=KEY_SPACE
	input.pressed=true
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	host._physics_process(0.2)
	check(host.flight.acceleration.y>1,"Space applies upward thrust in manual flight")
	input=input.duplicate()
	input.pressed=false
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	input=InputEventKey.new()
	input.keycode=KEY_CTRL
	input.physical_keycode=KEY_CTRL
	input.pressed=true
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	host._physics_process(0.2)
	check(host.flight.acceleration.y < -1,"Control applies downward thrust in manual flight")
	input=input.duplicate()
	input.pressed=false
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	host.test_running=true
	# Reproduce returning to the chair with a walking key still held, then standing again.
	host.flight.phase="docked"
	host.flight.plan_route("tharsis")
	host.flight.entered_coords=host.flight.plan.target
	host.flight.entered_burn=6
	host.flight.entered_reserve=200
	host.flight.load_route()
	host.flight.phase="departure"
	host.flight.ship_position=host.flight.station_position(0,host.flight.elapsed)+Vector3(0,0,-500)
	host.flight.engage_navigation()
	host.camera.rotation=Vector3(-1,0,0)
	press(host,KEY_F)
	check(not host.seated and host.flight.autopilot,"Standing from pilot seat keeps NAV engaged")
	host.camera.rotation=Vector3(-1,0,0)
	press(host,KEY_F)
	check(host.seated and host.flight.autopilot,"Returning to pilot seat keeps NAV engaged")
	input=InputEventKey.new()
	input.keycode=KEY_W
	input.physical_keycode=KEY_W
	input.pressed=true
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	host.test_running=false
	host._physics_process(0.2)
	host.test_running=true
	check(host.flight.autopilot,"Held movement key after sitting cannot cancel NAV")
	input=input.duplicate()
	input.pressed=false
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	host.camera.rotation=Vector3(-1,0,0)
	press(host,KEY_F)
	check(not host.seated and host.flight.autopilot,"Pilot can stand again without entering engage twice")
	print("LONGHAUL PAPER CHECKS ",passed," passed / ",failed," failed")
	return failed==0
