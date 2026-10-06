extends "res://scripts/longhaul_preview.gd"
## Approved interior, stable local frame, live inertial flight outside the windows.
const FlightState = preload("res://scripts/longhaul_flight_state.gd")
const Terminal = preload("res://scripts/longhaul_terminal.gd")
const SAVE_FILE := "user://longhaul_flight_v1.json"
var flight := FlightState.new()
var terminals: Array = []
var flight_sheet: Node3D
var active_terminal: Node
var camera_before_terminal := Transform3D.IDENTITY
var cockpit_module: Node3D
var ramp_pivot: Node3D
var ramp_fold: Node3D
var ramp_tween: Tween
var ramp_moving := false
var ramp_up := false
var space_root: Node3D
var station_nodes: Array[Node3D] = []
var station_deck: StaticBody3D
var stars: Node3D
var planet: MeshInstance3D
var announcement: Label
var status_repeaters: Array[Label3D] = []
var notice_timer := 0.0
var seen_warning := 0
var flight_ready := false
var paused := false
var test_running := false
var sound: AudioStreamPlayer
var life_targets: Array[StaticBody3D] = []
var automatic_save_timer := 60.0

func uses_flight_world() -> bool:
	return true

func _ready() -> void:
	super._ready()
	DisplayServer.window_set_title("Longhaul — Flight & Ship Life")
	player.position=Vector3(0,0.05,-9.4)
	player.rotation=Vector3.ZERO
	camera.far=10000
	for child in get_children():
		if child.get_script()==preload("res://scripts/longhaul_cockpit.gd"):
			cockpit_module=child
			break
	var roles={"nav":"chart","dock":"nav","fuel":"fuel","drive":"engine","comms":"comms","radar":"nav","power":"engine"}
	for panel in cockpit_module.monitor_faces:
		var terminal:=Terminal.new()
		add_child(terminal)
		terminal.build(self,panel,roles.get(panel.get_meta("content"),"nav"))
		terminals.append(terminal)
	flight_sheet=preload("res://scripts/longhaul_flight_sheet.gd").new()
	add_child(flight_sheet)
	flight_sheet.build(self,terminals[0].panel)
	_build_flight_space()
	_register_life_actions()
	announcement=Label.new()
	announcement.add_theme_font_override("font",font)
	announcement.add_theme_font_size_override("font_size",26)
	announcement.modulate=Color("f2cf86")
	announcement.position=Vector2(24,112)
	announcement.size=Vector2(1160,100)
	announcement.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	overlay.add_child(announcement)
	sound=AudioStreamPlayer.new()
	add_child(sound)
	flight_ready=true
	flight.alert("Welcome aboard. F to sit; look at any screen and F. Type help for your next step.")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if "--flight-test" in OS.get_cmdline_user_args():
		test_running=true
		_run_flight_tests.call_deferred()
	elif "--flight-capture" in OS.get_cmdline_user_args():
		_capture_flight.call_deferred()
	elif FileAccess.file_exists(SAVE_FILE):
		load_session()
	if not test_running and "--flight-capture" not in OS.get_cmdline_user_args() and flight.phase=="docked":
		_take_seat()
		open_terminal(terminals[1])

func _exterior() -> void:
	# A real hinge at the aft threshold carries geometry and collision together.
	ramp_pivot=Node3D.new()
	ramp_pivot.position=Vector3(0,-0.03,11.1)
	ramp_pivot.rotation.x=atan(1.2/4.2)
	add_child(ramp_pivot)
	loading_module.ramp_trim.queue_free()
	for section in 2:
		var parent: Node3D=ramp_pivot
		if section==1:
			ramp_fold=Node3D.new()
			ramp_fold.position=Vector3(0,0,2.2)
			ramp_pivot.add_child(ramp_fold)
			parent=ramp_fold
		var body:=StaticBody3D.new()
		body.position=Vector3(0,-0.03,1.1)
		parent.add_child(body)
		space_box(body,Vector3.ZERO,Vector3(2.8,0.18,2.2),SHADOW)
		var collision:=CollisionShape3D.new()
		var bounds:=BoxShape3D.new()
		bounds.size=Vector3(2.8,0.18,2.2)
		collision.shape=bounds
		body.add_child(collision)
		for x in [-1.32,1.32]: space_box(body,Vector3(x,0.1,0),Vector3(0.085,0.02,2.13),ORANGE)
		for i in 6: space_box(body,Vector3(0,0.101,-0.96+i*0.35),Vector3(2.48,0.012,0.045),DARK)
	for x in [-3.95,3.95]:
		wall(Vector3(x,1,9.25),Vector3(1.6,3.2,4.7))
		_box(Vector3(x,1,10.7),Vector3(1.65,3.25,0.6),ORANGE)
		_box(Vector3(x,1,11.63),Vector3(1.3,2.5,0.15),DARK)
	for x in [-2.5,2.5]:
		for z in [0,8.5]: wall(Vector3(x,-0.7,z),Vector3(0.35,1.05,0.6),DARK)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-35,-35,0)
	sun.light_energy=0.65
	sun.shadow_enabled=true
	add_child(sun)

