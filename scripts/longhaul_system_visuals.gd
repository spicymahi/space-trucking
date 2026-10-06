extends Node3D
## The Aurel system in the ship's floating local frame. All bodies use one real
## scale: positions and radii are transformed together, preserving occultation.
const System = preload("res://scripts/longhaul_system.gd")
const SUN_DIRECTION := Vector3(-0.45, 0.55, -0.70)
const AUREL_AXIAL_TILT := 17.0
const CREAM := Color("b7b5a2")
const DARK := Color("293632")
const RUST := Color("a86138")
const WINDOW := Color("edcd86")
var host: Node3D
var station_nodes: Array[Node3D] = []
var moon_nodes: Array[Node3D] = []
var planet: Node3D
var stars: Node3D
var celestial_viewport: SubViewport
var celestial_camera: Camera3D
var celestial_root: Node3D
var _solid: SurfaceTool
var _glow: SurfaceTool

func build(owner_node: Node3D) -> void:
	host=owner_node
	name="AurelSystem"
	_build_background_pass()
	planet=Node3D.new()
	planet.name="Aurel"
	celestial_root.add_child(planet)
	var globe:=_globe_mesh(-1,96,48)
	planet.add_child(globe)
	globe.scale=Vector3.ONE*System.PLANET_RADIUS
	globe.rotation_degrees.z=AUREL_AXIAL_TILT
	var ring_plane:=Node3D.new()
	ring_plane.name="Rings"
	ring_plane.rotation_degrees.z=AUREL_AXIAL_TILT
	planet.add_child(ring_plane)
	_build_rings(ring_plane)
	for i in System.MOONS.size():
		var moon:=Node3D.new()
		moon.name=str(System.MOONS[i].name)
		moon.set_meta("moon_index",i)
		celestial_root.add_child(moon)
		moon_nodes.append(moon)
		var surface:=_globe_mesh(i,64,32)
		surface.scale=Vector3.ONE*float(System.MOONS[i].body_radius_km)/System.REAL_KM_PER_UNIT
		moon.add_child(surface)
		if System.MOONS[i].kind in ["cloud","atmosphere"]:
			_atmosphere(moon,float(System.MOONS[i].body_radius_km)/System.REAL_KM_PER_UNIT,Color(System.MOONS[i].color))
	for i in System.STATIONS.size():
		_build_station(i)
	_build_stars()

func _build_background_pass() -> void:
	# The cockpit needs a centimetre-scale near plane. Giving that same camera
	# a two-million-unit far plane degenerates Metal's culling frustum. A second
	# camera renders real astronomical distances, then sits behind local geometry.
	celestial_viewport=SubViewport.new()
	celestial_viewport.name="AstronomicalBackground"
	celestial_viewport.own_world_3d=true
	celestial_viewport.msaa_3d=Viewport.MSAA_4X
	celestial_viewport.size=Vector2i(1280,800)
	celestial_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(celestial_viewport)
	celestial_root=Node3D.new()
	celestial_viewport.add_child(celestial_root)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("050a12")
	celestial_root.add_child(environment)
	celestial_camera=Camera3D.new()
	celestial_camera.near=10.0
	celestial_camera.far=2000000.0
	celestial_root.add_child(celestial_camera)
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D celestial_image : source_color, filter_linear;
void vertex() {
    POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}
void fragment() {
    ALBEDO = texture(celestial_image, SCREEN_UV).rgb;
}
"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.render_priority=-128
	material.set_shader_parameter("celestial_image",celestial_viewport.get_texture())
	var screen:=MeshInstance3D.new()
	screen.name="CelestialBackdrop"
	var quad:=QuadMesh.new()
	quad.size=Vector2(2,2)
	screen.mesh=quad
	screen.material_override=material
	screen.extra_cull_margin=16384
	screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)

