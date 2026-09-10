class_name IdleState extends StateBase
## 静止：减速停下；有输入转移动，可起手攻击 / 跳跃。

func enter(_msg: Dictionary) -> void:
	player().vertical_velocity = 0.0

func physics_update(delta: float) -> void:
	var p := player()
	p.horizontal_move(Vector3.ZERO, p.movement.decel, delta)
	p.apply_gravity(delta)
	if p.jump_buffer_timer > 0.0:
		p.jump_buffer_timer = 0.0
		sm.transition(&"air", {"jump": true})
	elif p.actor_source.wants_attack():
		sm.transition(&"attack", {})
	elif not p.wish_direction().is_zero_approx():
		sm.transition(&"run", {})
	elif not p.is_on_floor():
		sm.transition(&"air", {})
