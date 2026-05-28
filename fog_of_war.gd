extends Node3D

var is_gm_mode = false
var fog_plane : MeshInstance3D
var fog_material : ShaderMaterial
var grid_size = 20
var cell_size = 1.0
var world = null
var global_vision_radius = 6.0
var feather = 1.5
var darkness = 0.95
var fog_color = Color(0.05, 0.05, 0.08, 1.0)
var fog_enabled = true
var terraform_manager = null
const MAX_LIGHTS = 8
const MAX_WALLS = 64
const MIN_FOG_EXTENT := 64.0
const FOG_EXTENT_MULTIPLIER := 5.0
var fog_extent := 0.0
var _cached_wall_data : Array = []

# The fog is a flat plane that sits just above the ground.
# It has no height so the camera angle doesn't matter at all —
# you always look down at it, never from inside it.
const BASE_FOG_Y := 0.08


func _ready():
	world = get_parent()
	terraform_manager = world.get_node_or_null("ModularTerraformManager")
	setup_fog_plane()


func setup_fog_plane():
	fog_plane = MeshInstance3D.new()

	var plane = PlaneMesh.new()
	fog_extent = MIN_FOG_EXTENT
	plane.size = Vector2(fog_extent, fog_extent)
	fog_plane.mesh = plane
	fog_plane.position = Vector3(0, BASE_FOG_Y, 0)

	var shader = preload("res://fog_of_war.gdshader")

	fog_material = ShaderMaterial.new()
	fog_material.shader = shader
	fog_material.render_priority = 120
	fog_plane.material_override = fog_material
	add_child(fog_plane)


func build_fog(g_size: int, c_size: float):
	grid_size = g_size
	cell_size = c_size
	var total = grid_size * cell_size
	fog_extent = max(total * FOG_EXTENT_MULTIPLIER + 4.0, MIN_FOG_EXTENT)
	var plane = PlaneMesh.new()
	plane.size = Vector2(fog_extent, fog_extent)
	fog_plane.mesh = plane
	fog_plane.position = Vector3(0, BASE_FOG_Y, 0)


func update_fog(token_list: Array):
	# Ground plane visibility
	var ground_mesh = world.get_node_or_null("StaticBody3D/MeshInstance3D")
	if ground_mesh:
		ground_mesh.visible = is_gm_mode or not fog_enabled or _any_player_token(token_list)

	if not fog_enabled:
		fog_plane.visible = false
		update_piece_visibility(token_list)
		return

	fog_plane.visible = true

	# Rebuild wall cache BEFORE visibility check so it uses current data
	var wall_data     = PackedVector4Array()
	_cached_wall_data = []
	var half          = cell_size * 0.5
	for key in world.placed_pieces:
		if wall_data.size() >= MAX_WALLS:
			break
		var piece = world.placed_pieces[key]
		if piece.piece_type != "wall":
			continue
		var blocks = true
		if piece.has_method("cycle_type"):
			blocks = piece.blocks_vision
		if not blocks:
			continue
		var pos  = piece.position
		var rot  = piece.rotation.y
		var dx   = cos(rot) * half
		var dz   = sin(rot) * half
		wall_data.append(Vector4(pos.x - dx, pos.z - dz, pos.x + dx, pos.z + dz))
		_cached_wall_data.append({
			"key":  key,
			"pos":  pos,
			"rot":  rot,
			"dir":  piece.direction,
			"dx":   dx,
			"dz":   dz
		})
	if is_gm_mode:
		update_piece_visibility(token_list)
		var gm_darkness = darkness * 0.15
		fog_material.set_shader_parameter("fog_darkness", gm_darkness)
		fog_material.set_shader_parameter("feather", feather)
		fog_material.set_shader_parameter("fog_color", fog_color)
		while wall_data.size() < MAX_WALLS:
			wall_data.append(Vector4(9999, 9999, 9999, 9999))
		fog_material.set_shader_parameter("wall_segments", wall_data)
		fog_material.set_shader_parameter("wall_count", _cached_wall_data.size())

		var positions = PackedVector2Array()
		var radii     = PackedFloat32Array()
		for token in token_list:
			var token_type  = token.get("token_type")   if token is Dictionary else token.token_type
			var token_pos   = token.get("position")     if token is Dictionary else token.position
			var token_blind = token.get("blinded")       if token is Dictionary else false
			if token_type != 0 or token_blind:
				continue
			positions.append(Vector2(token_pos.x, token_pos.z))
			var token_radius = token.get("vision_radius") if token is Dictionary else token.vision_radius
			var radius = (token_radius if token_radius and token_radius > 0 else global_vision_radius) * cell_size
			radii.append(radius)
		while positions.size() < MAX_LIGHTS:
			positions.append(Vector2(9999, 9999))
			radii.append(0.0)
		fog_material.set_shader_parameter("light_positions", positions)
		fog_material.set_shader_parameter("light_radii",     radii)
		fog_material.set_shader_parameter("light_count",     min(positions.size(), MAX_LIGHTS))
		return

	update_piece_visibility(token_list)
	while wall_data.size() < MAX_WALLS:
		wall_data.append(Vector4(9999, 9999, 9999, 9999))
	fog_material.set_shader_parameter("wall_segments", wall_data)
	fog_material.set_shader_parameter("wall_count",    _cached_wall_data.size())
	fog_material.set_shader_parameter("feather",       feather)
	fog_material.set_shader_parameter("fog_darkness",  darkness)
	fog_material.set_shader_parameter("fog_color",     fog_color)

	var positions = PackedVector2Array()
	var radii     = PackedFloat32Array()
	for token in token_list:
		var token_type  = token.get("token_type")   if token is Dictionary else token.token_type
		var token_pos   = token.get("position")     if token is Dictionary else token.position
		var token_blind = token.get("blinded")       if token is Dictionary else false
		if token_type != 0 or token_blind:
			continue
		positions.append(Vector2(token_pos.x, token_pos.z))
		var token_radius = token.get("vision_radius") if token is Dictionary else token.vision_radius
		var radius = (token_radius if token_radius and token_radius > 0 else global_vision_radius) * cell_size
		radii.append(radius)
	while positions.size() < MAX_LIGHTS:
		positions.append(Vector2(9999, 9999))
		radii.append(0.0)
	fog_material.set_shader_parameter("light_positions", positions)
	fog_material.set_shader_parameter("light_radii",     radii)
	fog_material.set_shader_parameter("light_count",     min(positions.size(), MAX_LIGHTS))


