class_name Combat
## 战斗结算核心（技术方案 4.1 - 4.3）。
## 近战瞬时判定用 PhysicsDirectSpaceState3D.intersect_shape（判定帧同步查询，无信号时序问题）；
## Area3D 只用于持续型判定（火域、光环，P1 接入）。

## 球形近战判定：返回去重后的 collider 列表（已排除攻击者自身）
static func melee_query(attacker: CollisionObject3D, origin: Vector3,
		radius: float, mask: int, max_results: int = 16) -> Array:
	var space := attacker.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [attacker.get_rid()]
	var hits: Array = []
	for result in space.intersect_shape(params, max_results):
		var collider: Variant = result.get("collider")
		if collider != null and not hits.has(collider):
			hits.append(collider)
	return hits

## 攻击结算主入口。目标需实现：
##   get_health() 必需；get_defense() / get_resistance(el) 缺省视为 0；
##   get_aura() / status_holder() / apply_hit_reaction(result, ctx) 可选。
## 返回 { "damage", "crit", "reaction", "killed" }；目标无效时返回空字典。
static func resolve_attack(target: Object, ctx: DamageContext) -> Dictionary:
	if target == null or not target.has_method("get_health"):
		return {}
	var health: HealthComponent = target.call("get_health")
	if health == null or health.invincible or health.is_dead():
		return {}

	# —— 元素附着与反应（策划案 5.3 / 技术方案 4.2）—— #
	var amplify_mult := 1.0
	var fixed_damage := 0.0
	var reaction: ReactionDefinition = null
	if target.has_method("get_aura"):
		var aura: ElementAura = target.call("get_aura")
		if aura != null and ctx.element != &"" and ctx.aura_gu > 0.0:
			reaction = aura.apply_incoming(ctx.element, ctx.aura_gu)
	if reaction != null:
		match reaction.reaction_type:
			ReactionDefinition.ReactionType.AMPLIFY:
				amplify_mult = reaction.damage_mult
			ReactionDefinition.ReactionType.TRANSFORM:
				fixed_damage = DamageFormulas.transformative_damage(
					ctx.attacker_level, reaction.damage_mult, ctx.element_mastery)

	# —— 伤害计算（策划案 9.2）—— #
	var defense := _target_defense(target)
	var resistance := 0.0
	if target.has_method("get_resistance"):
		resistance = float(target.call("get_resistance", ctx.element))
	var damage := DamageFormulas.hit_damage(
		ctx.atk, ctx.skill_mult, ctx.attacker_level, defense, resistance, amplify_mult)
	damage = damage * ctx.equivalence_mult + fixed_damage
	# 易伤乘区（破霸后 5s，策划案 §5.2）
	if target.has_method("get_damage_taken_mult"):
		damage *= float(target.call("get_damage_taken_mult"))
	var is_crit := randf() < ctx.crit_rate
	if is_crit:
		damage *= 1.0 + ctx.crit_damage
	damage = maxf(1.0, damage)

	health.take_damage(damage)
	# 吸血（血之炼成，策划案 §6.2：伤害 ×10% 回复施法者）
	if ctx.lifesteal > 0.0 and ctx.attacker != null and ctx.attacker.has_method("get_health"):
		var attacker_health: HealthComponent = ctx.attacker.call("get_health")
		if attacker_health != null:
			attacker_health.heal(damage * ctx.lifesteal)
	# 削霸（策划案 §5.2：重击与爆发技可击退；精英/BOSS 霸体条）
	if ctx.poise_damage > 0.0 and target.has_method("damage_poise"):
		target.call("damage_poise", ctx.poise_damage)

	# —— 反应附加效果（策划案 §9.4；质之炼成效果时长 ×2 经 ctx.effect_duration_mult）—— #
	if reaction != null and target.has_method("break_shell"):
		# 熔金破壳（策划案 §9.2 BOSS 行：熔金反应可直接削除护壳）
		target.call("break_shell")
	if reaction != null and reaction.effect_id != &"" and target.has_method("status_holder"):
		var status: StatusHolder = target.call("status_holder")
		if status != null:
			var effect_duration: float = reaction.effect_duration * ctx.effect_duration_mult
			match reaction.effect_id:
				&"slow":
					status.apply(&"slow", reaction.effect_value, effect_duration)
				&"armor_break":
					status.apply(&"armor_break", reaction.effect_value, effect_duration)
				&"stagger_up":
					status.apply(&"stagger_up", reaction.effect_value, effect_duration)
					# 淬火脆化双效果：硬直积累+50% 的同时霸体恢复暂停（策划案 §9.4）
					status.apply(&"poise_pause", 0.0, effect_duration)
				&"poise_pause":
					status.apply(&"poise_pause", reaction.effect_value, effect_duration)
				&"dot":
					# 锈蚀：剧变基础伤害 × effect_value / 秒，持续 effect_duration 秒
					var base := DamageFormulas.transformative_damage(
						ctx.attacker_level, 1.0, ctx.element_mastery)
					status.apply_dot(base * reaction.effect_value, effect_duration)

	# —— 表现层（伤害数字 / 事件广播 / 受击反馈钩子）—— #
	var color := Color.WHITE if ctx.element == &"" else Elements.color(ctx.element)
	if reaction != null:
		color = Color(0.85, 0.55, 1.0) # 反应触发统一紫色调，便于辨识
	var pos := Vector3.ZERO
	if target is Node3D:
		pos = (target as Node3D).global_position \
			+ Vector3(randf_range(-0.3, 0.3), 1.7, randf_range(-0.3, 0.3))
	EventBus.damage_number_requested.emit(pos, damage, color, is_crit)

	var result := {
		"damage": damage,
		"crit": is_crit,
		"reaction": reaction.id if reaction != null else &"",
		"killed": health.is_dead(),
	}
	if target.has_method("apply_hit_reaction"):
		target.call("apply_hit_reaction", result, ctx)
	EventBus.hit_landed.emit(target, result)
	if target is Node and (target as Node).is_in_group("enemies"):
		EventBus.enemy_damaged.emit(target, damage, is_crit)
	return result

static func _target_defense(target: Object) -> float:
	var defense := 0.0
	if target.has_method("get_defense"):
		defense = float(target.call("get_defense"))
	if target.has_method("status_holder"):
		var status: StatusHolder = target.call("status_holder")
		if status != null:
			defense *= status.get_def_mult()
	return defense
