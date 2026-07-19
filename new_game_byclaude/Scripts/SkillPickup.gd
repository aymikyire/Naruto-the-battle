extends Area2D

# 技能拾取物
class_name SkillPickup

var skill_data = null
var lifetime := 30.0  # 30秒无人捡自动消失
var blink_timer := 0.0
var _float_time := 0.0

@onready var sprite := $Sprite2D
@onready var label := $Label

func _ready():
	add_to_group("skill_pickups")
	body_entered.connect(_on_body_entered)
	if skill_data:
		label.text = skill_data.get("name", "技能")

func _process(delta):
	_float_time += delta

	lifetime -= delta
	if lifetime <= 0:
		# 闪烁消失
		blink_timer += delta
		if blink_timer > 0.1:
			blink_timer = 0
			visible = not visible
	if lifetime <= -3.0:
		queue_free()

	queue_redraw()

func _draw():
	var bob := sin(_float_time * 3.0) * 3.0
	var float_y := bob

	# 外圈光晕
	draw_circle(Vector2(0, float_y), 42, Color(1, 0.85, 0.2, 0.15))
	# 主圈（金黄）
	draw_circle(Vector2(0, float_y), 30, Color(1, 0.8, 0.2, 0.8))
	# 内圈（亮黄）
	draw_circle(Vector2(0, float_y), 18, Color(1, 0.9, 0.4, 0.9))
	# 核心（白）
	draw_circle(Vector2(0, float_y), 9, Color(1, 1, 0.8, 1.0))

	# 星型标记（3x放大）
	var icon_size := 12.0
	var dirs := [Vector2(0, -1), Vector2(0.7, -0.7), Vector2(1, 0), Vector2(0.7, 0.7), Vector2(0, 1)]
	for d in dirs:
		draw_line(Vector2(0, float_y), Vector2(0, float_y) + d * icon_size, Color(1, 1, 1, 0.6), 3.0)

func _on_body_entered(body):
	if body.has_method("pickup_skill"):
		body.pickup_skill(skill_data)
		queue_free()
