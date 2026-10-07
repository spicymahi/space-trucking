extends "res://scripts/cargo_trial.gd"
## Complete cargo + original flight + daily survival test, with an independent save.
const LifeState=preload("res://scripts/ship_life_state.gd")
const LifeEconomy=preload("res://scripts/ship_life_economy.gd")
const LifeArt=preload("res://scripts/ship_life_visuals.gd")
const LIFE_SAVE="user://ship_life_v1.json"
const CHECKPOINT="user://ship_life_departure_v1.json"
const WORLD_HOURS_PER_SECOND:=LifeEconomy.WORLD_HOURS_PER_SECOND
const FOOD_PRICE:=8
const WATER_PRICE:=4
const FUEL_PRICE:=0.08
var life:=LifeState.new()
var life_economy:=LifeEconomy.new()
var life_art:Node3D
var fixtures:Dictionary
var life_hand:Node3D
var visual_hand_key:="!"
var shower_on:=false
var printed:=false
var paper_in_tray:=false
var terminal_history:Array[String]=[]
var terminal_live:=false
var paper_open:=false
var daily_paper:Node3D
var paper_text:=""
var paper_stowed:=false
var paper_terminal_hidden:=false
var aim_dot:Control
var paused_life:=false
var seated_pilot:=false
var seated_table:=false
var skip:Dictionary={}
var skip_screen:ColorRect
var skip_bar:ProgressBar
var skip_label:Label
var life_ready:=false
var autosave_seconds:=0.0
var observed_phase:="docked"
var printed_timer:=0.0
var demo_mode:=false
var session_notice:=""

func _create_ship() -> Node3D:
	return preload("res://scripts/ship_life_flight.gd").new()

func _ready() -> void:
	economy=life_economy
	super._ready()
	tool.hide()
	DisplayServer.window_set_title("Space Trucking — Complete Ship Life Test")
	ship.configure(self)
	life_art=LifeArt.new();fixtures=life_art.build(self,ship)
	daily_paper=preload("res://scripts/ship_life_paper.gd").new();daily_paper.build(camera)
	for child in hud.get_parent().get_children():
		if child is Label and child.text=="+":aim_dot=child
	_build_skip_ui()
	life_ready=true
	life.begin_station_visit()
	message("SHIP LIFE TEST: F at CONTRACTS to accept work. PROVISIONS sells food/water days and fuel. Hab computer prints your daily routine. F1 opens the test guide.")
	var args:=OS.get_cmdline_user_args()
	if "--ship-life-test" in args:
		_run_life_tests.call_deferred()
	elif "--ship-life-capture" in args:
		_capture_life.call_deferred()
	elif FileAccess.file_exists(LIFE_SAVE) and "--ship-life-new" not in args:
		message(load_life())
	else:
		save_life(CHECKPOINT)
	refresh_dock_visibility()

func _build_skip_ui() -> void:
	var layer:=CanvasLayer.new();layer.layer=30;add_child(layer)
	skip_screen=ColorRect.new();skip_screen.color=Color.BLACK;layer.add_child(skip_screen)
	skip_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip_label=Label.new();skip_screen.add_child(skip_label)
	skip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER);skip_label.offset_left=-430;skip_label.offset_right=430;skip_label.offset_top=-90;skip_label.offset_bottom=40
	skip_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	skip_label.add_theme_font_override("font",FONT);skip_label.add_theme_font_size_override("font_size",28)
	skip_bar=ProgressBar.new();skip_screen.add_child(skip_bar)
	skip_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER);skip_bar.offset_left=-320;skip_bar.offset_right=320;skip_bar.offset_top=65;skip_bar.offset_bottom=90
	skip_screen.hide()

func _process(delta:float) -> void:
	if not life_ready:return
	toast_timer=maxf(0,toast_timer-delta);toast.visible=toast_timer>0 and not paper_open and not panel.visible and ship.active_terminal==null
	hud.visible=not paper_open
	if aim_dot:aim_dot.visible=not paper_open and not panel.visible
	var title:String="NO CONTRACT" if economy.active.is_empty() else economy.active.id+" / "+economy.active.phase.to_upper()
	hud.text="%s / %s\n%s   %d CR   FOOD %dd   WATER %dd   HYGIENE %d%%\nRACKED %d/%d / STAGED %d   F1 GUIDE / H PAPER / TAB READ / F5 SAVE / F9 LOAD" % [life.time_text(),ship.flight.phase.to_upper(),title,economy.credits,life.food_stock,life.water_stock,life.hygiene,packing.placements.size(),parcels.size(),stage_count()]
	if paused_life:prompt.text="PAUSED / ESC RESUME";return
	if life.game_over:
		skip_screen.show();skip_bar.hide();skip_label.text="RESCUE / RUN ENDED\nEmergency rest exhausted.\nF9 reloads the departure checkpoint."
		return
	if not skip.is_empty():
		_process_skip(delta)
		return
	if panel.visible and terminal_live:readout.text=_terminal_text(terminal_mode)
	if panel.visible or ship.active_terminal!=null:
		ghost.hide();prompt.text="ESC BACK / TAB FLIGHT PAPER" if ship.active_terminal else "ESC CLOSE"
	elif paper_open:prompt.text="TAB LOWER CHECKLIST / H STOW / F AT HAB BIN TO RECYCLE"
	else:_update_aim()
	if not paused_life:
		life.tick_interactions(delta,shower_on and LifeArt.SHOWER_BOUNDS.has_point(ship.to_local(walker.global_position)))
	printed_timer=maxf(0,printed_timer-delta)
	_update_life_visuals()
	if daily_paper.visible and not paper_open and ship.active_terminal==null and not panel.visible:
		prompt.text += "\n[H] STOW PAPER    [TAB] READ CLOSER    [F] AT RECYCLING BIN TO DISCARD"
	if ship.flight.warning_serial!=ship.seen_warning:
		ship.seen_warning=ship.flight.warning_serial
		message(ship.flight.warning)
	if ship.active_terminal==null and ship.flight.paper_visible:prompt.text="P STOW FLIGHT PAPER / TAB PIN / DELETE RECYCLE"

