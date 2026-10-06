extends Control
## Body-first navigation schematic. Directory browsing never changes the flight plan.
## Overview/neighborhood spacing favors readability; route/local retain flight geometry.
const System = preload("res://scripts/longhaul_system.gd")
const GREEN := Color("9fe7b1")
const AMBER := Color("f3d38e")
const DIM := Color("345347")
const TRAIL := Color("65c9b0")
const MODES := ["system", "route", "local"]
var host: Node3D
var map_font: Font
var tint := GREEN
var mode := "system"
var selected_body := -1 # Aurel; 0..7 are moons. Retained when returning to overview.
var centre := Vector3.ZERO
var map_scale := 0.00028
var plot_bounds := Rect2()
var label_boxes: Array[Rect2] = []
var station_label_boxes: Dictionary = {}
var moon_label_boxes: Dictionary = {}
var _route_cache := PackedVector3Array()
var _route_key := ""
var _projection_mode := "system"
var directory_boxes: Array[Rect2] = []
var _schematic_radii: Array[float] = []

func set_mode(value: String) -> bool:
	var wanted := value.strip_edges().to_lower()
	# Old command remains harmless; all browsing views now stay where the pilot puts them.
	if wanted == "auto": wanted = "system"
	if wanted not in MODES: return false
	mode = wanted
	queue_redraw()
	return true

func show_body(value: String) -> bool:
	var wanted := value.strip_edges().to_lower()
	var found := -2
	if wanted == "aurel": found = -1
	for index in System.MOONS.size():
		if wanted == System.MOONS[index].id: found = index
	if found == -2: return false
	selected_body = found
	mode = "body"
	queue_redraw()
	return true

func resolved_mode() -> String:
	return mode

func body_name() -> String:
	return "AUREL" if selected_body < 0 else str(System.MOONS[selected_body].name).to_upper()

func visible_station_ids() -> Array[int]:
	var result: Array[int] = []
	if mode == "system": return result
	if mode == "body":
		for index in System.STATIONS.size():
			if int(System.STATIONS[index].moon) == selected_body: result.append(index)
		result.sort_custom(func(a, b): return System.STATIONS[a].number < System.STATIONS[b].number)
	elif host:
		var state = host.flight
		if mode == "local": result.append(state.reference_station_id())
		else:
			result.append(state.dock_id)
			if (state.nav_selected or not state.plan.is_empty()) and state.destination != state.dock_id:
				result.append(state.destination)
	return result

func snapshot() -> Dictionary:
	return {"mode": mode, "body": selected_body}

static func valid_view(data: Variant) -> bool:
	if not data is Dictionary or data.get("mode", "") not in ["system", "body", "route", "local"]: return false
	var body = data.get("body")
	return (body is int or body is float) and is_finite(float(body)) and body == int(body) and body >= -1 and body < System.MOONS.size()

func restore(data: Dictionary) -> bool:
	if not valid_view(data): return false
	mode = data.mode
	selected_body = int(data.body)
	queue_redraw()
	return true

func point(world: Vector3) -> Vector2:
	var relative := world - centre
	var planar := Vector2(relative.x, relative.z)
	if _projection_mode in ["system", "body"]:
		return plot_bounds.get_center() + planar.normalized() * _schematic_radius(planar.length())
	return plot_bounds.get_center() + planar * map_scale

func _schematic_radius(radius: float) -> float:
	var outer := minf(plot_bounds.size.x, plot_bounds.size.y) * 0.5 - 18
	var inner := 40.0
	if _schematic_radii.is_empty(): return 0.0
	var previous_radius := 0.0
	var previous_pixel := 0.0
	for index in _schematic_radii.size():
		var next_pixel := lerpf(inner, outer, float(index) / maxf(1, _schematic_radii.size() - 1))
		if _schematic_radii.size() == 1: next_pixel = outer * 0.78
		var next_radius := _schematic_radii[index]
		if radius <= next_radius:
			return lerpf(previous_pixel, next_pixel, radius / next_radius if index == 0 else (radius - previous_radius) / (next_radius - previous_radius))
		previous_radius = next_radius
		previous_pixel = next_pixel
	return previous_pixel + (radius - previous_radius) / maxf(previous_radius, 1) * 15.0

