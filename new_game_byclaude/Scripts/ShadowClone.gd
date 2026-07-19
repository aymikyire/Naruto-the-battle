extends CharacterBody2D

# 影分身
class_name ShadowClone

var caster
var max_absorb := 2.0
var absorbed_damage := 0.0
var _life_time := 3.0

@onready var sprite := $Sprite2D

func _ready():
	# 短暂闪烁表示生成
	modulate = Color(1, 1, 1, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)

func _process(delta):
	_life_time -= delta
	if _life_time <= 0:
		# 自动消失
		notify_caster()
		queue_free()
	queue_redraw()

func _draw():
	# 半透明分身外观
	var pulse := 0.8 + sin(_life_time * 3.0) * 0.2

	# 外圈（透明紫）
	draw_circle(Vector2.ZERO, 12, Color(0.8, 0.3, 0.8, 0.2 * pulse))
	# 身体（半透红）
	draw_circle(Vector2.ZERO, 9, Color(1, 0.2, 0.2, 0.35 * pulse))
	# 边框
	draw_circle(Vector2.ZERO, 9, Color(1, 0.5, 0.5, 0.5 * pulse), false, 1.5)

func take_damage(amount: float):
	absorbed_damage += amount
	# 受击闪烁
	modulate = Color(1, 0.5, 0.5, 0.8)
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)

	if absorbed_damage >= max_absorb:
		notify_caster()
		queue_free()

func notify_caster():
	if caster and is_instance_valid(caster):
		# 分身消失，取消双倍状态
		# 检查是否还有其他分身
		var other_clones = get_tree().get_nodes_in_group("shadow_clones")
		var alive = false
		for clone in other_clones:
			if clone != self and is_instance_valid(clone):
				alive = true
				break
		if not alive:
			caster.set_meta("has_clones", false)
