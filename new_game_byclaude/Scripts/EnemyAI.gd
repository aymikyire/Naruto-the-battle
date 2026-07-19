extends CharacterBody2D

# AI对手 - 自动打野、发育、寻找玩家战斗
class_name EnemyAI

# 阵营常量（避免循环引用Player）
const TEAM_UCHIHA := 0
const TEAM_SENJU := 1

const MAX_HP := 10
const SPEED := 90.0  # 初始移速为玩家的0.9倍
const MAP_WIDTH := 1500
const MAP_HEIGHT := 1500
const SPRITE_SCALE := 0.04

var current_hp := MAX_HP
var _bob_time := 0.0
var team := TEAM_SENJU
var target = null  # 当前攻击目标（玩家/野怪）
var camp_target = null  # 目标野怪营地（野怪死光后去等刷新）
var state := State.IDLE
var _patrol_index := 0  # 巡逻点索引
var _patrol_target_pos := Vector2.ZERO  # 硬编码巡逻目标坐标

enum State { IDLE, FARMING, SEEKING, FIGHTING, ATTACKING_BASE, RETURNING }

# 已知5个营地坐标（兜底巡逻用）
const CAMP_POSITIONS := [
    Vector2(200, 580),
    Vector2(400, 400),
    Vector2(750, 300),
    Vector2(1100, 400),
    Vector2(1300, 580),
]

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

# 角色贴图
const SASUKE_TEX := preload("res://Assets/player_sasuke.png")
const NARUTO_TEX := preload("res://Assets/player_naruto.png")

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

    # 角色分配（从GameManager读取）
    is_senju = not GameManager.is_swap_mode  # 正常模式敌方千手，互换模式敌方宇智波
    if not is_senju:
        # 敌方是宇智波/佐助
        sprite.texture = SASUKE_TEX

    # 初始绘制密卷标记点
    queue_redraw()

    # 添加状态调试标签
    var debug_label = Label.new()
    debug_label.name = "DebugLabel"
    debug_label.position = Vector2(-50, -55)
    debug_label.size = Vector2(100, 14)
    debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    debug_label.add_theme_color_override("font_color", Color(0, 1, 1))
    debug_label.add_theme_font_size_override("font_size", 10)
    add_child(debug_label)

    # 开局直接打野发育（先硬编码走到最近的营地5）
    state = State.FARMING
    target = null
    camp_target = null
    _patrol_index = 4  # 从最近的营地5(1300,580)开始
    _patrol_target_pos = CAMP_POSITIONS[4]
    # 同时尝试查找真实野怪
    find_farming_target()

func update_debug_label():
    var label = get_node_or_null("DebugLabel")
    if not label:
        return
    var state_names = ["IDLE", "FARMING", "SEEKING", "FIGHTING", "ATK_BASE", "RETURN"]
    var txt = state_names[state]
    if target and is_instance_valid(target):
        txt += "→" + target.name
    elif _patrol_target_pos != Vector2.ZERO:
        txt += "→ Patrol"
    label.text = txt

func _update_health_text():
    health_bar.text = str(current_hp) + "/" + str(MAX_HP)

func _draw():
    # 在血条上方绘制金黄色密卷标记点
    var skill_count := 0
    for s in skill_slots:
        if s != null:
            skill_count += 1
    if skill_count == 0:
        return

    var dot_y := -48  # 血条上方
    var dot_radius := 5.0
    var dot_spacing := 14.0
    var start_x := -(float(skill_count) - 1.0) * dot_spacing / 2.0

    for i in range(skill_count):
        var dot_pos := Vector2(start_x + i * dot_spacing, dot_y)
        # 外圈光晕
        draw_circle(dot_pos, dot_radius + 2, Color(1, 0.85, 0.2, 0.3))
        # 实心金黄点
        draw_circle(dot_pos, dot_radius, Color(1, 0.8, 0.2, 1.0))
        # 高光
        draw_circle(dot_pos + Vector2(-1.5, -1.5), dot_radius * 0.4, Color(1, 1, 0.6, 0.8))

