extends Control
class_name VictoryUI

@export var next_level_path: String = ""

var _panel: Panel
var _btn_restart: Button
var _btn_next: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # process when paused
	visible = false
	mouse_filter = MOUSE_FILTER_STOP          # keep mouse from clicking the background
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 1.0; anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(360, 180)
	_panel.anchor_left = 0.5; _panel.anchor_top = 0.5
	_panel.offset_left = -180; _panel.offset_top = -90
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(360, 180)
	vb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "Victory!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(360, 80)
	vb.add_child(title)

	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(hb)

	_btn_restart = Button.new()
	_btn_restart.text = "Restart"
	_btn_restart.pressed.connect(_on_restart)
	hb.add_child(_btn_restart)

	_btn_next = Button.new()
	_btn_next.text = "Next Level"
	_btn_next.disabled = (next_level_path == "")
	_btn_next.pressed.connect(_on_next)
	hb.add_child(_btn_next)

func show_victory() -> void:
	visible = true
	get_tree().paused = true

func _on_restart() -> void:
	var st := get_tree()
	st.paused = false
	var cs := st.current_scene
	if cs and cs.scene_file_path != "":
		st.change_scene_to_file(cs.scene_file_path)
	else:
		st.reload_current_scene()

func _on_next() -> void:
	if next_level_path == "":
		return
	
	# Play victory sound before transitioning to next level
	_play_victory_sound()
	
	var st := get_tree()
	st.paused = false
	st.change_scene_to_file(next_level_path)

# Play victory sound using audio file
func _play_victory_sound():
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Load the victory sound (replace with your MP3 file path)
	var victory_sound = load("res://assets/victory.mp3")
	if victory_sound:
		audio_player.stream = victory_sound
		audio_player.volume_db = -5  # Slightly louder for celebration
		audio_player.play()
		
		# Note: We don't wait for the sound to finish since we're changing scenes
		# The sound will play briefly before the scene transition
	else:
		# Clean up if no audio file found
		audio_player.queue_free()