func _process(_delta: float) -> void:
	var main_camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(main_camera): return
	celestial_camera.transform=main_camera.global_transform
	celestial_camera.fov=main_camera.fov
	celestial_camera.keep_aspect=main_camera.keep_aspect
	celestial_camera.h_offset=main_camera.h_offset
	celestial_camera.v_offset=main_camera.v_offset
	var dimensions:=Vector2i(get_viewport().get_visible_rect().size)
	if dimensions.x>0 and dimensions.y>0 and celestial_viewport.size!=dimensions:
		celestial_viewport.size=dimensions

static func overview_pose() -> Dictionary:
	return {"position":System.PLANET+Vector3(22000,24000,65000),"look_at":System.PLANET}

func update(state: RefCounted) -> void:
	var inverse: Basis=state.attitude.inverse()
	planet.transform=Transform3D(inverse,inverse*(System.PLANET-state.ship_position))
	for i in moon_nodes.size():
		moon_nodes[i].transform=Transform3D(inverse,inverse*(System.moon_position(i,state.elapsed)-state.ship_position))
	for i in station_nodes.size():
		var offset: Vector3=state.station_position(i,state.elapsed)-state.ship_position
		station_nodes[i].transform=Transform3D(inverse,inverse*offset)
		station_nodes[i].visible=not _station_occulted(state.ship_position,offset,state.elapsed)
	stars.basis=inverse

func _station_occulted(origin: Vector3, offset: Vector3, when: float) -> bool:
	# Local stations render over the astronomical pass. Geometric visibility
	# prevents a station on a moon's far side drawing through its silhouette.
	var distance:=offset.length()
	if distance<1: return false
	var direction:=offset/distance
	if _ray_hits_body(origin,direction,distance,System.PLANET,System.PLANET_RADIUS): return true
	for i in System.MOONS.size():
		if _ray_hits_body(origin,direction,distance,System.moon_position(i,when),System.moon_radius(i)): return true
	return false

func _ray_hits_body(origin: Vector3, direction: Vector3, distance: float, center: Vector3, radius: float) -> bool:
	var relative:=center-origin
	var along:=relative.dot(direction)
	if along<=0 or along>=distance: return false
	return (relative-direction*along).length_squared()<radius*radius

func _material(unshaded: bool) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=0.92
	if unshaded:
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _mesh(tool: SurfaceTool, parent: Node3D, mesh_name: String, unshaded:=false) -> MeshInstance3D:
	var instance:=MeshInstance3D.new()
	instance.name=mesh_name
	instance.mesh=tool.commit()
	instance.material_override=_material(unshaded)
	if unshaded: instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _tool() -> SurfaceTool:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.set_color(color)
	# Godot uses clockwise front faces, viewed from outside.
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var normal: Vector3=(c-a).cross(b-a).normalized()
	_triangle(tool,a,b,c,color,normal)
	_triangle(tool,a,c,d,color,normal)

func _box(at: Vector3, size: Vector3, color: Color, glow:=false) -> void:
	var tool: SurfaceTool=_glow if glow else _solid
	var h:=size*0.5
	var a:=at+Vector3(-h.x,-h.y,-h.z)
	var b:=at+Vector3(h.x,-h.y,-h.z)
	var c:=at+Vector3(h.x,h.y,-h.z)
	var d:=at+Vector3(-h.x,h.y,-h.z)
	var e:=at+Vector3(-h.x,-h.y,h.z)
	var f:=at+Vector3(h.x,-h.y,h.z)
	var g:=at+Vector3(h.x,h.y,h.z)
	var h8:=at+Vector3(-h.x,h.y,h.z)
	_quad(tool,a,b,c,d,color)
	_quad(tool,f,e,h8,g,color)
	_quad(tool,e,a,d,h8,color)
	_quad(tool,b,f,g,c,color)
	_quad(tool,d,c,g,h8,color)
	_quad(tool,e,f,b,a,color)

