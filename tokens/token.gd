extends CharacterBody3D

# Token types
enum TokenType {PLAYER, NPC, DECORATION}

# Condition constants
const CONDITION_MODELS_PATH = "res://assets/condition_models/"
const CONDITION_COLORS = {
	"Blinded": Color("#444444"),
	"Charmed": Color("#FF00FF"),
	"Concentration": Color("#4488FF"),
	"Cursed": Color("#660099"),
	"Deafened": Color("#AAAAAA"),
	"Frenzied": Color("#FF6600"),
	"Frightened": Color("#88CC00"),
	"Grappled": Color("#885522"),
	"Incapitated": Color("#888888"),
	"Inspired": Color("#FFD700"),
	"Invisible": Color("#00DDDD"),
	"paralyzed": Color("#CCCCDD"),
	"Petrified": Color("#777777"),
	"Poisoned": Color("#44CC44"),
	"Prone": Color("#AA8855"),
	"Raging": Color("#DD2222"),
	"Reckless": Color("#DD0033"),
	"Restrained": Color("#DD8800"),
	"Stunned": Color("#FFFF44"),
	"Unconscious": Color("#333333")
}
var conditions: Dictionary = {}:
	set(val):
		conditions = val
		_update_condition_rings()

# Token data
var token_name = "Unknown"
var token_type = TokenType.PLAYER
var hp = 10
var max_hp = 10
var initiative = 0
var grid_position = Vector2.ZERO
var target_position = Vector3.ZERO
var is_being_dragged = false
var has_custom_model = false
const DRAG_FOLLOW_SPEED: float = 120.0
var move_speed = 30
var movement_budget = 30
var ac = 10
var is_selected = false
var current_rotation_y = 0.0
var vision_radius = 0.0
var blinded = false
var terrain_height = 0.0
var free_placement = false
var owner_id: int = -1
var custom_model_path: String = ""

# Node references
@onready var mesh = $Mesh
@onready var selection_ring = $SelectionRing
@onready var name_label = $Billboard/NameLabel
@onready var initiative_label = $Billboard/InitiativeLabel
@onready var distance_label = $Billboard/DistanceLabel

# Materials
var ring_material: StandardMaterial3D
var is_hovered = false
var _ring_pulse_time = 0.0

var base_scale = 1.0
var scale_multiplier = 1.0:
	set(val):
		scale_multiplier = val
		_apply_scale_direct(val)

# Drag animation state
var _drag_bob_time: float = 0.0
const _DRAG_BOB_AMP: float = 0.12
const _DRAG_BOB_FREQ: float = 4.0
var _drop_indicator: MeshInstance3D = null
var _condition_rings: Dictionary = {}

func _ready():
	if selection_ring and selection_ring.material_override:
		ring_material = selection_ring.material_override.duplicate() as StandardMaterial3D
		selection_ring.material_override = ring_material
	update_visuals()
	mesh.visible = false

func init(data: Dictionary, cell_pos: Vector2, cell_size: float, grid_size: int):
	token_name = data.get("name", "Unknown")
	token_type = data.get("type", TokenType.PLAYER)
	hp = data.get("hp", 10)
	max_hp = data.get("max_hp", 10)
	initiative = data.get("initiative", 0)

	if data.has("model_path"):
		custom_model_path = data.model_path
		call_deferred("load_custom_model", data.model_path)
	else:
		# No custom model — show default capsule
		mesh.visible = true

	place_at_cell(cell_pos, cell_size, grid_size)

func load_custom_model(path: String):
	custom_model_path = path
	var model_scene = load(path)
	if model_scene == null:
		push_error("Failed to load model: " + path)
		return
	var new_mesh = model_scene.instantiate()
	if mesh:
		mesh.queue_free()
		mesh = null
	add_child(new_mesh)
	mesh = new_mesh

	# Only auto scale player/NPC tokens — props and decorations use their original size
	if token_type != TokenType.DECORATION:
		var aabb = _get_aabb(new_mesh)
		if aabb.size != Vector3.ZERO:
			var max_side = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
			base_scale = 0.9 / max_side
			apply_scale(1.0)

	has_custom_model = true
	call_deferred("fix_floor_position")
	update_visuals()

