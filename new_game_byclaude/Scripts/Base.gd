extends StaticBody2D

# 基地
class_name GameBase

var max_hp := 10.0
var current_hp := max_hp

@onready var health_bar := $HealthBar
@onready var label := $Label

func _ready():
    _update_health_text()
    health_bar.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
    label.text = name

func _update_health_text():
    health_bar.text = str(current_hp) + "/" + str(max_hp)

func take_damage(amount: float):
    current_hp -= amount
    _update_health_text()

    # 闪烁
    modulate = Color(1, 0.5, 0.5)
    await get_tree().create_timer(0.15).timeout
    modulate = Color(1, 1, 1, 1)

    if current_hp <= 0:
        destroyed()

func destroyed():
    label.text = "摧毁!"
    # 游戏结束
    var game_manager = get_node("/root/Main/GameManager")
    if game_manager:
        game_manager.on_base_destroyed(self)
