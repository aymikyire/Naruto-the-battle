extends Node

# 技能管理器 - 处理所有技能的实际效果

func use_skill(slot_idx: int, skill_data, caster):
	match skill_data.type:
		"fireball":
			fire_fireball(caster, skill_data)
		"rasengan":
			use_rasengan(caster, skill_data)
		"shadow_clone":
			use_shadow_clone(caster, skill_data)

# ========== 火球术 ==========
func fire_fireball(caster, skill_data):
	# 向前方发射多个火球，中距离
	# 距离越近击退越远
	# 伤害2格，CD 5s
	var dir := Vector2.RIGHT if caster.sprite.scale.x >= 0 else Vector2.LEFT
	var base_pos: Vector2 = caster.global_position + dir * 60  # 发射起点前移（3x）
	var spread := 45.0  # 扩散角度偏移（3x）

	# 佐助特性：发射4个火球（普通3个）
	var fireball_count := 4 if _is_sasuke(caster) else 3
	var center_offset := (fireball_count - 1) * 0.5  # 居中偏移

	# 检测影分身双倍效果
	var has_clone_buff: bool = caster.has_meta("has_clones") and caster.get_meta("has_clones")
	var volley_count: int = 2 if has_clone_buff else 1

	for volley in range(volley_count):
		var volley_offset := volley * 6  # 两轮稍微错开，不重叠
		for i in range(fireball_count):
			var fireball = preload("res://Scenes/Fireball.tscn").instantiate()
			fireball.direction = dir
			fireball.damage = 1.0  # 每个火球1点
			fireball.global_position = base_pos + Vector2(0, (i - center_offset) * spread + volley_offset)
			fireball.caster = caster
			caster.get_parent().add_child(fireball)

	# 消耗分身
	if has_clone_buff:
		_consume_clone(caster)

# ========== 螺旋丸 ==========
func use_rasengan(caster, skill_data):
	# 短位移 + 小范围持续伤害 2s, 每秒1格
	var dir := Vector2.RIGHT if caster.sprite.scale.x >= 0 else Vector2.LEFT
	caster.global_position += dir * 80  # 短位移

	# 检测影分身双倍效果
	var has_clone_buff: bool = caster.has_meta("has_clones") and caster.get_meta("has_clones")
	var damage: float = 2.0 if has_clone_buff else 1.0  # 双倍伤害

	var rasengan = preload("res://Scenes/RasenganArea.tscn").instantiate()
	# 鸣人特性：螺旋丸范围翻倍
	if _is_naruto(caster):
		rasengan.scale = Vector2(2, 2)
	rasengan.global_position = caster.global_position + dir * 30
	rasengan.caster = caster
	rasengan.damage_per_tick = damage
	rasengan.duration = 2.0
	caster.get_parent().add_child(rasengan)

	# 消耗分身
	if has_clone_buff:
		_consume_clone(caster)

# ========== 影分身 ==========
func use_shadow_clone(caster, skill_data):
	# 检查是否已有分身
	if caster.has_meta("has_clones") and caster.get_meta("has_clones"):
		return  # 已有分身，不叠加

	# 仅创建一个分身（定位在角色身后，由ShadowClone自行跟随）
	var clone_scene = preload("res://Scenes/ShadowClone.tscn")
	var clone = clone_scene.instantiate()
	clone.caster = caster
	caster.get_parent().add_child(clone)
	caster.set_meta("has_clones", true)

# 判断施法者是否是鸣人（千手风格）
func _is_naruto(caster) -> bool:
	return ("is_uchiha" in caster and caster.is_uchiha == false) or ("is_senju" in caster and caster.is_senju == true)

# 判断施法者是否是佐助（宇智波风格）
func _is_sasuke(caster) -> bool:
	return ("is_uchiha" in caster and caster.is_uchiha == true) or ("is_senju" in caster and caster.is_senju == false)

# 消耗分身：找到并移除，清除标记
func _consume_clone(caster):
	if not is_instance_valid(caster):
		return
	var clones = caster.get_tree().get_nodes_in_group("shadow_clones")
	for c in clones:
		if is_instance_valid(c) and c.caster == caster:
			c.disappear()
			return
	# 找不到分身节点但标记还在，清除标记
	caster.set_meta("has_clones", false)
