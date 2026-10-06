extends Node
## Text is rendered onto the existing cockpit CRT, never onto a floating menu.
var host: Node3D
var panel: Node3D
var kind := ""
var viewport: SubViewport
var header: Label
var readout: Label
var prompt: Label
var footer: Label
var entry := ""
var lines: Array[String] = []
var history: Array[String] = []
var history_index := 0
var focused := false
var show_map := false
var chart_map: Control
var refresh_timer := 0.0

func build(ship: Node3D, monitor: Node3D, role: String) -> void:
	host=ship
	panel=monitor
	kind=role
	viewport=SubViewport.new()
	viewport.size=Vector2i(840,600)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var bg:=ColorRect.new()
	bg.color=Color("071611") if kind in ["chart","nav","comms"] else Color("191609")
	bg.size=viewport.size
	viewport.add_child(bg)
	var tint:=Color("9fe7b1") if kind in ["chart","nav","comms"] else Color("edc876")
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
	footer.text="F: USE CRT   |   help: COMMANDS"
	var material:=StandardMaterial3D.new()
	material.albedo_texture=viewport.get_texture()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	panel.get_meta("screen_mesh").material_override=material
	panel.set_meta("terminal",self)
	if kind=="chart":
		chart_map=preload("res://scripts/longhaul_route_map.gd").new()
		chart_map.host=host
		chart_map.map_font=host.font
		chart_map.position=Vector2(24,98)
		chart_map.size=Vector2(770,275)
		viewport.add_child(chart_map)
	refresh()

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
	if lines.is_empty(): append(host.flight.help_text(kind))
	refresh()

func append(message: String) -> void:
	for line in message.split("\n"): lines.append(line)
	while lines.size()>80: lines.pop_front()

func submit(value: String) -> void:
	if value.strip_edges().is_empty(): return
	history.append(value)
	history_index=history.size()
	show_map=kind=="chart" and value.strip_edges().to_lower()=="map"
	if show_map:
		entry=""
		refresh()
		return
	if value.strip_edges().to_lower()=="clear": lines.clear()
	else:
		append("> "+value)
		append(host.terminal_command(kind,value))
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
	if chart_map: chart_map.visible=not focused or show_map
	readout.add_theme_font_size_override("font_size",26)
	if focused:
		# Fixed visible history: long help/readback outputs remain scroll-free.
		readout.text="\n".join(lines.slice(maxi(0,lines.size()-11)))
		prompt.text=kind.to_upper()+"> "+entry+"_"
		footer.text="ENTER: RUN   UP/DOWN: HISTORY   ESC: STEP BACK"
	else:
		readout.text=state.status(kind)
		if kind=="nav":
			readout.add_theme_font_size_override("font_size",60)
			var g: Dictionary=state.guidance()
			readout.text="YAW %s %.1f°\nPITCH %s %.1f°\nDELTA-V %.1f m/s\nRANGE %.0f m\nBURN IN %.0f s\n%s" % ["LEFT" if g.yaw>0 else "RIGHT",absf(g.yaw),"UP" if g.pitch>0 else "DOWN",absf(g.pitch),g.dv.length(),state.ship_position.distance_to(state.station_position(state.destination,state.elapsed)),state.time_to_burn(),"COAST / SAFE TO LEAVE" if state.phase=="coast" else ("CUT THRUST / ALIGN / X" if state.phase in ["departure","injection"] and g.dv.length()<3 else "W THRUST / SHIFT FINE")]
		prompt.text="[F] "+kind.to_upper()+" TERMINAL"
		if kind=="nav" and state.phase=="docked":
			readout.add_theme_font_size_override("font_size",50)
			readout.text="BERTH K-01 / DOCKED\nENGINE: CHECKLIST\nFUEL: MIXTURE 2.5\nCHART: PLOT ROUTE\nNAV: LOAD TRANSFER\nCOMMS: REQUEST"
		if kind=="nav" and state.phase=="approach":
			var g: Dictionary=state.guidance()
			readout.text="YAW %+.1f° / UP %+.1f°\nDELTA-V %.1f m/s\nRANGE %.0f m\nREL SPEED %.1f m/s\nCAPTURE <20m / <2m/s\nCOMMS: APPROACH / DOCK" % [g.yaw,g.pitch,g.dv.length(),state.ship_position.distance_to(state.station_position(state.destination,state.elapsed)),(state.velocity-state.station_velocity(state.destination,state.elapsed)).length()]
		footer.text="INERTIAL FLIGHT / MANUAL THRUST" if kind=="nav" else "TYPE help FOR COMMANDS"
	if chart_map and chart_map.visible:
		chart_map.queue_redraw()
		readout.position=Vector2(24,387)
		readout.size=Vector2(792,126)
		readout.text="plot <station> direct|economy\n"+("COORDS "+state.coords_text()+"\nBURN %.2f kg/s   RESERVE %.0f kg" % [state.plan.burn,state.plan.reserve] if not state.plan.is_empty() else "destinations: list stations\nhelp: command reference")

	if state.phase=="coast" and state.time_to_burn()<=75:
		footer.text="MANEUVER IN %.0fs / RETURN TO CONTROLS" % state.time_to_burn()
	elif state.phase=="brake":
		footer.text="ARRIVAL BURN DUE / MANUAL BRAKING REQUIRED"

func _process(delta: float) -> void:
	refresh_timer-=delta
	if refresh_timer<=0:
		refresh_timer=0.15
		refresh()
