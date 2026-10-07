extends RefCounted
## Authoritative, renderer-independent shipboard calendar and survival state.
## World hours enter through advance(); interaction durations are real seconds.
## The scene owns money, dock access, journey interrupts, visuals and persistence.
const CAPACITY := 12
const HYGIENE_REQUIRED := 40.0
const HYGIENE_LOSS_PER_DAY := 6.0
const SENSOR_WEAR_PER_DAY := 1.0
const COOK_SECONDS := 4.0
const REAL_SECONDS_PER_DAY := 3600.0
const WORLD_HOURS_PER_SECOND := 24.0 / REAL_SECONDS_PER_DAY
const SENSOR_NAMES: Array[String] = ["navigation", "proximity", "coolant", "pressure", "drive", "communications"]
const HAND_ITEMS: Array[String] = ["", "raw_food", "meal", "dirty_plate", "empty_glass", "water_glass", "used_glass"]

var elapsed_hours := 6.0
var capacity := CAPACITY
var food_stock := 0
var water_stock := 0
var hygiene := 55.0
var hand_item := ""
var hand_bites := 0
var oven_state := ""
var cook_remaining := 0.0
var table_bites := -1 # -1 empty; 0 dirty plate; 1..5 uneaten bites.
var daily_food := 0.0
var daily_water := false
var sensors: Dictionary = {}
var selected_sensors: Array[String] = []
var checked_sensors: Array[String] = []
var degraded_sensors: Array[String] = []
var calibration: Dictionary = {}
var emergency_uses := 0
var game_over := false
var printed_day := 0
var last_error := ""
var _bought_food := false
var _bought_water := false

func _init() -> void:
	for sensor in SENSOR_NAMES: sensors[sensor] = 100.0
	_select_sensors()

func day() -> int:
	return int(floor(elapsed_hours / 24.0)) + 1

func hour() -> float:
	return fposmod(elapsed_hours, 24.0)

func time_text() -> String:
	var minutes := int(floor(hour() * 60.0 + 0.00001))
	# Round only the display down. The shared simulation retains precise time.
	minutes -= minutes % 5
	return "DAY %02d / %02d:%02d AST" % [day(), minutes / 60, minutes % 60]

func advance(hours: float) -> void:
	if game_over or not is_finite(hours) or hours <= 0.0: return
	var target := elapsed_hours + hours
	# Process each boundary exactly once, even for a multi-day skip. Inspection
	# credits belong to the day that ends, never the newly generated checklist.
	while (floorf(elapsed_hours / 24.0) + 1.0) * 24.0 <= target:
		var boundary := (floorf(elapsed_hours / 24.0) + 1.0) * 24.0
		hygiene = maxf(0.0, hygiene - (boundary - elapsed_hours) * HYGIENE_LOSS_PER_DAY / 24.0)
		_apply_daily_wear()
		elapsed_hours = boundary
		daily_food = 0.0
		daily_water = false
		checked_sensors.clear()
		calibration.clear()
		_select_sensors()
	hygiene = maxf(0.0, hygiene - (target - elapsed_hours) * HYGIENE_LOSS_PER_DAY / 24.0)
	elapsed_hours = target

func _select_sensors() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 70001 + day() * 7919
	var options: Array[String] = SENSOR_NAMES.duplicate()
	selected_sensors.clear()
	for index in 2:
		var selected := rng.randi_range(0, options.size() - 1)
		selected_sensors.append(options[selected])
		options.remove_at(selected)

func _apply_daily_wear() -> void:
	for sensor in SENSOR_NAMES:
		var multiplier := 1.0
		if sensor in selected_sensors:
			multiplier = 0.5 if sensor in checked_sensors else 1.5
		if sensor in degraded_sensors: multiplier = 1.5
		sensors[sensor] = maxf(0.0, float(sensors[sensor]) - SENSOR_WEAR_PER_DAY * multiplier)

func tick_interactions(seconds: float, showering: bool = false) -> void:
	if game_over or not is_finite(seconds) or seconds <= 0.0: return
	if oven_state == "cooking":
		cook_remaining = maxf(0.0, cook_remaining - seconds)
		if cook_remaining == 0.0: oven_state = "ready"
	if showering: hygiene = minf(100.0, hygiene + seconds * 5.0)

func purchase_error(kind: String, units: int) -> String:
	if game_over: return "This run has ended. Reload your departure checkpoint."
	if kind not in ["food", "water"]: return "Choose food or water."
	if units < 0: return "Purchase quantities cannot be negative."
	var stock: int = food_stock if kind == "food" else water_stock
	if stock + units > capacity: return "Only %d %s days fit in storage." % [capacity - stock, kind]
	return ""

