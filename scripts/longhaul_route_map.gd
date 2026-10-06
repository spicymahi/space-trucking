extends Control
## Current position and station ephemerides; flown trail and predicted transfer.
var host: Node3D
var map_font: Font
var tint:=Color("84bf9b")
var centre:=Vector3.ZERO
var map_scale:=0.00028

func point(world: Vector3) -> Vector2:
	var relative:=world-centre
	return size*0.5+Vector2(relative.x,relative.z)*map_scale

func _draw() -> void:
	if not host: return
	var f=host.flight
	var approach: bool=f.nav_selected and f.phase in ["brake","approach"] and f.station_range()<12000
	var future_arrival:=Vector3.ZERO
	var arrival_time: float=f.elapsed
	if not f.plan.is_empty() and not approach:
		var future_velocity: Vector3=f.propagate(f.ship_position,f.required_velocity if f.autopilot else f.plan.velocity,maxf(0,f.plan.eta-f.elapsed))[1]
		arrival_time=maxf(f.elapsed,f.plan.eta)+(future_velocity-f.station_velocity(f.destination,f.plan.eta)).length()/maxf(f.planning_acceleration(),1)+30
		future_arrival=f.station_position(f.destination,arrival_time)+f.hold_offset
	var targets: Array[Vector3]=[f.ship_position]
	if not f.plan.is_empty() and not approach:
		targets.append(f.plan.target)
		targets.append(future_arrival)
		if not f.trail.is_empty(): targets.append(f.trail[0])
	if f.nav_selected or not f.plan.is_empty(): targets.append(f.station_position(f.destination,f.elapsed))
	else:
		for i in 4: targets.append(f.station_position(i,f.elapsed))
	var low:=targets[0]
	var high:=targets[0]
	for target in targets:
		low=low.min(target)
		high=high.max(target)
	centre=(low+high)*0.5
	var extent:=high-low
	map_scale=minf(size.x*0.70/maxf(extent.x,1200 if approach else 100000),size.y*0.65/maxf(extent.z,1200 if approach else 100000))
	for x in range(0,int(size.x),70): draw_line(Vector2(x,0),Vector2(x,size.y),Color("19352a"))
	for y in range(0,int(size.y),45): draw_line(Vector2(0,y),Vector2(size.x,y),Color("19352a"))
	var bounds:=Rect2(Vector2(6,6),size-Vector2(12,12))
	if f.trail.size()>1:
		for i in range(1,f.trail.size()):
			var a:=point(f.trail[i-1])
			var b:=point(f.trail[i])
			if bounds.has_point(a) and bounds.has_point(b): draw_line(a,b,Color("63cdb5"),2,true)
	if not f.plan.is_empty():
		var previous:=point(f.ship_position)
		for j in range(1,41):
			var next: Vector2
			if approach:
				next=point(f.ship_position.lerp(f.station_position(f.destination,f.elapsed),float(j)/40))
			else:
				var speed: Vector3=f.required_velocity if f.autopilot else f.plan.velocity
				next=point(f.propagate(f.ship_position,speed,maxf(0,f.plan.eta-f.elapsed)*j/40)[0])
			if j%2==0 and bounds.has_point(previous) and bounds.has_point(next): draw_line(previous,next,Color("efd39b"),2,true)
			previous=next
		if not approach:
			var destination_point:=point(future_arrival)
			if bounds.has_point(previous) and bounds.has_point(destination_point):
				draw_dashed_line(previous,destination_point,Color("efd39b"),2,5)
			if bounds.has_point(destination_point):
				var diamond:=PackedVector2Array([destination_point+Vector2(0,-7),destination_point+Vector2(7,0),destination_point+Vector2(0,7),destination_point+Vector2(-7,0),destination_point+Vector2(0,-7)])
				draw_polyline(diamond,Color("efd39b"),2)
				draw_string(map_font,Vector2(clampf(destination_point.x+12,8,size.x-170),clampf(destination_point.y-15,30,size.y-40)),"ARRIVAL",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("efd39b"))
			var orbit:=point(f.station_position(f.destination,f.elapsed))
			for j in range(1,20):
				var next:=point(f.station_position(f.destination,lerpf(f.elapsed,arrival_time,float(j)/19)))
				if bounds.has_point(orbit) and bounds.has_point(next): draw_line(orbit,next,Color("385848"),1)
				orbit=next
	for i in 4:
		var p:=point(f.station_position(i,f.elapsed))
		if not bounds.has_point(p): continue
		draw_rect(Rect2(p-Vector2(6,6),Vector2(12,12)),tint,false,2)
		draw_string(map_font,Vector2(clampf(p.x+12,8,size.x-210),clampf(p.y-12,30,size.y-35)),f.IDS[i].to_upper()+(" NOW" if not approach and i==f.destination and not f.plan.is_empty() else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,28,tint)
		if approach and i==f.destination: draw_circle(p,1000*map_scale,Color("355d4a"),false,1)
	var here:=point(f.ship_position)
	draw_circle(here,7,Color("ffe7ab"))
	var heading: Vector3=-f.attitude.z
	draw_line(here,here+Vector2(heading.x,heading.z).normalized()*18,Color("ffe7ab"),3)
	draw_string(map_font,Vector2(12,size.y-8),"APPROACH / X-Z" if approach else "TRANSFER / X-Z",HORIZONTAL_ALIGNMENT_LEFT,-1,25,tint)
