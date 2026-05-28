extends Node

var test_runner = null

func run():
	# This tests the world_to_cell math independently.
	# The real function uses grid properties; here we duplicate the logic.

	var grid_size = 20
	var cell_size = 1.0

	test("center_origin", func():
		# At origin (0,0), cell should be center (10, 10)
		var cell = world_to_cell(0, 0, grid_size, cell_size)
		return cell == Vector2(10, 10)
	)

	test("negative_quadrant", func():
		var half = (grid_size * cell_size) / 2.0
		var cell = world_to_cell(-half + 0.1, -half + 0.1, grid_size, cell_size)
		return cell == Vector2(0, 0)
	)

	test("positive_quadrant", func():
		var half = (grid_size * cell_size) / 2.0
		var cell = world_to_cell(half - 0.1, half - 0.1, grid_size, cell_size)
		return cell == Vector2(grid_size - 1, grid_size - 1)
	)

	test("clamp_negative", func():
		var cell = world_to_cell(-999, -999, grid_size, cell_size)
		return cell == Vector2(0, 0)
	)

	test("clamp_positive", func():
		var cell = world_to_cell(999, 999, grid_size, cell_size)
		return cell == Vector2(grid_size - 1, grid_size - 1)
	)

	test("different_cell_size", func():
		var grid_size2 = 10
		var cell_size2 = 2.0
		var cell = world_to_cell(0, 0, grid_size2, cell_size2)
		return cell == Vector2(5, 5)
	)

	test("get_closest_edge_north", func():
		var edge = get_closest_edge(0, -4, Vector2(10, 10), 20, 1.0)
		return edge == "N"
	)

	test("get_closest_edge_south", func():
		var edge = get_closest_edge(0, 4, Vector2(10, 10), 20, 1.0)
		return edge == "S"
	)

	test("get_closest_edge_east", func():
		var edge = get_closest_edge(4, 0, Vector2(10, 10), 20, 1.0)
		return edge == "E"
	)

	test("get_closest_edge_west", func():
		var edge = get_closest_edge(-4, 0, Vector2(10, 10), 20, 1.0)
		return edge == "W"
	)

func world_to_cell(world_x: float, world_z: float, grid_size: int, cell_size: float) -> Vector2:
	var half = (grid_size * cell_size) / 2.0
	var cx = floor((world_x + half) / cell_size)
	var cz = floor((world_z + half) / cell_size)
	cx = clamp(cx, 0, grid_size - 1)
	cz = clamp(cz, 0, grid_size - 1)
	return Vector2(cx, cz)

func get_closest_edge(world_x: float, world_z: float, cell_pos: Vector2, grid_size: int, cell_size: float) -> String:
	var half = (grid_size * cell_size) / 2.0
	var cx = (cell_pos.x * cell_size) - half + cell_size / 2.0
	var cz = (cell_pos.y * cell_size) - half + cell_size / 2.0
	var dist_n = abs(world_z - (cz - cell_size / 2.0))
	var dist_s = abs(world_z - (cz + cell_size / 2.0))
	var dist_e = abs(world_x - (cx + cell_size / 2.0))
	var dist_w = abs(world_x - (cx - cell_size / 2.0))
	var min_d = min(dist_n, min(dist_s, min(dist_e, dist_w)))
	if min_d == dist_n: return "N"
	if min_d == dist_s: return "S"
	if min_d == dist_e: return "E"
	return "W"

func test(name: String, fn: Callable):
	var ok = fn.call()
	if test_runner:
		test_runner.report(ok, "  [Coords] " + name)
	else:
		if not ok:
			push_error("FAIL: ", name)