func space_box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow:=false) -> MeshInstance3D:
	var m:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=size
	m.mesh=box
	m.position=at
	m.material_override=_material(color,glow)
	parent.add_child(m)
	return m

func _build_flight_space() -> void:
	space_root=Node3D.new()
	add_child(space_root)
	for i in 4:
		var node:=Node3D.new()
		space_root.add_child(node)
		station_nodes.append(node)
		# Open berth, aft service spine, and side machinery give a readable approach.
		space_box(node,Vector3(0,-1.45,0),Vector3(42,0.5,52),Color("434c4b"))
		space_box(node,Vector3(0,7,45),Vector3(52,16,20),Color("7c8175"))
		for side in [-1,1]:
			space_box(node,Vector3(side*20,3,8),Vector3(4,8,65),DARK)
			space_box(node,Vector3(side*20,7.2,8),Vector3(3.8,0.25,60),ORANGE)
			space_box(node,Vector3(side*55,9,45),Vector3(62,1,20),Color("293a47"))
			for z in range(-22,26,4): space_box(node,Vector3(side*7,-1.15,z),Vector3(0.15,0.08,1.4),Color("a8d9c2"),true)
		for x in range(-20,21,5): space_box(node,Vector3(x,10,34.9),Vector3(1.2,0.6,0.08),Color("f5d69a"),true)
		var title:=Label3D.new()
		title.font=font
		title.font_size=80
		title.pixel_size=0.02
		title.text=FlightState.NAMES[i].to_upper()+"\nBERTH K-01"
		title.position=Vector3(0,6,34.8)
		title.rotation.y=PI
		title.no_depth_test=false
		title.modulate=Color("efc878")
		node.add_child(title)
	station_deck=StaticBody3D.new()
	add_child(station_deck)
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(42,0.5,52)
	collision.shape=box
	collision.position=Vector3(0,-1.45,0)
	station_deck.add_child(collision)
	stars=Node3D.new()
	add_child(stars)
	var random:=RandomNumberGenerator.new()
	random.seed=92811
	for i in 280:
		var dir:=Vector3(random.randfn(),random.randfn(),random.randfn()).normalized()
		space_box(stars,dir*4200,Vector3.ONE*random.randf_range(1,3),Color("939eae"),true)
	planet=MeshInstance3D.new()
	var globe:=SphereMesh.new()
	globe.radius=1
	globe.height=2
	globe.radial_segments=32
	globe.rings=16
	planet.mesh=globe
	planet.material_override=_material(Color("54757c"))
	add_child(planet)
	for z in [-7.5,3.0,9.2]:
		var repeater:=Label3D.new()
		repeater.font=font
		repeater.font_size=48
		repeater.pixel_size=0.0012
		repeater.position=Vector3(0,2.22,z)
		repeater.modulate=Color("aadbb1")
		add_child(repeater)
		status_repeaters.append(repeater)

func _register_life_actions() -> void:
	life_box("sleep","Rest until maneuver warning",Vector3(-0.90,0.90,-7.1),Vector3(0.10,0.6,1.45))
	life_box("eat","Prepare a meal",Vector3(1.10,1.10,-7.02),Vector3(0.16,0.16,0.56))
	life_box("drink","Drink water",Vector3(1.08,1.18,-8.12),Vector3(0.16,0.28,0.48))

