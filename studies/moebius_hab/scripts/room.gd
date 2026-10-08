extends Node3D
## New, standalone walking controller. All imported geometry belongs to this study.
const INK = preload("res://shaders/outline.gdshader")
const PAINT = preload("res://shaders/illustrated.gdshader")
var body: CharacterBody3D
var eye: Camera3D
var pitch := -0.065
var ui: Label
var capturing := false
var art: Node3D
var material_count := 0
const SPAWN := Vector3(1.0,0.02,1.0)
const EYE_HEIGHT := 1.62

func _ready() -> void:
    DisplayServer.window_set_title("Illustrated Hab — new room study")
    art = preload("res://assets/hab.glb").instantiate()
    add_child(art)
    _materials(art)
    _collisions()
    _lighting()
    _space_view()
    _player()
    var canvas := CanvasLayer.new(); add_child(canvas)
    ui = Label.new(); canvas.add_child(ui); ui.position=Vector2(22,20)
    ui.text="HAB / ILLUSTRATION STUDY\nWASD walk · Mouse look · Shift stroll faster\nEsc release mouse · Click resume · R return to entrance · H hide controls"
    ui.add_theme_font_size_override("font_size",16)
    ui.add_theme_color_override("font_color",Color("efe7d3"))
    ui.add_theme_color_override("font_shadow_color",Color("263c52"))
    ui.add_theme_constant_override("shadow_offset_x",1);ui.add_theme_constant_override("shadow_offset_y",1)
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    print("HAB READY / new authored materials ",material_count," / no save or gameplay systems")
    if "--capture" in OS.get_cmdline_user_args():
        capturing=true
        _capture.call_deferred()
    elif "--walk-test" in OS.get_cmdline_user_args():
        capturing=true
        _walk_test.call_deferred()

func _materials(node:Node) -> void:
    if node is MeshInstance3D:
        var mesh := node as MeshInstance3D
        for i in mesh.mesh.get_surface_count():
            var source=mesh.get_active_material(i)
            if not source is StandardMaterial3D:continue
            var title:String=source.resource_name
            if title in ["Light","CRT","Phosphor"]:
                var flat:=StandardMaterial3D.new();flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
                flat.albedo_color=Color("ffdf9f") if title=="Light" else source.albedo_color
                mesh.set_surface_override_material(i,flat)
            elif title in ["Ink","Seam"]:
                var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
                ink.albedo_color=source.albedo_color;mesh.set_surface_override_material(i,ink)
            else:
                var paint:=ShaderMaterial.new();paint.shader=PAINT
                paint.set_shader_parameter("base_color",source.albedo_color)
                var contour:=ShaderMaterial.new();contour.shader=INK
                contour.set_shader_parameter("stroke",0.0021 if title!="WhiteCloth" else 0.0015)
                paint.next_pass=contour;mesh.set_surface_override_material(i,paint)
            material_count+=1
    for child in node.get_children():_materials(child)

func _collisions() -> void:
    var specs=JSON.parse_string(FileAccess.get_file_as_string("res://assets/collision.json"))
    for spec in specs:
        var solid:=StaticBody3D.new();solid.name=spec.name;add_child(solid)
        solid.position=Vector3(spec.center[0],spec.center[1],spec.center[2])
        var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
        box.size=Vector3(spec.size[0],spec.size[1],spec.size[2]);shape.shape=box;solid.add_child(shape)

func _lighting() -> void:
    var env:=WorldEnvironment.new();add_child(env);env.environment=Environment.new()
    var e:=env.environment
    e.background_mode=Environment.BG_COLOR;e.background_color=Color("173654")
    e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    # Restrained violet-grey bounce leaves room for warm practicals and dark recesses.
    e.ambient_light_color=Color("b4bfd3");e.ambient_light_energy=0.30
    e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.tonemap_exposure=1.0
    e.ssao_enabled=true;e.ssao_radius=0.28;e.ssao_intensity=1.5;e.ssao_power=1.5
    var sun:=DirectionalLight3D.new();add_child(sun);sun.name="WindowSun"
    sun.rotation_degrees=Vector3(-24,-65,0);sun.light_color=Color("ffdda5");sun.light_energy=1.10
    sun.light_angular_distance=0.0
    sun.shadow_enabled=true;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.directional_shadow_max_distance=18;sun.shadow_bias=0.10;sun.shadow_normal_bias=0.35
    # A small bounce contribution, rather than a room-wide key which washes out shadows.
    _omni(Vector3(.65,1.95,-1.20),Color("ffe0b0"),0.16,4.4)
    for p in [Vector3(.20,2.60,0.9),Vector3(.20,2.60,-2.0),Vector3(.20,2.60,-4.4)]:
        _spot(p,p+Vector3.DOWN,Color("ffd39a"),1.20,4.0,65.0)
    _spot(Vector3(-1.98,1.465,-4.07),Vector3(-1.75,0.95,-3.9),Color("ffd088"),0.70,1.75,53.0)
    _omni(Vector3(-1.86,1.40,-4.03),Color("ffda9b"),0.10,1.15)
    _omni(Vector3(1.70,1.59,-3.1),Color("ffdaa0"),0.36,1.85,true)
    _spot(Vector3(.42,2.36,-6.6),Vector3(.42,.2,-6.6),Color("ffd7a0"),.55,3.1,64.0)

