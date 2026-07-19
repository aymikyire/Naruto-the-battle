extends Control

# 虚拟摇杆 - 触屏/鼠标控制移动
class_name GameVirtualJoystick

var is_pressed := false
var output := Vector2.ZERO
var _touch_index := -1
var _center := Vector2.ZERO
var _radius := 80.0
var _inner_radius := 20.0

@onready var knob := $Knob
@onready var touch_area := $TouchArea

func _ready():
	_center = size / 2
	knob.position = _center - knob.size / 2

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			# 检查触摸是否在摇杆区域内
			if is_point_in_joystick_area(event.position):
				_touch_index = event.index
				is_pressed = true
				update_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			is_pressed = false
			output = Vector2.ZERO
			knob.position = _center - knob.size / 2

	if event is InputEventScreenDrag and event.index == _touch_index:
		update_knob(event.position)

func is_point_in_joystick_area(pos: Vector2) -> bool:
	# 摇杆在屏幕左半区
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_rect = Rect2(
		global_position.x - 100,
		global_position.y - 100,
		size.x + 200,
		size.y + 200
	)
	return joystick_rect.has_point(pos)

func update_knob(touch_pos: Vector2):
	var local_pos = touch_pos - global_position
	var vec = local_pos - _center
	var dist = vec.length()

	if dist > _radius:
		vec = vec.normalized() * _radius

	knob.position = _center + vec - knob.size / 2
	output = vec / _radius  # 归一化 (0~1)

	# 死区
	if dist < _inner_radius:
		output = Vector2.ZERO
		knob.position = _center - knob.size / 2

# 键盘调试替代（PC用）
func _process(delta):
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		var dir = Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
		output = dir

	# 将摇杆输出应用到玩家移动方向
	var player = get_tree().get_first_node_in_group("human_player")
	if player:
		player.move_direction = output
