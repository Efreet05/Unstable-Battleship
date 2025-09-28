extends Label

'''
Integration notes:
- Assign `game_manager_path` in the Inspector to `Board/GameManager`.
- This label will update automatically as long as GameManager emits:
    * `player_turn_started(steps_left)`
    * `player_step_count_changed(used, left)`
    * `shot_triggers_generated(triggers)`
    * (Optionally) `enemy_turn_ended` to restore alpha if you dim during enemy turns
- If ever need to override the display manually (e.g., scripted bonus/buffs),
  call `set_used_and_max(used, new_max)`.
'''

@export var game_manager_path: NodePath

var gm: Node = null
var used_steps: int = 0
var max_steps: int = 0
var shot_triggers: PackedInt32Array = []

var _turn_current: int = 0
var _turn_max: int = 10

func _ready():
	gm = get_node_or_null(game_manager_path)

	if gm.has_signal("player_turn_started"):
		gm.player_turn_started.connect(_on_player_turn_started)
	if gm.has_signal("player_step_count_changed"):
		gm.player_step_count_changed.connect(_on_player_step_changed)
	if gm.has_signal("shot_triggers_generated"):
		gm.shot_triggers_generated.connect(_on_triggers_generated)
	if gm.has_signal("enemy_turn_ended"):
		gm.enemy_turn_ended.connect(func(): self.modulate.a = 1.0)
		
	# Try to read current values immediately (in case GM is already running)
	# Note: using `get()` avoids compile-time dependency on class members.
	var ms = gm.get(&"max_steps_per_turn")
	if typeof(ms) == TYPE_INT:
		max_steps = ms
	var used = gm.get(&"steps_used")
	if typeof(used) == TYPE_INT:
		used_steps = used

	# Wait a frame so any late connections/state settle, then pull a coherent snapshot.
	await get_tree().process_frame
	_pull_initial_state()
	_update_text()

# Pull a fresh snapshot from GM. Safe to call any time.
func _pull_initial_state():
	var ms = gm.get("max_steps_per_turn")
	if typeof(ms) == TYPE_INT: max_steps = ms

	var su = gm.get("steps_used")
	if typeof(su) == TYPE_INT: used_steps = su

	var trg = gm.get("current_shot_triggers")
	if typeof(trg) == TYPE_PACKED_INT32_ARRAY: shot_triggers = trg

# Start of player phase: reset used steps, refresh max.
# `steps_left` is typically == max at phase start; use it as source-of-truth.
func _on_player_turn_started(steps_left: int) -> void:
	used_steps = 0
	max_steps = max(steps_left, 0)
	_update_text()

# After each player move: update used; recompute/raise max if GM grants extra steps mid-turn.
func _on_player_step_changed(used: int, left: int) -> void:
	used_steps = max(0, used)
	max_steps = max(used + left, max_steps)
	_update_text()

# Optional external override, e.g., when a bonus modifies both values at once.
func set_used_and_max(used: int, new_max: int) -> void:
	used_steps = max(0, used)
	max_steps = max(0, new_max)
	_update_text()

func set_turn_counter(current: int, max_turns: int) -> void:
	# Called by Spawner each time a new player turn starts.
	_turn_current = current
	_turn_max = max_turns
	_update_text()

# When the GM rolls new shot triggers at player-phase start.
func _on_triggers_generated(triggers: PackedInt32Array) -> void:
	shot_triggers = triggers
	_update_text()

func _update_text():
	var turn_text := "Turn: %d/%d" % [_turn_current, _turn_max]
	var steps_text := "Steps: %d/%d" % [clamp(used_steps, 0, max_steps), max_steps]
	var shots_text := "Shots at: --"
	if shot_triggers.size() > 0:
		var parts: Array[String] = []
		for v in shot_triggers:
			parts.append(str(v))
		shots_text = "Shots at: " + String(", ").join(parts)
	text = turn_text + "\n" + steps_text + "\n" + shots_text + "\n" + "end turn: space"
