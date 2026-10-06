extends "res://scripts/longhaul_room.gd"
## Fitted engineering workshop. Repair states are local to this walkable study.
var isolated := false
var cover_open := false
var cover_moving := false
var fuse_pattern: Array[bool] = [false, true, false]
var bypass_ready := false
var repaired := false
var service_cover: Node3D
var cover_tween: Tween
var status_label: Label3D
var service_label: Label3D
var isolate_label: Label3D
var fuse_lenses: Array[MeshInstance3D] = []
var fuse_labels: Array[Label3D] = []
var pump_lamp: MeshInstance3D
var status_bars: Array[MeshInstance3D] = []
var pump_rotor: Node3D

func build(ship: Node3D) -> void:
	host = ship
	name = "LonghaulEngineering"
	_fitted_shell()
	_coolant_plant()
	_service_bay()
	_diagnostic_station()
	_power_and_workbench()
	_bulkhead_fittings()
	_ceiling()
	_refresh()

func _fitted_shell() -> void:
	for side in [-1,1]:
		box(Vector3(side*2.25,0.12,9.08),Vector3(1.48,0.24,3.80),DARK,true)
		box(Vector3(side*2.95,1.36,9.08),Vector3(0.08,2.60,3.81),EDGE,true)
		box(Vector3(side*2.93,2.54,9.08),Vector3(0.09,0.14,3.78),ORANGE)
		# A paired supply and return manifold connects every machine to the ceiling.
		for offset in [-0.15,0.15]:
			box(Vector3(side*2.69+offset,2.50,9.08),Vector3(0.105,0.105,3.78),ORANGE if offset<0 else EDGE)
			for z in [7.35,8.2,9.1,10.0,10.82]:box(Vector3(side*2.69+offset,2.50,z),Vector3(0.15,0.15,0.08),DARK)
		for z in [7.30,9.20,10.87]:
			box(Vector3(side*2.92,1.39,z),Vector3(0.13,2.62,0.09),DARK)
			box(Vector3(side*1.53,0.23,z),Vector3(0.13,0.24,0.13),ORANGE)
	# Flat deck plates and recessed inspection strips keep the freight route level.
	for x in [-1.34,1.34]:
		for z in [7.48,8.35,9.22,10.09,10.80]:box(Vector3(x,0.032,z),Vector3(0.065,0.008,0.45),AMBER)
	for z in [7.45,8.40,9.35,10.30]:
		box(Vector3(0,0.029,z),Vector3(1.88,0.009,0.74),Color("626459"))
		for x in [-0.86,0.86]:
			for dz in [-0.29,0.29]:box(Vector3(x,0.035,z+dz),Vector3(0.045,0.007,0.045),DARK)

