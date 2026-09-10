class_name MoteEnemy extends EnemyBase
## 游荡水元素（策划案 §5.4：远程水弹、给自己挂水——教学目标：用火打蒸汽爆发）。
## 风筝 AI：与玩家保持 5-9m；每 5s 自挂 1GU 水附着。

const KITE_MIN := 5.0
const KITE_MAX := 9.0
const SELF_AURA_PERIOD := 5.0

var _self_aura_acc := 0.0

func _physics_process(delta: float) -> void:
	_self_aura_acc += delta
	if _self_aura_acc >= SELF_AURA_PERIOD:
		_self_aura_acc = 0.0
		aura.apply_incoming(Elements.WATER, 1.0) # 自挂水：给玩家"火→蒸汽爆发"的机会
	super._physics_process(delta)

## 风筝：距离过近后退，过远接近，区间内停下施法
func _tick_chase(delta: float) -> void:
	var player := _find_player()
	if player == null:
		_enter(State.IDLE)
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > config.aggro_radius * 1.6:
		_enter(State.IDLE)
		return
	_face_toward(to_player.normalized(), delta)
	if dist <= KITE_MAX and _cooldown <= 0.0:
		_enter(State.WINDUP)
		return
	var move_dir := Vector3.ZERO
	if dist < KITE_MIN:
		move_dir = -to_player.normalized() # 后撤
	elif dist > KITE_MAX:
		move_dir = to_player.normalized()
	var speed := _effective_speed() * status.get_speed_mult()
	horizontal_move(move_dir * speed, 20.0, delta)

## 远程水弹替代近战点判
func _strike() -> void:
	var player := _find_player()
	if player == null:
		return
	var bolt := PoolManager.spawn(Projectile.POOL_ID)
	if bolt == null:
		return
	var from := global_position + Vector3.UP * 1.2
	var dir := (player.global_position + Vector3.UP * 1.0 - from).normalized()
	get_parent().add_child(bolt)
	(bolt as Projectile).launch(from, dir, DataManager.config("combat").enemy_attack_damage * 0.5, self)
