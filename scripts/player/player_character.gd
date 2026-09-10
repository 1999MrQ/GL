class_name PlayerCharacter extends CharacterBody3D
## 玩家角色（技术方案 §3.1 节点结构 + 策划案 §7 三角色之一）。
## P1：由 PartyManager 常驻装配（3 份实例，切换时资源不重置）；
## 也可独立使用（测试场景：自建 runtime/inventory，party 为 null）。
## 手感三件套（土狼时间/输入缓冲/相机相对移动）不变。

@export var movement: MovementConfig
@export var stats: CharacterConfig

@onready var visual_root: Node3D = $VisualRoot
@onready var camera_rig: CameraRig = $CameraRig

var actor_source: IActorSource
var fsm: StateMachine
var health: HealthComponent
var stamina: StaminaComponent
var flash: FlashOverlay
var runtime: CharacterRuntime
var inventory: PartyInventory ## 队伍级背包引用（质之炼成代价）；独立使用时自建
var party: PartyManager = null ## 所属队伍；独立使用时为 null

var level: int = 1
var atk: float = 0.0
var face_dir := Vector3(0, 0, 1) ## 视觉朝向（白模约定：模型正面为 +Z）
var horizontal_velocity := Vector3.ZERO
var vertical_velocity := 0.0
var jump_buffer_timer := 0.0 ## 手感三件套：跳跃输入缓冲 0.15s
var coyote_timer := 0.0 ## 手感三件套：土狼时间 0.1s

## 等价交换状态（策划案 §6.1）：R 激活，持续 10s 或施放 1 次技能后结束
var equivalence_active := false
var equivalence_timer := 0.0
var super_armor_left := 0.0 ## Q 自身霸体（艾登「钢之洪流」5s）

var _spawn_position := Vector3.ZERO
var _dead := false

func _ready() -> void:
	add_to_group("player")
	actor_source = LocalActorSource.new()
	if runtime == null: # 独立使用（测试场景）：自建队伍级资源
		runtime = CharacterRuntime.new()
		inventory = PartyInventory.new()
	_bind_runtime()

	stamina = StaminaComponent.new()
	add_child(stamina)

	flash = FlashOverlay.new()
	var combat_cfg: CombatConfig = DataManager.config("combat")
	flash.setup(FlashOverlay.collect_meshes(visual_root), combat_cfg.flash_duration)
	add_child(flash)

	fsm = StateMachine.new(self, {
		"idle": IdleState.new(),
		"run": RunState.new(),
		"air": AirState.new(),
		"climb": ClimbState.new(),
		"attack": AttackState.new(),
		"hit": HitState.new(),
	}, &"idle")

	_spawn_position = global_position
	camera_rig.initialize(self)
	if party == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## PartyManager 在 add_child 之前注入队伍资源
func bind_party(p_runtime: CharacterRuntime, p_inventory: PartyInventory, p_party: PartyManager) -> void:
	runtime = p_runtime
	inventory = p_inventory
	party = p_party

## 资源唯一存储在 CharacterRuntime（技术方案 §3.2/§7），组件是视图
func _bind_runtime() -> void:
	runtime.setup(stats, StringName(stats.display_name_key))
	if health == null:
		health = HealthComponent.new()
		add_child(health)
	health.max_hp = runtime.max_hp
	health.set_full()
	if not health.damaged.is_connected(_sync_hp_to_runtime):
		health.damaged.connect(_sync_hp_to_runtime)
		health.healed.connect(_sync_hp_to_runtime)
	level = runtime.level()
	atk = runtime.atk()

func _sync_hp_to_runtime(_amount: float) -> void:
	runtime.hp = health.hp

func _physics_process(delta: float) -> void:
	if _dead:
		return
	# 手感三件套计时器
	if actor_source.wants_jump():
		jump_buffer_timer = movement.jump_buffer
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	coyote_timer = movement.coyote_time if is_on_floor() else maxf(0.0, coyote_timer - delta)

	stamina.tick(delta)
	_tick_combat_inputs()
	if equivalence_active:
		equivalence_timer -= delta
		if equivalence_timer <= 0.0:
			equivalence_active = false
	super_armor_left = maxf(0.0, super_armor_left - delta)

	fsm.physics_process(delta)
	velocity = Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)
	move_and_slide()

func _process(delta: float) -> void:
	fsm.process(delta)

## —— 技能与等价交换（策划案 §5.1 输入 / §6.1-6.3 规则）—— ##

var current_interactable: Node = null ## P2：扫描到的最近可交互对象（HUD 提示与 F 触发）

func _tick_combat_inputs() -> void:
	if actor_source.wants_skill_e():
		try_cast_skill_e()
	if actor_source.wants_burst_q():
		try_cast_burst_q()
	if actor_source.wants_equivalence():
		try_activate_equivalence()
	# P2 交互（策划案 §10 F 交互）：扫描 2.5m 内最近可交互对象
	current_interactable = find_interactable()
	if actor_source.wants_interact() and current_interactable != null:
		current_interactable.call("interact", self)

## 眼部沿 direction 的墙面探测（攀爬入口；仅 world 层）
func probe_wall(direction: Vector3) -> Dictionary:
	var from := global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 0.9, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

## 2.5m 内最近的可交互对象（组 interactables）
func find_interactable() -> Node:
	var best: Node = null
	var best_dist := 2.5
	for node in get_tree().get_nodes_in_group("interactables"):
		var n3 := node as Node3D
		if n3 == null:
			continue
		var dist := n3.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best

