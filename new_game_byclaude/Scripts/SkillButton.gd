extends Control

# 技能按钮 - 支持触屏和鼠标

class_name SkillButton

var slot_index := 0
var skill_data = null
var is_on_cooldown := false

var _last_trigger_time := 0

@onready var icon_sprite := $Icon
@onready var cd_label := $CDLabel
@onready var name_label := $NameLabel

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	cd_label.visible = false
	gui_input.connect(_on_gui_input)

func set_skill(data):
	skill_data = data
	if data:
		name_label.text = data.get("name", "")
		icon_sprite.visible = true
	else:
		name_label.text = ""
		icon_sprite.visible = false

func _on_gui_input(event: InputEvent):
	var triggered := false
	if event is InputEventScreenTouch and event.pressed:
		triggered = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		triggered = true

	if not triggered:
		return

	# 防抖：防止触摸事件和模拟鼠标事件重复触发
	var now = Time.get_ticks_msec()
	if now - _last_trigger_time < 50:
		return
	_last_trigger_time = now

	_on_pressed()

func _on_pressed():
	if is_on_cooldown:
		return
	if skill_data == null:
		return
	var player = get_tree().get_first_node_in_group("human_player")
	if player and player.has_method("use_skill"):
		player.use_skill(slot_index)

func start_cooldown(duration: float):
	if is_on_cooldown:
		return
	is_on_cooldown = true
	cd_label.visible = true
	modulate = Color(0.5, 0.5, 0.5, 0.7)

	var remain = duration
	while remain > 0:
		cd_label.text = str(ceil(remain))
		await get_tree().create_timer(0.2).timeout
		remain -= 0.2

	cd_label.visible = false
	is_on_cooldown = false
	modulate = Color(1, 1, 1, 1)