func _coolant_plant() -> void:
	var plant := group(Vector3(-1.70,0,8.23),PI/2)
	box(Vector3(0,1.32,-0.62),Vector3(1.84,2.20,1.24),DARK,true,plant)
	for x in [-0.86,0.86]:box(Vector3(x,1.31,0.01),Vector3(0.09,2.20,0.10),CREAM,false,plant)
	box(Vector3(0,2.38,0.01),Vector3(1.84,0.18,0.11),CREAM,false,plant)
	label("P-01 / THERMAL LOOP",Vector3(0,2.38,0.078),0.00113,DARK,plant)
	# Mounted twin filter cans and motor are linked to the overhead coolant bus.
	for x in [-0.49,-0.13]:
		box(Vector3(x,1.74,0.035),Vector3(0.24,0.75,0.19),LIGHT,false,plant)
		for y in [1.37,1.50,1.98,2.11]:box(Vector3(x,y,0.058),Vector3(0.29,0.07,0.23),EDGE,false,plant)
		box(Vector3(x,2.18,0.025),Vector3(0.085,0.18,0.14),ORANGE,false,plant)
		label("FILTER",Vector3(x,1.72,0.138),0.00060,DARK,plant)
	box(Vector3(-0.31,2.25,-0.20),Vector3(0.62,0.09,0.55),ORANGE,false,plant)
	box(Vector3(-0.31,2.44,-0.45),Vector3(0.11,0.44,0.11),ORANGE,false,plant)
	box(Vector3(-0.27,1.08,0.01),Vector3(1.0,0.48,0.22),EDGE,false,plant)
	for x in [-0.64,-0.49,-0.34,-0.19,-0.04,0.11]:box(Vector3(x,1.08,0.14),Vector3(0.055,0.41,0.07),CREAM,false,plant)
	pump_rotor = Node3D.new()
	pump_rotor.position = Vector3(0.40,1.06,0.11)
	plant.add_child(pump_rotor)
	box(Vector3.ZERO,Vector3(0.40,0.40,0.085),ORANGE,false,pump_rotor)
	box(Vector3(0,0,0.051),Vector3(0.22,0.22,0.022),DARK,false,pump_rotor)
	for y in [-0.115,0.115]:box(Vector3(0,y,0.067),Vector3(0.32,0.031,0.018),EDGE,false,pump_rotor)
	box(Vector3(0.64,1.63,0.01),Vector3(0.10,1.05,0.11),ORANGE,false,plant)
	box(Vector3(0.41,2.14,-0.20),Vector3(0.56,0.105,0.55),ORANGE,false,plant)
	box(Vector3(0.41,2.37,-0.44),Vector3(0.105,0.48,0.11),ORANGE,false,plant)
	cabinet_face(Vector3(-0.24,0.57,0.015),Vector2(1.11,0.39),plant)
	label("FILTER / DRAIN",Vector3(-0.24,0.61,0.054),0.00095,DARK,plant)
	vent(Vector3(0,0.29,0.024),1.62,plant)
	# The isolation lever is separate from the machine service hatch.
	box(Vector3(-0.47,1.10,0.205),Vector3(0.40,0.43,0.055),DARK,false,plant)
	box(Vector3(-0.47,1.13,0.246),Vector3(0.24,0.12,0.035),ORANGE,false,plant)
	collider(Vector3(-0.47,1.10,0.255),Vector3(0.40,0.43,0.075),plant,"eng_isolate")
	isolate_label = label("ISOLATE",Vector3(-0.47,0.965,0.301),0.00080,LIGHT,plant)
	pump_lamp = box(Vector3(0.45,1.89,0.085),Vector3(0.24,0.13,0.07),AMBER,false,plant,true)
	label("PUMP",Vector3(0.45,1.71,0.118),0.00080,LIGHT,plant)

func _service_bay() -> void:
	var rack := group(Vector3(-1.69,0,10.11),PI/2)
	box(Vector3(0,1.35,-0.62),Vector3(1.54,2.30,1.24),DARK,true,rack)
	for x in [-0.73,0.73]:box(Vector3(x,1.35,0.02),Vector3(0.08,2.30,0.10),CREAM,false,rack)
	box(Vector3(0,2.48,0.03),Vector3(1.54,0.12,0.12),CREAM,false,rack)
	label("P-01 / FIELD SERVICE",Vector3(0,2.48,0.099),0.00100,DARK,rack)
	# Cover retracts straight up within the cabinet; no hinge swings into the aisle.
	for x in [-0.56,0.56]:box(Vector3(x,1.55,0.12),Vector3(0.055,1.73,0.08),EDGE,false,rack)
	box(Vector3(0,1.13,0.028),Vector3(1.03,0.77,0.08),Color("111d19"),false,rack)
	for i in 3:
		var x: float = -0.36+0.36*i
		box(Vector3(x,1.14,0.08),Vector3(0.25,0.54,0.06),EDGE,false,rack)
		box(Vector3(x,1.12,0.13),Vector3(0.15,0.31,0.07),DARK,false,rack)
		fuse_lenses.append(box(Vector3(x,1.13,0.175),Vector3(0.092,0.12,0.035),AMBER,false,rack,true))
		fuse_labels.append(label("A" if i==0 else ("B" if i==1 else "C"),Vector3(x,0.965,0.18),0.00080,LIGHT,rack))
		collider(Vector3(x,1.13,0.183),Vector3(0.245,0.50,0.07),rack,"eng_fuse_%d" % i)
		box(Vector3(x,1.50,0.08),Vector3(0.055,0.27,0.055),ORANGE,false,rack)
	box(Vector3(0,1.61,0.075),Vector3(0.83,0.055,0.06),ORANGE,false,rack)
	label("BYPASS   1 / 0 / 1",Vector3(0,0.72,0.103),0.00103,AMBER,rack)
	service_cover = Node3D.new()
	service_cover.position = Vector3(0,1.13,0.245)
	rack.add_child(service_cover)
	box(Vector3.ZERO,Vector3(1.04,0.81,0.065),CREAM,true,service_cover)
	for y in [-0.26,0.26]:box(Vector3(0,y,0.055),Vector3(0.60,0.045,0.05),DARK,false,service_cover)
	label("P-01\nBYPASS FUSES",Vector3(0,0,0.04),0.00115,DARK,service_cover)
	box(Vector3(0.645,1.70,0.195),Vector3(0.145,0.34,0.10),DARK,false,rack)
	box(Vector3(0.645,1.71,0.255),Vector3(0.10,0.20,0.042),ORANGE,false,rack)
	collider(Vector3(0.645,1.70,0.247),Vector3(0.155,0.35,0.060),rack,"eng_access")
	label("HATCH",Vector3(0.645,1.435,0.247),0.00050,LIGHT,rack)
	service_label = label("ISOLATE PUMP FIRST",Vector3(0,0.54,0.071),0.00094,AMBER,rack)
	vent(Vector3(0,0.30,0.035),1.29,rack)
	box(Vector3(0,2.18,0.028),Vector3(1.03,0.42,0.035),EDGE,false,rack)
	for i in 4:box(Vector3(0,2.045+i*0.09,0.054),Vector3(0.88,0.035,0.025),DARK,false,rack)

