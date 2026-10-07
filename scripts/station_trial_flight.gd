extends "res://scripts/ship_life_flight.gd"
## The Blender hangar integration has its own scene and flight adapter.
const StationFlightState=preload("res://scripts/station_trial_flight_state.gd")

func _ready() -> void:
	super._ready()
	flight=StationFlightState.new()

func _build_flight_space() -> void:
	system_visuals=preload("res://scripts/station_trial_system_visuals.gd").new()
	add_child(system_visuals);system_visuals.build(self)
	space_root=system_visuals;station_nodes=system_visuals.station_nodes;planet=system_visuals.planet;stars=system_visuals.stars
	# Compatibility node only: the runtime hangar owns the real floor/wall shapes.
	station_deck=StaticBody3D.new();station_deck.name="UnusedLegacyDeck";add_child(station_deck)
	station_deck.collision_layer=0
	for z in [-7.5,3.0,9.2]:
		var repeater:=Label3D.new();repeater.font=font;repeater.font_size=48;repeater.pixel_size=0.0012
		repeater.position=Vector3(0,2.22,z);repeater.modulate=Color("aadbb1");add_child(repeater);status_repeaters.append(repeater)

func station_frame(index:int) -> Transform3D:
	var inverse:Basis=flight.attitude.inverse()
	return Transform3D(inverse,inverse*(flight.station_position(index,flight.elapsed)-flight.ship_position))

func nearby_station_id() -> int:
	return system_visuals.active_station_index if is_instance_valid(system_visuals) else flight.reference_station_id()

func prepare_hangar_departure() -> String:
	if not controller or not controller.station_hangar: return "Hangar is initializing."
	if flight.phase!="docked": return ""
	if not flight.base_departure_ready(): return ""
	flight.departure_door_requested=true
	controller.station_hangar.set_door_open(true)
	flight.hangar_door_clear=controller.station_hangar.door_clear_for_flight
	if not flight.hangar_door_clear:
		return "BAY 01 / pressure door opening. Wait until it is fully clear, then enter depart again. Your flight checklist remains ready."
	return ""

func terminal_command(kind:String,value:String,source:Node=null) -> String:
	if kind=="comms" and value.strip_edges().to_lower()=="depart":
		var notice:=prepare_hangar_departure()
		if not notice.is_empty(): return notice
	return super.terminal_command(kind,value,source)

func sync_hardware() -> void:
	super.sync_hardware()
	if controller and controller.station_hangar:
		flight.hangar_door_clear=controller.station_hangar.door_clear_for_flight

func update_hangar_state() -> void:
	if not controller or not controller.station_hangar: return
	var runtime:Node3D=controller.station_hangar
	var index:=nearby_station_id()
	var near:bool=flight.ship_position.distance_to(flight.station_position(index,flight.elapsed))<1800
	var open:bool=(flight.phase=="docked" and flight.departure_door_requested) or (flight.phase=="departure" and index==flight.dock_id) or (near and index==flight.destination and flight.approach_clearance)
	runtime.set_door_open(open)
	flight.hangar_door_clear=runtime.door_clear_for_flight

func _update_flight_world() -> void:
	if not is_instance_valid(space_root): return
	system_visuals.update(flight)
	update_hangar_state()
	if controller: controller.refresh_dock_visibility()
