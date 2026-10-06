extends RefCounted
## Compact wet room furnishings. The service module owns the shell and interactions.
const STEEL := Color("858b80")
const PORCELAIN := Color("c9c5ae")
const RUBBER := Color("414c48")
const TOWEL := Color("b89960")
const WATER := Color("8db1ad")
var s: Node3D

func build(service: Node3D) -> void:
	s = service
	_shower()
	_toilet()
	_basin()
	_wall_equipment()

func _shower() -> void:
	# Flush wet-deck insert: no collision lip for the walking controller to trip on.
	s.box(Vector3(-2.02,0.020,-3.39),Vector3(1.02,0.025,0.86),STEEL)
	s.box(Vector3(-2.02,0.035,-3.39),Vector3(0.91,0.010,0.76),RUBBER)
	for i in 7:
		s.box(Vector3(-2.02,0.042,-3.71+i*0.106),Vector3(0.85,0.006,0.025),s.EDGE)
	for x in [-2.52,-1.52]:
		s.box(Vector3(x,0.034,-3.39),Vector3(0.025,0.020,0.88),s.LIGHT)
	for z in [-3.81,-2.97]:
		s.box(Vector3(-2.02,0.034,z),Vector3(1.02,0.020,0.025),s.LIGHT)
	s.box(Vector3(-2.02,0.047,-3.74),Vector3(0.34,0.007,0.048),s.DARK)
	for i in 6:
		s.box(Vector3(-2.16+i*0.056,0.052,-3.74),Vector3(0.025,0.007,0.045),STEEL)
	# Washable liner panels wrap around the pipework and meet the floor insert.
	s.box(Vector3(-2.594,1.08,-3.40),Vector3(0.045,2.06,0.94),PORCELAIN)
	s.box(Vector3(-2.02,1.08,-3.875),Vector3(1.08,2.06,0.045),PORCELAIN)
	for y in [0.54,1.08,1.62,2.11]:
		s.box(Vector3(-2.566,y,-3.40),Vector3(0.015,0.017,0.92),s.EDGE)
		s.box(Vector3(-2.02,y,-3.846),Vector3(1.06,0.017,0.015),s.EDGE)
	# Port-wall controls and a rigid shower riser keep the entire standing area clear.
	var control: Node3D = s.group(Vector3(-2.555,1.18,-3.25),PI/2)
	s.box(Vector3.ZERO,Vector3(0.37,0.43,0.075),s.DARK,false,control)
	s.box(Vector3(0,0,0.047),Vector3(0.32,0.38,0.03),s.CREAM,false,control)
	s.box(Vector3(0,0.071,0.073),Vector3(0.23,0.095,0.025),s.DARK,false,control)
	s.label("38 C",Vector3(0,0.070,0.090),0.00087,s.GREEN,control)
	s.box(Vector3(-0.073,-0.099,0.095),Vector3(0.105,0.076,0.065),s.ORANGE,false,control)
	s.box(Vector3(0.074,-0.099,0.095),Vector3(0.077,0.076,0.065),STEEL,false,control)
	s.label("SHOWER",Vector3(0,0.278,0.018),0.00115,s.DARK,control)
	s.collider(Vector3(0,0,0.079),Vector3(0.38,0.43,0.19),control,"shower")
	s.box(Vector3(-2.49,1.76,-3.42),Vector3(0.044,0.53,0.045),STEEL)
	s.box(Vector3(-2.49,0.83,-3.42),Vector3(0.044,0.62,0.045),STEEL)
	for y in [0.57,1.59,1.95]:
		s.box(Vector3(-2.534,y,-3.42),Vector3(0.13,0.045,0.095),s.EDGE)
	s.box(Vector3(-2.355,2.025,-3.42),Vector3(0.32,0.065,0.065),STEEL)
	s.box(Vector3(-2.235,2.01,-3.42),Vector3(0.31,0.075,0.33),s.DARK)
	s.box(Vector3(-2.235,1.963,-3.42),Vector3(0.27,0.020,0.29),STEEL)
	for x in [-2.31,-2.16]:
		for z in [-3.50,-3.34]:
			s.box(Vector3(x,1.95,z),Vector3(0.040,0.010,0.040),s.DARK)
	s.shower_flow = s.group(Vector3(-2.235,0.997,-3.42))
	s.shower_flow.name = "ShowerWater"
	for x in [-0.075,0.075]:
		for z in [-0.08,0.08]:
			var stream: MeshInstance3D = s.box(Vector3(x,0,z),Vector3(0.009,1.894,0.009),WATER,false,s.shower_flow)
			stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.shower_flow.visible = false
	# Soap recess is shallow, above the tray perimeter instead of in the doorway.
	var soap: Node3D = s.group(Vector3(-1.68,1.28,-3.837))
	s.box(Vector3.ZERO,Vector3(0.37,0.36,0.055),s.DARK,false,soap)
	s.box(Vector3(0,-0.16,0.080),Vector3(0.37,0.035,0.17),s.EDGE,false,soap)
	for x in [-0.09,0.085]:
		s.box(Vector3(x,-0.036,0.070),Vector3(0.11,0.20,0.09),s.CREAM if x < 0 else s.ORANGE,false,soap)
		s.box(Vector3(x,0.080,0.070),Vector3(0.08,0.035,0.07),s.DARK,false,soap)
	s.label("RINSE / RECOVER",Vector3(0,0.244,0.035),0.00091,s.DARK,soap)
	# Grab rail and drying hook use the forward wall, away from the shower controls.
	s.box(Vector3(-1.41,0.94,-3.78),Vector3(0.038,0.61,0.045),s.ORANGE)
	for y in [0.655,1.225]:
		s.box(Vector3(-1.41,y,-3.83),Vector3(0.085,0.062,0.13),s.EDGE)

