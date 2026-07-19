extends Control

# 攻击按钮 - 支持触屏和鼠标

var _last_trigger_time := 0

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	var triggered := false
	if event is InputEventScreenTouch and event.pressed:
		triggered = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		triggered = true

	if not triggered:
		return

	# 防抖：防止触摸事件和模拟鼠标事件重复触发（< 50ms内只触发一次）
	var now = Time.get_ticks_msec()
	if now - _last_trigger_time < 50:
		return
	_last_trigger_time = now

	var player = get_tree().get_first_node_in_group("human_player")
	if player and player.has_method("attack"):
		player.attack()
