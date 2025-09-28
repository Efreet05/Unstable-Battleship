extends Control
class_name DefeatUI

@export var message: String = "An enemy breached the danger line!"  # Or "An enemy has passed your dangerline!"

var _panel: Panel
var _btn_restart: Button

func _ready() -> void:
	# UI should still work while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = MOUSE_FILTER_STOP

	# Full screen control to center our panel
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 1.0; anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	# Centered panel
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(420, 180)
	_panel.anchor_left = 0.5; _panel.anchor_top = 0.5
	_panel.offset_left = -210; _panel.offset_top = -90
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(420, 180)
	vb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "Defeat"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(420, 50)
	vb.add_child(title)

	var msg := Label.new()
	msg.text = message
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size = Vector2(420, 70)
	vb.add_child(msg)

	_btn_restart = Button.new()
	_btn_restart.text = "Restart"
	_btn_restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_restart.pressed.connect(_on_restart)
	vb.add_child(_btn_restart)

func show_defeat() -> void:
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
