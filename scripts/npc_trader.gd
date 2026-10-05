class_name NpcTrader
extends AnimatableBody3D
## An NPC hauler running the same loop you do: buy where a good is cheap, fly it
## to the station that pays most for the trip, sell, and go again. When nothing
## pays it may take a hauling job off the board, or move on empty.
##
## It parks on one of a station's roof berths, climbs straight up to the traffic
## lane LANE_HEIGHT above, flies to the next station's lane point and comes down
## onto a free berth there. The lane keeps it clear of the hangar mouths and of
## the straight lines your own ship flies between stations.

enum State { PARKED, CLIMB, TRANSIT, HOLD, DESCEND }

const LANE_HEIGHT := 320.0
const CRUISE := 420.0
const ACCEL := 60.0
const VERT := 30.0
const PARK_MIN := 18.0
const PARK_MAX := 40.0
## Body origin above the roof top when parked (the gear reaches down to it).
const PARKED_Y := 2.55
## A trade has to clear this share of the buy price to be worth the trip.
const MIN_MARGIN := 0.12
const START_CREDITS := 4000

var callsign := "HAULER"
var accent := Vox.TEAL
var capacity := 8
var credits := START_CREDITS
var stations: Array = []
var state := State.PARKED
var at: Station = null # where it is parked, or where it is heading
var dest: Station = null
var berth := -1
var timer := 0.0
var speed := 0.0
## {"commodity", "crates", "paid"}, or empty
var cargo: Dictionary = {}
## A contract it took off a board, or empty
var job: Dictionary = {}
var sales := 0
var departures := 0
## Closest it has come to any station centre while moving faster than 100 m/s.
var closest_fast := INF
## Every flight state it has been in, for the self-test.
var states_seen := {}
var rng := RandomNumberGenerator.new()
var _pending_arrival := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO


func build(p_callsign: String, p_accent: Color, p_capacity: int) -> void:
	callsign = p_callsign
	accent = p_accent
	capacity = p_capacity
	name = "Npc_" + callsign
	collision_layer = Vox.L_WORLD
	collision_mask = 0
	sync_to_physics = true
	var b := Vox.Batch.new(self)
	b.solid(Vector3(0, 0, 0), Vector3(6, 3, 12), Vox.BEIGE)
	b.solid(Vector3(0, 1.95, -4.5), Vector3(3, 0.9, 2.5), Vox.BEIGE2)
	b.box(Vector3(0, 2.0, -5.77), Vector3(2.4, 0.5, 0.04), Color("1a2530"))
	b.box(Vector3(0, 0.6, 0), Vector3(6.04, 0.5, 12.04), accent)
	for sx in [-1, 1]:
		b.solid(Vector3(2 * sx, 0, 6.6), Vector3(1.6, 1.6, 1.2), Vox.DBROWN)
		for z in [-4, 4]:
			b.solid(Vector3(2.2 * sx, -2.0, z), Vector3(0.6, 1.1, 0.6), Vox.DBROWN)
	b.commit("Hull")
	for sx in [-1, 1]:
		Vox.box(self, Vector3(2 * sx, 0, 7.22), Vector3(1.2, 1.2, 0.04), Color("ff9a3c"), true)
	var l := Vox.label(self, callsign, Vector3(3.03, 0, 0), 0.006, Vox.DBROWN, GameState.font_label)
	l.rotation.y = PI / 2
	var r := Vox.label(self, callsign, Vector3(-3.03, 0, 0), 0.006, Vox.DBROWN, GameState.font_label)
	r.rotation.y = -PI / 2


## Puts it on a berth at a station, ready to leave after `wait` seconds.
func park_at(st: Station, wait: float) -> bool:
	var i := st.claim_berth(self)
	if i < 0:
		return false
	at = st
	berth = i
	global_transform = st.berth_transform(i)
	state = State.PARKED
	timer = wait
	speed = 0.0
	return true


func _physics_process(delta: float) -> void:
	states_seen[state] = true
	match state:
		State.PARKED:
			_parked(delta)
		State.CLIMB:
			if _move_line(delta, VERT):
				_start_transit()
		State.TRANSIT:
			_transit(delta)
		State.HOLD:
			timer -= delta
			if timer <= 0.0:
				_try_descend()
		State.DESCEND:
			if _move_line(delta, VERT):
				global_transform = at.berth_transform(berth)
				state = State.PARKED
				timer = rng.randf_range(PARK_MIN, PARK_MAX)
				_pending_arrival = true
	if speed > 100.0:
		for st in stations:
			closest_fast = minf(closest_fast, global_position.distance_to(st.global_position))