func _toilet() -> void:
	# Vacuum toilet faces forward; the cistern and service chase sit on the aft wall.
	s.box(Vector3(-2.24,0.20,-1.49),Vector3(0.48,0.40,0.55),s.EDGE,true)
	s.box(Vector3(-2.24,0.385,-1.56),Vector3(0.59,0.20,0.67),PORCELAIN,true)
	s.box(Vector3(-2.24,0.495,-1.56),Vector3(0.61,0.06,0.69),s.DARK)
	# Four pieces make an actual seat opening instead of a solid lid.
	for x in [-2.495,-1.985]:
		s.box(Vector3(x,0.535,-1.56),Vector3(0.105,0.055,0.64),PORCELAIN)
	for z in [-1.84,-1.28]:
		s.box(Vector3(-2.24,0.535,z),Vector3(0.48,0.055,0.10),PORCELAIN)
	s.box(Vector3(-2.24,0.815,-1.20),Vector3(0.62,0.78,0.20),s.CREAM,true)
	var cistern: Node3D = s.group(Vector3(-2.24,0.88,-1.312),PI)
	s.cabinet_face(Vector3.ZERO,Vector2(0.52,0.45),cistern)
	s.label("VAC / 01",Vector3(0,0.054,0.034),0.0010,s.DARK,cistern)
	s.box(Vector3(0,-0.045,0.070),Vector3(0.16,0.055,0.085),s.ORANGE,false,cistern)
	s.box(Vector3(0.20,0.19,0.040),Vector3(0.038,0.038,0.025),s.GREEN,false,cistern,true)
	# Wall-held roll and waste can leave the front standing space unobstructed.
	s.box(Vector3(-2.57,0.79,-1.82),Vector3(0.11,0.20,0.27),s.DARK)
	s.box(Vector3(-2.49,0.81,-1.82),Vector3(0.15,0.16,0.20),s.LIGHT)
	s.box(Vector3(-2.42,0.745,-1.81),Vector3(0.017,0.15,0.14),s.LIGHT)
	s.box(Vector3(-1.826,0.19,-1.37),Vector3(0.19,0.38,0.32),s.DARK,true)
	s.box(Vector3(-1.826,0.39,-1.37),Vector3(0.20,0.035,0.33),s.EDGE)
	var vacuum: Node3D = s.group(Vector3(-2.56,0.30,-1.48),PI/2)
	s.cabinet_face(Vector3.ZERO,Vector2(0.47,0.34),vacuum,s.EDGE)
	s.label("FILTER",Vector3(0,0.043,0.035),0.00095,s.LIGHT,vacuum)
	# Fitted vacuum-service cassette above the cistern; the room retains its full aisle.
	var vacuum_service: Node3D = s.group(Vector3(-2.24,1.62,-1.157),PI)
	s.box(Vector3.ZERO,Vector3(0.66,0.68,0.08),s.DARK,false,vacuum_service)
	s.cabinet_face(Vector3(0,0,0.052),Vector2(0.61,0.63),vacuum_service,s.CREAM)
	s.label("VACUUM / FILTER",Vector3(0,0.241,0.087),0.00089,s.DARK,vacuum_service)
	s.vent(Vector3(0,0.015,0.098),0.50,vacuum_service)
	s.box(Vector3(-0.22,-0.221,0.104),Vector3(0.045,0.045,0.025),s.GREEN,false,vacuum_service,true)
	s.label("SERVICE",Vector3(0,-0.148,0.087),0.00076,s.DARK,vacuum_service)
	s.box(Vector3(-2.47,1.243,-1.217),Vector3(0.035,0.093,0.037),s.EDGE)
	s.box(Vector3(-2.02,1.243,-1.217),Vector3(0.035,0.093,0.037),s.EDGE)

