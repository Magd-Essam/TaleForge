extends MeshInstance3D

const SAFE_RENDER_PRIORITY_MAX: int = 127

@export var grid_size: int = 20
@export var cell_size: float = 1.0
@export var grid_color: Color = Color(0.0, 0.0, 0.0, 0.85)
@export var sub_grid_color: Color = Color(0.0, 0.0, 0.0, 0.35)
@export var line_width: float = 0.8
@export var sub_grid_division: int = 5
@export var fade_distance: float = 150.0
@export var fade_sharpness: float = 1.0
@export var render_priority: int = 110
@export var base_height: float = 0.02

var grid_mat: ShaderMaterial

func _ready() -> void:
	setup_grid()
	draw_grid()

func setup_grid() -> void:
	if mesh == null or not (mesh is PlaneMesh):
		mesh = PlaneMesh.new()

	if grid_mat == null:
		grid_mat = ShaderMaterial.new()
		grid_mat.shader = load("res://grid.gdshader")
		grid_mat.render_priority = _get_safe_render_priority()

	material_override = grid_mat
	set_overlay_height(0.0)

func draw_grid() -> void:
	if mesh == null or not (mesh is PlaneMesh):
		mesh = PlaneMesh.new()

	var plane: PlaneMesh = mesh as PlaneMesh
	var total_size: float = float(grid_size) * cell_size
	plane.size = Vector2(total_size, total_size)

	if grid_mat == null:
		grid_mat = ShaderMaterial.new()
		grid_mat.shader = load("res://grid.gdshader")
		grid_mat.render_priority = _get_safe_render_priority()
		material_override = grid_mat

	grid_mat.render_priority = _get_safe_render_priority()
	grid_mat.set_shader_parameter("grid_color", grid_color)
	grid_mat.set_shader_parameter("sub_grid_color", sub_grid_color)
	grid_mat.set_shader_parameter("grid_size", cell_size)
	grid_mat.set_shader_parameter("line_width", line_width)
	grid_mat.set_shader_parameter("sub_grid_division", sub_grid_division)
	grid_mat.set_shader_parameter("fade_distance", fade_distance)
	grid_mat.set_shader_parameter("fade_sharpness", fade_sharpness)

func set_overlay_height(height: float) -> void:
	var target_y: float = max(base_height, height + base_height)
	position.y = target_y

func _get_safe_render_priority() -> int:
	return min(render_priority, SAFE_RENDER_PRIORITY_MAX)
