extends CharacterBody2D
class_name Player

# 玩家基础属性
var max_hp := 10.0
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
var current_hp := max_hp
var is_dashing := false
var _facing := 1.0  # 人物朝向：1=右，-1=左
var dash_direction := Vector2.RIGHT
const DASH_DISTANCE := 150.0  # 位移距离
const DASH_SPEED := 400.0

# 阵营
enum Team { UCHIHA, SENJU }
var team := Team.UCHIHA
var is_uchiha := true  # false = 千手风格（第3下击退）

# 角色贴图
const SASUKE_TEX := preload("res://Assets/player_sasuke.png")
const NARUTO_TEX := preload("res://Assets/player_naruto.png")

# 技能系统
var skill_slots := [null, null, null]  # 3个技能槽
var skill_cooldowns := [0.0, 0.0, 0.0]
var _seen_skill_types := {}  # 首次拾取提示追踪

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
	current_hp = max_hp
	_update_health_text()
	# 设置血条文字颜色
	health_bar.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	# 设置贴图缩放
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position = Vector2.ZERO
	# 隐藏_draw角色视觉（贴图已替代）
	if character_visual:
		character_visual.visible = false

	# 角色分配（从GameManager读取）
	is_uchiha = not GameManager.is_swap_mode
	if not is_uchiha:
		# 玩家是千手/鸣人 → 换贴图、换连击风格
		sprite.texture = NARUTO_TEX

	# 延迟一帧，等UI场景准备好后再找技能槽
	call_deferred("_init_skill_ui")

	# 初始绘制密卷标记点
	queue_redraw()

func _update_health_text():
	health_bar.text = str(current_hp) + "/" + str(max_hp)

func _draw():
	# 在血条上方绘制金黄色密卷标记点
	var skill_count := 0
	for s in skill_slots:
		if s != null:
			skill_count += 1
	if skill_count == 0:
		return

	var dot_y := -48  # 血条上方
	var dot_radius := 5.0
	var dot_spacing := 14.0
	var start_x := -(float(skill_count) - 1.0) * dot_spacing / 2.0

	for i in range(skill_count):
		var dot_pos := Vector2(start_x + i * dot_spacing, dot_y)
		# 外圈光晕
		draw_circle(dot_pos, dot_radius + 2, Color(1, 0.85, 0.2, 0.3))
		# 实心金黄点
		draw_circle(dot_pos, dot_radius, Color(1, 0.8, 0.2, 1.0))
		# 高光
		draw_circle(dot_pos + Vector2(-1.5, -1.5), dot_radius * 0.4, Color(1, 1, 0.6, 0.8))

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
		# 面向方向（贴图左右翻转）
		if move_direction.x != 0:
			_facing = sign(move_direction.x)
			sprite.scale.x = _facing * SPRITE_SCALE
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
	if is_uchiha:
		# 宇智波：4连击，第4下位移突进
		match attack_state:
			AttackState.IDLE:
				do_attack_1()
			AttackState.ATTACK1:
				do_attack_2()
			AttackState.ATTACK2:
				do_attack_3()
			AttackState.ATTACK3:
				do_dash()
	else:
		# 千手：3连击，第3下击退
		match attack_state:
			AttackState.IDLE:
				do_attack_1()
			AttackState.ATTACK1:
				do_attack_2()
			AttackState.ATTACK2:
				do_attack_3_senju()
			AttackState.ATTACK3:
				pass  # 等待计时器归零后自动回到IDLE

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

func do_attack_3_senju():
	# 千手第3击：伤害+击退（单次射线，deal_damage_in_front 统一处理）
	attack_state = AttackState.ATTACK3
	attack_timer = attack_combo_window
	if character_visual:
		character_visual.trigger_attack()
	deal_damage_in_front(0.5, true)

func do_dash():
	attack_state = AttackState.DASH
	is_dashing = true
	dash_direction = Vector2.RIGHT if _facing >= 0 else Vector2.LEFT
	# 冲刺攻击特效（保持朝向）
	sprite.scale = Vector2(_facing * SPRITE_SCALE * 1.3, SPRITE_SCALE * 1.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.scale = Vector2(_facing * SPRITE_SCALE, SPRITE_SCALE)

	# 冲刺无敌帧
	set_collision_layer_value(1, false)  # 临时无敌

	# 0.3秒后结束冲刺
	await get_tree().create_timer(0.3).timeout

	is_dashing = false
	set_collision_layer_value(1, true)
	attack_state = AttackState.IDLE

func deal_damage_in_front(damage: float, apply_knockback: bool = false):
	var dir := Vector2.RIGHT if _facing >= 0 else Vector2.LEFT
	# 攻击缩放脉冲（保持朝向）
	sprite.scale = Vector2(_facing * SPRITE_SCALE * 1.15, SPRITE_SCALE * 0.85)
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(_facing * SPRITE_SCALE, SPRITE_SCALE), 0.15)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 80)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)

	if result and result.collider.has_method("take_damage"):
		# 影分身双倍伤害
		if has_meta("has_clones") and get_meta("has_clones"):
			damage *= 2
			_consume_clone()
		result.collider.take_damage(damage)
		# 千手第3下附带击退（同一射线，保证命中）
		if apply_knockback and result.collider.has_method("knockback"):
			result.collider.knockback(dir * 100)

