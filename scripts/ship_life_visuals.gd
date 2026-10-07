extends Node3D
## Physical ship-life fittings. The controller owns inventory and interactions;
## this module only marks reachable surfaces and reflects authoritative state.
const Art = preload("res://scripts/cargo_trial_visuals.gd")
const CREAM := Color("c3b89b")
const DARK := Color("252e28")
const ORANGE := Color("b96d38")
const GREEN := Color("a2e6b1")
const AMBER := Color("e2bf71")
const WATER := Color("80bbb7")
const SHOWER_CENTER := Vector3(-2.08, 0.05, -3.38)
const SHOWER_BOUNDS := AABB(Vector3(-2.56, -0.05, -3.84), Vector3(1.03, 2.0, 0.92))
var host: Node3D
var fittings: Node3D
var targets: Dictionary = {}
var table_plate: Node3D
var oven_plate: Node3D
var printer_paper: Node3D
var shower_water: Node3D
var oven_readout: Label3D
var hab_readout: Label3D
var sensor_readout: Label3D
var paper_label: Label3D
var port_readout: Label3D
var repairs_readout: Label3D
var oven_lamp: MeshInstance3D
var last_table_bites := -999
var dining_seat: Marker3D

func build(parent: Node3D, ship: Node3D) -> Dictionary:
	name = "ShipLifeVisuals"
	if not is_inside_tree(): parent.add_child(self)
	host = ship
	fittings = Node3D.new()
	fittings.name = "ShipLifeFittings"
	host.add_child(fittings)
	_galley()
	_hab()
	_service()
	_engineering()
	_port()
	return {"targets":targets, "table_plate":table_plate, "oven_plate":oven_plate,
		"printer_paper":printer_paper, "shower_center":SHOWER_CENTER,
		"shower_bounds":SHOWER_BOUNDS, "hab_readout":hab_readout,
		"sensor_readout":sensor_readout, "port_readout":port_readout}

func _target(action: String, pos: Vector3, size: Vector3, parent: Node3D = fittings) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Life_" + action
	body.position = pos
	body.collision_layer = 4
	body.collision_mask = 0
	body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	body.set_meta("life_action", action)
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.add_child(shape)
	parent.add_child(body)
	targets[action] = body
	return body

func _group(pos: Vector3, yaw := 0.0, parent: Node3D = fittings) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = pos
	node.rotation.y = yaw
	return node

func _label(parent: Node3D, words: String, pos: Vector3, px := 0.0011, tint := CREAM) -> Label3D:
	var node := Art.label(parent, words, pos, px)
	node.modulate = tint
	return node

func _plaque(pos: Vector3, yaw: float, words: String, width := 0.42) -> void:
	var face := _group(pos, yaw)
	Art.box(face, Vector3.ZERO, Vector3(width, 0.09, 0.019), DARK)
	_label(face, words, Vector3(0, 0, 0.013), minf(0.00087, width / maxf(words.length() * 30.0, 1.0)), CREAM)

