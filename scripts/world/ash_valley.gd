extends Node3D
## 灰烬河谷（策划案 §8.1：250×250m 三段结构——废弃矿镇 → 河谷走廊 → 蚀化洞窟）。
## P2 白模 V2：地形/高壁（攀爬）/传送阵×3/采集点×15/宝箱×8/谜题原型（3 灯开密门）/BOSS。
## 美术资产为占位规范灰模；正式场景内容按策划案在 P2 后续轮次填充。

const PLAYER_SPAWN := Vector3(0, 0.5, 100)
const HALF := 125.0

const ENEMY_SCENES := {
	&"miner": preload("res://scenes/characters/enemies/enemy_miner.tscn"),
	&"hound": preload("res://scenes/characters/enemies/enemy_hound.tscn"),
	&"mote": preload("res://scenes/characters/enemies/enemy_mote.tscn"),
	&"puppet": preload("res://scenes/characters/enemies/enemy_puppet.tscn"),
}
const OVERSEER_SCENE := preload("res://scenes/characters/enemies/enemy_overseer.tscn")
const BOSS_SCENE := preload("res://scenes/characters/enemies/boss_colossus.tscn")
const GATHER_SCENE := preload("res://scenes/world/gather_node.tscn")
const CHEST_SCENE := preload("res://scenes/world/chest.tscn")
const LAMP_SCENE := preload("res://scenes/world/puzzle_lamp.tscn")
const PUZZLE_DOOR_SCENE := preload("res://scenes/world/puzzle_door.tscn")
const RUST_DOOR_SCENE := preload("res://scenes/world/puzzle_rust_door.tscn")
const VISTA_SCENE := preload("res://scenes/world/vista_point.tscn")
const EROSION_WALL_SCENE := preload("res://scenes/world/erosion_wall.tscn")

const ENEMY_RESPAWN_SEC := 6.0
const ENEMY_HP_MULT := 8.0

var _enemy_slots: Array = []

func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_interactables()
	_spawn_actors()
	EventBus.enemy_died.connect(_on_enemy_died)
	print("=== GL · 灰烬河谷（P2 白模 V2） ===")
	print("矿镇(南) → 河谷走廊 → 蚀化洞窟(北，BOSS 蚀核巨像)")
	print("攀爬：推向 ≥65° 陡面自动扒墙（10 体力/s）· 滑翔：空中再按跳跃（8 体力/s）")
	print("F 采集/开箱/传送/观景 · 谜题：火点炼成灯 / 水点亮寒晶镜 / 先水后金蚀断锁链门 · BOSS 战火先金后打熔金破壳、用水开蒸汽安全区")
	print("P2 第二轮新增：蚀晶壁（金技能造攀爬点，墙顶有宝箱）· F5 存档 / F9 读档（野外采集刷新）")

## —— 环境 —— ##

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.38, 0.45) # 灰烬天色
	sky_mat.sky_horizon_color = Color(0.62, 0.55, 0.5)
	sky_mat.ground_bottom_color = Color(0.15, 0.14, 0.13)
	sky_mat.ground_horizon_color = Color(0.45, 0.4, 0.36)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

## —— 地形：三段结构与攀爬高壁 —— ##

func _build_terrain() -> void:
	# 地面与边界（边界墙 20m：攀爬体力上限 100 无法翻越出图——复审 2026-09-11 #2）
	_add_box(Vector3.ZERO, Vector3(HALF * 2, 1.0, HALF * 2), Color(0.4, 0.38, 0.36))
	var wall_color := Color(0.28, 0.27, 0.3)
	var wall_len := HALF * 2 + 2.0
	_add_box(Vector3(0, 10, -HALF - 0.5), Vector3(wall_len, 20.0, 1.0), wall_color)
	_add_box(Vector3(0, 10, HALF + 0.5), Vector3(wall_len, 20.0, 1.0), wall_color)
	_add_box(Vector3(-HALF - 0.5, 10, 0), Vector3(1.0, 20.0, wall_len), wall_color)
	_add_box(Vector3(HALF + 0.5, 10, 0), Vector3(1.0, 20.0, wall_len), wall_color)

	# 攀爬教学墙（垂直 8m，墙顶宝箱激励；策划案 §8.2：≥65° 陡面攀爬）
	_add_box(Vector3(0, 4, 78), Vector3(12, 8.0, 1.2), Color(0.34, 0.33, 0.36))
	# 缓坡对照（20°，直接行走不可攀）
	_add_box(Vector3(-30, 0.8, 70), Vector3(8, 0.6, 12), Color(0.42, 0.41, 0.4), -20.0)

	# 矿镇废墟（南区，出生点周边）
	var ruin := Color(0.36, 0.35, 0.38)
	for pos in [Vector3(-12, 1, 92), Vector3(14, 1.5, 90), Vector3(-20, 0.75, 84), Vector3(20, 0.75, 96)]:
		_add_box(pos, Vector3(3, 2, 3), ruin)
	# 河谷走廊岩石（中区）
	var rock := Color(0.33, 0.35, 0.33)
	for pos in [Vector3(-45, 1, 20), Vector3(48, 1.4, -10), Vector3(-52, 1, -30), Vector3(38, 1.2, 35)]:
		_add_box(pos, Vector3(4, 2, 4), rock)
	# 洞窟（北区）：三面围墙 + 南侧开口
	var cave := Color(0.25, 0.24, 0.27)
	_add_box(Vector3(-20, 3, -90), Vector3(1.5, 6.0, 40), cave)
	_add_box(Vector3(20, 3, -90), Vector3(1.5, 6.0, 40), cave)
	_add_box(Vector3(0, 3, -109.5), Vector3(41.5, 6.0, 1.0), cave)

