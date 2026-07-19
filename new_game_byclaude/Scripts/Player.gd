extends CharacterBody2D
class_name Player

# 玩家基础属性
const MAX_HP := 5
const SPEED := 100.0  # 1单位/秒 (100px/s)
const MAP_WIDTH := 1500  # 地图总宽
const MAP_HEIGHT := 1500  # 地图总高
const SPRITE_SCALE := 0.04  # 贴图缩放到适合游戏尺寸
var _bob_time := 0.0  # 行走浮动计时

# 普攻系统
enum AttackState { IDLE, ATTACK1, ATTACK2, ATTACK3, DASH }
var attack_state := AttackState.IDLE
var attack_timer := 0.0
var attack_combo_window := 0.6  # 连击窗口
var current_hp := MAX_HP
var is_dashing := false
var dash_direction := Vector2.RIGHT
const DASH_DISTANCE := 150.0  # 位移距离
const DASH_SPEED := 400.0

# 阵营
enum Team { UCHIHA, SENJU }
var team := Team.UCHIHA

# 技能系统
var skill_slots := [null, null, null]  # 3个技能槽
var skill_cooldowns := [0.0, 0.0, 0.0]

# 输入
var move_direction := Vector2.ZERO
var attack_pressed := false
var skill_pressed := [-1, -1, -1]

# 引用
@onready var sprite := $Sprite2D
@onready var animation := $AnimationPlayer
@onready var health_bar := $HealthBar
@onready var attack_area := $AttackArea
@onready var dash_ray := $DashRayCast
@onready var state_label := $StateLabel
@onready var character_visual := $CharacterVisual
var skill_ui: SkillSlotUI = null

func _ready():
	add_to_group("players")
	add_to_group("human_player")
	current_hp = MAX_HP
	_update_health_text()
	# 设置血条文字颜色
	health_bar.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	# 设置贴图缩放
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position = Vector2.ZERO
	# 隐藏_draw角色视觉（贴图已替代）
	if character_visual:
		character_visual.visible = false

	# 延迟一帧，等UI场景准备好后再找技能槽
	call_deferred("_init_skill_ui")

func _update_health_text():
	health_bar.text = str(current_hp) + "/" + str(MAX_HP)

func _init_skill_ui():
	skill_ui = get_tree().get_first_node_in_group("skill_ui")
	if skill_ui:
		skill_ui.init_slots(skill_slots.size())

func _process(delta):
	# 连击计时
	if attack_state != AttackState.IDLE and attack_state != AttackState.DASH:
		attack_timer -= delta
		if attack_timer <= 0:
			attack_state = AttackState.IDLE

	# 技能CD
	for i in range(skill_cooldowns.size()):
		if skill_cooldowns[i] > 0:
			skill_cooldowns[i] -= delta
			if skill_cooldowns[i] < 0:
				skill_cooldowns[i] = 0

	# 行走浮动动画
	if velocity.length() > 0:
		_bob_time += delta * 8.0
		sprite.position.y = sin(_bob_time) * 2.0
	else:
		_bob_time = 0.0
		sprite.position.y = 0.0

func _physics_process(delta):
	if is_dashing:
		# 冲刺中
		var was_on_wall := is_on_wall()
		var collision := move_and_collide(dash_direction * DASH_SPEED * delta)
		if collision or was_on_wall:
			# 穿墙：冲刺可以穿过薄墙，厚墙会停下
			if collision and collision.get_collider() is TileMap:
				pass  # 穿墙逻辑
		return

	# 移动
	if move_direction != Vector2.ZERO:
		velocity = move_direction.normalized() * SPEED
		# 面向方向
		if move_direction.x != 0:
			sprite.scale.x = sign(move_direction.x) * SPRITE_SCALE
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# 边界限制
	global_position = Vector2(
		clamp(global_position.x, 50, MAP_WIDTH - 50),
		clamp(global_position.y, 50, MAP_HEIGHT - 50)
	)

func attack():
	if is_dashing:
		return
	match attack_state:
		AttackState.IDLE:
			do_attack_1()
		AttackState.ATTACK1:
			do_attack_2()
		AttackState.ATTACK2:
			do_attack_3()
		AttackState.ATTACK3:
			do_dash()

func do_attack_1():
	attack_state = AttackState.ATTACK1
	attack_timer = attack_combo_window
	if character_visual:
		character_visual.trigger_attack()
	deal_damage_in_front(0.5)

