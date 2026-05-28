extends Node

static func compute(node: Node) -> AABB:
	var aabb = AABB()
	if node is MeshInstance3D:
		aabb = node.get_aabb()
	for child in node.get_children():
		var child_aabb = compute(child)
		if aabb.size == Vector3.ZERO:
			aabb = child_aabb
		elif child_aabb.size != Vector3.ZERO:
			aabb = aabb.merge(child_aabb)
	return aabb