func fix_floor_position():
	if not mesh:
		return
	# Just zero out vertical offset — origin is correct from Blender
	mesh.position.y = 0.0
	position.y = terrain_height

func set_terrain_height(height: float) -> void:
	terrain_height = height
	if not is_being_dragged:
		target_position.y = terrain_height
		position.y = terrain_height

func apply_scale(multiplier: float):
	scale_multiplier = multiplier

func _apply_scale_direct(multiplier: float):
	if mesh:
		var s = base_scale * multiplier
		mesh.scale = Vector3(s, s, s)
		call_deferred("fix_floor_position")

func _get_aabb(node: Node) -> AABB:
	if not is_instance_valid(AabbUtil):
		return AABB()
	return AabbUtil.compute(node)

func place_at_cell(cell_pos: Vector2, cell_size: float, grid_size: int):
	grid_position = cell_pos  # make sure this line exists
	var half_grid = cell_size * grid_size / 2.0
	var cx = (cell_pos.x * cell_size) - half_grid + cell_size / 2.0
	var cz = (cell_pos.y * cell_size) - half_grid + cell_size / 2.0
	position = Vector3(cx, terrain_height, cz)
	if has_custom_model:
		call_deferred("fix_floor_position")
	update_visuals()

func update_visuals():
	if not is_inside_tree():
		return

	name_label.text = token_name

	if token_type == TokenType.DECORATION:
		name_label.visible = false
		initiative_label.visible = false
		return

	name_label.visible = true

	initiative_label.text = "#" + str(initiative)
	initiative_label.visible = initiative > 0

	# Only tint if using default capsule, not custom model
	if not has_custom_model:
		var mesh_instance = get_mesh_instance()
		if mesh_instance:
			mesh_instance.set_surface_override_material(0, _make_color_material(get_type_color()))

func get_mesh_instance() -> MeshInstance3D:
	# Check if mesh itself is a MeshInstance3D
	if mesh is MeshInstance3D:
		return mesh
	# Otherwise search inside it
	if mesh:
		for child in mesh.get_children():
			if child is MeshInstance3D:
				return child
	return null

func get_type_color() -> Color:
	match token_type:
		TokenType.PLAYER:
			return Color(0.2, 0.4, 0.9)
		TokenType.NPC:
			return Color(0.9, 0.2, 0.2)
		_:
			return Color(0.6, 0.5, 0.3)

func _make_color_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	return mat

func set_hp(new_hp: int):
	hp = clamp(new_hp, 0, max_hp)
	update_visuals()

func show_hover():
	if not is_hovered:
		is_hovered = true
		if not is_selected:
			scale = Vector3(1.08, 1.08, 1.08)
			if selection_ring and ring_material:
				selection_ring.visible = true
				ring_material.albedo_color = Color(0.6, 0.8, 1.0, 0.3)
				ring_material.emission = Color(0.6, 0.8, 1.0)
				ring_material.emission_energy_multiplier = 1.0

func hide_hover():
	if is_hovered:
		is_hovered = false
		if not is_selected:
			scale = Vector3(1, 1, 1)
			if selection_ring:
				selection_ring.visible = false

func show_distance(from_cell: Vector2, to_cell: Vector2):
	# Decorations don't need distance
	if token_type == TokenType.DECORATION:
		return
		
	var dx = abs(to_cell.x - from_cell.x)
	var dy = abs(to_cell.y - from_cell.y)
	# D&D 5e diagonal movement — diagonals cost 5ft too
	var cells = max(dx, dy)
	var feet = cells * 5
	distance_label.text = str(feet) + " ft"
	distance_label.visible = true
	# Color based on movement range
	# Default move speed is 30ft = 6 cells
	if feet <= 30:
		distance_label.modulate = Color(0.2, 0.9, 0.2)
	elif feet <= 60:
		distance_label.modulate = Color(0.9, 0.7, 0.1)
	else:
		distance_label.modulate = Color(0.9, 0.2, 0.2)