func do_attack_2():
	attack_state = AttackState.ATTACK2
	attack_timer = attack_combo_window
	if character_visual:
		character_visual.trigger_attack()
	deal_damage_in_front(0.5)

func do_attack_3():
	attack_state = AttackState.ATTACK3
	attack_timer = attack_combo_window
	if character_visual:
		character_visual.trigger_attack()
	deal_damage_in_front(0.5)

func do_dash():
	attack_state = AttackState.DASH
	is_dashing = true
	dash_direction = Vector2.RIGHT if sprite.scale.x >= 0 else Vector2.LEFT
	# 冲刺攻击特效
	sprite.scale = Vector2(SPRITE_SCALE * 1.3, SPRITE_SCALE * 1.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	# 冲刺无敌帧
	set_collision_layer_value(1, false)  # 临时无敌

	# 0.3秒后结束冲刺
	await get_tree().create_timer(0.3).timeout

	is_dashing = false
	set_collision_layer_value(1, true)
	attack_state = AttackState.IDLE

func deal_damage_in_front(damage: float):
	var dir := Vector2.RIGHT if sprite.scale.x >= 0 else Vector2.LEFT
	# 攻击缩放脉冲
	sprite.scale = Vector2(SPRITE_SCALE * 1.15, SPRITE_SCALE * 0.85)
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.15)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 60)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)

	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(damage)

func take_damage(amount: float):
	current_hp -= amount
	_update_health_text()
	# 闪红效果
	modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)

	if current_hp <= 0:
		die()

func knockback(vector: Vector2):
	velocity = vector
	# 一帧后恢复（由move_and_slide处理减速）

func die():
	# 掉落随机一个技能
	var owned_skills = []
	for i in range(skill_slots.size()):
		if skill_slots[i] != null:
			owned_skills.append(i)
	if owned_skills.size() > 0:
		var drop_idx = owned_skills[randi() % owned_skills.size()]
		drop_skill_at_position(drop_idx, global_position)

	# 清空技能
	for i in range(skill_slots.size()):
		skill_slots[i] = null

	current_hp = MAX_HP
	_update_health_text()
	# 回到基地
	respawn()

func respawn():
	var spawn_pos = Vector2(100, MAP_HEIGHT/2) if team == Team.UCHIHA else Vector2(MAP_WIDTH-100, MAP_HEIGHT/2)
	global_position = spawn_pos
	velocity = Vector2.ZERO
	# 3秒复活
	visible = false
	await get_tree().create_timer(3.0).timeout
	visible = true
	modulate = Color(1, 1, 1, 1)

func drop_skill_at_position(slot_idx: int, pos: Vector2):
	var skill_data = skill_slots[slot_idx]
	if skill_data == null:
		return
	# 在地图生成可拾取的技能物品
	var skill_pickup = preload("res://Scenes/SkillPickup.tscn").instantiate()
	skill_pickup.skill_data = skill_data
	skill_pickup.global_position = pos
	get_parent().add_child(skill_pickup)
	skill_slots[slot_idx] = null

func pickup_skill(skill_data):
	for i in range(skill_slots.size()):
		if skill_slots[i] == null:
			skill_slots[i] = skill_data
			skill_ui.update_slot(i, skill_data)
			return true
	# 如果满了，替换第一个
	skill_slots[0] = skill_data
	skill_ui.update_slot(0, skill_data)
	return true

func use_skill(slot_idx: int):
	if slot_idx < 0 or slot_idx >= skill_slots.size():
		return
	if skill_slots[slot_idx] == null:
		return
	if skill_cooldowns[slot_idx] > 0:
		return

	var skill_data = skill_slots[slot_idx]
	skill_cooldowns[slot_idx] = skill_data.cooldown
	skill_ui.start_cooldown(slot_idx, skill_data.cooldown)

	# 技能效果由SkillManager处理
	var skill_manager = $SkillManager
	skill_manager.use_skill(slot_idx, skill_data, self)

# 输入处理（键盘调试用）
func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_J and event.pressed:
			attack()
		if event.keycode == KEY_K and event.pressed:
			use_skill(0)
		if event.keycode == KEY_L and event.pressed:
			use_skill(1)
		if event.keycode == KEY_U and event.pressed:
			use_skill(2)
