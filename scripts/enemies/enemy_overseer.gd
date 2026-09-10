class_name OverseerEnemy extends EnemyBase
## 精英·矿监工（策划案 §5.4：双阶段、召唤矿工；§5.2 霸体条）。
## P1 精英战验收：60-90s 且有博弈感（破霸窗口 / 召唤压力 / 狂暴阶段）。

const SUMMON_CD := 12.0
const MAX_MINIONS := 2
const PHASE2_HP_RATIO := 0.5

var minion_scene: PackedScene = preload("res://scenes/characters/enemies/enemy_miner.tscn")

var _summon_cd := 8.0
var _phase2 := false
var _minions: Array = []
var _hp_label: Label3D

func _ready() -> void:
	super()
	# 精英血条（白模常显 Label3D；正式 Boss 条 HUD 是 P3 屏清单）
	_hp_label = Label3D.new()
	_hp_label.position = Vector3(0, 2.6, 0)
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.font_size = 26
	add_child(_hp_label)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state != State.DEAD:
		_hp_label.text = "%s %d%%" % [tr(config.display_name_key), roundi(health.ratio() * 100.0)]

## 二阶段（70%→50% HP 取中，策划案定 50%）：狂暴——移速/攻速提升
func _effective_speed() -> float:
	return config.move_speed * (1.25 if _phase2 else 1.0)

func _effective_attack_cooldown() -> float:
	return config.attack_cooldown * (0.7 if _phase2 else 1.0)

func _tick_chase(delta: float) -> void:
	if not _phase2 and health.hp < health.max_hp * PHASE2_HP_RATIO:
		_phase2 = true
		flash.flash(0.9, Color(1.0, 0.4, 0.2))
		_summon_cd = minf(_summon_cd, 3.0) # 狂暴后很快召唤一波
	_summon_cd = maxf(0.0, _summon_cd - delta)
	if _summon_cd <= 0.0:
		_summon()
		_summon_cd = SUMMON_CD * (0.6 if _phase2 else 1.0)
	super._tick_chase(delta)

## 召唤蚀化矿工（场上随从上限 2；沙盒倍率 3× 血，避免秒融）
func _summon() -> void:
	_minions = _minions.filter(func(m: Variant) -> bool: return is_instance_valid(m))
	if _minions.size() >= MAX_MINIONS:
		return
	var minion := minion_scene.instantiate()
	minion.hp_multiplier = 3.0
	var offset := Vector3(randf_range(-2.0, 2.0), 0.5, randf_range(-2.0, 2.0))
	minion.position = global_position + offset
	get_parent().add_child(minion)
	_minions.append(minion)
	TransmuteRing.spawn(get_parent(), global_position, 2.0, Color(0.9, 0.5, 0.9))
