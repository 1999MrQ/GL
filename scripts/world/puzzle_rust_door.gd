class_name PuzzleRustDoor extends StaticBody3D
## 锈蚀锁链门（策划案 §8.1 元素谜题 3/3）：门体缠绕蚀化金属锁链，
## 需在门上触发"锈蚀"反应（先水后金，策划案 §5.3 组合顺序）蚀断锁链开启。
## 与炼成灯同一套附着管线：可被攻击命中（超大血量），监听自身的锈蚀反应事件。

var _open := false
var _aura: ElementAura
var _health: HealthComponent

func _ready() -> void:
	add_to_group("puzzle_rust_doors")
	collision_layer = 4 # enemy_body：玩家攻击查询可命中
	collision_mask = 0
	_aura = ElementAura.new()
	_aura.setup(DataManager.config("reactions"))
	add_child(_aura)
	_health = HealthComponent.new()
	_health.max_hp = 1000000000.0 # 实际不可打死：开启条件是反应而非伤害
	_health.set_full()
	add_child(_health)
	EventBus.reaction_triggered.connect(_on_reaction)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and EventBus.reaction_triggered.is_connected(_on_reaction):
		EventBus.reaction_triggered.disconnect(_on_reaction)

func is_open() -> bool:
	return _open

# —— Combat 目标接口（与 PuzzleLamp 同构）——
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

func _on_reaction(target: Node, reaction_id: StringName) -> void:
	if _open or target != self or reaction_id != &"rust":
		return
	_open = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	TransmuteRing.spawn(get_parent(), global_position, 2.2, Color(0.4, 0.75, 0.4))
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 3.0, 1.0)
	tween.tween_callback(queue_free)