func hide_distance():
	distance_label.visible = false

func _process(delta):
	if is_selected and selection_ring and ring_material:
		_ring_pulse_time += delta * 2.0
		var pulse = 0.6 + sin(_ring_pulse_time) * 0.15
		ring_material.albedo_color.a = pulse
	if is_being_dragged:
		position = position.move_toward(target_position, DRAG_FOLLOW_SPEED * delta)
		if position.distance_to(target_position) < 0.01:
			position = target_position
		_drag_bob_time += delta
		var bob = sin(_drag_bob_time * _DRAG_BOB_FREQ) * _DRAG_BOB_AMP
		position.y = target_position.y + 0.3 + bob
		rotation.z = sin(_drag_bob_time * 3.0) * 0.03
		_update_indicator_position()

func set_drag_target(world_pos: Vector3):
	target_position = world_pos
	if not is_being_dragged:
		is_being_dragged = true
		_drag_bob_time = PI * 0.5

func stop_drag():
	is_being_dragged = false
	_remove_drop_indicator()
	_restore_ring_visual()
	position.y = terrain_height
	rotation.z = 0.0
	if has_custom_model:
		call_deferred("fix_floor_position")
	var squish = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	squish.tween_property(self, "scale", Vector3(0.92, 0.92, 0.92), 0.05)
	squish.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.12)


# ── drag visual helpers ─────────────────────────────────────────────────────

func start_grab_animation():
	_drag_bob_time = PI * 0.5
	_create_drop_indicator()
	_set_drag_ring_visual()

func start_drop_animation():
	_remove_drop_indicator()
	_restore_ring_visual()
	rotation.z = 0.0

func _create_drop_indicator():
	_remove_drop_indicator()
	_drop_indicator = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(0.35, 0.35)
	_drop_indicator.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.25, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 2
	_drop_indicator.material_override = mat
	_drop_indicator.rotation_degrees = Vector3(-90, 0, 0)
	_update_indicator_position()
	_drop_indicator.position.y = 0.02
	get_parent().add_child(_drop_indicator)

func _remove_drop_indicator():
	if _drop_indicator and is_instance_valid(_drop_indicator):
		_drop_indicator.queue_free()
	_drop_indicator = null

func _update_indicator_position():
	if _drop_indicator and is_instance_valid(_drop_indicator):
		_drop_indicator.position.x = position.x
		_drop_indicator.position.z = position.z

func _set_drag_ring_visual():
	if selection_ring and ring_material:
		selection_ring.visible = true
		ring_material.albedo_color = Color(1.0, 0.7, 0.1, 0.6)
		ring_material.emission = Color(1.0, 0.7, 0.1)
		ring_material.emission_energy_multiplier = 2.0

func _restore_ring_visual():
	if selection_ring and ring_material:
		if is_selected:
			ring_material.albedo_color = Color(0.3, 0.6, 1.0, 0.5)
			ring_material.emission = Color(0.3, 0.6, 1.0)
			ring_material.emission_energy_multiplier = 2.0
		else:
			selection_ring.visible = false

func select():
	is_selected = true
	scale = Vector3(1.1, 1.1, 1.1)
	if selection_ring and ring_material:
		selection_ring.visible = true
		ring_material.albedo_color = Color(0.3, 0.6, 1.0, 0.5)
		ring_material.emission = Color(0.3, 0.6, 1.0)
		ring_material.emission_energy_multiplier = 2.0
	_ring_pulse_time = 0.0

func deselect():
	is_selected = false
	scale = Vector3(1.0, 1.0, 1.0)
	if selection_ring:
		selection_ring.visible = false