func _cylinder(at: Vector3, radius: float, height: float, color: Color, segments:=12) -> void:
	for n in segments:
		var a:=TAU*n/segments
		var b:=TAU*(n+1)/segments
		var va:=Vector3(cos(a)*radius,-height/2,sin(a)*radius)
		var vb:=Vector3(cos(b)*radius,-height/2,sin(b)*radius)
		var top:=Vector3(0,height,0)
		_quad(_solid,at+va,at+va+top,at+vb+top,at+vb,color)
		_triangle(_solid,at+Vector3(0,height/2,0),at+vb+top,at+va+top,color,Vector3.UP)
		_triangle(_solid,at+Vector3(0,-height/2,0),at+va,at+vb,color,Vector3.DOWN)

func _build_station(index: int) -> void:
	var data: Dictionary=System.STATIONS[index]
	var node:=Node3D.new()
	node.name=str(data.name).validate_node_name()
	node.set_meta("station_index",index)
	station_nodes.append(node)
	add_child(node)
	_solid=_tool()
	_glow=_tool()
	var accent:=Color(data.get("color","a86138"))
	# Berth K-01 stays geometrically identical at every station. Structural
	# variations sit behind its service wall or outside its unobstructed entry.
	_box(Vector3(0,-1.45,0),Vector3(42,0.5,52),Color("434c4b"))
	_box(Vector3(0,-3.9,3),Vector3(44,4.4,56),DARK)
	_box(Vector3(0,7,45),Vector3(52,16,20),CREAM)
	_box(Vector3(0,15.3,45),Vector3(54,0.6,22),accent)
	_box(Vector3(0,5.5,34.88),Vector3(30,5.5,0.12),DARK)
	for side in [-1,1]:
		_box(Vector3(side*20,3,8),Vector3(4,8,65),DARK)
		_box(Vector3(side*20,7.2,8),Vector3(3.8,0.25,60),accent)
		for z in range(-22,26,4):
			_box(Vector3(side*7,-1.15,z),Vector3(0.15,0.08,1.4),Color("a8d9c2"),true)
		for z in [-19,-7,5,17,29]:
			_box(Vector3(side*17.88,2,z),Vector3(0.14,3.8,7),CREAM.darkened(0.2))
			_box(Vector3(side*17.77,4.25,z),Vector3(0.12,0.15,5),WINDOW,true)
		_box(Vector3(side*11,-1.18,0),Vector3(0.20,0.02,49),accent)
	for x in range(-20,21,5):
		_box(Vector3(x,11.5,34.9),Vector3(1.2,0.6,0.08),WINDOW,true)
	for distance in [60,150,300]:
		for side in [-1,1]:
			_box(Vector3(side*12,1,-distance),Vector3(0.6,0.6,2),Color("81daa4"),true)
	for x in [-4,0,4]:
		_box(Vector3(x,-1.185,0),Vector3(0.035,0.015,50),DARK)
	for z in range(-24,26,5):
		_box(Vector3(0,-1.185,z),Vector3(35,0.015,0.035),DARK)
	var style: String=(str(data.get("style",""))+" "+str(data.get("role",""))+" "+str(data.get("purpose",""))).to_lower()
	if "yard" in style or "repair" in style:
		_shipyard(accent,index)
	elif "fuel" in style or "refin" in style:
		_tank_farm(accent,index)
	elif "food" in style or "agri" in style or "green" in style:
		_greenhouses(accent,index)
	elif "hab" in style or "settle" in style or "residen" in style:
		_habitat(accent,index)
	elif "relay" in style or "comm" in style:
		_relay(accent,index)
	elif "research" in style or "observ" in style or "science" in style:
		_observatory(accent,index)
	elif "min" in style or "ore" in style or "foundry" in style:
		_ore_works(accent,index)
	else:
		_freight_hub(accent,index)
	_mesh(_solid,node,"StationStructure")
	_mesh(_glow,node,"BerthLights",true)
	_sign(node,str(data.name).to_upper()+"\nBERTH K-01",Vector3(0,6.2,34.75),72,0.019,WINDOW)
	_sign(node,str(data.get("role","ORBITAL STATION")).to_upper(),Vector3(0,2.8,34.74),40,0.013,Color("a8d9c2"))
	_sign(node,"K-01",Vector3(0,-1.15,-16),130,0.025,Color("b9c5ab"),true)