func _process(delta):
    # CD更新
    for i in range(skill_cooldowns.size()):
        if skill_cooldowns[i] > 0:
            skill_cooldowns[i] -= delta

    # 连击计时
    if attack_timer > 0:
        attack_timer -= delta

    # 更新调试标签
    update_debug_label()

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
    var player = find_nearest_enemy()

    # 1. 玩家已死/复活中 → 拆基地
    if not player or not is_instance_valid(player) or not player.visible:
        state = State.ATTACKING_BASE
        return

    # 2. 统计当前技能数量
    var skill_count := 0
    for s in skill_slots:
        if s != null:
            skill_count += 1

    # 3. 技能少于2个 → 优先打野发育
    if skill_count < 2:
        # 但如果玩家贴脸（<200px），立即自卫反击
        if player and is_instance_valid(player):
            var dist := global_position.distance_to(player.global_position)
            if dist < 200:
                target = player
                state = State.FIGHTING
                return
        # 否则继续安心打野
        if state != State.FARMING:
            state = State.FARMING
            find_farming_target()
        elif not _is_farming_target_valid():
            find_farming_target()
        return

    # 4. 技能 >= 2个 → 主动找玩家战斗
    var dist_to_player := INF
    if player:
        dist_to_player = global_position.distance_to(player.global_position)

    if dist_to_player < 600:
        target = player
        state = State.FIGHTING
    else:
        target = player
        state = State.SEEKING

# 检查当前打野目标是否仍然有效
func _is_farming_target_valid() -> bool:
    # 有活的野怪目标
    if target and is_instance_valid(target):
        if _is_pickup_target(target):
            return true  # 密卷还没消失，继续去捡
        return target.has_method("take_damage") and target.current_hp > 0
    # 有营地目标且营地还有活的野怪
    if camp_target and is_instance_valid(camp_target):
        return camp_target.has_alive_monsters()
    # 硬编码巡逻
    if _patrol_target_pos != Vector2.ZERO:
        return true
    return false

# ========== 寻找目标 ==========

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

func find_enemy_base():
    var bases = get_tree().get_nodes_in_group("bases")
    for b in bases:
        if is_instance_valid(b) and b.team != team:
            return b
    return null

# 判断目标是否是密卷拾取物
func _is_pickup_target(node) -> bool:
    return node is SkillPickup and node.skill_data != null

# 搜索附近的密卷拾取物（找最近的一个）
func _scan_nearby_pickup() -> bool:
    var nearest = null
    var min_dist = 400.0
    for p in get_tree().get_nodes_in_group("skill_pickups"):
        if is_instance_valid(p) and p is SkillPickup and p.skill_data != null:
            var d = global_position.distance_to(p.global_position)
            if d < min_dist:
                min_dist = d
                nearest = p
    if nearest:
        target = nearest
        camp_target = null
        _patrol_target_pos = Vector2.ZERO
        return true
    return false

# 搜索最近的活野怪作为目标
func find_farming_target():
    # 1. 优先找活的野怪（全地图）
    var monsters = get_tree().get_nodes_in_group("monsters")
    var nearest_monster = null
    var min_dist = INF
    for m in monsters:
        if is_instance_valid(m) and m.current_hp > 0:
            var d = global_position.distance_to(m.global_position)
            if d < min_dist:
                min_dist = d
                nearest_monster = m

    if nearest_monster:
        target = nearest_monster
        camp_target = null
        _patrol_target_pos = Vector2.ZERO
        return

    # 2. 没有活野怪 → 找最近且有活怪的营地（去等刷新）
    var camps = get_tree().get_nodes_in_group("monster_camps")
    var nearest_camp = null
    var min_cd = INF
    for c in camps:
        if is_instance_valid(c) and c.has_alive_monsters():
            var d = global_position.distance_to(c.global_position)
            if d < min_cd:
                min_cd = d
                nearest_camp = c
    if nearest_camp:
        target = null
        camp_target = nearest_camp
        _patrol_target_pos = Vector2.ZERO
        return

    # 3. 全地图都没活怪 → 找最近的营地等刷新（所有营地都在等刷新）
    var fallback_camp = null
    var min_fb = INF
    for c in camps:
        if is_instance_valid(c):
            var d = global_position.distance_to(c.global_position)
            if d < min_fb:
                min_fb = d
                fallback_camp = c
    if fallback_camp:
        target = null
        camp_target = fallback_camp
        _patrol_target_pos = Vector2.ZERO
        return

    # 4. 啥都没找到 → 硬编码巡逻到已知营地坐标
    var camp_pos = CAMP_POSITIONS[_patrol_index]
    var dist_to_camp = global_position.distance_to(camp_pos)
    # 到达当前巡逻点后切换到下一个
    if dist_to_camp < 60:
        _patrol_index = (_patrol_index + 1) % CAMP_POSITIONS.size()
        camp_pos = CAMP_POSITIONS[_patrol_index]
    target = null
    camp_target = null
    _patrol_target_pos = camp_pos

