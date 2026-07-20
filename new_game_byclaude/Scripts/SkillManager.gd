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

# ========== 工具：获取分身节点 ==========
func _get_clone(caster):
	if not caster.has_meta("has_clones") or not caster.get_meta("has_clones"):
		return null
	var clones = caster.get_tree().get_nodes_in_group("shadow_clones")
	for c in clones:
		if is_instance_valid(c) and c.caster == caster:
			return c
	return null

# ========== 火球术 ==========
func fire_fireball(caster, skill_data):
	# 音效：发射火球
	AudioManager.play_sfx("shoot", caster.global_position)
	var dir := Vector2.RIGHT if caster.sprite.scale.x >= 0 else Vector2.LEFT
	var base_pos: Vector2 = caster.global_position + dir * 60
	var spread := 45.0
	var fireball_count := 4 if _is_sasuke(caster) else 3
	var center_offset := (fireball_count - 1) * 0.5

	# 本体发射
	_spawn_fireballs_dir(base_pos, dir, spread, fireball_count, center_offset, 0, caster)

	# 影分身存在 → 额外发射一组，偏移20px
	var clone = _get_clone(caster)
	if clone:
		var facing: float = sign(caster.sprite.scale.x)
		var clone_offset: float = 20.0 * facing
		var clone_pos: Vector2 = base_pos + Vector2(clone_offset, 0)
		_spawn_fireballs_dir(clone_pos, dir, spread, fireball_count, center_offset, 0, caster)
		# 确保分身不因任何异常清空meta而消失
		caster.set_meta("has_clones", true)

# 辅助：生成一组火球
func _spawn_fireballs_dir(base_pos: Vector2, dir: Vector2, spread: float,
		count: int, center_offset: float, volley_offset: float, caster):
	for i in range(count):
		var fireball = preload("res://Scenes/Fireball.tscn").instantiate()
		fireball.direction = dir
		fireball.damage = 1.0
		fireball.global_position = base_pos + Vector2(0, (i - center_offset) * spread + volley_offset)
		fireball.caster = caster
		caster.get_parent().add_child(fireball)

# ========== 螺旋丸 ==========
func use_rasengan(caster, skill_data):
	# 音效：螺旋丸
	AudioManager.play_sfx("rasengan", caster.global_position)
	var dir := Vector2.RIGHT if caster.sprite.scale.x >= 0 else Vector2.LEFT
	caster.global_position += dir * 80  # 短位移

	var damage: float = 1.0

	# 本体螺旋丸
	_spawn_rasengan(caster, dir, damage)

	# 影分身存在 → 额外放一个，偏移20px
	var clone = _get_clone(caster)
	if clone:
		var facing: float = sign(caster.sprite.scale.x)
		var offset_pos: Vector2 = caster.global_position + Vector2(20.0 * facing, 0)
		var rasengan2 = preload("res://Scenes/RasenganArea.tscn").instantiate()
		if _is_naruto(caster):
			rasengan2.scale = Vector2(2, 2)
		rasengan2.global_position = offset_pos + dir * 30
		rasengan2.caster = caster
		rasengan2.damage_per_tick = damage
		rasengan2.duration = 2.0
		caster.get_parent().add_child(rasengan2)
		# 确保分身不消失
		caster.set_meta("has_clones", true)

func _spawn_rasengan(caster, dir: Vector2, damage: float):
	var rasengan = preload("res://Scenes/RasenganArea.tscn").instantiate()
	if _is_naruto(caster):
		rasengan.scale = Vector2(2, 2)
	rasengan.global_position = caster.global_position + dir * 30
	rasengan.caster = caster
	rasengan.damage_per_tick = damage
	rasengan.duration = 2.0
	caster.get_parent().add_child(rasengan)

# ========== 影分身 ==========
func use_shadow_clone(caster, skill_data):
	# 音效：召唤分身
	AudioManager.play_sfx("poof", caster.global_position)
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

# 消耗分身：找到并移除，清除标记（保留给普攻/受伤使用）
func _consume_clone(caster):
	if not is_instance_valid(caster):
		return
	var clones = caster.get_tree().get_nodes_in_group("shadow_clones")
	for c in clones:
		if is_instance_valid(c) and c.caster == caster:
			c.disappear()
			return
	caster.set_meta("has_clones", false)
