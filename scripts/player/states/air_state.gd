class_name AirState extends StateBase
## 空中：跳跃上升 / 下落合并；落地回地面状态。
## P2 滑翔（策划案 §8.2 / §5.2）：空中再次按跳跃展开滑翔翼——
## 垂直速度钳制 -3 m/s，水平可操控，耗体力 8/s；再按取消 / 体力尽 / 落地 / 受击取消。

const GLIDE_FALL_CLAMP := 3.0
const GLIDE_STAMINA_DRAIN := 8.0
const GLIDE_SPEED_MULT := 1.25

var gliding := false

func enter(msg: Dictionary) -> void:
	var p := player()
	gliding = false
	if msg.get("jump", false):
		p.vertical_velocity = p.movement.jump_velocity

func physics_update(delta: float) -> void:
	var p := player()
	var wish := p.wish_direction()

	# 滑翔开关：空中再按跳跃展开 / 再按取消
	if p.actor_source.wants_jump():
		if not gliding and p.vertical_velocity < 0.0 and p.stamina.can_afford(0.5):
			gliding = true
		elif gliding:
			gliding = false
	# 体力耗尽强制收翼
	if gliding:
		p.stamina.drain(GLIDE_STAMINA_DRAIN, delta)
		if p.stamina.stamina <= 0.0:
			gliding = false

	# 垂直：滑翔钳制下坠速度（策划案 §8.2：-3 m/s）；否则常规重力
	if gliding:
		p.vertical_velocity = maxf(p.vertical_velocity - p.movement.gravity * delta, -GLIDE_FALL_CLAMP)
	else:
		p.apply_gravity(delta)

	# 水平：滑翔时操控性更好
	var speed := p.movement.walk_speed * (GLIDE_SPEED_MULT if gliding else 1.0)
	p.horizontal_move(wish * speed, p.movement.accel * p.movement.air_control * (1.5 if gliding else 1.0), delta)
	p.face_toward(wish, delta)

	# 攀爬入口：空中贴向 ≥65° 陡面（滑翔贴墙时尤为自然）
	if not wish.is_zero_approx():
		var hit := p.probe_wall(wish)
		if not hit.is_empty() and ClimbState.is_climbable(hit.normal):
			p.vertical_velocity = 0.0
			sm.transition(&"climb", {"normal": hit.normal})
			return

	# 落地（vertical_velocity 守卫避免起跳帧误判）
	if p.is_on_floor() and p.vertical_velocity <= 0.0:
		sm.transition(&"run" if not wish.is_zero_approx() else &"idle", {})
