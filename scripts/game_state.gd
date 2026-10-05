extends Node
## Global game state: credits, station markets, input bindings and shared fonts.

signal toast(text: String)
signal credits_changed(value: int)

const CRATE_SCU := 2
## Selling straight from a docked ship's hold costs a dock-crew fee. Crates you
## carry to the pallet yourself, or sell from your hands, pay full price.
const HOLD_SALE_FEE := 0.10

const COMMODITIES := {
	"water_ice": {"name": "Water Ice", "short": "ICE", "color": Color("9fe3ff")},
	"iron_ore": {"name": "Iron Ore", "short": "ORE", "color": Color("b07a4e")},
	"hydro_food": {"name": "Hydroponic Food", "short": "FOOD", "color": Color("7fd36a")},
	"machine_parts": {"name": "Machine Parts", "short": "PARTS", "color": Color("e3a92c")},
	"med_supplies": {"name": "Medical Supplies", "short": "MED", "color": Color("c8432f")},
}
const COMMODITY_ORDER := ["water_ice", "iron_ore", "hydro_food", "machine_parts", "med_supplies"]

## Station definitions. Positions are multiples of 100 m so nav-grid coordinates are exact.
const STATIONS := {
	"ceres_yard": {
		"name": "Ceres Yard",
		"position": Vector3(0, 0, 0),
		"accent": Color("e0662f"),
		"blurb": "Belt mining station",
	},
	"tharsis_ring": {
		"name": "Tharsis Ring",
		"position": Vector3(2400, 300, -6800),
		"accent": Color("3d8c87"),
		"blurb": "Mars orbital farm and fab yard",
	},
}

## Starting prices per crate. "buy" is what the player pays, "sell" is what the station pays.
const START_MARKETS := {
	"ceres_yard": {
		"water_ice": {"buy": 80, "sell": 66, "stock": 40},
		"iron_ore": {"buy": 55, "sell": 44, "stock": 60},
		"hydro_food": {"buy": 0, "sell": 260, "stock": 0},
		"machine_parts": {"buy": 690, "sell": 600, "stock": 6},
		"med_supplies": {"buy": 0, "sell": 1250, "stock": 0},
	},
	"tharsis_ring": {
		"water_ice": {"buy": 0, "sell": 190, "stock": 0},
		"iron_ore": {"buy": 0, "sell": 130, "stock": 0},
		"hydro_food": {"buy": 120, "sell": 100, "stock": 50},
		"machine_parts": {"buy": 480, "sell": 420, "stock": 20},
		"med_supplies": {"buy": 980, "sell": 880, "stock": 8},
	},
}

var credits: int = 1500
var markets: Dictionary = {}
var using_gamepad := false

var font_crt: Font
var font_label: Font


func _ready() -> void:
	markets = START_MARKETS.duplicate(true)
	font_crt = load("res://assets/fonts/VT323-Regular.ttf")
	font_label = load("res://assets/fonts/Oswald-Variable.ttf")
	setup_input()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false


func say(text: String) -> void:
	toast.emit(text)


func station_name(id: String) -> String:
	return STATIONS[id]["name"] if STATIONS.has(id) else "Deep space"


func station_grid(id: String) -> Vector3i:
	var p: Vector3 = STATIONS[id]["position"]
	return Vector3i(roundi(p.x / 100.0), roundi(p.y / 100.0), roundi(p.z / 100.0))


func station_at_grid(g: Vector3i) -> String:
	for id in STATIONS:
		if station_grid(id) == g:
			return id
	return ""


static func format_grid(v: int) -> String:
	return ("+" if v >= 0 else "-") + str(absi(v)).pad_zeros(3)


static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func market(station_id: String, commodity: String) -> Dictionary:
	return markets[station_id][commodity]


## Buys up to qty crates. Returns how many were bought.
func buy(station_id: String, commodity: String, qty: int) -> int:
	var m: Dictionary = market(station_id, commodity)
	if m["buy"] <= 0 or m["stock"] <= 0:
		return 0
	var count := 0
	while count < qty and m["stock"] > 0 and credits >= m["buy"]:
		credits -= m["buy"]
		m["stock"] -= 1
		count += 1
		# Supply gets tighter as you buy, so prices creep up.
		m["buy"] = int(ceil(m["buy"] * 1.015))
	if count > 0:
		credits_changed.emit(credits)
	return count


