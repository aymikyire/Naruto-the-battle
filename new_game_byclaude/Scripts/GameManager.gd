extends Node

# 游戏管理器 - 控制游戏状态和流程
class_name GameManager

# 角色分配：false=玩家宇智波/敌方千手（正常），true=玩家千手/敌方宇智波（互换）
static var is_swap_mode := false

var game_over := false
var winner := ""

@onready var main := get_parent()

func _ready():
    # 随机分配角色（50%概率互换）
    is_swap_mode = (randi() % 2 == 1)
    print("游戏开始! 角色模式:", "互换" if is_swap_mode else "正常",
          " 玩家=", "千手" if is_swap_mode else "宇智波",
          " 敌方=", "宇智波" if is_swap_mode else "千手")
    await get_tree().create_timer(0.5).timeout
    print("游戏开始!")

func on_base_destroyed(base: GameBase):
    if game_over:
        return
    game_over = true

    # 判断哪一方
    if base.name == "BaseA":
        winner = "千手一族 胜利!"
    else:
        winner = "宇智波一族 胜利!"

    print("游戏结束: " + winner)

    # 显示结束画面
    var game_over_panel = $"../UI/GameUI/GameOverPanel"
    if game_over_panel:
        game_over_panel.show()
        game_over_panel.get_node("Label").text = winner

    # 3秒后重新开始
    await get_tree().create_timer(3.0).timeout
    get_tree().reload_current_scene()
