class_name AttackState extends StateBase
## 白模三段连击（策划案 §7 普攻：三段，第三段附 1GU 本角色元素）。
## 近战（艾登/卡文）：球体步进 query；远程（莉赛尔火铳）：沿准线步进搜索首个目标 + 曳光。
## 帧数据（秒）：windup 起手 → active 判定帧 → recover 后摇；判定后按攻击键排队下一段。
## 倍率与附着量对应策划案 §9.2 / §5.3：60% / 65% / 80%，第三段 1GU；削霸 5/5/8。

const COMBO_DATA: Array[Dictionary] = [
	{"windup": 0.12, "active": 0.18, "recover": 0.30, "step": 1.8, "mult": 0.60, "poise": 5.0},
	{"windup": 0.10, "active": 0.16, "recover": 0.30, "step": 2.0, "mult": 0.65, "poise": 5.0},
	{"windup": 0.16, "active": 0.22, "recover": 0.46, "step": 2.8, "mult": 0.80, "poise": 8.0},
]

var _combo := 0
var _elapsed := 0.0
var _resolved := false
var _queued := false
var _entry_physics_frame := 0

func enter(msg: Dictionary) -> void:
	var p := player()
	_combo = int(msg.get("combo", 0))
	_elapsed = 0.0
	_resolved = false
	_queued = false
	_entry_physics_frame = Engine.get_physics_frames()
	p.vertical_velocity = 0.0
	var wish := p.wish_direction()
	if not wish.is_zero_approx():
		p.face_toward(wish, 1.0) # delta=1.0 → 立即完成转向

func physics_update(delta: float) -> void:
	var p := player()
	var data: Dictionary = COMBO_DATA[_combo]
	_elapsed += delta
	p.apply_gravity(delta)

	# 前扑步进（远程风格不前扑，站桩射击）
	var phase_speed := 0.0
	if _elapsed <= float(data["active"]) and p.stats.attack_style == CharacterConfig.AttackStyle.MELEE:
		phase_speed = float(data["step"]) / maxf(float(data["active"]), 0.01)
	p.horizontal_move(p.face_dir * phase_speed, p.movement.accel, delta)
	p.face_toward(p.face_dir, delta)

	# 瞬时判定：active 起始帧一次（技术方案 4.1）
	if not _resolved and _elapsed >= float(data["active"]):
		_resolved = true
		_resolve_hits(p, data)

	# 连段缓冲：进入攻击态后任意时刻按攻击键都排队（排除进入帧本身）
	if Engine.get_physics_frames() != _entry_physics_frame and p.actor_source.wants_attack():
		_queued = true

	if _elapsed >= float(data["active"]) + float(data["recover"]):
		if _queued and _combo < COMBO_DATA.size() - 1:
			sm.transition(&"attack", {"combo": _combo + 1})
		else:
			_combo = 0
			var wish := p.wish_direction()
			sm.transition(&"run" if not wish.is_zero_approx() else &"idle", {})

func _resolve_hits(p: PlayerCharacter, data: Dictionary) -> void:
	var cfg: CombatConfig = DataManager.config("combat")
	var ctx := DamageContext.make(p, p.level, p.atk, float(data["mult"]))
	ctx.source_name = "普攻%d" % (_combo + 1)
	ctx.knockback_force = cfg.knockback_heavy if _combo == 2 else cfg.knockback_light
	ctx.poise_damage = float(data["poise"])
	ctx.crit_rate = p.stats.crit_rate
	ctx.crit_damage = p.stats.crit_damage
	ctx.element_mastery = p.stats.element_mastery
	if _combo == 2:
		# 策划案 §7：第三段附 1GU 角色元素附着
		ctx.with_element(p.stats.element, 1.0)

	var hit_any := false
	if p.stats.attack_style == CharacterConfig.AttackStyle.RANGED:
		hit_any = _resolve_ranged(p, ctx)
	else:
		var origin := p.global_position + p.face_dir * 1.1 + Vector3.UP * 0.9
		for target in Combat.melee_query(p, origin, cfg.attack_range, 4): # layer_3 = enemy_body
			var result := Combat.resolve_attack(target, ctx)
			hit_any = hit_any or not result.is_empty()
	if hit_any:
		# 顿帧（策划案 P0 验收项）+ 能量（策划案 §9.1：普攻命中 +4）
		var heavy := _combo == 2
		GameManager.hitstop(
			cfg.hitstop_heavy_duration if heavy else cfg.hitstop_light_duration,
			cfg.hitstop_heavy_scale if heavy else cfg.hitstop_light_scale)
		AudioManager.play_sfx(&"hit_light")
		p.runtime.gain_energy(4.0)
		p.runtime.notify_combat()

## 远程火铳（莉赛尔）：沿准线步进搜索首个目标（自带轻微准度补偿），命中即曳光
func _resolve_ranged(p: PlayerCharacter, ctx: DamageContext) -> bool:
	var max_dist: float = p.stats.attack_style_ranged_distance
	var from := p.global_position + Vector3.UP * 1.2
	var step := 1.5
	var dist := step
	while dist <= max_dist:
		for target in Combat.melee_query(p, from + p.face_dir * dist, 1.0, 4):
			var result := Combat.resolve_attack(target, ctx)
			_spawn_tracer(p, from + p.face_dir * dist)
			return not result.is_empty()
		dist += step
	_spawn_tracer(p, from + p.face_dir * max_dist)
	return false

## 曳光占位视觉：细长方块 0.06s 淡出
func _spawn_tracer(p: PlayerCharacter, to_point: Vector3) -> void:
	var from := p.global_position + Vector3.UP * 1.2
	var length := from.distance_to(to_point)
	if length < 0.2:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Elements.color(p.stats.element), 0.8)
	mesh.material = mat
	tracer.mesh = mesh
	p.get_parent().add_child(tracer)
	tracer.global_position = (from + to_point) * 0.5
	if absf(p.face_dir.dot(Vector3.UP)) < 0.99:
		tracer.look_at(to_point, Vector3.UP)
	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(tracer.queue_free)