func _basin() -> void:
	s.box(Vector3(-1.27,0.44,-1.39),Vector3(0.74,0.88,0.56),s.DARK,true)
	var vanity: Node3D = s.group(Vector3(-1.27,0.46,-1.687),PI)
	s.cabinet_face(Vector3.ZERO,Vector2(0.68,0.76),vanity)
	s.label("WASH / SUPPLIES",Vector3(0,0.16,0.035),0.00094,s.DARK,vanity)
	s.vent(Vector3(0,-0.16,0.032),0.55,vanity)
	s.box(Vector3(-1.27,0.912,-1.40),Vector3(0.79,0.065,0.62),PORCELAIN,true)
	s.box(Vector3(-1.27,0.951,-1.43),Vector3(0.52,0.018,0.40),s.DARK)
	s.box(Vector3(-1.27,0.964,-1.43),Vector3(0.43,0.018,0.31),STEEL)
	s.box(Vector3(-1.27,0.975,-1.43),Vector3(0.065,0.010,0.065),s.DARK)
	s.box(Vector3(-1.27,1.08,-1.17),Vector3(0.050,0.28,0.055),s.EDGE)
	s.box(Vector3(-1.27,1.20,-1.295),Vector3(0.055,0.060,0.28),s.EDGE)
	s.box(Vector3(-1.27,1.165,-1.420),Vector3(0.069,0.044,0.069),s.DARK)
	var tap: Node3D = s.group(Vector3(-0.988,1.02,-1.31),PI)
	s.box(Vector3.ZERO,Vector3(0.125,0.060,0.15),s.DARK,false,tap)
	s.box(Vector3(0,0.046,0),Vector3(0.089,0.045,0.11),s.ORANGE,false,tap)
	s.collider(Vector3(0,0.02,0),Vector3(0.15,0.11,0.17),tap,"tap")
	s.tap_flow = s.group(Vector3(-1.27,1.063,-1.420))
	s.tap_flow.name = "BasinWater"
	var stream: MeshInstance3D = s.box(Vector3.ZERO,Vector3(0.019,0.174,0.019),WATER,false,s.tap_flow)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.tap_flow.visible = false
	# A recessed mirror and light above the sink retain head room in the aisle.
	var mirror: Node3D = s.group(Vector3(-1.27,1.59,-1.151),PI)
	s.box(Vector3.ZERO,Vector3(0.79,0.77,0.068),s.EDGE,false,mirror)
	s.box(Vector3(0,0,0.044),Vector3(0.68,0.64,0.025),Color("52635e"),false,mirror)
	s.box(Vector3(-0.25,0,0.059),Vector3(0.017,0.57,0.004),Color("738178"),false,mirror)
	s.box(Vector3(0,-0.381,0.068),Vector3(0.79,0.032,0.15),s.DARK,false,mirror)
	s.box(Vector3(0,0.431,0.075),Vector3(0.76,0.072,0.12),s.DARK,false,mirror)
	s.box(Vector3(0,0.420,0.143),Vector3(0.66,0.036,0.023),Color("ffe0ad"),false,mirror,true)
	s.host._lamp(Vector3(-1.27,1.92,-1.58),0.20,1.4,Color("ffe0ad"))
	# Cup and dispenser are retained at the back corners of the counter.
	s.box(Vector3(-1.55,1.063,-1.23),Vector3(0.095,0.19,0.09),s.LIGHT)
	s.box(Vector3(-1.55,1.164,-1.23),Vector3(0.052,0.019,0.060),s.DARK)
	s.box(Vector3(-1.59,1.192,-1.22),Vector3(0.015,0.13,0.015),s.ORANGE)

