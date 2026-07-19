extends Control

# 技能槽UI - 显示3个技能按钮
class_name SkillSlotUI

var slot_count := 3
var slot_buttons := []

var skill_slot_scene = preload("res://Scenes/UI/SkillButton.tscn")

func _ready():
	add_to_group("skill_ui")
	init_slots(slot_count)

func init_slots(count: int):
	slot_count = count
	# 清空旧的
	for btn in slot_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	slot_buttons.clear()

	# 在SkillSlotUI区域内横向排列
	var btn_size := 70
	var gap := 10

	for i in range(count):
		var btn = skill_slot_scene.instantiate()
		btn.position = Vector2(i * (btn_size + gap), 10)
		btn.slot_index = i
		add_child(btn)
		slot_buttons.append(btn)

func update_slot(idx: int, skill_data):
	if idx >= 0 and idx < slot_buttons.size():
		slot_buttons[idx].set_skill(skill_data)

func start_cooldown(idx: int, cooldown: float):
	if idx >= 0 and idx < slot_buttons.size():
		slot_buttons[idx].start_cooldown(cooldown)
