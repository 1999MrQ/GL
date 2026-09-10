class_name LocalActorSource extends IActorSource
## 本地输入实现：全部走 InputMap 动作名（技术方案 9：代码零硬编码键位）。

func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func wants_jump() -> bool:
	return Input.is_action_just_pressed("jump")

func wants_sprint() -> bool:
	return Input.is_action_pressed("sprint")

func wants_attack() -> bool:
	return Input.is_action_just_pressed("attack")

func wants_skill_e() -> bool:
	return Input.is_action_just_pressed("skill_e")

func wants_burst_q() -> bool:
	return Input.is_action_just_pressed("burst_q")

func wants_equivalence() -> bool:
	return Input.is_action_just_pressed("equivalence_r")

func wants_interact() -> bool:
	return Input.is_action_just_pressed("interact")
