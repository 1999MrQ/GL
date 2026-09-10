class_name BossColossus extends EnemyBase
## BOSS·蚀核巨像（策划案 §5.4：三阶段，验证全部 3 元素与至少 2 种反应）。
## 一阶段：近战砸击 + 冲撞（霸体条 200）。
## 二阶段（70% HP）：周期性自挂金属护壳（金附着 4GU，金抗 +80%、承伤 -70%）
##   ——必须用火打金附着触发熔金直接削壳（策划案 §9.2）。
## 三阶段（30% HP）：灼热地板持续灼烧 + 攻速 +30% + 承伤 +50%（策划案 §5.4）；
##   玩家用水元素技能打地板生成蒸汽安全区。

const SHELL_INTERVAL := 12.0
const PHASE2_RATIO := 0.7
const PHASE3_RATIO := 0.3
const ARENA_RADIUS := 15.0
const CHARGE_MIN_DIST := 4.0
const CHARGE_MAX_DIST := 10.0
const CHARGE_TIME := 0.55
const CHARGE_SPEED := 14.0

var shell_active := false
var phase := 1

var _shell_acc := 0.0
var _attack_count := 0
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _heat: HeatZone = null
var _hp_label: Label3D

func _ready() -> void:
	super()
	_hp_label = Label3D.new()
	_hp_label.position = Vector3(0, 4.6, 0)
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.font_size = 30
	add_child(_hp_label)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state != State.DEAD:
		_hp_label.text = "%s %d%%" % [tr(config.display_name_key), roundi(health.ratio() * 100.0)]
	# 护壳期间持续维持金附着（被熔金消耗时由 break_shell 关闭）
	if shell_active and state != State.DEAD and not aura.has_aura(Elements.METAL):
		aura.apply_incoming(Elements.METAL, 4.0)

## —— 阶段与机制 —— ##

func _update_phase() -> void:
	var ratio := health.ratio()
	if phase == 1 and ratio <= PHASE2_RATIO:
		phase = 2
		apply_shell()
		flash.flash(1.0, Color(0.9, 0.8, 0.3))
	elif phase == 2 and ratio <= PHASE3_RATIO:
		phase = 3
		shell_active = false # 三阶段停护壳循环（策划案 §5.4）
		_heat = HeatZone.spawn(get_parent(), global_position, ARENA_RADIUS)
		flash.flash(1.0, Color(1.0, 0.35, 0.1))

func _effective_speed() -> float:
	return config.move_speed * (1.2 if phase == 3 else 1.0)

func _effective_attack_cooldown() -> float:
	return config.attack_cooldown * (0.7 if phase == 3 else 1.0) # 三阶段攻速 +30%

func get_resistance(element: StringName) -> float:
	if shell_active and element == Elements.METAL:
		return 0.8 # 护壳金抗 +80%（策划案 §9.2）
	return super.get_resistance(element)

func get_damage_taken_mult() -> float:
	var mult := super.get_damage_taken_mult()
	if shell_active:
		mult *= 0.3 # 护壳承伤 -70%（白模定值，策划案未给数值）
	if phase == 3:
		mult *= 1.5 # 三阶段承伤 +50%（策划案 §5.4）
	return mult

## 金属护壳：自挂金附着 4GU
func apply_shell() -> void:
	shell_active = true
	_shell_acc = 0.0
	aura.apply_incoming(Elements.METAL, 4.0)
	flash.flash(0.9, Color(0.9, 0.8, 0.3))

## 熔金削壳（Combat 检测到 molten_gold 命中带壳目标时回调，策划案 §9.2）
func break_shell() -> void:
	if not shell_active:
		return
	shell_active = false
	aura.aura_elements().erase(Elements.METAL)
	flash.flash(1.0, Color(1.0, 0.8, 0.3))
	_stagger_total = 3.0 # 破壳硬直：输出窗口
	if state != State.DEAD:
		_enter(State.STAGGER)

## BOSS 死亡：清除灼热地板（HeatZone 挂在场景上，不由 BOSS 自动释放——复审 2026-09-11 #1）
func _on_died() -> void:
	if _heat != null and is_instance_valid(_heat):
		_heat.queue_free()
	super._on_died()

## —— 攻击：砸击 AOE / 冲撞交替 —— ##

func _tick_chase(delta: float) -> void:
	_update_phase()
	if phase == 2 and not shell_active:
		_shell_acc += delta
		if _shell_acc >= SHELL_INTERVAL:
			apply_shell()
	super._tick_chase(delta)

func _tick_windup(delta: float) -> void:
	_elapsed += delta
	horizontal_move(Vector3.ZERO, 30.0, delta)
	var player := _find_player()
	if player != null:
		_face_toward((player.global_position - global_position).normalized(), delta * 0.5)
	# 前摇提示：整体膨胀（白模 telegraph）
	visual_root.scale = Vector3.ONE * (1.0 + 0.22 * minf(_elapsed / config.attack_windup, 1.0))
	if _elapsed < config.attack_windup:
		return
	visual_root.scale = Vector3.ONE
	var dist := 999.0
	if player != null:
		dist = global_position.distance_to(player.global_position)
	_attack_count += 1
	# 冲撞：中距离且轮到第 3 次；否则砸地 AOE
	if _attack_count % 3 == 0 and dist >= CHARGE_MIN_DIST and dist <= CHARGE_MAX_DIST and player != null:
		_charge_dir = (player.global_position - global_position)
		_charge_dir.y = 0.0
		_charge_dir = _charge_dir.normalized()
		_charge_hit = false
		_enter(State.LUNGE)
		return
	_strike()
	_enter(State.RECOVER)

## 冲撞（策划案 §5.4：冲撞）：直线高速推进 + 单次接触判定
func _tick_lunge(delta: float) -> void:
	_elapsed += delta
	horizontal_move(_charge_dir * CHARGE_SPEED, 400.0, delta)
	if not _charge_hit:
		for target in Combat.melee_query(self, global_position + Vector3.UP * 1.2, 2.0, 2):
			if target.has_method("get_health"):
				var cfg: CombatConfig = DataManager.config("combat")
				var ctx := DamageContext.make(self, config.level, cfg.enemy_attack_damage * 0.85, 1.0)
				ctx.knockback_force = 8.0
				ctx.source_name = tr(config.display_name_key)
				Combat.resolve_attack(target, ctx)
				_charge_hit = true
	if _elapsed >= CHARGE_TIME:
		_enter(State.RECOVER)

## 砸地 AOE（策划案 §5.4：近战砸击）
func _strike() -> void:
	var cfg: CombatConfig = DataManager.config("combat")
	for target in Combat.melee_query(self, global_position + Vector3.UP * 0.6, 3.5, 2):
		var ctx := DamageContext.make(self, config.level, cfg.enemy_attack_damage, 1.0)
		ctx.knockback_force = 8.0
		ctx.source_name = tr(config.display_name_key)
		Combat.resolve_attack(target, ctx)
	TransmuteRing.spawn(get_parent(), global_position, 3.5, Color(0.8, 0.5, 0.3))
