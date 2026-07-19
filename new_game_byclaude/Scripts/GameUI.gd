extends CanvasLayer

# 顶部阵营显示：动态根据角色分配更新

func _ready():
	_update_faction_display()

func _update_faction_display():
	var is_swap = GameManager.is_swap_mode
	var left = "千手一族" if is_swap else "宇智波一族"
	var right = "宇智波一族" if is_swap else "千手一族"
	$TopBar/FactionDisplay.text = left + "  vs  " + right
