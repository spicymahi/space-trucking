class_name TradeTerminalUI
extends Control
## The commodity exchange screen: a green-phosphor CRT in a beige terminal casing.
## Bought crates appear on pallet 07-B by your pad. Selling takes crates off that pallet.

signal closed

var station: Station
var sel := 0
var qty := 1
var message := ""
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
	sb.border_color = Vox.BEIGE3
	sb.set_border_width_all(6)
	sb.border_width_bottom = 22
	casing.add_theme_stylebox_override("panel", sb)
	add_child(casing)
	var tag := Label.new()
	tag.text = "  COMMODITY EXCHANGE  "
	tag.add_theme_font_override("font", GameState.font_label)
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Vox.CREAM)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color("16130f")
	tsb.set_corner_radius_all(3)
	tag.add_theme_stylebox_override("normal", tsb)
	tag.position = Vector2(440, 14)
	casing.add_child(tag)
	var crt := Panel.new()
	crt.position = Vector2(40, 52)
	crt.size = Vector2(980, 500)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color("0d2414")
	csb.set_corner_radius_all(26)
	csb.border_color = Color("2c241c")
	csb.set_border_width_all(10)
	crt.add_theme_stylebox_override("panel", csb)
	casing.add_child(crt)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.position = Vector2(34, 22)
	_text.size = Vector2(912, 460)
	_text.add_theme_font_override("normal_font", GameState.font_crt)
	_text.add_theme_font_size_override("normal_font_size", 31)
	_text.add_theme_color_override("default_color", Vox.PHOS_GREEN)
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


func open(st: Station) -> void:
	station = st
	message = "WELCOME, KESTREL-9."
	qty = 1
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func selected() -> String:
	return GameState.COMMODITY_ORDER[sel]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cancel"):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		sel = posmod(sel - 1, GameState.COMMODITY_ORDER.size())
		qty = 1
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		sel = posmod(sel + 1, GameState.COMMODITY_ORDER.size())
		qty = 1
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		qty = maxi(1, qty - 1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		qty = mini(maxi(1, station.free_pallet_slots().size()), qty + 1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		buy_selected()
	elif event.is_action_pressed("sell"):
		sell_selected()
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()


func buy_selected() -> int:
	var c := selected()
	var m := GameState.market(station.station_id, c)
	var free := station.free_pallet_slots().size()
	if m["buy"] <= 0 or m["stock"] <= 0:
		message = "NOT SOLD HERE."
		return 0
	if free == 0:
		message = "PALLET 07-B IS FULL. LOAD YOUR HOLD FIRST."
		return 0
	var n := GameState.buy(station.station_id, c, mini(qty, free))
	if n == 0:
		message = "INSUFFICIENT CREDITS."
		return 0
	station.spawn_on_pallet(c, n)
	message = "BOUGHT %d CRATE%s. DELIVERED TO PALLET 07-B." % [n, "" if n == 1 else "S"]
	qty = 1
	_refresh()
	return n


func sell_selected() -> int:
	var c := selected()
	var have := station.pallet_count(c)
	if have == 0:
		message = "NO %s ON PALLET 07-B. UNLOAD IT FROM YOUR HOLD FIRST." % GameState.COMMODITIES[c]["short"]
		return 0
	var n := station.take_from_pallet(c, have)
	var earned := GameState.sell(station.station_id, c, n)
	message = "SOLD %d CRATE%s FOR %s CR." % [n, "" if n == 1 else "S", GameState.money(earned)]
	_refresh()
	return earned


func _refresh() -> void:
	if not station:
		return
	var sid := station.station_id
	var t := "> EXCHANGE · %s%sCR %s\n" % [station.display_name.to_upper(), " ".repeat(maxi(1, 33 - station.display_name.length())), GameState.money(GameState.credits)]
	t += "  %-18s%7s%7s%7s%8s\n" % ["GOOD (PER CRATE)", "BUY", "SELL", "STOCK", "ON PAD"]
	t += "------------------------------------------------------\n"
	for i in GameState.COMMODITY_ORDER.size():
		var c: String = GameState.COMMODITY_ORDER[i]
		var m := GameState.market(sid, c)
		var buy := "--" if m["buy"] <= 0 or m["stock"] <= 0 else str(m["buy"])
		var line := "%s %-18s%7s%7s%7s%8s" % ["▶" if i == sel else " ", String(GameState.COMMODITIES[c]["name"]).to_upper(), buy, str(m["sell"]), str(m["stock"]), str(station.pallet_count(c))]
		if i == sel:
			t += "[bgcolor=#8cff9e][color=#0b1f10]%s [/color][/bgcolor]\n" % line
		else:
			t += line + "\n"
	t += "------------------------------------------------------\n"
	var c := selected()
	var m := GameState.market(sid, c)
	var free := station.free_pallet_slots().size()
	t += "QTY [ %02d ]   COST %s CR   PALLET SLOTS FREE %d\n" % [qty, GameState.money(qty * maxi(0, m["buy"])), free]
	var best := GameState.best_elsewhere(sid, c)
	if best["station"] != "":
		t += "BEST KNOWN SELL: %s PAYS %d\n" % [GameState.station_name(best["station"]).to_upper(), best["price"]]
	t += message
	_text.text = t
	var g := GameState.using_gamepad
	_hint.text = ("D-pad select · LB/RB quantity · A buy · X sell all on pad · B close" if g
		else "W/S or arrows select · A/D quantity · F or Enter buy · R sell all on pad · Esc close")
