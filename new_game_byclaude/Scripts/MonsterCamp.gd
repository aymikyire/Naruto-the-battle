extends Node2D

# 野怪营地 - 管理野怪的生成和技能掉落
class_name MonsterCamp

var is_boss_camp := false  # 中央营地是否为Boss
var spawn_count := 1
var monster_scene = preload("res://Scenes/Monster.tscn")
var respawn_timer := 20.0  # 20秒刷新

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
    for i in range(spawn_count):
        var monster = monster_scene.instantiate()
        monster.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
        monster.is_boss = is_boss_camp
        monster.home_position = monster.global_position
        add_child(monster)
        _monsters.append(monster)

func has_alive_monsters() -> bool:
    for m in _monsters:
        if is_instance_valid(m) and m.current_hp > 0:
            return true
    return false

func on_monster_died(monster):
    _monsters.erase(monster)
    drop_skill(monster.global_position)

    # 启动刷新计时
    if _timer == null:
        _timer = Timer.new()
        _timer.one_shot = true
        _timer.timeout.connect(spawn_monsters)
        add_child(_timer)
    _timer.start(respawn_timer)

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