func _any_player_token(token_list: Array) -> bool:
	for token in token_list:
		var t_type = token.get("token_type") if token is Dictionary else token.token_type
		if t_type == 0:
			return true
	return false


func toggle_gm_mode():
	is_gm_mode = !is_gm_mode
	world.update_fog()


func update_piece_visibility(token_list: Array):
	var placed_pieces = world.placed_pieces
	for key in placed_pieces:
		var piece      = placed_pieces[key]
		var piece_type = piece.piece_type
		if piece_type != "wall" and piece_type != "floor":
			continue
		if is_gm_mode or not fog_enabled:
			piece.visible = true
			continue

		var piece_pos     = Vector2(piece.position.x, piece.position.z)
		var can_see_piece = false

		for token in token_list:
			var token_type  = token.get("token_type") if token is Dictionary else token.token_type
			var token_pos   = token.get("position")   if token is Dictionary else token.position
			var token_blind = token.get("blinded")     if token is Dictionary else false
			if token_type != 0:
				continue
			if token_blind:
				continue

			var token_radius = token.get("vision_radius") if token is Dictionary else token.vision_radius
			var radius   = (token_radius if token_radius and token_radius > 0 else global_vision_radius) * cell_size
			var token_xz = Vector2(token_pos.x, token_pos.z)
			var dist     = piece_pos.distance_to(token_xz)

			if piece_type == "floor":
				if dist <= radius and not ray_blocked_excluding(token_xz, piece_pos, key):
					can_see_piece = true
					break
			else:
				if dist <= radius + cell_size * 1.5:
					var seg_start = Vector2(
						piece.position.x - cos(piece.rotation.y) * cell_size * 0.5,
						piece.position.z - sin(piece.rotation.y) * cell_size * 0.5
					)
					var seg_end = Vector2(
						piece.position.x + cos(piece.rotation.y) * cell_size * 0.5,
						piece.position.z + sin(piece.rotation.y) * cell_size * 0.5
					)
					for check_point in [seg_start, piece_pos, seg_end]:
						if not ray_blocked_excluding(token_xz, check_point, key):
							can_see_piece = true
							break
			if can_see_piece:
				break

		piece.visible = can_see_piece

	# Token visibility
	var placed_tokens = world.placed_tokens
	for key in placed_tokens:
		var token = placed_tokens[key]
		if is_gm_mode or not fog_enabled:
			token.visible = true
			continue
		if token.token_type == 0:
			token.visible = true
			continue
		var token_pos     = Vector2(token.position.x, token.position.z)
		var can_see_token = false
		for t in token_list:
			var t_type = t.get("token_type") if t is Dictionary else t.token_type
			var t_pos  = t.get("position")   if t is Dictionary else t.position
			var t_blind = t.get("blinded")    if t is Dictionary else false
			if t_type != 0 or t_blind:
				continue
			var t_radius = t.get("vision_radius") if t is Dictionary else t.vision_radius
			var radius = (t_radius if t_radius and t_radius > 0 else global_vision_radius) * cell_size
			var t_xz   = Vector2(t_pos.x, t_pos.z)
			if token_pos.distance_to(t_xz) <= radius:
				if not ray_blocked_excluding(t_xz, token_pos, ""):
					can_see_token = true
					break
		token.visible = can_see_token

	# Prop visibility
	var placed_props = world.placed_props
	for key in placed_props:
		var prop = placed_props[key]
		if is_gm_mode or not fog_enabled:
			prop.visible = true
			continue
		var prop_pos = Vector2(prop.position.x, prop.position.z)
		var can_see_prop = false
		for token in token_list:
			var token_type  = token.get("token_type") if token is Dictionary else token.token_type
			var token_pos   = token.get("position")   if token is Dictionary else token.position
			var token_blind = token.get("blinded")     if token is Dictionary else false
			if token_type != 0 or token_blind:
				continue
			var token_radius = token.get("vision_radius") if token is Dictionary else token.vision_radius
			var radius   = (token_radius if token_radius and token_radius > 0 else global_vision_radius) * cell_size
			var token_xz = Vector2(token_pos.x, token_pos.z)
			var dist     = prop_pos.distance_to(token_xz)
			if dist <= radius and not ray_blocked(token_xz, prop_pos):
				can_see_prop = true
				break
		prop.visible = can_see_prop

	_update_terrain_block_visibility(token_list)



