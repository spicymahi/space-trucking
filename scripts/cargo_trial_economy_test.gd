extends SceneTree
const Economy = preload("res://scripts/cargo_trial_economy.gd")
const System = preload("res://scripts/longhaul_system.gd")
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		printerr("CARGO ECONOMY FAIL: ", label)

func run() -> void:
	var e = Economy.new()
	e.setup()
	var mirror = Economy.new()
	mirror.setup()
	check(e.stations == mirror.stations, "seed reproduces initial economy")
	check(e.stations.size() == System.STATIONS.size(), "all fifteen authored stations participate")
	var offers: Array = e.offers()
	check(offers.size() == 3, "Ceres offers short, full and collection work")
	check(offers == e.offers(), "board quotes stable until economy changes")
	check(offers[0].kind == "outbound" and offers[0].units == 24, "small outbound uses half the hold")
	check(offers[1].full and offers[1].units == 48, "full outbound uses the complete hold")
	check(offers[2].kind == "collection", "collection work appears with outbound work")
	for employer in System.STATIONS.size():
		var board: Array = e.offers(employer)
		check(not board.is_empty() and board.size() <= 3, "bounded jobs for "+System.NAMES[employer])
		for offer in board:
			check(offer.source != offer.destination, "job moves goods between distinct stations")
			check(e.stations[offer.source].supply.get(offer.commodity, 0) >= offer.units, "quoted freight exists")
			check(e.stations[offer.destination].demand.get(offer.commodity, 0) >= offer.units, "quoted destination needs freight")
			check(offer.payout > offer.fuel_cost and offer.employer_margin > 0, "profitable player and employer match")
			check(offer.payout == offer.advance+offer.remaining_pay, "payment split adds up")
			check(offer.payout == offer.fuel_cost+offer.time_pay+offer.handling_pay+offer.upkeep+offer.profit, "all work and expenses priced")
			for leg in offer.legs:
				check(leg.minutes <= 30.0 and leg.minutes > 0.0, "each quoted leg fits journey limit")
	var foreign: Dictionary = e.offers(1)[0]
	check(e.accept(foreign.id).is_empty(), "cannot accept remote employer board")
	var outbound: Dictionary = offers[1]
	var initial_stock: float = e.stations[outbound.source].supply[outbound.commodity]
	var initial_demand: float = e.stations[outbound.destination].demand[outbound.commodity]
	var accepted: Dictionary = e.accept(outbound.id)
	check(not accepted.is_empty(), "accept outbound")
	check(e.credits == 600+int(outbound.advance), "fuel advance credited once")
	check(e.stations[outbound.source].supply[outbound.commodity] == initial_stock-outbound.units, "accepted freight reserved at source")
	check(e.stations[outbound.destination].demand[outbound.commodity] == initial_demand-outbound.units, "destination need reserved")
	check(e.stations[outbound.destination].reserved_inbound[outbound.commodity] == outbound.units, "inbound capacity reserved")
	check(e.accept(outbound.id).is_empty() and e.credits == 600+int(outbound.advance), "cannot double accept or claim second advance")
	check(e.offers().is_empty(), "one active contract at a time")
	accepted.payout = -1000
	check(e.active.payout == outbound.payout, "returned contract cannot mutate authoritative quote")
	e.tick(120.0)
	check(e.active.payout == outbound.payout and e.active.phase == "loading", "no deadline or price changes after long wait")
	check(e.stations[outbound.destination].reserved_inbound[outbound.commodity] == outbound.units, "background trade cannot steal inbound reservation")
	check(e.stations[outbound.destination].demand[outbound.commodity]+outbound.units <= Economy.MAX_DEMAND, "demand respects reserved capacity")
	check(not e.travel_to(outbound.destination), "loaded/secured gate required before travel")
	e.active.box_count = 13
	check(e.mark_collected(), "mark collected at source")
	check(e.active.box_count == 13, "mark collected preserves registered manifest count")
	check(not e.mark_collected(), "cannot collect twice")
	check(not e.travel_to(outbound.source), "wrong next station refused")
	check(e.travel_to(outbound.destination), "quoted outbound leg can be paid with advance")
	check(e.credits == 600 and e.active.fuel_spent == outbound.fuel_cost, "advance exactly pays quoted fuel")
	check(not e.travel_to(outbound.destination), "travel fuel cannot charge twice")
	check(not e.complete(12, 13, outbound.destination), "incomplete consignment not paid")
	check(not e.complete(13, 13, outbound.source), "wrong unloading station not paid")
	check(not e.complete(1, 1, outbound.destination), "forged reduced manifest not paid")
	check(not e.complete(0, 0, outbound.destination), "empty delivery not paid")
	check(e.complete(13, 13, outbound.destination), "full unloaded manifest settles once")
	check(e.credits == 600+int(outbound.remaining_pay), "full job leaves positive net earnings")
	check(e.stations[outbound.destination].reserved_inbound[outbound.commodity] == 0, "delivery releases reserved destination capacity")
	check(e.stations[outbound.destination].fulfilled[outbound.commodity] == outbound.units, "delivery fulfills station commodity need")
	var paid_credits: int = e.credits
	check(not e.complete(13, 13, outbound.destination) and e.credits == paid_credits, "repeated completion cannot mint payment")
	check(e.receipts.size() == 1, "one delivery receipt retained")
	check(not e.offers(e.station).is_empty(), "new contracts offered at arrival station")
	check_collection()
	check_refresh_and_tick()
	print("CARGO ECONOMY CHECKS ",passed," passed / ",failed," failed")
	quit(0 if failed == 0 else 1)

