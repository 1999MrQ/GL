extends CanvasLayer
## Esc 暂停 / 继续（P0 临时实现；正式菜单与设置屏为 P3 清单）。
## 顺带负责鼠标锁定与释放：暂停时释放指针，继续时重新锁定。

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		GameManager.toggle_pause()
		_sync()
		get_viewport().set_input_as_handled()
		return
	# 暂停外的任意点击 → 重新锁定鼠标（Esc 释放后恢复）
	if GameManager.state == GameManager.State.PLAYING \
			and event is InputEventMouseButton and event.is_pressed():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _sync() -> void:
	visible = GameManager.state == GameManager.State.PAUSED
	$ColorRect/Center/VBox/Title.text = tr("MENU_PAUSED")
	$ColorRect/Center/VBox/Hint.text = tr("MENU_RESUME_HINT")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
