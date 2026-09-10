class_name EnemyBase extends CharacterBody3D
## 敌人白模（技术方案 4.4：GDScript 分层状态机）。P0 实现"1 个敌人追击 AI"验收链路：
## IDLE(巡逻待机) → CHASE(追击) → WINDUP(前摇提示) → 打击判定 → RECOVER(后摇) → 冷却。
## NavigationAgent3D 寻路于 P1 接入（需要导航烘焙）；白模平地用直线追踪即可。

enum State { IDLE, CHASE, WINDUP, LUNGE, RECOVER, STAGGER, DEAD }

@export var config: EnemyConfig
## 沙盒血量倍率（默认 1.0 = 策划案数值）。白模竞技场调高它让反应链可观察；
## 正式关卡不用此字段，教学怪 33 HP 等文档锚点数值不受影响（玩测反馈 2026-09-10）。
@export var hp_multiplier: float = 1.0

@onready var visual_root: Node3D = $VisualRoot

var health: HealthComponent
var aura: ElementAura
var status: StatusHolder
var flash: FlashOverlay
var poise: PoiseComponent = null ## 霸体条（仅 poise_max > 0 的敌人持有，策划案 §5.2）
var has_super_armor: bool = false ## 常驻霸体（锈蚀傀儡）：免击退免硬直，破霸前

var state: int = State.IDLE
var face_dir := Vector3(0, 0, 1)
var horizontal_velocity := Vector3.ZERO
var vertical_velocity := 0.0

var _elapsed := 0.0
var _cooldown := 0.0
var _stagger_total := 0.35
var _debug_label: Label3D

func _ready() -> void:
	add_to_group("enemies")
	health = HealthComponent.new()
	health.max_hp = DamageFormulas.enemy_max_hp(config.level, config.hp_tier_mult * hp_multiplier)
	health.died.connect(_on_died)
	add_child(health)

	aura = ElementAura.new()
	aura.setup(DataManager.config("reactions"))
	add_child(aura)

	status = StatusHolder.new()
	status.setup(health)
	add_child(status)

	flash = FlashOverlay.new()
	var combat_cfg: CombatConfig = DataManager.config("combat")
	flash.setup(FlashOverlay.collect_meshes(visual_root), combat_cfg.flash_duration)
	add_child(flash)

	# 附着可视化：身体元素染色 + 头顶光珠（玩测反馈 2026-09-10）
	AuraVisualizer.attach(self, visual_root, aura)

	_debug_label = Label3D.new()
	_debug_label.position = Vector3(0, 2.2, 0)
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.no_depth_test = true
	_debug_label.font_size = 22
	_debug_label.visible = false
	add_child(_debug_label)

	if config.poise_max > 0.0:
		setup_poise()

func setup_poise() -> void:
	poise = PoiseComponent.new()
	poise.setup(config.poise_max, status)
	poise.broke.connect(_on_poise_broken)
	add_child(poise)

## 破霸：5s 易伤硬直（策划案 §5.2），结束后 PoiseComponent 自动回满
func _on_poise_broken() -> void:
	_stagger_total = 5.0
	if state != State.DEAD:
		_enter(State.STAGGER)

func damage_poise(amount: float) -> void:
	if poise != null:
		poise.take_poise_damage(amount)

## 易伤乘区（破霸后承伤 +30%）
func get_damage_taken_mult() -> float:
	if poise != null and poise.is_broken():
		return PoiseComponent.BROKEN_DAMAGE_TAKEN_MULT
	return 1.0

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	status.tick(delta)
	if poise != null:
		poise.tick(delta)
	_update_debug_label()
	# 冻结（卡文 Q）：完全停止行动，不吃 AI 推进（策划案 §7.3）
	if status.is_frozen():
		horizontal_move(Vector3.ZERO, 60.0, delta)
		_apply_gravity(delta)
		velocity = Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)
		move_and_slide()
		return
	match state:
		State.IDLE:
			_tick_idle(delta)
		State.CHASE:
			_tick_chase(delta)
		State.WINDUP:
			_tick_windup(delta)
		State.LUNGE:
			_tick_lunge(delta)
		State.RECOVER:
			_tick_recover(delta)
		State.STAGGER:
			_tick_stagger(delta)
	_apply_gravity(delta)
	velocity = Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)
	move_and_slide()

## 突进态（蚀化猎犬覆写；基类默认匀速前冲）
func _tick_lunge(delta: float) -> void:
	_elapsed += delta
	horizontal_move(face_dir * 10.0, 200.0, delta)
	if _elapsed >= 0.4:
		_enter(State.RECOVER)

## —— 状态实现 —— ##

func _tick_idle(_delta: float) -> void:
	horizontal_move(Vector3.ZERO, 20.0, _delta)
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= config.aggro_radius:
		_enter(State.CHASE)

func _tick_chase(delta: float) -> void:
	var player := _find_player()
	if player == null:
		_enter(State.IDLE)
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > config.aggro_radius * 1.6: # 脱离追击（P0 简化：无仇恨列表）
		_enter(State.IDLE)
		return
	_face_toward(to_player.normalized(), delta)
	if dist <= config.attack_range and _cooldown <= 0.0:
		_enter(State.WINDUP)
		return
	var speed := _effective_speed() * status.get_speed_mult()
	if dist <= config.attack_range * 0.8:
		speed = 0.0 # 贴脸停步，不推挤玩家
	var dir := to_player.normalized() if dist > 0.01 else Vector3.ZERO
	horizontal_move(dir * speed, 20.0, delta)

