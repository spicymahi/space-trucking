extends Node3D
## Fixed-size paper moves through a clipping slot. Printed copies stay in a paper rack.
var host: Node3D
var viewport: SubViewport
var print_viewport: SubViewport
var feed: MeshInstance3D
var held: MeshInstance3D
var body: Label
var print_body: Label
var heading: Label
var print_heading: Label
var paper_key := ""
var feed_tween: Tween
var feed_material: ShaderMaterial
var progress := 0.0
var printing := false
var feed_paper_id := -1
var printer_sound: AudioStreamPlayer
var paper_bin: MeshInstance3D
var discard_tween: Tween

func build(ship: Node3D, chart_panel: Node3D) -> void:
	host=ship
	viewport=make_page()
	print_viewport=make_page()
	heading=viewport.get_node("Heading")
	body=viewport.get_node("Body")
	print_heading=print_viewport.get_node("Heading")
	print_body=print_viewport.get_node("Body")
	var material:=StandardMaterial3D.new()
	material.albedo_texture=viewport.get_texture()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var printer:=Node3D.new()
	chart_panel.add_child(printer)
	printer.position=Vector3(-0.08,-0.32,-0.08)
	host.space_box(printer,Vector3(0,0.025,-0.015),Vector3(0.33,0.16,0.28),Color("9b9b86"))
	host.space_box(printer,Vector3(0,-0.037,0.285),Vector3(0.265,0.016,0.32),Color("474e44"))
	host.space_box(printer,Vector3(0,-0.008,0.136),Vector3(0.25,0.022,0.012),Color("17201c"))
	for side in [-1,1]:
		host.space_box(printer,Vector3(side*0.126,-0.005,0.137),Vector3(0.021,0.025,0.018),Color("424840"))
	host.space_box(printer,Vector3(0.13,0.067,0.135),Vector3(0.018,0.014,0.008),Color("99d8a4"),true)
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, cull_disabled; uniform sampler2D page : source_color; uniform float amount = 0.0; void fragment(){ if (UV.y < 1.0-amount) discard; ALBEDO = texture(page, UV).rgb; }"
	feed_material=ShaderMaterial.new()
	feed_material.shader=shader
	feed_material.set_shader_parameter("page",print_viewport.get_texture())
	feed=paper_quad(Vector2(0.21,0.29),feed_material,printer)
	feed.rotation.x=-PI/2
	feed.visible=false
	held=paper_quad(Vector2(0.122,0.170),material,host.camera)
	held.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	held.visible=false
	printer_sound=AudioStreamPlayer.new()
	add_child(printer_sound)
	# A small recycling pocket below the console matches the existing cassette hardware.
	paper_bin=host.space_box(printer,Vector3(0,-0.16,0.08),Vector3(0.27,0.075,0.20),Color("646b5a"))
	host.space_box(printer,Vector3(0,-0.12,0.08),Vector3(0.22,0.008,0.15),Color("182520"))

func make_page() -> SubViewport:
	var page:=SubViewport.new()
	page.size=Vector2i(900,1280)
	page.disable_3d=true
	page.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(page)
	var bg:=ColorRect.new()
	bg.size=page.size
	bg.color=Color("e6dec3")
	page.add_child(bg)
	for x in [20,865]:
		for y in range(20,1260,42):
			var hole:=ColorRect.new()
			hole.position=Vector2(x,y)
			hole.size=Vector2(12,12)
			hole.color=Color("999688")
			page.add_child(hole)
	var strip:=ColorRect.new()
	strip.position=Vector2(54,32)
	strip.size=Vector2(790,67)
	strip.color=Color("a56139")
	page.add_child(strip)
	for name in ["Heading","Body","Commands","Details"]:
		var label:=Label.new()
		label.name=name
		label.position=Vector2(66,{"Heading":43,"Body":120,"Commands":330,"Details":650}[name])
		label.size=Vector2(774,1110 if name=="Body" else 100)
		label.visible=name in ["Heading","Body"]
		label.add_theme_font_override("font",host.font)
		label.add_theme_font_size_override("font_size",40 if name=="Heading" else 37)
		label.add_theme_color_override("font_color",Color("f8e9c7") if name=="Heading" else Color("30392f"))
		page.add_child(label)
	return page

func paper_quad(size: Vector2, material: Material, parent: Node3D) -> MeshInstance3D:
	var item:=MeshInstance3D.new()
	var mesh:=QuadMesh.new()
	mesh.size=size
	item.mesh=mesh
	item.material_override=material
	parent.add_child(item)
	return item

func paper_text(sheet: Dictionary) -> String:
	if sheet.kind=="checklist":
		return "DEPARTURE / COMMAND REFERENCE\n\n01 ENGINE / right arm\n   port on\n   starboard on\n02 CHART / forward left\n   stations\n   plot <station> direct\n   print\n03 NAV / forward middle\n   Copy the commands on your ROUTE sheet.\n04 COMMS / left arm\n   request\n   code <code returned by ATC>\n05 CHECKLIST / forward right\n   hatch close  (wait for sealed)\n   ramp raise   (wait for raised)\n   status       (all items must be OK)\n   Secure cargo clamps in the hold.\n06 COMMS: depart\n   Fly forward past the 300 m lights.\n07 NAV: engage\n   NAV stays engaged. Sleep wakes early.\n08 COMMS: approach\n   manual to fly, or: auto dock\n   Assistance: <1000 m / <15 m/s.\n   Manual: <20 m / <2 m/s; dock\n\nTAB pin / SHIFT+TAB next / DEL discard"
	var t: Dictionary=sheet.data
	return "FLIGHT ORDER %03d / %s\nTO %s\n\nTYPE AT THE MIDDLE NAV COMPUTER\nOne command per line; Enter to run.\n\ncoords %s\nburn %.2f\nreserve %.0f\nload\n\n--------------------------------\nCoordinates in kilometres.\nKeep all numbers and minus signs.\n\nTRIP FUEL   %.0f kg\nSPARE FUEL  %.0f kg\nSpare covers docking / corrections.\n\nTRANSFER ~%.0f min + approach\n\nAfter clearing the station:\nNAV: engage\n\nTAB pin / SHIFT+TAB next / DEL recycle" % [t.revision,str(t.style).to_upper(),str(t.station).to_upper(),t.coords,t.burn,t.reserve,t.fuel,t.reserve,(t.coast+120)/60]

