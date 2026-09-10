class_name HealthComponent extends Node
## 生命组件：HP 结算的唯一入口（受击 / DoT / 治疗都走这里）。

signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var max_hp: float = 100.0
@export var invincible: bool = false

var hp: float = -1.0 # <0 表示未初始化，进树时取满

func _ready() -> void:
	if hp < 0.0:
		hp = max_hp

func ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0

func is_dead() -> bool:
	return hp <= 0.0

## 返回实际生效的伤害量
func take_damage(amount: float) -> float:
	if invincible or is_dead() or amount <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp -= applied
	damaged.emit(applied)
	if hp <= 0.0:
		died.emit()
	return applied

func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var applied := minf(max_hp - hp, amount)
	hp += applied
	healed.emit(applied)
	return applied

func set_full() -> void:
	hp = max_hp
