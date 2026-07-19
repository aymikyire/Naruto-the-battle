extends Node2D
class_name SimpleCharacter

# 简单角色绘制 - 使用 _draw() 绘制可识别的角色图形
# 在没有美术资源时提供基本的视觉表现

enum Type { PLAYER, ENEMY, MONSTER }

var type := Type.PLAYER
var facing_dir := Vector2.RIGHT
var is_moving := false
var attack_flash := 0.0

var _bob_time := 0.0

func _process(delta):
	if is_moving:
		_bob_time += delta * 8.0
	else:
		_bob_time = 0.0

	if attack_flash > 0:
		attack_flash -= delta * 5.0

	queue_redraw()


func _draw():
	var body_color: Color
	var accent_color: Color
	var outline_color: Color

	match type:
		Type.PLAYER:
			body_color = Color(1, 0.2, 0.2)
			accent_color = Color(1, 0.5, 0.3)
			outline_color = Color(0.6, 0.1, 0.1)
		Type.ENEMY:
			body_color = Color(0.2, 0.3, 1)
			accent_color = Color(0.4, 0.6, 1)
			outline_color = Color(0.1, 0.15, 0.6)
		Type.MONSTER:
			body_color = Color(0.2, 0.8, 0.2)
			accent_color = Color(0.4, 1, 0.4)
			outline_color = Color(0.1, 0.5, 0.1)

	var bob := sin(_bob_time) * 2.0 if is_moving else 0.0
	var center := Vector2(0, bob)
	var dir := facing_dir.normalized()

	# === 身体（主圆）===
	draw_circle(center, 11, body_color)
	draw_circle(center, 11, outline_color, false, 1.5)

	# === 方向指示器（头/前方的三角形）===
	var head_pos := center + dir * 8
	draw_circle(head_pos, 4, accent_color)
	draw_circle(head_pos, 4, outline_color, false, 1.0)

	# === 眼睛（两个小白点）===
	if type != Type.MONSTER:
		var perp := Vector2(-dir.y, dir.x)
		var eye_center := head_pos + dir * 3
		draw_circle(eye_center + perp * 2.5, 1.5, Color(1, 1, 1))
		draw_circle(eye_center - perp * 2.5, 1.5, Color(1, 1, 1))
		draw_circle(eye_center + perp * 2.5, 1.5, Color(0, 0, 0), false, 0.5)
		draw_circle(eye_center - perp * 2.5, 1.5, Color(0, 0, 0), false, 0.5)

	# === 攻击特效 ===
	if attack_flash > 0:
		var alpha := minf(attack_flash * 1.5, 0.6)
		# 闪光圈
		draw_circle(center, 14, Color(1, 1, 1, alpha))
		# 斩击弧线
		var perp := Vector2(-dir.y, dir.x)
		var arc_start := center + dir * 6 + perp * 6
		var arc_end := center + dir * 16 + perp * 2
		draw_line(arc_start, arc_end, Color(1, 1, 1, alpha + 0.3), 2.5)


func trigger_attack():
	attack_flash = 1.0
