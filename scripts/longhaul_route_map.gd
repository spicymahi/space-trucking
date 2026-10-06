extends Control
## In-world chart: current orbits and the numerically propagated transfer.
var host: Node3D
var map_font: Font
var tint:=Color("84bf9b")
var centre:=Vector2(0,0)
var map_scale:=0.00028

func point(world: Vector3) -> Vector2:
	return Vector2(size.x*0.47,size.y*0.53)+Vector2(world.x,world.z)*map_scale

func _draw() -> void:
	if not host: return
	var f=host.flight
	var points: Array[Vector3]=[]
	var max_distance:=200000.0
	for i in 4:
		var p: Vector3=f.station_position(i,f.elapsed)
		points.append(p)
		max_distance=maxf(max_distance,maxf(absf(p.x),absf(p.z)))
	max_distance=maxf(max_distance,maxf(absf(f.ship_position.x),absf(f.ship_position.z)))
	map_scale=minf(size.x*0.42,size.y*0.42)/max_distance
	for x in range(0,int(size.x),70): draw_line(Vector2(x,0),Vector2(x,size.y),Color("19352a"))
	for y in range(0,int(size.y),45): draw_line(Vector2(0,y),Vector2(size.x,y),Color("19352a"))
	for i in 4:
		var arc:=PackedVector2Array()
		for j in 21: arc.append(point(f.station_position(i,f.elapsed+j*90)))
		draw_polyline(arc,Color("315848"),1)
		var p:=point(points[i])
		draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),tint,false,2)
		draw_string(map_font,p+Vector2(10,-4),f.IDS[i].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,21,tint)
	var primary:=point(f.PLANET)
	draw_circle(primary,90000*map_scale,Color("284d48"))
	draw_arc(primary,90000*map_scale,0,TAU,32,tint,1)
	var here:=point(f.ship_position)
	draw_circle(here,5,Color("ffe7ab"))
	if not f.plan.is_empty():
		var path:=PackedVector2Array()
		var v: Vector3=f.plan.velocity if not f.loaded else f.velocity
		var duration: float=maxf(0,f.plan.eta-f.elapsed)
		for j in 26: path.append(point(f.propagate(f.ship_position,v,duration*j/25)[0]))
		draw_polyline(path,Color("efd39b"),2,true)
		var target:=point(f.plan.target)
		draw_circle(target,7,Color("efd39b"),false,2)
	draw_string(map_font,Vector2(12,size.y-8),"X / Z  |  ORBITS + TRANSFER  |  km",HORIZONTAL_ALIGNMENT_LEFT,-1,22,tint)
