class_name Interactable extends Node3D
## 可交互对象基类（策划案 §10 F 交互）。
## 玩家每物理帧扫描 2.5m 内组 "interactables" 的最近对象；
## 按 F 调用 interact(player)；HUD 提示文案取 prompt()。

func _ready() -> void:
	add_to_group("interactables")

## 按 F 时调用（player 为交互发起者）
func interact(_player: PlayerCharacter) -> void:
	pass

## HUD 交互提示文案（已本地化）
func prompt() -> String:
	return ""
