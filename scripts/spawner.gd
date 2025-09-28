extends Node
class_name Spawner
"""
Part 2: enemy spawning (hand-designed), item-enemy behavior and end conditions.

Hook-up in Inspector (relative to Board/Spawner):
- gm_path               -> ../GameManager
- enemy_container_path  -> ../Pieces/Enemy   (or %EnemyContainer if you use a unique name)
- enemy_ground_path     -> ../Ground/EnemyGround
- bonus_ground_path     -> ../Ground/BonusGround
"""

@export var gm_path: NodePath
@export var enemy_container_path: NodePath
@export var enemy_ground_path: NodePath
@export var bonus_ground_path: NodePath
@export var enemy_script: Script = preload("res://scripts/enemy.gd")

@export var max_turns: int = 10
@export var normal_counts_per_turn := PackedInt32Array([1,1,1,0,0,2,2,0,0,3])
@export var item_turn_move_plus  := PackedInt32Array([4])  # GOLD right-mover (left edge)
@export var item_turn_attack_plus:= PackedInt32Array([8])  # PINK left-mover (right edge)

var bonus_moves: int = 0
var bonus_shots: int = 0
var base_moves: int = 0
var base_shots: int = 0

var gm: Node
var enemy_container: Node
var enemy_ground: Node
var bonus_ground: Node
var rng := RandomNumberGenerator.new()
var turn_index: int = 0

var stop_spawning: bool = false #Stop after 10 turns

func _ready() -> void:
	rng.randomize()
	gm = get_node(gm_path)
	enemy_container = _get_enemy_container()
	assert(enemy_container != null, "Enemy container not found. Set enemy_container_path to ../Pieces/Enemy or use %EnemyContainer.")
	enemy_ground = get_node(enemy_ground_path)
	bonus_ground = get_node(bonus_ground_path)

	if gm.has_method("get"):
		base_moves = int(gm.get(&"max_steps_per_turn"))
		base_shots = int(gm.get(&"shots_per_turn"))

	if gm.has_signal("player_turn_started"):
		gm.player_turn_started.connect(_on_player_turn_started)
	if gm.has_signal("enemy_turn_ended"):
		gm.enemy_turn_ended.connect(_on_enemy_turn_ended)

func _get_enemy_container() -> Node:
	# Try inspector path
	var c := get_node_or_null(enemy_container_path)
	# Try unique-name fallback
	if c == null:
		c = get_node_or_null("%EnemyContainer")
	# Try hard-coded relative fallback (Board/Spawner -> Board/Pieces/Enemy)
	if c == null:
		c = get_node_or_null("../Pieces/Enemy")
	return c

func _on_player_turn_started(_steps_left: int) -> void:
	if stop_spawning:
		# keep label clamped to max
		_update_turn_label(max_turns)
		return
	turn_index += 1
	
	 # Hard stop: no spawns after last designed turn
	if turn_index > max_turns:
		_update_turn_label(max_turns)
		return

	# Ensure container reference is valid (scene reload / replaced)
	var test := _get_enemy_container()
	print_rich("[color=yellow]Spawner turn ", turn_index + 1, 
		   " container=", test, " path=", enemy_container_path, "[/color]")
	enemy_container = test
	if enemy_container == null:
		push_warning("Enemy container missing at turn start")
		return

	# Clean pre-placed enemies on the very first turn
	if turn_index == 1:
		for n in enemy_container.get_children():
			if is_instance_valid(n):
				n.queue_free()

	# Normal enemies
	_spawn_normals_for_turn(turn_index)

	# Bonus item enemies (top lane)
	if item_turn_move_plus.has(turn_index):
		_spawn_item_enemy("move", 1)
	if item_turn_attack_plus.has(turn_index):
		_spawn_item_enemy("attack", -1)

	# Update "Turn: x/10" label (Board/Label)
	var label := get_node_or_null(^"../Label") \
		if get_node_or_null(^"../Label") != null else get_node_or_null("%Label")
	if label and label.has_method("set_turn_counter"):
		label.call("set_turn_counter", turn_index, max_turns)

