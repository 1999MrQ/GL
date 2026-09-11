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
	# 释放队伍：后续 BOSS/攀爬节用独立玩家，且敌人索敌只认激活组（player_active）——
	# 队伍在场会把 BOSS 仇恨引到远处的后台站位上（第四轮审查 S1）
	pm.queue_free()
	await _frames(3)

	# —— 6b. P2：攀爬 / 滑翔 / 交互 / 谜题 / BOSS 三阶段 —— #
	var p2_pos: Vector3 = player.global_position

	# 攀爬：垂直墙立在玩家前方（W 前进方向为 -Z），推向墙面应自动扒墙并上移
	var climb_wall := StaticBody3D.new()
	climb_wall.collision_layer = 1
	var wall_col := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(6, 12, 1)
	wall_col.shape = wall_box
	climb_wall.add_child(wall_col)
	climb_wall.global_position = p2_pos + Vector3(0, 6, -1.3)
	add_child(climb_wall)
	await _frames(2)
	Input.action_press("move_forward")
	await _frames(10)
	check(player.fsm.current_id == &"climb", "推向 ≥65° 陡面进入攀爬（state=%s）" % player.fsm.current_id)
	var y_on_wall := player.global_position.y
	await _frames(30)
	check(player.global_position.y > y_on_wall + 0.8,
		"攀爬沿墙上移（%.2f → %.2f）" % [y_on_wall, player.global_position.y])
	Input.action_release("move_forward")

	# 滑翔：空中再按跳跃 → 垂直速度钳制 -3 m/s，体力 8/s
	player.global_position = Vector3(p2_pos.x, 12.0, p2_pos.z)
	await _frames(5) # 进入下落
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(60) # 1s：未滑翔时已坠超 -20 m/s
	check(player.vertical_velocity >= -3.5, "滑翔钳制下坠速度（vv=%.2f）" % player.vertical_velocity)
	check(player.stamina.stamina < 100.0, "滑翔消耗体力 8/s")
	player.global_position = Vector3(p2_pos.x, 0.5, p2_pos.z)
	await _frames(20)

	# 采集：F 采集铁矿入包（策划案 §8.1）
	var gather := (load("res://scenes/world/gather_node.tscn") as PackedScene).instantiate()
	add_child(gather)
	gather.global_position = player.global_position + Vector3(0, 0, 1.5)
	var iron_before := player.inventory.iron
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)
	check(player.inventory.iron == iron_before + 2, "F 采集铁矿 ×2 入包")

	# 宝箱：F 开启得炼金尘
	var chest := (load("res://scenes/world/chest.tscn") as PackedScene).instantiate()
	add_child(chest)
	chest.global_position = player.global_position + Vector3(0, 0, 1.5)
	var dust_before := player.inventory.dust
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)
	check(player.inventory.dust > dust_before, "F 开启宝箱得炼金尘")

	# 传送阵：解锁 A/B，激活 A 传送到 B（策划案 §8.1 传送炼成阵 ×3 的最小形态）
	var gate_a := (load("res://scenes/world/teleport_gate.tscn") as PackedScene).instantiate()
	var gate_b := (load("res://scenes/world/teleport_gate.tscn") as PackedScene).instantiate()
	gate_a.gate_id = &"t_a"
	gate_b.gate_id = &"t_b"
	add_child(gate_a)
	add_child(gate_b)
	gate_a.global_position = player.global_position + Vector3(0, 0, 1.5)
	gate_b.global_position = player.global_position + Vector3(0, 0, -8)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)
	check(gate_a.is_unlocked(), "F 激活传送阵 A")
	gate_b.interact(player) # 直接解锁 B
	check(gate_b.is_unlocked(), "传送阵 B 解锁")
	var b_pos: Vector3 = gate_b.global_position
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)
	check(player.global_position.distance_to(b_pos) < 2.5, "激活 A 传送到已解锁的 B")

	# 谜题原型：火元素点亮 3 座炼成灯 → 密门开启（策划案 §8.1）
	var lamps: Array = []
	for offset: Vector3 in [Vector3(2, 0, 0), Vector3(-2, 0, 2), Vector3(0, 0, -2)]:
		var lamp := (load("res://scenes/world/puzzle_lamp.tscn") as PackedScene).instantiate()
		add_child(lamp)
		lamp.global_position = player.global_position + offset
		lamps.append(lamp)
	var door := (load("res://scenes/world/puzzle_door.tscn") as PackedScene).instantiate()
	add_child(door)
	door.global_position = player.global_position + Vector3(0, 1.5, 5)
	door.register_lamps(lamps)
	for lamp in lamps:
		var lamp_fire := DamageContext.make(player, 1, 10.0, 1.0)
		lamp_fire.crit_rate = 0.0
		lamp_fire.with_element(Elements.FIRE, 1.0)
		Combat.resolve_attack(lamp, lamp_fire)
	await _frames(5)
	check(door._open, "3 座炼成灯全部点亮后密门开启")

	# BOSS 蚀核巨像：三阶段 / 护壳熔金削除 / 灼热地板与蒸汽安全区（策划案 §5.4/§9.2）
	var boss := (load("res://scenes/characters/enemies/boss_colossus.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(boss)
	boss.global_position = player.global_position + Vector3(6, 0.5, -6)
	await _frames(10)
	check(boss.phase == 1 and boss.poise != null, "BOSS 一阶段（霸体条就绪）")
	boss.health.take_damage(boss.health.max_hp * 0.35)
	await _frames(3)
	check(boss.phase == 2 and boss.shell_active, "70% 进入二阶段并展开金属护壳")
	check(approx(boss.get_resistance(Elements.METAL), 0.8, 0.001), "护壳金抗 +80%")
	# 火直打护壳 = 金先火后 → 淬火脆化，不削壳（策划案 §9.2：仅熔金削壳——
	# 火单独可破壳会架空"火先金后"的双角色配合设计；第四轮审查 S2）
	var boss_fire := DamageContext.make(player, 1, 10.0, 1.0)
	boss_fire.crit_rate = 0.0
	boss_fire.with_element(Elements.FIRE, 2.0)
	var r_quench: Dictionary = Combat.resolve_attack(boss, boss_fire)
	check(boss.shell_active and r_quench.get("reaction", &"") == &"quench_brittle",
		"火直打护壳触发淬火而非熔金，护壳不削（策划案 §9.2）")
	await get_tree().create_timer(2.7, true).timeout # 过 2.5s ICD（淬火对火/金双向设 ICD）
	boss.aura.set_aura(Elements.FIRE, 2.0) # 模拟无壳窗口期莉赛尔已挂的火先手
	var boss_metal := DamageContext.make(player, 1, 10.0, 1.0)
	boss_metal.crit_rate = 0.0
	boss_metal.with_element(Elements.METAL, 2.0)
	var r_molten: Dictionary = Combat.resolve_attack(boss, boss_metal)
	check(not boss.shell_active and r_molten.get("reaction", &"") == &"molten_gold",
		"火先金后触发熔金 → 护壳削除（策划案 §5.4：必须火+金）")
	boss.health.take_damage(boss.health.max_hp * 0.5) # → 约 15%
	boss._update_phase() # 直接推进阶段判定（破壳后本有 3s 硬直输出窗口，测试不等其自然结束）
	await _frames(3)
	check(boss.phase == 3 and is_instance_valid(boss._heat), "30% 进入三阶段并生成灼热地板")
	boss.global_position = Vector3(60, 0.5, -60) # 撤走 BOSS，避免攻击干扰灼烧计量
	var hp0 := player.health.hp
	await _frames(40)
	check(player.health.hp < hp0, "灼热地板持续灼烧（%.0f → %.0f）" % [hp0, player.health.hp])
	SteamZone.spawn(self, player.global_position, 3.0, 6.0)
	var hp1 := player.health.hp
	await _frames(45)
	check(approx(player.health.hp, hp1, 0.01), "蒸汽安全区内免疫灼烧（%.0f → %.0f）" % [hp1, player.health.hp])
	if is_instance_valid(boss._heat):
		boss._heat.queue_free()
	boss.queue_free()

	# —— 6c. P2 第二轮：蚀晶壁 / 锈蚀锁链门 / 观景点 / 存档流 —— #
	# 蚀晶壁（策划案 §8.2）：徒手不可攀；金元素技能命中生成抓握点后可攀
	player.global_position = Vector3(p2_pos.x + 15.0, 0.5, p2_pos.z + 15.0)
	player.face_dir = Vector3.FORWARD
	player.horizontal_velocity = Vector3.ZERO
	await _frames(3)
	var erosion := (load("res://scenes/world/erosion_wall.tscn") as PackedScene).instantiate()
	add_child(erosion)
	erosion.global_position = player.global_position + Vector3(0, 5.0, -1.3)
	await _frames(2)
	Input.action_press("move_forward")
	await _frames(10)
	Input.action_release("move_forward")
	check(player.fsm.current_id != &"climb", "蚀晶壁徒手不可攀（无抓握点时拒绝进入攀爬）")
	Input.action_press("skill_e") # 独立玩家默认艾登（金）→ 生成抓握点
	await _frames(3)
	Input.action_release("skill_e")
	await _frames(2)
	check(get_tree().get_nodes_in_group("climb_holds").size() >= 3,
		"金元素技能命中蚀晶壁生成抓握点（≥3 个）")
	Input.action_press("move_forward")
	await _frames(10)
	Input.action_release("move_forward")
	check(player.fsm.current_id == &"climb", "踩上抓握点进入攀爬（炼金术×探索）")
	Input.action_press("jump") # 跳离墙面，释放玩家
	await _frames(3)
	Input.action_release("jump")
	await _frames(5)

	# 锈蚀锁链门（谜题 3/3）：需先水后金触发锈蚀反应开启（策划案 §5.3 组合顺序）
	var rust_door := (load("res://scenes/world/puzzle_rust_door.tscn") as PackedScene).instantiate()
	add_child(rust_door)
	rust_door.global_position = player.global_position + Vector3(0, 1.5, -4.0)
	await _frames(2)
	var chain_water := DamageContext.make(player, 1, 10.0, 1.0)
	chain_water.crit_rate = 0.0
	chain_water.with_element(Elements.WATER, 2.0)
	Combat.resolve_attack(rust_door, chain_water)
	check(not rust_door.is_open(), "仅水附着未触发锈蚀，门保持关闭")
	var chain_metal := DamageContext.make(player, 1, 10.0, 1.0)
	chain_metal.crit_rate = 0.0
	chain_metal.with_element(Elements.METAL, 2.0)
	var r_rust: Dictionary = Combat.resolve_attack(rust_door, chain_metal)
	check(r_rust.get("reaction", &"") == &"rust" and rust_door.is_open(),
		"金后手触发锈蚀 → 锁链蚀断门开（先水后金）")
	rust_door.queue_free()

	# 观景点（策划案 §8.1 ×2）：一次性观赏
	var vista := (load("res://scenes/world/vista_point.tscn") as PackedScene).instantiate()
	add_child(vista)
	vista.global_position = player.global_position + Vector3(0, 0, 1.2)
	await _frames(2)
	vista.interact(player)
	check(vista.is_visited(), "F 观赏观景点（一次性）")

	# 存档流（F5/F9 背后逻辑 GameSaveFlow）：野外采集读档刷新 / 洞窟一次性不刷新 / 队伍往返
	var pm2 := PartyManager.new()
	add_child(pm2)
	pm2.setup(Vector3(70, 0.5, 70), [
		DataManager.config("char_aiden"),
		DataManager.config("char_lisea"),
		DataManager.config("char_kaven"),
	])
	await _frames(3)
	var save_aiden := pm2.members[0] as PlayerCharacter
	save_aiden.health.take_damage(300.0)
	pm2.inventory.add_dust(7)
	var cave_gather := (load("res://scenes/world/gather_node.tscn") as PackedScene).instantiate()
	cave_gather.node_id = "gather_cave_test"
	cave_gather.one_shot = true
	add_child(cave_gather)
	cave_gather.global_position = Vector3(70, 0, 72)
	await _frames(2)
	cave_gather.interact(save_aiden) # 洞窟一次性：采集中即记录进注册表
	check(GameSaveFlow.save_game(get_tree()), "F5 存档写入成功（队伍/背包/世界三块）")
	# 篡改现场后读档：应恢复存档时状态
	save_aiden.health.heal(999.0)
	pm2.inventory.dust = 0
	var cave_rebuild := (load("res://scenes/world/gather_node.tscn") as PackedScene).instantiate()
	cave_rebuild.node_id = "gather_cave_test" # 模拟重新进入世界：同 ID 一次性节点重建
	cave_rebuild.one_shot = true
	add_child(cave_rebuild)
	var field_rebuild := (load("res://scenes/world/gather_node.tscn") as PackedScene).instantiate()
	field_rebuild.node_id = "gather_field_test" # 野外点：读档后应刷新（仍可采）
	add_child(field_rebuild)
	await _frames(2)
	check(GameSaveFlow.load_game(get_tree()), "F9 读档成功")
	await _frames(3)
	check(approx(save_aiden.runtime.hp, 800.0, 1.0) and pm2.inventory.dust == 7,
		"读档恢复队伍 HP 与背包（HP=%.0f dust=%d）" % [save_aiden.runtime.hp, pm2.inventory.dust])
	check(not is_instance_valid(cave_rebuild), "洞窟一次性采集读档后不刷新（策划案 §8.1）")
	check(is_instance_valid(field_rebuild) and not field_rebuild.taken(),
		"野外采集点读档后刷新（策划案 §8.1）")
	pm2.queue_free()
	if is_instance_valid(field_rebuild):
		field_rebuild.queue_free()

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