func _diagnostic_station() -> void:
	var station := group(Vector3(1.64,0,8.15),-PI/2)
	box(Vector3(0,1.32,-0.62),Vector3(1.67,2.20,1.24),DARK,true,station)
	for x in [-0.79,0.79]:box(Vector3(x,1.32,0.025),Vector3(0.08,2.23,0.10),CREAM,false,station)
	box(Vector3(0,2.40,0.018),Vector3(1.67,0.16,0.10),ORANGE,false,station)
	label("ENGINEERING / K-01",Vector3(0,2.40,0.077),0.00117,LIGHT,station)
	# Deep CRT housing, physical keys, printer and paper service instructions.
	box(Vector3(0,1.62,0.01),Vector3(1.39,0.97,0.19),CREAM,false,station)
	box(Vector3(0,1.62,0.121),Vector3(1.21,0.80,0.05),DARK,false,station)
	box(Vector3(0,1.62,0.154),Vector3(1.10,0.70,0.019),Color("0a271d"),false,station,true)
	status_label = label("",Vector3(0,1.62,0.169),0.00090,GREEN,station)
	status_label.line_spacing = 0
	collider(Vector3(0,1.62,0.166),Vector3(1.23,0.83,0.07),station,"eng_diag")
	box(Vector3(0,1.075,0.01),Vector3(1.41,0.09,0.31),EDGE,true,station)
	for row in 2:
		for col in 10:box(Vector3(-0.58+col*0.128,1.13,0.005+row*0.095),Vector3(0.104,0.035,0.071),ORANGE if col>7 else LIGHT,false,station)
	for i in 3:
		box(Vector3(-0.48+i*0.48,2.20,0.04),Vector3(0.32,0.095,0.045),DARK,false,station)
		status_bars.append(box(Vector3(-0.48+i*0.48,2.20,0.075),Vector3(0.24,0.042,0.025),GREEN,false,station,true))
	cabinet_face(Vector3(-0.32,0.63,0.016),Vector2(0.78,0.58),station)
	label("LOG / PRINTER",Vector3(-0.32,0.78,0.051),0.00075,DARK,station)
	box(Vector3(-0.32,0.635,0.07),Vector3(0.58,0.06,0.05),DARK,false,station)
	box(Vector3(-0.32,0.49,0.11),Vector3(0.44,0.24,0.014),LIGHT,false,station)
	label("P-01 / SERVICE\nISOLATE > ACCESS\nSET FUSES 1 / 0 / 1\nCLOSE > RESTORE",Vector3(-0.32,0.495,0.124),0.00045,DARK,station)
	box(Vector3(0.48,0.66,0.06),Vector3(0.43,0.48,0.09),CREAM,false,station)
	box(Vector3(0.48,0.665,0.125),Vector3(0.19,0.13,0.047),ORANGE,false,station)
	label("FAULT TEST",Vector3(0.48,0.80,0.111),0.00062,DARK,station)
	label("RESET DEMO",Vector3(0.48,0.50,0.111),0.00054,DARK,station)
	collider(Vector3(0.48,0.66,0.14),Vector3(0.37,0.40,0.09),station,"eng_reset")
	vent(Vector3(0,0.27,0.03),1.42,station)

