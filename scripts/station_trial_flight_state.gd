extends "res://scripts/longhaul_flight_state.gd"
## Station-trial berth: physical +Z entrance, ship nose -Z, same orbital dock origin.
## The standalone flight model and its old open-apron berth remain unchanged.
const HANGAR_FORWARD := Vector3.FORWARD
const HANGAR_HOLD := Vector3(0,2,600)
const ENTRY := Vector3(0,2,70)
const FLOOR := -1.315
const SHIP_MIN := Vector3(-5.438,-1.315,-14.739)
const SHIP_MAX := Vector3(5.438,4.430,11.720)
var sensors_ready := true
var hangar_door_clear := false
var departure_door_requested := false
var clearance_notice_at := -100.0
var bypass_height := -35.0

func _init() -> void:
	super._init()
	hold_offset=HANGAR_HOLD

func restore(data:Dictionary) -> bool:
	if not super.restore(data): return false
	# Mechanical door position is reconstructed by the hangar runtime. Loading a
	# docked checkpoint must not retain a request from the abandoned departure.
	departure_door_requested=phase=="departure"
	hangar_door_clear=false
	hold_offset=HANGAR_HOLD
	clearance_notice_at=-100.0
	bypass_height=90.0 if (ship_position-station_position(reference_station_id(),elapsed)).y>15 else -35.0
	return true

func base_departure_ready() -> bool:
	return sensors_ready and super.can_depart()

func can_depart() -> bool:
	return base_departure_ready() and hangar_door_clear

func checklist() -> String:
	return super.checklist()+"\nSENSOR CONDITION: "+("OK" if sensors_ready else "PORT REPAIR REQUIRED")+"\n[%s] STATION PRESSURE DOOR / depart requests opening"%mark(hangar_door_clear)

func depart() -> String:
	if phase!="docked": return "Already in flight."
	if not can_depart(): return "Departure interlock. Review CHECKLIST readiness.\n"+checklist()
	phase="departure";autopilot=false;arrival_hold=false;warp=1;trail.clear()
	departure_door_requested=true
	alert("Berth released / pressure door clear. SPACE: lift 2 m. S: reverse straight out through BAY 01. Keep the nose facing the hangar. NAV available beyond 300 m.")
	return warning

func safe_departure() -> bool:
	var relative:=ship_position-station_position(dock_id,elapsed)
	return (relative.z>300 and absf(relative.x)<500 and absf(relative.y)<500) or relative.length()>1000

func request_approach() -> String:
	var result:=super.request_approach()
	if not approach_clearance: return result
	return "ATC / %s\nBAY 01 ASSIGNED / PRESSURE DOOR OPENING\nApproach the green lights on the +Z side. Nose heading 000 / pitch 000.\nauto dock below 1000 m / 15 m/s.\nManual: enter at 2 m lift, stop above the landing marks, lower onto the deck, then dock.\nCapture requires <3 m, <1 m/s and level nose-first alignment."%NAMES[destination]

func docking_target() -> Vector3:
	var station:=station_position(destination,elapsed)
	var relative:=ship_position-station
	if docking_stage=="":
		bypass_height=90.0 if relative.y>15 else -35.0
		if relative.z<40 and relative.z>-5 and absf(relative.x)<2 and relative.y>=-0.05 and relative.y<3.0:
			docking_stage="final"
		elif relative.z>=55:
			docking_stage="entry"
		else:
			docking_stage="clearance"
	# Take the nearest unobstructed vertical side of the station envelope before
	# moving around its end. Standard transfer arrivals already use the front.
	if docking_stage=="clearance":
		var bypass:=Vector3(relative.x,bypass_height,relative.z)
		if absf(relative.y-bypass_height)>2: return station+bypass
		docking_stage="overhead" # Legacy save enum; used here as the under-keel transit.
	if docking_stage=="overhead":
		var outside:=Vector3(0,bypass_height,90)
		if relative.distance_to(outside)>2 or relative_speed()>0.6: return station+outside
		docking_stage="entry"
	if docking_stage=="entry":
		if relative.distance_to(ENTRY)>0.7 or relative_speed()>0.35 or not hangar_door_clear:
			return station+ENTRY
		docking_stage="final"
	# Translate level through the real aperture before descending. Crossing the
	# door plane while trying to descend was the source of the old pad illusion.
	if absf(relative.z)>0.25 or absf(relative.x)>0.15:
		return station+Vector3(0,2,0)
	return station

