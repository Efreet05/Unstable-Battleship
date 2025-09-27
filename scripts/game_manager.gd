extends Node
class_name GameManager

enum Phase { PLAYER, ENEMY }

@export var max_steps_per_turn: int = 4
@export var shots_per_turn: int = 2

signal player_turn_started(steps_left: int)
signal player_step_count_changed(used: int, left: int)
signal player_turn_ended()
signal enemy_turn_started()
signal enemy_turn_ended()
signal shot_triggers_generated(triggers: PackedInt32Array)

var phase: int = Phase.PLAYER
var steps_used: int = 0
var locked_waiting_space: bool = false
var current_shot_triggers: PackedInt32Array = []

func _ready():
	_emit_player_start()

# --- Internal: start a PLAYER phase and publish triggers/initial counts ---
func _emit_player_start():
	current_shot_triggers = _generate_shot_triggers()
	emit_signal("shot_triggers_generated", current_shot_triggers)
	emit_signal("player_turn_started", max_steps_per_turn - steps_used)

# --- External API: called by Player after a successful grid move ---
func notify_player_step():
	if phase != Phase.PLAYER:
		return
	steps_used += 1
	var left := max_steps_per_turn - steps_used
	emit_signal("player_step_count_changed", steps_used, left)
	if steps_used >= max_steps_per_turn:
		locked_waiting_space = true

# --- External API: called by Player when SPACE is pressed to end the turn ---
func request_end_player_turn():
	if phase != Phase.PLAYER:
		return
	_start_enemy_turn()

# --- Internal: run ENEMY phase, then rotate back to PLAYER phase ---
func _start_enemy_turn():
	phase = Phase.ENEMY
	emit_signal("player_turn_ended")
	emit_signal("enemy_turn_started")

	# Drive all enemies once. Enemy scripts should:
	#   - add_to_group("enemies")
	#   - implement `func enemy_take_turn():`
	for e in get_tree().get_nodes_in_group("enemies"):
		if e and e.has_method("enemy_take_turn"):
			e.enemy_take_turn()

	phase = Phase.PLAYER
	steps_used = 0
	locked_waiting_space = false
	emit_signal("enemy_turn_ended")
	_emit_player_start()

# --- Internal: generate distinct random shot steps in [1..max_steps_per_turn], sorted ascending ---
func _generate_shot_triggers() -> PackedInt32Array:
	var m: int = max_steps_per_turn
	var k: int = clamp(shots_per_turn, 0, m)
	var arr: PackedInt32Array = PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	while arr.size() < k:
		var v: int = rng.randi_range(1, m)
		if not arr.has(v):
			arr.append(v)

	arr.sort()
	return arr