func _build_interactables() -> void:
	# 传送炼成阵 ×3（策划案 §8.1）：矿镇 / 河谷 / 洞窟口
	_add_gate(&"gate_town", Vector3(6, 0, 96))
	_add_gate(&"gate_valley", Vector3(70, 0, 0))
	_add_gate(&"gate_cave", Vector3(0, 0, -55))

	# 采集点（策划案 §8.1：矿脉/药草/水镜露；野外读档刷新，洞窟一次性）
	var gather_index := 0
	var ore_spots := [Vector2(-25, 88), Vector2(30, 82), Vector2(-40, 40), Vector2(45, 30), Vector2(-60, -10), Vector2(55, -35)]
	for p: Vector2 in ore_spots:
		_add_gather(&"ore", Vector3(p.x, 0, p.y), "gather_%02d" % gather_index, false)
		gather_index += 1
	var herb_spots := [Vector2(-15, 70), Vector2(20, 55), Vector2(-35, 5), Vector2(60, 15), Vector2(-5, -20)]
	for p: Vector2 in herb_spots:
		_add_gather(&"herb", Vector3(p.x, 0, p.y), "gather_%02d" % gather_index, false)
		gather_index += 1
	var dew_spots := [Vector2(-70, 60), Vector2(75, 45), Vector2(-75, -55), Vector2(80, -60)]
	for p: Vector2 in dew_spots:
		_add_gather(&"dew", Vector3(p.x, 0, p.y), "gather_%02d" % gather_index, false)
		gather_index += 1
	# 洞窟内一次性采集（策划案 §8.1"洞窟内采集为一次性"——读档不刷新，避开 BOSS 仇恨圈）
	_add_gather(&"ore", Vector3(14, 0, -74), "gather_%02d" % gather_index, true)
	gather_index += 1
	_add_gather(&"dew", Vector3(-14, 0, -76), "gather_%02d" % gather_index, true)

	# 宝箱（策划案 §8.1 ×8 + 蚀晶壁顶/水谜密门后各 1——P2 第二轮密度调优，不刷新）
	var chest_index := 0
	for pos: Vector3 in [Vector3(0, 8.05, 78), Vector3(-15, 0, 95), Vector3(18, 0, 78), Vector3(-45, 0, 25),
			Vector3(50, 0, -15), Vector3(-60, 0, -35), Vector3(40, 0, 40), Vector3(-12, 0, -70)]:
		_add_chest(pos, "chest_%02d" % chest_index)
		chest_index += 1
	_add_chest(Vector3(78, 10.6, 20), "chest_%02d" % chest_index) # 蚀晶壁顶（金技能攀爬奖励）
	chest_index += 1
	_add_chest(Vector3(-52, 0, -35), "chest_%02d" % chest_index) # 水谜密门后
	chest_index += 1

	# 元素谜题 1/3（策划案 §8.1 示例）：炼成灯（火）×3 → 密门
	var lamps: Array = []
	for pos: Vector3 in [Vector3(46, 0, 52), Vector3(52, 0, 44), Vector3(40, 0, 42)]:
		var lamp := LAMP_SCENE.instantiate()
		lamp.position = pos
		add_child(lamp)
		lamps.append(lamp)
	var door := PUZZLE_DOOR_SCENE.instantiate()
	door.position = Vector3(46, 1.5, 36)
	add_child(door)
	door.register_lamps(lamps)

	# 元素谜题 2/3：寒晶镜（水附着点亮）×3 → 密门（P2 第二轮，复用灯的管线）
	var mirrors: Array = []
	for pos: Vector3 in [Vector3(-48, 0, -28), Vector3(-56, 0, -28), Vector3(-52, 0, -24)]:
		var mirror := LAMP_SCENE.instantiate()
		mirror.target_element = Elements.WATER
		mirror.position = pos
		add_child(mirror)
		mirrors.append(mirror)
	var mirror_door := PUZZLE_DOOR_SCENE.instantiate()
	mirror_door.position = Vector3(-52, 1.5, -32)
	add_child(mirror_door)
	mirror_door.register_lamps(mirrors)

	# 元素谜题 3/3：锈蚀锁链门——需在门上触发锈蚀反应（先水后金，策划案 §5.3）
	var rust_door := RUST_DOOR_SCENE.instantiate()
	rust_door.position = Vector3(-12, 1.5, -66) # 守住洞窟内既有宝箱
	add_child(rust_door)

	# 观景点 ×2（策划案 §8.1）：攀爬教学墙顶 / 洞窟口
	_add_vista("VISTA_VALLEY", Vector3(1.5, 8.1, 78))
	_add_vista("VISTA_CAVE", Vector3(4, 0.5, -50))

	# 蚀晶壁（策划案 §8.2"第一期亮点"）：金元素技能命中生成攀爬抓握点，墙顶有宝箱
	var erosion := EROSION_WALL_SCENE.instantiate()
	erosion.position = Vector3(78, 5.5, 20)
	add_child(erosion)

