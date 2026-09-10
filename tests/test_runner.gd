extends Node
## 自动化数值 / 规则用例（技术方案 10.2：改数值先跑测试再进游戏）。
## 场景式运行器：在正常游戏模式下运行（Autoload 齐备），headless 可跑：
##   Godot_console.exe --headless --path <项目根> res://tests/test_runner.tscn
## 退出码 0 = 全部通过；1 = 存在失败。

const DAMAGE_EPS := 0.05

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== GL 自动化用例：DamageFormulas / 元素反应 / 状态 / 配置与场景 ===")
	_test_damage_formulas_doc_examples()
	_test_growth_curves()
	_test_reaction_table_data()
	_test_element_aura_rules()
	_test_status_holder()
	_test_health_component()
	_test_stamina_component()
	_test_configs_and_scenes()
	_test_poise_component()
	_test_character_runtime()
	_test_party_inventory()
	_test_localization()
	_test_pool_manager()
	_test_save_manager_roundtrip()
	print("=== 结果：%d/%d 通过 ===" % [_passed, _passed + _failed])
	get_tree().quit(1 if _failed > 0 else 0)

# ---------------------------------------------------------------- helpers

func check(cond: bool, case_name: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL: " + case_name)

func approx(a: float, b: float, eps: float = DAMAGE_EPS) -> bool:
	return absf(a - b) <= eps

# ---------------------------------------------------------------- 用例

## 策划案 9.3 示例校验数值逐项复核（V2.1 修正后的锚点）
func _test_damage_formulas_doc_examples() -> void:
	print("-- DamageFormulas：策划案 9.2/9.3 锚点")
	# 1 级：ATK 22，普攻一段 60% 对 DEF 3 → ≈13（3 段击杀 33 HP 教学怪）
	check(approx(DamageFormulas.defense_reduction(3.0, 1), 3.0 / 213.0), "防御减免(1级) = 3/213")
	check(approx(DamageFormulas.hit_damage(22.0, 0.6, 1, 3.0, 0.0), 13.0), "1级普攻一段 ≈ 13")
	# 防御减免上限 70%（伤害乘数下限 0.30）
	check(approx(DamageFormulas.defense_reduction(10000.0, 1), 0.7, 0.0001), "防御减免上限 70%")
	check(approx(DamageFormulas.hit_damage(100.0, 1.0, 1, 10000.0, 0.0), 30.0), "上限减免时伤害乘数 = 0.30")
	# 25 级：ATK ≈ 43.12 / HP 2288 / 小怪 HP ≈ 646（文档 ≈650）
	check(approx(DamageFormulas.character_atk(22.0, 25), 43.12), "25级 ATK = 43.12")
	check(approx(DamageFormulas.character_max_hp(1100.0, 25), 2288.0), "25级 HP = 2288")
	check(approx(DamageFormulas.enemy_max_hp(25), 645.96, 0.5), "25级小怪 HP ≈ 646")
	check(approx(DamageFormulas.enemy_max_hp(1, 1.5), 33.0, 0.05), "1级教学怪 HP = 33")
	# 25 级一轮循环（文档：E≈81 / Q≈155 / 熔金≈240）
	var def25 := DamageFormulas.defense_reduction(75.0, 25)
	check(approx(def25, 0.142857, 0.001), "25级对 75 DEF 减免 ≈ 14.3%")
	check(approx(DamageFormulas.hit_damage(43.12, 2.2, 25, 75.0, 0.0), 81.3), "25级 E ≈ 81")
	check(approx(DamageFormulas.hit_damage(43.12, 4.2, 25, 75.0, 0.0), 155.2), "25级 Q ≈ 155")
	check(approx(DamageFormulas.transformative_damage(25, 2.0, 0.0), 240.0), "25级熔金 ≈ 240")
	# 期望伤害含暴击期望（策划案 9.2 完整式）
	var expected := DamageFormulas.expected_damage(22.0, 1.0, 1, 0.0, 0.0, 0.05, 0.5)
	check(approx(expected, 22.0 * 1.025), "期望伤害 = 面板 × (1 + 0.05×0.5)")

func _test_growth_curves() -> void:
	print("-- DamageFormulas：成长曲线边界")
	check(approx(DamageFormulas.character_max_hp(1100.0, 1), 1100.0), "1级 HP = 基础值")
	check(approx(DamageFormulas.character_atk(22.0, 20, 1), 41.06), "20级+1突破 ATK = 41.06")
	check(approx(DamageFormulas.enemy_max_hp(1), 22.0), "小怪 HP 基准 22×1^1.05")

## 反应表数据与策划案 5.3/9.4 一一对应
func _test_reaction_table_data() -> void:
	print("-- ReactionTable：第一期 5 反应数据")
	var table: ReactionTable = load("res://resources/reactions/reaction_table.tres")
	check(table != null, "reaction_table.tres 可加载")
	if table == null:
		return
	check(table.size() == 5, "反应表共 5 条")
	var steam := table.find(Elements.WATER, Elements.FIRE) # 水+火 → 蒸汽爆发
	check(steam != null and steam.id == &"steam_burst" and steam.reaction_type == ReactionDefinition.ReactionType.AMPLIFY and approx(steam.damage_mult, 1.5), "蒸汽爆发 = 水→火 增幅 ×1.5")
	var mist := table.find(Elements.FIRE, Elements.WATER) # 火+水 → 白雾弥漫
	check(mist != null and mist.id == &"white_mist" and approx(mist.damage_mult, 1.25) and mist.effect_id == &"slow" and approx(mist.effect_value, 0.3) and approx(mist.effect_duration, 4.0), "白雾弥漫 = 火→水 增幅 ×1.25 + 减速30% 4s")
	var molten := table.find(Elements.FIRE, Elements.METAL) # 火+金 → 熔金
	check(molten != null and molten.id == &"molten_gold" and molten.reaction_type == ReactionDefinition.ReactionType.TRANSFORM and approx(molten.damage_mult, 2.0) and molten.effect_id == &"armor_break" and approx(molten.effect_value, 0.25) and approx(molten.effect_duration, 6.0), "熔金 = 火→金 剧变 ×2.0 + 破甲25% 6s")
	var rust := table.find(Elements.WATER, Elements.METAL) # 水+金 → 锈蚀
	check(rust != null and rust.id == &"rust" and approx(rust.damage_mult, 1.0) and rust.effect_id == &"dot" and approx(rust.effect_value, 0.6) and approx(rust.effect_duration, 8.0), "锈蚀 = 水→金 DoT ×0.6/s 8s")
	var quench := table.find(Elements.METAL, Elements.FIRE) # 金+火 → 淬火脆化
	check(quench != null and quench.id == &"quench_brittle" and approx(quench.damage_mult, 0.0) and quench.effect_id == &"stagger_up" and approx(quench.effect_value, 1.5) and approx(quench.effect_duration, 3.0), "淬火脆化 = 金→火 硬直+50% 3s")
	check(table.find(Elements.METAL, Elements.WATER) == null, "金→水 无反应（方向性）")
	check(table.find(Elements.FIRE, Elements.FIRE) == null, "同元素无反应")
	check(table.by_id(&"molten_gold") != null, "by_id 查询有效")

## 附着规则：同元素取 max / 衰减 -0.2GU/s / 反应消耗与残留 / 单一 ICD 2.5s（策划案 5.3）
func _test_element_aura_rules() -> void:
	print("-- ElementAura：附着 / 衰减 / 反应 / ICD")
	var table: ReactionTable = load("res://resources/reactions/reaction_table.tres")
	# 场景 A：同元素取 max（1GU 上叠 2GU → 2GU，而非相加 3GU）+ 衰减
	var aura_a := ElementAura.new()
	aura_a.setup(table)
	aura_a.apply_incoming(Elements.FIRE, 1.0)
	check(approx(aura_a.gu(Elements.FIRE), 1.0), "火附着 1GU")
	aura_a.apply_incoming(Elements.FIRE, 2.0)
	check(approx(aura_a.gu(Elements.FIRE), 2.0), "重复施加取 max 不叠加（=2 而非 3）")
	aura_a.tick(1.0)
	check(approx(aura_a.gu(Elements.FIRE), 1.8), "衰减 -0.2GU/s")
	aura_a.free()
	# 场景 B：火 2GU + 水 2GU → 白雾；消耗双方 1GU，火侧残留 1GU
	var aura := ElementAura.new()
	aura.setup(table)
	aura.apply_incoming(Elements.FIRE, 2.0)
	var rd := aura.apply_incoming(Elements.WATER, 2.0)
	check(rd != null and rd.id == &"white_mist", "火+水 触发白雾弥漫")
	check(approx(aura.gu(Elements.FIRE), 1.0), "反应消耗 1GU 后火侧残留 1GU")
	check(not aura.has_aura(Elements.WATER), "后手元素被反应消耗，不残留")
	# 场景 C：ICD——反应后 2.5s 内同元素施加被挡
	check(aura.apply_incoming(Elements.FIRE, 1.0) == null, "ICD 内火施加无效")
	check(approx(aura.gu(Elements.FIRE), 1.0), "ICD 内附着量不变")
	aura.tick(2.6) # 过火/水 ICD（期间火衰减 1.0 → 0.48）
	check(aura.apply_incoming(Elements.FIRE, 1.0) == null and approx(aura.gu(Elements.FIRE), 1.0), "ICD 过后火附着恢复（取 max）")
	# 场景 D：火先金后 = 熔金（方向性）
	aura.tick(2.6)
	aura.apply_incoming(Elements.FIRE, 2.0)
	var rd2 := aura.apply_incoming(Elements.METAL, 2.0)
	check(rd2 != null and rd2.id == &"molten_gold", "火+金 触发熔金（非淬火：先手是火）")
	# 方向性：金先 + 火后 = 淬火
	var aura2 := ElementAura.new()
	aura2.setup(table)
	aura2.apply_incoming(Elements.METAL, 2.0)
	var rd3 := aura2.apply_incoming(Elements.FIRE, 1.0)
	check(rd3 != null and rd3.id == &"quench_brittle", "金+火 触发淬火脆化")
	check(approx(aura2.gu(Elements.METAL), 1.0), "反应消耗后金侧残留 1GU")
	# 场景 E：4GU 满附着 ≈ 20s（衰减至 0 消失）
	var aura3 := ElementAura.new()
	aura3.setup(table)
	aura3.apply_incoming(Elements.WATER, 4.0)
	aura3.tick(19.9)
	check(aura3.has_aura(Elements.WATER), "4GU 在 19.9s 时仍在")
	aura3.tick(0.2)
	check(not aura3.has_aura(Elements.WATER), "4GU 在 20.1s 时耗尽消失")
	aura.free()
	aura2.free()
	aura3.free()

func _test_status_holder() -> void:
	print("-- StatusHolder：减速 / 破甲 / DoT / 硬直强化")
	var status := StatusHolder.new()
	status.apply(&"slow", 0.3, 4.0)
	check(approx(status.get_speed_mult(), 0.7), "减速 30% → 速度 ×0.7")
	status.tick(4.05)
	check(approx(status.get_speed_mult(), 1.0), "减速 4s 后过期")
	status.apply(&"armor_break", 0.25, 6.0)
	check(approx(status.get_def_mult(), 0.75), "破甲 25% → 防御 ×0.75")
	status.apply(&"stagger_up", 1.5, 3.0)
	check(approx(status.stagger_mult(), 1.5), "淬火 → 硬直 ×1.5")
	# DoT：10 dps × 8s，每秒一跳（按 1s 步进 tick，模拟逐帧累积）
	var health := HealthComponent.new()
	health.max_hp = 100.0
	health.set_full()
	status.setup(health)
	status.apply_dot(10.0, 8.0)
	for i in 2:
		status.tick(1.0)
	check(approx(health.hp, 80.0), "DoT 2s 跳 2 次 = 80 HP")
	for i in 6:
		status.tick(1.0)
	check(approx(health.hp, 20.0), "DoT 8s 共 8 跳 = 20 HP")
	check(not status.has_dot(), "DoT 到期清除")
	# 冻结（卡文 Q，策划案 §7.3）
	status.apply(&"frozen", 0.0, 2.0)
	check(status.is_frozen(), "冻结生效")
	status.tick(2.1)
	check(not status.is_frozen(), "冻结 2s 后解除")
	# 淬火双效果：削霸效率 +50% 与霸体恢复暂停（策划案 §9.4）
	status.apply(&"stagger_up", 1.5, 3.0)
	status.apply(&"poise_pause", 0.0, 3.0)
	check(approx(status.poise_damage_mult(), 1.5) and status.poise_pause_active(), "淬火：削霸 +50% 且恢复暂停")
	status.free()
	health.free()

func _test_poise_component() -> void:
	print("-- PoiseComponent：削霸 / 破霸易伤 / 恢复暂停（策划案 §5.2/§9.4）")
	var status := StatusHolder.new()
	var poise := PoiseComponent.new()
	poise.setup(100.0, status)
	poise.take_poise_damage(40.0)
	check(approx(poise.poise, 60.0), "削霸 40 → 60")
	for i in 10:
		poise.tick(1.0)
	check(approx(poise.poise, 100.0), "未破霸缓慢恢复至上限")
	status.apply(&"poise_pause", 0.0, 3.0)
	poise.poise = 50.0
	poise.tick(1.0)
	check(approx(poise.poise, 50.0), "淬火期间恢复暂停")
	status.tick(3.1) # 过掉 poise_pause
	poise.poise = 20.0
	status.apply(&"stagger_up", 1.5, 3.0) # 淬火削霸效率 +50%
	var broke_count := [0]
	poise.broke.connect(func() -> void: broke_count[0] += 1)
	poise.take_poise_damage(20.0) # 20 × 1.5 = 30 ≥ 20 → 破霸
	check(poise.is_broken() and broke_count[0] == 1, "淬火加成下破霸触发且仅一次")
	check(approx(PoiseComponent.BROKEN_DAMAGE_TAKEN_MULT, 1.3), "破霸易伤乘区 = 1.3")
	for i in 6:
		poise.tick(1.0)
	check(not poise.is_broken() and approx(poise.poise, 100.0), "破霸 5s 后回满")
	status.free()
	poise.free()

func _test_character_runtime() -> void:
	print("-- CharacterRuntime：MP 恢复 / 能量 / 冷却（策划案 §9.1/§6.3）")
	var rt := CharacterRuntime.new()
	var cfg: CharacterConfig = load("res://resources/config/char_aiden.tres")
	rt.setup(cfg, &"aiden")
	check(approx(rt.max_mp, 82.0) and approx(rt.mp, 82.0), "MP 上限 = 80 + 2×等级 = 82")
	# 战斗/脱战恢复：前 4 秒 2/s（脱战前），5 秒起 8/s（数值取低避开 MP 上限钳制）
	rt.mp = 20.0
	rt.notify_combat()
	for i in 10:
		rt.tick_resources(1.0)
	check(approx(rt.mp, 76.0), "MP 恢复：战斗 2/s × 4s，脱战 5s 后 8/s × 6s（20+8+48=76）")
	# 能量与 Q 消耗
	rt.gain_energy(4.0 + 8.0 + 5.0 + 10.0)
	check(approx(rt.energy, 27.0), "能量获取（普攻4/技能8/受击5/入场10）")
	rt.gain_energy(500.0)
	check(approx(rt.energy, 100.0), "能量上限 100")
	check(not rt.can_cast_burst() or rt.consume_burst_energy(), "满能量可释放 Q")
	check(approx(rt.energy, 0.0), "Q 消耗后能量归零")
	# 冷却 tick
	rt.e_cooldown_left = 6.0
	for i in 6:
		rt.tick_resources(1.0)
	check(approx(rt.e_cooldown_left, 0.0), "E 冷却随 tick 递减")

func _test_party_inventory() -> void:
	print("-- PartyInventory：炼金尘（质之炼成代价源）")
	var inv := PartyInventory.new()
	inv.add_dust(3)
	check(inv.dust == 3, "入包 3 尘")
	check(inv.can_take_dust(3) and inv.take_dust(3), "质之炼成可扣 3 尘")
	check(not inv.can_take_dust(3), "不足 3 尘时不可扣")
	check(not inv.take_dust(3), "不足时扣除失败")

func _test_health_component() -> void:
	print("-- HealthComponent：伤害 / 无敌 / 死亡 / 治疗")
	var health := HealthComponent.new()
	health.max_hp = 50.0
	health.set_full()
	var died_count := [0]
	health.died.connect(func() -> void: died_count[0] += 1)
	check(health.take_damage(20.0) > 0.0 and approx(health.hp, 30.0), "扣血 20 → 30")
	health.invincible = true
	check(health.take_damage(100.0) == 0.0, "无敌免伤")
	health.invincible = false
	health.take_damage(100.0)
	check(health.is_dead() and died_count[0] == 1, "超量伤害致死且 died 只发一次")
	health.set_full()
	check(health.heal(10.0) == 0.0, "满血治疗无效")
	health.take_damage(10.0)
	check(approx(health.heal(999.0), 10.0), "治疗钳制到上限")
	health.free()

func _test_stamina_component() -> void:
	print("-- StaminaComponent：消耗 / 延迟恢复")
	var stamina := StaminaComponent.new()
	stamina.drain(15.0, 1.0)
	check(approx(stamina.stamina, 85.0), "冲刺 15/s × 1s = 85")
	stamina.tick(1.9)
	check(approx(stamina.stamina, 85.0), "停止消耗 2s 内不恢复")
	stamina.tick(0.2)
	check(approx(stamina.stamina, 89.0), "2s 后按 20/s 恢复（整 delta 4 点）")
	check(stamina.consume(100.0) == false, "一次性消耗不足时拒绝")
	check(stamina.consume(89.0) and approx(stamina.stamina, 0.0), "一次性消耗成功归零")
	stamina.free()

func _test_configs_and_scenes() -> void:
	print("-- 配置资源与场景可加载性（编辑器外格式校验）")
	var config_paths := {
		"camera": "res://resources/config/camera_config.tres",
		"movement": "res://resources/config/movement_config.tres",
		"combat": "res://resources/config/combat_config.tres",
		"char_aiden": "res://resources/config/char_aiden.tres",
		"char_lisea": "res://resources/config/char_lisea.tres",
		"char_kaven": "res://resources/config/char_kaven.tres",
		"enemy_miner": "res://resources/config/enemy_miner_config.tres",
		"enemy_hound": "res://resources/config/enemy_hound_config.tres",
		"enemy_puppet": "res://resources/config/enemy_puppet_config.tres",
		"enemy_mote": "res://resources/config/enemy_mote_config.tres",
		"enemy_overseer": "res://resources/config/enemy_overseer_config.tres",
		"reactions": "res://resources/reactions/reaction_table.tres",
	}
	for key in config_paths:
		check(load(config_paths[key]) != null, "配置可加载 " + key)
	var scene_paths := {
		"main": "res://scenes/main/main.tscn",
		"arena": "res://scenes/world/p0_arena.tscn",
		"player": "res://scenes/characters/player/player_character.tscn",
		"enemy_miner": "res://scenes/characters/enemies/enemy_miner.tscn",
		"enemy_hound": "res://scenes/characters/enemies/enemy_hound.tscn",
		"enemy_puppet": "res://scenes/characters/enemies/enemy_puppet.tscn",
		"enemy_mote": "res://scenes/characters/enemies/enemy_mote.tscn",
		"enemy_overseer": "res://scenes/characters/enemies/enemy_overseer.tscn",
		"training_dummy": "res://scenes/common/training_dummy.tscn",
		"damage_number": "res://scenes/common/damage_number.tscn",
		"water_bolt": "res://scenes/combat/water_bolt.tscn",
		"hud": "res://scenes/ui/hud.tscn",
		"pause": "res://scenes/ui/pause_overlay.tscn",
		"debug": "res://scenes/ui/debug_panel.tscn",
	}
	for key in scene_paths:
		check(load(scene_paths[key]) != null, "场景可加载 " + key)

func _test_localization() -> void:
	print("-- 本地化：翻译加载与回退（审核 2026-09-10 #8）")
	check(tr("HUD_HP") == "生命", "tr() 命中 zh_CN 词条")
	check(tr("REACTION_MOLTEN_GOLD") == "熔金", "反应名词条可用")
	check(tr("ELEMENT_FIRE") == "火", "元素显示名词条可用")
	check(tr("HUD_NOT_A_REAL_KEY") == "HUD_NOT_A_REAL_KEY", "缺失词条回退为 key 本身（不崩溃）")

func _test_pool_manager() -> void:
	print("-- PoolManager：复用与失效剔除（审核 2026-09-10 #4）")
	PoolManager.register_pool(&"test_probe", preload("res://scenes/common/damage_number.tscn"), 0)
	var first := PoolManager.spawn(&"test_probe")
	check(first != null, "spawn 返回实例")
	PoolManager.despawn(&"test_probe", first)
	var reused := PoolManager.spawn(&"test_probe")
	check(reused == first, "归还后复用同一实例")
	reused.free() # 模拟场景整体释放导致池内节点悬空
	var fresh := PoolManager.spawn(&"test_probe")
	check(fresh != null and is_instance_valid(fresh) and fresh != first, "池内失效节点被剔除并新建")
	PoolManager.despawn(&"test_probe", fresh)
	fresh.free()
	PoolManager.spawn(&"test_probe") # 触发剔除，验证脏池自愈

func _test_save_manager_roundtrip() -> void:
	print("-- SaveManager：JSON 往返 + 校验和防篡改（审核 2026-09-10 #7）")
	var payload := {"party": {"aiden": {"hp": 890, "mp": 120, "level": 12}}}
	check(SaveManager.save_game(99, payload), "存档写入成功")
	var loaded: Dictionary = SaveManager.load_game(99)
	check(not loaded.is_empty() and int(loaded.get("schema_version", 0)) == 1, "读回 schema_version = 1")
	var party: Dictionary = loaded.get("party", {})
	var aiden: Dictionary = party.get("aiden", {})
	check(int(aiden.get("hp", 0)) == 890 and int(aiden.get("level", 0)) == 12, "角色数据往返无损")
	check(SaveManager.has_save(99), "has_save 侦测有效")
	# 篡改正文（保持校验和不变）→ 必须被拦截
	var save_path := "%s/slot_%d.json" % [SaveManager.SAVE_DIR, 99]
	var read_file := FileAccess.open(save_path, FileAccess.READ)
	var text := read_file.get_as_text()
	read_file.close()
	var lines := text.split("\n")
	var write_file := FileAccess.open(save_path, FileAccess.WRITE)
	write_file.store_string(lines[0] + "\n" + String(lines[1]).replace("890", "99999"))
	write_file.close()
	check(SaveManager.load_game(99).is_empty(), "篡改正文被校验和拦截")
	# 缺校验和的裸 JSON → 拒绝
	var bare_file := FileAccess.open(save_path, FileAccess.WRITE)
	bare_file.store_string("{\"schema_version\":1}")
	bare_file.close()
	check(SaveManager.load_game(99).is_empty(), "无校验和的裸 JSON 被拒绝")
	# 清理
	DirAccess.remove_absolute(save_path)
	check(not SaveManager.has_save(99) and SaveManager.load_game(99).is_empty(), "删除后不再视为有存档")
	check(SaveManager.load_game(42).is_empty(), "不存在的槽位返回空")