func _spawn_normals_for_turn(t: int) -> void:
	if t < 1 or t > max_turns:
		return
	var count := normal_counts_per_turn[t - 1]
	if count <= 0:
		return

	var cols = enemy_ground.get_cols()
	var used := {}
	for i in count:
		var c := _rand_unique_col(cols, used)
		if c == -1:
			return

		var enemy_node := Control.new()
		enemy_node.set_script(enemy_script)

		# Set exported vars BEFORE add_child so enemy.gd _ready() can read them
		enemy_node.set("ground_path", enemy_ground.get_path())
		enemy_node.set("start_col", c)
		enemy_node.set("start_row_from_top", 1)

		enemy_node.add_to_group("enemies")

		var container := _get_enemy_container()
		if container == null:
			push_warning("Enemy container missing while spawning normals")
			return
		container.add_child(enemy_node)
		enemy_container = container  # refresh cache

func _spawn_item_enemy(kind: String, dir_sign: int) -> void:
	var item := ItemEnemy.new()
	item.kind = kind
	item.dir = sign(dir_sign)
	item.ground_path = bonus_ground.get_path() # set before add_child
	item.killed.connect(_on_item_killed)

	var container := _get_enemy_container()
	if container == null:
		push_warning("Enemy container missing while spawning item enemy")
		return
	container.add_child(item)
	enemy_container = container

func _on_item_killed(kind: String) -> void:
	if kind == "move":
		bonus_moves += 1
	elif kind == "attack":
		bonus_shots += 1

func _apply_bonuses_for_next_player() -> void:
	if not gm: return
	var new_moves: int = base_moves + bonus_moves
	var new_shots: int = int(min(base_shots + bonus_shots, new_moves))
	gm.set(&"max_steps_per_turn", new_moves)
	gm.set(&"shots_per_turn", new_shots)

func _on_enemy_turn_ended() -> void:
	# Re-resolve container in case it was freed/replaced
	enemy_container = _get_enemy_container()
	if enemy_container == null:
		return

	# 1) Apply bonuses for NEXT player turn
	_apply_bonuses_for_next_player()

	# 2) Defeat: any NORMAL enemy below EnemyGround bottom?
	for e in enemy_container.get_children():
		if not is_instance_valid(e):
			continue
		if e is ItemEnemy:
			continue
		if e.has_method("get_cell"):
			var cell = e.get_cell()
			if cell.y < 0:
				_emit_defeat()
				return

	# 3) Victory: after max_turns AND no enemies remain
	if turn_index >= max_turns and _no_enemies_left():
		stop_spawning = true        # Stop spawning after victory
		_emit_victory()
		return

func _no_enemies_left() -> bool:
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			return false
	return true

func _emit_victory() -> void:
	var ui := get_node_or_null(^"../HUD/CenterContainer/VictoryUI") \
		if get_node_or_null(^"../HUD/CenterContainer/VictoryUI") != null else get_node_or_null("%VictoryUI")
	if ui and ui.has_method("show_victory"):
		ui.call("show_victory")
	else:
		print("[LEVEL] Victory")
		get_tree().paused = true

func _emit_defeat() -> void:
	var ui := get_node_or_null(^"../HUD/DefeatUI")
	if ui == null:
		ui = get_node_or_null("%DefeatUI")
	if ui and ui.has_method("show_defeat"):
		ui.call("show_defeat")
	else:
		print("[LEVEL] Defeat")
		get_tree().paused = true


func _rand_unique_col(cols: int, used: Dictionary) -> int:
	var pool: Array[int] = []
	for c in range(cols):
		if not used.has(c):
			pool.append(c)
	if pool.is_empty():
		return -1
	var idx: int = rng.randi_range(0, pool.size() - 1)
	var col: int = pool[idx]
	used[col] = true
	return col

func _update_turn_label(current:int) -> void:
	var label := get_node_or_null(^"../Label")
	if label == null:
		label = get_node_or_null("%Label")
	if label != null and label.has_method("set_turn_counter"):
		label.call("set_turn_counter", current, max_turns)