# ========== 行为执行 ==========

func execute_behavior(delta):
    match state:
        State.IDLE:
            velocity = Vector2.ZERO

        State.FARMING:
            var moved := false
            # 情况0：优先处理密卷拾取（每帧自动扫描 + 拾取）
            if not (target and is_instance_valid(target) and _is_pickup_target(target)):
                _scan_nearby_pickup()
            if target and is_instance_valid(target) and _is_pickup_target(target):
                var dist = global_position.distance_to(target.global_position)
                if dist > 35:
                    move_to(target.global_position)
                else:
                    velocity = Vector2.ZERO
                    if target.skill_data != null:
                        pickup_skill(target.skill_data)
                        target.queue_free()
                moved = true
            # 情况1：有活的野怪目标
            elif target and is_instance_valid(target) and target.current_hp > 0 and target.has_method("take_damage"):
                var dist = global_position.distance_to(target.global_position)
                if dist > 150:
                    # 远距离 → 直接走向野怪位置
                    move_to(target.global_position)
                elif dist > 80:
                    # 近距离 → 走向野怪前方60px的安全位置（避开碰撞阻挡）
                    var dir = (target.global_position - global_position).normalized()
                    var safe_pos = target.global_position - dir * 60.0
                    move_to(safe_pos)
                else:
                    velocity = Vector2.ZERO
                    # 面朝野怪
                    var dir_to_target = (target.global_position - global_position).normalized()
                    if abs(dir_to_target.x) > 0.1:
                        sprite.scale.x = sign(dir_to_target.x) * SPRITE_SCALE
                    if attack_timer <= 0:
                        attack_timer = 1.0
                        target.take_damage(1.0)
                moved = true
            # 情况2：有营地节点目标（正在等刷新）
            elif camp_target and is_instance_valid(camp_target):
                var to_camp := global_position.distance_to(camp_target.global_position)
                if to_camp > 60:
                    move_to(camp_target.global_position)
                else:
                    # 到达营地 → 停下检查是否有活野怪
                    velocity = Vector2.ZERO
                    if camp_target.has_alive_monsters():
                        find_farming_target()  # 有怪了，去找最近的
                moved = true
            # 情况3：硬编码巡逻
            elif _patrol_target_pos != Vector2.ZERO:
                move_to(_patrol_target_pos)
                if global_position.distance_to(_patrol_target_pos) < 60:
                    velocity = Vector2.ZERO
                    _patrol_index = (_patrol_index + 1) % CAMP_POSITIONS.size()
                    _patrol_target_pos = CAMP_POSITIONS[_patrol_index]
                moved = true
            # 情况4：什么都没找到
            if not moved:
                find_farming_target()

        State.SEEKING:
            if target and is_instance_valid(target):
                move_to(target.global_position)
            else:
                state = State.FARMING
                find_farming_target()

        State.FIGHTING:
            if target and is_instance_valid(target):
                fight_target()
            else:
                state = State.SEEKING

        State.ATTACKING_BASE:
            var base = find_enemy_base()
            if base and is_instance_valid(base):
                move_to(base.global_position)
                # 面朝基地
                var dir_to_base = (base.global_position - global_position).normalized()
                if abs(dir_to_base.x) > 0.1:
                    sprite.scale.x = sign(dir_to_base.x) * SPRITE_SCALE
                # 到达基地附近 → 攻击
                if global_position.distance_to(base.global_position) < 80:
                    velocity = Vector2.ZERO
                    var old_target = target
                    target = base
                    auto_attack()
                    target = old_target
                    # 使用技能攻击基地
                    for i in range(skill_slots.size()):
                        if skill_slots[i] != null and skill_cooldowns[i] <= 0:
                            use_skill(i, null)
            else:
                state = State.FARMING
                find_farming_target()

        State.RETURNING:
            var base = get_tree().get_nodes_in_group("bases")
            if base.size() > 0:
                var my_base = base[1] if team == TEAM_SENJU else base[0]
                move_to(my_base.global_position)
                if global_position.distance_to(my_base.global_position) < 50:
                    state = State.FARMING
                    find_farming_target()

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

    # 面朝目标（确保技能方向正确）
    var dir_to_target = (target.global_position - global_position).normalized()
    if abs(dir_to_target.x) > 0.1:
        sprite.scale.x = sign(dir_to_target.x) * SPRITE_SCALE

    # 追敌
    if dist > 80:
        move_to(target.global_position)
    else:
        velocity = Vector2.ZERO
        auto_attack()

    # 使用技能攻击玩家
    for i in range(skill_slots.size()):
        if skill_slots[i] != null and skill_cooldowns[i] <= 0:
            use_skill(i, null)

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
        var dmg := 0.5
        # 影分身双倍伤害
        if has_meta("has_clones") and get_meta("has_clones"):
            dmg = 1.0
            _consume_clone()
        target.take_damage(dmg)

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