func route_vertices() -> PackedVector3Array:
	if not host or host.flight.plan.is_empty():
		_route_key = ""
		_route_cache.clear()
		return _route_cache
	var state = host.flight
	var plan: Dictionary = state.plan
	var key := "%s/%s/%s/%s" % [state.route_serial, plan.get("start", 0), plan.eta, plan.get("points", []).size()]
	if key == _route_key: return _route_cache
	_route_key = key
	_route_cache.clear()
	# The planner supplies the safe transfer, including ring and planet bypasses.
	# Sampling only when the plan changes avoids repeated trajectory solving per frame.
	if plan.has("legs") and state.has_method("route_sample"):
		for sample in 81:
			var when := lerpf(float(plan.get("start", state.elapsed)), float(plan.eta), float(sample) / 80.0)
			var result: Dictionary = state.route_sample(when)
			if result.get("position") is Vector3: _route_cache.append(result.position)
	elif plan.has("path"):
		for item in plan.path:
			if item is Vector3: _route_cache.append(item)
	elif plan.has("points"):
		for item in plan.points:
			if item is Vector3: _route_cache.append(item)
	return _route_cache

func update_projection() -> void:
	if not host: return
	plot_bounds = Rect2(Vector2(12, 30), Vector2(maxf(1, size.x - 24), maxf(1, size.y - 88)))
	var state = host.flight
	var chosen := resolved_mode()
	_projection_mode = chosen
	_schematic_radii.clear()
	if chosen in ["system", "body"]:
		plot_bounds.size.x = size.x * 0.53 - 24
		centre = System.PLANET if chosen == "system" or selected_body < 0 else System.moon_position(selected_body, state.elapsed)
		if chosen == "system":
			for moon in System.MOONS: _schematic_radii.append(float(moon.radius_km) / System.REAL_KM_PER_UNIT)
		else:
			for index in visible_station_ids(): _schematic_radii.append(float(System.STATIONS[index].radius_km) / System.REAL_KM_PER_UNIT)
		_schematic_radii.sort()
		return
	var targets := PackedVector3Array([state.ship_position])
	if chosen == "route":
		for item in route_vertices(): targets.append(item)
		if state.nav_selected or not state.plan.is_empty(): targets.append(System.station_position(state.destination, state.elapsed))
	elif chosen == "local":
		targets.append(System.station_position(state.reference_station_id(), state.elapsed))
	var low := targets[0]
	var high := targets[0]
	for item in targets:
		low = low.min(item)
		high = high.max(item)
	centre = (low + high) * 0.5
	var extent := high - low
	var minimum := 1400.0 if chosen == "local" else 8000.0
	map_scale = minf(maxf(1, plot_bounds.size.x - 82) / maxf(extent.x, minimum), maxf(1, plot_bounds.size.y - 36) / maxf(extent.z, minimum))