func _power_and_workbench() -> void:
	var work := group(Vector3(1.65,0,9.805),-PI/2)
	box(Vector3(0,0.52,-0.63),Vector3(1.66,0.70,1.26),DARK,true,work)
	box(Vector3(0,0.91,-0.04),Vector3(1.66,0.10,0.37),LIGHT,true,work)
	for x in [-0.42,0.42]:
		cabinet_face(Vector3(x,0.56,0.013),Vector2(0.77,0.48),work)
		label("SPARES" if x<0 else "HAND TOOLS",Vector3(x,0.59,0.048),0.00077,DARK,work)
	vent(Vector3(0,0.25,0.029),1.43,work)
	# Batteries sit deep in a vented rack, with bus bars protected above reach.
	box(Vector3(0,1.88,-0.63),Vector3(1.67,1.23,1.26),DARK,true,work)
	box(Vector3(0,2.48,0.012),Vector3(1.67,0.13,0.10),CREAM,false,work)
	label("28V / AUX POWER",Vector3(0,2.48,0.073),0.00112,DARK,work)
	for col in 3:
		var x: float = -0.54+col*0.54
		for row in 2:
			var y: float = 1.61+row*0.46
			cabinet_face(Vector3(x,y,0.012),Vector2(0.49,0.40),work,LIGHT)
			box(Vector3(x-0.14,y+0.09,0.047),Vector3(0.055,0.05,0.017),GREEN,false,work,true)
			label("B%02d" % (1+col+row*3),Vector3(x+0.04,y+0.06,0.047),0.00070,DARK,work)
		box(Vector3(x,2.34,0.036),Vector3(0.23,0.065,0.07),ORANGE,false,work)
	box(Vector3(0,2.34,-0.07),Vector3(1.28,0.065,0.23),ORANGE,false,work)
	# Work lights illuminate a vise, tool rail and short clear maintenance surface.
	box(Vector3(0,1.34,0.00),Vector3(1.49,0.048,0.23),DARK,false,work)
	box(Vector3(0,1.307,0.035),Vector3(1.35,0.015,0.14),Color("ffe0a3"),false,work,true)
	box(Vector3(0,1.115,-0.025),Vector3(1.41,0.045,0.055),EDGE,false,work)
	for i in 5:
		var x: float = -0.50+i*0.25
		box(Vector3(x,1.095,0.024),Vector3(0.04,0.15,0.035),DARK,false,work)
		box(Vector3(x,1.055,0.045),Vector3(0.07,0.11,0.065),ORANGE if i%2==0 else EDGE,false,work)
	box(Vector3(-0.57,1.02,0.02),Vector3(0.29,0.15,0.22),EDGE,false,work)
	for x in [-0.67,-0.47]:box(Vector3(x,1.12,0.02),Vector3(0.075,0.105,0.20),DARK,false,work)
	box(Vector3(0.43,0.987,-0.008),Vector3(0.49,0.07,0.24),ORANGE,false,work)
	for x in [0.29,0.43,0.57]:box(Vector3(x,1.025,0.003),Vector3(0.08,0.016,0.18),CREAM,false,work)
	host._lamp(Vector3(1.35,1.30,9.82),0.24,1.7,Color("ffd5a0"))

func _bulkhead_fittings() -> void:
	for z in [7.13,10.965]:
		for side in [-1,1]:
			if z > 10 and side > 0: continue # Reserved for the loading hatch control.
			var end := group(Vector3(side*2.21,0,z),0 if z<8 else PI)
			cabinet_face(Vector3(0,1.58,0.009),Vector2(1.20,1.08),end)
			label("DRIVE / PORT" if side<0 else "DRIVE / STBD",Vector3(0,1.86,0.044),0.00094,DARK,end)
			for i in 3:
				box(Vector3(-0.37+i*0.37,1.61,0.05),Vector3(0.24,0.14,0.04),DARK,false,end)
				box(Vector3(-0.37+i*0.37,1.61,0.074),Vector3(0.08,0.055,0.017),GREEN,false,end,true)
			vent(Vector3(0,2.27,0.03),1.22,end)
			vent(Vector3(0,0.37,0.03),1.23,end)
			box(Vector3(0,0.79,0.027),Vector3(1.18,0.17,0.08),ORANGE,false,end)
			label("COOLANT / RETURN",Vector3(0,0.79,0.073),0.00078,LIGHT,end)

func _ceiling() -> void:
	for x in [-1.92,1.92]:
		box(Vector3(x,2.64,9.08),Vector3(0.67,0.15,3.79),DARK,true)
		for i in 13:box(Vector3(x,2.55,7.35+i*0.28),Vector3(0.56,0.07,0.055),EDGE)
		box(Vector3(x,2.525,9.08),Vector3(0.095,0.035,3.69),ORANGE)
	for z in [7.27,9.16,10.88]:
		box(Vector3(0,2.72,z),Vector3(5.88,0.11,0.13),EDGE)
		for x in [-1.42,1.42]:box(Vector3(x,2.66,z),Vector3(0.09,0.12,0.34),ORANGE)
	for z in [8.0,10.12]:
		box(Vector3(0,2.69,z),Vector3(1.45,0.16,0.58),DARK)
		box(Vector3(0,2.59,z),Vector3(1.26,0.045,0.40),Color("e9e0be"),false,self,true)
		host._lamp(Vector3(0,2.36,z),0.82,3.7,Color("eadcba"),true)

