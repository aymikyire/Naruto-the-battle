extends Node2D

# 影分身 - 跟随施法者身后
# 效果：未受伤→下次攻击/技能双倍后消失 | 受伤→吸收2点伤害后消失
class_name ShadowClone

var caster: Node2D
var absorb_remaining := 2.0
var _lifetime := 0.0

func _ready():
	add_to_group("shadow_clones")
	modulate = Color(1, 1, 1, 0.7)
	scale = Vector2(3, 3)

func _process(delta):
	_lifetime += delta
	if not caster or not is_instance_valid(caster):
		queue_free()
		return
	# 跟随施法者，定位在身后（根据朝向）
	var facing := 1.0
	if caster.has_node("Sprite2D"):
		facing = sign(caster.get_node("Sprite2D").scale.x)
	# 朝向右侧时，后面是左边（-X）；朝向左时后面是右边（+X）
	var offset := Vector2(-40 * facing, 0)
	global_position = caster.global_position + offset
	queue_redraw()

func _draw():
	var pulse := 0.8 + sin(_lifetime * 4.0) * 0.2
	# 外圈光晕（透明紫）
	draw_circle(Vector2.ZERO, 14, Color(0.8, 0.3, 0.8, 0.15 * pulse))
	# 身体（半透明紫）
	draw_circle(Vector2.ZERO, 10, Color(0.6, 0.4, 1.0, 0.35 * pulse))
	# 边框
	draw_circle(Vector2.ZERO, 10, Color(0.8, 0.5, 1.0, 0.5 * pulse), false, 1.5)
	# 内部光点
	draw_circle(Vector2.ZERO, 3, Color(1, 1, 1, 0.7 * pulse))

# 吸收伤害，返回未被吸收的剩余伤害
func absorb_damage(amount: float) -> float:
	var absorbed: float = min(amount, absorb_remaining)
	absorb_remaining -= absorbed
	# 受击闪烁
	modulate = Color(1, 0.3, 0.3, 0.9)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0.7), 0.1)

	if absorb_remaining <= 0:
		disappear()

	return amount - absorbed

func disappear():
	AudioManager.play_sfx("poof", global_position)
	if caster and is_instance_valid(caster):
		caster.set_meta("has_clones", false)
	# 消散渐隐效果
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	await tw.finished
	if is_instance_valid(self):
		queue_free()
