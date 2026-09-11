class_name VistaPoint extends Interactable
## 观景点（策划案 §8.1 ×2）：F 观赏——头顶弹出景点文本，一次性。

@export var vista_key := "VISTA_VALLEY" ## 本地化 key（data/loc/zh.csv）

var _visited := false

func interact(_player: PlayerCharacter) -> void:
	if _visited:
		return
	_visited = true
	remove_from_group("interactables")
	TransmuteRing.spawn(get_parent(), global_position, 2.2, Color(1.0, 0.9, 0.6))
	# 景点文本：临时 Label3D 上浮淡出（一次性事件，不值得入池）
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 12
	label.modulate = Color(1.0, 0.95, 0.75)
	label.text = tr(vista_key)
	get_parent().add_child(label)
	label.global_position = global_position + Vector3(0, 2.8, 0)
	var tween := label.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

func is_visited() -> bool:
	return _visited

func prompt() -> String:
	return "" if _visited else tr("INTERACT_VISTA")
