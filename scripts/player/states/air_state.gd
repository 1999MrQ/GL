class_name AirState extends StateBase
## 空中：跳跃上升 / 下落合并；落地回地面状态。
## 空中再次按跳跃展开滑翔为 P2 范围（策划案 8.2），此处预留。

func enter(msg: Dictionary) -> void:
	var p := player()
	if msg.get("jump", false):
		p.vertical_velocity = p.movement.jump_velocity

func physics_update(delta: float) -> void:
	var p := player()
	var wish := p.wish_direction()
	# 空中操控按 air_control 折减
	p.horizontal_move(wish * p.movement.walk_speed, p.movement.accel * p.movement.air_control, delta)
	p.apply_gravity(delta)
	p.face_toward(wish, delta)

	# 落地（vertical_velocity 守卫避免起跳帧误判）
	if p.is_on_floor() and p.vertical_velocity <= 0.0:
		sm.transition(&"run" if not wish.is_zero_approx() else &"idle", {})
