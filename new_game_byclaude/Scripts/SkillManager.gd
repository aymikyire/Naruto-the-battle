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
    # 向前方发射三个火球，中距离
    # 距离越近击退越远
    # 伤害2格，CD 5s
    var dir := Vector2.RIGHT if caster.sprite.scale.x >= 0 else Vector2.LEFT
    var base_pos: Vector2 = caster.global_position + dir * 30
    var spread := 15.0  # 扩散角度偏移

    for i in range(3):
        var fireball = preload("res://Scenes/Fireball.tscn").instantiate()
        fireball.direction = dir
        fireball.damage = 2.0
        fireball.global_position = base_pos + Vector2(0, (i - 1) * spread)
        fireball.caster = caster
        caster.get_parent().add_child(fireball)

# ========== 螺旋丸 ==========
func use_rasengan(caster, skill_data):
    # 短位移 + 小范围持续伤害 2s, 每秒1格
    var dir := Vector2.RIGHT if caster.sprite.scale.x >= 0 else Vector2.LEFT
    caster.global_position += dir * 80  # 短位移

    var rasengan = preload("res://Scenes/RasenganArea.tscn").instantiate()
    rasengan.global_position = caster.global_position + dir * 30
    rasengan.caster = caster
    rasengan.damage_per_tick = 1.0
    rasengan.duration = 2.0
    caster.get_parent().add_child(rasengan)

# ========== 影分身 ==========
func use_shadow_clone(caster, skill_data):
    # 分两个分身
    # 未受伤 → 双倍伤害
    # 受伤>2 → 分身消失（可挡2格伤害）
    var clone_scene = preload("res://Scenes/ShadowClone.tscn")

    var offset_left = Vector2(-30, 20)
    var offset_right = Vector2(-30, -20)

    var clone1 = clone_scene.instantiate()
    clone1.global_position = caster.global_position + offset_left
    clone1.caster = caster
    clone1.max_absorb = 2.0
    caster.get_parent().add_child(clone1)

    var clone2 = clone_scene.instantiate()
    clone2.global_position = caster.global_position + offset_right
    clone2.caster = caster
    clone2.max_absorb = 2.0
    caster.get_parent().add_child(clone2)

    # 标记本体有双倍状态
    caster.set_meta("has_clones", true)

    # 监听分身消失
    clone1.tree_exited.connect(_on_clone_destroyed.bind(caster, clone1, clone2))
    clone2.tree_exited.connect(_on_clone_destroyed.bind(caster, clone2, clone1))

func _on_clone_destroyed(caster, destroyed_clone, other_clone):
    if not is_instance_valid(other_clone) or not is_instance_valid(caster):
        caster.set_meta("has_clones", false)
        return
    # 如果全消失
    if not is_instance_valid(destroyed_clone) or not is_instance_valid(other_clone):
        caster.set_meta("has_clones", false)
