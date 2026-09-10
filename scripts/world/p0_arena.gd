extends Node3D
## P1 战斗核心白模竞技场（技术方案 §5.1：第一期刻意单场景；正式灰烬河谷为 P2）。
## 玩家由 PartyManager 装配（见 main.gd）；本场景负责环境、敌人布设与补刷。

const ENEMY_SCENE_MINER := preload("res://scenes/characters/enemies/enemy_miner.tscn")
const ENEMY_SCENE_HOUND := preload("res://scenes/characters/enemies/enemy_hound.tscn")
const ENEMY_SCENE_PUPPET := preload("res://scenes/characters/enemies/enemy_puppet.tscn")
const ENEMY_SCENE_MOTE := preload("res://scenes/characters/enemies/enemy_mote.tscn")
const ENEMY_SCENE_OVERSEER := preload("res://scenes/characters/enemies/enemy_overseer.tscn")
const DUMMY_SCENE := preload("res://scenes/common/training_dummy.tscn")

const ARENA_HALF := 28.0
## 白模竞技场专属：敌人死亡后延时原地补刷，保证可持续试玩。
## 正式玩法（P2 灰烬河谷）的怪物刷新规则按策划案另行设计，不复用此逻辑。
const ENEMY_RESPAWN_SEC := 6.0
## 沙盒血量倍率：8×（33 → 264 HP），让"挂附着→切元素→触发反应"在
## 一场战斗里看得见（玩测反馈 2026-09-10）。正式数值见策划案 9.3。
const ENEMY_HP_MULT := 8.0

var _enemy_slots: Array = [] # { "pos": Vector3, "scene": PackedScene, "enemy": EnemyBase }

func _ready() -> void:
	_build_environment()
	_build_ground_and_walls()
	_build_obstacles()
	_spawn_actors()
	EventBus.enemy_died.connect(_on_enemy_died)
	print("=== GL · P1 战斗核心（白模） ===")
	print("WASD 移动 | 鼠标 视角 | 左键 三段攻击 | E 炼成技 | Q 炼成爆发(满能量) | R 等价交换")
	print("1/2/3 切换角色（艾登·金 / 莉赛尔·火 / 卡文·水）| F3 调试 | Esc 暂停")
	print("普通怪死后 6 秒补刷；北侧紫色为精英·矿监工（霸体条，破霸 5s 易伤）")

## —— 环境 —— ##

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.46, 0.65)
	sky_mat.sky_horizon_color = Color(0.68, 0.62, 0.55)
	sky_mat.ground_bottom_color = Color(0.15, 0.14, 0.13)
	sky_mat.ground_horizon_color = Color(0.55, 0.5, 0.45)
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
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

## —— 地面与围墙 —— ##

func _build_ground_and_walls() -> void:
	_add_box(Vector3.ZERO, Vector3(ARENA_HALF * 2, 1.0, ARENA_HALF * 2), Color(0.42, 0.44, 0.47))
	var wall_color := Color(0.3, 0.32, 0.36)
	var wall_len := ARENA_HALF * 2 + 2.0
	_add_box(Vector3(0, 1.5, -ARENA_HALF - 0.5), Vector3(wall_len, 3.0, 1.0), wall_color)
	_add_box(Vector3(0, 1.5, ARENA_HALF + 0.5), Vector3(wall_len, 3.0, 1.0), wall_color)
	_add_box(Vector3(-ARENA_HALF - 0.5, 1.5, 0), Vector3(1.0, 3.0, wall_len), wall_color)
	_add_box(Vector3(ARENA_HALF + 0.5, 1.5, 0), Vector3(1.0, 3.0, wall_len), wall_color)

## —— 障碍：缓坡（可行走）/ 陡壁（不可攀，P2 攀爬目标）/ 箱子群 —— ##

func _build_obstacles() -> void:
	# 缓坡 ~20°：直接行走（策划案 8.2：缓坡无需攀爬）
	_add_box(Vector3(12, 1.2, 10), Vector3(5, 0.6, 10), Color(0.5, 0.52, 0.5), -20.0)
	# 陡壁 ~70°：滑落（≥65° 陡峭面，P2 接攀爬）
	_add_box(Vector3(-14, 1.6, -12), Vector3(5, 0.5, 7), Color(0.35, 0.37, 0.4), -70.0)
	var crate_color := Color(0.55, 0.47, 0.36)
	for offset in [Vector3(4, 0.5, -6), Vector3(5.2, 0.5, -6.4), Vector3(4.6, 1.5, -6.2), Vector3(-6, 0.5, 8), Vector3(-18, 0.5, 4), Vector3(16, 0.5, -12)]:
		_add_box(offset, Vector3(1, 1, 1), crate_color)

## —— 角色布设（玩家由 PartyManager 装配，见 main.gd）—— ##

func _spawn_actors() -> void:
	# 普通怪：可补刷槽位（正式刷新规则属 P2，见策划案 §8.1）
	_add_respawn_slot(Vector3(-14, 0.5, -6), ENEMY_SCENE_MINER)
	_add_respawn_slot(Vector3(14, 0.5, -14), ENEMY_SCENE_MINER)
	_add_respawn_slot(Vector3(-18, 0.5, 0), ENEMY_SCENE_HOUND)
	_add_respawn_slot(Vector3(10, 0.5, -2), ENEMY_SCENE_HOUND)
	_add_respawn_slot(Vector3(16, 0.5, 6), ENEMY_SCENE_MOTE)
	_add_respawn_slot(Vector3(-8, 0.5, -18), ENEMY_SCENE_MOTE)
	_add_respawn_slot(Vector3(-2, 0.5, -14), ENEMY_SCENE_PUPPET)
	# 精英：北侧固定位，不补刷（挑战性单位，策划案 §5.4）
	var overseer := ENEMY_SCENE_OVERSEER.instantiate()
	overseer.position = Vector3(0, 0.5, -24)
	add_child(overseer)

	# 训练假人（连段与反应验证）
	for pos: Vector3 in [Vector3(-6, 0, 2), Vector3(-4, 0, 2), Vector3(-2, 0, 2)]:
		var dummy := DUMMY_SCENE.instantiate()
		dummy.position = pos
		add_child(dummy)

func _add_respawn_slot(pos: Vector3, scene: PackedScene) -> void:
	var enemy := _spawn_enemy(scene, pos)
	_enemy_slots.append({"pos": pos, "scene": scene, "enemy": enemy})

func _spawn_enemy(scene: PackedScene, pos: Vector3) -> EnemyBase:
	var enemy: EnemyBase = scene.instantiate()
	enemy.position = pos
	if scene == ENEMY_SCENE_MINER:
		enemy.hp_multiplier = ENEMY_HP_MULT # 沙盒血量：仅矿工，保持反应链可观察
	add_child(enemy)
	return enemy

## 敌人死亡 → 找到所属槽位 → 延时原地补刷（玩测反馈 2026-09-10）
func _on_enemy_died(enemy: Node) -> void:
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

func _add_box(pos: Vector3, size: Vector3, color: Color, rot_x_deg: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 # world
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
