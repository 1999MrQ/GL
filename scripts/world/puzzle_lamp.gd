class_name PuzzleLamp extends StaticBody3D
## 炼成灯（策划案 §8.1 元素谜题示例：用火点燃 3 座炼成灯开启密门）。
## 火元素伤害命中（火附着）即点亮；同 puzzle_id 全亮 → 对应密门开启。
## 实现：与怪物共用同一套附着/结算管线（超大血量不可打死的可命中对象），
## 监听自己的火附着事件点亮。

@export var puzzle_id: StringName = &"puzzle_01"

var _lit := false
var _flame: MeshInstance3D
var _aura: ElementAura
var _health: HealthComponent

func _ready() -> void:
	add_to_group("puzzle_lamps")
	collision_layer = 4 # enemy_body：玩家攻击查询可命中
	collision_mask = 0
	_aura = ElementAura.new()
	_aura.setup(DataManager.config("reactions"))
	add_child(_aura)
	_health = HealthComponent.new()
	_health.max_hp = 1000000000.0 # 实际不可打死的可命中对象
	_health.set_full()
	add_child(_health)

	var pillar := MeshInstance3D.new()
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.4, 1.4, 0.4)
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.5, 0.45, 0.4)
	pillar_mesh.material = pillar_mat
	pillar.mesh = pillar_mesh
	pillar.position.y = 0.7
	add_child(pillar)

	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(0.35, 0.35, 0.4) # 未点亮：暗
	_flame = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.material = flame_mat
	_flame.mesh = mesh
	_flame.position.y = 1.6
	add_child(_flame)

	EventBus.element_applied.connect(_on_element_applied)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and EventBus.element_applied.is_connected(_on_element_applied):
		EventBus.element_applied.disconnect(_on_element_applied)

func is_lit() -> bool:
	return _lit

## Combat 目标接口
func get_health() -> HealthComponent:
	return _health

func get_defense() -> float:
	return 0.0

func get_resistance(_element: StringName) -> float:
	return 0.0

func get_aura() -> ElementAura:
	return _aura

func status_holder() -> StatusHolder:
	return null

func _on_element_applied(target: Node, element: StringName, _gu: float) -> void:
	if _lit or target != self or element != Elements.FIRE:
		return
	_lit = true
	(_flame.mesh as SphereMesh).material.albedo_color = Color(1.0, 0.6, 0.15)
	TransmuteRing.spawn(get_parent(), global_position, 0.8, Elements.color(Elements.FIRE))