func purchase(kind: String, units: int) -> String:
	last_error = purchase_error(kind, units)
	if not last_error.is_empty(): return last_error
	if units == 0: return "No purchase made."
	if kind == "food":
		food_stock += units
		_bought_food = true
	else:
		water_stock += units
		_bought_water = true
	var reset := _bought_food and _bought_water
	if reset:
		emergency_uses = 0
		# A fresh pair of actual purchases is required for a later reset.
		_bought_food = false
		_bought_water = false
	return "Purchased %d %s day(s).%s" % [units, kind, " Emergency rest allowance restored to 3." if reset else ""]

func begin_station_visit() -> void:
	_bought_food = false
	_bought_water = false

func interact(action: String) -> String:
	if game_over: return "This run has ended. Reload your departure checkpoint."
	match action:
		"fridge":
			if not hand_item.is_empty(): return "Put down or clean the item in your hand first."
			if food_stock <= 0: return "The fridge is empty. Buy food at the port terminal."
			if daily_food >= 0.999: return "You have eaten today's food allowance."
			food_stock -= 1
			hand_item = "raw_food"
			return "Meal pack collected. Take it to the oven."
		"oven":
			if hand_item == "raw_food" and oven_state.is_empty():
				hand_item = ""
				oven_state = "cooking"
				cook_remaining = COOK_SECONDS
				return "Cooking. Your meal will be ready in 4 seconds."
			if oven_state == "ready" and hand_item.is_empty():
				oven_state = ""
				hand_item = "meal"
				hand_bites = 5
				return "Meal ready. Set the plate on the table."
			if oven_state == "cooking": return "Cooking: %.1f seconds remaining." % cook_remaining
			if oven_state == "ready": return "Empty your hand before taking the meal."
			return "Bring a meal pack from the fridge."
		"table":
			if hand_item in ["meal", "dirty_plate"]:
				if table_bites >= 0: return "There is already a plate here. Clear it before setting another meal."
				table_bites = hand_bites if hand_item == "meal" else 0
				hand_item = ""
				hand_bites = 0
				return "Plate set on the table. Use the table to eat."
			if not hand_item.is_empty(): return "Your hand must be empty to eat."
			if table_bites > 0:
				table_bites -= 1
				daily_food = minf(1.0, daily_food + 0.2)
				return "Meal finished. Pick up the plate and take it to the sink." if table_bites == 0 else "Eating: %d of 5 bites remain." % table_bites
			if table_bites == 0:
				table_bites = -1
				hand_item = "dirty_plate"
				return "Dirty plate collected. Wash it at the sink."
			return "Set a cooked meal on the table."
		"take_plate":
			if not hand_item.is_empty(): return "Empty your hand before picking up the plate."
			if table_bites < 0: return "There is no plate on the table."
			hand_bites = maxi(0, table_bites)
			hand_item = "meal" if table_bites > 0 else "dirty_plate"
			table_bites = -1
			return "Plate collected. Remaining food is preserved."
		"cabinet":
			if not hand_item.is_empty(): return "Empty your hand before taking a glass."
			hand_item = "empty_glass"
			return "Glass collected. Fill it at the water cooler."
		"cooler":
			if hand_item == "water_glass": return "The glass is already full. Drink it before filling another."
			if hand_item == "used_glass": return "Clean the used glass in the sink."
			if hand_item != "empty_glass": return "Bring an empty glass from the cabinet."
			if water_stock <= 0: return "The drinking-water tank is empty. Buy water at port."
			water_stock -= 1
			hand_item = "water_glass"
			return "Glass filled. Drink it, then take it to the sink."
		"drink":
			if hand_item != "water_glass": return "Fill a glass at the water cooler first."
			daily_water = true
			hand_item = "used_glass"
			return "Daily drinking water complete. Wash the glass in the sink."
		"sink":
			if hand_item in ["dirty_plate", "used_glass", "empty_glass"]:
				hand_item = ""
				hand_bites = 0
				return "Washed and put away."
			if hand_item in ["meal", "raw_food", "water_glass"]: return "Finish your food or water before washing up."
			return "Bring your used plate or glass to the sink."
	return "Unknown shipboard action."