func _parked(delta: float) -> void:
	# Trades wait while you're at a terminal, so the price on your screen holds.
	if GameState.market_hold:
		return
	if _pending_arrival:
		_pending_arrival = false
		_arrive()
	timer -= delta
	if timer > 0.0:
		return
	_plan()
	at.release_berth(self)
	_from = global_position
	_to = at.to_global(at.berth_position(berth) + Vector3(0, LANE_HEIGHT, 0))
	berth = -1
	state = State.CLIMB
	departures += 1


## Moves along _from -> _to at up to `top` m/s, easing in at the end. True on arrival.
func _move_line(delta: float, top: float) -> bool:
	var left := global_position.distance_to(_to)
	speed = minf(top, minf(speed + ACCEL * delta, sqrt(2.0 * ACCEL * left) + 2.0))
	var step := speed * delta
	if step >= left:
		global_position = _to
		speed = 0.0
		return true
	global_position += (_to - global_position).normalized() * step
	return false


func _start_transit() -> void:
	_from = global_position
	_to = dest.to_global(Vector3(Station.NPC_BERTHS[1].x, LANE_HEIGHT, 0))
	state = State.TRANSIT


func _transit(delta: float) -> void:
	var d := _to - global_position
	if d.length() > 1.0:
		var want := Basis.looking_at(d.normalized(), Vector3.UP)
		global_basis = global_basis.slerp(want, minf(1.0, delta * 1.5)).orthonormalized()
	if _move_line(delta, CRUISE):
		at = dest
		_try_descend()


func _try_descend() -> void:
	var i := at.claim_berth(self)
	if i < 0:
		# Every berth is taken: hover on the lane and try again shortly.
		state = State.HOLD
		timer = 2.0
		return
	berth = i
	_from = global_position
	_to = at.berth_transform(i).origin
	global_basis = at.berth_transform(i).basis
	state = State.DESCEND


## Sells what it brought and hands in any job it carried.
func _arrive() -> void:
	var here := at.station_id
	if not cargo.is_empty():
		var c: String = cargo["commodity"]
		var n: int = cargo["crates"]
		var earned := GameState.market_sell(here, c, n)
		credits += earned
		sales += 1
		GameState.log_traffic(here, "%s SOLD %d %s FOR %s" % [callsign, n, GameState.COMMODITIES[c]["short"], GameState.money(earned)])
		cargo = {}
	if not job.is_empty():
		credits += job["reward"]
		GameState.log_traffic(here, "%s DELIVERED JOB %d" % [callsign, job["id"]])
		job = {}
	# The owners keep their haulers flying.
	if credits < 500:
		credits = START_CREDITS


## Picks the best paying trade from here, or a job, or an empty hop.
func _plan() -> void:
	var here := at.station_id
	var best := {}
	var best_score := 0.0
	for c in GameState.COMMODITY_ORDER:
		var m := GameState.market(here, c)
		if m["buy"] <= 0 or m["stock"] <= 0:
			continue
		for d in GameState.STATIONS:
			if d == here:
				continue
			var profit: int = GameState.market(d, c)["sell"] - m["buy"]
			if profit < m["buy"] * MIN_MARGIN:
				continue
			var n := mini(capacity, mini(m["stock"], credits / m["buy"]))
			if n <= 0:
				continue
			var score := float(profit * n) / (GameState.station_distance_km(here, d) + 4.0)
			if score > best_score:
				best_score = score
				best = {"commodity": c, "dest": d, "crates": n}
	if not best.is_empty():
		var r := GameState.market_buy(here, best["commodity"], best["crates"], credits)
		if r["count"] > 0:
			credits -= r["spent"]
			cargo = {"commodity": best["commodity"], "crates": r["count"], "paid": r["spent"]}
			dest = _station(best["dest"])
			GameState.log_traffic(here, "%s BOUGHT %d %s FOR %s" % [callsign, r["count"], GameState.COMMODITIES[best["commodity"]]["short"], dest.display_name.to_upper()])
			return
	if GameState.turnover_enabled and rng.randf() < 0.5:
		var j := GameState.npc_take_offer(here, rng)
		if not j.is_empty():
			job = j
			dest = _station(j["dest"])
			GameState.log_traffic(here, "%s TOOK JOB %d TO %s" % [callsign, j["id"], dest.display_name.to_upper()])
			return
	var others := stations.filter(func(s): return s != at)
	dest = others[rng.randi() % others.size()]
	GameState.log_traffic(here, "%s LEFT EMPTY FOR %s" % [callsign, dest.display_name.to_upper()])


func _station(id: String) -> Station:
	for s in stations:
		if s.station_id == id:
			return s
	return null


## One line for the flight HUD.
func status_text() -> String:
	if not cargo.is_empty():
		return "%d %s" % [cargo["crates"], GameState.COMMODITIES[cargo["commodity"]]["short"]]
	if not job.is_empty():
		return "JOB %d" % job["id"]
	return "EMPTY"