func _omni(p:Vector3,c:Color,energy:float,radius:float,shadow:bool=false) -> void:
    var light:=OmniLight3D.new();add_child(light);light.position=p;light.light_color=c
    light.light_energy=energy;light.omni_range=radius;light.omni_attenuation=1.1
    light.light_specular=0;light.shadow_enabled=shadow
    if shadow:
        light.light_size=0.0;light.shadow_bias=0.08;light.shadow_normal_bias=0.3

func _spot(p:Vector3,target:Vector3,c:Color,energy:float,radius:float,angle:float) -> void:
    var light:=SpotLight3D.new();add_child(light);light.position=p
    # A forward vector parallel to UP requires a different look-at reference axis.
    light.look_at(target,Vector3.FORWARD if absf((target-p).normalized().y)>.98 else Vector3.UP)
    light.light_color=c;light.light_energy=energy;light.light_specular=0.0
    light.spot_range=radius;light.spot_angle=angle;light.spot_attenuation=1.1
    light.spot_angle_attenuation=0.65;light.light_size=0.0
    light.shadow_enabled=true;light.shadow_bias=0.08;light.shadow_normal_bias=0.30

func _space_view() -> void:
    # Newly generated backdrop geometry; the reference image is never used as scenery.
    var planet:=MeshInstance3D.new();add_child(planet)
    var globe:=SphereMesh.new();globe.radius=6.5;globe.height=13.;globe.radial_segments=96;globe.rings=48
    planet.mesh=globe;planet.position=Vector3(-32,6,-9)
    var shade:=ShaderMaterial.new();shade.shader=preload("res://shaders/planet.gdshader");planet.material_override=shade
    planet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var ring_root:=Node3D.new();add_child(ring_root);ring_root.position=planet.position
    ring_root.rotation_degrees=Vector3(14,0,-14)
    for idx in range(4):
        var vertices:=PackedVector3Array();var colors:=PackedColorArray()
        var radius:float=8.2+idx*0.8;var width:float=.52 if idx!=2 else .3
        var ring_color:Color=[Color("c9c9bc"),Color("b6b6b0"),Color("747f9b"),Color("e1d7bd")][idx]
        for i in range(192):
            var a:float=i*TAU/192;var b:float=(i+1)*TAU/192
            for p in [Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(cos(b)*radius,0,sin(b)*radius),Vector3(cos(a)*(radius+width),0,sin(a)*(radius+width)),Vector3(cos(b)*radius,0,sin(b)*radius),Vector3(cos(b)*(radius+width),0,sin(b)*(radius+width)),Vector3(cos(a)*(radius+width),0,sin(a)*(radius+width))]:vertices.append(p);colors.append(ring_color)
        var array:=[];array.resize(Mesh.ARRAY_MAX);array[Mesh.ARRAY_VERTEX]=vertices;array[Mesh.ARRAY_COLOR]=colors
        var ring_mesh:=ArrayMesh.new();ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,array)
        var ring:=MeshInstance3D.new();ring_root.add_child(ring);ring.mesh=ring_mesh
        var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;ring.material_override=material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var rand:=RandomNumberGenerator.new();rand.seed=91027
    var stars:=MultiMeshInstance3D.new();add_child(stars);stars.multimesh=MultiMesh.new();stars.multimesh.transform_format=MultiMesh.TRANSFORM_3D
    var sm:=SphereMesh.new();sm.radius=.035;sm.height=.07;sm.radial_segments=6;sm.rings=3;stars.multimesh.mesh=sm;stars.multimesh.instance_count=280
    var star_mat:=StandardMaterial3D.new();star_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_mat.albedo_color=Color("d4dfd9");stars.material_override=star_mat;stars.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for i in range(280):stars.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(-52,rand.randf_range(-18,35),rand.randf_range(-44,40))))

func _player() -> void:
    body=CharacterBody3D.new();body.name="Walker";add_child(body);body.position=SPAWN
    var collider:=CollisionShape3D.new();body.add_child(collider)
    var capsule:=CapsuleShape3D.new();capsule.radius=.22;capsule.height=1.76;collider.shape=capsule;collider.position.y=.89
    body.floor_snap_length=.20;body.safe_margin=.015
    eye=Camera3D.new();body.add_child(eye);eye.position.y=EYE_HEIGHT;eye.current=true;eye.fov=72;eye.near=.04;eye.far=120
    _reset_view()