func set_page_body(label: Label, sheet: Dictionary) -> void:
	var page: SubViewport=label.get_parent()
	var commands: Label=page.get_node("Commands")
	var details: Label=page.get_node("Details")
	commands.visible=sheet.kind=="route"
	details.visible=sheet.kind=="route"
	if sheet.kind=="route":
		var t: Dictionary=sheet.data
		label.text="FLIGHT ORDER %03d / %s\nTO %s\n\nTYPE AT NAV / ENTER AFTER EACH LINE" % [t.revision,str(t.style).to_upper(),str(t.station).to_upper()]
		label.add_theme_font_size_override("font_size",40)
		commands.text="coords %s\nburn %.2f\nreserve %.0f\nload" % [t.coords,t.burn,t.reserve]
		var command_size:=56
		commands.add_theme_font_size_override("font_size",command_size)
		while command_size>42 and commands.get_minimum_size().x>774:
			command_size-=1
			commands.add_theme_font_size_override("font_size",command_size)
		details.add_theme_font_size_override("font_size",38)
		details.text="Coordinates in km. Keep minus signs.\nBurn rate in kg per second.\n\nTRIP FUEL:  %.0f kg\nSPARE FUEL: %.0f kg\nSpare covers docking and corrections.\nTRANSFER: ~%.0f min + approach\n\nAfter clearing the station: NAV engage\n\nTAB pin / SHIFT+TAB next / DEL recycle" % [t.fuel,t.reserve,(t.coast+120)/60]
		return
	label.text=paper_text(sheet)
	var font_size:=37
	label.add_theme_font_size_override("font_size",font_size)
	while font_size>30 and (label.get_minimum_size().y>1100 or label.get_minimum_size().x>774):
		font_size-=1
		label.add_theme_font_size_override("font_size",font_size)

func print_sheet() -> void:
	var sheet: Dictionary=host.flight.current_paper()
	if sheet.is_empty(): return
	if feed_tween: feed_tween.kill()
	printing=true
	feed_paper_id=int(sheet.number)
	print_heading.text="LONGHAUL / SHEET %02d" % sheet.number
	set_page_body(print_body,sheet)
	feed.visible=true
	feed_tween=create_tween()
	# Small mechanical advances keep the page rigid; only the part beyond the slot is visible.
	set_feed(0)
	for step in range(1,25):
		feed_tween.tween_method(set_feed,float(step-1)/24,float(step)/24,0.055)
		feed_tween.tween_interval(0.025)
	feed_tween.tween_method(set_feed,1.0,1.10,0.18)
	feed_tween.tween_callback(func():
		printing=false
		feed.visible=false)
	play_printer()

func set_feed(value: float) -> void:
	progress=value
	feed.position=Vector3(0,-0.009,0.14-0.145+value*0.29)
	feed_material.set_shader_parameter("amount",minf(value,1))

func play_printer() -> void:
	if DisplayServer.get_name()=="headless": return
	var sound:=AudioStreamWAV.new()
	sound.format=AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate=22050
	var samples:=PackedByteArray()
	samples.resize(48000*2)
	var noise:=RandomNumberGenerator.new()
	noise.seed=42
	for i in 48000:
		var t:=float(i)/22050
		var gate:=1.0 if fmod(t,0.08)<0.055 else 0.1
		var v: float=(sin(t*TAU*130)*0.3+noise.randf_range(-0.45,0.45))*gate*1200
		samples.encode_s16(i*2,int(v))
	sound.data=samples
	printer_sound.stream=sound
	printer_sound.play()

func refresh(_animate:=false) -> void:
	var sheet: Dictionary=host.flight.current_paper()
	var new_key:=JSON.stringify(sheet)
	if new_key!=paper_key:
		paper_key=new_key
		if not sheet.is_empty():
			heading.text="LONGHAUL / SHEET %02d" % sheet.number
			set_page_body(body,sheet)
	if not printing or not host.flight.papers.any(func(p): return int(p.number)==feed_paper_id): feed.visible=false
	held.visible=(host.paper_pinned if host.active_terminal else host.flight.paper_visible) and not sheet.is_empty() and not printing
	if host.active_terminal:
		held.mesh.size=Vector2(0.122,0.170)
		held.position=Vector3(0.122,-0.002,-0.32)
		held.rotation=Vector3(0,0,deg_to_rad(-2))
	else:
		var aspect: float=host.get_viewport().get_visible_rect().size.aspect()
		var height:=minf(0.43,0.60*aspect)
		held.mesh.size=Vector2(height*900/1280,height)
		held.position=Vector3(0,0,-0.32)
		held.rotation=Vector3.ZERO

func _process(_delta: float) -> void:
	refresh()
