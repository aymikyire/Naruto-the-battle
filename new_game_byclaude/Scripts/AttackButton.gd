extends TouchScreenButton

# 攻击按钮
class_name AttackButton

func _ready():
    shape = RectangleShape2D.new()
    shape.size = Vector2(80, 80)
    pressed.connect(_on_pressed)

func _on_pressed():
    var player = get_tree().get_first_node_in_group("human_player")
    if player and player.has_method("attack"):
        player.attack()
