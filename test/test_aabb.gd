extends Node

var test_runner = null

func run():
	# Test the AABB utility logic independently.

	test("single_mesh_aabb", func():
		var root = Node3D.new()
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3(2, 1, 3)
		root.add_child(mesh)
		var aabb = compute_aabb(mesh)
		var ok = aabb.size == Vector3(2, 1, 3)
		root.queue_free()
		return ok
	)

	test("nested_mesh_aabb", func():
		var root = Node3D.new()
		var child = Node3D.new()
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3(1, 1, 1)
		child.add_child(mesh)
		root.add_child(child)
		var aabb = compute_aabb(root)
		var ok = aabb.size == Vector3(1, 1, 1)
		root.queue_free()
		return ok
	)

	test("empty_node_aabb", func():
		var root = Node3D.new()
		var aabb = compute_aabb(root)
		var ok = aabb.size == Vector3.ZERO
		root.queue_free()
		return ok
	)

func compute_aabb(node: Node) -> AABB:
	var aabb = AABB()
	if node is MeshInstance3D:
		aabb = node.get_aabb()
	for child in node.get_children():
		var child_aabb = compute_aabb(child)
		if aabb.size == Vector3.ZERO:
			aabb = child_aabb
		elif child_aabb.size != Vector3.ZERO:
			aabb = aabb.merge(child_aabb)
	return aabb

func test(name: String, fn: Callable):
	var ok = fn.call()
	if test_runner:
		test_runner.report(ok, "  [AABB] " + name)
	else:
		if not ok:
			push_error("FAIL: ", name)