## 移速/攻击冷却虚方法：子类（狂暴阶段等）覆写
func _effective_speed() -> float:
	return config.move_speed

func _effective_attack_cooldown() -> float:
	return config.attack_cooldown

func _tick_windup(delta: float) -> void:
	_elapsed += delta
	horizontal_move(Vector3.ZERO, 30.0, delta)
	var player := _find_player()
	if player != null:
		_face_toward((player.global_position - global_position).normalized(), delta * 0.5)
	# 前摇提示：身体逐渐放大（白模 telegraph，正式动画为 P1 资产项）
	visual_root.scale = Vector3.ONE * (1.0 + 0.18 * minf(_elapsed / config.attack_windup, 1.0))
	if _elapsed >= config.attack_windup:
		visual_root.scale = Vector3.ONE
		_strike()
		_enter(State.RECOVER)

func _tick_recover(delta: float) -> void:
	_elapsed += delta
	horizontal_move(Vector3.ZERO, 20.0, delta)
	if _elapsed >= config.attack_recover:
		_cooldown = _effective_attack_cooldown()
		_enter(State.CHASE)

func _tick_stagger(delta: float) -> void:
	_elapsed += delta
	horizontal_move(Vector3.ZERO, 8.0, delta)
	if _elapsed >= _stagger_total:
		_enter(State.CHASE)

func _enter(next: int) -> void:
	state = next
	_elapsed = 0.0

## —— 攻击与受击 —— ##

func _strike() -> void:
	var cfg: CombatConfig = DataManager.config("combat")
	var origin := global_position + face_dir * 1.0 + Vector3.UP * 0.8
	for target in Combat.melee_query(self, origin, 1.0, 2): # layer_2 = player_body
		var ctx := DamageContext.make(self, config.level, cfg.enemy_attack_damage, 1.0)
		ctx.source_name = tr(config.display_name_key)
		ctx.knockback_force = 4.0
		Combat.resolve_attack(target, ctx)

## Combat 目标接口
func get_health() -> HealthComponent:
	return health

## DEF = 层级系数 × 等级（策划案 9.2：小怪 3×等级）
func get_defense() -> float:
	return config.def_level_mult * float(config.level)

func get_resistance(element: StringName) -> float:
	# 元素抗性表（策划案 §9.2：水元素 水抗+30%/火抗-10%，锈蚀傀儡 金抗+50%）
	match element:
		Elements.FIRE:
			return config.resist_fire
		Elements.WATER:
			return config.resist_water
		Elements.METAL:
			return config.resist_metal
		_:
			return 0.0

func get_aura() -> ElementAura:
	return aura

func status_holder() -> StatusHolder:
	return status

## 受击反馈：击退 + 硬直（淬火脆化经 status.stagger_mult() 延长硬直）。
## 常驻霸体（傀儡）：破霸前免击退免硬直，只闪白（策划案 §5.4 锈蚀傀儡）。
func apply_hit_reaction(_result: Dictionary, ctx: DamageContext) -> void:
	if state == State.DEAD:
		return
	flash.flash()
	var poise_broken := poise != null and poise.is_broken()
	if has_super_armor and not poise_broken:
		return
	var kb := ctx.knockback_force * (1.0 - config.knockback_resist)
	var dir := -face_dir
	if ctx.attacker is Node3D:
		var away := global_position - (ctx.attacker as Node3D).global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			dir = away.normalized()
	horizontal_velocity = dir * kb
	vertical_velocity = 2.0
	_stagger_total = config.stagger_time * status.stagger_mult()
	_enter(State.STAGGER)

func _on_died() -> void:
	_enter(State.DEAD)
	# 击杀事件单一来源：无论直接伤害还是 DoT 击杀都从这里广播（审核 2026-09-10 #2）
	EventBus.enemy_died.emit(self)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	# 白模死亡：下沉消失（死亡动画为 P1 资产项）
	var tween := create_tween()
	tween.tween_property(visual_root, "position:y", -2.0, 1.0)
	tween.tween_callback(queue_free)

## —— 工具 —— ##

func horizontal_move(target_velocity: Vector3, accel: float, delta: float) -> void:
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		vertical_velocity = -1.0
	else:
		vertical_velocity = maxf(vertical_velocity - 22.0 * delta, -40.0)

func _face_toward(dir: Vector3, delta: float) -> void:
	if dir.is_zero_approx():
		return
	face_dir = dir.normalized()
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		atan2(face_dir.x, face_dir.z),
		minf(1.0, 10.0 * delta))

func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

## 调试：附着可视化（技术方案 10.2：元素附着状态可视化）。
## 经 SceneTree 元数据读取开关，避免 EnemyBase ⇄ DebugPanel 的类名循环依赖。
func _update_debug_label() -> void:
	var visible_now := false
	var tree := get_tree()
	if tree != null:
		visible_now = bool(tree.get_meta("gl_show_aura_viz", false))
	_debug_label.visible = visible_now
	if not visible_now:
		return
	var parts: Array[String] = []
	for element in aura.aura_elements():
		parts.append("%s %.1f" % [tr(Elements.display_key(element)), aura.gu(element)])
	_debug_label.text = " | ".join(parts) if not parts.is_empty() else "-"
