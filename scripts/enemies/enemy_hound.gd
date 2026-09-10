class_name HoundEnemy extends EnemyBase
## 蚀化猎犬（策划案 §5.4：快速突进撕咬）：
## 前摇锁定玩家方向 → LUNGE 猛冲 0.4s，接触判定一次性伤害。

const LUNGE_SPEED := 12.0
const LUNGE_TIME := 0.4

var _lunge_dir := Vector3.ZERO
var _lunge_hit := false

func _tick_windup(delta: float) -> void:
	_elapsed += delta
	horizontal_move(Vector3.ZERO, 30.0, delta)
	var player := _find_player()
	if player != null:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.001:
			_lunge_dir = to_player.normalized()
			_face_toward(_lunge_dir, delta)
	# 前摇提示：压低身体（与矿工的膨胀区分， telegraph 可读性）
	visual_root.scale = Vector3(1.15, 0.85, 1.15)
	if _elapsed >= config.attack_windup:
		visual_root.scale = Vector3.ONE
		_lunge_hit = false
		_enter(State.LUNGE)

func _tick_lunge(delta: float) -> void:
	_elapsed += delta
	horizontal_move(_lunge_dir * LUNGE_SPEED, 400.0, delta)
	if not _lunge_hit:
		for target in Combat.melee_query(self, global_position + Vector3.UP * 0.7, 1.0, 2):
			if target.has_method("get_health"):
				var cfg: CombatConfig = DataManager.config("combat")
				var ctx := DamageContext.make(self, config.level, cfg.enemy_attack_damage * 0.8, 1.0)
				ctx.knockback_force = 5.0
				ctx.source_name = tr(config.display_name_key)
				Combat.resolve_attack(target, ctx)
				_lunge_hit = true
	if _elapsed >= LUNGE_TIME:
		_enter(State.RECOVER)
