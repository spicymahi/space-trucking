extends "res://scripts/longhaul_flight.gd"
## The existing cockpit/flight implementation hosted by the combined cargo-life session.
## Initialization deliberately never loads the legacy flight save or freight system.
var controller:Node3D

class LifeFlightState extends "res://scripts/longhaul_flight_state.gd":
	var sensors_ready:=true
	func can_depart() -> bool:
		return sensors_ready and super.can_depart()
	func checklist() -> String:
		return super.checklist()+"\nSENSOR CONDITION: "+("OK" if sensors_ready else "PORT REPAIR REQUIRED")

class LifeTerminal extends "res://scripts/longhaul_terminal.gd":
	func refresh() -> void:
		super.refresh()
		if host.controller and kind not in ["chart","map"]:
			header.text="K-01 / %s\n%s | %.0f kg | %s" % [kind.to_upper(),host.flight.phase.to_upper(),host.flight.fuel,host.controller.life.time_text()]

func _ready() -> void:
	flight=LifeFlightState.new()
	_build_environment()
	hull=StaticBody3D.new();add_child(hull)
	_build_ship()
	for child in get_children():
		if child.get_script()==preload("res://scripts/longhaul_cockpit.gd"):cockpit_module=child
	preload("res://scripts/longhaul_blender_assets.gd").install(self,cockpit_module)
	cargo_module.hide()
	for body in cargo_module.find_children("*","CollisionObject3D",true,false):body.collision_layer=0
	for node in get_node("BlenderLonghaul").find_children("*","Node3D",true,false):
		if node.get_meta("extras",{}).get("room","")=="Cargo" and "Equipment" in String(node.name):node.hide()
	# Only the combined controller runs gameplay. Existing furniture animations remain available.
	set_process(false);set_physics_process(false);set_process_unhandled_input(false)

func configure(owner_node:Node3D) -> void:
	controller=owner_node
	player=controller.walker;camera=controller.camera
	camera.far=10000
	var roles={"nav":"chart","dock":"nav","fuel":"checklist","drive":"engine","comms":"comms","radar":"radar","power":"velocity"}
	for screen in cockpit_module.monitor_faces:
		var terminal:=LifeTerminal.new();add_child(terminal)
		terminal.build(self,screen,"distance" if screen.get_meta("content")=="comms" and screen.position.y>2 else roles.get(screen.get_meta("content"),"nav"))
		terminals.append(terminal)
	flight_sheet=preload("res://scripts/longhaul_flight_sheet.gd").new();add_child(flight_sheet)
	flight_sheet.build(self,terminals[0].panel)
	_build_flight_space()
	flight.fuel=900
	sync_hardware()
	_update_flight_world()

func sync_hardware() -> void:
	if not controller:return
	flight.hatch_closed=not loading_module.hatch_open
	flight.ramp_raised=ramp_up
	flight.closures_busy=loading_module.hatch_moving or ramp_moving
	flight.cargo_secured=controller.parcels.is_empty() or (controller.locked and controller.load_readiness().is_empty())
	flight.cargo_mass=560.0+controller.parcels.size()*35.0
	flight.coolant=0.82
	flight.sensors_ready=controller.life.can_depart()
	loading_module.flight_locked=flight.phase!="docked"

func terminal_command(kind:String,value:String,source:Node=null) -> String:
	var words:=value.strip_edges().to_lower().split(" ",false)
	if words.is_empty():return ""
	var op:String=words[0]
	if op in ["warp","sleep"]:return "Use the bunk for sleep or pass time. Shipboard time stays consistent."
	if kind=="comms":
		if op in ["jobs","contract"]:return controller._job_board() if op=="jobs" else controller._status()
		if op=="accept":return "Accept freight at the hangar CONTRACTS terminal."
		if op=="depart":return controller.flight_departure()
		if op=="refuel":return controller.buy_fuel()
		if op=="service":return "Use PROVISIONS or REPAIRS in the hangar. All operating costs are paid from your wallet."
		if op=="save":return controller.save_life()
		if op=="load":return controller.load_life()
		if op in ["crew","deliver"]:return "Use the hand tool and dock DELIVERY completion terminal."
		if op=="rescue":return controller.rescue_ship()
		if op=="help" or op=="commands":return "jobs / contract / refuel / save / load\n"+flight.command(kind,value)
	return super.terminal_command(kind,value,source)

func freight_manifest() -> String:
	return controller._status() if controller else ""

func save_session(_path:=SAVE_FILE) -> String:
	return controller.save_life() if controller else "Combined session not ready."

func load_session(_path:=SAVE_FILE) -> String:
	return controller.load_life() if controller else "Combined session not ready."

func _update_flight_world() -> void:
	super._update_flight_world()
	if controller:controller.refresh_dock_visibility()
