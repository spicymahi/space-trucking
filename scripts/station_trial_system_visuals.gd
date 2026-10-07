extends "res://scripts/longhaul_system_visuals.gd"
## One provisional industrial station family at every existing economy location.
## Shared meshes are distant shells; only the active port loads detailed bay art.
const DistantStation=preload("res://assets/stations/industrial_keel/station_distant.glb")
const StationStructure=preload("res://assets/stations/industrial_keel/station_structure.glb")
const StandardHangar=preload("res://assets/stations/industrial_keel/standard_hangar.glb")
const STRUCTURE_OFFSET:=Vector3(27,-1.315,0)
const DETAIL_RANGE:=1800.0
var near_station:Node3D
var adjacent_bay:Node3D
var active_station_index:=0

func build(owner_node:Node3D) -> void:
	super.build(owner_node)
	near_station=Node3D.new();near_station.name="IndustrialKeelNear";add_child(near_station)
	var structure:Node3D=StationStructure.instantiate()
	structure.position=STRUCTURE_OFFSET;near_station.add_child(structure)
	adjacent_bay=StandardHangar.instantiate()
	adjacent_bay.name="Bay02Exterior";adjacent_bay.position=Vector3(54,-1.315,0)
	near_station.add_child(adjacent_bay)
	# This bay is visible outside, but its controllers and collisions belong only
	# to the assigned bay. Door leaves remain in their exported closed pose.
	for animation in adjacent_bay.find_children("*","AnimationPlayer",true,false): animation.stop()
	_add_approach_lights(near_station)

func _build_station(index:int) -> void:
	var node:=Node3D.new();node.name=System.NAMES[index].validate_node_name()
	node.set_meta("station_index",index);station_nodes.append(node);add_child(node)
	var exterior:Node3D=DistantStation.instantiate();exterior.position=STRUCTURE_OFFSET;node.add_child(exterior)

func update(state:RefCounted) -> void:
	super.update(state)
	var index:int=state.reference_station_id()
	var distance:float=state.ship_position.distance_to(state.station_position(index,state.elapsed))
	# NAV switches its reference to the destination as soon as engaged. Keep the
	# departure hangar physically present until it is actually out of range.
	for candidate in station_nodes.size():
		var candidate_distance:float=state.ship_position.distance_to(state.station_position(candidate,state.elapsed))
		if candidate_distance<distance:
			index=candidate;distance=candidate_distance
	active_station_index=index
	var active:=distance<DETAIL_RANGE
	near_station.visible=active
	if active:
		near_station.transform=host.station_frame(index)
		station_nodes[index].hide()

func _add_approach_lights(parent:Node3D) -> void:
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("a6ddb8");material.emission_enabled=true;material.emission=Color("81bc98")
	material.emission_energy_multiplier=1.5
	for distance in [42,65,100,160,240,320]:
		for side in [-1,1]:
			var light:=MeshInstance3D.new();light.name="ApproachBeacon"
			var shape:=BoxMesh.new();shape.size=Vector3(0.3,0.3,1.4)
			light.mesh=shape;light.material_override=material
			light.position=Vector3(side*8.5,1.8,distance);parent.add_child(light)