func check_sensor(sensor: String) -> String:
	sensor = sensor.to_lower().strip_edges()
	if not sensors.has(sensor): return "Unknown sensor. Use status to list sensors."
	if game_over: return "This run has ended."
	if float(sensors[sensor]) <= 0.0: return "Sensor failed. A port technician must repair it."
	if sensor in checked_sensors: return "%s already checked today." % sensor.capitalize()
	# Any sensor can be calibrated. Availability must never reveal today's assignment.
	if not calibration.is_empty():
		if calibration.sensor == sensor: return calibration_text()
		return "Finish or cancel the active calibration first.\n\n" + calibration_text()
	var rng := RandomNumberGenerator.new()
	rng.seed = day() * 7919 + SENSOR_NAMES.find(sensor) * 131 + 83
	var target: Array[int] = []
	var readings: Array[int] = []
	for channel in 3:
		var reference := rng.randi_range(3, 6)
		var offset := rng.randi_range(1, 3) * (-1 if rng.randi_range(0, 1) == 0 else 1)
		target.append(reference)
		readings.append(reference + offset)
	calibration = {"sensor":sensor, "day":day(), "target":target, "readings":readings}
	return calibration_text()

func calibration_text() -> String:
	if calibration.is_empty(): return "No active calibration. Use check <sensor>."
	var lines: Array[String] = ["CALIBRATION / " + str(calibration.sensor).to_upper(), "", "Adjust each reading to match its reference.", "CHANNEL    READING    REFERENCE", ""]
	for i in 3:
		lines.append("   %s          %d           %d" % [["A", "B", "C"][i], calibration.readings[i], calibration.target[i]])
	lines.append("\ntrim <a|b|c> <signed amount>  (example: trim a -2)\ntest : submit all three readings\ncancel : leave without submitting\n\nNo timer. Failed tests mark DEGRADED; recalibration is allowed.")
	return "\n".join(lines)

func trim_sensor(channel: String, amount: int) -> String:
	if calibration.is_empty(): return "Start a calibration with check <sensor>."
	var index := ["a", "b", "c"].find(channel.to_lower())
	if index < 0 or absi(amount) > 9: return "Use trim <a|b|c> <amount from -9 to 9>."
	var value := int(calibration.readings[index]) + amount
	if value < 0 or value > 9: return "Reading must stay between 0 and 9.\n\n" + calibration_text()
	calibration.readings[index] = value
	return calibration_text()

func submit_sensor() -> String:
	if calibration.is_empty(): return "Start a calibration with check <sensor>."
	var sensor: String = calibration.sensor
	if game_over or float(sensors[sensor]) <= 0.0:
		calibration.clear()
		return "Sensor unavailable. Arrange port service."
	var passed: bool = calibration.readings == calibration.target
	calibration.clear()
	if passed:
		if sensor not in checked_sensors: checked_sensors.append(sensor)
		degraded_sensors.erase(sensor)
		return "PASS / %s calibration verified. Inspection recorded.\nLost condition still needs a port technician." % sensor.to_upper()
	checked_sensors.erase(sensor)
	if sensor not in degraded_sensors: degraded_sensors.append(sensor)
	return "DEGRADED / %s calibration failed. Inspection incomplete.\nDaily wear is 1.5x until recalibrated or repaired.\nUse check %s to try again; no condition is restored by calibration." % [sensor.to_upper(), sensor]

func cancel_calibration() -> String:
	calibration.clear()
	return "Calibration cancelled. No test submitted or condition changed."

func can_depart() -> bool:
	for condition in sensors.values():
		if float(condition) <= 0.0: return false
	return not game_over

func repair_quote(sensor: String = "all") -> int:
	if sensor != "all" and not sensors.has(sensor): return -1
	var price := 0
	for name in SENSOR_NAMES:
		if sensor == "all" or name == sensor:
			price += int(ceil((100.0 - float(sensors[name])) * 2.0))
	return price

func repair(sensor: String = "all") -> String:
	if repair_quote(sensor) < 0: return "Unknown sensor."
	for name in SENSOR_NAMES:
		if sensor == "all" or name == sensor:
			sensors[name] = 100.0
			degraded_sensors.erase(name)
	if not calibration.is_empty() and (sensor == "all" or calibration.sensor == sensor): calibration.clear()
	return "Port service restored %s sensor condition." % ("all" if sensor == "all" else sensor)

func survival_ready() -> bool:
	return daily_food >= 0.999 and daily_water and hygiene >= HYGIENE_REQUIRED

func checklist_complete() -> bool:
	if not survival_ready(): return false
	for sensor in selected_sensors:
		if sensor not in checked_sensors: return false
	return true

