extends Node
## Text is rendered onto the existing cockpit CRT, never onto a floating menu.
const VALID_ROLES := ["checklist","chart","nav","engine","comms","fuel","map","distance","velocity","radar"]
const GREEN_ROLES := ["chart","nav","comms","map","radar"]
var host: Node3D
var panel: Node3D
var kind := ""
var viewport: SubViewport
var header: Label
var readout: Label
var prompt: Label
var footer: Label
var background: ColorRect
var telemetry_note: Label
var entry := ""
var lines: Array[String] = []
var history: Array[String] = []
var history_index := 0
var focused := false
var show_map := false
var show_help := false
var show_live := true
var chart_map: Control
var refresh_timer := 0.0

func build(ship: Node3D, monitor: Node3D, role: String) -> void:
	host=ship
	panel=monitor
	viewport=SubViewport.new()
	viewport.size=Vector2i(840,600)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	background=ColorRect.new()
	background.size=viewport.size
	viewport.add_child(background)
	var tint:=Color("9fe7b1")
	header=label(Vector2(24,14),29,tint)
	header.size=Vector2(792,78)
	readout=label(Vector2(24,103),26,tint)
	readout.size=Vector2(792,408)
	readout.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	readout.clip_text=true
	prompt=label(Vector2(24,516),27,tint)
	prompt.size=Vector2(792,36)
	prompt.clip_text=true
	footer=label(Vector2(24,558),23,tint.darkened(0.18))
	footer.size=Vector2(792,30)
	footer.clip_text=true
	telemetry_note=label(Vector2(24,420),29,tint)
	telemetry_note.size=Vector2(792,90)
	telemetry_note.clip_text=true
	var material:=StandardMaterial3D.new()
	material.albedo_texture=viewport.get_texture()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	panel.get_meta("screen_mesh").material_override=material
	panel.set_meta("terminal",self)
	set_role(role)

func set_role(role: String) -> bool:
	var wanted:=role.strip_edges().to_lower()
	if wanted not in VALID_ROLES: return false
	kind=wanted
	entry=""
	lines.clear()
	history.clear()
	history_index=0
	show_map=false
	show_help=false
	show_live=true
	var tint:=Color("9fe7b1") if kind in GREEN_ROLES else Color("edc876")
	background.color=Color("071611") if kind in GREEN_ROLES else Color("191609")
	for item in [header,readout,prompt,telemetry_note]:
		item.add_theme_color_override("font_color",tint)
	footer.add_theme_color_override("font_color",tint.darkened(0.18))
	if kind in ["chart","map"] and not chart_map:
		chart_map=preload("res://scripts/longhaul_route_map.gd").new()
		chart_map.host=host
		chart_map.map_font=host.font
		chart_map.position=Vector2(24,98)
		chart_map.size=Vector2(770,275)
		viewport.add_child(chart_map)
	refresh()
	return true

func label(at: Vector2, size_px: int, tint: Color) -> Label:
	var item:=Label.new()
	item.position=at
	item.add_theme_font_override("font",host.font)
	item.add_theme_font_size_override("font_size",size_px)
	item.add_theme_color_override("font_color",tint)
	viewport.add_child(item)
	return item

func focus() -> void:
	focused=true
	show_map=false
	show_help=false
	show_live=true
	lines.clear()
	refresh()

func append(message: String) -> void:
	for line in message.split("\n"): lines.append(line)
	while lines.size()>80: lines.pop_front()

func submit(value: String) -> void:
	if value.strip_edges().is_empty(): return
	history.append(value)
	history_index=history.size()
	show_help=false
	var command:=value.strip_edges().to_lower()
	show_map=kind=="chart" and command=="map"
	if show_map:
		show_live=true
		entry=""
		refresh()
		return
	if command in ["clear","status"]:
		lines.clear()
		show_live=true
	else:
		var old_kind:=kind
		var result: String=host.terminal_command(kind,value,self)
		lines.clear()
		show_live=old_kind!=kind
		if kind=="engine" and result==host.flight.engine_diagram(): show_live=true
		if kind=="checklist" and command=="checklist": show_live=true
		if not show_live:
			append("> "+value)
			append(result)
	entry=""
	refresh()

