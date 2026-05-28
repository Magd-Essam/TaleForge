extends RefCounted
class_name AoeShapes


static func create_sphere(radius: float) -> SphereMesh:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


static func create_cone(length: float, width: float) -> ArrayMesh:
	var radius = width * 0.5
	var segments = 16
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0, 0))

	var tip = Vector3(0, 0, 0)
	var base_center = Vector3(0, 0, -length)

	for i in range(segments):
		var a1 = 2.0 * PI * i / segments
		var a2 = 2.0 * PI * (i + 1) / segments
		var p1 = base_center + Vector3(cos(a1) * radius, sin(a1) * radius, 0)
		var p2 = base_center + Vector3(cos(a2) * radius, sin(a2) * radius, 0)

		var n = (p1 - tip).cross(p2 - tip).normalized()
		st.set_normal(n)
		st.add_vertex(tip)
		st.add_vertex(p1)
		st.add_vertex(p2)

		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(base_center)
		st.add_vertex(p2)
		st.add_vertex(p1)

	return st.commit()


static func create_line(length: float, width: float) -> ArrayMesh:
	var radius = width * 0.5
	var segments = 16
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0, 0))

	var hl = length * 0.5
	var front = Vector3(0, 0, hl)
	var back = Vector3(0, 0, -hl)

	for i in range(segments):
		var a1 = 2.0 * PI * i / segments
		var a2 = 2.0 * PI * (i + 1) / segments
		var c1 = Vector3(cos(a1) * radius, sin(a1) * radius, 0)
		var c2 = Vector3(cos(a2) * radius, sin(a2) * radius, 0)
		var pf1 = front + c1
		var pf2 = front + c2
		var pb1 = back + c1
		var pb2 = back + c2
		var n1 = Vector3(cos(a1), sin(a1), 0)
		var n2 = Vector3(cos(a2), sin(a2), 0)

		st.set_normal(n1)
		st.add_vertex(pf1)
		st.set_normal(n2)
		st.add_vertex(pf2)
		st.set_normal(n2)
		st.add_vertex(pb2)

		st.set_normal(n1)
		st.add_vertex(pf1)
		st.set_normal(n2)
		st.add_vertex(pb2)
		st.set_normal(n1)
		st.add_vertex(pb1)

		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(front)
		st.add_vertex(pf2)
		st.add_vertex(pf1)

		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(back)
		st.add_vertex(pb1)
		st.add_vertex(pb2)

	return st.commit()


static func create_cube(side: float) -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(side, side, side)
	return mesh