func try_cast_skill_e() -> void:
	if _dead or runtime.e_cooldown_left > 0.0:
		return
	var eq := take_equivalence_params() # 施放瞬间支付代价（策划案 §6.1）
	Skills.cast(self, true, eq)
	runtime.e_cooldown_left = stats.skill_e_cooldown * eq.get("cooldown_mult", 1.0) # 智祭 CD -30%

func try_cast_burst_q() -> void:
	if _dead:
		return
	if not runtime.consume_burst_energy(): # Q 只耗能量 100（策划案 §6.3 第 6 条）
		return
	var eq := take_equivalence_params() # R 强化 Q 时按角色绑定代价支付一次
	Skills.cast(self, false, eq)

func try_activate_equivalence() -> void:
	if equivalence_active or _dead:
		return
	if not _can_pay_equivalence():
		EventBus.equivalence_failed.emit(stats.element) # HUD 提示（素材不足等）
		return
	equivalence_active = true
	equivalence_timer = 10.0

## R 代价可支付性：血/智总能支付；质之炼成需 3 份炼金尘（策划案 §6.2）
func _can_pay_equivalence() -> bool:
	if stats.equivalence_type == CharacterConfig.EquivalenceType.MATTER:
		return inventory == null or inventory.can_take_dust(3)
	return true

## 施放瞬间消费 R：支付代价并返回强化参数（策划案 §6.2 数值表）
func take_equivalence_params() -> Dictionary:
	if not equivalence_active:
		return {}
	equivalence_active = false
	var params := {}
	match stats.equivalence_type:
		CharacterConfig.EquivalenceType.BLOOD:
			# 血之炼成：15% 当前 HP，保底扣至剩 1 HP 绝不致死（策划案 §6.3 第 2 条）
			var cost := minf(maxf(0.0, health.hp - 1.0), health.hp * 0.15)
			health.hp -= cost
			runtime.hp = health.hp
			params["damage_mult"] = 1.5
			params["lifesteal"] = 0.1
		CharacterConfig.EquivalenceType.WISDOM:
			runtime.mp = maxf(0.0, runtime.mp * 0.6) # 智之炼成：40% 当前 MP
			params["area_mult"] = 1.5
			params["cooldown_mult"] = 0.7
		CharacterConfig.EquivalenceType.MATTER:
			if inventory != null:
				inventory.take_dust(3) # 质之炼成：3 份炼金尘
			params["effect_duration_mult"] = 2.0
	return params

func get_party() -> PartyManager:
	return party

## —— 移动工具（状态层调用）—— ##

## 期望移动方向（相机相对，水平面归一）
func wish_direction() -> Vector3:
	var input_vec := actor_source.move_vector()
	if input_vec.is_zero_approx():
		return Vector3.ZERO
	var dir := camera_rig.forward_flat() * (-input_vec.y) + camera_rig.right_flat() * input_vec.x
	return dir.normalized()

func horizontal_move(target_velocity: Vector3, accel: float, delta: float) -> void:
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)

## 重力自实现（技术方案 3.1）；贴地时给微小下压保持 floor 接触
func apply_gravity(delta: float) -> void:
	if is_on_floor():
		vertical_velocity = -1.0
	else:
		vertical_velocity = maxf(
			vertical_velocity - movement.gravity * delta,
			-movement.max_fall_speed)

func face_toward(dir: Vector3, delta: float) -> void:
	if dir.is_zero_approx():
		return
	face_dir = dir.normalized()
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		atan2(face_dir.x, face_dir.z),
		minf(1.0, movement.rotate_speed * delta))

## —— Combat 目标接口（技术方案 4.3 鸭子类型契约）—— ##

func get_health() -> HealthComponent:
	return health

func get_defense() -> float:
	return 0.0 # 玩家减伤暂不计；养成落地时补齐（策划案 9.1）

func get_resistance(_element: StringName) -> float:
	return 0.0

## 受击反馈：击退 + 硬直 + 闪白；Q 霸体期间免击退免硬直（策划案 §7.1）
func apply_hit_reaction(result: Dictionary, ctx: DamageContext) -> void:
	if health.invincible or _dead:
		return
	runtime.gain_energy(5.0) # 策划案 §9.1：受击 +5 能量
	runtime.notify_combat()
	flash.flash()
	if super_armor_left > 0.0:
		return
	var kb_dir := -face_dir
	if ctx.attacker is Node3D:
		var away := global_position - (ctx.attacker as Node3D).global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			kb_dir = away.normalized()
	horizontal_velocity = kb_dir * maxf(ctx.knockback_force, 3.0)
	vertical_velocity = 2.5
	# 击退量经 msg 传入 HitState（审核 2026-09-10 #1）
	fsm.transition(&"hit", {"knockback": horizontal_velocity})
	EventBus.player_damaged.emit(float(result.get("damage", 0.0)))
	GameManager.hitstop(0.06, 0.1)

## —— 死亡与复活（PartyManager 驱动；独立模式自复活）—— ##

func _on_died() -> void:
	_dead = true
	equivalence_active = false
	EventBus.player_died.emit()
	horizontal_velocity = Vector3.ZERO
	if party == null:
		# 子节点 Timer 随宿主释放，避免场景切换后悬挂回调（审核 2026-09-10 #5）
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = 1.5
		timer.timeout.connect(func() -> void:
			timer.queue_free()
			revive_at(_spawn_position)
		)
		add_child(timer)
		timer.start()

func is_dead() -> bool:
	return _dead

## 就地满血复活（PartyManager 传出生点/原地）
func revive_at(pos: Vector3) -> void:
	global_position = pos
	horizontal_velocity = Vector3.ZERO
	vertical_velocity = 0.0
	health.set_full()
	runtime.hp = health.hp
	_dead = false
	if fsm.current != null:
		fsm.transition(&"idle", {})
