extends RefCounted
## Authored orbital geography. Travel uses a compressed simulation space;
## catalogue radii remain orbital kilometres, and docking uses local metres.
const REVISION := 1
const REAL_KM_PER_UNIT := 4.0
const ORBIT_TIME_SCALE := 60.0
const PLANET := Vector3(0,0,500000)
const PLANET_NAME := "Aurel"
const PLANET_RADIUS := 14500.0
const RING_INNER := 19000.0
const RING_OUTER := 35000.0
const MU := 2137500000.0
const IDS := ["ceres","tharsis","kepler","helios","aurel","ember","ashworks","slate","forge","brume","morrow","rime","ochre","farwatch","beacon"]
const NAMES := ["Ceres Yard","Tharsis Ring","Kepler Works","Helios Anchorage","Aurel Fuel","Ember Exchange","Ashworks","Slate Depot","Forge Terminal","Brume Gardens","Morrow Haven","Rime Lab","Ochre Supply","Farwatch","Beacon Nine"]
const MOONS := [
	{"id":"ember","name":"Ember","radius_km":215000.0,"body_radius_km":1250.0,"phase":-20.0,"inclination":1.2,"mu":28125.0,"kind":"volcanic","color":Color("a45b35")},
	{"id":"slate","name":"Slate","radius_km":290000.0,"body_radius_km":1600.0,"phase":65.0,"inclination":-1.0,"mu":67500.0,"kind":"rock","color":Color("606966")},
	{"id":"brume","name":"Brume","radius_km":410000.0,"body_radius_km":2100.0,"phase":145.0,"inclination":2.0,"mu":112500.0,"kind":"cloud","color":Color("b9c5be")},
	{"id":"morrow","name":"Morrow","radius_km":560000.0,"body_radius_km":2600.0,"phase":-160.0,"inclination":-2.0,"mu":196875.0,"kind":"atmosphere","color":Color("779baa")},
	{"id":"rime","name":"Rime","radius_km":780000.0,"body_radius_km":1800.0,"phase":100.0,"inclination":1.5,"mu":61875.0,"kind":"ice","color":Color("d5ded3")},
	{"id":"ochre","name":"Ochre","radius_km":1050000.0,"body_radius_km":1350.0,"phase":35.0,"inclination":-1.5,"mu":33750.0,"kind":"rock","color":Color("bca56e")},
	{"id":"hush","name":"Hush","radius_km":1500000.0,"body_radius_km":900.0,"phase":-75.0,"inclination":3.0,"mu":11250.0,"kind":"dark_ice","color":Color("69757b")},
	{"id":"veil","name":"Veil","radius_km":2100000.0,"body_radius_km":1150.0,"phase":165.0,"inclination":-3.0,"mu":16875.0,"kind":"ice","color":Color("8aadb8")}
]
## The first four indexes retain the legacy station IDs for save migration.
const STATIONS := [
	{"id":"ceres","name":"Ceres Yard","number":1,"moon":-1,"radius_km":160000.0,"phase":-90.0,"inclination":0.0,"role":"freight","purpose":"Central freight exchange","style":"freight","color":Color("ac793e"),"exports":"Mixed supplies","imports":"Machine parts","remote":false},
	{"id":"tharsis","name":"Tharsis Ring","number":2,"moon":-1,"radius_km":173000.0,"phase":-70.0,"inclination":0.4,"role":"trade","purpose":"Established commercial port","style":"habitat","color":Color("779a94"),"exports":"Provisions","imports":"Consumer goods","remote":false},
	{"id":"kepler","name":"Kepler Works","number":3,"moon":-1,"radius_km":184000.0,"phase":-103.0,"inclination":-0.5,"role":"shipyard","purpose":"Shipbuilding and heavy repairs","style":"yard","color":Color("a66d3e"),"exports":"Machine parts","imports":"Refined metals","remote":false},
	{"id":"helios","name":"Helios Anchorage","number":13,"moon":-1,"radius_km":1250000.0,"phase":-25.0,"inclination":1.2,"role":"freight","purpose":"Outer freight interchange","style":"freight","color":Color("a18650"),"exports":"Survey equipment","imports":"Mixed supplies","remote":true},
	{"id":"aurel","name":"Aurel Fuel","number":4,"moon":-1,"radius_km":157000.0,"phase":-45.0,"inclination":-0.6,"role":"refinery","purpose":"Propellant processing depot","style":"refinery","color":Color("ad8755"),"exports":"Fuel catalysts","imports":"Filters and valves","remote":false},
	{"id":"ember","name":"Ember Exchange","number":5,"moon":0,"radius_km":8500.0,"phase":150.0,"inclination":8.0,"role":"cargo","purpose":"Ember regional freight terminal","style":"freight","color":Color("ab663e"),"exports":"Mineral samples","imports":"Provisions","remote":false},
	{"id":"ashworks","name":"Ashworks","number":6,"moon":0,"radius_km":13000.0,"phase":-30.0,"inclination":-6.0,"role":"industry","purpose":"Materials processing plant","style":"refinery","color":Color("9e523b"),"exports":"Refined metals","imports":"Machine parts","remote":false},
	{"id":"slate","name":"Slate Depot","number":7,"moon":1,"radius_km":9000.0,"phase":20.0,"inclination":5.0,"role":"mining","purpose":"Ore storage and dispatch","style":"mining","color":Color("7e8b79"),"exports":"Ore concentrates","imports":"Mining tools","remote":false},
	{"id":"forge","name":"Forge Terminal","number":8,"moon":1,"radius_km":14500.0,"phase":190.0,"inclination":-5.0,"role":"machinery","purpose":"Industrial fabrication terminal","style":"yard","color":Color("b47743"),"exports":"Mining tools","imports":"Ore concentrates","remote":false},
	{"id":"brume","name":"Brume Gardens","number":9,"moon":2,"radius_km":17000.0,"phase":-65.0,"inclination":4.0,"role":"food","purpose":"Orbital greenhouse cooperative","style":"agriculture","color":Color("91aa76"),"exports":"Fresh produce","imports":"Water filters","remote":false},
	{"id":"morrow","name":"Morrow Haven","number":10,"moon":3,"radius_km":18000.0,"phase":80.0,"inclination":-4.0,"role":"habitation","purpose":"Residential station and clinic","style":"habitat","color":Color("94aca9"),"exports":"Medical supplies","imports":"Fresh produce","remote":false},
	{"id":"rime","name":"Rime Lab","number":11,"moon":4,"radius_km":15000.0,"phase":140.0,"inclination":7.0,"role":"research","purpose":"Ice and atmospheric research","style":"research","color":Color("a5bec0"),"exports":"Research samples","imports":"Laboratory supplies","remote":true},
	{"id":"ochre","name":"Ochre Supply","number":12,"moon":5,"radius_km":14000.0,"phase":-110.0,"inclination":-7.0,"role":"logistics","purpose":"Remote resupply outpost","style":"freight","color":Color("b39d63"),"exports":"Spare components","imports":"Provisions","remote":true},
	{"id":"farwatch","name":"Farwatch","number":14,"moon":-1,"radius_km":1750000.0,"phase":-110.0,"inclination":2.0,"role":"observatory","purpose":"Deep-space observatory","style":"research","color":Color("889da9"),"exports":"Instrument packages","imports":"Spare components","remote":true},
	{"id":"beacon","name":"Beacon Nine","number":15,"moon":-1,"radius_km":1950000.0,"phase":70.0,"inclination":-2.0,"role":"relay","purpose":"Outer navigation and communications","style":"relay","color":Color("9e9073"),"exports":"Recorder cartridges","imports":"Electronic parts","remote":true}
]