func prompt(action: String) -> String:
	match action:
		"eng_diag": return "READ ENGINEERING DIAGNOSTICS"
		"eng_isolate": return "RESTORE COOLANT CIRCUIT" if isolated else "ISOLATE COOLANT CIRCUIT"
		"eng_access": return "CLOSE SERVICE COVER" if cover_open else "OPEN SERVICE COVER"
		"eng_reset": return "FAULT TEST / RESET REPAIR DEMO"
	if action.begins_with("eng_fuse_"):
		var index := int(action.get_slice("_",2))
		return "FUSE %s: %d > %d  /  TARGET 1-0-1" % [["A","B","C"][index],int(fuse_pattern[index]),int(not fuse_pattern[index])]
	return ""

func use(action: String) -> void:
	match action:
		"eng_diag":
			explain("P-01: temporary bypass running. Station overhaul recommended." if repaired else ("Isolate P-01, open its cover, set fuses to 1-0-1, close and restore."))
		"eng_isolate":
			if isolated:
				if cover_open or cover_moving:
					explain("Close the service cover before restoring the circuit.")
					return
				if not bypass_ready:
					explain("Bypass incomplete: open the service cover and match 1-0-1.")
					return
				isolated = false
				repaired = true
				explain("Coolant restored. Temporary bypass online; arrange a station overhaul.")
			else:
				isolated = true
				explain("Coolant isolated. The service cover can now be opened.")
		"eng_access":
			if not isolated:
				explain("Isolate P-01 at the orange lever beside the pump first.")
				return
			if cover_moving: return
			cover_open = not cover_open
			cover_moving = true
			cover_tween = create_tween()
			cover_tween.tween_property(service_cover,"position:y",1.975 if cover_open else 1.13,0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			cover_tween.tween_callback(func() -> void: cover_moving = false)
			explain("Set fuses A / B / C to 1 / 0 / 1." if cover_open else "Cover secured. Restore the coolant circuit.")
		"eng_reset":
			if isolated or cover_open or cover_moving:
				explain("Finish the repair and restore the circuit before another fault test.")
				return
			fuse_pattern.assign([false,true,false])
			bypass_ready = false
			repaired = false
			explain("Fault test: coolant pump degraded. The repair demonstration is reset.")
		_:
			if not action.begins_with("eng_fuse_"): return
			if not isolated or not cover_open or cover_moving:
				explain("Isolate the circuit and fully open its service cover first.")
				return
			var index := int(action.get_slice("_",2))
			if index < 0 or index > 2: return
			fuse_pattern[index] = not fuse_pattern[index]
			bypass_ready = fuse_pattern == [true,false,true]
			explain("Bypass matched. Close the cover and restore the circuit." if bypass_ready else "Match the marked fuse pattern: A=1, B=0, C=1.")
	_refresh()

func _refresh() -> void:
	var color: Color = GREEN if repaired and not isolated else AMBER
	var mode := "BYPASS / RUNNING" if repaired else "DEGRADED / SERVICE"
	if isolated: mode = "ISOLATED / SAFE"
	status_label.text = "LONGHAUL / ENGINEERING\n------------------------\nP-01  " + mode + "\nFLOW  " + ("00%" if isolated else ("82%" if repaired else "46%")) + "    DRIVE 100%\nAUX   28.0V  BAT   94%\n------------------------\n" + ("STATION OVERHAUL ADVISED" if repaired else ("MATCH BYPASS:  1 / 0 / 1" if isolated else "ISOLATE > ACCESS > REPAIR"))
	status_label.modulate = color
	isolate_label.text = "RESTORE" if isolated else "ISOLATE"
	pump_lamp.material_override = host._material(color,true)
	status_bars[0].material_override = host._material(color,true)
	service_label.text = "CLOSE COVER > RESTORE" if bypass_ready and isolated else ("MATCH FUSES: 1 / 0 / 1" if isolated else ("TEMPORARY BYPASS ONLINE" if repaired else "ISOLATE PUMP FIRST"))
	service_label.modulate = color
	for i in 3:
		fuse_lenses[i].material_override = host._material(GREEN if fuse_pattern[i] else Color("505748"),fuse_pattern[i])
		fuse_labels[i].text = "%s / %d" % [["A","B","C"][i],int(fuse_pattern[i])]
