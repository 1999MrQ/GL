class_name HitState extends StateBase
## 受击硬直（策划案 5.2：受击打断普攻与施法）。

const STAGGER_TIME := 0.35

var _elapsed := 0.0

func enter(msg: Dictionary) -> void:
	_elapsed = 0.0
	var p := player()
	# 击退量必须由调用方经 msg 传入（player_character.apply_hit_reaction）；
	# 默认零向量仅兜底，禁止在此读取成员变量——会覆盖刚设置的击退（审核 2026-09-10 #1）
	var knockback: Vector3 = msg.get("knockback", Vector3.ZERO)
	p.horizontal_velocity = knockback
	p.vertical_velocity = 2.5

func physics_update(delta: float) -> void:
	var p := player()
	_elapsed += delta
	p.horizontal_move(Vector3.ZERO, p.movement.decel * 0.6, delta)
	p.apply_gravity(delta)
	if _elapsed >= STAGGER_TIME and p.is_on_floor():
		var wish := p.wish_direction()
		sm.transition(&"run" if not wish.is_zero_approx() else &"idle", {})
