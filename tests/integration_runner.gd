extends Node
## P0 端到端集成测试：headless 模拟真实输入驱动整条战斗链路。
## 运行：Godot_console.exe --headless --path <项目根> res://tests/integration_runner.tscn
## 验证：移动位移 / 三段攻击命中假人 / 敌人追击并攻击玩家。退出码 0 = 通过。

const PLAYER_SCENE := preload("res://scenes/characters/player/player_character.tscn")
const DUMMY_SCENE := preload("res://scenes/common/training_dummy.tscn")
const ENEMY_SCENE := preload("res://scenes/characters/enemies/enemy_miner.tscn")

var _passed := 0
var _failed := 0
var _hits := 0

func _ready() -> void:
	EventBus.hit_landed.connect(_on_hit_landed)
	await _run()
	print("=== 集成结果：%d/%d 通过 ===" % [_passed, _passed + _failed])
	get_tree().quit(1 if _failed > 0 else 0)

func check(cond: bool, case_name: String) -> void:
	if cond:
		_passed += 1
		print("  ok  " + case_name)
	else:
		_failed += 1
		printerr("  FAIL: " + case_name)

func _on_hit_landed(_target: Node, _result: Dictionary) -> void:
	_hits += 1

func approx(a: float, b: float, eps: float = 0.05) -> bool:
	return absf(a - b) <= eps

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run() -> void:
	# —— 布景：地板 + 玩家在原点，假人在 +Z 2m（玩家初始朝向 +Z），敌人初始远离 —— #
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(80, 1, 80)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)

	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.1, 0)

	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	add_child(dummy)
	dummy.global_position = Vector3(0, 0, 2)

	await _frames(10) # 等待 _ready / 首帧物理

	# —— 1. 三段连击命中假人（按键节奏落在连段窗口内：active 后 ~0.4s 再按）—— #
	var hp_before := dummy.health.hp
	for combo in 3:
		Input.action_press("attack")
		await _frames(3)
		Input.action_release("attack")
		await _frames(22) # 25 帧节奏 < combo 时长，保证排队下一段
	await _frames(8) # 等第三段判定帧（combo3 active = +0.22s）
	check(_hits >= 3, "三段连击命中假人（hit_landed %d 次）" % _hits)
	var lost := hp_before - dummy.health.hp
	check(lost > 42.0, "完整连击掉血超过三段基准 44.5 的大部分（掉血 %.1f）" % lost)
	check(dummy.aura.gu(Elements.METAL) > 0.5, "第三段附 1GU 金附着（GU=%.2f）" % dummy.aura.gu(Elements.METAL))

	# —— 1b. 元素反应流经 Combat 全管线（附着→白雾增幅→ICD→熔金剧变+破甲）—— #
	var rd_dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	add_child(rd_dummy)
	rd_dummy.global_position = Vector3(12, 0, 12)

	var fire_ctx := DamageContext.make(player, 1, 100.0, 1.0)
	fire_ctx.crit_rate = 0.0
	fire_ctx.with_element(Elements.FIRE, 2.0)
	var r1 := Combat.resolve_attack(rd_dummy, fire_ctx)
	check(not r1.is_empty() and r1.get("reaction", &"") == &"", "首击纯附着无反应")
	check(rd_dummy.aura.has_aura(Elements.FIRE), "火附着 2GU 挂上目标")

	var mist_ctx := DamageContext.make(player, 1, 100.0, 1.0)
	mist_ctx.crit_rate = 0.0
	mist_ctx.with_element(Elements.WATER, 1.0)
	var r2 := Combat.resolve_attack(rd_dummy, mist_ctx)
	check(r2.get("reaction", &"") == &"white_mist", "水后手触发白雾弥漫")
	check(approx(float(r2.get("damage", 0.0)), 125.0, 0.5),
		"白雾增幅伤害 = 100×1.25 = 125（实际 %.1f）" % float(r2.get("damage", 0.0)))
	check(approx(rd_dummy.status.get_speed_mult(), 0.7), "白雾减速 30% 生效于目标")

	var icd_ctx := DamageContext.make(player, 1, 100.0, 1.0)
	icd_ctx.crit_rate = 0.0
	icd_ctx.with_element(Elements.FIRE, 1.0)
	var r3 := Combat.resolve_attack(rd_dummy, icd_ctx)
	check(r3.get("reaction", &"") == &"", "ICD 内重复反应被拦截")

	var molten_ctx := DamageContext.make(player, 1, 100.0, 1.0)
	molten_ctx.crit_rate = 0.0
	molten_ctx.with_element(Elements.METAL, 1.0)
	var r4 := Combat.resolve_attack(rd_dummy, molten_ctx)
	check(r4.get("reaction", &"") == &"molten_gold", "金后手触发熔金")
	check(approx(float(r4.get("damage", 0.0)), 148.0, 0.5),
		"熔金伤害 = 物理100 + 剧变(20+4×1)×2.0 = 148（实际 %.1f）" % float(r4.get("damage", 0.0)))
	check(approx(rd_dummy.status.get_def_mult(), 0.75), "熔金破甲 25% 生效于目标")
	rd_dummy.queue_free()

	# —— 2. 移动：按住 W 应产生位移（相机初始朝向 -Z 为前）—— #
	await _frames(35) # 等连击后摇完全结束（攻击态按设计锁移动）
	var pos_before := player.global_position
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	var moved := (player.global_position - pos_before).length()
	check(moved > 1.5, "按 W 移动 40 帧，位移 %.2f m" % moved)

	# —— 3. 敌人追击并攻击玩家 —— #
	var enemy: EnemyBase = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = player.global_position + Vector3(0, 0, -7)
	var player_hp_before := player.health.hp
	var enemy_dist_before := enemy.global_position.distance_to(player.global_position)
	# 给足追击 + 前摇 + 攻击 + 冷却再攻击的时间
	for i in 8:
		await _frames(30)
	var enemy_dist_now := enemy.global_position.distance_to(player.global_position)
	check(enemy_dist_now < enemy_dist_before - 2.0, "敌人追击逼近（%.1fm → %.1fm）" % [enemy_dist_before, enemy_dist_now])
	check(player.health.hp < player_hp_before, "敌人攻击命中玩家（HP %.0f → %.0f）" % [player_hp_before, player.health.hp])
	check(enemy.state == EnemyBase.State.CHASE or enemy.state == EnemyBase.State.WINDUP \
		or enemy.state == EnemyBase.State.RECOVER or enemy.state == EnemyBase.State.STAGGER,
		"敌人处于活跃 AI 状态（state=%d）" % enemy.state)

	# 击杀事件恰好一次（直接伤害路径——审核 2026-09-10 #2）。
	# 用实例 id 收集：同一信号上的多次死亡互不串扰、每敌一次。
	var died_ids: Array = []
	EventBus.enemy_died.connect(func(e: Node) -> void: died_ids.append(e.get_instance_id()))
	var enemy1_id := enemy.get_instance_id()
	enemy.health.take_damage(999999.0)
	await _frames(5)
	check(died_ids == [enemy1_id], "直接击杀触发 enemy_died 恰好一次")

	# DoT 击杀路径（锈蚀类）：同样恰好一次、事件只发一份
	var enemy2: EnemyBase = ENEMY_SCENE.instantiate()
	add_child(enemy2)
	enemy2.global_position = player.global_position + Vector3(0, 0, -18) # 仇恨圈外，不干扰玩家
	var enemy2_id := enemy2.get_instance_id()
	enemy2.status.apply_dot(400.0, 1.0) # 33 HP 敌人，首跳必死
	await _frames(90) # > 1s：等 DoT 跳与死亡
	check(died_ids == [enemy1_id, enemy2_id],
		"DoT 击杀恰好一次且两敌人事件互不串扰（实际 %d 个事件）" % died_ids.size())

	# —— 5. hitstop：恢复到进入前的缩放，不覆盖调试面板设置（审核 2026-09-10 #6）—— #
	Engine.time_scale = 2.0
	GameManager.hitstop(0.08, 0.1)
	check(approx(Engine.time_scale, 0.1, 0.001), "hitstop 期间时间缩放被压低")
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(approx(Engine.time_scale, 2.0, 0.001), "hitstop 结束恢复进入前缩放（2.0）")
	Engine.time_scale = 1.0

	# —— 6. P1 队伍 / 等价交换 / 技能 —— #
	var pm := PartyManager.new()
	add_child(pm)
	pm.setup(Vector3(30, 0.5, 30), [
		DataManager.config("char_aiden"),
		DataManager.config("char_lisea"),
		DataManager.config("char_kaven"),
	])
	await _frames(5)
	check(pm.members.size() == 3 and pm.active_index == 0, "队伍 3 人常驻，初始艾登")
	check((pm.members[1] as PlayerCharacter).collision_layer == 0
		and not (pm.members[1] as PlayerCharacter).visible, "非激活角色关碰撞且隐藏（技术方案 §3.2/R9）")

	pm._request_switch(1)
	await _frames(3)
	check(pm.active_index == 1, "切换到莉赛尔")
	check((pm.members[0] as PlayerCharacter).collision_layer == 0, "旧角色碰撞已关闭")
	pm._request_switch(2) # 1s 公共冷却内，应被拒绝
	await _frames(2)
	check(pm.active_index == 1, "公共冷却内切换被拒绝")
	pm.members[1].health.take_damage(pm.members[1].health.hp * 0.5) # 掉一半血
	await get_tree().create_timer(1.1, true).timeout
	pm._request_switch(0)
	await get_tree().create_timer(1.1, true).timeout
	pm._request_switch(1)
	await _frames(3)
	check(approx(pm.members[1].health.hp, pm.members[1].runtime.hp, 1.0)
		and pm.members[1].health.hp < pm.members[1].health.max_hp * 0.6,
		"切换往返后资源不重置（半血仍是半血）")

	# 等价交换：血之炼成保底 1 HP（策划案 §6.3 第 2 条）
	var aiden := pm.members[0] as PlayerCharacter
	aiden.health.hp = 1.1
	aiden.runtime.hp = 1.1
	aiden.try_activate_equivalence()
	var eq := aiden.take_equivalence_params()
	check(approx(aiden.health.hp, 1.0, 0.01) and not aiden.health.is_dead()
		and eq.get("damage_mult", 0.0) == 1.5 and eq.get("lifesteal", 0.0) == 0.1,
		"血之炼成：15%% 当前HP 且保底 1 HP 不死（hp=%.2f dmg=%.2f ls=%.2f active=%s）"
			% [aiden.health.hp, eq.get("damage_mult", 0.0), eq.get("lifesteal", 0.0), aiden.equivalence_active])
	# 智之炼成：40% 当前 MP
	var lisea := pm.members[1] as PlayerCharacter
	lisea.runtime.mp = 50.0
	lisea.try_activate_equivalence()
	var eq2 := lisea.take_equivalence_params()
	check(approx(lisea.runtime.mp, 30.0, 0.01) and eq2.get("area_mult", 0.0) == 1.5
		and eq2.get("cooldown_mult", 0.0) == 0.7,
		"智之炼成：消耗 40%% 当前 MP（mp=%.2f area=%.2f cd=%.2f active=%s）"
			% [lisea.runtime.mp, eq2.get("area_mult", 0.0), eq2.get("cooldown_mult", 0.0), lisea.equivalence_active])
	# 质之炼成：3 炼金尘 → 效果持续 ×2；不足时激活失败
	pm.inventory.add_dust(5)
	var kaven := pm.members[2] as PlayerCharacter
	kaven.try_activate_equivalence()
	var eq3 := kaven.take_equivalence_params()
	check(pm.inventory.dust == 2 and eq3.get("effect_duration_mult", 0.0) == 2.0,
		"质之炼成：消耗 3 炼金尘（dust=%d eff=%.2f）" % [pm.inventory.dust, eq3.get("effect_duration_mult", 0.0)])
	var failed := [false]
	EventBus.equivalence_failed.connect(func(_el: StringName) -> void: failed[0] = true)
	kaven.try_activate_equivalence()
	check(not kaven.equivalence_active and failed[0], "炼金尘不足时 R 激活失败并有提示事件")

	# 技能烟测：切回艾登 → E 直线命中 + 能量奖励；Q 消耗 100 能量 + 自身霸体
	await get_tree().create_timer(1.1, true).timeout
	pm._request_switch(0)
	await _frames(3)
	check(pm.active_index == 0 and pm.members[0].stats.element == Elements.METAL,
		"切回艾登且角色配置正确（金元素）")
	check((pm.members[1] as PlayerCharacter).stats.element == Elements.FIRE,
		"莉赛尔配置正确（火元素）")
	check((pm.members[2] as PlayerCharacter).stats.element == Elements.WATER,
		"卡文配置正确（水元素）")
	var skill_dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	add_child(skill_dummy)
	skill_dummy.global_position = aiden.global_position + aiden.face_dir * 3.0
	var dummy_hp_before := skill_dummy.health.hp
	aiden.runtime.energy = 0.0 # 清零，隔离此前切换入场的 +10，专测技能奖励
	# 像真实玩家一样经物理帧按键驱动（intersect_shape 只在物理步上下文可靠）
	Input.action_press("skill_e")
	await _frames(3)
	Input.action_release("skill_e")
	await _frames(2)
	check(skill_dummy.health.hp < dummy_hp_before,
		"艾登 E「钢之涟漪」直线命中（%.0f → %.0f）" % [dummy_hp_before, skill_dummy.health.hp])
	check(approx(aiden.runtime.energy, 8.0, 0.01),
		"炼成技命中 +8 能量（实际 %.1f）" % aiden.runtime.energy)
	aiden.runtime.gain_energy(100.0)
	Input.action_press("burst_q")
	await _frames(3)
	Input.action_release("burst_q")
	await _frames(2)
	check(approx(aiden.runtime.energy, 8.0, 0.01), "Q 消耗 100 能量（8 = E 奖励余量）")
	check(aiden.super_armor_left > 4.8, "钢之洪流自身霸体 5s（%.2f，含帧衰减）" % aiden.super_armor_left)
	skill_dummy.queue_free()

	# 精英霸体：破霸 → 5s 易伤
	var overseer := (load("res://scenes/characters/enemies/enemy_overseer.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(overseer)
	overseer.global_position = Vector3(40, 0.5, 30)
	check(overseer.poise != null and not overseer.poise.is_broken(), "精英持有霸体条")
	overseer.damage_poise(200.0)
	check(overseer.poise.is_broken() and approx(overseer.get_damage_taken_mult(), 1.3, 0.001),
		"破霸后 5s 易伤（承伤 ×1.3）")
	overseer.queue_free()

	# —— 7. 竞技场敌人补刷（玩测反馈 2026-09-10：打死不刷新）—— #
	# 注意：此节会加入整套竞技场（7 个补刷槽 + 1 精英），必须放在最后。
	var arena := (load("res://scenes/world/p0_arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _frames(5)
	var initial_enemies := get_tree().get_nodes_in_group("enemies").size()
	check(initial_enemies == 8, "竞技场初始敌人 8 个（7 可刷槽 + 精英，实际 %d）" % initial_enemies)
	var arena_enemy := get_tree().get_first_node_in_group("enemies") as EnemyBase
	check(arena_enemy != null and absf(arena_enemy.health.max_hp - 264.0) <= 0.5,
		"沙盒矿工血量 = 33×8 = 264（实际 %.0f）" % (arena_enemy.health.max_hp if arena_enemy != null else 0.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is EnemyBase:
			(e as EnemyBase).health.invincible = false
			(e as EnemyBase).health.take_damage(999999.0)
	await get_tree().create_timer(1.2, true).timeout # 等死亡下沉与 queue_free
	var cleared := get_tree().get_nodes_in_group("enemies").size()
	check(cleared == 0, "击杀后全场清空（实际 %d）" % cleared)
	await get_tree().create_timer(6.0, true).timeout # > ENEMY_RESPAWN_SEC(6.0)
	var respawned := get_tree().get_nodes_in_group("enemies").size()
	check(respawned == 7, "补刷窗口后 7 个槽位回满（精英不补刷，实际 %d）" % respawned)

	Input.action_release("attack")
	Input.action_release("move_forward")