func check_collection() -> void:
	var e = Economy.new()
	e.setup(717)
	var collection: Dictionary = e.offers()[2]
	check(collection.legs.size() == 2, "collection quote covers empty and loaded legs")
	check(collection.fuel_cost == collection.legs[0].fuel_cost+collection.legs[1].fuel_cost, "both legs funded in advance")
	e.credits = 0
	check(not e.accept(collection.id).is_empty(), "player with no money can accept financed job")
	check(e.leg_destination() == collection.source, "collection first leg is pickup station")
	check(not e.mark_collected(), "cannot collect while still at employer station")
	check(not e.travel_to(collection.destination), "cannot skip collection trip")
	check(e.travel_to(collection.source), "advance pays empty outbound leg")
	check(e.active.phase == "loading" and e.station == collection.source, "collection cargo loaded at source")
	check(not e.complete(8, 8, collection.source), "pickup is not delivery")
	check(e.mark_collected(8), "register collection manifest")
	check(e.leg_destination() == collection.employer, "loaded return leg heads to employer")
	check(e.travel_to(collection.destination), "remaining advance pays loaded return")
	check(e.credits == 0 and e.active.fuel_spent == collection.fuel_cost, "zero starting balance never goes negative")
	check(e.complete(8, 8, collection.destination), "collection settled on return")
	check(e.credits == collection.remaining_pay and e.credits > 0, "collection earns money after both legs")

func check_refresh_and_tick() -> void:
	var e = Economy.new()
	e.setup()
	var stale: Dictionary = e.offers()[0]
	var before: Array = e.stations.duplicate(true)
	e.tick(1.0)
	check(before != e.stations, "production consumption and trade change economy")
	check(e.accept(stale.id).is_empty(), "unaccepted stale quote requires refresh")
	check(not e.offers().is_empty(), "current economic matches regenerate")
	e.tick(100000.0)
	for state in e.stations:
		for commodity in state.supply:
			check(state.supply[commodity] >= 0.0 and state.supply[commodity] <= Economy.MAX_STOCK, "stock stays bounded")
		for commodity in state.demand:
			check(state.demand[commodity] >= 0.0 and state.demand[commodity] <= Economy.MAX_DEMAND, "demand stays bounded")
	var time_before: float = e.elapsed_hours
	e.tick(-1.0)
	e.tick(INF)
	check(e.elapsed_hours == time_before, "invalid time cannot corrupt economy")
