class_name RunState extends StateBase
## 地面移动：走/跑合并，冲刺为速度修正（策划案 5.2：冲刺耗体力 15/s，耗尽降为步行）。

func physics_update(delta: float) -> void:
	var p := player()
	var wish := p.wish_direction()
	var sprinting := p.actor_source.wants_sprint() \
		and not wish.is_zero_approx() and p.stamina.can_afford(0.1)
	var speed := p.movement.sprint_speed if sprinting else p.movement.walk_speed
	if sprinting:
		p.stamina.drain(15.0, delta) # 冲刺 15/s（策划案 5.2）
	p.horizontal_move(wish * speed, p.movement.accel, delta)
	p.apply_gravity(delta)
	p.face_toward(wish, delta)

	if p.jump_buffer_timer > 0.0 and (p.is_on_floor() or p.coyote_timer > 0.0):
		p.jump_buffer_timer = 0.0
		sm.transition(&"air", {"jump": true})
	elif p.actor_source.wants_attack():
		sm.transition(&"attack", {})
	elif not p.is_on_floor():
		sm.transition(&"air", {})
	elif wish.is_zero_approx():
		sm.transition(&"idle", {})
