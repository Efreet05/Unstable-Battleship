extends Control

'''
Integration notes:
- GameManager governs when the player can act:
    * During PLAYER phase and while `locked_waiting_space == false`, arrow keys will move.
    * After `max_steps_per_turn` moves, GameManager sets `locked_waiting_space = true`
      and the player must press SPACE to end the turn.
- Shot triggers are generated each PLAYER phase by GameManager and delivered via
  `shot_triggers_generated(triggers)`. This script stores them in `pending_triggers`
  and consumes them when `used` equals a trigger value.
- `ground` must expose:
    * `get_cols() -> int`, `get_rows() -> int`
    * `cell_center_global(x, y_logic_bottom) -> Vector2`
    * `place_actor_at_cell(actor: Control, x: int, y_logic_bottom: int)`
  Coordinates are bottom-based: y=0 is the bottom row; y increases upward.
'''

@export var ground_path: NodePath
@export var bonus_ground_path: NodePath
@export var game_manager_path: NodePath
@export var start_cell := Vector2i(0, 0)
@export var triangle_size := Vector2i(48, 42)

var ground
var bonus_ground
var gm
var cell := Vector2i.ZERO
var pending_triggers: Array[int] = []

func _ready():
	self.z_index = 2
	size = triangle_size
	ground = get_node(ground_path)
	bonus_ground = get_node(bonus_ground_path)
	gm = get_node(game_manager_path)
	
	# Subscribe to per-turn shot triggers; store as an int array for quick lookup/erase
	if gm.has_signal("shot_triggers_generated"):
		gm.shot_triggers_generated.connect(func(trigs: PackedInt32Array):
			pending_triggers = []
			for t in trigs:
				pending_triggers.append(int(t))
		)
	# Subscribe to step count updates to check whether a trigger fires after each move
	if gm.has_signal("player_step_count_changed"):
		gm.player_step_count_changed.connect(_on_step_changed)
		
	# If the GameManager already generated triggers before this node connected, read the current cache
	var cur = gm.get("current_shot_triggers")
	if typeof(cur) == TYPE_PACKED_INT32_ARRAY:
		pending_triggers.clear()
		for t in cur:
			pending_triggers.append(int(t))

	# Clamp starting cell within PlayerGround and snap after layout settles
	var cols: int = ground.get_cols()
	var rows: int = ground.get_rows()
	cell = Vector2i(
		clamp(start_cell.x, 0, cols - 1),
		clamp(start_cell.y, 0, rows - 1)
	)

	# Wait 1–2 frames: containers finish layout, then we snap to the correct pixel center
	await get_tree().process_frame
	await get_tree().process_frame
	ground.place_actor_at_cell(self, cell.x, cell.y)

func _unhandled_input(event):
	# SPACE ends the player turn (regardless of how many steps were used)
	if event.is_action_pressed("ui_accept"):
		gm.request_end_player_turn()
		return
		
	# Only accept movement during PLAYER phase and before steps are exhausted
	if gm.phase != gm.Phase.PLAYER or gm.locked_waiting_space:
		return
		
	# Translate arrow-key input into a single-cell delta in bottom-based coordinates
	var d := Vector2i.ZERO
	if event.is_action_pressed("ui_right"): d.x += 1
	if event.is_action_pressed("ui_left"):  d.x -= 1
	if event.is_action_pressed("ui_up"):    d.y += 1
	if event.is_action_pressed("ui_down"):  d.y -= 1
	if d != Vector2i.ZERO:
		var next := cell + d
		if next.x >= 0 and next.x < ground.get_cols() and next.y >= 0 and next.y < ground.get_rows():
			cell = next
			ground.place_actor_at_cell(self, cell.x, cell.y)
			gm.notify_player_step()

# Called on each step update. When `used` matches a pending trigger, fire a projectile once.
func _on_step_changed(used: int, _left: int) -> void:
	if pending_triggers.has(used):
		pending_triggers.erase(used)
		_fire_projectile()
		
# Spawns one bullet at the current cell center, rendered under the player.
# Bullet despawns automatically when its top passes the top edge of BonusGround.
func _fire_projectile():
	var start_center: Vector2 = ground.cell_center_global(cell.x, cell.y)
	var bonus_top_y: float = (bonus_ground as Control).get_global_rect().position.y

	var p := preload("res://scripts/bullet.gd").new() as Control
	get_parent().add_child(p)
	p.top_limit_y = bonus_top_y
	p.global_position = start_center - p.size * 0.5
	p.z_index = 1

func _draw():
	var w := float(size.x)
	var h := float(size.y)
	var p_top   := Vector2(w * 0.5, 0.0)
	var p_left  := Vector2(0.0, h)
	var p_right := Vector2(w, h)
	draw_colored_polygon(PackedVector2Array([p_top, p_left, p_right]), Color(0.2, 0.85, 0.2))