static func orbital_offset(radius: float, phase: float, inclination: float, mu: float, when: float) -> Vector3:
	var axis:=Vector3.UP.rotated(Vector3.FORWARD,deg_to_rad(inclination))
	var initial:=Vector3(radius,0,0).rotated(Vector3.UP,deg_to_rad(phase)).rotated(Vector3.FORWARD,deg_to_rad(inclination))
	return initial.rotated(axis,sqrt(mu/pow(radius,3))*when)

static func orbital_velocity(offset: Vector3, inclination: float, mu: float) -> Vector3:
	var axis:=Vector3.UP.rotated(Vector3.FORWARD,deg_to_rad(inclination))
	return axis.cross(offset)*sqrt(mu/pow(offset.length(),3))

static func moon_position(index: int, when: float) -> Vector3:
	var m: Dictionary=MOONS[index]
	return PLANET+orbital_offset(m.radius_km/REAL_KM_PER_UNIT,m.phase,m.inclination,MU,when)

static func moon_velocity(index: int, when: float) -> Vector3:
	return orbital_velocity(moon_position(index,when)-PLANET,MOONS[index].inclination,MU)

static func moon_radius(index: int) -> float:
	return MOONS[index].body_radius_km/REAL_KM_PER_UNIT

static func station_position(index: int, when: float) -> Vector3:
	var s: Dictionary=STATIONS[index]
	var parent: Vector3=PLANET if s.moon<0 else moon_position(s.moon,when)
	var mu: float=MU if s.moon<0 else MOONS[s.moon].mu
	return parent+orbital_offset(s.radius_km/REAL_KM_PER_UNIT,s.phase,s.inclination,mu,when)

static func station_velocity(index: int, when: float) -> Vector3:
	var s: Dictionary=STATIONS[index]
	var parent: Vector3=PLANET if s.moon<0 else moon_position(s.moon,when)
	var mu: float=MU if s.moon<0 else MOONS[s.moon].mu
	return (Vector3.ZERO if s.moon<0 else moon_velocity(s.moon,when))+orbital_velocity(station_position(index,when)-parent,s.inclination,mu)

static func region(index: int) -> String:
	var s: Dictionary=STATIONS[index]
	return str(MOONS[s.moon].name) if s.moon>=0 else ("Outer system" if s.remote else "Aurel inner ports")

static func station_index(value: String) -> int:
	var id:=value.strip_edges().to_lower()
	if id.is_valid_int():
		for i in STATIONS.size():
			if STATIONS[i].number==int(id): return i
	return IDS.find(id)
