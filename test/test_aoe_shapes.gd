extends Node

var test_runner = null


func run():
	test("sphere_mesh", func():
		var mesh = AoeShapes.create_sphere(5.0)
		var ok = mesh is SphereMesh
		ok = ok and abs(mesh.radius - 5.0) < 0.001
		ok = ok and abs(mesh.height - 10.0) < 0.001
		return ok
	)

	test("cone_mesh_vertices", func():
		var mesh = AoeShapes.create_cone(10.0, 4.0)
		var arr = mesh.surface_get_arrays(0)
		if arr.is_empty():
			return false
		var verts = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var triangles = verts.size() / 3
		return triangles == 16 * 2
	)

	test("cone_mesh_tip_at_origin", func():
		var mesh = AoeShapes.create_cone(10.0, 4.0)
		var arr = mesh.surface_get_arrays(0)
		var verts = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for i in range(0, verts.size(), 3):
			var v0 = verts[i]
			if abs(v0.x) < 0.001 and abs(v0.y) < 0.001 and abs(v0.z) < 0.001:
				return true
		return false
	)

	test("cone_mesh_base_at_negative_z", func():
		var mesh = AoeShapes.create_cone(10.0, 4.0)
		var arr = mesh.surface_get_arrays(0)
		var verts = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for v in verts:
			if abs(v.z + 10.0) < 0.001:
				return true
		return false
	)

	test("line_mesh_vertices", func():
		var mesh = AoeShapes.create_line(10.0, 2.0)
		var arr = mesh.surface_get_arrays(0)
		if arr.is_empty():
			return false
		var verts = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		return verts.size() > 0
	)

	test("line_mesh_length", func():
		var mesh = AoeShapes.create_line(10.0, 2.0)
		var arr = mesh.surface_get_arrays(0)
		var verts = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var has_front = false
		var has_back = false
		for v in verts:
			if abs(v.z - 5.0) < 0.001:
				has_front = true
			if abs(v.z + 5.0) < 0.001:
				has_back = true
		return has_front and has_back
	)

	test("cube_mesh", func():
		var mesh = AoeShapes.create_cube(4.0)
		var ok = mesh is BoxMesh
		ok = ok and abs(mesh.size.x - 4.0) < 0.001
		ok = ok and abs(mesh.size.y - 4.0) < 0.001
		ok = ok and abs(mesh.size.z - 4.0) < 0.001
		return ok
	)

	test("zero_size_cone", func():
		var mesh = AoeShapes.create_cone(0.0, 0.0)
		var arr = mesh.surface_get_arrays(0)
		return not arr.is_empty()
	)


func test(name: String, fn: Callable):
	var ok = fn.call()
	if test_runner:
		test_runner.report(ok, "  [AoeShapes] " + name)
	else:
		if not ok:
			push_error("FAIL: ", name)