func rest_plan(kind: String = "sleep") -> Dictionary:
	if game_over: return {"ok":false, "hours":0.0, "error":"This run has ended. Reload your departure checkpoint."}
	var current_hour := hour()
	if kind == "pass":
		if not checklist_complete(): return {"ok":false, "hours":0.0, "error":"Complete today's checklist before passing time."}
		if current_hour >= 20.0 or current_hour < 6.0: return {"ok":false, "hours":0.0, "error":"It is bedtime. Use sleep to wake at 06:00."}
		return {"ok":true, "hours":20.0 - current_hour, "error":"", "label":"Passing time until 20:00"}
	if kind not in ["sleep", "emergency"]: return {"ok":false, "hours":0.0, "error":"Choose sleep, pass, or emergency."}
	if kind == "sleep":
		if current_hour >= 6.0 and current_hour < 20.0: return {"ok":false, "hours":0.0, "error":"Sleep is available from 20:00 to 06:00. Complete the checklist to pass time."}
		if not survival_ready(): return {"ok":false, "hours":0.0, "error":"Eat, drink and maintain hygiene before sleeping. If supplies are inadequate, emergency rest is available."}
	else:
		if daily_food >= 0.999 and daily_water: return {"ok":false, "hours":0.0, "error":"Food and water needs are met. Use normal sleep."}
		# An unconsumed meal or full glass counts as available supplies; emergency
		# rest cannot be farmed simply by choosing not to use stocked provisions.
		var has_food := daily_food >= 0.999 or food_stock > 0 or hand_item in ["raw_food", "meal"] or not oven_state.is_empty() or table_bites > 0
		var has_water := daily_water or water_stock > 0 or hand_item == "water_glass"
		if has_food and has_water: return {"ok":false, "hours":0.0, "error":"Supplies are available. Prepare your meal and drink first."}
		if emergency_uses >= 3: return {"ok":false, "hours":0.0, "error":"No emergency rests remain. Another attempt ends this run.", "fatal":true}
	var hours_until_morning := 6.0 - current_hour if current_hour < 6.0 else 30.0 - current_hour
	return {"ok":true, "hours":hours_until_morning, "error":"", "label":"Emergency rest until 06:00" if kind == "emergency" else "Sleeping until 06:00", "remaining":3 - emergency_uses}

func start_rest(kind: String = "sleep") -> Dictionary:
	var plan := rest_plan(kind)
	if bool(plan.get("fatal", false)):
		game_over = true
		plan.error = "RESCUE REQUIRED. Emergency rest exhausted. This run has ended; reload your departure checkpoint."
	elif bool(plan.ok) and kind == "emergency":
		emergency_uses += 1
		plan.remaining = 3 - emergency_uses
	return plan

func print_checklist() -> String:
	printed_day = day()
	return checklist_text()

func stock_text() -> String:
	return "FOOD: %d / %d days\nWATER: %d / %d days\nHYGIENE: %d%%\nEMERGENCY RESTS: %d / 3 remaining" % [food_stock, capacity, water_stock, capacity, roundi(hygiene), maxi(0, 3 - emergency_uses)]

func checklist_text() -> String:
	var lines: Array[String] = [time_text(), "DAILY SHIPBOARD ROUTINE", ""]
	lines.append("[%s] Eat daily meal (%d%%)" % ["X" if daily_food >= 0.999 else " ", roundi(daily_food * 100.0)])
	lines.append("[%s] Drink daily water" % ("X" if daily_water else " "))
	lines.append("[%s] Hygiene sufficient (%d%%)" % ["X" if hygiene >= HYGIENE_REQUIRED else " ", roundi(hygiene)])
	for sensor in selected_sensors: lines.append("[%s] Check %s sensors" % ["X" if sensor in checked_sensors else " ", sensor])
	lines.append("")
	lines.append(stock_text())
	return "\n".join(lines)

func sensor_text() -> String:
	var lines: Array[String] = ["ENGINEERING / SENSOR CONDITION", ""]
	for sensor in SENSOR_NAMES:
		var condition := float(sensors[sensor])
		var note := "FAILED / PORT REPAIR" if condition <= 0.0 else ("PORT SERVICE ADVISED" if condition <= 25.0 else "nominal")
		if sensor in degraded_sensors: note = "DEGRADED / RECALIBRATE"
		if condition <= 0.0: note = "FAILED / PORT REPAIR"
		elif sensor in checked_sensors: note += " / TEST PASSED"
		lines.append("%-15s %5.1f%%  %s" % [sensor.to_upper(), condition, note])
	lines.append("\ncheck <sensor> / resume / trim <a|b|c> <amount> / test / cancel\nDaily assignments are on the printed hab checklist.\nOnly port technicians restore condition.")
	return "\n".join(lines)

