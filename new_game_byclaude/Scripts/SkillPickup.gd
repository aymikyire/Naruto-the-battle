extends Area2D

# 技能拾取物
class_name SkillPickup

var skill_data = null
var lifetime := 30.0  # 30秒无人捡自动消失
var blink_timer := 0.0
var _float_time := 0.0

# 卷轴贴图
const FIRE_SCROLL := preload("res://Assets/红色卷轴(火球术).png")
const WATER_SCROLL := preload("res://Assets/蓝色卷轴(螺旋丸).png")
const SHADOW_SCROLL := preload("res://Assets/紫色卷轴(影分身).png")

@onready var sprite := $Sprite2D
@onready var label := $Label

func _ready():
	add_to_group("skill_pickups")
	body_entered.connect(_on_body_entered)
	if skill_data:
		label.text = skill_data.get("name", "技能")
		# 根据技能类型设置贴图
		match skill_data.get("type", ""):
			"fireball":
				sprite.texture = FIRE_SCROLL
			"rasengan":
				sprite.texture = WATER_SCROLL
			"shadow_clone":
				sprite.texture = SHADOW_SCROLL
		# 贴图放大约3倍（原_draw外圈42px→贴图显示约250px）
		sprite.scale = Vector2(0.045, 0.045)

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

func _on_body_entered(body):
	if body.has_method("pickup_skill"):
		body.pickup_skill(skill_data)
		queue_free()
