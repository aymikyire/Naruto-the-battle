extends Area2D

# 生命球 - 拾取后永久提升5点最大生命值

var lifetime := 30.0  # 30秒无人捡自动消失
var _float_time := 0.0

const ORB_TEX := preload("res://Assets/生命球.png")

func _ready():
	add_to_group("hp_orbs")
	body_entered.connect(_on_body_entered)
	collision_mask = 1

	# 创建贴图精灵
	var spr = Sprite2D.new()
	spr.texture = ORB_TEX
	spr.scale = Vector2(0.27, 0.27)  # 放大约3倍显示
	add_child(spr)

func _process(delta):
	_float_time += delta
	lifetime -= delta
	if lifetime <= 0:
		if lifetime < -3.0:
			queue_free()
		elif int(_float_time * 10) % 2 == 0:
			visible = false
		else:
			visible = true

func _on_body_entered(body):
	if body.has_method("increase_max_hp"):
		body.increase_max_hp(5.0)
		if body.has_method("heal"):
			body.heal(5.0)
		queue_free()
