extends Area2D

# 火球术投射物
class_name FireballProjectile

var direction := Vector2.RIGHT
var damage := 2.0
var speed := 350.0
var caster
var max_distance := 500.0
var traveled := 0.0
var _pulse_time := 0.0

@onready var sprite := $Sprite2D

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta):
	var move = direction * speed * delta
	global_position += move
	traveled += move.length()
	_pulse_time += delta
	queue_redraw()

	if traveled >= max_distance:
		queue_free()

func _draw():
	# 外圈火焰（橙色）
	var outer_radius := 6.0 + sin(_pulse_time * 10.0) * 1.0
	draw_circle(Vector2.ZERO, outer_radius, Color(1, 0.5, 0, 0.6))
	# 内核（黄色）
	draw_circle(Vector2.ZERO, 4.0, Color(1, 0.8, 0.2, 0.9))
	# 核心（白色）
	draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 0.8, 1.0))
	# 尾迹
	var trail_dir = -direction.normalized()
	draw_circle(trail_dir * 3, 3.0, Color(1, 0.5, 0, 0.3))
	draw_circle(trail_dir * 6, 2.0, Color(1, 0.3, 0, 0.15))

func _on_body_entered(body):
	if body == caster:
		return

	if body.has_method("take_damage"):
		# 击退效果：距离越近击退越远
		var dist = caster.global_position.distance_to(body.global_position) if caster else 999
		var knockback_strength = max(200.0 - dist, 20.0)  # 越近击退越强
		body.take_damage(damage)

		if body.has_method("knockback"):
			body.knockback(direction * knockback_strength)

	queue_free()

func _on_area_entered(area):
	if area == caster:
		return
	# 对其他area的效果
