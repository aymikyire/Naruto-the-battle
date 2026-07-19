extends CharacterBody2D

# 野怪
class_name Monster

const MAX_HP := 6.0
var current_hp := MAX_HP
var is_boss := false  # 是否是中央Boss

var speed := 60.0
var aggro_range := 200.0
var attack_range := 40.0
var attack_damage := 0.5
var attack_timer := 0.0
const ATTACK_COOLDOWN := 1.5

var target: Node2D = null
var home_position: Vector2

@onready var sprite := $Sprite2D
@onready var health_bar := $HealthBar
@onready var collision := $CollisionShape2D
@onready var character_visual := $CharacterVisual

func _ready():
    add_to_group("monsters")
    current_hp = MAX_HP
    home_position = global_position
    _update_health_text()
    health_bar.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
    if is_boss:
        sprite.scale = Vector2(1.5, 1.5)
        attack_damage = 1.0  # Boss伤害翻倍
    # 配置角色视觉
    if character_visual:
        character_visual.type = SimpleCharacter.Type.MONSTER

func _update_health_text():
    health_bar.text = str(current_hp) + "/" + str(MAX_HP)

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

        if dist < aggro_range:
            # 追击玩家
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
                        target.take_damage(attack_damage)
        else:
            # 回到原位
            return_to_home(delta)
    else:
        return_to_home(delta)

func find_target():
    var players = get_tree().get_nodes_in_group("players")
    for p in players:
        if is_instance_valid(p):
            return p
    return null

func return_to_home(delta):
    var dist = global_position.distance_to(home_position)
    if dist > 10:
        var dir = (home_position - global_position).normalized()
        velocity = dir * speed * 0.5
        move_and_slide()
    else:
        velocity = Vector2.ZERO

func take_damage(amount: float):
    current_hp -= amount
    _update_health_text()
    # 受击反馈
    modulate = Color(1, 0.5, 0.5)
    await get_tree().create_timer(0.1).timeout
    if is_instance_valid(self):
        modulate = Color(1, 1, 1, 1)

    if current_hp <= 0:
        die()

func die():
    # 掉落技能
    var camp = get_parent()
    if camp and camp.has_method("on_monster_died"):
        camp.on_monster_died(self)

    queue_free()
