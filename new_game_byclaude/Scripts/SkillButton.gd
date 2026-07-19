extends TouchScreenButton

# 技能按钮
class_name SkillButton

var slot_index := 0
var skill_data = null
var is_on_cooldown := false

@onready var icon_sprite := $Icon
@onready var cd_label := $CDLabel
@onready var name_label := $NameLabel

func _ready():
    cd_label.visible = false
    shape = RectangleShape2D.new()
    shape.size = Vector2(70, 70)

func set_skill(data):
    skill_data = data
    if data:
        name_label.text = data.get("name", "")
        # 图标稍后替换
        icon_sprite.visible = true
    else:
        name_label.text = ""
        icon_sprite.visible = false

func connect_pressed():
    pressed.connect(_on_pressed)

func _on_pressed():
    if is_on_cooldown:
        return
    if skill_data == null:
        return
    # 通知Player使用技能
    var player = get_tree().get_first_node_in_group("human_player")
    if player and player.has_method("use_skill"):
        player.use_skill(slot_index)

func start_cooldown(duration: float):
    if is_on_cooldown:
        return
    is_on_cooldown = true
    cd_label.visible = true
    modulate = Color(0.5, 0.5, 0.5, 0.7)

    var remain = duration
    while remain > 0:
        cd_label.text = str(ceil(remain))
        await get_tree().create_timer(0.2).timeout
        remain -= 0.2

    cd_label.visible = false
    is_on_cooldown = false
    modulate = Color(1, 1, 1, 1)
