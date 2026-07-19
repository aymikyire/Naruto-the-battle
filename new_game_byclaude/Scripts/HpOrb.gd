extends Area2D

# 生命球 - 拾取后永久提升5点最大生命值

var lifetime := 30.0  # 30秒无人捡自动消失
var _float_time := 0.0

func _ready():
	add_to_group("hp_orbs")
	body_entered.connect(_on_body_entered)
	# 碰撞检测：检测物理层1（玩家和AI所在层）
	collision_mask = 1

func _process(delta):
	_float_time += delta
	lifetime -= delta
	if lifetime <= 0:
		# 闪烁消失
		if lifetime < -3.0:
			queue_free()
		elif int(_float_time * 10) % 2 == 0:
			visible = false
		else:
			visible = true
	queue_redraw()

func _draw():
	var bob := sin(_float_time * 3.0) * 3.0

	# 外圈光晕（淡红）
	draw_circle(Vector2(0, bob), 42, Color(1, 0.3, 0.3, 0.15))
	# 主圈（红）
	draw_circle(Vector2(0, bob), 30, Color(1, 0.2, 0.2, 0.8))
	# 内圈（亮红）
	draw_circle(Vector2(0, bob), 18, Color(1, 0.4, 0.4, 0.9))
	# 核心（白）
	draw_circle(Vector2(0, bob), 9, Color(1, 1, 1, 1.0))

	# 十字生命标记
	var s := 8.0
	# 竖线
	draw_line(Vector2(0, -s) + Vector2(0, bob), Vector2(0, s) + Vector2(0, bob), Color(1, 1, 1, 0.7), 3.0)
	# 横线
	draw_line(Vector2(-s, 0) + Vector2(0, bob), Vector2(s, 0) + Vector2(0, bob), Color(1, 1, 1, 0.7), 3.0)

func _on_body_entered(body):
	if body.has_method("increase_max_hp"):
		body.increase_max_hp(5.0)
		# 拾取反馈：闪光
		if body.has_method("heal"):
			body.heal(5.0)
		queue_free()
