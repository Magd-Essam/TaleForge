extends Node

var test_runner = null

var _last_pass = true

func run():
	# These tests mirror the segment_intersects logic from fog_of_war.gd
	# and are pure math — no scene dependencies.

	# Crossing segments
	test("crossing_segments", func():
		return segments_intersect(
			Vector2(0, 0), Vector2(2, 2),
			Vector2(0, 2), Vector2(2, 0)
		)
	)

	# Parallel segments (no intersection)
	test("parallel_segments", func():
		return not segments_intersect(
			Vector2(0, 0), Vector2(2, 0),
			Vector2(0, 1), Vector2(2, 1)
		)
	)

	# Colinear segments (denom ~ 0)
	test("colinear_segments", func():
		return not segments_intersect(
			Vector2(0, 0), Vector2(3, 0),
			Vector2(1, 0), Vector2(2, 0)
		)
	)

	# T-junction — one end touches the middle of another
	test("t_junction", func():
		return segments_intersect(
			Vector2(1, 0), Vector2(1, 2),
			Vector2(0, 1), Vector2(2, 1)
		)
	)

	# Disjoint segments
	test("disjoint_segments", func():
		return not segments_intersect(
			Vector2(0, 0), Vector2(1, 1),
			Vector2(3, 3), Vector2(4, 4)
		)
	)

	# Touch at endpoints
	test("endpoint_touch", func():
		return segments_intersect(
			Vector2(0, 0), Vector2(1, 0),
			Vector2(1, 0), Vector2(1, 1)
		)
	)

func segments_intersect(p: Vector2, q: Vector2, a: Vector2, b: Vector2) -> bool:
	var r = q - p
	var s = b - a
	var denom = r.x * s.y - r.y * s.x
	if abs(denom) < 0.0001:
		return false
	var t = ((a.x - p.x) * s.y - (a.y - p.y) * s.x) / denom
	var u = ((a.x - p.x) * r.y - (a.y - p.y) * r.x) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func test(name: String, fn: Callable):
	var ok = fn.call()
	if test_runner:
		test_runner.report(ok, "  [Segments] " + name)
	else:
		if not ok:
			push_error("FAIL: ", name)