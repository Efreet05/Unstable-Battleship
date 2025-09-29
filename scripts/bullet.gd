@tool
extends Control

'''
Integration notes:
- Enemies of ANY type can be targetable as long as they:
    * are `Control`-derived (so `get_global_rect()` works), and
    * join the group named in `target_group` (default `"enemies"`).
      e.g. `add_to_group("enemies")` in `_ready()`.
- Spawning: Players (or other shooters) should:
    * `add_child(bullet)` first (same visual layer as the player/actors),
    * set `top_limit_y` to the world Y where bullets should despawn,
    * position the bullet such that its center is at the firing point
      (e.g., `bullet.global_position = center - Vector2(radius, radius)`).
'''

@export var speed: float = 800.0
@export var radius: float = 8.0
@export var target_group: StringName = &"enemies"

var color: Color = Color(0.2, 0.2, 0.85)
var top_limit_y: float = 0.0

func _ready():
	size = Vector2(radius*2.0, radius*2.0)

func _process(delta: float) -> void:
	global_position.y -= speed * delta
	_check_hit()
	if global_position.y < top_limit_y:
		queue_free()

# --- Circle-vs-Rect collision in global space ---
# Treat the bullet as a circle with center `c` and radius `r`.
# For each enemy (rect), clamp the circle center to the rect, compute squared distance,
# and compare to r^2. If overlapped, destroy both bullet and enemy.
func _check_hit():
	var c := global_position + Vector2(radius, radius)
	var r := radius

	for e in get_tree().get_nodes_in_group(target_group):
		if e == null or !is_instance_valid(e) or !(e is Control):
			continue
		var er := (e as Control).get_global_rect()
		var closest := Vector2(
			clamp(c.x, er.position.x, er.position.x + er.size.x),
			clamp(c.y, er.position.y, er.position.y + er.size.y)
		)
		if c.distance_squared_to(closest) <= r * r:
			# Play enemy death sound
			_play_enemy_death_sound()
			
			if e.has_method("on_hit_by_bullet"):
				e.on_hit_by_bullet()     # item enemies can emit a bonus before dying
			else:
				(e as Node).queue_free() # default: normal enemy dies immediately
			queue_free()
			return

# Play enemy death sound using audio file
func _play_enemy_death_sound():
	var audio_player = AudioStreamPlayer.new()
	get_parent().add_child(audio_player)  # Add to parent since bullet will be freed
	
	# Load the death sound (replace with your MP3 file path)
	var death_sound = load("res://assets/enemy_death.mp3")
	if death_sound:
		audio_player.stream = death_sound
		audio_player.volume_db = -8
		audio_player.play()
		
		# Clean up after sound finishes
		await audio_player.finished
		audio_player.queue_free()
	else:
		# Clean up if no audio file found
		audio_player.queue_free()

func _draw():
	draw_circle(Vector2(radius, radius), radius, color)
