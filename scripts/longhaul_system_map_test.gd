extends RefCounted
## Browse the same catalogue through the physical CLI without changing navigation.
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

func run(host = null) -> bool:
	var ship := ChartHost.new()
	var map := Map.new()
	map.host = ship
	map.size = Vector2(792, 405)
	check(map.resolved_mode() == "system" and map.visible_station_ids().is_empty(), "Default overview contains no station markers or station directory")
	var visible := true
	for dimensions in [Vector2(792, 405), Vector2(770, 275)]:
		map.size = dimensions
		for when in [0.0, 10000.0, 100000.0]:
			ship.flight.elapsed = when
			map.update_projection()
			visible = visible and map.plot_bounds.has_point(map.point(System.PLANET))
			for index in System.MOONS.size():
				visible = visible and map.plot_bounds.has_point(map.point(System.moon_position(index, when)))
	check(visible, "Aurel and all eight moons stay inside the schematic as orbits advance")
	check(map.show_body("AUREL") and map.visible_station_ids() == [0, 1, 2, 4, 3, 13, 14], "Aurel includes every direct-orbit station, including all distant ports")
	var seen: Array[int] = map.visible_station_ids()
	var body_queries := true
	for index in System.MOONS.size():
		body_queries = map.show_body(System.MOONS[index].id) and map.selected_body == index and body_queries
		for station in map.visible_station_ids():
			body_queries = body_queries and int(System.STATIONS[station].moon) == index and station not in seen
			seen.append(station)
	check(body_queries and seen.size() == 15, "Body browsing partitions all fifteen stations exactly once under the correct parent")
	map.show_body("hush")
	check(map.visible_station_ids().is_empty(), "Hush has no orbital facilities")
	map.show_body("veil")
	check(map.visible_station_ids().is_empty(), "Veil has no orbital facilities")
	map.show_body("brume")
	var selected := map.snapshot()
	check(not map.show_body("outer") and not map.show_body("brum") and map.snapshot() == selected, "Unknown body and removed outer category preserve the selected neighborhood")
	ship.flight.plan_route("beacon")
	ship.flight.nav_selected = true
	ship.flight.phase = "coast"
	check(map.resolved_mode() == "body" and map.selected_body == 2, "Planning and entering cruise cannot switch away from the chosen moon")
	map.set_mode("system")
	ship.flight.phase = "approach"
	check(map.resolved_mode() == "system" and map.selected_body == 2 and map.visible_station_ids().is_empty(), "Return keeps the moon highlight and remains uncluttered during arrival")
	check(map.set_mode("route") and not map.set_mode("nonsense") and map.mode == "route", "Invalid map view preserves the previous valid mode")
	var vertices := map.route_vertices()
	var sampled: bool = vertices.size() == 81 and not ship.flight.plan.is_empty()
	if sampled:
		for index in vertices.size():
			var when := lerpf(float(ship.flight.plan.start), float(ship.flight.plan.eta), float(index) / 80.0)
			sampled = sampled and vertices[index].is_equal_approx(ship.flight.route_sample(when).position)
	check(sampled, "Journey view still samples the actual flight plan")
	map.update_projection()
	var route_visible := true
	for vertex in vertices: route_visible = route_visible and map.plot_bounds.has_point(map.point(vertex))
	check(route_visible, "The entire planned transfer fits journey view")
	check(map.visible_station_ids() == [0, 14], "Journey view includes only departure and destination stations")
	var first_endpoint := vertices[-1] if not vertices.is_empty() else Vector3.ZERO
	ship.flight.phase = "docked"
	ship.flight.plan_route("rime")
	vertices = map.route_vertices()
	check(not vertices.is_empty() and not vertices[-1].is_equal_approx(first_endpoint) and vertices[-1].is_equal_approx(ship.flight.plan.target), "Changing destination invalidates the route cache")
	ship.flight.phase = "approach"
	ship.flight.nav_selected = true
	ship.flight.ship_position = ship.flight.station_position(ship.flight.destination, ship.flight.elapsed) + Vector3(0, 0, -600)
	check(map.resolved_mode() == "route", "Approaching a station leaves a manually chosen route view selected")
	map.set_mode("local")
	map.update_projection()
	check(map.visible_station_ids() == [ship.flight.destination] and map.plot_bounds.has_point(map.point(ship.flight.ship_position)) and map.plot_bounds.has_point(map.point(ship.flight.station_position(ship.flight.destination, ship.flight.elapsed))), "Explicit local view isolates the target station and includes the ship")
	map.show_body("slate")
	var saved = JSON.parse_string(JSON.stringify(map.snapshot()))
	map.set_mode("system")
	check(map.restore(saved) and map.mode == "body" and map.selected_body == 1, "View and selected body survive JSON serialization")
	var restored_view := map.snapshot()
	check(not map.restore({"mode":"body","body":99}) and map.snapshot() == restored_view and not Map.valid_view({"mode":"body","body":1.5}), "Invalid view data cannot change the current selection")
	ship.flight.plan.clear()
	check(map.route_vertices().is_empty(), "Cleared plan removes old transfer line")
	if host: _check_terminal(host)
	map.free()
	ship.free()
	print("LONGHAUL SYSTEM MAP ", passed, " passed / ", failed, " failed")
	return failed == 0

