class_name PuzzleDoor extends StaticBody3D
## 密门（策划案 §8.1 元素谜题）：同 puzzle_id 的炼成灯全部点亮 → 开启。
## 开启 = 碰撞移除 + 门体下沉消失；区域内不被补刷。

@export var puzzle_id: StringName = &"puzzle_01"

var _open := false
var _lamps: Array = [] # 由区域布设方注入

func register_lamps(lamps: Array) -> void:
	_lamps = lamps

func _physics_process(delta: float) -> void:
	if _open:
		return
	var all_lit := _lamps.size() > 0
	for lamp in _lamps:
		if not is_instance_valid(lamp) or not (lamp as PuzzleLamp).is_lit():
			all_lit = false
			break
	if all_lit:
		open()

func open() -> void:
	_open = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	TransmuteRing.spawn(get_parent(), global_position, 2.0, Color(1.0, 0.7, 0.3))
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 3.0, 1.0)
	tween.tween_callback(queue_free)
