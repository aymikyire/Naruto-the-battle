extends CharacterBody2D

# AI对手 - 自动打野、发育、寻找玩家战斗
class_name EnemyAI

# 阵营常量（避免循环引用Player）
const TEAM_UCHIHA := 0
const TEAM_SENJU := 1

const MAX_HP := 5
const SPEED := 90.0  # 初始移速为玩家的0.9倍
const MAP_WIDTH := 1500
const MAP_HEIGHT := 1500
const SPRITE_SCALE := 0.04

var current_hp := MAX_HP
var _bob_time := 0.0
var team := TEAM_SENJU
var target: Node2D = null  # 当前目标
var camp_target = null  # 目标野怪营地
var state := State.IDLE

enum State { IDLE, FARMING, SEEKING, FIGHTING, RETURNING }

# AI状态机
var ai_timer := 0.0
const DECISION_INTERVAL := 1.0  # 每秒决策一次

# 技能
var skill_slots := [null, null, null]
var skill_cooldowns := [0.0, 0.0, 0.0]
var attack_combo_counter := 0
var attack_timer := 0.0

# 阵营专属
var is_senju := true  # AI默认千手一族
var basic_attack_damage := 1.0
var attack_speed := 1.0  # 攻击间隔秒

# 引用
@onready var sprite := $Sprite2D
@onready var health_bar := $HealthBar
@onready var character_visual := $CharacterVisual

func _ready():
    add_to_group("players")
    current_hp = MAX_HP
    _update_health_text()
    health_bar.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
    # 设置贴图缩放
    sprite.scale = Vector2(-SPRITE_SCALE, SPRITE_SCALE)
    sprite.position = Vector2.ZERO
    # 隐藏_draw角色视觉（贴图已替代）
    if character_visual:
        character_visual.visible = false

func _update_health_text():
    health_bar.text = str(current_hp) + "/" + str(MAX_HP)

func _process(delta):
    # CD更新
    for i in range(skill_cooldowns.size()):
        if skill_cooldowns[i] > 0:
            skill_cooldowns[i] -= delta

    # 连击计时
    if attack_timer > 0:
        attack_timer -= delta

    # 行走浮动动画
    if velocity.length() > 0:
        _bob_time += delta * 8.0
        sprite.position.y = sin(_bob_time) * 2.0
    else:
        _bob_time = 0.0
        sprite.position.y = 0.0

func _physics_process(delta):
    ai_timer -= delta
    if ai_timer <= 0:
        ai_timer = DECISION_INTERVAL
        make_decision()

    execute_behavior(delta)
    move_and_slide()

    # 边界限制
    global_position = Vector2(
        clamp(global_position.x, 50, MAP_WIDTH - 50),
        clamp(global_position.y, 50, MAP_HEIGHT - 50)
    )

func make_decision():
    # 决策逻辑
    var nearest_enemy = find_nearest_enemy()

    if nearest_enemy and global_position.distance_to(nearest_enemy.global_position) < 400:
        # 附近有敌人 → 战斗
        target = nearest_enemy
        state = State.FIGHTING
        return

    # 检查技能数量
    var skill_count = 0
    for s in skill_slots:
        if s != null:
            skill_count += 1

    if skill_count < 2:
        # 技能不够 → 去打野
        state = State.FARMING
        camp_target = find_nearest_camp()
        return

    # 技能够了 → 去找敌人
    state = State.SEEKING
    target = find_nearest_enemy()

func find_nearest_enemy():
    var players = get_tree().get_nodes_in_group("players")
    var nearest = null
    var min_dist = INF
    for p in players:
        if p == self:
            continue
        var dist = global_position.distance_to(p.global_position)
        if dist < min_dist:
            min_dist = dist
            nearest = p
    return nearest

func find_nearest_camp():
    var camps = get_tree().get_nodes_in_group("monster_camps")
    var nearest = null
    var min_dist = INF
    for c in camps:
        if c.has_alive_monsters():
            var dist = global_position.distance_to(c.global_position)
            if dist < min_dist:
                min_dist = dist
                nearest = c
    return nearest

func execute_behavior(delta):
    match state:
        State.IDLE:
            velocity = Vector2.ZERO
        State.FARMING:
            if camp_target and is_instance_valid(camp_target):
                move_to(camp_target.global_position)
                # 到达营地附近攻击野怪
                if global_position.distance_to(camp_target.global_position) < 100:
                    auto_attack_monsters()
            else:
                camp_target = find_nearest_camp()
        State.SEEKING:
            if target and is_instance_valid(target):
                move_to(target.global_position)
            else:
                state = State.FARMING
        State.FIGHTING:
            if target and is_instance_valid(target):
                fight_target()
            else:
                state = State.SEEKING
        State.RETURNING:
            # 回基地
            var base = get_tree().get_nodes_in_group("bases")
            if base.size() > 0:
                var my_base = base[1] if team == TEAM_SENJU else base[0]
                move_to(my_base.global_position)
                if global_position.distance_to(my_base.global_position) < 50:
                    state = State.FARMING