func _sign(parent: Node3D, words: String, at: Vector3, font_size: int, pixel_size: float, color: Color, floor_sign:=false) -> void:
	var label:=Label3D.new()
	label.font=host.font
	label.font_size=font_size
	label.pixel_size=pixel_size
	label.text=words
	label.position=at
	label.rotation=Vector3(-PI/2,0,0) if floor_sign else Vector3(0,PI,0)
	label.modulate=color
	label.outline_size=0
	label.no_depth_test=false
	parent.add_child(label)

func _window_row(at: Vector3, count: int, spacing:=3.0) -> void:
	for j in count:
		_box(at+Vector3((j-(count-1)/2.0)*spacing,0,0),Vector3(1.35,0.65,0.08),WINDOW,true)

func _solar_wing(side: int, z: float, width:=40.0) -> void:
	_box(Vector3(side*(31+width/2),4,z),Vector3(width+14,1.3,2),DARK)
	for panel in 3:
		var x:=side*(36+panel*width/3)
		_box(Vector3(x,4.85,z),Vector3(width/3-0.6,0.35,22),Color("25454f"))
		for band in 5:
			_box(Vector3(x,5.04,z-9+band*4.5),Vector3(width/3-1,0.03,0.13),Color("65928b"))

func _freight_hub(accent: Color, index: int) -> void:
	for side in [-1,1]:
		_box(Vector3(side*49,0,66),Vector3(49,6,70),DARK)
		for column in 3:
			for level in 2+(index%2):
				_box(Vector3(side*(34+column*14),6+level*8,56),Vector3(12,7,25),accent if (column+level)%2==0 else CREAM.darkened(0.25))
		_box(Vector3(side*76,24,55),Vector3(3,44,6),CREAM)
	_box(Vector3(0,45,55),Vector3(156,3,7),accent)
	_box(Vector3(0,39,55),Vector3(8,11,5),DARK)
	_box(Vector3(0,24,88),Vector3(36,16,28),CREAM)
	_window_row(Vector3(0,28,73.9),10)
	if index==0:
		# Central exchange: stacked traffic-control cab and a broad antenna crown.
		_box(Vector3(0,37,88),Vector3(25,9,20),CREAM)
		_window_row(Vector3(0,39,77.9),7)
		_box(Vector3(0,45,88),Vector3(34,2,14),accent)
	elif index==3:
		# Outer interchange: a pair of long-range dishes and extended radiators.
		_dish(Vector3(-40,43,89),10,accent)
		_dish(Vector3(40,43,89),10,accent)
		for side in [-1,1]: _solar_wing(side,118,31)
	elif index==5:
		# Ember's exchange has an asymmetric insulated cargo tower.
		_box(Vector3(59,39,89),Vector3(23,43,26),CREAM.darkened(0.18))
		for level in 4:
			_box(Vector3(59,24+level*11,75.9),Vector3(24,2,0.2),accent)
	else:
		# Ochre's remote depot carries visibly bolted-on life-support stores.
		for side in [-1,1]:
			_cylinder(Vector3(side*88,12,86),9,25,CREAM)
			_box(Vector3(side*88,27,86),Vector3(20,2,20),accent)

func _shipyard(accent: Color, index: int) -> void:
	for z in [60,94,128]:
		for side in [-1,1]:
			_box(Vector3(side*56,22,z),Vector3(5,52,5),CREAM)
			_box(Vector3(side*55,50,z),Vector3(5,0.25,4),WINDOW,true)
		_box(Vector3(0,47,z),Vector3(116,5,5),accent)
		_box(Vector3(0,-3,z),Vector3(116,5,5),DARK)
	for side in [-1,1]:
		_box(Vector3(side*57,-1,93),Vector3(9,8,82),DARK)
		_box(Vector3(side*75,13,83),Vector3(28,20,32),CREAM)
		_window_row(Vector3(side*75,16,66.9),7)
	_box(Vector3(10,12,98),Vector3(19+index,12,53),accent.darkened(0.12))
	_box(Vector3(10,20,109),Vector3(13,5,27),CREAM)