func handle_key(event: InputEventKey) -> void:
	if not event.pressed: return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER: submit(entry)
		KEY_BACKSPACE: entry=entry.left(-1)
		KEY_UP:
			if not history.is_empty():
				history_index=maxi(0,history_index-1)
				entry=history[history_index]
		KEY_DOWN:
			history_index=mini(history.size(),history_index+1)
			entry=history[history_index] if history_index<history.size() else ""
		_:
			if event.unicode>=32 and event.unicode<127 and entry.length()<70:
				entry+=char(event.unicode)
	refresh()

func refresh() -> void:
	var state=host.flight
	header.text="K-01 / %s\n%s  |  %.0f kg  |  T+%05.1f h" % [kind.to_upper(),state.phase.to_upper(),state.fuel,state.elapsed/60]
	readout.position=Vector2(24,103)
	readout.size=Vector2(792,408)
	readout.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	telemetry_note.visible=false
	telemetry_note.position=Vector2(24,420)
	telemetry_note.size=Vector2(792,90)
	telemetry_note.add_theme_font_size_override("font_size",29)
	if chart_map: chart_map.visible=false
	readout.add_theme_font_size_override("font_size",26)
	var live: bool=not focused or show_live or show_map
	if focused:
		# Responses remain visible until status, clear, or a new focus restores telemetry.
		readout.text=state.status(kind) if live else "\n".join(lines.slice(maxi(0,lines.size()-13)))
		prompt.text=kind.to_upper()+"> "+entry+"_"
		footer.text="TAB paper / SHIFT+TAB next / display <role>"
	else:
		readout.text=state.status(kind)
		prompt.text="[F] "+kind.to_upper()+" COMPUTER"
		footer.text="TAB paper / SHIFT+TAB next / P read"
	if not live: return
	if kind=="engine":
		readout.text=state.engine_diagram()
		readout.add_theme_font_size_override("font_size",30)
	if kind=="checklist": readout.text=state.checklist()
	if kind=="map":
		chart_map.visible=true
		chart_map.position=Vector2(24,100)
		chart_map.size=Vector2(792,405)
		readout.text=""
		header.text="K-01 / MAP\nLIVE JOURNEY / "+state.phase.to_upper()
		chart_map.queue_redraw()
	if kind=="distance":
		header.text="K-01 / DISTANCE\nSTATION RANGE / NAV LINK"
		readout.text=""
		if state.nav_selected:
			var distance: float=state.station_range()
			readout.add_theme_font_size_override("font_size",85)
			readout.text="%s\n%s" % [state.IDS[state.destination].to_upper(),"%.1f km" % (distance/1000) if distance>=1000 else "%.0f m" % distance]
		else:
			telemetry_note.visible=true
			telemetry_note.text="NO DESTINATION LOADED AT NAV"
	if kind=="velocity": _show_velocity()
	if kind=="radar": _show_radar()
	if kind=="chart" and chart_map:
		chart_map.visible=true
		chart_map.position=Vector2(24,98)
		chart_map.size=Vector2(770,275)
		chart_map.queue_redraw()
		readout.position=Vector2(24,387)
		readout.size=Vector2(792,126)
		readout.text="plot <station> direct|economy\n"+("COORDS "+state.coords_text()+"\nBURN %.2f kg/s   SPARE %.0f kg" % [state.plan.burn,state.plan.reserve] if not state.plan.is_empty() else "destinations: list stations\nhelp: command reference")

func _show_velocity() -> void:
	var state=host.flight
	var reference: int=state.reference_station_id()
	var velocity: Vector3=state.relative_velocity_local()
	header.text="K-01 / VELOCITY\nRELATIVE TO %s / METRES PER SECOND" % state.IDS[reference].to_upper()
	readout.position=Vector2(24,112)
	readout.autowrap_mode=TextServer.AUTOWRAP_OFF
	readout.add_theme_font_size_override("font_size",96)
	readout.text="X %-7s %6.1f\nY %-7s %6.1f\nZ %-7s %6.1f" % [axis_direction(velocity.x,"RIGHT","LEFT"),absf(velocity.x),axis_direction(velocity.y,"UP","DOWN"),absf(velocity.y),axis_direction(-velocity.z,"FORWARD","BACK"),absf(velocity.z)]
	telemetry_note.visible=true
	telemetry_note.position=Vector2(24,445)
	telemetry_note.size=Vector2(792,65)
	telemetry_note.add_theme_font_size_override("font_size",26)
	telemetry_note.text="SHIP AXES / TOTAL %.1f m/s\n%s" % [velocity.length(),control_status()]

