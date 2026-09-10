class_name IActorSource extends RefCounted
## 输入源抽象（技术方案 12 联机预留）：角色只读本接口，不直接耦合 Input。
## 单机用 LocalActorSource；远期联机把实现替换为网络输入源，角色逻辑零改动。

## 移动输入：x 右为正 / y 前为正（相机相对）
func move_vector() -> Vector2:
	return Vector2.ZERO

func wants_jump() -> bool:
	return false

func wants_sprint() -> bool:
	return false

func wants_attack() -> bool:
	return false

## P1：炼成技 E / 炼成爆发 Q / 等价交换 R（策划案 §5.1）
func wants_skill_e() -> bool:
	return false

func wants_burst_q() -> bool:
	return false

func wants_equivalence() -> bool:
	return false

## P2：F 交互（采集/宝箱/传送阵，策划案 §5.1）
func wants_interact() -> bool:
	return false