func automatic_thrust(dt: float) -> Vector3:
	if not auto_docking: return super.automatic_thrust(dt)
	var target:=docking_target()
	var offset:=target-ship_position
	var direction:=HANGAR_FORWARD
	# Keep a level berth attitude throughout the corridor and descent. RCS can
	# translate all axes without pitching a 26 m ship into the door frame.
	if docking_stage in ["clearance","overhead"] and offset.length()>5:
		direction=offset.normalized()
	var turning:=(-attitude.z).dot(direction)<cos(deg_to_rad(5))
	attitude=attitude.slerp(Basis.looking_at(direction,Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.99 else Vector3.UP),minf(1,dt*0.9)).orthonormalized()
	angular_velocity=Vector3.ZERO
	var limit:=4.0 if docking_stage=="final" else 12.0
	if docking_stage=="final" and absf(offset.z)<0.5: limit=0.7
	var closing:=minf(limit,minf(offset.length()*0.20,sqrt(2*maxf(max_acceleration(),0.1)*0.4*offset.length())))
	if turning or (docking_stage=="final" and not hangar_door_clear): closing=0
	required_velocity=station_velocity(destination,elapsed)+offset.normalized()*closing
	var acceleration_needed:Vector3=(required_velocity-velocity)/1.1+gravity(station_position(destination,elapsed))-gravity(ship_position)
	return (attitude.inverse()*acceleration_needed/maxf(max_acceleration(),0.01)).limit_length(1)

func _step(dt: float, thrust: Vector3, rotation_input: Vector3, stop_rotation: bool) -> void:
	var station_id:=reference_station_id()
	var nearest_distance:=500.0*500.0
	for candidate in IDS.size():
		var distance:=ship_position.distance_squared_to(station_position(candidate,elapsed))
		if distance<nearest_distance:
			station_id=candidate;nearest_distance=distance
	var before:=ship_position-station_position(station_id,elapsed)
	var previous_basis:=attitude
	var was_clear:=hangar_obstruction(before,attitude).is_empty()
	super._step(dt,thrust,rotation_input,stop_rotation)
	if phase=="docked": return
	var after:=ship_position-station_position(station_id,elapsed)
	var obstruction:=""
	# Test the swept movement too, so a fast manual approach cannot jump from one
	# side of the door to the other between integration steps.
	var samples:=clampi(ceili(before.distance_to(after)/3.0),1,64)
	if before.length()<500 or after.length()<500:
		for index in range(1,samples+1):
			var weight:=float(index)/samples
			obstruction=hangar_obstruction(before.lerp(after,weight),previous_basis.slerp(attitude,weight))
			if not obstruction.is_empty(): break
	if was_clear and not obstruction.is_empty():
		ship_position=station_position(station_id,elapsed)+before
		velocity=station_velocity(station_id,elapsed)
		attitude=previous_basis;angular_velocity=Vector3.ZERO
		if elapsed-clearance_notice_at>3:
			clearance_notice_at=elapsed
			alert("BERTH CLEARANCE / "+obstruction+". Motion arrested; use fine thrust to correct. No damage.")
	if auto_docking and docking_stage=="final" and after.length()<0.30 and relative_speed()<0.2:
		dock()

func hangar_obstruction(relative: Vector3, orientation: Basis) -> String:
	# Conservative swept hull extents, independent from walking collision bodies.
	# This prevents manual flight passing through the pressure door or bay walls.
	var low:=Vector3(INF,INF,INF)
	var high:=Vector3(-INF,-INF,-INF)
	for x in [SHIP_MIN.x,SHIP_MAX.x]:
		for y in [SHIP_MIN.y,SHIP_MAX.y]:
			for z in [SHIP_MIN.z,SHIP_MAX.z]:
				var corner:Vector3=relative+orientation*Vector3(x,y,z)
				low=low.min(corner);high=high.max(corner)
	var outside:=_exterior_obstruction(AABB(low,high-low))
	if not outside.is_empty(): return outside
	if high.z< -19 or low.z>35 or high.x< -14 or low.x>14 or high.y<FLOOR-0.05 or low.y>FLOOR+10:
		return ""
	if low.z<33 and high.z> -19:
		if low.y<FLOOR-0.06: return "Raise ship above the deck"
		if high.y>FLOOR+9.8: return "Overhead clearance"
		if low.x< -13.8 or high.x>13.8: return "Side-wall clearance"
		if low.z< -18.8: return "Front bulkhead clearance"
	if low.z<35 and high.z>32.8:
		if not hangar_door_clear: return "Pressure door is not clear"
		if low.x< -8.85 or high.x>8.85: return "Center ship in BAY 01 doorway"
		if low.y<FLOOR-0.03 or high.y>FLOOR+8.85: return "Doorway vertical clearance"
	return ""

