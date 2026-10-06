extends RefCounted
## Navigation chart contracts: catalogue visibility, view selection and exact route geometry.
const Map = preload("res://scripts/longhaul_route_map.gd")
const State = preload("res://scripts/longhaul_flight_state.gd")
const System = preload("res://scripts/longhaul_system.gd")
class ChartHost extends Node3D:
	var flight = State.new()
var passed := 0
var failed := 0

func check(value: bool, description: String) -> void:
	if value: passed += 1
	else: failed += 1
	print("SYSTEM MAP ", description, ": ", value)

func run(_host = null) -> bool:
	var ship := ChartHost.new()
	var map := Map.new()
	map.host = ship
	map.size = Vector2(792, 405)
	check(map.resolved_mode() == "system", "Unplanned departure starts with the whole system")
	var visible := true
	for dimensions in [Vector2(792, 405), Vector2(770, 275)]:
		map.size = dimensions
		for when in [0.0, 10000.0, 100000.0]:
			ship.flight.elapsed = when
			ship.flight.ship_position = System.station_position(0, when)
			map.update_projection()
			visible = visible and map.plot_bounds.has_point(map.point(System.PLANET))
			for index in System.MOONS.size():
				visible = visible and map.plot_bounds.has_point(map.point(System.moon_position(index, when)))
			for index in System.STATIONS.size():
				visible = visible and map.plot_bounds.has_point(map.point(System.station_position(index, when)))
	check(visible, "All eight moons, fifteen stations and Aurel stay visible at both CRT sizes as orbits advance")
	check(map.set_mode("route") and not map.set_mode("nonsense") and map.mode == "route", "Invalid map view preserves the previous valid mode")
	ship.flight = State.new()
	ship.flight.plan_route("beacon")
	var vertices := map.route_vertices()
	var sampled: bool = vertices.size() == 81 and not ship.flight.plan.is_empty()
	if sampled:
		for index in vertices.size():
			var when := lerpf(float(ship.flight.plan.start), float(ship.flight.plan.eta), float(index) / 80.0)
			sampled = sampled and vertices[index].is_equal_approx(ship.flight.route_sample(when).position)
	check(sampled, "Displayed transfer samples the actual flight plan rather than a direct line through bodies")
	map.update_projection()
	var route_visible := true
	for vertex in vertices: route_visible = route_visible and map.plot_bounds.has_point(map.point(vertex))
	check(route_visible, "The entire planned transfer fits route view")
	var first_endpoint := vertices[-1] if not vertices.is_empty() else Vector3.ZERO
	ship.flight.plan_route("rime")
	vertices = map.route_vertices()
	check(not vertices.is_empty() and not vertices[-1].is_equal_approx(first_endpoint) and vertices[-1].is_equal_approx(ship.flight.plan.target), "Changing destination invalidates the route cache")
	map.set_mode("auto")
	ship.flight.phase = "coast"
	ship.flight.nav_selected = true
	check(map.resolved_mode() == "route", "Active transfer automatically follows route view")
	ship.flight.phase = "approach"
	ship.flight.ship_position = ship.flight.station_position(ship.flight.destination, ship.flight.elapsed) + Vector3(0, 0, -600)
	check(map.resolved_mode() == "local", "Arrival automatically switches to local docking scale")
	map.update_projection()
	check(map.plot_bounds.has_point(map.point(ship.flight.ship_position)) and map.plot_bounds.has_point(map.point(ship.flight.station_position(ship.flight.destination, ship.flight.elapsed))), "Local view contains both ship and destination")
	map.set_mode("system")
	check(map.resolved_mode() == "system", "Explicit system command remains available during approach")
	ship.flight.plan.clear()
	check(map.route_vertices().is_empty(), "Cleared plan removes old transfer line")
	map.free()
	ship.free()
	print("LONGHAUL SYSTEM MAP ", passed, " passed / ", failed, " failed")
	return failed == 0