func _update_terrain_block_visibility(token_list: Array) -> void:
	if not terraform_manager:
		return
	var terrain_holder = world.get_node_or_null("TerrainHolder")
	if not terrain_holder:
		return
	for block in terrain_holder.get_children():
		if is_gm_mode or not fog_enabled:
			block.visible = true
			continue
		var block_xz = Vector2(block.global_position.x, block.global_position.z)
		var can_see  = false
		for token in token_list:
			var token_type  = token.get("token_type")   if token is Dictionary else token.token_type
			var token_pos   = token.get("position")     if token is Dictionary else token.position
			var token_blind = token.get("blinded")       if token is Dictionary else false
			if token_type != 0 or token_blind:
				continue
			var token_radius = token.get("vision_radius") if token is Dictionary else token.vision_radius
			var radius   = (token_radius if token_radius and token_radius > 0 else global_vision_radius) * cell_size
			var token_xz = Vector2(token_pos.x, token_pos.z)
			if block_xz.distance_to(token_xz) <= radius:
				if not ray_blocked(token_xz, block_xz):
					can_see = true
					break
		block.visible = can_see


func ray_blocked_excluding(from: Vector2, to: Vector2, exclude_key: String) -> bool:
	for data in _cached_wall_data:
		if data.key == exclude_key:
			continue
		if segments_intersect(from, to,
				Vector2(data.pos.x - data.dx, data.pos.z - data.dz),
				Vector2(data.pos.x + data.dx, data.pos.z + data.dz)):
			return true
	return false


func ray_blocked(from: Vector2, to: Vector2) -> bool:
	for data in _cached_wall_data:
		if segments_intersect(from, to,
				Vector2(data.pos.x - data.dx, data.pos.z - data.dz),
				Vector2(data.pos.x + data.dx, data.pos.z + data.dz)):
			return true
	return false


func segments_intersect(p: Vector2, q: Vector2, a: Vector2, b: Vector2) -> bool:
	var r     = q - p
	var s     = b - a
	var denom = r.x * s.y - r.y * s.x
	var len_scale = max(r.length(), s.length())
	if len_scale > 0 and abs(denom) < 0.0001 * len_scale:
		return false
	if abs(denom) < 0.0001:
		return false
	var t = ((a.x - p.x) * s.y - (a.y - p.y) * s.x) / denom
	var u = ((a.x - p.x) * r.y - (a.y - p.y) * r.x) / denom
	return t > 0.0 and t < 1.0 and u > 0.0 and u < 1.0