func _draw() -> void:
	if not host: return
	if not map_font: map_font = ThemeDB.fallback_font
	update_projection()
	label_boxes.clear()
	station_label_boxes.clear()
	moon_label_boxes.clear()
	directory_boxes.clear()
	var state = host.flight
	var chosen := resolved_mode()
	if chosen in ["system", "body"]:
		_draw_schematic(state, chosen)
		return
	for x in range(0, int(size.x), 64): draw_line(Vector2(x, 20), Vector2(x, size.y - 49), Color("142c23"))
	for y in range(22, int(size.y) - 48, 42): draw_line(Vector2(0, y), Vector2(size.x, y), Color("142c23"))
	draw_line(Vector2(0, size.y - 47), Vector2(size.x, size.y - 47), DIM)
	draw_string(map_font, Vector2(6, 18), "AUREL / " + chosen.to_upper() + " / X-Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GREEN)

	_draw_bodies(state.elapsed, chosen)
	_draw_route(state, chosen)
	# Reserve pilot and target labels before placing the remaining station numbers.
	var here := point(state.ship_position)
	if plot_bounds.has_point(here):
		var heading: Vector3 = -state.attitude.z
		var forward := Vector2(heading.x, heading.z).normalized()
		if forward.length_squared() < 0.1: forward = Vector2.UP
		var right := forward.orthogonal()
		draw_colored_polygon(PackedVector2Array([here + forward * 9, here - forward * 6 + right * 5, here - forward * 3, here - forward * 6 - right * 5]), AMBER)
		_draw_label(here, "LH", AMBER, 21, 12)
	var selected: int = state.destination if state.nav_selected or not state.plan.is_empty() else -1
	for index in visible_station_ids():
		_draw_station(index, state.elapsed, index == selected)
	if chosen != "local":
		for index in System.MOONS.size():
			var moon_point := point(System.moon_position(index, state.elapsed))
			if plot_bounds.has_point(moon_point):
				moon_label_boxes[index] = _draw_label(moon_point, str(System.MOONS[index].name).to_upper(), GREEN.darkened(0.22), 18, 10, false)
	_draw_footer(state, chosen, selected)

func _draw_bodies(when: float, chosen: String) -> void:
	var planet := point(System.PLANET)
	var body_radius := maxf(6, _radius_pixels(System.PLANET_RADIUS, System.PLANET))
	var outer_radius := maxf(body_radius + 5, _radius_pixels(System.RING_OUTER, System.PLANET))
	var inner_radius := maxf(body_radius + 2, _radius_pixels(System.RING_INNER, System.PLANET))
	if plot_bounds.intersects(Rect2(planet - Vector2.ONE * outer_radius, Vector2.ONE * outer_radius * 2)):
		# The footprint warns about the whole ring belt, not just its decorative outline.
		for radius in [inner_radius, (inner_radius + outer_radius) * 0.5, outer_radius]:
			_draw_circle_clipped(planet, radius, Color("665b39"), 1)
		if plot_bounds.has_point(planet) and body_radius < plot_bounds.size.y:
			draw_circle(planet, body_radius, Color("414e38"))
			label_boxes.append(Rect2(planet - Vector2.ONE * body_radius, Vector2.ONE * body_radius * 2))
			_draw_circle_clipped(planet, body_radius, AMBER.darkened(0.25), 1)
			_draw_label(planet, "AUREL", AMBER.darkened(0.1), 20, outer_radius + 5, false)
	for index in System.MOONS.size():
		var moon := point(System.moon_position(index, when))
		if not plot_bounds.has_point(moon): continue
		var radius: float = maxf(3.5, _radius_pixels(float(System.MOONS[index].body_radius_km) / System.REAL_KM_PER_UNIT, System.moon_position(index, when)))
		if radius < plot_bounds.size.y:
			draw_circle(moon, radius, Color("416f59"))
			_draw_circle_clipped(moon, radius, GREEN.darkened(0.15), 1)
	if chosen == "local":
		var reference: int = host.flight.reference_station_id()
		var station := point(System.station_position(reference, when))
		_draw_circle_clipped(station, 1000 * map_scale, Color("2f5743"), 1)
		_draw_circle_clipped(station, 300 * map_scale, Color("41694e"), 1)

func _draw_route(state, chosen: String) -> void:
	if state.trail.size() > 1: _draw_path(PackedVector3Array(state.trail), TRAIL.darkened(0.15), 2)
	if chosen != "local":
		_draw_path(route_vertices(), AMBER, 2, true)
		if state.plan.has("points"):
			for waypoint in state.plan.points:
				var p := point(waypoint)
				if plot_bounds.has_point(p):
					draw_circle(p, 3, AMBER, false, 1)
					if absf(waypoint.y - System.PLANET.y) > 20000:
						_draw_label(p, "%s ORBIT PLANE" % ("ABOVE" if waypoint.y > System.PLANET.y else "BELOW"), AMBER.darkened(0.12), 18, 9, false)
	elif state.nav_selected:
		_draw_segment(point(state.ship_position), point(System.station_position(state.destination, state.elapsed)), AMBER.darkened(0.15), 1, true)

func _draw_station(index: int, when: float, selected: bool) -> void:
	var position := station_point(index, when)
	if not plot_bounds.has_point(position): return
	var color := AMBER if selected else GREEN
	draw_rect(Rect2(position - Vector2(4, 4), Vector2(8, 8)), color, false, 1.5)
	if selected: draw_circle(position, 10, AMBER, false, 1.5)
	var station: Dictionary = System.STATIONS[index]
	var number := "%02d" % int(station.get("number", index + 1))
	station_label_boxes[index] = _draw_label(position, number, color, 23 if size.y > 300 else 21, 12)

func station_point(index: int, when: float) -> Vector2:
	if mode != "body": return point(System.station_position(index, when))
	# Neighborhoods are a directory schematic, never a docking-bearing instrument.
	# Equal spacing prevents clustered inner ports from obscuring one another.
	var stations := visible_station_ids()
	var row := stations.find(index)
	var angle := -PI * 0.5 + TAU * row / maxf(1, stations.size())
	if stations.size() == 1: angle = -PI * 0.25
	return plot_bounds.get_center() + Vector2.from_angle(angle) * minf(plot_bounds.size.x, plot_bounds.size.y) * 0.36

func _draw_footer(state, chosen: String, selected: int) -> void:
	var destination := "SELECT A DESTINATION AT CHART"
	if selected >= 0:
		var station: Dictionary = System.STATIONS[selected]
		destination = "%02d %s" % [int(station.get("number", selected + 1)), str(station.name).to_upper()]
	elif state.phase == "docked":
		var station: Dictionary = System.STATIONS[state.dock_id]
		destination = "%02d %s / BERTH" % [int(station.get("number", state.dock_id + 1)), str(station.name).to_upper()]
	draw_string(map_font, Vector2(6, size.y - 24), destination, HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 22, AMBER)
	var view_note := "LH SHIP / SCHEMATIC ORBIT SPACING / LIVE POSITIONS"
	if chosen == "route": view_note = "AMBER PLANNED / GREEN FLOWN / LIVE EPHEMERIDES"
	if chosen == "local": view_note = "LOCAL RANGE / PAD CAPTURE: RADAR + VELOCITY"
	draw_string(map_font, Vector2(6, size.y - 3), view_note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 140, 18, GREEN.darkened(0.15))
	var division := 64.0 / maxf(map_scale, 0.000001)
	var scale_text := "ORB %.0f km/DIV" % (division * System.REAL_KM_PER_UNIT)
	if chosen == "system": scale_text = "SYMBOLS ENLARGED"
	if chosen == "local": scale_text = "%.0f m/DIV" % division
	draw_string(map_font, Vector2(size.x - 212, size.y - 24), scale_text, HORIZONTAL_ALIGNMENT_RIGHT, 206, 17, GREEN.darkened(0.15))

func _radius_pixels(radius: float, at: Vector3) -> float:
	return point(at + Vector3.RIGHT * radius).distance_to(point(at))

func _draw_schematic(state, chosen: String) -> void:
	var compact := size.y < 300
	var x := size.x * 0.55
	var text_width := size.x - x - 8
	var title := "AUREL / SYSTEM" if chosen == "system" else body_name() + " / STATIONS"
	draw_string(map_font, Vector2(6, 19), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, GREEN)
	draw_line(Vector2(x - 14, 30), Vector2(x - 14, size.y - 58), DIM)
	draw_line(Vector2(0, size.y - 47), Vector2(size.x, size.y - 47), DIM)
	var center := plot_bounds.get_center()
	if chosen == "system":
		for index in System.MOONS.size():
			var moon := point(System.moon_position(index, state.elapsed))
			var selected := index == selected_body
			_draw_circle_clipped(center, _schematic_radius(_schematic_radii[index]), DIM.darkened(0.25), 1)
			draw_circle(moon, 4.5 if selected else 3.5, AMBER if selected else GREEN)
			if selected: draw_circle(moon, 8, AMBER, false, 1)
		_draw_schematic_body(center, true, 13, selected_body == -1)
		var row_height := 19.0 if compact else 30.0
		for row in 9:
			var caption := "AUREL" if row == 0 else str(System.MOONS[row - 1].name).to_upper()
			_directory_row(x, 48 + row * row_height, text_width, caption, selected_body == row - 1, 18 if compact else 27)
		draw_string(map_font, Vector2(6, size.y - 24), "show <name> / OPEN BODY", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, AMBER)
		draw_string(map_font, Vector2(6, size.y - 3), "SCHEMATIC / map route / map local", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GREEN.darkened(0.15))
	else:
		_draw_schematic_body(center, selected_body < 0, 22, true)
		var stations := visible_station_ids()
		var selected: int = state.destination if state.nav_selected or not state.plan.is_empty() else -1
		for index in stations:
			_draw_station(index, state.elapsed, index == selected)
		var row_height := 25.0 if compact else 39.0
		for row in stations.size():
			var index := stations[row]
			var station: Dictionary = System.STATIONS[index]
			var caption := "%02d %s" % [station.number, str(station.name).to_upper()]
			_directory_row(x, 48 + row * row_height, text_width, caption, index == selected, 20 if compact else 25)
		if stations.is_empty():
			draw_string(map_font, Vector2(x, 60), "NO ORBITAL FACILITIES", HORIZONTAL_ALIGNMENT_LEFT, text_width, 23, GREEN)
			draw_string(map_font, Vector2(x, 90), "Moon survey only.", HORIZONTAL_ALIGNMENT_LEFT, text_width, 21, GREEN.darkened(0.2))
		draw_string(map_font, Vector2(6, size.y - 24), "map system / RETURN TO OVERVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, AMBER)
		draw_string(map_font, Vector2(6, size.y - 3), "SCHEMATIC / station <number> / plot <number> direct" if not stations.is_empty() else "SCHEMATIC / show <name> / OPEN ANOTHER BODY", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GREEN.darkened(0.15))

func _draw_schematic_body(at: Vector2, rings: bool, radius: float, selected: bool) -> void:
	var color := AMBER if selected else GREEN
	if rings:
		var ellipse := PackedVector2Array()
		for step in 65:
			var angle := TAU * step / 64.0
			ellipse.append(at + Vector2(cos(angle) * radius * 1.8, sin(angle) * radius * 0.6).rotated(-0.35))
		draw_polyline(ellipse, color.darkened(0.25), 1.5, true)
	draw_circle(at, radius, Color("18362a"))
	draw_circle(at, radius, color, false, 1.5)
	# Reserve the body silhouette before station-number labels are placed.
	label_boxes.append(Rect2(at - Vector2.ONE * (radius + 7), Vector2.ONE * (radius + 7) * 2))

func _directory_row(x: float, baseline: float, width: float, caption: String, selected: bool, font_size: int) -> void:
	var box := Rect2(Vector2(x - 5, baseline - font_size + 2), Vector2(width + 5, font_size + 1))
	directory_boxes.append(box)
	if selected: draw_rect(box, Color("293729"))
	draw_string(map_font, Vector2(x + 4, baseline), ("> " if selected else "  ") + caption, HORIZONTAL_ALIGNMENT_LEFT, width - 6, font_size, AMBER if selected else GREEN)

func _draw_label(anchor: Vector2, caption: String, color: Color, font_size: int, gap: float, required := true) -> Rect2:
	var text_size := map_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var dimensions := Vector2(text_size.x + 6, font_size + 4)
	var offsets: Array[Vector2] = [Vector2(gap, -dimensions.y - 2), Vector2(gap, 4), Vector2(-dimensions.x - gap, -dimensions.y - 2), Vector2(-dimensions.x - gap, 4), Vector2(-dimensions.x * 0.5, -gap - dimensions.y), Vector2(-dimensions.x * 0.5, gap)]
	var available := plot_bounds.grow(5)
	var best := Rect2()
	var best_overlap := INF
	for radius in [0.0, 22.0, 44.0, 70.0, 98.0, 132.0, 168.0]:
		for offset in offsets:
			var candidate := Rect2(anchor + offset + offset.normalized() * radius, dimensions)
			candidate.position.x = clampf(candidate.position.x, available.position.x, available.end.x - dimensions.x)
			candidate.position.y = clampf(candidate.position.y, available.position.y, available.end.y - dimensions.y)
			var overlap := 0.0
			for occupied in label_boxes:
				var intersection := occupied.grow(3).intersection(candidate)
				if intersection.has_area(): overlap += intersection.get_area()
			if overlap < best_overlap:
				best = candidate
				best_overlap = overlap
			if overlap == 0: break
		if best_overlap == 0: break
	if not required and best_overlap > 0: return Rect2()
	label_boxes.append(best)
	var leader := Vector2(clampf(anchor.x, best.position.x, best.end.x), clampf(anchor.y, best.position.y, best.end.y))
	if anchor.distance_to(leader) > gap + 6: draw_line(anchor, leader, color.darkened(0.55), 1)
	draw_rect(best, Color("081a12"))
	draw_string(map_font, best.position + Vector2(3, font_size), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return best

func _draw_path(path: PackedVector3Array, color: Color, width: float, dashed := false) -> void:
	for index in range(1, path.size()):
		_draw_segment(point(path[index - 1]), point(path[index]), color, width, dashed)

func _draw_circle_clipped(at: Vector2, radius: float, color: Color, width: float) -> void:
	var previous := at + Vector2(radius, 0)
	for sample in range(1, 97):
		var next := at + Vector2.from_angle(TAU * float(sample) / 96.0) * radius
		_draw_segment(previous, next, color, width)
		previous = next

func _draw_segment(from: Vector2, to: Vector2, color: Color, width: float, dashed := false) -> void:
	# Liang-Barsky clipping keeps orbital arcs out of the footer and terminal prompt.
	var delta := to - from
	var start := 0.0
	var end := 1.0
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [from.x - plot_bounds.position.x, plot_bounds.end.x - from.x, from.y - plot_bounds.position.y, plot_bounds.end.y - from.y]
	for edge in 4:
		if absf(p[edge]) < 0.000001:
			if q[edge] < 0: return
		else:
			var ratio: float = q[edge] / p[edge]
			if p[edge] < 0: start = maxf(start, ratio)
			else: end = minf(end, ratio)
			if start > end: return
	var a := from + delta * start
	var b := from + delta * end
	if dashed: draw_dashed_line(a, b, color, width, 5)
	else: draw_line(a, b, color, width, true)