func _galley() -> void:
	# The fitted cold cabinet is on the aisle side of the original utility bank.
	_target("fridge", Vector3(0.915, 0.89, -5.60), Vector3(0.085, 1.38, 0.73))
	_plaque(Vector3(0.879, 1.11, -5.60), -PI/2, "MEAL STORE", 0.50)
	# A compact oven sits on the existing induction worktop, leaving the sink clear.
	var oven := _group(Vector3(1.42, 1.25, -7.02), -PI/2)
	Art.box(oven, Vector3.ZERO, Vector3(0.64, 0.43, 0.63), CREAM)
	Art.box(oven, Vector3(0, 0, 0.324), Vector3(0.54, 0.32, 0.024), DARK)
	Art.box(oven, Vector3(0, -0.035, 0.341), Vector3(0.46, 0.20, 0.010), Color("192720"))
	Art.box(oven, Vector3(0, 0.08, 0.366), Vector3(0.36, 0.026, 0.052), ORANGE)
	oven_readout = _label(oven, "OVEN / READY", Vector3(0, 0.167, 0.346), 0.00074, GREEN)
	oven_lamp = Art.box(oven, Vector3(0.25, 0.12, 0.343), Vector3(0.026, 0.026, 0.018), GREEN)
	_target("oven", Vector3(1.055, 1.25, -7.02), Vector3(0.07, 0.45, 0.65))
	oven_plate = hand_prop("meal")
	oven.add_child(oven_plate)
	oven_plate.position = Vector3(0, -0.053, 0.345)
	oven_plate.scale = Vector3(0.90, 1.0, 0.24)
	oven_plate.visible = false
	_target("sink", Vector3(1.38, 1.065, -8.12), Vector3(0.63, 0.09, 0.57))
	_plaque(Vector3(0.952, 0.81, -8.12), -PI/2, "WASH / RETURN", 0.56)
	# Reuse the rightmost overhead locker for glasses, at standing eye reach.
	_target("cabinet", Vector3(1.365, 2.025, -6.63), Vector3(0.055, 0.51, 0.75))
	_plaque(Vector3(1.321, 2.065, -6.63), -PI/2, "DRINKING GLASSES", 0.65)
	# A dispenser covers the existing coffee unit footprint; no aisle intrusion.
	var cooler := _group(Vector3(1.53, 1.265, -6.48), -PI/2)
	Art.box(cooler, Vector3.ZERO, Vector3(0.33, 0.47, 0.37), CREAM)
	Art.box(cooler, Vector3(0, 0.078, 0.196), Vector3(0.27, 0.18, 0.025), DARK)
	_label(cooler, "POTABLE\nWATER", Vector3(0, 0.081, 0.214), 0.00074, GREEN)
	Art.box(cooler, Vector3(0, -0.072, 0.206), Vector3(0.038, 0.064, 0.071), ORANGE)
	Art.box(cooler, Vector3(0, -0.201, 0.243), Vector3(0.32, 0.035, 0.20), DARK)
	_target("water", Vector3(1.28, 1.26, -6.48), Vector3(0.10, 0.48, 0.36))

func _hab() -> void:
	# Seat reference is the middle of the actual Blender/legacy bench cushion.
	# The previous pose was at the aisle edge and ahead of the cushion.
	dining_seat = Marker3D.new()
	dining_seat.name = "DiningSeatCushion"
	fittings.add_child(dining_seat)
	dining_seat.position = Vector3(-1.24, 0.61, -4.49)
	# Keep the original table and its clear forward place setting. The keyboard
	# remains on the back half; meal props never float over its keys.
	Art.box(fittings, Vector3(-1.20, 0.849, -5.00), Vector3(0.42, 0.009, 0.29), Color("536253"))
	_target("table", Vector3(-1.20, 0.876, -5.00), Vector3(0.50, 0.10, 0.32))
	table_plate = Node3D.new()
	fittings.add_child(table_plate)
	table_plate.name = "DailyMealPlace"
	table_plate.position = Vector3(-1.20, 0.864, -5.00)
	_target("bunk", Vector3(-0.79, 0.79, -7.45), Vector3(0.20, 0.24, 1.78))
	_plaque(Vector3(-0.674, 0.69, -7.50), PI/2, "BUNK / REST", 0.45)
	# Overlay the static HAB screen with a live inventory/checklist terminal.
	var hab := _group(Vector3(-1.29, 1.25, -5.994))
	Art.box(hab, Vector3.ZERO, Vector3(0.585, 0.355, 0.027), Color("0b2117"))
	hab_readout = _label(hab, "HAB / SHIP LIFE\nPROVISIONS + DAILY LOG\n[F] OPEN TERMINAL", Vector3(0, 0, 0.020), 0.00080, GREEN)
	_target("hab", Vector3(-1.29, 1.25, -5.959), Vector3(0.62, 0.40, 0.046))
	# Compact printer below the wall CRT. The visible sheet only exists while
	# waiting in the tray; it disappears as soon as the controller collects it.
	var printer := _group(Vector3(-1.29, 0.965, -5.97))
	Art.box(printer, Vector3.ZERO, Vector3(0.48, 0.14, 0.17), CREAM)
	Art.box(printer, Vector3(0, 0.008, 0.091), Vector3(0.34, 0.030, 0.008), DARK)
	_label(printer, "DAILY LOG", Vector3(0, 0.055, 0.099), 0.00065, DARK)
	Art.box(printer, Vector3(0, -0.07, 0.118), Vector3(0.43, 0.016, 0.24), DARK)
	printer_paper = _group(Vector3(0, -0.035, 0.134), 0, printer)
	printer_paper.name = "ChecklistPrintout"
	Art.box(printer_paper, Vector3.ZERO, Vector3(0.27, 0.12, 0.008), Color("efe0b7"))
	paper_label = _label(printer_paper, "SHIPBOARD ROUTINE\nDAILY CHECKLIST", Vector3(0, 0, 0.006), 0.00035, DARK)
	printer_paper.visible = false
	_target("paper", Vector3(-1.29, 0.94, -5.766), Vector3(0.38, 0.16, 0.06))

