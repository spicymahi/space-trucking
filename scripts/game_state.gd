extends Node
## Global game state: credits, station markets, input bindings and shared fonts.

signal toast(text: String)
signal credits_changed(value: int)
signal board_changed(station_id: String)

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
	"vesta_forge": {
		"name": "Vesta Forge",
		"position": Vector3(-7400, 400, 1600),
		"accent": Color("c8432f"),
		"blurb": "Ore smelter and machine shop",
	},
	"europa_deep": {
		"name": "Europa Deep",
		"position": Vector3(-9600, -400, -3600),
		"accent": Color("4f7fb5"),
		"blurb": "Ice drillers and research labs",
	},
	"callisto_hub": {
		"name": "Callisto Hub",
		"position": Vector3(-4200, -200, -10200),
		"accent": Color("8a5fb0"),
		"blurb": "Habitat ring and free port",
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
	"vesta_forge": {
		"water_ice": {"buy": 0, "sell": 150, "stock": 0},
		"iron_ore": {"buy": 0, "sell": 160, "stock": 0},
		"hydro_food": {"buy": 0, "sell": 230, "stock": 0},
		"machine_parts": {"buy": 400, "sell": 350, "stock": 30},
		"med_supplies": {"buy": 0, "sell": 1150, "stock": 0},
	},
	"europa_deep": {
		"water_ice": {"buy": 60, "sell": 48, "stock": 60},
		"iron_ore": {"buy": 0, "sell": 120, "stock": 0},
		"hydro_food": {"buy": 0, "sell": 290, "stock": 0},
		"machine_parts": {"buy": 0, "sell": 650, "stock": 0},
		"med_supplies": {"buy": 900, "sell": 800, "stock": 12},
	},
	"callisto_hub": {
		"water_ice": {"buy": 0, "sell": 170, "stock": 0},
		"iron_ore": {"buy": 0, "sell": 95, "stock": 0},
		"hydro_food": {"buy": 140, "sell": 120, "stock": 40},
		"machine_parts": {"buy": 0, "sell": 720, "stock": 0},
		"med_supplies": {"buy": 0, "sell": 1320, "stock": 0},
	},
}

## Hauling contracts. Each board keeps OFFERS_PER_BOARD jobs posted, at least
## one to every other station. A job's crates belong to the client: they can't
## be sold at an exchange, only delivered to the job's destination.
const OFFERS_PER_BOARD := 5
const MAX_ACTIVE_JOBS := 4
## Every this many seconds each board drops its oldest offer and posts a new one.
const OFFER_TURNOVER := 180.0
## Abandoning a job costs this share of its reward.
const ABANDON_PENALTY := 0.25
## Reward per crate is (JOB_BASE + km * JOB_PER_KM) times the commodity's value factor.
const JOB_BASE := 25.0
const JOB_PER_KM := 12.0
const JOB_VALUE := {"water_ice": 1.0, "iron_ore": 1.0, "hydro_food": 1.15, "machine_parts": 1.3, "med_supplies": 1.5}
const CLIENTS := {
	"ceres_yard": ["Ceres Mining Co-op", "Belt Ice Partners"],
	"tharsis_ring": ["Tharsis Agri-Collective", "Red Sands Fab"],
	"vesta_forge": ["Vesta Smelting Works", "Forge Union 9"],
	"europa_deep": ["Europa Research Trust", "Deep Bore Drilling"],
	"callisto_hub": ["Callisto Port Authority", "Hub Freight Exchange"],
}

## Markets move this share of the way back to their usual prices every MARKET_TICK seconds.
const MARKET_RELAX := 0.04
const MARKET_TICK := 6.0

var credits: int = 1500
var markets: Dictionary = {}
var using_gamepad := false
var rng := RandomNumberGenerator.new()
## station id -> Array of offer dictionaries (see make_job)
var offers: Dictionary = {}
## Jobs the player has signed, in signing order.
var jobs: Array[Dictionary] = []
var _next_job := 11
var _turnover := OFFER_TURNOVER
## Off under the self-test, so its seeded boards don't re-roll mid-run.
var turnover_enabled := true
## Prices and NPC trades hold still while you're at a terminal, so the
## quote on screen is the price you get.
var market_hold := false
## station id -> last few NPC trades there
var traffic: Dictionary = {}
var _relax_t := MARKET_TICK

var font_crt: Font
var font_label: Font


func _ready() -> void:
	markets = START_MARKETS.duplicate(true)
	# Fixed seed under the self-test so its job boards are the same every run.
	if "--selftest" in OS.get_cmdline_user_args():
		rng.seed = 42
		turnover_enabled = false
	else:
		rng.randomize()
	for id in STATIONS:
		offers[id] = []
		_fill_board(id)
	font_crt = load("res://assets/fonts/VT323-Regular.ttf")
	font_label = load("res://assets/fonts/Oswald-Variable.ttf")
	setup_input()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false


func _process(delta: float) -> void:
	if not market_hold:
		_relax_t -= delta
		if _relax_t <= 0.0:
			_relax_t = MARKET_TICK
			relax_markets()
	if not turnover_enabled:
		return
	_turnover -= delta
	if _turnover <= 0.0:
		_turnover = OFFER_TURNOVER
		for id in offers:
			if not offers[id].is_empty():
				offers[id].pop_front()
			_fill_board(id)
			board_changed.emit(id)


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
	var r := market_buy(station_id, commodity, qty, credits)
	if r["count"] > 0:
		credits -= r["spent"]
		credits_changed.emit(credits)
	return r["count"]


## Sells qty crates. Returns credits earned.
func sell(station_id: String, commodity: String, qty: int) -> int:
	var earned := market_sell(station_id, commodity, qty)
	credits += earned
	credits_changed.emit(credits)
	return earned