func _tank_farm(accent: Color, index: int) -> void:
	for side in [-1,1]:
		_box(Vector3(side*49,0,69),Vector3(49,5,77),DARK)
		for k in 3:
			var p:=Vector3(side*(36+(k%2)*24),14,46+k*24)
			_cylinder(p,10,27+(index%3)*3,CREAM.darkened(0.12))
			_cylinder(p+Vector3(0,5,0),10.15,3,accent)
			_box(p+Vector3(0,22,0),Vector3(1,16,1),DARK)
		_box(Vector3(side*27,3,75),Vector3(2,2,65),accent)
	_box(Vector3(0,12,96),Vector3(27,22,20),CREAM)
	_window_row(Vector3(0,18,85.9),7)

func _greenhouses(accent: Color, index: int) -> void:
	for side in [-1,1]:
		for k in 3:
			var p:=Vector3(side*54,3+k*10,64+k*5)
			_box(p,Vector3(60,2,38),CREAM)
			_box(p+Vector3(0,4,0),Vector3(56,6,34),Color("376f5c"))
			for rib in 5:
				_box(p+Vector3(-25+rib*12.5,4,0),Vector3(0.9,8,37),accent)
			_box(p+Vector3(0,3,-17.1),Vector3(51,0.18,0.10),Color("9cbd78"),true)
		_solar_wing(side,113,40+index)
	_box(Vector3(0,27,92),Vector3(24,24,27),CREAM)

func _habitat(accent: Color, index: int) -> void:
	var radius:=43.0+index%3*7
	var center:=Vector3(0,28,94)
	_box(Vector3(0,7,74),Vector3(12,13,57),DARK)
	for k in 16:
		var angle:=TAU*k/16
		var p:=center+Vector3(cos(angle)*radius,sin(angle)*radius,0)
		_box(p,Vector3(17,12,18),CREAM if k%2==0 else CREAM.darkened(0.18))
		_box(p+Vector3(0,4,-9.1),Vector3(13,0.8,0.1),WINDOW,true)
		_box(p+Vector3(0,-4,-9.1),Vector3(13,1.2,0.15),accent)
	_box(center,Vector3(radius*2,3,6),DARK)
	_box(center,Vector3(3,radius*2,6),DARK)
	_box(center,Vector3(17,17,24),accent)

func _dish(at: Vector3, radius: float, accent: Color) -> void:
	_box(at+Vector3(0,-radius,4),Vector3(3,radius*2,4),DARK)
	# Stepped, shallow receiving bowl facing the berth side of the station.
	for step in 4:
		var r:=radius*(1.0-step*0.19)
		_box(at+Vector3(0,0,step*1.1),Vector3(r*2,r*2,1.1),CREAM if step%2==0 else CREAM.darkened(0.1))
	_box(at+Vector3(0,0,-5),Vector3(1.3,1.3,14),accent)
	_box(at+Vector3(0,0,-12),Vector3(3,3,2),Color("a8d9c2"),true)

func _observatory(accent: Color, index: int) -> void:
	for side in [-1,1]:
		_box(Vector3(side*44,12,66),Vector3(30,18,36),CREAM)
		_box(Vector3(side*44,22,66),Vector3(32,2,38),accent)
		_window_row(Vector3(side*44,14,47.9),8)
		_dish(Vector3(side*49,47,72),14+index%3*2,accent)
		_solar_wing(side,109,35)
	_cylinder(Vector3(0,27,99),12,38,CREAM.darkened(0.13))
	_cylinder(Vector3(0,50,99),15,8,accent)

