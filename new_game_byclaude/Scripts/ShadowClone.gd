extends Node2D

# 影分身 - 跟随施法者身后，显示角色贴图
# 效果：未受伤→下次攻击/技能与本体同时释放（双倍视觉效果）
#       受伤→吸收2点伤害后消失

class_name ShadowClone

var caster: Node2D
var absorb_remaining := 2.0
var _lifetime := 0.0

@onready var _sprite: Sprite2D = $CloneSprite

func _ready():
	add_to_group("shadow_clones")
	modulate = Color(1, 1, 1, 0.6)
	_copy_caster_texture()

func _copy_caster_texture():
	if not caster or not caster.has_node("Sprite2D"):
		return
	var cs: Sprite2D = caster.get_node("Sprite2D")
	if cs.texture:
		_sprite.texture = cs.texture
	_sprite.scale = cs.scale
	_sprite.centered = cs.centered

func _process(delta):
	_lifetime += delta
	if not caster or not is_instance_valid(caster):
		queue_free()
		return

	# 定期刷新贴图（防止引用丢失）
	if not _sprite.texture and caster.has_node("Sprite2D"):
		var cs: Sprite2D = caster.get_node("Sprite2D")
		if cs.texture:
			_sprite.texture = cs.texture

	# 同步朝向
	var facing := 1.0
	if caster.has_node("Sprite2D"):
		var cs: Sprite2D = caster.get_node("Sprite2D")
		facing = sign(cs.scale.x)
		_sprite.scale.x = abs(_sprite.scale.x) * facing

	var offset := Vector2(-50 * facing, 0)
	global_position = caster.global_position + offset

# 吸收伤害，返回未被吸收的剩余伤害
func absorb_damage(amount: float) -> float:
	var absorbed: float = min(amount, absorb_remaining)
	absorb_remaining -= absorbed
	modulate = Color(1, 0.3, 0.3, 0.9)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0.6), 0.1)

	if absorb_remaining <= 0:
		disappear()

	return amount - absorbed

# 临时切换为普通攻击贴图，duration秒后恢复为施法者当前贴图
func flash_attack(tex: Texture2D, duration: float):
	_sprite.texture = tex
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		_sync_to_caster_texture()

# 临时切换为特殊攻击贴图，duration秒后恢复为施法者当前贴图
func flash_special(texture: Texture2D, scale: Vector2, duration: float):
	_sprite.texture = texture
	_sprite.scale = scale
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		_sync_to_caster_texture()
		_sync_to_caster_scale()

# 与施法者贴图同步
func _sync_to_caster_texture():
	if not caster or not caster.has_node("Sprite2D"):
		return
	var cs: Sprite2D = caster.get_node("Sprite2D")
	if cs.texture:
		_sprite.texture = cs.texture

func _sync_to_caster_scale():
	if not caster or not caster.has_node("Sprite2D"):
		return
	var cs: Sprite2D = caster.get_node("Sprite2D")
	_sprite.scale = cs.scale

func disappear():
	AudioManager.play_sfx("poof", global_position)
	if caster and is_instance_valid(caster):
		caster.set_meta("has_clones", false)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	await tw.finished
	if is_instance_valid(self):
		queue_free()