func _physics_process(delta:float) -> void:
	if not life_ready or paused_life or life.game_over or not skip.is_empty():return
	if not seated_pilot and not seated_table and not paper_open and ship.active_terminal==null:super._physics_process(delta)
	else:walker.velocity=Vector3.ZERO
	var thrust:=Vector3.ZERO;var rotation_input:=Vector3.ZERO
	var piloting:bool=seated_pilot and not paper_open and ship.active_terminal==null and not panel.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	if piloting:
		thrust=Vector3(ship.key(KEY_D)-ship.key(KEY_A),ship.key(KEY_SPACE)-ship.key(KEY_CTRL),ship.key(KEY_S)-ship.key(KEY_W))
		rotation_input=Vector3(ship.key(KEY_UP)-ship.key(KEY_DOWN),ship.key(KEY_LEFT)-ship.key(KEY_RIGHT),ship.key(KEY_Q)-ship.key(KEY_E))
		if Input.is_physical_key_pressed(KEY_SHIFT):thrust*=0.12;rotation_input*=0.25
	if "--ship-life-test" not in OS.get_cmdline_user_args():_advance_simulation(delta,thrust,rotation_input,piloting and Input.is_physical_key_pressed(KEY_X))
	autosave_seconds+=delta
	if autosave_seconds>=45 and "--ship-life-test" not in OS.get_cmdline_user_args():
		autosave_seconds=0;save_life()

func _advance_simulation(seconds:float,thrust:=Vector3.ZERO,rotation_input:=Vector3.ZERO,stop:=false) -> float:
	if seconds<=0:return 0
	ship.sync_hardware()
	var before:float=ship.flight.elapsed
	if ship.flight.phase=="docked":
		ship.flight.elapsed+=seconds
		ship.flight.ship_position=ship.flight.station_position(ship.flight.dock_id,ship.flight.elapsed)
		ship.flight.velocity=ship.flight.station_velocity(ship.flight.dock_id,ship.flight.elapsed)
	else:
		ship.flight.warp=1;ship.flight.sleeping=false
		ship.flight.tick(seconds,thrust,rotation_input,stop)
	var actual:float=maxf(0,ship.flight.elapsed-before)
	var before_day:int=life.day()
	life.advance(actual*WORLD_HOURS_PER_SECOND)
	if before_day!=life.day() and printed:
		message("New shipboard day. Collect a new work order from the hab printer.")
	life_economy.tick(actual*WORLD_HOURS_PER_SECOND)
	ship._update_flight_world()
	if ship.flight.phase=="docked" and observed_phase!="docked":_arrived()
	observed_phase=ship.flight.phase
	return actual*WORLD_HOURS_PER_SECOND

func refresh_dock_visibility() -> void:
	if dock.is_empty():return
	var dock_root:Node3D=dock.terminal.get_parent()
	var active:bool=ship.flight.phase=="docked"
	dock_root.visible=active
	for body in dock_root.find_children("*","StaticBody3D",true,false):body.collision_layer=1 if active else 0
	if life_art:
		for action in ["provisions","repairs"]:
			if fixtures.targets.has(action):
				var body:Node3D=fixtures.targets[action]
				body.get_parent().visible=active
				body.collision_layer=5 if active else 0

func _update_aim() -> void:
	if not life_ready:super._update_aim();return
	super._update_aim()
	if held>=0:return
	var term=ship.aimed_terminal()
	if term:prompt.text="[F] USE "+term.kind.to_upper()+" COMPUTER";return
	var hit:=_life_hit()
	if not hit.is_empty():
		var action:String=hit.collider.get_meta("life_action","")
		prompt.text="[F] "+_action_hint(action)
		return
	var service:Dictionary=ship.service_module.interaction(camera,walker)
	if not service.is_empty():prompt.text="[F] "+str(service.get("label",service.action));return
	if seated_table:prompt.text="[F] EAT / PICK UP PLATE    [G] STAND";return
	if life.hand_item=="water_glass":prompt.text="[F] DRINK WATER / THEN RETURN GLASS TO SINK";return
	if seated_pilot:prompt.text="W/S THRUST  A/D STRAFE  SPACE/CTRL LIFT  ARROWS STEER  X STOP ROTATION\n[G] LEAVE SEAT / F USE COMPUTER";return
	if walker.position.z< -9.0 and walker.position.distance_to(Vector3(0,0,-10.45))<2.1:prompt.text="[G] TAKE PILOT SEAT / F USE COMPUTER"