func rotate_by(degrees: float):
	current_rotation_y += degrees
	rotation.y = deg_to_rad(current_rotation_y)


# ── condition markers ─────────────────────────────────────────────────────────

const CONDITION_NAMES := [
	"Blinded", "Charmed", "Concentration", "Cursed", "Deafened",
	"Frenzied", "Frightened", "Grappled", "Incapitated", "Inspired",
	"Invisible", "paralyzed", "Petrified", "Poisoned", "Prone",
	"Raging", "Reckless", "Restrained", "Stunned", "Unconscious"
]

func toggle_condition(name: String):
	if conditions.has(name):
		conditions.erase(name)
		if name == "Blinded":
			blinded = false
	else:
		conditions[name] = true
		if name == "Blinded":
			blinded = true
	conditions = conditions.duplicate()

func get_condition_list() -> Array:
	return conditions.keys()

func _update_condition_rings():
	var to_remove = []
	for name in _condition_rings:
		if not conditions.has(name):
			to_remove.append(name)
	for name in to_remove:
		_remove_condition_ring(name)
	for name in conditions:
		if not _condition_rings.has(name):
			_spawn_condition_ring(name)
	blinded = conditions.has("Blinded")

func _spawn_condition_ring(name: String):
	var path = CONDITION_MODELS_PATH + name + ".glb"
	var scene = load(path)
	if scene == null:
		return
	var inst = scene.instantiate()
	add_child(inst)
	inst.position.y = 0.01
	var color = CONDITION_COLORS.get(name, Color.WHITE)
	_apply_material_override(inst, color)
	_condition_rings[name] = inst

func _remove_condition_ring(name: String):
	if _condition_rings.has(name):
		var ring = _condition_rings[name]
		if is_instance_valid(ring):
			ring.queue_free()
		_condition_rings.erase(name)

func _apply_material_override(node: Node, color: Color):
	for child in node.get_children():
		_apply_material_override(child, color)
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = 5
		node.material_override = mat


func serialize() -> Dictionary:
	var cell = grid_position
	return {
		"token_name": token_name,
		"token_type": token_type,
		"hp": hp,
		"max_hp": max_hp,
		"initiative": initiative,
		"move_speed": move_speed,
		"movement_budget": movement_budget,
		"ac": ac,
		"vision_radius": vision_radius,
		"blinded": blinded,
		"free_placement": free_placement,
		"model_path": custom_model_path if has_custom_model else "",
		"cell_x": int(cell.x),
		"cell_y": int(cell.y),
		"position_x": position.x,
		"position_y": position.y,
		"position_z": position.z,
		"rotation_y": rotation.y,
		"owner_id": owner_id,
		"conditions": conditions.duplicate(),
	}


func init_from_data(data: Dictionary, cell_size: float, grid_size: int):
	token_name = data.get("token_name", "Unknown")
	token_type = data.get("token_type", 0)
	hp = data.get("hp", 10)
	max_hp = data.get("max_hp", 10)
	initiative = data.get("initiative", 0)
	move_speed = data.get("move_speed", 30)
	movement_budget = data.get("movement_budget", 30)
	ac = data.get("ac", 10)
	vision_radius = data.get("vision_radius", 0.0)
	blinded = data.get("blinded", false)
	free_placement = data.get("free_placement", false)
	owner_id = data.get("owner_id", -1)
	conditions = data.get("conditions", {}).duplicate()
	var model_path = data.get("model_path", "")
	custom_model_path = model_path
	if model_path != "":
		call_deferred("load_custom_model", model_path)
	else:
		mesh.visible = true

	if free_placement:
		position = Vector3(data.get("position_x", 0.0), data.get("position_y", 0.0), data.get("position_z", 0.0))
	else:
		var cell_pos = Vector2(data.get("cell_x", 0), data.get("cell_y", 0))
		place_at_cell(cell_pos, cell_size, grid_size)

	rotation.y = data.get("rotation_y", 0.0)
	update_visuals()
