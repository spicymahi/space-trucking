extends RefCounted
## Back navigation restores presentation only, never replays ship commands.
const State=preload("res://scripts/longhaul_flight_state.gd")
var passed:=0
var failed:=0

func check(value: bool, description: String) -> void:
	if value: passed+=1
	else: failed+=1
	print("RETURN ",description,": ",value)

func type_command(terminal, text: String) -> void:
	for letter in text:
		var event:=InputEventKey.new()
		event.pressed=true
		event.unicode=letter.unicode_at(0)
		terminal.handle_key(event)
	var enter:=InputEventKey.new()
	enter.pressed=true
	enter.keycode=KEY_ENTER
	terminal.handle_key(enter)

func run(host) -> bool:
	var original_state=host.flight
	var original_views: Array=[]
	for terminal in host.terminals: original_views.append(terminal.view_snapshot())
	host.flight=State.new()
	host.close_terminal()
	var terminal=host.terminals[0]
	for role in terminal.VALID_ROLES:
		terminal.set_role(role)
		host.open_terminal(terminal)
		terminal.submit("help")
		check(terminal.readout.text.contains("return: previous screen"),role.to_upper()+" documents RETURN")
		type_command(terminal,"return")
		check(terminal.kind==role and terminal.show_live and terminal.lines.is_empty() and terminal.view_history.is_empty(),role.to_upper()+" returns from help to its live home screen")
	terminal.set_role("chart")
	terminal.chart_map.set_mode("system")
	terminal.submit("show brume")
	terminal.submit("station 09")
	var details: String=terminal.readout.text
	terminal.submit("help")
	terminal.submit("return")
	check(terminal.readout.text==details,"RETURN restores station details without retyping their query")
	terminal.submit("return")
	check(terminal.chart_map.visible and terminal.chart_map.mode=="body" and terminal.chart_map.selected_body==2,"Second RETURN restores the Brume neighborhood")
	terminal.submit("return")
	check(terminal.chart_map.mode=="system" and terminal.chart_map.selected_body==2,"Third RETURN reaches the overview and highlights Brume")
	terminal.submit("return")
	check(terminal.chart_map.mode=="system" and terminal.view_history.is_empty(),"Repeated RETURN at the overview is harmless and does not create a loop")
	terminal.submit("show aurel")
	terminal.submit("show slate")
	terminal.submit("show hush")
	terminal.submit("return")
	check(terminal.chart_map.selected_body==1,"RETURN restores the actual preceding moon rather than always choosing system")
	terminal.submit("map route")
	terminal.submit("return")
	check(terminal.chart_map.mode=="body" and terminal.chart_map.selected_body==1,"RETURN from journey view restores the previous body view")
	terminal.submit("show brum")
	terminal.submit("return")
	check(terminal.show_live and terminal.chart_map.selected_body==1,"RETURN recovers the map after an invalid body command")
	terminal.submit("show brum")
	host.close_terminal()
	host.open_terminal(terminal)
	terminal.submit("return")
	check(terminal.chart_map.mode=="body" and terminal.chart_map.selected_body==-1 and not terminal.readout.text.contains("Unknown"),"RETURN skips an already visible page after refocusing the terminal")
	terminal.submit("stations 1")
	var page: String=terminal.readout.text
	terminal.submit("stations 2")
	terminal.submit("return")
	check(terminal.readout.text==page,"RETURN restores the previous station-directory page")
	terminal.submit("display engine")
	terminal.submit("return")
	check(terminal.kind=="chart" and terminal.readout.text==page,"RETURN reverses a display-role change and restores its previous page")
	terminal.set_role("engine")
	terminal.submit("port on")
	terminal.submit("help")
	terminal.submit("return")
	check(host.flight.engines[0] and terminal.show_live,"RETURN shows current engine status without switching the engine off")
	terminal.set_role("nav")
	terminal.submit("reserve 333")
	terminal.submit("help")
	terminal.submit("return")
	check(is_equal_approx(host.flight.entered_reserve,333),"RETURN does not undo entered navigation settings")
	terminal.set_role("checklist")
	terminal.submit("print")
	var papers: int=host.flight.papers.size()
	terminal.submit("help")
	terminal.submit("return")
	check(host.flight.papers.size()==papers and papers==1,"RETURN to a print result does not print a second sheet")
	if host.print_camera_tween: host.print_camera_tween.kill()
	terminal.set_role("chart")
	terminal.chart_map.set_mode("system")
	terminal.submit("show brume")
	terminal.submit("station 09")
	details=terminal.readout.text
	var other=host.terminals[1]
	other.set_role("nav")
	terminal.submit("go nav")
	check(host.active_terminal==other,"GO opens the requested physical terminal")
	other.submit("help")
	other.submit("return")
	check(host.active_terminal==other and other.show_live,"RETURN first leaves the destination terminal's help page")
	other.submit("return")
	check(host.active_terminal==terminal and terminal.readout.text==details,"RETURN after GO returns to the original terminal and page")
	terminal.submit("return")
	check(terminal.chart_map.mode=="body" and terminal.chart_map.selected_body==2,"The original terminal's earlier map history still works after GO and RETURN")
	terminal.view_history.clear()
	terminal.restore_map_view({"mode":"body","body":7})
	terminal.submit("return")
	check(terminal.chart_map.mode=="system" and terminal.chart_map.selected_body==7,"A restored body view with no history can still RETURN to the overview")
	for i in 40: terminal.submit("show "+("brume" if i%2==0 else "slate"))
	check(terminal.view_history.size()<=terminal.VIEW_HISTORY_LIMIT,"Long browsing sessions keep a bounded history")
	host.close_terminal()
	host.flight=original_state
	for i in host.terminals.size():
		host.terminals[i].view_history.clear()
		host.terminals[i].restore_view(original_views[i])
	print("LONGHAUL RETURN ",passed," passed / ",failed," failed")
	return failed==0
