class_name ElementAura extends Node
## 元素附着组件（技术方案 4.2 / 策划案 5.3 修正 B6 的可实现规则）：
## 1. 附着量单位 GU；同一敌人每种元素最多 1 层，重复施加取 max 不叠加
## 2. 衰减：每秒 -0.2GU，归零消失（4GU 满附着约持续 20s）
## 3. 单一 ICD（单机简化取舍）：同种元素的"附着施加"与"反应触发"共用 2.5s 间隔；
##    ICD 仅由反应触发设置——普攻挂元素 → 换元素触发反应的标准循环不受影响
## 4. 反应消耗双方附着量（aura_cost），残留元素保留

const DECAY_PER_SEC := 0.2
const REACTION_ICD_SEC := 2.5

var reaction_table: ReactionTable = null

var _auras: Dictionary = {} ## StringName(元素) -> float(剩余 GU)
var _icd_until: Dictionary = {} ## StringName(元素) -> float(内部时钟，秒)
var _clock: float = 0.0 ## 内部时钟：由 tick() 推进，测试可直接推进复现时序

func setup(table: ReactionTable) -> void:
	reaction_table = table

func _physics_process(delta: float) -> void:
	tick(delta)

## 推进衰减与 ICD 时钟（宿主每物理帧调用；测试可直接调用）
func tick(delta: float) -> void:
	_clock += delta
	if _auras.is_empty():
		return
	for element in _auras.keys():
		_auras[element] = maxf(0.0, _auras[element] - DECAY_PER_SEC * delta)
	for element in _auras.keys():
		if _auras[element] <= 0.0:
			_auras.erase(element)

func gu(element: StringName) -> float:
	return _auras.get(element, 0.0)

func has_aura(element: StringName) -> bool:
	return gu(element) > 0.0

func aura_elements() -> Array:
	return _auras.keys()

func is_icd_blocked(element: StringName) -> bool:
	return _clock < float(_icd_until.get(element, -1.0))

## 后手元素施加入口。返回触发的 ReactionDefinition；未触发反应（纯附着或被 ICD 挡）返回 null。
func apply_incoming(element: StringName, gu_amount: float) -> ReactionDefinition:
	if element == &"" or gu_amount <= 0.0:
		return null
	# 规则 3：incoming 元素在 ICD 内 → 本次施加整体无效
	if is_icd_blocked(element):
		return null
	# 查反应表：既有附着为先手、incoming 为后手
	if reaction_table != null:
		for existing in _auras.keys():
			if existing == element:
				continue
			var rd := reaction_table.find(existing, element)
			if rd == null:
				continue
			# 规则 4：消耗双方附着量，残留保留
			_auras[existing] = _auras[existing] - rd.aura_cost
			if _auras[existing] <= 0.0:
				_auras.erase(existing)
			# 规则 3：反应触发后，双方元素进入 2.5s ICD
			_icd_until[existing] = _clock + REACTION_ICD_SEC
			_icd_until[element] = _clock + REACTION_ICD_SEC
			_notify_reaction(rd)
			return rd
	# 无反应：附着（同元素不叠加取 max）
	_auras[element] = maxf(_auras.get(element, 0.0), gu_amount)
	_notify_applied(element)
	return null

## 直接设置附着量（绕过反应管线与 ICD）。仅供宿主自身机制使用（如 BOSS 自挂护壳——
## 经 apply_incoming 会在有火附着时自触熔金、在有水附着时自触锈蚀，且受 ICD 阻塞）。
## 外部攻击附着请一律走 apply_incoming。
func set_aura(element: StringName, gu_amount: float) -> void:
	if element == &"" or gu_amount <= 0.0:
		return
	_auras[element] = maxf(_auras.get(element, 0.0), gu_amount)
	_notify_applied(element)

## 清除某元素附着（熔金削壳等机制）；不动 ICD 时钟。
func clear(element: StringName) -> void:
	_auras.erase(element)

func _notify_reaction(rd: ReactionDefinition) -> void:
	var host := get_parent()
	if host != null:
		EventBus.reaction_triggered.emit(host, rd.id)

func _notify_applied(element: StringName) -> void:
	var host := get_parent()
	if host != null:
		EventBus.element_applied.emit(host, element, _auras.get(element, 0.0))
