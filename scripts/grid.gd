@tool
extends GridContainer

'''
Integration notes:
- This grid is purely visual/background. It does **not** own gameplay logic.
- Actors (player/enemies/bonus items) should be separate Controls placed by
  `place_actor_at_cell()`. Make sure they share a non-container parent to avoid
  container layout overriding their positions.
- If change `width/height/cellWidth/cellHeight` in the Inspector, the grid
  rebuilds immediately in the editor.

Caveats:
- Because this node extends GridContainer, its children are **laid out by the
  container**; do not add actors under this node. Keep actors in a sibling layer.
'''

@export var width := 5:
	set(value):
		width = value
		_remove_grid()
		_create_grid()
@export var height := 5:
	set(value):
		height = value
		_remove_grid()
		_create_grid()
@export var cellWidth := 100:
	set(value):
		cellWidth = value
		_remove_grid()
		_create_grid()
@export var cellHeight := 100:
	set(value):
		cellHeight = value
		_remove_grid()
		_create_grid()

# Visual cell scene to instantiate into this container (one per cell)
const GRID_CELL = preload("res://scenes/grid_cell.tscn")
const borderSize = 4

func _ready() -> void:
	if get_child_count() != width * height:
		_remove_grid()
		_create_grid()
	
# --- Internal: rebuild visual tiles ---
func _create_grid():
	columns = width
	
	for i in width * height:
		var gridCellNode = GRID_CELL.instantiate()
		gridCellNode.custom_minimum_size = Vector2(cellWidth, cellHeight)
		add_child(gridCellNode)

func _remove_grid():
	for node in get_children():
		node.queue_free()

# --- Public API (used by Player/Enemy/any actor scripts) ---
func get_cols() -> int:
	return width

func get_rows() -> int:
	return height

# Convert logical (x, y_bottom) to the child index in this GridContainer.
# Because GridContainer lays out from the TOP visually, we flip the logical Y.
func cell_index(x: int, y_logic_bottom: int) -> int:
	var visual_row := (height - 1) - y_logic_bottom
	return visual_row * width + x

# Get the cell node (the visual tile) at logical (x, y_bottom).
func cell_node(x: int, y_logic_bottom: int) -> Node:
	var idx := cell_index(x, y_logic_bottom)
	if idx < 0 or idx >= get_child_count():
		return null
	return get_child(idx)

# Get the global rectangle of the visual cell at (x, y_bottom).
func cell_rect_global(x: int, y_logic_bottom: int) -> Rect2:
	var node := cell_node(x, y_logic_bottom)
	return node.get_global_rect() if node else Rect2()

# Get the global pixel center of the visual cell at (x, y_bottom).
func cell_center_global(x: int, y_logic_bottom: int) -> Vector2:
	return cell_rect_global(x, y_logic_bottom).get_center()

# Snap any Control to the pixel center of the given logical cell.
# NOTE: This sets the actor's GLOBAL position; ensure the actor lives under a
# non-container Control so layout doesn't override it.
func place_actor_at_cell(actor: Control, x: int, y_logic_bottom: int) -> void:
	var c := cell_center_global(x, y_logic_bottom)
	actor.global_position = c - actor.size * 0.5
