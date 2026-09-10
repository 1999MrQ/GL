class_name Skills
## 技能执行器（技术方案 §4 / 策划案 §7 技能组、§9.2 倍率表、§6 等价交换）。
## 形态由 CharacterConfig 的 shape 字段分发；数值一律走 DamageContext → Combat 统一管线。
## eq 参数由 PlayerCharacter.take_equivalence_params() 在施放瞬间生成（已支付代价）。

## 统一施放入口：is_e = 炼成技 / 炼成爆发
static func cast(p: PlayerCharacter, is_e: bool, eq: Dictionary) -> void:
	var cfg: CharacterConfig = p.stats
	var ctx := DamageContext.make(p, p.runtime.level(), p.runtime.atk(), 1.0)
	ctx.crit_rate = cfg.crit_rate
	ctx.crit_damage = cfg.crit_damage
	ctx.element_mastery = cfg.element_mastery
	ctx.element = cfg.element
	ctx.aura_gu = cfg.skill_e_gu if is_e else cfg.skill_q_gu
	ctx.skill_mult = cfg.skill_e_mult if is_e else cfg.skill_q_mult
	ctx.poise_damage = cfg.skill_e_poise_damage if is_e else cfg.skill_q_poise_damage
	ctx.equivalence_mult = eq.get("damage_mult", 1.0)
	ctx.lifesteal = eq.get("lifesteal", 0.0)
	ctx.effect_duration_mult = eq.get("effect_duration_mult", 1.0)
	var shape: StringName = cfg.skill_e_shape if is_e else cfg.skill_q_shape
	var range_base: float = cfg.skill_e_range if is_e else cfg.skill_q_range
	var range_size: float = range_base * eq.get("area_mult", 1.0)
	var origin := p.global_position
	var dir := p.face_dir

	var hit_any := false
	match shape:
		&"line":
			hit_any = _cast_line(p, origin, dir, range_size, ctx)
		&"burst":
			hit_any = _cast_radius(p, origin, range_size, ctx, Vector3.ZERO)
			# 「钢之洪流」自身霸体（策划案 §7.1）
			var armor: float = cfg.skill_q_self_armor
			if armor > 0.0:
				p.super_armor_left = armor
		&"cone":
			hit_any = _cast_radius(p, origin, range_size, ctx, dir)
			# 「苍炎葬列」点燃地面
			GroundField.spawn(p.get_parent(), origin, range_size * 0.8,
				cfg.skill_q_field_duration * eq.get("effect_duration_mult", 1.0),
				cfg.element, p, p.runtime.atk(), 0.6, ctx.aura_gu * 0.5)
		&"toss_field":
			hit_any = _cast_toss_field(p, origin, dir, range_size, ctx, cfg, eq, is_e)
		&"heal_ring":
			hit_any = _cast_heal_ring(p, origin, range_size, ctx, cfg)
		&"freeze_burst":
			hit_any = _cast_freeze_burst(p, origin, range_size, ctx, cfg, eq)
		_:
			push_warning("Skills: 未知技能形态 %s" % shape)

	# 元素色炼成阵占位特效
	TransmuteRing.spawn(p.get_parent(), origin, maxf(2.0, range_size * 0.7), Elements.color(cfg.element))
	# 策划案 §9.1：炼成技命中 +8 能量
	if hit_any:
		p.runtime.gain_energy(8.0)
	p.runtime.notify_combat()

## 直线（艾登 E「钢之涟漪」）：沿线球体步进查询，去重命中
static func _cast_line(p: PlayerCharacter, origin: Vector3, dir: Vector3, length: float, ctx: DamageContext) -> bool:
	var hit_any := false
	var seen: Array = []
	var steps := int(ceil(length))
	for i in steps:
		var point := origin + dir * (1.2 + float(i) * 1.0) + Vector3.UP * 0.8
		for target in Combat.melee_query(p, point, 0.9, 4):
			if target in seen:
				continue
			seen.append(target)
			var result := Combat.resolve_attack(target, ctx)
			hit_any = hit_any or not result.is_empty()
	return hit_any

## 环绕 / 扇形（cone 时用 dir 过滤 ±45°）
static func _cast_radius(p: PlayerCharacter, origin: Vector3, radius: float, ctx: DamageContext, cone_dir: Vector3) -> bool:
	var hit_any := false
	var center := origin + Vector3.UP * 0.8
	for target in Combat.melee_query(p, center, radius, 4):
		if not cone_dir.is_zero_approx():
			var to_target: Vector3 = target.global_position - origin
			to_target.y = 0.0
			if to_target.length_squared() < 0.01:
				continue
			if to_target.normalized().dot(cone_dir) < 0.707: # 90° 扇形（±45°）
				continue
		var result := Combat.resolve_attack(target, ctx)
		hit_any = hit_any or not result.is_empty()
	return hit_any

## 投掷火域（莉赛尔 E「灼痕印记」）：落点瞬伤 + 留场火域
static func _cast_toss_field(p: PlayerCharacter, origin: Vector3, dir: Vector3,
		range_size: float, ctx: DamageContext, cfg: CharacterConfig, eq: Dictionary, is_e: bool) -> bool:
	var duration_base: float = cfg.skill_e_field_duration if is_e else cfg.skill_q_field_duration
	var field_duration: float = duration_base * eq.get("effect_duration_mult", 1.0)
	var landing := origin + dir * clampf(range_size * 0.6, 3.0, 6.0)
	GroundField.spawn(p.get_parent(), landing, range_size * 0.45, field_duration,
		cfg.element, p, p.runtime.atk(), 0.6, ctx.aura_gu * 0.5)
	# 落点瞬伤（复用 burst 查询）
	return _cast_radius(p, landing, range_size * 0.45, ctx, Vector3.ZERO)

## 环形治疗（卡文 E「涌泉之环」）：范围水附着 + 全队按最大HP比例回复
static func _cast_heal_ring(p: PlayerCharacter, origin: Vector3, radius: float,
		ctx: DamageContext, cfg: CharacterConfig) -> bool:
	var hit_any := _cast_radius(p, origin, radius, ctx, Vector3.ZERO)
	# 治疗全队（治疗量随元素精通：白模 = 比例 × (1 + EM/400)，策划案 §7.3）
	var heal := cfg.base_hp * cfg.skill_e_heal_ratio * (1.0 + cfg.element_mastery / 400.0)
	var party := p.get_party()
	if party != null:
		for member in party.members:
			if is_instance_valid(member) and not (member as PlayerCharacter).health.is_dead():
				(member as PlayerCharacter).health.heal(heal)
				EventBus.damage_number_requested.emit(
					(member as PlayerCharacter).global_position + Vector3(0, 2.0, 0), heal, Color(0.4, 1.0, 0.6), false)
	else:
		p.health.heal(heal)
	return hit_any

## 冻结爆发（卡文 Q「深渊之拥」）：大范围水附着 + 冻结 2s
static func _cast_freeze_burst(p: PlayerCharacter, origin: Vector3, radius: float,
		ctx: DamageContext, cfg: CharacterConfig, eq: Dictionary) -> bool:
	var hit_any := false
	var freeze: float = cfg.skill_q_freeze * float(eq.get("effect_duration_mult", 1.0))
	for target in Combat.melee_query(p, origin + Vector3.UP * 0.8, radius, 4):
		var result := Combat.resolve_attack(target, ctx)
		hit_any = hit_any or not result.is_empty()
		if target.has_method("status_holder"):
			var status: StatusHolder = target.call("status_holder")
			if status != null:
				status.apply(&"frozen", 0.0, freeze)
	return hit_any