func move_to(pos: Vector2):
    var dir = (pos - global_position).normalized()
    velocity = dir * SPEED
    # 面向
    if abs(dir.x) > 0.1:
        sprite.scale.x = sign(dir.x) * SPRITE_SCALE

func fight_target():
    if not target or not is_instance_valid(target):
        state = State.SEEKING
        return

    var dist = global_position.distance_to(target.global_position)

    # 追敌
    if dist > 80:
        move_to(target.global_position)
    else:
        # 攻击
        velocity = Vector2.ZERO
        auto_attack()

    # 使用技能
    for i in range(skill_slots.size()):
        if skill_slots[i] != null and skill_cooldowns[i] <= 0:
            use_skill(i, target)

func auto_attack():
    if attack_timer > 0:
        return
    attack_timer = attack_speed

    # 攻击视觉特效（横向拉伸脉冲）
    var dir_sign = sign(sprite.scale.x)
    sprite.scale = Vector2(dir_sign * SPRITE_SCALE * 1.3, SPRITE_SCALE * 0.8)
    var tw = create_tween()
    tw.tween_property(sprite, "scale", Vector2(dir_sign * SPRITE_SCALE, SPRITE_SCALE), 0.12)

    attack_combo_counter += 1

    # 统一普攻：每次 0.5 伤害（与玩家一致）
    if target and is_instance_valid(target):
        target.take_damage(0.5)

    if is_senju:
        # 千手一族：第3次攻击击退（无减速）
        if attack_combo_counter >= 3:
            attack_combo_counter = 0
            if target and is_instance_valid(target):
                var dir = (target.global_position - global_position).normalized()
                if target.has_method("knockback"):
                    target.knockback(dir * 100)
    else:
        # 宇智波一族：第3次无特效，第4次位移突进
        if attack_combo_counter >= 4:
            attack_combo_counter = 0
            if target and is_instance_valid(target):
                var dir = (target.global_position - global_position).normalized()
                global_position += dir * 100

func auto_attack_monsters():
    var monsters = get_tree().get_nodes_in_group("monsters")
    var nearest_monster = null
    var min_dist = INF
    for m in monsters:
        if m.current_hp > 0:
            var dist = global_position.distance_to(m.global_position)
            if dist < min_dist:
                min_dist = dist
                nearest_monster = m

    if nearest_monster:
        var dist = global_position.distance_to(nearest_monster.global_position)
        if dist > 50:
            move_to(nearest_monster.global_position)
        else:
            velocity = Vector2.ZERO
            if attack_timer <= 0:
                attack_timer = 1.0
                nearest_monster.take_damage(1.0)

func use_skill(slot_idx: int, _target):
    if slot_idx < 0 or slot_idx >= skill_slots.size():
        return
    if skill_slots[slot_idx] == null:
        return
    if skill_cooldowns[slot_idx] > 0:
        return

    skill_cooldowns[slot_idx] = skill_slots[slot_idx].cooldown
    # 使用技能
    var skill_manager = $SkillManager
    skill_manager.use_skill(slot_idx, skill_slots[slot_idx], self)

func pickup_skill(skill_data):
    for i in range(skill_slots.size()):
        if skill_slots[i] == null:
            skill_slots[i] = skill_data
            return true
    return false

func take_damage(amount: float):
    current_hp -= amount
    _update_health_text()
    modulate = Color(1, 0.3, 0.3)
    await get_tree().create_timer(0.1).timeout
    if is_instance_valid(self):
        modulate = Color(1, 1, 1, 1)

    if current_hp <= 0:
        die()

func knockback(vector: Vector2):
    velocity = vector

func die():
    # 掉落随机技能
    var owned = []
    for i in range(skill_slots.size()):
        if skill_slots[i] != null:
            owned.append(i)
    if owned.size() > 0:
        var drop_idx = owned[randi() % owned.size()]
        var drop = preload("res://Scenes/SkillPickup.tscn").instantiate()
        drop.skill_data = skill_slots[drop_idx]
        drop.global_position = global_position
        get_parent().add_child(drop)
        skill_slots[drop_idx] = null

    current_hp = MAX_HP
    _update_health_text()
    respawn()

func respawn():
    var spawn_pos = Vector2(MAP_WIDTH-100, MAP_HEIGHT/2)
    global_position = spawn_pos
    velocity = Vector2.ZERO
    visible = false
    await get_tree().create_timer(3.0).timeout
    visible = true
    modulate = Color(1, 1, 1, 1)
    state = State.FARMING