func _relay(accent: Color, index: int) -> void:
	_box(Vector3(0,10,75),Vector3(40,18,45),CREAM)
	for k in 5:
		_box(Vector3(0,28+k*12,80),Vector3(14,1.6,14),accent)
	for x in [-6,6]:
		for z in [74,86]:
			_box(Vector3(x,49,z),Vector3(1.3,72,1.3),DARK)
	_box(Vector3(0,99,80),Vector3(1.4,30+index,1.4),CREAM)
	_box(Vector3(0,115+index/2.0,80),Vector3(2.3,2.3,2.3),Color("d8ad69"),true)
	for side in [-1,1]:
		_dish(Vector3(side*31,46,82),12,accent)
		_solar_wing(side,75,30)

func _ore_works(accent: Color, index: int) -> void:
	for side in [-1,1]:
		_box(Vector3(side*47,-1,72),Vector3(47,7,79),DARK)
		for k in 3:
			_cylinder(Vector3(side*(35+k%2*21),15,46+k*25),9,29,CREAM.darkened(0.18+k*0.06),8)
			_box(Vector3(side*(35+k%2*21),32,46+k*25),Vector3(18,3,18),accent)
		_box(Vector3(side*43,38,74),Vector3(3,3,76),accent)
	_box(Vector3(0,18,108),Vector3(29,38+index%3*4,30),CREAM)
	for x in [-7,7]:
		_box(Vector3(x,49,109),Vector3(5,28,6),DARK)

func _sphere_point(latitude: float, longitude: float) -> Vector3:
	return Vector3(cos(latitude)*cos(longitude),sin(latitude),cos(latitude)*sin(longitude))

func _globe_mesh(moon_index: int, segments: int, latitude_steps: int) -> MeshInstance3D:
	var tool:=_tool()
	var noise:=FastNoiseLite.new()
	noise.seed=717+moon_index*981
	noise.frequency=3.1 if moon_index<0 else 4.0
	for row in latitude_steps:
		var lat_a: float=-PI/2+PI*row/latitude_steps
		var lat_b: float=-PI/2+PI*(row+1)/latitude_steps
		for column in segments:
			var lon_a: float=TAU*column/segments
			var lon_b: float=TAU*(column+1)/segments
			var center:=_sphere_point((lat_a+lat_b)/2,(lon_a+lon_b)/2)
			var color:=_surface_color(moon_index,center,noise)
			# Cloud bands and rings share Aurel's equator, while illumination
			# remains anchored to the same system-space sun as the other bodies.
			var lit_normal:=center.rotated(Vector3.BACK,deg_to_rad(AUREL_AXIAL_TILT)) if moon_index<0 else center
			var lighting:=0.12+0.88*maxf(0,lit_normal.dot(SUN_DIRECTION.normalized()))
			color=Color(color.r*lighting,color.g*lighting,color.b*lighting)
			var a:=_sphere_point(lat_a,lon_a)
			var b:=_sphere_point(lat_a,lon_b)
			var c:=_sphere_point(lat_b,lon_b)
			var d:=_sphere_point(lat_b,lon_a)
			_quad(tool,a,b,c,d,color)
	var result:=MeshInstance3D.new()
	result.name="FacetedSurface"
	result.mesh=tool.commit()
	result.material_override=_material(true)
	result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

