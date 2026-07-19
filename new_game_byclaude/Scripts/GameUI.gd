extends CanvasLayer

# UI管理器：动态根据视口大小定位按钮

func _ready():
	_update_faction_display()
	call_deferred("_reposition_ui")
	if not get_tree().root.size_changed.is_connected(_reposition_ui):
		get_tree().root.size_changed.connect(_reposition_ui)

func _update_faction_display():
	var is_swap = GameManager.is_swap_mode
	var left = "千手一族" if is_swap else "宇智波一族"
	var right = "宇智波一族" if is_swap else "千手一族"
	$TopBar/FactionDisplay.text = left + "  vs  " + right

func _reposition_ui():
	var vp = get_viewport().get_visible_rect().size

	# 根据屏幕宽度动态缩放按钮尺寸（适配手机小屏）
	var base_width = 1920.0
	var scale = minf(vp.x / base_width, 1.0)
	scale = maxf(scale, 0.5)  # 最小缩放 0.5 倍

	var margin = 20 * scale
	var btn_size = 400 * scale
	var skill_size = 130 * scale
	var joystick_size = 600 * scale

	# 更新攻击按钮尺寸
	$AttackButton.size = Vector2(btn_size, btn_size)
	$AttackButton.position.x = vp.x - btn_size - margin
	$AttackButton.position.y = vp.y - btn_size - margin

	# 更新技能槽：攻击键正上方居中
	var skill_gap = 8 * scale
	var skill_total_w = skill_size * 3 + skill_gap * 2
	var skill_center_x = $AttackButton.position.x + btn_size / 2
	$SkillSlotUI.position.x = skill_center_x - skill_total_w / 2
	$SkillSlotUI.position.y = $AttackButton.position.y - skill_size - margin
	$SkillSlotUI.size.y = skill_size
	$SkillSlotUI.apply_scale(scale)

	# 更新摇杆：左下角
	$JoystickContainer.size = Vector2(joystick_size, joystick_size)
	$JoystickContainer.position = Vector2(margin, vp.y - joystick_size - margin)

	# 顶部栏：全宽
	$TopBar.size.x = vp.x
