extends Node3D
## A dot-matrix route slip: physical printer output and a readable held copy at NAV.
var host: Node3D
var viewport: SubViewport
var feed: MeshInstance3D
var held: MeshInstance3D
var labels: Dictionary = {}
var ink := Color("30392f")
var paper_key := ""
var feed_tween: Tween

func build(ship: Node3D, chart_panel: Node3D) -> void:
	host=ship
	viewport=SubViewport.new()
	viewport.size=Vector2i(720,1000)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var bg:=ColorRect.new()
	bg.size=viewport.size
	bg.color=Color("e6dec3")
	viewport.add_child(bg)
	for x in [18,686]:
		for y in range(20,980,40): rect(Vector2(x,y),Vector2(12,12),Color("9c9989"))
	rect(Vector2(54,35),Vector2(612,63),Color("a56139"))
	text_label("brand","LONGHAUL / FLIGHT ORDER",Vector2(70,44),38,Color("f8e9c7"))
	text_label("route","",Vector2(64,115),40)
	rect(Vector2(62,205),Vector2(590,3),ink)
	text_label("coords_title","01  COORDINATES / km",Vector2(64,230),34)
	text_label("coords","",Vector2(84,278),44)
	rect(Vector2(62,431),Vector2(590,2),ink)
	text_label("burn","",Vector2(64,453),39)
	text_label("reserve","",Vector2(64,521),39)
	rect(Vector2(62,584),Vector2(590,2),ink)
	text_label("fuel","",Vector2(64,603),31)
	text_label("instructions","AT THE MIDDLE NAV COMPUTER\n1. Type plot\n2. Copy X Y Z on one line\n3. Enter burn, then reserve\n4. Type load",Vector2(64,688),32)
	text_label("footer","READBACK COPY / KEEP AT NAV\nTake your time. No launch deadline.",Vector2(64,889),29)
	var material:=StandardMaterial3D.new()
	material.albedo_texture=viewport.get_texture()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	# Compact printer fixed beneath the chart housing, above the keyboard.
	var printer:=Node3D.new()
	chart_panel.add_child(printer)
	printer.position=Vector3(-0.08,-0.32,-0.08)
	host.space_box(printer,Vector3.ZERO,Vector3(0.31,0.13,0.25),Color("9b9b86"))
	host.space_box(printer,Vector3(0,0.02,0.13),Vector3(0.27,0.024,0.014),Color("202924"))
	host.space_box(printer,Vector3(0.11,-0.029,0.135),Vector3(0.025,0.017,0.01),Color("99d8a4"),true)
	feed=paper_quad(Vector2(0.21,0.29),material,printer)
	feed.position=Vector3(0,-0.015,0.24)
	feed.rotation.x=deg_to_rad(-67)
	feed.visible=false
	# This held sheet sits in the camera's right-hand view while typing at NAV.
	held=paper_quad(Vector2(0.32,0.445)*(0.32/0.84),material,host.camera)
	held.position=Vector3(0.32,-0.005,-0.84)*(0.32/0.84)
	held.rotation.z=deg_to_rad(-2)
	held.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	held.visible=false

func rect(at: Vector2, extent: Vector2, color: Color) -> void:
	var r:=ColorRect.new()
	r.position=at
	r.size=extent
	r.color=color
	viewport.add_child(r)

func text_label(key: String, value: String, at: Vector2, font_size: int, color:=Color("30392f")) -> void:
	var item:=Label.new()
	item.position=at
	item.size=Vector2(610,190)
	item.add_theme_font_override("font",host.font)
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	item.text=value
	viewport.add_child(item)
	labels[key]=item

func paper_quad(size: Vector2, material: Material, parent: Node3D) -> MeshInstance3D:
	var item:=MeshInstance3D.new()
	var mesh:=QuadMesh.new()
	mesh.size=size
	item.mesh=mesh
	item.material_override=material
	parent.add_child(item)
	return item

func refresh(animate:=false) -> void:
	var ticket: Dictionary=host.flight.printed_route
	var new_key:=JSON.stringify(ticket)
	if paper_key!=new_key:
		paper_key=new_key
		feed.visible=not ticket.is_empty()
		if not ticket.is_empty():
			labels.route.text="SHEET %03d / %s\nTO %s" % [ticket.revision,str(ticket.style).to_upper(),str(ticket.station).to_upper()]
			var coords: PackedStringArray=ticket.coords.split(" ",false)
			labels.coords.text="X   %s\nY   %s\nZ   %s" % [coords[0],coords[1],coords[2]]
			labels.burn.text="02  BURN       %.2f kg/s" % ticket.burn
			labels.reserve.text="03  RESERVE    %.0f kg" % ticket.reserve
			labels.fuel.text="TRIP FUEL  %.0f kg + %.0f reserve\nARRIVAL BRAKING INCLUDED" % [ticket.fuel,ticket.reserve]
	if animate and not ticket.is_empty():
		if feed_tween: feed_tween.kill()
		feed.scale.y=0.05
		feed_tween=create_tween()
		feed_tween.tween_property(feed,"scale:y",1.0,0.85)
	held.visible=not ticket.is_empty() and host.active_terminal!=null and host.active_terminal.kind=="nav"

func _process(_delta: float) -> void:
	refresh()