## Sells qty crates. Returns credits earned.
func sell(station_id: String, commodity: String, qty: int) -> int:
	var m: Dictionary = market(station_id, commodity)
	var earned := 0
	for i in qty:
		earned += m["sell"]
		m["stock"] += 1
		# Demand softens as you flood the market.
		m["sell"] = maxi(1, int(floor(m["sell"] * 0.985)))
	credits += earned
	credits_changed.emit(credits)
	return earned


## What selling qty crates would earn, after skipping the first `skip` sales
## (prices soften with every crate sold). Doesn't change the market.
func quote_sell(station_id: String, commodity: String, qty: int, skip := 0) -> int:
	var p: int = market(station_id, commodity)["sell"]
	var earned := 0
	for i in skip + qty:
		if i >= skip:
			earned += p
		p = maxi(1, int(floor(p * 0.985)))
	return earned


func pay_fee(amount: int) -> void:
	credits -= amount
	credits_changed.emit(credits)


## Best sell price for a commodity at any station other than here.
func best_elsewhere(here: String, commodity: String) -> Dictionary:
	var best := {"station": "", "price": 0}
	for id in markets:
		if id == here:
			continue
		var p: int = markets[id][commodity]["sell"]
		if p > best["price"]:
			best = {"station": id, "price": p}
	return best


# ---------------------------------------------------------------- input

func setup_input() -> void:
	# Movement on foot
	_bind("move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1)])
	_bind("move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1)])
	_bind("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1)])
	_bind("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1)])
	_bind("look_left", [_axis(JOY_AXIS_RIGHT_X, -1)])
	_bind("look_right", [_axis(JOY_AXIS_RIGHT_X, 1)])
	_bind("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1)])
	_bind("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1)])
	_bind("sprint", [_key(KEY_SHIFT), _btn(JOY_BUTTON_LEFT_STICK)])
	_bind("interact", [_key(KEY_F), _btn(JOY_BUTTON_A)])
	_bind("cancel", [_key(KEY_ESCAPE), _btn(JOY_BUTTON_B)])
	_bind("pause", [_key(KEY_P), _btn(JOY_BUTTON_START)])
	_bind("sell", [_key(KEY_R), _btn(JOY_BUTTON_X)])
	_bind("nav_directory", [_key(KEY_M)])

	# Flight
	_bind("throttle_up", [_key(KEY_W), _axis(JOY_AXIS_TRIGGER_RIGHT, 1)])
	_bind("throttle_down", [_key(KEY_S), _axis(JOY_AXIS_TRIGGER_LEFT, 1)])
	_bind("strafe_left", [_key(KEY_A), _axis(JOY_AXIS_RIGHT_X, -1)])
	_bind("strafe_right", [_key(KEY_D), _axis(JOY_AXIS_RIGHT_X, 1)])
	_bind("thrust_up", [_key(KEY_SPACE), _axis(JOY_AXIS_RIGHT_Y, -1)])
	_bind("thrust_down", [_key(KEY_Z), _axis(JOY_AXIS_RIGHT_Y, 1)])
	_bind("pitch_up", [_key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, 1)])
	_bind("pitch_down", [_key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, -1)])
	_bind("yaw_left", [_key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1)])
	_bind("yaw_right", [_key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1)])
	_bind("roll_left", [_key(KEY_Q), _btn(JOY_BUTTON_LEFT_SHOULDER)])
	_bind("roll_right", [_key(KEY_E), _btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_bind("request_dock", [_key(KEY_L), _btn(JOY_BUTTON_X)])
	_bind("nav_computer", [_key(KEY_N), _btn(JOY_BUTTON_Y)])
	_bind("cruise", [_key(KEY_C), _btn(JOY_BUTTON_LEFT_STICK)])

	# Menus and keypad navigation
	_bind("ui_up", [_btn(JOY_BUTTON_DPAD_UP)])
	_bind("ui_down", [_btn(JOY_BUTTON_DPAD_DOWN)])
	_bind("ui_left", [_btn(JOY_BUTTON_DPAD_LEFT), _btn(JOY_BUTTON_LEFT_SHOULDER)])
	_bind("ui_right", [_btn(JOY_BUTTON_DPAD_RIGHT), _btn(JOY_BUTTON_RIGHT_SHOULDER)])


func _bind(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for e in events:
		InputMap.action_add_event(action, e)


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _axis(a: JoyAxis, dir: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = dir
	return e
