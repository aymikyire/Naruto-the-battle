extends Control

# 技能槽UI - 显示3个技能按钮
class_name SkillSlotUI

var slot_count := 3
var slot_buttons := []

var skill_slot_scene = preload("res://Scenes/UI/SkillButton.tscn")

func _ready():
	add_to_group("skill_ui")
	init_slots(slot_count)

func init_slots(count: int, scale := 1.0):
	slot_count = count
	# 清空旧的
	for btn in slot_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	slot_buttons.clear()

	_create_buttons(scale)

func _create_buttons(scale: float):
	var btn_size := 130 * scale
	var gap := 8 * scale

	for i in range(slot_count):
		var btn = skill_slot_scene.instantiate()
		btn.position = Vector2(i * (btn_size + gap), 10 * scale)
		btn.size = Vector2(btn_size, btn_size)
		btn.slot_index = i
		add_child(btn)
		slot_buttons.append(btn)

# 当屏幕缩放变化时，就地更新按钮尺寸（不重建）
func apply_scale(scale: float):
	var btn_size := 130 * scale
	var gap := 8 * scale

	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		if not is_instance_valid(btn):
			continue
		btn.position = Vector2(i * (btn_size + gap), 10 * scale)
		btn.size = Vector2(btn_size, btn_size)

func update_slot(idx: int, skill_data):
	if idx >= 0 and idx < slot_buttons.size():
		slot_buttons[idx].set_skill(skill_data)

func start_cooldown(idx: int, cooldown: float):
	if idx >= 0 and idx < slot_buttons.size():
		slot_buttons[idx].start_cooldown(cooldown)
