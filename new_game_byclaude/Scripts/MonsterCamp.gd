extends Node2D

# 野怪营地 - 管理野怪的生成和技能掉落
class_name MonsterCamp

var is_boss_camp := false  # 中央营地是否为Boss
var spawn_count := 1
var monster_scene = preload("res://Scenes/Monster.tscn")
var respawn_timer := 40.0  # 40秒刷新
var respawn_count := 0  # 累计重生次数（血量递增）

var _monsters := []
var _timer: Timer

# 可用技能列表
var available_skills := [
    {
        "type": "fireball",
        "name": "火球术",
        "description": "发射三个火球，每个1点伤害，距离越近击退越远",
        "damage": 2.0,
        "cooldown": 5.0,
        "icon": null
    },
    {
        "type": "rasengan",
        "name": "螺旋丸",
        "description": "短位移+持续范围伤害2s",
        "damage": 1.0,
        "cooldown": 4.0,
        "icon": null
    },
    {
        "type": "shadow_clone",
        "name": "影分身",
        "description": "分身挡伤/双倍伤害",
        "damage": 0.0,
        "cooldown": 10.0,
        "icon": null
    }
]

func _ready():
    add_to_group("monster_camps")
    if is_boss_camp:
        spawn_count = 1  # Boss只有1个，但更强
    spawn_monsters()

func spawn_monsters():
    respawn_count += 1
    var hp_mult = pow(2.0, respawn_count - 1)  # 1, 2, 4, 8...
    for i in range(spawn_count):
        var monster = monster_scene.instantiate()
        var spawn_pos = global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
        # 限制在地图范围内（地图1500x1500，边界留60px安全区）
        spawn_pos.x = clamp(spawn_pos.x, 60, 1440)
        spawn_pos.y = clamp(spawn_pos.y, 60, 1440)
        monster.global_position = spawn_pos
        monster.is_boss = is_boss_camp
        monster.hp_multiplier = hp_mult
        monster.home_position = monster.global_position
        add_child(monster)
        _monsters.append(monster)

func has_alive_monsters() -> bool:
    for m in _monsters:
        if is_instance_valid(m) and m.current_hp > 0:
            return true
    return false

func on_monster_died(monster, killer = null):
    _monsters.erase(monster)
    drop_skill(monster.global_position)

    # Boss击杀奖励：掉落红色生命球（拾取后永久+5HP）
    if is_boss_camp:
        _drop_hp_orb(monster.global_position)

    # 启动刷新计时（Boss翻倍）
    var timer_duration := respawn_timer * 2 if is_boss_camp else respawn_timer
    if _timer == null:
        _timer = Timer.new()
        _timer.one_shot = true
        _timer.timeout.connect(spawn_monsters)
        add_child(_timer)
    _timer.start(timer_duration)

# 掉落红色生命球
func _drop_hp_orb(pos: Vector2):
    var orb = preload("res://Scripts/HpOrb.gd").new()
    # 设置Area2D属性
    orb.name = "HpOrb"
    # 添加碰撞形状
    var shape = CircleShape2D.new()
    shape.radius = 45.0
    var col = CollisionShape2D.new()
    col.shape = shape
    orb.add_child(col)
    orb.global_position = pos + Vector2(randf_range(-15, 15), -100 + randf_range(-10, 10))
    get_parent().add_child(orb)

func drop_skill(pos: Vector2):
    # 随机掉落一个技能
    var skill_data = available_skills[randi() % available_skills.size()].duplicate()

    var pickup = preload("res://Scenes/SkillPickup.tscn").instantiate()
    pickup.skill_data = skill_data
    pickup.global_position = pos + Vector2(randf_range(-15, 15), -100 + randf_range(-10, 10))
    get_parent().add_child(pickup)

    # Boss掉落两个
    if is_boss_camp:
        var skill_data2 = available_skills[randi() % available_skills.size()].duplicate()
        var pickup2 = preload("res://Scenes/SkillPickup.tscn").instantiate()
        pickup2.skill_data = skill_data2
        pickup2.global_position = pos + Vector2(randf_range(-15, 15), -100 + randf_range(-10, 10))
        get_parent().add_child(pickup2)
