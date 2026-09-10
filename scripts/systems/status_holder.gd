class_name StatusHolder extends Node
## 时效状态容器：承接元素反应的附加效果（策划案 9.4）——
## slow（白雾减速）/ armor_break（熔金破甲）/ dot（锈蚀持续伤害）/ stagger_up（淬火硬直强化）。
## P1 养成 BUFF 复用此容器扩展。

const DOT_TICK_SEC := 1.0

var health: HealthComponent

var _effects: Dictionary = {} # StringName(id) -> { "value": float, "remaining": float }
var _dot: Dictionary = {} # { "dps": float, "remaining": float, "tick_timer": float }

func setup(p_health: HealthComponent) -> void:
	health = p_health

func apply(id: StringName, value: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_effects[id] = {"value": value, "remaining": duration}

## 锈蚀类 DoT：每秒伤害 = 剧变基础伤害 × effect_value（结算时已换算为 dps 传入）
func apply_dot(dps: float, duration: float) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	_dot = {"dps": dps, "remaining": duration, "tick_timer": 0.0} # 覆盖旧 DoT（首版简化）

func get_speed_mult() -> float:
	return 1.0 - _effect_value(&"slow")

func get_def_mult() -> float:
	return 1.0 - _effect_value(&"armor_break")

## 淬火脆化：硬直时间倍率（无状态时 1.0）；同一效果 id 兼作削霸效率倍率（策划案 §9.4）
func stagger_mult() -> float:
	if _effects.has(&"stagger_up"):
		return float(_effects[&"stagger_up"]["value"])
	return 1.0

## 淬火脆化：削霸效率倍率（PoiseComponent 结算时调用）
func poise_damage_mult() -> float:
	return stagger_mult()

## 淬火脆化：霸体条恢复暂停（策划案 §9.4）
func poise_pause_active() -> bool:
	return _effects.has(&"poise_pause")

## 冻结（卡文 Q「深渊之拥」策划案 §7.3）：目标完全停止行动
func is_frozen() -> bool:
	return _effects.has(&"frozen")

func has_dot() -> bool:
	return not _dot.is_empty()

## 每物理帧推进（宿主在树内自动运行；测试可直接调用）
func tick(delta: float) -> void:
	for id in _effects.keys():
		_effects[id]["remaining"] -= delta
	for id in _effects.keys():
		if _effects[id]["remaining"] <= 0.0:
			_effects.erase(id)
	if _dot.is_empty():
		return
	_dot["remaining"] -= delta
	_dot["tick_timer"] = float(_dot["tick_timer"]) + delta
	if float(_dot["tick_timer"]) >= DOT_TICK_SEC:
		_dot["tick_timer"] = float(_dot["tick_timer"]) - DOT_TICK_SEC
		if health != null:
			var applied := health.take_damage(float(_dot["dps"]) * DOT_TICK_SEC)
			if applied > 0.0:
				_emit_dot_number(applied)
	if float(_dot["remaining"]) <= 0.0:
		_dot = {}

func _effect_value(id: StringName) -> float:
	return float(_effects[id]["value"]) if _effects.has(id) else 0.0

func _emit_dot_number(amount: float) -> void:
	var host := get_parent()
	if host is Node3D:
		EventBus.damage_number_requested.emit(
			(host as Node3D).global_position + Vector3(0, 1.7, 0),
			amount, Color(0.65, 0.65, 0.65), false)