func _service() -> void:
	_target("shower", Vector3(-2.403, 1.18, -3.25), Vector3(0.055, 0.43, 0.38))
	shower_water = host.service_module.shower_flow
	# Leave existing doors open. The tray is reachable through the service room.
	_plaque(Vector3(-2.38, 1.46, -3.25), PI/2, "RECYCLED / SHOWER", 0.51)

func _engineering() -> void:
	# The existing diagnostic screen is authoritative for sensor checks now.
	host.engineering_module.status_label.hide()
	for old_text in host.engineering_module.find_children("*", "Label3D", true, false):
		if "ISOLATE > ACCESS" in old_text.text or "FAULT TEST" in old_text.text or "RESET DEMO" in old_text.text:
			old_text.hide()
	var face := _group(Vector3(1.429, 1.62, 8.15), -PI/2)
	Art.box(face, Vector3.ZERO, Vector3(1.095, 0.69, 0.018), Color("092217"))
	sensor_readout = _label(face, "SHIP SENSOR DIAGNOSTICS\nDAILY SELF-TEST / CALIBRATION\n[F] OPEN TERMINAL", Vector3(0, 0, 0.014), 0.00105, GREEN)
	_target("sensors", Vector3(1.396, 1.62, 8.15), Vector3(0.045, 0.75, 1.15))
	_plaque(Vector3(1.407, 2.16, 8.15), -PI/2, "SENSORS / DAILY CARE", 1.15)

func _port() -> void:
	var provisions := Art._terminal(self, Vector3(-5.3, -1.2, 18.0), "", "PROVISIONS", "FOOD + WATER\n12 DAYS / CAPACITY\n[F] SHIP STORES")
	var repairs := Art._terminal(self, Vector3(-7.0, -1.2, 18.0), "", "REPAIR SERVICES", "SENSOR TECHNICIAN\nINSPECT / RESTORE\n[F] REPAIRS")
	for entry in [["provisions", provisions], ["repairs", repairs]]:
		var body: StaticBody3D = entry[1].get_node("InteractionBody")
		body.collision_layer = 5
		body.collision_mask = 0
		body.set_meta("life_action", entry[0])
		body.remove_meta("action")
		targets[entry[0]] = body
		entry[1].remove_meta("action")
	port_readout = provisions.get_node("StatusText")
	repairs_readout = repairs.get_node("StatusText")

