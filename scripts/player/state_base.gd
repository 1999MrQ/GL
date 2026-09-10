class_name StateBase extends RefCounted
## 玩家状态基类：子类按需覆写；sm.agent 为宿主 PlayerCharacter。

var sm: StateMachine

func enter(_msg: Dictionary) -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func player() -> PlayerCharacter:
	return sm.agent as PlayerCharacter