# ========== 技能系统 ==========

func use_skill(slot_idx: int, _target):
    if slot_idx < 0 or slot_idx >= skill_slots.size():
        return
    if skill_slots[slot_idx] == null:
        return
    if skill_cooldowns[slot_idx] > 0:
        return

    skill_cooldowns[slot_idx] = skill_slots[slot_idx].cooldown
    var skill_manager = $SkillManager
    skill_manager.use_skill(slot_idx, skill_slots[slot_idx], self)

func pickup_skill(skill_data):
    for i in range(skill_slots.size()):
        if skill_slots[i] == null:
            skill_slots[i] = skill_data
            queue_redraw()
            return true
    return false

# 消耗影分身
func _consume_clone():
    var clones = get_tree().get_nodes_in_group("shadow_clones")
    for c in clones:
        if is_instance_valid(c) and c.caster == self:
            c.disappear()
            return
    set_meta("has_clones", false)

# ========== 战斗受击 ==========

func take_damage(amount: float):
    if has_meta("has_clones") and get_meta("has_clones"):
        var clones = get_tree().get_nodes_in_group("shadow_clones")
        for c in clones:
            if is_instance_valid(c) and c.caster == self:
                amount = c.absorb_damage(amount)
                break
        if amount <= 0:
            return

    current_hp -= amount
    _update_health_text()
    modulate = Color(1, 0.3, 0.3)
    await get_tree().create_timer(0.1).timeout
    if is_instance_valid(self):
        modulate = Color(1, 1, 1, 1)

    if current_hp <= 0:
        die()

func knockback(vector: Vector2):
    global_position += vector

func die():
    if has_meta("has_clones") and get_meta("has_clones"):
        _consume_clone()

    var owned = []
    for i in range(skill_slots.size()):
        if skill_slots[i] != null:
            owned.append(i)
    if owned.size() > 0:
        var drop_idx = owned[randi() % owned.size()]
        var drop = preload("res://Scenes/SkillPickup.tscn").instantiate()
        drop.skill_data = skill_slots[drop_idx]
        drop.global_position = global_position + Vector2(randf_range(-15, 15), -100 + randf_range(-10, 10))
        get_parent().add_child(drop)
        skill_slots[drop_idx] = null

    queue_redraw()
    current_hp = MAX_HP
    _update_health_text()
    respawn()

func respawn():
    var spawn_pos = Vector2(MAP_WIDTH-100, MAP_HEIGHT/2)
    global_position = spawn_pos
    velocity = Vector2.ZERO
    visible = false
    await get_tree().create_timer(10.0).timeout
    visible = true
    modulate = Color(1, 1, 1, 1)
    state = State.FARMING
    find_farming_target()

func heal(amount: float):
    current_hp = min(current_hp + amount, MAX_HP)
    _update_health_text()
    modulate = Color(0.5, 1, 0.5)
    await get_tree().create_timer(0.15).timeout
    if is_instance_valid(self):
        modulate = Color(1, 1, 1, 1)

func get_team() -> int:
    return team
