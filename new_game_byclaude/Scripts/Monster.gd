extends CharacterBody2D

# 野怪
class_name Monster

const BOSS_TEX := preload("res://Assets/boss.webp")
const NORMAL_TEX := preload("res://Assets/怪物.webp")

var max_hp := 6.0
var current_hp := max_hp
var is_boss := false  # 是否是中央Boss

var speed := 60.0
var aggro_range := 200.0
var attack_range := 40.0
var max_chase_range := 400.0  # 最大追击距离，超过则回到出生点
var attack_damage := 0.5
var attack_timer := 0.0
const ATTACK_COOLDOWN := 1.5

var target: Node2D = null
var home_position: Vector2
var last_attacker = null  # 记录最后攻击者，用于Boss击杀奖励

@onready var sprite := $Sprite2D
@onready var health_bar := $HealthBar
@onready var collision := $CollisionShape2D
@onready var character_visual := $CharacterVisual

func _ready():
    add_to_group("monsters")
    if is_boss:
        max_hp = 12.0        # Boss血量翻倍
        sprite.texture = BOSS_TEX
        sprite.scale = Vector2(0.32, 0.32)  # 普通怪0.16的2倍
        attack_damage = 2.0   # Boss伤害翻倍
    else:
        max_hp = 6.0
        sprite.texture = NORMAL_TEX
        sprite.scale = Vector2(0.16, 0.16)
    current_hp = max_hp
    home_position = global_position
    _update_health_text()
    health_bar.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
    # 隐藏_draw角色视觉（贴图已替代）
    if character_visual:
        character_visual.visible = false

func _update_health_text():
    health_bar.text = str(current_hp) + "/" + str(max_hp)

func _physics_process(delta):
    attack_timer -= delta

    # 更新角色视觉动画
    if character_visual:
        character_visual.is_moving = (velocity.length() > 0)
        if target and is_instance_valid(target):
            character_visual.facing_dir = (target.global_position - global_position).normalized()

    # 寻找附近玩家
    if not target or not is_instance_valid(target):
        target = find_target()

    if target and is_instance_valid(target):
        var dist = global_position.distance_to(target.global_position)
        var home_dist = global_position.distance_to(home_position)

        # 离出生点太远 → 放弃追击，回到原位
        if home_dist > max_chase_range:
            target = null
            return_to_home(delta)
            return

        if dist < aggro_range:
            # 追击目标
            var dir = (target.global_position - global_position).normalized()
            velocity = dir * speed
            move_and_slide()

            if dist < attack_range:
                # 攻击
                velocity = Vector2.ZERO
                if attack_timer <= 0:
                    attack_timer = ATTACK_COOLDOWN
                    if character_visual:
                        character_visual.trigger_attack()
                    if target.has_method("take_damage"):
                        AudioManager.play_sfx("hit", global_position)
                        target.take_damage(attack_damage)
        else:
            # 回到原位
            return_to_home(delta)
    else:
        return_to_home(delta)

func find_target():
    var players = get_tree().get_nodes_in_group("players")
    var nearest = null
    var min_dist = INF
    for p in players:
        if is_instance_valid(p):
            var d = global_position.distance_to(p.global_position)
            if d < min_dist:
                min_dist = d
                nearest = p
    return nearest

func return_to_home(delta):
    var dist = global_position.distance_to(home_position)
    if dist > 10:
        var dir = (home_position - global_position).normalized()
        velocity = dir * speed * 0.5
        move_and_slide()
    else:
        velocity = Vector2.ZERO

func take_damage(amount: float, attacker = null):
    if attacker != null:
        last_attacker = attacker
    current_hp -= amount
    _update_health_text()
    AudioManager.play_sfx("hit", global_position)
    # 受击反馈
    modulate = Color(1, 0.5, 0.5)
    await get_tree().create_timer(0.1).timeout
    if is_instance_valid(self):
        modulate = Color(1, 1, 1, 1)

    if current_hp <= 0:
        die()

func die():
    # 掉落技能并通知营地
    var camp = get_parent()
    if camp and camp.has_method("on_monster_died"):
        AudioManager.play_sfx("death", global_position)
    camp.on_monster_died(self, last_attacker)

    queue_free()