func _add_gate(gate_id: StringName, pos: Vector3) -> void:
	var gate := preload("res://scenes/world/teleport_gate.tscn").instantiate()
	gate.gate_id = gate_id
	gate.position = pos
	add_child(gate)

func _add_gather(resource_id: StringName, pos: Vector3, id: String, one_shot: bool) -> void:
	var node := GATHER_SCENE.instantiate()
	node.resource_id = resource_id
	node.node_id = id
	node.one_shot = one_shot
	node.position = pos
	add_child(node)

func _add_chest(pos: Vector3, id: String) -> void:
	var chest := CHEST_SCENE.instantiate()
	chest.node_id = id
	chest.position = pos
	add_child(chest)

func _add_vista(vista_key: String, pos: Vector3) -> void:
	var vista := VISTA_SCENE.instantiate()
	vista.vista_key = vista_key
	vista.position = pos
	add_child(vista)

## —— 敌人布设（槽位化补刷；BOSS/精英不补刷）—— ##

func _spawn_actors() -> void:
	var spots := [
		[&"miner", Vector3(-20, 0.5, 75)], [&"miner", Vector3(25, 0.5, 70)],
		[&"hound", Vector3(-35, 0.5, 30)], [&"hound", Vector3(30, 0.5, 20)],
		[&"mote", Vector3(-60, 0.5, 10)], [&"mote", Vector3(65, 0.5, -20)],
		[&"miner", Vector3(-40, 0.5, -20)], [&"puppet", Vector3(35, 0.5, -35)],
		[&"mote", Vector3(-30, 0.5, -50)], [&"hound", Vector3(15, 0.5, -45)],
		[&"puppet", Vector3(-12, 0.5, -75)], [&"miner", Vector3(12, 0.5, -80)],
	]
	for spot: Array in spots:
		var enemy := _spawn_enemy(ENEMY_SCENES[spot[0]], spot[1])
		_enemy_slots.append({"pos": spot[1], "scene": ENEMY_SCENES[spot[0]], "enemy": enemy})
	# 精英（河谷深处）与 BOSS（洞窟底，留出与后墙的间距）
	var overseer := OVERSEER_SCENE.instantiate()
	overseer.position = Vector3(0, 0.5, -35)
	add_child(overseer)
	var boss := BOSS_SCENE.instantiate()
	boss.position = Vector3(0, 0.5, -104)
	add_child(boss)

func _spawn_enemy(scene: PackedScene, pos: Vector3) -> EnemyBase:
	var enemy: EnemyBase = scene.instantiate()
	enemy.position = pos
	if scene == ENEMY_SCENES[&"miner"]:
		enemy.hp_multiplier = ENEMY_HP_MULT # 沙盒血量：反应链可观察（正式数值见策划案 9.3）
	add_child(enemy)
	return enemy

func _on_enemy_died(enemy: Node) -> void:
	if enemy is BossColossus:
		print("=== 蚀核巨像已讨伐：突破素材已入包（白模） ===")
		var party := get_tree().get_first_node_in_group("party")
		if party != null:
			(party as PartyManager).inventory.add_dust(50)
	for slot in _enemy_slots:
		if slot["enemy"] == enemy:
			slot["enemy"] = null
			var timer := Timer.new()
			timer.one_shot = true
			timer.wait_time = ENEMY_RESPAWN_SEC
			timer.timeout.connect(func() -> void:
				timer.queue_free()
				slot["enemy"] = _spawn_enemy(slot["scene"], slot["pos"])
			)
			add_child(timer)
			timer.start()
			return

## —— 白模盒体工具 —— ##

func _add_box(pos: Vector3, size: Vector3, color: Color, rot_x_deg: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.x = rot_x_deg
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box_mesh.material = mat
	mesh_instance.mesh = box_mesh
	body.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body