func life_box(action: String, words: String, at: Vector3, size: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.position=at
	body.collision_layer=64
	body.collision_mask=0
	body.set_meta("life_action",action)
	body.set_meta("life_label",words)
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	add_child(body)
	life_targets.append(body)

func aimed_life() -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*2.1,65,[player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("life_action"): return {"action":hit.collider.get_meta("life_action"),"label":hit.collider.get_meta("life_label")}
	return {}

func aimed_terminal() -> Node:
	# Plane intersection respects the glass bounds and the real hardware occlusion.
	var nearest:=2.4
	var result: Node
	for terminal in terminals:
		var panel: Node3D=terminal.panel
		var origin:=panel.to_local(camera.global_position)
		var direction:=panel.global_basis.inverse()*(-camera.global_basis.z)
		if direction.z>=-0.01: continue
		var distance: float=(0.174-origin.z)/direction.z
		if distance<0 or distance>nearest: continue
		var point:=origin+direction*distance
		var size: Vector2=panel.get_meta("display_size")
		if absf(point.x)>size.x/2 or absf(point.y)>size.y/2: continue
		var query:=PhysicsRayQueryParameters3D.create(camera.global_position,panel.to_global(point),1,[player.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		nearest=distance
		result=terminal
	return result

func open_terminal(terminal: Node) -> void:
	if cargo_module.carrying: return
	if active_terminal:
		active_terminal.focused=false
		active_terminal.refresh()
	else:
		camera_before_terminal=camera.transform
	active_terminal=terminal
	var panel: Node3D=terminal.panel
	var screen_size: Vector2=panel.get_meta("display_size")
	var eye_distance:=0.174+screen_size.y*1.9
	var offset:=0.20 if terminal.kind=="nav" and not flight.printed_route.is_empty() else 0.0
	camera.global_transform=panel.global_transform*Transform3D(Basis.IDENTITY,Vector3(offset,0,eye_distance))
	var aspect:=get_viewport().get_visible_rect().size.aspect()
	camera.fov=rad_to_deg(2*atan(tan(deg_to_rad(55)/2)*maxf(1,1.6/aspect))) if offset>0 else 55
	terminal.focus()
	player.velocity=Vector3.ZERO
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func close_terminal() -> void:
	if active_terminal:
		active_terminal.focused=false
		active_terminal.refresh()
	active_terminal=null
	camera.transform=camera_before_terminal
	camera.fov=76

func sync_hardware() -> void:
	flight.hatch_closed=not loading_module.hatch_open
	flight.ramp_raised=ramp_up
	flight.closures_busy=loading_module.hatch_moving or ramp_moving
	flight.cargo_secured=cargo_module.locked and not cargo_module.carrying
	flight.coolant=0.0 if engineering_module.isolated else (0.82 if engineering_module.repaired else 0.70)
	loading_module.flight_locked=flight.phase!="docked"

func terminal_command(kind: String, value: String) -> String:
	sync_hardware()
	var words:=value.strip_edges().to_lower().split(" ",false)
	if words.is_empty(): return ""
	if words[0]=="go":
		if words.size()!=2 or words[1] not in ["chart","nav","fuel","engine","comms"]:
			return "Use go chart, go nav, go fuel, go engine or go comms."
		for terminal in terminals:
			if terminal.kind==words[1]:
				open_terminal(terminal)
				return "Now at "+words[1].to_upper()+". Type help for your next step."
	if kind=="engine" and words.size()==2:
		if words[0]=="hatch" and words[1] in ["open","close"]:
			if flight.phase!="docked": return "Hatch sealed for flight. Dock first."
			if loading_module.hatch_moving: return "Hatch moving. Wait for SEALED."
			var wanted: bool=words[1]=="open"
			if loading_module.hatch_open!=wanted: loading_module.use("load_inner")
			return "Hatch moving." if loading_module.hatch_moving else (loading_module.notice if not loading_module.notice.is_empty() else "Hatch already set.")
		if words[0]=="ramp" and words[1] in ["raise","lower"]: return set_ramp(words[1]=="raise")
	if kind=="comms":
		if words[0]=="save": return save_session()
		if words[0]=="load": return load_session()
		if words[0]=="service":
			if flight.phase!="docked": return "Station services require docking."
			if engineering_module.isolated or engineering_module.cover_open: return "Close the repair cover and restore coolant first."
			engineering_module.repaired=true
			engineering_module.bypass_ready=true
			engineering_module._refresh()
			flight.rations=8
			flight.drinks=12
			return "Test supply: provisions restocked and coolant serviced."
	var result: String=flight.command(kind,value)
	if kind=="chart" and words[0]=="print" and result.contains("PRINTED"):
		flight_sheet.refresh(true)
		_play_chime()
	_update_flight_world()
	return result

func set_ramp(raised: bool) -> String:
	if flight.phase!="docked": return "Ramp locked for flight. Dock first."
	if ramp_moving: return "Ramp moving."
	if raised==ramp_up: return "Ramp already "+("raised." if raised else "lowered.")
	if raised and (loading_module.hatch_open or loading_module.hatch_moving): return "Close the cargo hatch first."
	if raised and loading_module.occupied(Vector3(0,0.7,13.2),Vector3(3.3,4.4,4.8)): return "Ramp occupied. Step aboard and clear the hinge."
	ramp_moving=true
	ramp_tween=create_tween()
	if raised:
		ramp_tween.tween_property(ramp_fold,"rotation:x",PI,0.7)
		ramp_tween.tween_property(ramp_pivot,"rotation:x",-PI/2,1.0)
	else:
		ramp_tween.tween_property(ramp_pivot,"rotation:x",atan(1.2/4.2),1.0)
		ramp_tween.tween_property(ramp_fold,"rotation:x",0.0,0.7)
	ramp_tween.tween_callback(func():
		ramp_up=raised
		ramp_moving=false
		sync_hardware())
	return "Ramp "+("raising." if raised else "lowering.")

func _unhandled_input(event: InputEvent) -> void:
	if not flight_ready: return
	if active_terminal:
		if event is InputEventKey:
			if event.pressed and event.keycode==KEY_ESCAPE: close_terminal()
			else: active_terminal.handle_key(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			paused=not paused
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
			return
		if paused: return
		if event.physical_keycode==KEY_F:
			if flight.sleeping:
				flight.sleeping=false
				flight.warp=1
				return
			var target:=aimed_terminal()
			if target:
				open_terminal(target)
				return
			var life:=aimed_life()
			if not life.is_empty():
				use_life(life.action)
				return
			if seated and flight.phase not in ["docked","coast"]:
				flight.alert("Establish a stable coast before leaving the pilot seat.")
				return
	if paused: return
	super._unhandled_input(event)

func use_life(action: String) -> void:
	if cargo_module.carrying:
		flight.alert("Secure your cargo before using the hab.")
		return
	match action:
		"sleep": flight.alert(flight.sleep_until_warning())
		"eat":
			if flight.rations<=0: flight.alert("Food locker empty. COMMS: service at a station.")
			else:
				flight.rations-=1
				flight.food=minf(100,flight.food+40)
				flight.alert("Meal prepared. Food %.0f%% / %d meals remain." % [flight.food,flight.rations])
		"drink":
			if flight.drinks<=0: flight.alert("Water supply empty. COMMS: service at a station.")
			else:
				flight.drinks-=1
				flight.water=minf(100,flight.water+45)
				flight.alert("Water restored to %.0f%%. %d portions remain." % [flight.water,flight.drinks])

func key(code: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(code) else 0.0

func _physics_process(delta: float) -> void:
	if not flight_ready or paused: return
	if test_running:
		if active_terminal==null: super._physics_process(delta)
		return
	sync_hardware()
	var thrust:=Vector3.ZERO
	var rotation_input:=Vector3.ZERO
	var stop:=false
	if seated and active_terminal==null and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		thrust=Vector3(key(KEY_D)-key(KEY_A),key(KEY_R)-key(KEY_V),key(KEY_S)-key(KEY_W))
		rotation_input=Vector3(key(KEY_UP)-key(KEY_DOWN),key(KEY_LEFT)-key(KEY_RIGHT),key(KEY_Q)-key(KEY_E))
		if Input.is_physical_key_pressed(KEY_SHIFT):
			thrust*=0.12
			rotation_input*=0.25
		stop=Input.is_physical_key_pressed(KEY_X)
	flight.tick(delta,thrust,rotation_input,stop)
	if active_terminal==null and not flight.sleeping: super._physics_process(delta)
	if flight.sleeping:
		player.velocity=Vector3.ZERO
	# Existing physical washroom controls now affect the journey's hygiene state.
	if service_module.shower_on or service_module.tap_on:
		flight.hygiene=minf(100,flight.hygiene+delta*4)
	_update_flight_world()
	automatic_save_timer-=delta
	if automatic_save_timer<=0 and not cargo_module.carrying and not ramp_moving and not loading_module.hatch_moving:
		automatic_save_timer=60
		save_session()

func _update_flight_world() -> void:
	if not is_instance_valid(space_root): return
	var inverse:=flight.attitude.inverse()
	stars.basis=inverse
	for i in 4:
		var offset: Vector3=flight.station_position(i,flight.elapsed)-flight.ship_position
		var scale_factor:=minf(1,3500/maxf(1,offset.length()))
		station_nodes[i].position=inverse*offset*scale_factor
		station_nodes[i].basis=inverse.scaled(Vector3.ONE*scale_factor)
	var planet_offset: Vector3=FlightState.PLANET-flight.ship_position
	var planet_scale:=3500/planet_offset.length()
	planet.position=inverse*planet_offset*planet_scale
	planet.scale=Vector3.ONE*90000*planet_scale
	station_deck.collision_layer=1 if flight.phase=="docked" else 0

func _process(delta: float) -> void:
	if not flight_ready: return
	super._process(delta)
	room_label.text=room_label.text.replace("WALKABLE DESIGN STUDY","K-01 / "+flight.phase.to_upper())
	var controls: Label=overlay.get_child(1)
	controls.text="WASD WALK   MOUSE LOOK   F USE   ESC PAUSE"
	if seated: controls.text="W/S THRUST   A/D STRAFE   R/V LIFT   ARROWS STEER   Q/E ROLL   X STOP SPIN   SHIFT FINE   F USE"
	room_label.visible=active_terminal==null
	cockpit_hint.visible=active_terminal==null
	if active_terminal:
		cockpit_hint.text="%s / TYPE COMMANDS ON THE CRT" % active_terminal.kind.to_upper()
		controls.text="ENTER RUN   HELP NEXT STEP   COMMANDS REFERENCE   GO NAV / CHART / FUEL / ENGINE / COMMS   ESC BACK"
	else:
		var target:=aimed_terminal()
		if target: cockpit_hint.text="[F] USE "+target.kind.to_upper()+" TERMINAL"
		else:
			var life:=aimed_life()
			if not life.is_empty(): cockpit_hint.text="[F] "+life.label
	if flight.warning_serial!=seen_warning:
		seen_warning=flight.warning_serial
		notice_timer=12
		_play_chime()
	notice_timer=maxf(0,notice_timer-delta)
	announcement.text=flight.warning if notice_timer>0 and active_terminal==null else ""
	if paused: announcement.text="PAUSED / ESC TO RESUME\nProgress autosaves. COMMS: save / load."
	if flight.sleeping: announcement.text="RESTING / TIME 20x\nAlarm at 75 seconds to burn. F to wake."
	for repeater in status_repeaters:
		repeater.text="%s  /  BURN %.0fs\n%s" % [flight.phase.to_upper(),flight.time_to_burn(),flight.warning if notice_timer>0 else "FOOD %02d  WATER %02d  REST %02d" % [flight.food,flight.water,flight.rest]]

func _play_chime() -> void:
	if DisplayServer.get_name()=="headless": return
	var audio:=AudioStreamWAV.new()
	audio.format=AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate=22050
	var samples:=PackedByteArray()
	samples.resize(11025*2)
	for i in 11025:
		var t:=float(i)/22050
		var envelope:=maxf(0,1-t*2)*minf(1,t*60)
		var sample:=int(sin(t*TAU*(660 if t<0.23 else 880))*envelope*1700)
		samples.encode_s16(i*2,sample)
	audio.data=samples
	sound.stream=audio
	sound.play()

func save_session(path:=SAVE_FILE) -> String:
	if cargo_module.carrying or ramp_moving or loading_module.hatch_moving or engineering_module.cover_moving:
		return "Finish moving hardware and secure your carried case before saving."
	sync_hardware()
	var data:=flight.snapshot()
	data["rooms"]={"crate_slot":cargo_module.crate_slot,"locked":cargo_module.locked,"repaired":engineering_module.repaired,"isolated":engineering_module.isolated,"cover":engineering_module.cover_open,"fuses":engineering_module.fuse_pattern.duplicate(),"bypass":engineering_module.bypass_ready}
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return "Save failed. Previous session preserved."
	file.store_string(JSON.stringify(data))
	file.close()
	var result:=DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	return "Flight and ship state saved." if result==OK else "Save failed. Previous session preserved."

func load_session(path:=SAVE_FILE) -> String:
	if cargo_module.carrying or ramp_moving or loading_module.hatch_moving or engineering_module.cover_moving: return "Finish cargo/hatch movement before loading."
	if not FileAccess.file_exists(path): return "No saved Longhaul flight yet."
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("rooms") is Dictionary: return "Save is incomplete; current session preserved."
	var r: Dictionary=data.rooms
	for k in ["crate_slot","locked","repaired","isolated","cover","fuses","bypass"]:
		if not r.has(k): return "Save room state incomplete."
	if not (r.crate_slot is float or r.crate_slot is int) or r.crate_slot!=int(r.crate_slot) or int(r.crate_slot) not in [0,1] or not r.fuses is Array or r.fuses.size()!=3: return "Save room state invalid."
	for k in ["locked","repaired","isolated","cover","bypass"]:
		if not r[k] is bool: return "Save room state invalid."
	for v in r.fuses:
		if not v is bool: return "Save fuse state invalid."
	if not flight.restore(data): return "Save invalid; current session preserved."
	ramp_up=flight.ramp_raised
	ramp_pivot.rotation.x=-PI/2 if ramp_up else atan(1.2/4.2)
	ramp_fold.rotation.x=PI if ramp_up else 0
	loading_module.hatch_open=not flight.hatch_closed
	for i in 2: loading_module.leaves[i].position.x=(-1 if i==0 else 1)*(2.14 if loading_module.hatch_open else 0.70)
	loading_module._update_status()
	engineering_module.repaired=r.repaired
	engineering_module.isolated=r.isolated
	engineering_module.cover_open=r.cover
	engineering_module.service_cover.position.y=1.975 if r.cover else 1.13
	engineering_module.fuse_pattern.assign(r.fuses)
	engineering_module.bypass_ready=r.bypass
	engineering_module._refresh()
	cargo_module.crate_slot=int(r.crate_slot)
	cargo_module.locked=r.locked
	cargo_module.held_crate.position=cargo_module.slots[cargo_module.crate_slot]
	cargo_module._update_manifest()
	if active_terminal: close_terminal()
	_take_seat()
	_update_flight_world()
	flight.alert("Saved flight restored. Type help at any terminal for your next step.")
	return flight.warning

func _run_flight_tests() -> void:
	await _frames(5)
	var suite=load("res://scripts/longhaul_flight_test.gd").new()
	var ok: bool=await suite.run(self)
	var guide_suite=load("res://scripts/longhaul_flight_guidance_test.gd").new()
	ok=(await guide_suite.run(self)) and ok
	print("LONGHAUL FLIGHT ","PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _capture_flight() -> void:
	_take_seat()
	var args:=OS.get_cmdline_user_args()
	var index:=args.find("--flight-capture")
	var mode:=args[index+1] if index+1<args.size() else "pilot"
	if mode=="paper":
		terminal_command("engine","power on")
		terminal_command("fuel","mixture 2.5")
		terminal_command("chart","plot tharsis direct")
		terminal_command("chart","print")
		open_terminal(terminals[1])
		terminals[1].submit("plot")
	elif mode!="pilot":
		for terminal in terminals:
			if terminal.kind==mode:
				open_terminal(terminal)
				if mode=="chart": terminal.submit("plot tharsis direct")
				break
	await _frames(40)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/longhaul-flight-"+mode+".png")
	get_tree().quit()