func _wall_equipment() -> void:
	# Full-width high medicine / linen lockers over the fixed aft fixtures.
	var lockers: Node3D = s.group(Vector3(-1.76,2.19,-1.225),PI)
	s.box(Vector3(0,0,-0.025),Vector3(1.65,0.30,0.23),s.DARK,true,lockers)
	for i in 3:
		var x: float = -0.54+i*0.54
		s.cabinet_face(Vector3(x,0,0.113),Vector2(0.51,0.265),lockers,s.CREAM)
		s.label(["LINEN","HYGIENE","FIRST AID"][i],Vector3(x,0.047,0.148),0.00080,s.DARK,lockers)
	# Port-side water treatment unit uses the wall between shower and toilet.
	var water: Node3D = s.group(Vector3(-2.570,1.59,-2.43),PI/2)
	s.box(Vector3.ZERO,Vector3(0.55,0.75,0.09),s.DARK,false,water)
	s.cabinet_face(Vector3(0,0,0.058),Vector2(0.50,0.70),water)
	s.label("WATER / LOOP",Vector3(0,0.244,0.092),0.00096,s.DARK,water)
	s.box(Vector3(0,0.097,0.10),Vector3(0.38,0.135,0.045),s.DARK,false,water)
	s.label("RECOVER 94%",Vector3(0,0.096,0.126),0.00077,s.GREEN,water)
	for x in [-0.145,0,0.145]:
		s.box(Vector3(x,-0.142,0.124),Vector3(0.080,0.22,0.096),STEEL,false,water)
		s.box(Vector3(x,-0.015,0.124),Vector3(0.095,0.035,0.102),s.ORANGE,false,water)
	s.box(Vector3(-2.553,0.73,-2.45),Vector3(0.056,0.77,0.065),s.EDGE)
	s.box(Vector3(-2.553,0.357,-2.72),Vector3(0.056,0.045,0.59),s.EDGE)
	var towel: Node3D = s.group(Vector3(-2.566,0.95,-2.08),PI/2)
	s.box(Vector3(0,0,0.089),Vector3(0.29,0.025,0.034),s.ORANGE,false,towel)
	for x in [-0.13,0.13]:
		s.box(Vector3(x,0,0.044),Vector3(0.035,0.07,0.11),s.EDGE,false,towel)
	s.box(Vector3(0,-0.19,0.11),Vector3(0.22,0.38,0.04),TOWEL,false,towel)
	s.box(Vector3(0,-0.326,0.135),Vector3(0.22,0.028,0.009),s.LIGHT,false,towel)
	# A shallow extractor at each end and connected high cable / duct runs.
	var front: Node3D = s.group(Vector3(-1.72,2.22,-3.854))
	s.vent(Vector3.ZERO,1.42,front)
	s.label("DRY / EXTRACT",Vector3(0,-0.198,0.035),0.00105,s.DARK,front)
	s.box(Vector3(-2.535,2.25,-2.45),Vector3(0.095,0.11,2.76),s.EDGE)
	for z in [-3.64,-2.57,-1.34]:
		s.box(Vector3(-2.52,2.25,z),Vector3(0.11,0.16,0.055),s.DARK)
	# Partition panels occupy only the solid door shoulders, never the opening.
	var forward_panel: Node3D = s.group(Vector3(-0.835,1.50,-3.48),-PI/2)
	s.cabinet_face(Vector3.ZERO,Vector2(0.60,0.91),forward_panel)
	s.label("HOT WATER",Vector3(0,0.28,0.035),0.00104,s.DARK,forward_panel)
	s.vent(Vector3(0,0.04,0.045),0.48,forward_panel)
	s.label("ISOLATE",Vector3(0,-0.25,0.038),0.00090,s.DARK,forward_panel)
	s.box(Vector3(0,-0.15,0.065),Vector3(0.19,0.043,0.050),s.ORANGE,false,forward_panel)