func axis_direction(value: float, positive: String, negative: String) -> String:
	if absf(value)<0.05: return "STOP"
	return positive if value>0 else negative

func distance_text(value: float) -> String:
	return "%.2f km" % absf(value/1000) if absf(value)>=1000 else "%.1f m" % absf(value)

func control_status() -> String:
	var state=host.flight
	if state.phase=="docked": return "BERTH CAPTURED / ENGINES IDLE"
	if state.auto_docking: return "AUTODOCK / COMPUTER HAS CONTROL"
	if state.arrival_hold: return "ARRIVAL HOLD / COMPUTER HAS CONTROL"
	if state.autopilot: return "NAV ENGAGED / COMPUTER HAS CONTROL"
	return "MANUAL / MOMENTUM IS PRESERVED"

func _show_radar() -> void:
	var state=host.flight
	var reference: int=state.reference_station_id()
	var offset: Vector3=state.station_offset_local()
	var velocity: Vector3=state.relative_velocity_local()
	var distance:=offset.length()
	var forward: bool=offset.z<0 or distance<0.1
	# A fixed-angle forward view: X/Y on this reticle are directions from the nose.
	# Off-screen targets stick to the edge, with a separate BEHIND indicator.
	var depth:=maxf(absf(offset.z),1)
	var horizontal:=offset.x/depth
	var vertical:=offset.y/depth
	var col:=clampi(roundi(10+horizontal*9),1,19)
	var row:=clampi(roundi(4-vertical*3),1,7)
	var outside: bool=not forward or absf(horizontal)>1 or absf(vertical)>1
	var grid: Array[String]=[]
	for y in 9:
		var line:=""
		for x in 21:
			var mark:=" "
			if y==0 or y==8: mark="+" if x==0 or x==20 else "-"
			elif x==0 or x==20: mark="|"
			elif y==4: mark="+" if x==10 else "-"
			elif x==10: mark="|"
			if x==col and y==row: mark="!" if not forward else "O"
			line+=mark
		grid.append(line)
	header.text="K-01 / RADAR\n%s / %s" % [state.IDS[reference].to_upper(),"TARGET BEHIND" if not forward else ("TARGET OFF SCREEN" if outside else "FORWARD VIEW +/-45 DEG")]
	readout.position=Vector2(24,116)
	readout.size=Vector2(410,382)
	readout.autowrap_mode=TextServer.AUTOWRAP_OFF
	readout.add_theme_font_size_override("font_size",36)
	readout.text="\n".join(grid)
	var closing: float=velocity.dot(offset.normalized()) if distance>0.01 else 0.0
	var nose: Vector3=-state.attitude.z
	var heading:=fposmod(rad_to_deg(atan2(nose.x,-nose.z)),360)
	var pitch:=rad_to_deg(asin(clampf(nose.y,-1,1)))
	var berth: String="CAPTURED" if state.phase=="docked" else ("K-01 RESERVED" if state.approach_clearance else "NOT RESERVED")
	telemetry_note.visible=true
	telemetry_note.position=Vector2(446,111)
	telemetry_note.size=Vector2(372,401)
	telemetry_note.add_theme_font_size_override("font_size",29)
	telemetry_note.text="RANGE %s\nX %s %s\nY %s %s\n%s %.1f m/s\nDRIFT X %+.1f m/s\nDRIFT Y %+.1f m/s\nHDG %03.0f / PITCH %+.0f\nBERTH HDG 180 / P 000\nBERTH %s\nCAPTURE <20m / <2m/s\n%s" % [distance_text(distance),axis_direction(offset.x,"RIGHT","LEFT"),distance_text(offset.x),axis_direction(offset.y,"UP","DOWN"),distance_text(offset.y),"CLOSING" if closing>=0 else "OPENING",absf(closing),velocity.x,velocity.y,heading,pitch,berth,"O TARGET / + YOUR NOSE" if forward else "! BEHIND / TURN TO FACE"]

func _process(delta: float) -> void:
	refresh_timer-=delta
	if refresh_timer<=0:
		refresh_timer=0.15
		refresh()