## Takes up to qty crates off a market for anyone with `budget` credits (you or
## an NPC trader). Returns {"count", "spent"}.
func market_buy(station_id: String, commodity: String, qty: int, budget: int) -> Dictionary:
	var m: Dictionary = market(station_id, commodity)
	var count := 0
	var spent := 0
	if m["buy"] <= 0:
		return {"count": 0, "spent": 0}
	while count < qty and m["stock"] > 0 and budget - spent >= m["buy"]:
		spent += m["buy"]
		m["stock"] -= 1
		count += 1
		# Supply gets tighter as anyone buys, so prices creep up.
		m["buy"] = int(ceil(m["buy"] * 1.015))
	return {"count": count, "spent": spent}


## Puts qty crates on a market. Returns what it paid.
func market_sell(station_id: String, commodity: String, qty: int) -> int:
	var m: Dictionary = market(station_id, commodity)
	var earned := 0
	for i in qty:
		earned += m["sell"]
		m["stock"] += 1
		# Demand softens as the market fills.
		m["sell"] = maxi(1, int(floor(m["sell"] * 0.985)))
	return earned


## Markets drift back toward their usual prices and stock: producers restock,
## consumers use up what they bought, and prices relax.
func relax_markets() -> void:
	for id in markets:
		for c in markets[id]:
			var m: Dictionary = markets[id][c]
			var base: Dictionary = START_MARKETS[id][c]
			for k in ["buy", "sell"]:
				if base[k] > 0:
					var d: int = base[k] - m[k]
					if d != 0:
						m[k] += signi(d) * mini(absi(d), maxi(1, roundi(absi(d) * MARKET_RELAX)))
			m["stock"] += signi(base["stock"] - m["stock"])
			if m["buy"] > 0 and m["sell"] >= m["buy"]:
				m["sell"] = m["buy"] - 1


## A line on a station's traffic log, shown on its exchange.
func log_traffic(station_id: String, text: String) -> void:
	var lines: Array = traffic.get(station_id, [])
	lines.append(text)
	while lines.size() > 3:
		lines.pop_front()
	traffic[station_id] = lines


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


# ---------------------------------------------------------------- contracts

func station_distance_km(a: String, b: String) -> float:
	return (STATIONS[a]["position"] as Vector3).distance_to(STATIONS[b]["position"]) / 1000.0


## A new hauling offer from `origin` to `dest`. The cargo is something origin
## makes when it can, and the client pays more for distance and for valuable goods.
func make_job(origin: String, dest: String) -> Dictionary:
	var made: Array = []
	for c in COMMODITY_ORDER:
		if START_MARKETS[origin][c]["buy"] > 0:
			made.append(c)
	var c: String = made[rng.randi() % made.size()] if not made.is_empty() else COMMODITY_ORDER[rng.randi() % COMMODITY_ORDER.size()]
	var crates := rng.randi_range(1, 6)
	var per: float = (JOB_BASE + station_distance_km(origin, dest) * JOB_PER_KM) * float(JOB_VALUE[c])
	var clients: Array = CLIENTS[origin]
	var job := {
		"id": _next_job,
		"origin": origin,
		"dest": dest,
		"commodity": c,
		"crates": crates,
		"reward": int(round(per * crates / 10.0)) * 10,
		"client": clients[rng.randi() % clients.size()],
	}
	_next_job += 1
	return job


## Tops a board up to OFFERS_PER_BOARD, posting first to stations it has no offer for.
func _fill_board(id: String) -> void:
	var board: Array = offers[id]
	while board.size() < OFFERS_PER_BOARD:
		var missing: Array = []
		var others: Array = []
		for d in STATIONS:
			if d == id:
				continue
			others.append(d)
			if not board.any(func(o): return o["dest"] == d):
				missing.append(d)
		var pool := missing if not missing.is_empty() else others
		board.append(make_job(id, pool[rng.randi() % pool.size()]))


func job(id: int) -> Dictionary:
	for j in jobs:
		if j["id"] == id:
			return j
	return {}


## Signs an offer from a station's board. The caller spawns its crates.
func accept_job(station_id: String, job_id: int) -> Dictionary:
	if jobs.size() >= MAX_ACTIVE_JOBS:
		return {}
	var board: Array = offers[station_id]
	for i in board.size():
		if board[i]["id"] == job_id:
			var j: Dictionary = board[i]
			board.remove_at(i)
			jobs.append(j)
			_fill_board(station_id)
			return j
	return {}


## Pays out a delivered job, less the dock crew's fee. Returns credits earned.
func complete_job(job_id: int, fee: int) -> int:
	var j := job(job_id)
	if j.is_empty():
		return 0
	jobs.erase(j)
	credits += j["reward"] - fee
	credits_changed.emit(credits)
	return j["reward"] - fee


## Cancels a signed job and charges the penalty. Returns the penalty.
func abandon_job(job_id: int) -> int:
	var j := job(job_id)
	if j.is_empty():
		return 0
	jobs.erase(j)
	# Never takes you below zero.
	var penalty := mini(int(round(j["reward"] * ABANDON_PENALTY)), maxi(0, credits))
	pay_fee(penalty)
	return penalty


## An NPC trader takes a random offer off a station's board. Returns it, or empty.
func npc_take_offer(station_id: String, r: RandomNumberGenerator) -> Dictionary:
	var board: Array = offers[station_id]
	if board.is_empty():
		return {}
	var j: Dictionary = board.pop_at(r.randi() % board.size())
	_fill_board(station_id)
	board_changed.emit(station_id)
	return j


func jobs_to(station_id: String) -> int:
	return jobs.filter(func(j): return j["dest"] == station_id).size()


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
