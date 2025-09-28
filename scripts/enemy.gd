extends Control

'''
Integration notes:
- This node calls `add_to_group("enemies")` in `_ready()`. GameManager drives all
  enemies by calling `enemy_take_turn()` on the "enemies" group each ENEMY phase.
- The ground must be a grid node that implements:
    - `get_cols() -> int`
    - `get_rows() -> int`          # y = 0 is the bottom row of that ground
    - `place_actor_at_cell(actor: Control, x: int, y_logic_bottom: int)`  # snaps to cell center
- Columns are **0-based**: 0 is the leftmost column; rows are **bottom-based**:
  y = 0 is the bottom row, y = rows - 1 is the top row.
'''

@export var ground_path: NodePath
@export var start_col: int = 1
@export var triangle_size := Vector2i(48, 42)
@export var start_row_from_top: int = 1  # 1 = very top row, 2 = second row from top

var ground
var cell := Vector2i.ZERO

func _ready():
	size = triangle_size
	ground = get_node(ground_path)
	add_to_group("enemies")

	# Clamp starting column into bounds; start on the **top row** (rows - 1)
	var cols: int = ground.get_cols()
	var rows: int = ground.get_rows()
	cell.x = clamp(start_col, 0, cols - 1)
	cell.y = clamp(rows - start_row_from_top, 0, rows - 1)

	# Wait 1–2 frames so container layout finishes, then snap to the initial cell
	await get_tree().process_frame
	await get_tree().process_frame
	ground.place_actor_at_cell(self, cell.x, cell.y)

# Called by GameManager once per ENEMY phase.
# Moves this enemy **down by 1 cell** (i.e., y - 1 in our bottom-based system),
func enemy_take_turn():
	var next := cell + Vector2i(0, -1)
	
	if next.y >= 0:
		cell = next
		ground.place_actor_at_cell(self, cell.x, cell.y)
	else:
		cell = next
		visible = false #invisible when defeat

func _draw():
	var w := float(size.x)
	var h := float(size.y)
	var p_bottom := Vector2(w * 0.5, h)
	var p_left   := Vector2(0.0, 0.0)
	var p_right  := Vector2(w, 0.0)
	draw_colored_polygon(PackedVector2Array([p_bottom, p_left, p_right]), Color(0.85, 0.2, 0.2))

func get_cell() -> Vector2i:
	return cell
	
func on_hit_by_bullet() -> void:
	queue_free()  # default death for normal enemies
