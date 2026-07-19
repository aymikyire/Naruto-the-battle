extends Area2D

# 螺旋丸持续伤害区域
class_name RasenganArea

var damage_per_tick := 1.0
var duration := 3.0  # 3秒持续
var caster
var _life_time := 0.0

@onready var sprite := $Sprite2D
var hit_timer := 0.0
const TICK_INTERVAL := 0.5  # 每秒2次

func _ready():
	# 自动消失+缩小（从3x缩小到0）
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.01, 0.01), duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _process(delta):
	_life_time += delta
	# 对范围内敌人持续伤害
	hit_timer -= delta
	if hit_timer <= 0:
		hit_timer = TICK_INTERVAL
		for body in get_overlapping_bodies():
			if body != caster and body.has_method("take_damage"):
				body.take_damage(damage_per_tick)
	queue_redraw()

func _draw():
	var progress := _life_time / duration  # 0~1
	var base_radius := 75.0 * (1.0 - progress * 0.8)

	# 外圈光晕（淡蓝）
	draw_circle(Vector2.ZERO, base_radius, Color(0.2, 0.6, 1, 0.15))
	# 主圈（蓝）
	draw_circle(Vector2.ZERO, base_radius * 0.7, Color(0.3, 0.7, 1, 0.3))
	# 核心（亮蓝）
	draw_circle(Vector2.ZERO, base_radius * 0.35, Color(0.6, 0.9, 1, 0.5))
	# 内核心（白）
	draw_circle(Vector2.ZERO, base_radius * 0.15, Color(1, 1, 1, 0.7))

	# 螺旋纹理线（加粗）
	var segments := 6
	for i in range(segments):
		var angle := _life_time * 4.0 + i * TAU / segments
		var spiral_len := base_radius * 0.5
		var x := cos(angle) * spiral_len
		var y := sin(angle) * spiral_len
		draw_line(Vector2.ZERO, Vector2(x, y), Color(0.8, 0.95, 1, 0.3), 4.0)

func _on_body_entered(body):
	pass

func _on_body_exited(body):
	pass
