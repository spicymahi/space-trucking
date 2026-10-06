extends Control
## Live ephemerides on a readable orthographic cassette-era traffic chart.
## System view compresses orbital spacing; route and local views are orthographic.
const System = preload("res://scripts/longhaul_system.gd")
const GREEN := Color("9fe7b1")
const AMBER := Color("f3d38e")
const DIM := Color("345347")
const TRAIL := Color("65c9b0")
const MODES := ["auto", "system", "route", "local"]
var host: Node3D
var map_font: Font
var tint := GREEN
var mode := "auto"
var centre := Vector3.ZERO
var map_scale := 0.00028
var plot_bounds := Rect2()
var label_boxes: Array[Rect2] = []
var station_label_boxes: Dictionary = {}
var moon_label_boxes: Dictionary = {}
var _orbit_paths: Array[PackedVector3Array] = []
var _route_cache := PackedVector3Array()
var _route_key := ""
var _projection_mode := "system"

func set_mode(value: String) -> bool:
	var wanted := value.strip_edges().to_lower()
	if wanted not in MODES: return false
	mode = wanted
	queue_redraw()
	return true

func resolved_mode() -> String:
	if mode != "auto": return mode
	if not host: return "system"
	var state = host.flight
	if state.phase == "docked" or state.plan.is_empty(): return "system"
	if state.nav_selected and state.phase in ["brake", "approach"] and state.station_range() < 12000:
		return "local"
	return "route"

func point(world: Vector3) -> Vector2:
	var relative := world - centre
	var planar := Vector2(relative.x, relative.z)
	if _projection_mode == "system": planar = planar.normalized() * sqrt(planar.length())
	return plot_bounds.get_center() + planar * map_scale

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

func _prepare_orbits() -> void:
	if not _orbit_paths.is_empty(): return
	for index in System.MOONS.size():
		var radius: float = System.MOONS[index].radius_km / System.REAL_KM_PER_UNIT
		var period := TAU * sqrt(pow(radius, 3) / System.MU)
		var path := PackedVector3Array()
		for sample in 97: path.append(System.moon_position(index, period * float(sample) / 96.0))
		_orbit_paths.append(path)

func update_projection() -> void:
	if not host: return
	_prepare_orbits()
	plot_bounds = Rect2(Vector2(12, 24), Vector2(maxf(1, size.x - 24), maxf(1, size.y - 78)))
	var state = host.flight
	var chosen := resolved_mode()
	_projection_mode = chosen
	if chosen == "system": plot_bounds.size.x = size.x * 0.53 - 24
	var targets := PackedVector3Array([state.ship_position])
	if chosen == "system":
		targets.append(System.PLANET)
		for path in _orbit_paths:
			for item in path: targets.append(item)
		for index in System.STATIONS.size(): targets.append(System.station_position(index, state.elapsed))
	elif chosen == "route":
		for item in route_vertices(): targets.append(item)
		if state.nav_selected or not state.plan.is_empty(): targets.append(System.station_position(state.destination, state.elapsed))
	elif chosen == "local":
		targets.append(System.station_position(state.reference_station_id(), state.elapsed))
	var low := targets[0]
	var high := targets[0]
	for item in targets:
		low = low.min(item)
		high = high.max(item)
	if chosen == "system":
		centre = System.PLANET
		var largest := 1.0
		for target in targets:
			var relative := target - centre
			largest = maxf(largest, Vector2(relative.x, relative.z).length())
		map_scale = minf(plot_bounds.size.x - 64, plot_bounds.size.y - 24) * 0.5 / sqrt(largest)
		return
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
	var state = host.flight
	var chosen := resolved_mode()
	for x in range(0, int(size.x), 64): draw_line(Vector2(x, 20), Vector2(x, size.y - 49), Color("142c23"))
	for y in range(22, int(size.y) - 48, 42): draw_line(Vector2(0, y), Vector2(size.x, y), Color("142c23"))
	draw_line(Vector2(0, size.y - 47), Vector2(size.x, size.y - 47), DIM)
	draw_string(map_font, Vector2(6, 18), "AUREL / " + chosen.to_upper() + " / X-Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GREEN)
	draw_string(map_font, Vector2(size.x - 259, 18), "8 MOONS  /  15 STATIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM.lightened(0.2))
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
	if selected >= 0: _draw_station(selected, state.elapsed, true)
	for index in System.STATIONS.size():
		if index != selected: _draw_station(index, state.elapsed, false)
	if chosen != "local":
		for index in System.MOONS.size():
			var moon_point := point(System.moon_position(index, state.elapsed))
			if plot_bounds.has_point(moon_point):
				moon_label_boxes[index] = _draw_label(moon_point, str(System.MOONS[index].name).to_upper(), GREEN.darkened(0.22), 18, 10, false)
	if chosen == "system": _draw_directory(selected, state.dock_id if state.phase == "docked" else -1)
	_draw_footer(state, chosen, selected)

func _draw_bodies(when: float, chosen: String) -> void:
	for path in _orbit_paths: _draw_path(path, Color("243e32"), 1)
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
	var position := point(System.station_position(index, when))
	if not plot_bounds.has_point(position): return
	var color := AMBER if selected else GREEN
	draw_rect(Rect2(position - Vector2(4, 4), Vector2(8, 8)), color, false, 1.5)
	if selected: draw_circle(position, 10, AMBER, false, 1.5)
	var station: Dictionary = System.STATIONS[index]
	var number := "%02d" % int(station.get("number", index + 1))
	station_label_boxes[index] = _draw_label(position, number, color, 23 if size.y > 300 else 21, 12)

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

func _draw_directory(selected: int, docked: int) -> void:
	var start_x := size.x * 0.55
	var compact := size.y < 300
	var columns := 2 if compact else 1
	var per_column := 8 if compact else 15
	var spacing := 23 if compact else 20
	var font_size := 19 if compact else 22
	var column_width := (size.x - start_x - 8) / columns
	var sorted := System.STATIONS.duplicate()
	sorted.sort_custom(func(a, b): return a.number < b.number)
	for row in sorted.size():
		var station: Dictionary = sorted[row]
		var column := int(row / per_column)
		var y := 45 + (row % per_column) * spacing
		var x := start_x + column * column_width
		var index := System.IDS.find(station.id)
		var color := AMBER if index == selected else GREEN
		if index == docked and selected < 0: color = AMBER
		var caption := "%02d %s" % [station.number, str(station.name).to_upper()]
		draw_string(map_font, Vector2(x, y), caption, HORIZONTAL_ALIGNMENT_LEFT, column_width - 6, font_size, color)

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