func take_damage(amount: float, attacker = null):
	# 影分身吸收伤害
	if has_meta("has_clones") and get_meta("has_clones"):
		var clones = get_tree().get_nodes_in_group("shadow_clones")
		for c in clones:
			if is_instance_valid(c) and c.caster == self:
				amount = c.absorb_damage(amount)
				break
		if amount <= 0:
			return  # 伤害被完全吸收

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
	# 直接位置位移（保留传入的完整距离）
	global_position += vector

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	_update_health_text()
	# 回复闪光
	modulate = Color(0.5, 1, 0.5)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)

func increase_max_hp(amount: float):
	max_hp += amount
	current_hp = min(current_hp + amount, max_hp)  # 同时回复等量生命
	_update_health_text()
	# 升级闪光（金色）
	modulate = Color(1, 1, 0.5)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)

func get_team() -> int:
	return team

func die():
	# 移除影分身
	if has_meta("has_clones") and get_meta("has_clones"):
		_consume_clone()

	# 掉落随机一个技能（保留剩余密卷）
	var owned_skills = []
	for i in range(skill_slots.size()):
		if skill_slots[i] != null:
			owned_skills.append(i)
	if owned_skills.size() > 0:
		var drop_idx = owned_skills[randi() % owned_skills.size()]
		drop_skill_at_position(drop_idx, global_position)

	queue_redraw()  # 更新密卷标记点

	current_hp = max_hp
	_update_health_text()
	# 回到基地
	respawn()

func respawn():
	var spawn_pos = Vector2(100, MAP_HEIGHT/2) if team == Team.UCHIHA else Vector2(MAP_WIDTH-100, MAP_HEIGHT/2)
	global_position = spawn_pos
	velocity = Vector2.ZERO
	# 10秒复活
	visible = false
	await get_tree().create_timer(10.0).timeout
	visible = true
	modulate = Color(1, 1, 1, 1)

func drop_skill_at_position(slot_idx: int, pos: Vector2):
	var skill_data = skill_slots[slot_idx]
	if skill_data == null:
		return
	# 在地图生成可拾取的技能物品
	var skill_pickup = preload("res://Scenes/SkillPickup.tscn").instantiate()
	skill_pickup.skill_data = skill_data
	skill_pickup.global_position = pos + Vector2(randf_range(-15, 15), -100 + randf_range(-10, 10))
	get_parent().add_child(skill_pickup)
	skill_slots[slot_idx] = null
	queue_redraw()  # 更新密卷标记点

func pickup_skill(skill_data):
	# 首次拾取该类型密卷 → 显示效果提示
	var skill_type: String = skill_data.get("type", "")
	if skill_type != "" and not _seen_skill_types.has(skill_type):
		_seen_skill_types[skill_type] = true
		_show_skill_notification(skill_data)

	for i in range(skill_slots.size()):
		if skill_slots[i] == null:
			skill_slots[i] = skill_data
			if skill_ui:
				skill_ui.update_slot(i, skill_data)
			queue_redraw()
			return true
	# 如果满了，替换第一个
	skill_slots[0] = skill_data
	if skill_ui:
		skill_ui.update_slot(0, skill_data)
	queue_redraw()
	return true

# 首次拾取提示：人物上方浮动面板，跟随移动，持续3秒
func _show_skill_notification(skill_data):
	# 移除旧提示
	var old = get_node_or_null("SkillNotify")
	if old:
		old.queue_free()

	# 背景面板（半透明黑底 + 金边）
	var panel = Panel.new()
	panel.name = "SkillNotify"
	panel.position = Vector2(-140, -110)
	panel.size = Vector2(280, 56)
	panel.z_index = 100
	panel.add_theme_stylebox_override("panel", _make_notification_style())
	add_child(panel)

	# 文字标签
	var label = Label.new()
	label.name = "NotifyLabel"
	label.text = skill_data.get("name", "密卷") + "\n" + skill_data.get("description", "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	label.add_theme_font_size_override("font_size", 13)
	label.position = Vector2(4, 4)
	label.size = Vector2(272, 48)
	label.z_index = 101
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)

	# 上浮 + 渐隐（3秒）
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position", Vector2(-140, -150), 3.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), 2.5).set_delay(0.5)
	tween.tween_callback(panel.queue_free)

# 创建提示面板的样式：半透明黑底 + 金色边框
func _make_notification_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.border_color = Color(1, 0.8, 0.2, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

# 消耗影分身
func _consume_clone():
	var clones = get_tree().get_nodes_in_group("shadow_clones")
	for c in clones:
		if is_instance_valid(c) and c.caster == self:
			c.disappear()
			return
	set_meta("has_clones", false)

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