func _exterior_obstruction(hull:AABB) -> String:
	# Broad engineering volumes follow the approved asset. Fine greebles stay
	# visual, while the major pressure hulls, radiators and adjacent closed bay
	# cannot be flown through. All bounds are measured from BAY 01's dock origin.
	var volumes: Array[AABB]=[
		AABB(Vector3(38,-2.14,-21.9),Vector3(32,13.8,57.7)), # Closed BAY 02.
		AABB(Vector3(-26,28,-20),Vector3(48,21,20)), # Process drum 01.
		AABB(Vector3(26,28,-20),Vector3(48,21,20)), # Process drum 02.
		AABB(Vector3(-47,15.5,-19),Vector3(18,23,20)), # Operations decks.
		AABB(Vector3(-34,18.1,-21),Vector3(140,7.4,18)), # Keel and pressure corridor.
		AABB(Vector3(-2.5,10.2,-21),Vector3(5,11.5,4)), # Bay 01 service lift.
		AABB(Vector3(51.5,10.2,-21),Vector3(5,11.5,4)), # Bay 02 service lift.
		AABB(Vector3(122,15.5,-16),Vector3(16,12,12)), # Power plant.
		AABB(Vector3(123,-14.4,-11),Vector3(14,75,2)), # Radiator banks.
		AABB(Vector3(2,24.2,-62),Vector3(30,1,41)) # Solar panels and yoke.
	]
	for volume in volumes:
		if hull.intersects(volume): return "Station structure clearance"
	return ""

func dock() -> String:
	if phase=="docked": return "Already docked at %s / BAY 01."%NAMES[dock_id]
	if not approach_clearance: return "Type approach on NAV or COMMS to receive BAY 01."
	var relative:=ship_position-station_position(destination,elapsed)
	if relative.length()>3 or relative_speed()>1 or relative.y>1.5:
		return "BAY 01: reach the landing marks within 3 m, below 1 m/s and less than 1.5 m lift. Or use auto dock."
	if (-attitude.z).dot(HANGAR_FORWARD)<cos(deg_to_rad(5)) or attitude.y.dot(Vector3.UP)<cos(deg_to_rad(5)) or angular_velocity.length()>0.02:
		return "Align nose heading 000 / pitch 000, level roll, then [X] stop rotation."
	if not hangar_door_clear: return "Wait for the pressure door to finish opening."
	dock_id=destination;autopilot=false;auto_docking=false;docking_stage="";arrival_hold=false;sleeping=false
	phase="docked";ship_position=station_position(dock_id,elapsed);velocity=station_velocity(dock_id,elapsed)
	attitude=Basis.IDENTITY;angular_velocity=Vector3.ZERO;completed_trips+=1;loaded=false
	clearance="";clearance_confirmed=false;approach_clearance=false;warp=1;departure_door_requested=false
	alert("Docked at %s / BAY 01. Pressure door closing. Lower the loading ramp and open the cargo hatch when ready."%NAMES[dock_id])
	return warning

func rescue() -> String:
	departure_door_requested=false
	return super.rescue()

func guidance() -> Dictionary:
	var result:=super.guidance()
	if phase=="approach" and station_range()<100:
		var direction:=attitude.inverse()*HANGAR_FORWARD
		result.direction=HANGAR_FORWARD
		result.yaw=rad_to_deg(atan2(-direction.x,-direction.z))
		result.pitch=rad_to_deg(atan2(direction.y,Vector2(direction.x,direction.z).length()))
	return result