func refresh(state: Dictionary) -> void:
	var bites := int(state.get("table_bites", -1))
	if bites != last_table_bites:
		for child in table_plate.get_children():
			table_plate.remove_child(child)
			child.queue_free()
		if bites >= 0: table_plate.add_child(hand_prop("dirty_plate" if bites == 0 else "meal", bites))
		table_plate.visible = bites >= 0
		last_table_bites = bites
	var oven_state := String(state.get("oven_state", ""))
	oven_plate.visible = oven_state in ["ready", "cooking"]
	oven_readout.text = "OVEN / READY"
	if oven_state == "cooking": oven_readout.text = "HEATING / %ds" % ceili(float(state.get("cook_remaining", 0)))
	elif oven_state == "ready": oven_readout.text = "MEAL / READY"
	oven_lamp.material_override = Art._material(AMBER if oven_state == "cooking" else GREEN, true)
	shower_water.visible = bool(state.get("shower_on", false))
	printer_paper.visible = bool(state.get("printed", false))
	var feed:=clampf(float(state.get("print_progress",1.0)),0.0,1.0)
	printer_paper.scale.y=maxf(0.02,feed)
	printer_paper.position.y=lerpf(0.025,-0.035,feed)
	targets.paper.collision_layer = 4 if printer_paper.visible and feed>=1.0 else 0
	if state.has("paper_text"):
		paper_label.text = "DAILY CHECKLIST\n" + String(state.paper_text).split("\n")[0]
	if state.has("food_stock") or state.has("food"):
		var food: int = int(state.get("food_stock", state.get("food", 0)))
		var water: int = int(state.get("water_stock", state.get("water", 0)))
		hab_readout.text = "HAB / SHIP LIFE\nFOOD %s / 12   WATER %s / 12\n[F] STORES + DAILY LOG" % [food, water]
		port_readout.text = "ONBOARD PROVISIONS\nFOOD %s/12  WATER %s/12\n[F] BUY SUPPLIES" % [food, water]
	if state.has("sensors"):
		var lines: Array[String] = ["ENGINEERING / DAILY SENSOR CARE", ""]
		var checked: Array = state.get("checked_sensors", [])
		var degraded: Array = state.get("degraded_sensors", [])
		for sensor in state.sensors:
			var condition: float = float(state.sensors[sensor])
			var flag := "FAIL" if condition <= 0 else ("DEGRADED" if sensor in degraded else ("PASS" if sensor in checked else "OK"))
			lines.append("%-14s %3d%% %s" % [String(sensor).to_upper(), roundi(condition), flag])
		lines.append("\n[F] STATUS / SELF-TEST")
		sensor_readout.text = "\n".join(lines)
	elif state.has("sensor_summary"):
		sensor_readout.text = String(state.sensor_summary)

func hand_prop(kind: String, bites := 5) -> Node3D:
	var prop := Node3D.new()
	prop.name = "LifeProp_" + kind
	match kind:
		"raw_food":
			Art.box(prop, Vector3.ZERO, Vector3(0.24, 0.065, 0.19), CREAM)
			Art.box(prop, Vector3(0, 0.037, 0), Vector3(0.21, 0.012, 0.17), ORANGE)
			var words := _label(prop, "DAILY MEAL", Vector3(0, 0.046, 0), 0.00045, CREAM)
			words.rotation.x = -PI/2
		"meal", "dirty_plate":
			Art.box(prop, Vector3.ZERO, Vector3(0.285, 0.022, 0.25), CREAM)
			Art.box(prop, Vector3(0, 0.014, 0), Vector3(0.23, 0.009, 0.197), Color("ded3b3"))
			for x in [-0.135, 0.135]: Art.box(prop, Vector3(x, 0.018, 0), Vector3(0.016, 0.022, 0.25), CREAM)
			for z in [-0.117, 0.117]: Art.box(prop, Vector3(0, 0.018, z), Vector3(0.27, 0.022, 0.016), CREAM)
			if kind == "meal":
				for i in clampi(bites, 0, 5):
					var pos := Vector3(-0.078 + (i % 3) * 0.077, 0.04, -0.056 + (i / 3) * 0.098)
					Art.box(prop, pos, Vector3(0.064, 0.031, 0.071), [Color("bb8649"), Color("7c9451"), Color("b69a69")][i % 3])
			else:
				for i in 3: Art.box(prop, Vector3(-0.053+i*0.045, 0.022, 0.025*(i%2)), Vector3(0.018, 0.005, 0.017), Color("8b754b"))
		"empty_glass", "water_glass", "used_glass":
			Art.box(prop, Vector3(0, -0.073, 0), Vector3(0.095, 0.014, 0.095), Color("a9cbc2"))
			for x in [-0.043, 0.043]: Art.box(prop, Vector3(x, 0, 0), Vector3(0.009, 0.15, 0.095), Color("bed3c7"))
			for z in [-0.043, 0.043]: Art.box(prop, Vector3(0, 0, z), Vector3(0.078, 0.15, 0.009), Color("99b7ae"))
			if kind == "water_glass": Art.box(prop, Vector3(0, 0.030, 0), Vector3(0.077, 0.008, 0.077), WATER)
		"paper":
			Art.box(prop, Vector3.ZERO, Vector3(0.21, 0.29, 0.006), Color("efe0b7"))
			_label(prop, "DAILY CHECKLIST\nAUREL STANDARD TIME\n\nFOOD / WATER\nHYGIENE\nSENSOR CHECKS", Vector3(0, 0.005, 0.004), 0.00036, DARK)
	return prop