func snapshot() -> Dictionary:
	return {"version":1, "elapsed_hours":elapsed_hours, "food_stock":food_stock, "water_stock":water_stock,
		"hygiene":hygiene, "hand_item":hand_item, "hand_bites":hand_bites, "oven_state":oven_state,
		"cook_remaining":cook_remaining, "table_bites":table_bites, "daily_food":daily_food, "daily_water":daily_water,
		"sensors":sensors.duplicate(true), "selected_sensors":selected_sensors.duplicate(), "checked_sensors":checked_sensors.duplicate(),
		"degraded_sensors":degraded_sensors.duplicate(), "calibration":calibration.duplicate(true),
		"emergency_uses":emergency_uses, "game_over":game_over, "printed_day":printed_day,
		"bought_food":_bought_food, "bought_water":_bought_water}

func restore(data: Dictionary) -> void:
	elapsed_hours = maxf(0.0, _finite(data.get("elapsed_hours", 6.0), 6.0))
	food_stock = clampi(int(data.get("food_stock", 0)), 0, capacity)
	water_stock = clampi(int(data.get("water_stock", 0)), 0, capacity)
	hygiene = clampf(_finite(data.get("hygiene", 55.0), 55.0), 0.0, 100.0)
	hand_item = str(data.get("hand_item", ""))
	if hand_item not in HAND_ITEMS: hand_item = ""
	hand_bites = clampi(int(data.get("hand_bites", 0)), 0, 5)
	if hand_item == "meal" and hand_bites == 0: hand_item = "dirty_plate"
	if hand_item != "meal": hand_bites = 0
	oven_state = str(data.get("oven_state", ""))
	if oven_state not in ["", "cooking", "ready"]: oven_state = ""
	cook_remaining = clampf(_finite(data.get("cook_remaining", 0.0), 0.0), 0.0, COOK_SECONDS)
	if oven_state == "cooking" and cook_remaining == 0.0: oven_state = "ready"
	if oven_state != "cooking": cook_remaining = 0.0
	table_bites = clampi(int(data.get("table_bites", -1)), -1, 5)
	daily_food = clampf(_finite(data.get("daily_food", 0.0), 0.0), 0.0, 1.0)
	daily_water = bool(data.get("daily_water", false))
	sensors.clear()
	var saved_sensors: Dictionary = data.get("sensors", {}) if data.get("sensors", {}) is Dictionary else {}
	for sensor in SENSOR_NAMES: sensors[sensor] = clampf(_finite(saved_sensors.get(sensor, 100.0), 100.0), 0.0, 100.0)
	_select_sensors()
	checked_sensors.clear()
	var saved_checked = data.get("checked_sensors", [])
	if saved_checked is Array:
		for sensor in saved_checked:
			if str(sensor) in SENSOR_NAMES and str(sensor) not in checked_sensors: checked_sensors.append(str(sensor))
	degraded_sensors.clear()
	var saved_degraded = data.get("degraded_sensors", [])
	if saved_degraded is Array:
		for sensor in saved_degraded:
			if str(sensor) in SENSOR_NAMES and str(sensor) not in degraded_sensors:
				degraded_sensors.append(str(sensor))
				checked_sensors.erase(str(sensor))
	calibration.clear()
	var saved_calibration = data.get("calibration", {})
	if saved_calibration is Dictionary and str(saved_calibration.get("sensor", "")) in SENSOR_NAMES and int(saved_calibration.get("day", 0)) == day():
		var valid := true
		for key in ["target", "readings"]:
			var values = saved_calibration.get(key, [])
			if not values is Array or values.size() != 3: valid = false
			else:
				for value in values:
					if (value is not int and value is not float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0 or float(value) > 9: valid = false
		if valid:
			calibration = {"sensor":str(saved_calibration.sensor), "day":day(), "target":[], "readings":[]}
			for key in ["target", "readings"]:
				for value in saved_calibration[key]: calibration[key].append(int(value))
	emergency_uses = clampi(int(data.get("emergency_uses", 0)), 0, 3)
	game_over = bool(data.get("game_over", false))
	printed_day = clampi(int(data.get("printed_day", 0)), 0, day())
	_bought_food = bool(data.get("bought_food", false))
	_bought_water = bool(data.get("bought_water", false))
	last_error = ""

func _finite(value: Variant, fallback: float) -> float:
	if value is not float and value is not int: return fallback
	return float(value) if is_finite(float(value)) else fallback
