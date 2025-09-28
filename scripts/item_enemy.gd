extends Control
class_name ItemEnemy
"""
Top-lane bonus enemy:
- Spawns on the TOP row of BONUS ground.
- Moves horizontally by 1 cell each ENEMY phase.
- If the next step would leave the grid, it disappears.
- On hit, emits a bonus (+1 move or +1 shot for NEXT turn) then dies.
- Must be in group "enemies" so bullet.gd can detect it.
"""

@export var ground_path: NodePath
@export var kind: String = "move"    # "move" => +1 move (gold), "attack" => +1 shot (pink-purple)
@export var dir: int = 1             # 1 = move right (spawn at left edge), -1 = move left (spawn at right edge)
@export var triangle_size := Vector2i(48, 42)

@export var runtime_active: bool = true  # set FALSE on your pre-placed placeholder

signal killed(kind: String)

var ground: Node = null
var cell := Vector2i.ZERO
var tri_color: Color = Color(0.95, 0.85, 0.20) # default gold

func _ready() -> void:
	if not Engine.is_editor_hint() and not runtime_active:
		queue_free()
		return
	add_to_group("enemies")
	size = triangle_size
	ground = get_node(ground_path)

	# Color by kind
	if kind == "move":
		tri_color = Color(0.95, 0.85, 0.20)  # gold
	elif kind == "attack":
		tri_color = Color(0.90, 0.50, 0.95)  # pink-purple

	# TOP row of the bonus ground
	var rows = ground.get_rows()
	cell.y = rows - 1

	# Spawn at edge based on dir
	var cols = ground.get_cols()
	cell.x = 0 if dir >= 0 else (cols - 1)

	# Place on grid
	await get_tree().process_frame
	await get_tree().process_frame
	ground.place_actor_at_cell(self, cell.x, cell.y)

func enemy_take_turn() -> void:
	# One horizontal step; if next cell is outside the grid, disappear.
	var cols = ground.get_cols()
	var next_col = cell.x + dir
	if next_col < 0 or next_col >= cols:
		queue_free()
		return
	cell.x = next_col
	ground.place_actor_at_cell(self, cell.x, cell.y)

func on_hit_by_bullet() -> void:
	emit_signal("killed", kind)  # award bonus to whoever listens
	queue_free()

func _draw() -> void:
	# Draw a triangle pointing to `dir`
	var w := float(size.x)
	var h := float(size.y)

	if dir >= 0:
		# right-pointing triangle
		var p_tip  = Vector2(w, h * 0.5)
		var p_top  = Vector2(0.0, 0.0)
		var p_bot  = Vector2(0.0, h)
		draw_colored_polygon(PackedVector2Array([p_tip, p_bot, p_top]), tri_color)
	else:
		# left-pointing triangle
		var p_tip  = Vector2(0.0, h * 0.5)
		var p_top  = Vector2(w, 0.0)
		var p_bot  = Vector2(w, h)
		draw_colored_polygon(PackedVector2Array([p_tip, p_top, p_bot]), tri_color)