func _check_terminal(host) -> void:
	var original_state = host.flight
	var original_roles: Array[String] = []
	var original_views: Array = []
	for item in host.terminals:
		original_roles.append(item.kind)
		original_views.append(item.chart_map.snapshot() if item.chart_map else null)
	host.flight = State.new()
	host.close_terminal()
	var terminal = host.terminals[0]
	terminal.set_role("chart")
	host.open_terminal(terminal)
	terminal.submit("show brume")
	check(terminal.show_live and terminal.chart_map.visible and terminal.chart_map.selected_body == 2 and terminal.chart_map.visible_station_ids() == [9], "CHART show brume opens only Brume Gardens")
	terminal.submit("show brum")
	check(terminal.readout.text.contains("View preserved") and terminal.chart_map.selected_body == 2, "CLI typo explains valid commands without selecting another body")
	host.close_terminal()
	host.open_terminal(terminal)
	check(terminal.chart_map.visible and terminal.chart_map.mode == "body" and terminal.chart_map.selected_body == 2, "Leaving and reopening the terminal keeps the chosen moon")
	terminal.submit("map system")
	check(terminal.chart_map.mode == "system" and terminal.chart_map.selected_body == 2 and terminal.chart_map.size == Vector2(792,405), "Overview remembers the selected body and uses the full readable display")
	terminal.set_role("map")
	terminal.submit("show aurel")
	check(terminal.chart_map.visible_station_ids().size() == 7 and not host.flight.nav_selected and host.flight.plan.is_empty(), "MAP show aurel browses the planet without selecting the Aurel Fuel destination")
	terminal.submit("station 15")
	check(terminal.readout.text.contains("Beacon Nine"), "Station details work directly from a MAP terminal")
	terminal.submit("plot 15 direct")
	check(host.flight.destination == 14 and not host.flight.plan.is_empty() and terminal.chart_map.selected_body == -1, "MAP accepts listed station numbers for route planning without switching views")
	terminal.submit("show slate")
	var file_path := "/tmp/longhaul-map-view-test.json"
	check(host.save_session(file_path).contains("saved"), "Full flight session saves selected map neighborhoods")
	terminal.submit("show brume")
	var loaded: String = host.load_session(file_path)
	check(loaded.contains("restored") and terminal.chart_map.mode == "body" and terminal.chart_map.selected_body == 1, "Full-session reload restores the selected neighborhood")
	host.close_terminal()
	host.flight = original_state
	for index in host.terminals.size():
		host.terminals[index].set_role(original_roles[index])
		if original_views[index] != null: host.terminals[index].restore_map_view(original_views[index])
		elif host.terminals[index].chart_map: host.terminals[index].chart_map.restore({"mode":"system","body":-1})
