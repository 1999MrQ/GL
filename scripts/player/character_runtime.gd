class_name CharacterRuntime extends RefCounted
## 角色运行时数据（技术方案 §3.2/§7）：HP/MP/能量/技能冷却。
## 切换不重置——数据存在这里而不是节点上，非激活期间由 PartyManager 代管后台恢复。

const MAX_ENERGY := 100.0
const OUT_OF_COMBAT_SEC := 5.0
const MP_REGEN_COMBAT := 2.0
const MP_REGEN_OFFCOMBAT := 8.0

var character_id: StringName = &""
var config: CharacterConfig

var max_hp: float = 0.0
var hp: float = 0.0 ## HP 的权威存储（组件 health.hp 只是视图；组件信号回写此处）
var max_mp: float = 0.0
var mp: float = 0.0
var energy: float = 0.0
var e_cooldown_left: float = 0.0

var _out_of_combat_timer: float = OUT_OF_COMBAT_SEC

func setup(p_config: CharacterConfig, p_id: StringName) -> void:
	config = p_config
	character_id = p_id
	max_hp = DamageFormulas.character_max_hp(p_config.base_hp, p_config.level)
	hp = max_hp
	max_mp = 80.0 + 2.0 * float(p_config.level) # 策划案 §9.1
	mp = max_mp

func level() -> int:
	return config.level

func atk() -> float:
	return DamageFormulas.character_atk(config.base_atk, config.level)

## 进入战斗状态（普攻命中 / 施放技能 / 受击时调用）
func notify_combat() -> void:
	_out_of_combat_timer = 0.0

## 前台角色的资源 tick（PartyManager 每帧调用）
func tick_resources(delta: float) -> void:
	e_cooldown_left = maxf(0.0, e_cooldown_left - delta)
	_out_of_combat_timer = minf(_out_of_combat_timer + delta, OUT_OF_COMBAT_SEC)
	var regen := MP_REGEN_OFFCOMBAT if _out_of_combat_timer >= OUT_OF_COMBAT_SEC else MP_REGEN_COMBAT
	mp = minf(max_mp, mp + regen * delta)

## 后台角色的资源 tick（策划案 §6.3：后台 MP 以 2%/3s 缓慢恢复，HP 不恢复）
func tick_reserve(delta: float) -> void:
	e_cooldown_left = maxf(0.0, e_cooldown_left - delta)
	mp = minf(max_mp, mp + max_mp * 0.02 / 3.0 * delta)

func gain_energy(amount: float) -> void:
	energy = minf(MAX_ENERGY, energy + amount)

func can_cast_burst() -> bool:
	return energy >= MAX_ENERGY

func consume_burst_energy() -> bool:
	if not can_cast_burst():
		return false
	energy = 0.0
	return true
