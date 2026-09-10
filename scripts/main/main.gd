extends Node
## 启动入口（技术方案 §2.2 scenes/main）：
## P1 装配 = PartyManager（3 角色常驻）+ 竞技场 + HUD + 暂停 + 调试面板 + 池注册。

const ASH_VALLEY_SCENE := preload("res://scenes/world/ash_valley.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_overlay.tscn")
const DEBUG_SCENE := preload("res://scenes/ui/debug_panel.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/common/damage_number.tscn")
const WATER_BOLT_SCENE := preload("res://scenes/combat/water_bolt.tscn")
const PLAYER_SPAWN := Vector3(0, 0.5, 10)

func _ready() -> void:
	randomize()
	GameManager.start_playing()
	PoolManager.register_pool(DamageNumber.POOL_ID, DAMAGE_NUMBER_SCENE, 8)
	PoolManager.register_pool(Projectile.POOL_ID, WATER_BOLT_SCENE, 4)
	EventBus.damage_number_requested.connect(_spawn_damage_number)
	EventBus.reaction_triggered.connect(_spawn_reaction_pop)
	EventBus.enemy_died.connect(_on_enemy_died_drop)

	var party := PartyManager.new()
	party.name = "PartyManager"
	add_child(party) # 先入树再装配：成员的 _ready/@onready 依赖节点已在树内（第二轮检查修复）
	party.setup(PLAYER_SPAWN, [
		DataManager.config("char_aiden"),
		DataManager.config("char_lisea"),
		DataManager.config("char_kaven"),
	])

	add_child(ASH_VALLEY_SCENE.instantiate())
	add_child(HUD_SCENE.instantiate())
	add_child(PAUSE_SCENE.instantiate())
	if OS.is_debug_build():
		add_child(DEBUG_SCENE.instantiate())

func _spawn_damage_number(world_pos: Vector3, amount: float, color: Color, is_crit: bool) -> void:
	var number := PoolManager.spawn(DamageNumber.POOL_ID) as DamageNumber
	if number == null:
		return
	add_child(number)
	number.setup(world_pos, amount, color, is_crit)

## 反应触发时在目标头顶弹出反应名（玩测反馈 2026-09-10：元素系统要看得见）
func _spawn_reaction_pop(target: Node, reaction_id: StringName) -> void:
	var table: ReactionTable = DataManager.config("reactions")
	var rd := table.by_id(reaction_id)
	if rd == null or not (target is Node3D):
		return
	var number := PoolManager.spawn(DamageNumber.POOL_ID) as DamageNumber
	if number == null:
		return
	add_child(number)
	number.setup_label(
		(target as Node3D).global_position + Vector3(0, 2.4, 0),
		tr(rd.name_key),
		Color(0.88, 0.6, 1.0))

## 掉落（策划案 §9.6 最小版）：击杀掉 1-3 炼金尘，直接入队伍背包
func _on_enemy_died_drop(_enemy: Node) -> void:
	var party := get_tree().get_first_node_in_group("party")
	if party != null:
		(party as PartyManager).inventory.add_dust(randi_range(1, 3))

func _exit_tree() -> void:
	EventBus.damage_number_requested.disconnect(_spawn_damage_number)
	EventBus.reaction_triggered.disconnect(_spawn_reaction_pop)
	EventBus.enemy_died.disconnect(_on_enemy_died_drop)