func _life_hit() -> Dictionary:
	var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*2.8,5,[walker.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit if not hit.is_empty() and hit.collider.has_meta("life_action") else {}

func _action_hint(action:String) -> String:
	match action:
		"fridge":return "TAKE FOOD / %d DAYS STOCKED"%life.food_stock
		"oven":return "OVEN / "+(life.oven_state.to_upper() if not life.oven_state.is_empty() else "INSERT FOOD")
		"table":return "SET MEAL" if life.hand_item=="meal" else ("EAT / %d BITES LEFT"%life.table_bites if life.table_bites>0 else ("PICK UP DIRTY PLATE" if life.table_bites==0 else "TABLE"))
		"sink":return "WASH PLATE / GLASS"
		"cabinet":return "TAKE GLASS"
		"water":return "FILL GLASS / %d DAYS WATER"%life.water_stock
		"bunk":return "REST / SLEEP TO 06:00 OR PASS TIME"
		"hab":return "HAB / STORES AND DAILY CHECKLIST"
		"paper":return "READ DAILY CHECKLIST"
		"trash":
			if not printed or paper_in_tray:return "PAPER RECYCLING / NO PAPER HELD"
			return "RECYCLE HELD PAPER" if not paper_stowed else "PAPER RECYCLING / H TO RETRIEVE YOUR SHEET"
		"shower":return "SHOWER "+("OFF" if shower_on else "ON")
		"sensors":return "ENGINEERING / SENSOR STATUS"
		"provisions":return "PORT PROVISIONS / FOOD, WATER, FUEL"
		"repairs":return "PORT SENSOR REPAIRS"
	return action.to_upper()

func _use() -> void:
	if held>=0:super._use();return
	var terminal=ship.aimed_terminal()
	if terminal:
		if not life.hand_item.is_empty():message("Put your dish or glass in its place before using the cockpit.");return
		ship.open_terminal(terminal);return
	var hit:=_life_hit()
	if not hit.is_empty():_use_life(hit.collider.get_meta("life_action"));return
	if seated_table:_use_life("table");return
	if life.hand_item=="water_glass":_use_life("drink");return
	var service:Dictionary=ship.service_module.interaction(camera,walker)
	if not service.is_empty() and service.action in ["wash_door","air_door","wash_inside","air_inside"]:ship.service_module.use(service.action);return
	if not life.hand_item.is_empty():message("Your hand tool is holding "+life.hand_item.replace("_"," ")+". Finish the kitchen task first.");return
	super._use()

func _use_life(action:String) -> void:
	if held>=0:message("Put the cargo down before using the hab.");return
	if action in ["hab","sensors","provisions","repairs","bunk"]:open_terminal(action);return
	if action=="paper":
		_collect_daily_paper()
		return
	if action=="trash":
		if not life.hand_item.is_empty():message("The paper bin only accepts paper. Put your dish or glass away.");return
		if not printed or paper_in_tray:message("You have no collected paper to recycle.");return
		if paper_stowed:message("Press H to take out your checklist, then F to recycle it.");return
		_discard_daily_paper();life_art.recycle_paper();message("Checklist placed in the recycling bin. Hands empty.");return
	if action=="shower":
		shower_on=not shower_on;message("Shower running. Stand under the water to wash." if shower_on else "Shower off.");return
	if action=="water":action="cooler"
	var was_plate:int=life.table_bites
	var reply:String=life.interact(action)
	if not life.hand_item.is_empty():_stow_daily_paper()
	if action=="table" and was_plate<0 and life.table_bites>0:
		_sit_at_table()
	message(reply);_update_life_visuals()

func _sit_at_table() -> void:
	seated_table=true
	var seat:Vector3=life_art.dining_seat.global_position
	walker.global_position=Vector3(seat.x,ship.global_position.y+0.05,seat.z)
	walker.velocity=Vector3.ZERO;walker.rotation=Vector3.ZERO
	camera.global_position=seat+Vector3(0,0.72,0)
	camera.look_at(life_art.table_plate.global_position+Vector3(0,0.04,0),Vector3.UP)
	pitch=camera.rotation.x

func _collect_daily_paper() -> void:
	if not printed or not paper_in_tray or printed_timer>0:return
	if held>=0 or not life.hand_item.is_empty():message("Put your carried item away before collecting the sheet.");return
	paper_in_tray=false;paper_stowed=false
	ship.flight.paper_visible=false;ship.paper_pinned=false;ship.flight_sheet.refresh()
	message("Checklist in hand. H stows it; TAB reads closer. F at the galley recycling bin throws it away.")
	_update_life_visuals()

func _stow_daily_paper() -> void:
	if paper_open:_set_paper_open(false)
	paper_stowed=true

func pick_case(id:int) -> bool:
	if not life.hand_item.is_empty():return false
	var picked:=super.pick_case(id)
	if picked:_stow_daily_paper()
	_update_life_visuals()
	return picked

func place_held(target:Dictionary) -> bool:
	var placed:=super.place_held(target)
	_update_life_visuals()
	return placed

func _set_paper_open(value:bool) -> void:
	paper_open=value
	if value:
		paper_stowed=false
		ship.flight.paper_visible=false;ship.paper_pinned=false;ship.flight_sheet.refresh()
		paper_terminal_hidden=panel.visible
		if paper_terminal_hidden:panel.hide();command.release_focus()
	else:
		if paper_terminal_hidden:panel.show();command.grab_focus()
		paper_terminal_hidden=false
	daily_paper.set_closeup(value)
	_update_life_visuals()

func _discard_daily_paper() -> void:
	_set_paper_open(false)
	printed=false;paper_in_tray=false;paper_text="";paper_stowed=false;printed_timer=0
	_update_life_visuals()

func _daily_paper_key(event:InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:return false
	var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if not life_ready or paused_life or life.game_over or not skip.is_empty():return false
	if code==KEY_ESCAPE and paper_open:_set_paper_open(false);return true
	var carried:bool=printed and not paper_in_tray
	# Flight terminals retain their established route-paper controls.
	if ship.active_terminal!=null or (ship.flight.paper_visible and not panel.visible and not paper_open):return false
	if code==KEY_TAB and carried:
		if paper_stowed:message("Checklist is stowed. Press H to take it out first.");return true
		if held>=0 or not life.hand_item.is_empty():message("Put your carried item away to read the checklist.");return true
		_set_paper_open(not paper_open);return true
	if code in [KEY_H,KEY_J] and not panel.visible:
		if not carried:message("Collect the printed checklist from the hab printer with F.");return true
		if paper_stowed and (held>=0 or not life.hand_item.is_empty()):message("Put your carried item away before taking out the checklist.");return true
		if paper_open:_set_paper_open(false)
		paper_stowed=not paper_stowed
		message("Checklist stowed. Hands empty. H retrieves it." if paper_stowed else "Checklist in hand. TAB reads closer; F at the galley bin recycles it.")
		_update_life_visuals();return true
	if code in [KEY_DELETE,KEY_BACKSPACE] and carried and not paper_stowed and (not panel.visible or paper_open):
		_discard_daily_paper();message("Daily sheet recycled.");return true
	return false

func _input(event:InputEvent) -> void:
	# Capture Tab before a terminal LineEdit consumes it for keyboard focus.
	if _daily_paper_key(event):get_viewport().set_input_as_handled()

func _unhandled_input(event:InputEvent) -> void:
	if not life_ready:return
	if _daily_paper_key(event):return
	if event is InputEventKey and event.pressed and not event.echo:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_F9:message(load_life(CHECKPOINT if life.game_over else LIFE_SAVE));return
		if life.game_over:return
		if code==KEY_F5:message(save_life());return
		if not skip.is_empty():
			if code==KEY_ESCAPE:_end_skip("Rest interrupted.")
			return
		if code==KEY_F1:open_terminal("guide");return
		if ship.active_terminal:
			if ship.paper_key(event):return
			if code==KEY_ESCAPE:ship.close_terminal()
			else:ship.active_terminal.handle_key(event)
			return
		if code==KEY_ESCAPE:
			if panel.visible:panel.hide();paper_open=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			else:paused_life=not paused_life;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused_life else Input.MOUSE_MODE_CAPTURED
			return
		if paused_life:return
		if panel.visible:return
		if paper_open:return
		if code==KEY_G:
			if seated_table:
				seated_table=false;walker.position=Vector3(0,0.05,-4.65);walker.rotation=Vector3.ZERO;camera.position.y=1.62;pitch=0;camera.rotation=Vector3.ZERO;return
			if held>=0 or not life.hand_item.is_empty():message("Put your carried item away first.");return
			if seated_pilot:
				if ship.flight.phase!="docked" and not ship.flight.autopilot:message("Engage NAV before leaving the pilot seat.");return
				seated_pilot=false;walker.position=Vector3(0,0.05,-10.32);camera.rotation=Vector3.ZERO;pitch=0
			elif walker.position.z< -9:
				ship._take_seat();seated_pilot=true;pitch=ship.pitch
			return
		if code==KEY_P and seated_pilot:ship.flight.paper_visible=not ship.flight.paper_visible;ship.flight_sheet.refresh();return
		if ship.paper_key(event):return
	if paused_life or not skip.is_empty() or ship.active_terminal or paper_open:return
	super._unhandled_input(event)

func _update_life_visuals() -> void:
	if not life_art:return
	var display:Dictionary=life.snapshot()
	if printed and life.printed_day==life.day():paper_text=life.checklist_text()
	display.shower_on=shower_on;display.printed=printed and paper_in_tray;display.print_progress=1.0-printed_timer;display.paper_text=paper_text;display.sensor_summary=life.sensor_text()
	life_art.refresh(display)
	if daily_paper:
		daily_paper.set_text(paper_text)
		daily_paper.visible=printed and not paper_in_tray and not paper_stowed and held<0 and life.hand_item.is_empty() and ship.active_terminal==null and not ship.flight.paper_visible and not panel.visible and skip.is_empty()
	var key:String=life.hand_item+str(life.hand_bites)
	if key!=visual_hand_key:
		visual_hand_key=key
		if is_instance_valid(life_hand):life_hand.queue_free()
		life_hand=life_art.hand_prop(life.hand_item,life.hand_bites)
		if life_hand:
			camera.add_child(life_hand);life_hand.position=Vector3(0.24,-0.31,-0.62)
	tool.visible=held>=0 and not panel.visible and ship.active_terminal==null and not paper_open

func open_terminal(mode:String) -> void:
	if paper_open:_set_paper_open(false)
	terminal_mode=mode
	terminal_history.clear()
	terminal_live=mode in ["hab","daily","sensors","provisions","bunk"]
	panel.get_child(0).get_child(0).text="K-01 / "+mode.to_upper()+"                         ESC / CLOSE"
	output=_terminal_text(mode)
	readout.text=output;panel.show();command.clear();command.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	command.placeholder_text="Type a command shown above and press Enter"

func _terminal_text(mode:String) -> String:
	match mode:
		"hab","daily":return life.stock_text()+"\n\n"+_daily_summary()+"\n\nstock / checklist / print / status / save / load"
		"sensors":return life.calibration_text() if not life.calibration.is_empty() else life.sensor_text()
		"provisions":return _provisions_text()
		"repairs":return life.sensor_text()+"\n\nREPAIR ALL: %d CR\nquote <sensor|all> / repair <sensor|all>\nrepair emergency : repair failed sensors on account if funds are short."%life.repair_quote()
		"bunk":return life.time_text()+"\n"+life.stock_text()+"\n\nsleep : bedtime 20:00–06:00, wake next 06:00\npass : complete checklist, then pass until bedtime\nemergency : inadequate supplies, 3 uses between port resupply\nFourth emergency rest ends the run.\n\n"+_travel_text()
		"guide":return _guide_text()
		"depart":return _status()+"\n\nFLIGHT: use cockpit checklist, CHART/NAV and COMMS.\n\nstart test : optional prepared cruise for testing ship life immediately\nThis test shortcut requires loaded/locked cargo and enough fuel; buys nothing.\nNormal departure and manual flying remain available in the cockpit."
		"plan":return _packing_plan()
		_:return _job_board()

func _command(text:String) -> void:
	var words:=text.strip_edges().to_lower().split(" ",false)
	if words.is_empty():return
	var op:String=words[0]
	if op=="return":
		terminal_live=false
		output=terminal_history.pop_back() if not terminal_history.is_empty() else _terminal_text(terminal_mode)
		readout.text=output;command.clear();return
	var previous_output:String=readout.text
	terminal_live=false
	if op=="save":output=save_life()
	elif op=="load":output=load_life()
	elif op=="status":output=_terminal_text(terminal_mode);terminal_live=terminal_mode in ["hab","daily","sensors","provisions","bunk"]
	elif op=="stock":output=life.stock_text()+"\n\n"+_travel_text()
	elif op=="checklist":output=_daily_summary()
	elif op=="print" and terminal_mode in ["hab","daily"]:
		if printed:output="An existing sheet is in the tray or your possession. Recycle it at the galley bin, or use Delete / discard before printing another."
		else:
			printed=true;paper_in_tray=true;printed_timer=1.0;paper_text=life.print_checklist()
			output="PRINTING / DAILY WORK ORDER\nCollect the sheet from the tray with F.\nH stows/retrieves it; TAB brings it closer.\nF at the galley recycling bin throws it away."
	elif op=="discard":_discard_daily_paper();output="Daily paper recycled. Print another at the hab terminal."
	elif op=="check" and terminal_mode=="sensors" and words.size()==2:output=life.check_sensor(words[1])
	elif op=="trim" and terminal_mode=="sensors" and words.size()==3 and words[2].is_valid_int():output=life.trim_sensor(words[1],int(words[2]))
	elif op=="test" and terminal_mode=="sensors":output=life.submit_sensor()+"\n\n"+life.sensor_text()
	elif op=="resume" and terminal_mode=="sensors":output=life.calibration_text()
	elif op=="cancel" and terminal_mode=="sensors":output=life.cancel_calibration()
	elif op in ["sleep","pass","emergency"] and terminal_mode=="bunk":output=start_rest(op)
	elif op=="buy" and terminal_mode=="provisions" and words.size()==3 and words[2].is_valid_int():output=buy_provisions(words[1],int(words[2]))
	elif op=="refuel" and terminal_mode in ["provisions","depart"]:output=buy_fuel()
	elif op=="quote" and terminal_mode=="repairs" and words.size()==2:output="REPAIR %s: %d CR"%[words[1],life.repair_quote(words[1])]
	elif op=="repair" and terminal_mode=="repairs" and words.size()==2:output=repair_sensors(words[1])
	elif op=="advance" and terminal_mode in ["provisions","contract","depart"]:output=request_advance()
	elif text.strip_edges().to_lower()=="start test" and terminal_mode=="depart":output=start_test_cruise()
	elif op=="depart":output="Use COMMS depart from the cockpit after the flight checklist. Or start test here for a prepared cruise."
	elif op=="help":output=_terminal_text(terminal_mode)
	else:
		super._command(text)
		if output!=previous_output:terminal_history.append(previous_output)
		return
	if output!=previous_output:terminal_history.append(previous_output)
	if terminal_history.size()>32:terminal_history.pop_front()
	readout.text=output;readout.scroll_to_line(0);command.clear();_update_life_visuals()

func _daily_summary() -> String:
	return life.time_text()+"\nDAILY WORK ORDER / "+("COMPLETE" if life.checklist_complete() else "INCOMPLETE")+"\nPrint and collect the hab checklist for today's assigned sensor checks.\nYour paper records meal, water, hygiene and inspection completion."

func _provisions_text() -> String:
	return "PORT PROVISIONS / %d CR\n%s\n\nFOOD %d CR/day / WATER %d CR/day / capacity 12 each\nbuy food <days> / buy water <days> / refuel\nFuel %.0f / 3000 kg; fill costs %d CR\nadvance : optional essential shortfall against accepted fee\nBuying both food and water here resets emergency rest.\n\n%s"%[economy.credits,life.stock_text(),FOOD_PRICE,WATER_PRICE,ship.flight.fuel,_fuel_cost(),_travel_text()]

func buy_provisions(kind:String,units:int) -> String:
	if ship.flight.phase!="docked":return "Purchase supplies at a station."
	var error:String=life.purchase_error(kind,units)
	if not error.is_empty():return error
	var cost:int=units*(FOOD_PRICE if kind=="food" else WATER_PRICE)
	if not life_economy.spend(cost):return "Not enough credits. Choose shorter work or request an advance."
	var reply:String=life.purchase(kind,units)
	_refresh_station()
	return reply+"\n%d CR paid / %d CR remaining\n"%[cost,economy.credits]+life.stock_text()

func _fuel_cost() -> int:
	return int(ceil(maxf(0,3000-ship.flight.fuel)*FUEL_PRICE))

func buy_fuel() -> String:
	if ship.flight.phase!="docked":return "Refuel at a station."
	var cost:=_fuel_cost()
	if not life_economy.spend(cost):return "Fuel fill costs %d CR. Use a contract advance if necessary."%cost
	ship.flight.fuel=3000
	return "Fuel filled / %d CR paid / %d CR remaining."%[cost,economy.credits]

func repair_sensors(sensor:String) -> String:
	if ship.flight.phase!="docked":return "Only port technicians repair sensors."
	if sensor=="emergency":
		var cost:=0
		for name in life.sensors:
			if life.sensors[name]<=0:cost+=life.repair_quote(name)
		if cost==0:return "No failed sensors require emergency service."
		var paid:=mini(cost,economy.credits)
		life_economy.spend(paid);life_economy.debt+=cost-paid
		for name in life.sensors:
			if life.sensors[name]<=0:life.repair(name)
		return "Failed sensors restored. Paid %d CR; %d CR billed against future deliveries."%[paid,cost-paid]
	var cost:int=life.repair_quote(sensor)
	if cost<0:return "Unknown sensor."
	if not life_economy.spend(cost):return "Repair costs %d CR. Failed sensors qualify for repair emergency on account."%cost
	return life.repair(sensor)+"\n%d CR paid."%cost

func _remaining_trip_hours() -> float:
	var travelling:bool=ship.flight.phase!="docked" and not ship.flight.plan.is_empty()
	var result:float=(ship.flight.time_to_burn()+120.0)*WORLD_HOURS_PER_SECOND if travelling else 0.0
	if economy.active.is_empty():return result
	var next_leg:int=int(economy.active.get("legs_completed",0))+(1 if travelling else 0)
	for i in range(next_leg,economy.active.legs.size()):result+=economy.active.legs[i].world_hours
	return result

func _travel_text() -> String:
	var hours:=_remaining_trip_hours()
	var needed:=maxi(1,int(ceil(hours/24.0)))
	return "JOURNEY ESTIMATE: %.1f days / pack %d days minimum\n%s"%[hours/24.0,needed,"PROVISIONS WARNING: food or water below estimate." if life.food_stock<needed or life.water_stock<needed else "Provisions cover the current estimate."]

func request_advance() -> String:
	if ship.flight.phase!="docked":return "Request an advance at a station."
	var days:=maxi(1,int(ceil(_remaining_trip_hours()/24.0)))
	var future_legs:=0 if economy.active.is_empty() else maxi(0,economy.active.legs.size()-int(economy.active.get("legs_completed",0))-1)
	# Reserve money for intermediate refuelling/resupply as well as the first leg.
	var essential:=_fuel_cost()+future_legs*int(3000*FUEL_PRICE)+maxi(0,days-life.food_stock)*FOOD_PRICE+maxi(0,days-life.water_stock)*WATER_PRICE
	for name in life.sensors:
		if life.sensors[name]<=0:essential+=life.repair_quote(name)
	var amount:int=life_economy.request_advance(essential)
	return "Advance paid: %d CR / remaining delivery fee: %d CR"%[amount,economy.active.remaining_pay] if amount>0 else life_economy.error

func accept_job(index:int) -> bool:
	if ship.flight.phase!="docked":output="Accept contracts while docked.";return false
	# Keep a quoted offer selectable while the calendar/economy advances; accept()
	# still verifies actual available goods and reserved destination capacity.
	life_economy._offer_cache[economy.station]=jobs.duplicate(true)
	var ok:=super.accept_job(index)
	if ok:
		output="CONTRACT ACCEPTED / FIXED FEE\n"+_status()
		message("Contract accepted. Buy provisions and fuel at the port kiosk; load and secure cargo. No advance was taken.")
	return ok

func toggle_lock() -> bool:
	var ok:=super.toggle_lock()
	if ok and locked:message("Cargo secured. Prepare the cockpit flight checklist or use START TEST at DEPARTURE for a prepared cruise.")
	return ok

func depart() -> bool:
	output="Use the cockpit for departure, or start test at the dock DEPARTURE computer."
	return false

func flight_departure() -> String:
	ship.sync_hardware()
	if not life.can_depart():return "Sensor failure blocks takeoff. Repair at the hangar service terminal."
	if not economy.active.is_empty() and economy.active.phase not in ["complete","to_pickup"] and (not load_readiness().is_empty() or not locked):return "Load and secure every contracted case before departure."
	if economy.leg_destination()>=0 and ship.flight.destination!=economy.leg_destination():return "Route does not match this contract's next station: "+System.NAMES[economy.leg_destination()]
	if not ship.flight.can_depart():return ship.flight.checklist()
	save_life(CHECKPOINT)
	life.begin_station_visit() # Departing ends the purchase-pair station visit.
	var result:String=ship.flight.depart()
	observed_phase=ship.flight.phase;refresh_dock_visibility()
	return result+"\n"+_travel_text()

func start_test_cruise() -> String:
	if ship.flight.phase!="docked":return "The ship is already travelling."
	var destination:int=economy.leg_destination()
	if destination<0:return "Accept a contract and load/lock it first."
	if economy.active.phase!="to_pickup" and (not load_readiness().is_empty() or not locked):return "Load and lock all cargo first."
	if not life.can_depart():return "Repair failed sensors before departure."
	ship.sync_hardware()
	var f=ship.flight
	f.command("engine","port on");f.command("engine","starboard on")
	f.plan_route(System.IDS[destination])
	if f.plan.is_empty():return "No route solution. Replot in the cockpit."
	if f.fuel<f.plan.fuel+f.RESERVE:return "Refuel first: this route needs %.0f kg plus spare fuel."%f.plan.fuel
	save_life(CHECKPOINT)
	panel.hide();seated_pilot=false;seated_table=false
	walker.position=Vector3(0,0.05,-6.0);walker.rotation=Vector3.ZERO;camera.position.y=1.62;camera.rotation=Vector3.ZERO
	ship.loading_module.hatch_open=false
	for i in 2:ship.loading_module.leaves[i].position.x=(-1 if i==0 else 1)*0.70
	ship.loading_module._update_status()
	ship.ramp_up=true;ship.ramp_pivot.rotation.x=-PI/2;ship.ramp_fold.rotation.x=PI
	f.ship_position=f.station_position(f.dock_id,f.elapsed)+Vector3(0,0,-420)
	f.velocity=f.station_velocity(f.dock_id,f.elapsed)
	f.phase="injection"
	f.plan_route(System.IDS[destination]);f.entered_coords=f.plan.target;f.entered_burn=f.plan.burn;f.entered_reserve=f.plan.reserve;f.load_route()
	var result:String=f.engage_navigation()
	demo_mode=true;observed_phase=f.phase;life.begin_station_visit();refresh_dock_visibility()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	message("Prepared test cruise started. Print your daily checklist at HAB. You will wake before arrival; dock using NAV approach / auto dock.")
	return result+"\n"+_travel_text()

func _arrived() -> void:
	life.begin_station_visit()
	var destination:int=ship.flight.dock_id
	if destination==economy.leg_destination():
		if life_economy.finish_leg(destination):
			if economy.active.phase=="loading":_spawn_manifest()
			message("Docked at "+System.NAMES[destination]+". Lower ramp / open hatch using CHECKLIST. Unload and complete your delivery.")
	else:economy.station=destination
	jobs=economy.offers(economy.station)
	_refresh_station();refresh_dock_visibility()

func rescue_ship() -> String:
	var result:String=ship.flight.rescue()
	life_economy.debt+=150
	_arrived();observed_phase="docked"
	return result+"\nRecovery service: 150 CR billed against future deliveries."

func start_rest(kind:String) -> String:
	if held>=0 or not life.hand_item.is_empty():return "Put your carried cargo, dish or glass away first."
	if ship.flight.phase!="docked" and (not ship.flight.autopilot or ship.flight.phase not in ["injection","coast"]):return "Rest needs a safe dock or NAV transfer. Arrival watch must be handled awake."
	var arrival_hours:float=INF if ship.flight.phase=="docked" else ship.flight.arrival_wake_in()*WORLD_HOURS_PER_SECOND
	if arrival_hours<=0.000001:return "Arrival watch: stay awake and return to the cockpit."
	var plan:Dictionary=life.start_rest(kind)
	if not plan.ok:return plan.error
	var requested:float=plan.hours
	skip={"total":requested,"remaining":requested,"label":plan.label,"kind":kind}
	panel.hide();skip_screen.show();skip_bar.show();skip_bar.value=0;shower_on=false
	return plan.label

func _process_skip(delta:float) -> void:
	if skip.is_empty():return
	var step:float=minf(skip.remaining,delta*skip.total/4.0)
	if ship.flight.phase!="docked":step=minf(step,ship.flight.arrival_wake_in()*WORLD_HOURS_PER_SECOND)
	if step<=0.000001:_end_skip("Arrival watch: awake 90 seconds before arrival braking. NAV remains engaged.");return
	var before_day:int=life.day()
	if ship.flight.phase!="docked" and (not ship.flight.autopilot or ship.flight.phase not in ["injection","coast"]):
		_end_skip("NAV needs attention. Rest stopped; return to the cockpit.");return
	var used:=_advance_simulation(step/WORLD_HOURS_PER_SECOND)
	skip.remaining=maxf(0,skip.remaining-used)
	life.tick_interactions(step/WORLD_HOURS_PER_SECOND,false)
	skip_bar.value=100*(1-skip.remaining/skip.total)
	skip_label.text="%s\n%s\n%.1f shipboard hours remaining / ESC wake"%[skip.label,life.time_text(),skip.remaining]
	if ship.flight.phase!="docked" and not ship.flight.autopilot:
		_end_skip("NAV interrupted. Rest stopped; restore propulsion at the cockpit.");return
	if not life.can_depart() and before_day!=life.day():_end_skip("Sensor service required. Current journey remains navigable; arrange port repair.");return
	if ship.flight.phase!="docked" and ship.flight.arrival_wake_in()<=0.000001:_end_skip("Arrival watch: awake 90 seconds before arrival braking. Return to cockpit.");return
	if skip.remaining<=0.000001:_end_skip("Rest complete. "+life.time_text())

func _end_skip(reason:String) -> void:
	skip.clear();skip_screen.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;message(reason)
	_update_life_visuals()

func _job_board() -> String:
	if not economy.active.is_empty() and economy.active.phase!="complete":return _status()
	jobs=economy.offers(economy.station)
	var result:="%s / CONTRACT BOARD / %d CR\nFixed delivery fees. You pay fuel, provisions and upkeep.\n\n"%[System.NAMES[economy.station],economy.credits]
	for i in jobs.size():
		var j:Dictionary=jobs[i]
		result+="%d / %s / %s\n    %s > %s\n    %d CR FIXED FEE / estimated %.1f shipboard days\n\n"%[i+1,j.kind.to_upper(),"FULL HOLD" if j.full else "SMALL LOAD",System.NAMES[j.source],System.NAMES[j.destination],j.payout,j.world_hours/24.0]
	return result+"accept <number> / jobs / status / advance\nAn optional shortfall advance is deducted from final payment.\nF1: complete test guide."

func _status() -> String:
	if economy.active.is_empty():return "No active contract. jobs lists available work.\n"+completion_receipt
	var c:Dictionary=economy.active
	return "%s / %s / %s\n%s > %s\nFIXED FEE %d CR / ADVANCE %d / FINAL BALANCE %d\nRACKED %d/%d / STAGED %d / DELIVERED %d\n%s / %d CR WALLET\n\n%s\n\nFuel, provisions and upkeep are your operating costs.\nNo deadlines. Load, lock, prepare cockpit and depart."%[c.id,c.commodity,c.phase.to_upper(),System.NAMES[c.source],System.NAMES[c.destination],c.payout,c.advance,c.remaining_pay,packing.placements.size(),parcels.size(),stage_count(),delivered_count(),"CARGO LOCKED" if locked else "CARGO UNLOCKED",economy.credits,_travel_text()]

func _refresh_station() -> void:
	super._refresh_station()
	if dock.is_empty():return
	var status=dock.transit.get_node_or_null("StatusText")
	if status:status.text="DEPARTURE / [F]\nFLIGHT CHECKLIST\nOPTIONAL TEST CRUISE"

func complete_delivery() -> bool:
	var ok:=super.complete_delivery()
	if ok:
		completion_receipt="DELIVERY COMPLETE / final balance paid once.\nWallet %d CR / outstanding service debt %d CR"%[economy.credits,life_economy.debt]
		message(completion_receipt)
	return ok

func _guide_text() -> String:
	return "COMPLETE SHIP LIFE TEST\n\n1. Dock CONTRACTS: jobs, accept 1 (small) or accept 2 (full).\n2. PROVISIONS beside it: buy food 12 / buy water 12 / refuel.\n3. F carry cargo; R/T rotate; pack racks; cargo-lock button.\n4. Flight: cockpit CHECKLIST print, CHART plot/print, NAV coords/burn/reserve/load.\n   ENGINE port on / starboard on; COMMS request/code; CHECKLIST hatch close/ramp raise.\n   COMMS depart, G pilot seat, manual exit, NAV engage, G stand.\n   OR dock DEPARTURE: start test to begin a prepared cruise.\n5. HAB computer: stock / print, F collect at tray. TAB inspect / H stow/retrieve / F at galley recycling bin.\n6. Fridge → oven → cooked plate → table → five F bites → plate → sink.\n7. Cabinet → cooler → F drink → sink. Shower periodically in bathroom.\n8. Read assigned sensors on your paper. ENGINEERING: check <sensor>, trim a/b/c, test.\n9. Bunk: pass until20:00, then sleep until06:00. Black progress shows the skip.\n10. Arrival wakes90s early. NAV approach / auto dock, or fly manually.\n11. CHECKLIST ramp lower / hatch open. Unlock cargo, unload, F complete at DELIVERY.\n\nF5 save / F9 load / ESC pause / G stand from table or pilot seat.\nThis session has its own save; your old flight progress is preserved."

func _save_path(path:String) -> String:
	if "--ship-life-test" in OS.get_cmdline_user_args() and path.begins_with("user://"):
		return "/tmp/ship-life-integration-"+path.get_file()
	return path

func save_life(path:String=LIFE_SAVE) -> String:
	if not life_ready:return "Session not ready."
	if not skip.is_empty() or ship.ramp_moving or ship.loading_module.hatch_moving:return "Finish rest or moving hatch/ramp before saving."
	ship.sync_hardware()
	var data:Dictionary={"version":1,"life":life.snapshot(),"economy":life_economy.snapshot(),"flight":ship.flight.snapshot(),"parcels":parcels.duplicate(true),"manifest":packing.manifest.duplicate(true),"solution":packing.solution_order.duplicate(),"racked":packing.placements.duplicate(true),"floor":floor_packing.placements.duplicate(true),"held":held,"held_size":held_size,"locked":locked,"walker":walker.transform,"camera":camera.transform,"seated_pilot":seated_pilot,"seated_table":seated_table,"printed":printed,"paper_in_tray":paper_in_tray,"paper_text":paper_text,"paper_stowed":paper_stowed,"case_poses":{},"roles":[],"maps":[]}
	for id in cases:data.case_poses[id]=cases[id].global_transform
	for terminal in ship.terminals:
		data.roles.append(terminal.kind)
		data.maps.append(terminal.chart_map.snapshot() if terminal.chart_map else null)
	var target:=_save_path(path)
	var file:=FileAccess.open(target+".tmp",FileAccess.WRITE)
	if not file:return "Save failed; previous file preserved."
	file.store_string(JSON.stringify(_encode(data)));file.close()
	var result:=DirAccess.rename_absolute(ProjectSettings.globalize_path(target+".tmp"),ProjectSettings.globalize_path(target))
	return "Ship life, cargo, clock and flight saved." if result==OK else "Save failed; previous file preserved."

func load_life(path:String=LIFE_SAVE) -> String:
	var target:=_save_path(path)
	if not FileAccess.file_exists(target):return "No saved ship-life session yet. F5 saves."
	var raw=JSON.parse_string(FileAccess.get_file_as_string(target))
	var data=_decode(raw)
	if not data is Dictionary or int(data.get("version",0))!=1:return "Invalid session file; current state preserved."
	for required in ["life","economy","flight","parcels","manifest","solution","racked","floor","walker","camera","case_poses","held_size","roles","maps"]:
		if not data.has(required):return "Incomplete session; current state preserved."
	var check_economy:=LifeEconomy.new()
	var check_flight:=preload("res://scripts/longhaul_flight_state.gd").new()
	if not check_economy.restore(data.economy) or not check_flight.restore(data.flight):return "Invalid economic/flight state; session preserved."
	if not data.walker is Transform3D or not data.camera is Transform3D:return "Invalid player pose."
	for id in data.parcels:
		if not data.case_poses.has(id) or not data.case_poses[id] is Transform3D:return "Missing cargo pose."
	if ship.active_terminal:ship.close_terminal()
	_clear_cases()
	life.restore(data.life);life_economy.restore(data.economy);ship.flight.restore(data.flight)
	packing.manifest=data.manifest;packing.solution_order.assign(data.solution);packing.placements=data.racked
	floor_packing.manifest=packing.manifest;floor_packing.placements=data.floor
	parcels=data.parcels;locked=bool(data.get("locked",false));held=int(data.get("held",-1));held_size=data.held_size
	walker.transform=data.walker;camera.transform=data.camera
	pitch=camera.rotation.x
	for id in parcels:
		var appearance:Dictionary=parcels[id].duplicate(true);appearance.slot=0;appearance.cell=Vector3i.ZERO
		_make_case(appearance)
		cases[id].global_transform=data.case_poses[id]
		if id==held:
			cases[id].reparent(walker);_case_body(id).collision_layer=0
	if held>=0:_update_carry()
	seated_pilot=bool(data.get("seated_pilot",false));seated_table=bool(data.get("seated_table",false));printed=bool(data.get("printed",false));paper_in_tray=bool(data.get("paper_in_tray",false));printed_timer=0
	paper_text=str(data.get("paper_text",life.checklist_text() if printed and life.printed_day==life.day() else "Previous day work order. Recycle and reprint at HAB."))
	paper_stowed=bool(data.get("paper_stowed",false));paper_open=false;paper_terminal_hidden=false;daily_paper.set_closeup(false,true)
	if seated_table:_sit_at_table()
	ship.ramp_up=ship.flight.ramp_raised;ship.ramp_pivot.rotation.x=-PI/2 if ship.ramp_up else atan(1.2/4.2);ship.ramp_fold.rotation.x=PI if ship.ramp_up else 0
	ship.loading_module.hatch_open=not ship.flight.hatch_closed
	for i in 2:ship.loading_module.leaves[i].position.x=(-1 if i==0 else 1)*(2.14 if ship.loading_module.hatch_open else 0.70)
	ship.loading_module._update_status()
	for i in mini(data.roles.size(),ship.terminals.size()):
		ship.terminals[i].set_role(data.roles[i])
		if i<data.maps.size() and data.maps[i]!=null:ship.terminals[i].restore_map_view(data.maps[i])
	skip.clear();skip_screen.hide();panel.hide();shower_on=false;paused_life=false
	observed_phase=ship.flight.phase;ship._update_flight_world();jobs=economy.offers(economy.station)
	_update_life_visuals();_refresh_station();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	return "Ship-life session restored. "+life.time_text()

func _encode(value:Variant) -> Variant:
	if value is int:return {"@int":value}
	if value is Vector3i:return {"@v3i":[value.x,value.y,value.z]}
	if value is Vector3:return {"@v3":[value.x,value.y,value.z]}
	if value is Transform3D:return {"@pose":[_encode(value.basis.x),_encode(value.basis.y),_encode(value.basis.z),_encode(value.origin)]}
	if value is Dictionary:
		var pairs:Array=[]
		for key in value:pairs.append([_encode(key),_encode(value[key])])
		return {"@dict":pairs}
	if value is Array:
		var items:Array=[]
		for item in value:items.append(_encode(item))
		return items
	return value

func _decode(value:Variant) -> Variant:
	if value is Dictionary:
		if value.has("@int"):return int(value["@int"])
		if value.has("@v3i"):
			var a:Array=value["@v3i"];return Vector3i(int(a[0]),int(a[1]),int(a[2]))
		if value.has("@v3"):
			var a:Array=value["@v3"];return Vector3(a[0],a[1],a[2])
		if value.has("@pose"):
			var a:Array=value["@pose"];return Transform3D(Basis(_decode(a[0]),_decode(a[1]),_decode(a[2])),_decode(a[3]))
		if value.has("@dict"):
			var result:Dictionary={}
			for pair in value["@dict"]:
				var key:Variant=_decode(pair[0])
				if key is float and key==floor(key):key=int(key)
				result[key]=_decode(pair[1])
			return result
	if value is Array:
		var result:Array=[]
		for item in value:result.append(_decode(item))
		return result
	return value

func _run_life_tests() -> void:
	await get_tree().process_frame
	var suite=load("res://scripts/ship_life_integration_test.gd").new()
	var ok:bool=await suite.run(self)
	var flight_suite=load("res://scripts/ship_life_flight_test.gd").new()
	var flight_ok:bool=await flight_suite.run(self)
	ok=ok and flight_ok
	print("SHIP LIFE INTEGRATION ","PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _capture_life() -> void:
	if "--survival-revision" in OS.get_cmdline_user_args():
		await _capture_survival_revision()
		return
	walker.position=Vector3(0,0.05,-5.3);walker.rotation=Vector3.ZERO
	camera.look_at(Vector3(1.3,1.3,-7),Vector3.UP)
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/ship-life-combined-hab.png")
	open_terminal("hab")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/ship-life-combined-terminal.png")
	panel.hide();life.elapsed_hours=20;life.daily_food=1;life.daily_water=true;life.hygiene=100
	start_rest("sleep")
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/ship-life-sleep-progress.png")
	get_tree().quit()

func _capture_survival_revision() -> void:
	set_physics_process(false)
	life.hand_item="meal";life.hand_bites=5
	_use_life("table")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-seat.png")
	# Show the supporting cushion from a side angle as well as the seated view.
	var seat_pose:Transform3D=camera.global_transform
	camera.global_position=Vector3(-0.25,1.6,-4.5)
	camera.look_at(life_art.dining_seat.global_position,Vector3.UP)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-bench.png")
	camera.global_transform=seat_pose
	seated_table=false;walker.position=Vector3(0,0.05,-5.3);camera.position=Vector3(0,1.62,0);walker.rotation=Vector3.ZERO;camera.rotation=Vector3.ZERO
	open_terminal("hab");_command("print");panel.hide();printed_timer=0;_collect_daily_paper()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-paper-carried.png")
	_stow_daily_paper();_update_life_visuals()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-empty-hands.png")
	paper_stowed=false;_update_life_visuals()
	_set_paper_open(true)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-paper-read.png")
	_set_paper_open(false)
	open_terminal("sensors");_command("check "+life.selected_sensors[0])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-calibration.png")
	_command("test")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-degraded.png")
	panel.hide();walker.position=Vector3(0,0.05,-7.46);camera.look_at(fixtures.targets.trash.global_position,Vector3.UP)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-paper-bin.png")
	_use_life("trash")
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/survival-paper-discarded.png")
	get_tree().quit()
