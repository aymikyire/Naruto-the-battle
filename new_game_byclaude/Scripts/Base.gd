extends StaticBody2D

# 基地
class_name GameBase

const TEAM_UCHIHA := 0
const TEAM_SENJU := 1

var max_hp := 20.0
var current_hp := max_hp
var team := TEAM_UCHIHA  # 由 Main 场景设置
var _heal_timer := 0.0
const HEAL_RATE := 2.0  # 每秒回复2格
var _friendly_bodies := []  # 在治疗范围内的友方单位

@onready var health_bar := $HealthBar
@onready var label := $Label
@onready var heal_area := $HealArea

func _ready():
    add_to_group("bases")
    _update_health_text()
    health_bar.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
    label.text = name
    heal_area.body_entered.connect(_on_heal_body_entered)
    heal_area.body_exited.connect(_on_heal_body_exited)

func _process(delta):
    _heal_timer += delta
    if _heal_timer >= 1.0 and _friendly_bodies.size() > 0:
        _heal_timer -= 1.0
        for body in _friendly_bodies:
            if is_instance_valid(body) and body.has_method("heal"):
                body.heal(HEAL_RATE)

func _on_heal_body_entered(body):
    if body.has_method("get_team") and body.get_team() == team:
        _friendly_bodies.append(body)

func _on_heal_body_exited(body):
    _friendly_bodies.erase(body)

func _update_health_text():
    health_bar.text = str(current_hp) + "/" + str(max_hp)

func take_damage(amount: float, attacker = null):
    current_hp -= amount
    _update_health_text()
    AudioManager.play_sfx("base_hit", global_position)

    # 闪烁
    modulate = Color(1, 0.5, 0.5)
    await get_tree().create_timer(0.15).timeout
    modulate = Color(1, 1, 1, 1)

    if current_hp <= 0:
        destroyed()

func destroyed():
    AudioManager.play_sfx("base_destroy", global_position)
    label.text = "摧毁!"
    # 游戏结束
    var game_manager = get_node("/root/Main/GameManager")
    if game_manager:
        game_manager.on_base_destroyed(self)