func _surface_color(moon_index: int, point: Vector3, noise: FastNoiseLite) -> Color:
	var n:=noise.get_noise_3dv(point)
	if moon_index<0:
		var palette: Array[Color]=[Color("ceab72"),Color("ead5a1"),Color("986848"),Color("bf8c5e"),Color("e9c58b"),Color("b07c50"),Color("ddc499")]
		var band:=int(floor((point.y+1)*16+n*1.2))
		var storm:=pow((point.y+0.26)/0.13,2)+pow((point.x-0.83)/0.22,2)
		if point.z<0 and storm<1.0: return Color("a76744") if storm>0.35 else Color("d8a273")
		return palette[posmod(band,palette.size())].lightened(n*0.1)
	var base:=Color(System.MOONS[moon_index].color)
	# Atmospheric worlds have broad cloudy belts; airless moons have mottled
	# impact basins and isolated bright rims. Ice worlds carry blue fractures.
	if System.MOONS[moon_index].kind in ["cloud","atmosphere"]:
		var clouds:=noise.get_noise_3dv(point*Vector3(1,2.7,1))
		return base.lerp(Color("d4d3b9"),clampf((clouds+0.15)*1.8,0,0.68)).darkened(maxf(0,-n)*0.25)
	if System.MOONS[moon_index].kind in ["ice","dark_ice"]:
		var crack:=absf(noise.get_noise_3dv(point*2.1))
		return base.darkened(0.3) if crack<0.035 else base.lightened(n*0.25)
	var basin:=noise.get_noise_3dv(point*1.7)
	var result:=base.lightened(n*0.45)
	if basin>0.28: result=result.darkened(0.29)
	elif basin>0.20: result=result.lightened(0.17)
	if moon_index==0 and absf(noise.get_noise_3dv(point*3.4))<0.025:
		result=result.lerp(Color("a76639"),0.55)
	return result

func _atmosphere(parent: Node3D, radius: float, tint: Color) -> void:
	var shell:=MeshInstance3D.new()
	shell.name="AtmosphericLimb"
	var sphere:=SphereMesh.new()
	sphere.radius=radius*1.015
	sphere.height=sphere.radius*2
	sphere.radial_segments=64
	sphere.rings=32
	shell.mesh=sphere
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 atmosphere_color : source_color;
void fragment() {
    float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
    ALBEDO = atmosphere_color.rgb * 0.18;
    ALPHA = rim * 0.38;
}
"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("atmosphere_color",tint)
	shell.material_override=material
	shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shell)

func _build_rings(parent: Node3D) -> void:
	var tool:=_tool()
	var palette: Array[Color]=[Color("746d5c"),Color("b7ab8e"),Color("d3c7a8"),Color("a5967c"),Color("ded5b7"),Color("8c806c")]
	var bands:=28
	var inner: float=System.RING_INNER
	var width: float=System.RING_OUTER-inner
	for band in bands:
		if band in [8,9,20]: continue
		var near_radius:=inner+width*band/bands
		var far_radius:=inner+width*(band+0.90)/bands
		for segment in 160:
			var a:=TAU*segment/160
			var b:=TAU*(segment+1)/160
			var midpoint:=Vector3(cos((a+b)/2)*(near_radius+far_radius)/2,0,sin((a+b)/2)*(near_radius+far_radius)/2)
			# A geometric planet-shadow mask on the rings, fixed to the system sun.
			var sun:=Basis(Vector3.FORWARD,deg_to_rad(AUREL_AXIAL_TILT))*SUN_DIRECTION.normalized()
			var to_sun:=midpoint.dot(sun)
			var shadow:=to_sun<0 and (midpoint-sun*to_sun).length()<System.PLANET_RADIUS
			var color:=palette[band%palette.size()].darkened(0.75 if shadow else 0.15)
			_quad(tool,Vector3(cos(a)*near_radius,0,sin(a)*near_radius),Vector3(cos(b)*near_radius,0,sin(b)*near_radius),Vector3(cos(b)*far_radius,0,sin(b)*far_radius),Vector3(cos(a)*far_radius,0,sin(a)*far_radius),color)
	var rings:=_mesh(tool,parent,"BandedRings",true)
	(rings.material_override as StandardMaterial3D).cull_mode=BaseMaterial3D.CULL_DISABLED

func _build_stars() -> void:
	stars=Node3D.new()
	stars.name="DistantStars"
	celestial_root.add_child(stars)
	_solid=_tool()
	_glow=_tool()
	var random:=RandomNumberGenerator.new()
	random.seed=92811
	for i in 360:
		var direction:=Vector3(random.randfn(),random.randfn(),random.randfn()).normalized()
		_box(direction*1800000,Vector3.ONE*random.randf_range(150,420),Color("687b88") if i%4 else Color("b5b7a2"),true)
	_mesh(_glow,stars,"Starfield",true)
