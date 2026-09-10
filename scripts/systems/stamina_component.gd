class_name StaminaComponent extends Node
## 体力（策划案 5.2 / 9.1）：上限 100；持续消耗（冲刺 15/s、攀爬 10/s、滑翔 8/s）；
## 停止消耗 2 秒后 20/s 恢复。重击为一次性消耗（consume）。

signal depleted

const REGEN_DELAY := 2.0

@export var max_stamina: float = 100.0
@export var regen_rate: float = 20.0

var stamina: float = 100.0
var _since_drain: float = 999.0

func ratio() -> float:
	return clampf(stamina / max_stamina, 0.0, 1.0) if max_stamina > 0.0 else 0.0

func can_afford(cost: float) -> bool:
	return stamina >= cost

## 持续消耗（每帧按速率调用）
func drain(rate_per_sec: float, delta: float) -> void:
	var before := stamina
	stamina = maxf(0.0, stamina - rate_per_sec * delta)
	_since_drain = 0.0
	if stamina <= 0.0 and before > 0.0:
		depleted.emit()

## 一次性消耗（重击 20，策划案 5.2）；不足则不动并返回 false
func consume(cost: float) -> bool:
	if not can_afford(cost):
		return false
	stamina -= cost
	_since_drain = 0.0
	if stamina <= 0.0:
		depleted.emit()
	return true

## 每物理帧调用：推进恢复
func tick(delta: float) -> void:
	_since_drain += delta
	if _since_drain >= REGEN_DELAY and stamina < max_stamina:
		stamina = minf(max_stamina, stamina + regen_rate * delta)
