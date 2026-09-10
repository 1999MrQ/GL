class_name PoiseComponent extends Node
## 霸体条（策划案 §5.2：BOSS 与精英怪有霸体条，破霸体后进入 5s 易伤硬直）。
## 淬火脆化（策划案 §9.4）：削霸效率 +50%（poise_damage_mult）、霸体恢复暂停 3s。

signal broke

const REGEN_PER_SEC := 4.0
const BROKEN_DURATION := 5.0
const BROKEN_DAMAGE_TAKEN_MULT := 1.3 # 易伤：承伤 +30%（白模定值，可调）

var max_poise: float = 100.0
var poise: float = 100.0

var _broken_left: float = 0.0
var _status: StatusHolder

func setup(p_max_poise: float, status: StatusHolder) -> void:
	max_poise = p_max_poise
	poise = p_max_poise
	_status = status

func is_broken() -> bool:
	return _broken_left > 0.0

## 削霸（伤害结算侧调用；淬火期间效率 +50%）
func take_poise_damage(amount: float) -> void:
	if is_broken() or amount <= 0.0:
		return
	var mult := 1.0
	if _status != null:
		mult = _status.poise_damage_mult()
	poise = maxf(0.0, poise - amount * mult)
	if poise <= 0.0:
		_broken_left = BROKEN_DURATION
		broke.emit()

## 每物理帧：破霸倒计时（结束后回满）与未破时缓慢恢复（淬火暂停 3s）
func tick(delta: float) -> void:
	if is_broken():
		_broken_left -= delta
		if _broken_left <= 0.0:
			_broken_left = 0.0
			poise = max_poise
		return
	if _status != null and _status.poise_pause_active():
		return
	poise = minf(max_poise, poise + REGEN_PER_SEC * delta)
