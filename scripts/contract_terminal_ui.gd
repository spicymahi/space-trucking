class_name ContractTerminalUI
extends Control
## The contract board: an amber-phosphor CRT in a mustard terminal casing.
## Lists the hauling jobs posted at this station and the jobs you have signed.
## Signing a job puts its crates on pallet 07-B. You haul them in your hold and
## deliver them at the destination's board, from your hands, the pallet there,
## or your docked hold (the dock crew unloads hold crates for a fee).

signal closed

const PHOS := Color("ffb347")
const PHOS_BG := Color("2a1806")

var station: Station
var ship: Ship
var player: Player
var stations: Array = []
var sel := 0
var message := ""
var _confirm_abandon := 0
var _text: RichTextLabel
var _hint: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var casing := Panel.new()
	casing.set_anchors_preset(Control.PRESET_CENTER)
	casing.custom_minimum_size = Vector2(1060, 660)
	casing.size = casing.custom_minimum_size
	casing.position = -casing.size / 2
	var sb := StyleBoxFlat.new()
	sb.bg_color = Vox.BEIGE
	sb.set_corner_radius_all(18)
	sb.border_color = Vox.MUSTARD
	sb.set_border_width_all(6)
	sb.border_width_bottom = 22
	casing.add_theme_stylebox_override("panel", sb)
	add_child(casing)
	var tag := Label.new()
	tag.text = "  CONTRACT BOARD  "
	tag.add_theme_font_override("font", GameState.font_label)
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Vox.CREAM)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color("16130f")
	tsb.set_corner_radius_all(3)
	tag.add_theme_stylebox_override("normal", tsb)
	tag.position = Vector2(455, 14)
	casing.add_child(tag)
	var crt := Panel.new()
	crt.position = Vector2(40, 52)
	crt.size = Vector2(980, 500)
	var csb := StyleBoxFlat.new()
	csb.bg_color = PHOS_BG
	csb.set_corner_radius_all(26)
	csb.border_color = Color("2c241c")
	csb.set_border_width_all(10)
	crt.add_theme_stylebox_override("panel", csb)
	casing.add_child(crt)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.position = Vector2(34, 20)
	_text.size = Vector2(912, 464)
	_text.add_theme_font_override("normal_font", GameState.font_crt)
	_text.add_theme_font_size_override("normal_font_size", 27)
	_text.add_theme_color_override("default_color", PHOS)
	_text.add_theme_constant_override("line_separation", -4)
	crt.add_child(_text)
	_hint = Label.new()
	_hint.position = Vector2(40, 570)
	_hint.size = Vector2(980, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", GameState.font_label)
	_hint.add_theme_font_size_override("font_size", 21)
	_hint.add_theme_color_override("font_color", Vox.DBROWN)
	casing.add_child(_hint)
	GameState.board_changed.connect(_on_board_changed)


## Offers turn over while the board is open: keep the cursor on the same job.
func _on_board_changed(station_id: String) -> void:
	if not visible or station == null or station_id != station.station_id:
		return
	var id: int = selected().get("job", {}).get("id", 0)
	var rows := entries()
	for i in rows.size():
		if rows[i]["job"]["id"] == id:
			sel = i
	_refresh()


func open(st: Station, p_ship: Ship, p_player: Player, p_stations: Array) -> void:
	station = st
	ship = p_ship
	player = p_player
	stations = p_stations
	_confirm_abandon = 0
	message = "WELCOME, KESTREL-9."
	sel = 0
	# Arriving with a job for here: put the cursor on it.
	var rows := entries()
	for i in rows.size():
		if rows[i]["signed"] and rows[i]["job"]["dest"] == st.station_id:
			sel = i
			message = "JOB %d ENDS HERE. PRESS %s TO DELIVER." % [rows[i]["job"]["id"], _key_use()]
			break
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


## The board's rows: jobs posted here, then your signed jobs.
func entries() -> Array:
	var out := []
	for o in GameState.offers[station.station_id]:
		out.append({"job": o, "signed": false})
	for j in GameState.jobs:
		out.append({"job": j, "signed": true})
	return out


func selected() -> Dictionary:
	var rows := entries()
	return rows[clampi(sel, 0, rows.size() - 1)] if not rows.is_empty() else {}


## Where a signed job's crates are, as far as this station can reach them.
func job_counts(id: int) -> Dictionary:
	var hand := 1 if player and player.carried and player.carried.job_id == id else 0
	var hold := Slot.count_job(ship.hold_slots, id) if ship and ship.landed_at == station else 0
	return {"hand": hand, "pad": Slot.count_job(station.pallet_slots, id), "hold": hold}


## Dock crew fee for unloading a job's hold crates: a share of the reward.
func delivery_fee(j: Dictionary, hold: int) -> int:
	return roundi(j["reward"] * float(hold) / j["crates"] * GameState.HOLD_SALE_FEE)


func _key_use() -> String:
	return "A" if GameState.using_gamepad else "F"


func _key_alt() -> String:
	return "X" if GameState.using_gamepad else "R"


func _kbd(k: String) -> String:
	return "[lb]" + k + "[rb]"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var n := entries().size()
	if event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		sel = posmod(sel - 1, maxi(1, n))
		_confirm_abandon = 0
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		sel = posmod(sel + 1, maxi(1, n))
		_confirm_abandon = 0
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		use_selected()
	elif event.is_action_pressed("sell"):
		abandon_selected()
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()


## Signs the selected offer, or delivers the selected job. Returns credits earned.
func use_selected() -> int:
	_confirm_abandon = 0
	var row := selected()
	if row.is_empty():
		return 0
	if row["signed"]:
		return deliver(row["job"]["id"])
	sign_job(row["job"]["id"])
	return 0


func sign_job(id: int) -> bool:
	var offer: Dictionary = {}
	for o in GameState.offers[station.station_id]:
		if o["id"] == id:
			offer = o
	if offer.is_empty():
		return false
	if GameState.jobs.size() >= GameState.MAX_ACTIVE_JOBS:
		message = "YOU HOLD %d JOBS, THE MOST ALLOWED. DELIVER ONE FIRST." % GameState.MAX_ACTIVE_JOBS
		return false
	var free := station.free_pallet_slots().size()
	if free < offer["crates"]:
		message = "PALLET 07-B HAS ROOM FOR %d. THIS JOB NEEDS %d. LOAD YOUR HOLD FIRST." % [free, offer["crates"]]
		return false
	var j := GameState.accept_job(station.station_id, id)
	station.spawn_on_pallet(j["commodity"], j["crates"], j["id"])
	message = "JOB %d SIGNED. %d CRATE%s ON PALLET 07-B FOR %s." % [j["id"], j["crates"], "" if j["crates"] == 1 else "S", GameState.station_name(j["dest"]).to_upper()]
	# Keep the cursor on the job you just signed, now in your list.
	var rows := entries()
	for i in rows.size():
		if rows[i]["signed"] and rows[i]["job"]["id"] == j["id"]:
			sel = i
	return true


## Delivers a job here if all its crates are here. Returns credits earned.
func deliver(id: int) -> int:
	var j := GameState.job(id)
	if j.is_empty():
		return 0
	if j["dest"] != station.station_id:
		message = "JOB %d DELIVERS TO %s, NOT HERE." % [id, GameState.station_name(j["dest"]).to_upper()]
		return 0
	var k := job_counts(id)
	var have: int = k["hand"] + k["pad"] + k["hold"]
	if have < j["crates"]:
		message = "ONLY %d OF %d CRATES HERE. BRING THE REST TO PALLET 07-B." % [have, j["crates"]]
		return 0
	var fee := delivery_fee(j, k["hold"])
	if k["hand"] > 0:
		player.give_up_carried()
	Slot.take_job(station.pallet_slots, id)
	if k["hold"] > 0:
		Slot.take_job(ship.hold_slots, id)
	var earned := GameState.complete_job(id, fee)
	message = "JOB %d DELIVERED. PAID %s CR%s." % [id, GameState.money(earned), (" (DOCK CREW FEE %s)" % GameState.money(fee)) if fee > 0 else ""]
	sel = clampi(sel, 0, entries().size() - 1)
	return earned


## Abandons the selected signed job on the second press. Returns the penalty paid.
func abandon_selected() -> int:
	var row := selected()
	if row.is_empty() or not row["signed"]:
		_confirm_abandon = 0
		message = "SELECT ONE OF YOUR JOBS TO ABANDON IT."
		return 0
	var j: Dictionary = row["job"]
	if _confirm_abandon != j["id"]:
		_confirm_abandon = j["id"]
		message = "PRESS %s AGAIN TO ABANDON JOB %d. PENALTY %s CR, AND THE CLIENT RECLAIMS ITS CRATES." % [_key_alt(), j["id"], GameState.money(roundi(j["reward"] * GameState.ABANDON_PENALTY))]
		return 0
	_confirm_abandon = 0
	if player and player.carried and player.carried.job_id == j["id"]:
		player.give_up_carried()
	Slot.take_job(ship.hold_slots, j["id"])
	for st in stations:
		Slot.take_job(st.pallet_slots, j["id"])
	var penalty := GameState.abandon_job(j["id"])
	message = "JOB %d ABANDONED. PENALTY %s CR." % [j["id"], GameState.money(penalty)]
	sel = clampi(sel, 0, entries().size() - 1)
	return penalty


func _row(j: Dictionary, i: int, extra: String) -> String:
	var cargo := "%d %s" % [j["crates"], GameState.COMMODITIES[j["commodity"]]["short"]]
	var to := GameState.station_name(j["dest"]).to_upper()
	var km := GameState.station_distance_km(j["origin"], j["dest"])
	var line := "%s %-5s%-10s%-15s%6.1f%8s %s" % [">" if i == sel else " ", "#%d" % j["id"], cargo, to, km, GameState.money(j["reward"]), extra]
	if i == sel:
		return "[bgcolor=#ffb347][color=#2a1806]%s [/color][/bgcolor]\n" % line
	return line + "\n"


func _refresh() -> void:
	if not station:
		return
	var sid := station.station_id
	sel = clampi(sel, 0, maxi(0, entries().size() - 1))
	var head := "> CONTRACTS · " + station.display_name.to_upper()
	var cr := "CR " + GameState.money(GameState.credits)
	var t := head + " ".repeat(maxi(1, 62 - head.length() - cr.length())) + cr + "\n"
	t += "  %-5s%-10s%-15s%6s%8s\n" % ["JOB", "CARGO", "DELIVER TO", "KM", "PAY"]
	t += "--------------------------------------------------------------\n"
	t += "POSTED HERE\n"
	var rows := entries()
	var i := 0
	for r in rows:
		if r["signed"]:
			break
		t += _row(r["job"], i, "")
		i += 1
	t += "YOUR JOBS %d/%d\n" % [GameState.jobs.size(), GameState.MAX_ACTIVE_JOBS]
	if GameState.jobs.is_empty():
		t += "  NONE SIGNED\n"
	for j in GameState.jobs:
		var extra := ""
		if j["dest"] == sid:
			var k := job_counts(j["id"])
			extra = "%d/%d HERE" % [k["hand"] + k["pad"] + k["hold"], j["crates"]]
		t += _row(j, i, extra)
		i += 1
	t += "--------------------------------------------------------------\n"
	var row := selected()
	if not row.is_empty():
		var j: Dictionary = row["job"]
		t += "%s: %d CRATE%s OF %s TO %s.\n" % [String(j["client"]).to_upper(), j["crates"], "" if j["crates"] == 1 else "S", String(GameState.COMMODITIES[j["commodity"]]["name"]).to_upper(), GameState.station_name(j["dest"]).to_upper()]
		if not row["signed"]:
			t += "%s SIGN · CRATES GO TO PALLET 07-B · PAD SPACE %d\n" % [_kbd(_key_use()), station.free_pallet_slots().size()]
		elif j["dest"] == sid:
			var k := job_counts(j["id"])
			var fee := delivery_fee(j, k["hold"])
			t += "%s DELIVER%s · %s ABANDON\n" % [_kbd(_key_use()), ("  (HOLD %d, CREW FEE %s)" % [k["hold"], GameState.money(fee)]) if k["hold"] > 0 else "", _kbd(_key_alt())]
		else:
			t += "DELIVER AT %s · %s ABANDON\n" % [GameState.station_name(j["dest"]).to_upper(), _kbd(_key_alt())]
	t += message
	_text.text = t
	var g := GameState.using_gamepad
	_hint.text = ("D-pad select · A sign or deliver · X abandon · B close" if g
		else "W/S select · F sign or deliver · R abandon · Esc close")