func _reset_view() -> void:
    body.position=SPAWN;body.velocity=Vector3.ZERO
    var target:=Vector3(-1.30,1.25,-3.0)
    eye.rotation=Vector3.ZERO;body.rotation=Vector3.ZERO
    var d:Vector3=(target-eye.global_position).normalized()
    body.rotation.y=atan2(-d.x,-d.z);pitch=asin(d.y);eye.rotation.x=pitch

func _unhandled_input(event:InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
        body.rotate_y(-event.relative.x*.0021);pitch=clampf(pitch-event.relative.y*.0021,-1.35,1.35);eye.rotation.x=pitch
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
        elif event.keycode==KEY_R:_reset_view()
        elif event.keycode==KEY_H:ui.visible=not ui.visible
    elif event is InputEventMouseButton and event.pressed:
        Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _physics_process(delta:float) -> void:
    if capturing:return
    var input:=Vector2.ZERO
    if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
        input=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
    var direction:=body.basis*Vector3(input.x,0,input.y)
    var speed:=2.9 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.65
    body.velocity.x=move_toward(body.velocity.x,direction.x*speed,delta*9.)
    body.velocity.z=move_toward(body.velocity.z,direction.z*speed,delta*9.)
    if not body.is_on_floor():body.velocity.y-=9.8*delta
    else:body.velocity.y=-.1
    body.move_and_slide()
    if body.position.y< -2:_reset_view()

func _pose(pos:Vector3,target:Vector3) -> void:
    body.position=pos;body.rotation=Vector3.ZERO;eye.rotation=Vector3.ZERO
    var d:Vector3=(target-eye.global_position).normalized();body.rotation.y=atan2(-d.x,-d.z);eye.rotation.x=asin(d.y)

func _capture() -> void:
    ui.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    var shots:=[
        ["01-concept",SPAWN,Vector3(-1.30,1.25,-3.0)],
        ["02-bunk",Vector3(.70,.02,-1.0),Vector3(-1.70,1.35,-3.16)],
        ["03-galley",Vector3(-.55,.02,-2.30),Vector3(1.91,1.27,-3.1)],
        ["04-reverse",Vector3(.10,.02,-4.50),Vector3(-.1,1.20,.3)],
        ["05-desk",Vector3(.40,.02,.85),Vector3(-1.78,1.15,0.0)]
    ]
    for shot in shots:
        _pose(shot[1],shot[2])
        for i in 15:await get_tree().process_frame
        await RenderingServer.frame_post_draw
        var file:String="res://review/"+shot[0]+".png"
        get_viewport().get_texture().get_image().save_png(file)
        print("CAPTURE ",file)
    _reset_view()
    for i in 45:await get_tree().process_frame
    var times:Array[float]=[];var last:=Time.get_ticks_usec()
    for i in 90:
        await get_tree().process_frame
        var now:=Time.get_ticks_usec();times.append((now-last)/1000.);last=now
    times.sort();print("RENDER median_ms=",times[45]," p95=",times[85]," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    get_tree().quit()

func _walk_test() -> void:
    var failures:=0
    # Real capsule, gravity and static geometry: entry -> central aisle -> corridor -> return.
    var waypoints:=[Vector3(.1,0,-1.3),Vector3(.1,0,-4.35),Vector3(.42,0,-6.65),Vector3(.1,0,-3.1),Vector3(.1,0,-.9)]
    for target in waypoints:
        for step in 300:
            await get_tree().physics_frame
            var direction:Vector3=target-body.position;direction.y=0
            if direction.length()<.09:break
            direction=direction.normalized();body.velocity=Vector3(direction.x*1.8,body.velocity.y-9.8/60.,direction.z*1.8);body.move_and_slide()
        var distance:float=Vector2(target.x-body.position.x,target.z-body.position.z).length()
        var passed:bool=distance<.13 and body.position.y>-.05 and body.position.y<.08
        print("WALK ",target," ",passed," distance=",distance," floor_y=",body.position.y)
        if not passed:failures+=1
    # Cannot pass through the bunk collision; can approach it.
    body.position=Vector3(0,.02,-3.0)
    for i in 90:
        await get_tree().physics_frame;body.velocity=Vector3(-2,-.3,0);body.move_and_slide()
    var blocked:bool=body.position.x> -1.2 and body.position.x<-.7
    print("BUNK COLLISION ",blocked," x=",body.position.x)
    if not blocked:failures+=1
    print("WALK TEST failures=",failures)
    get_tree().quit(0 if failures==0 else 1)
