extends Node
## 游戏状态机（技术方案 2.1）：BOOT / MENU / PLAYING / PAUSED + 场景切换。
## 另承载战斗顿帧（hitstop）——策划案 P0 验收项"攻击命中反馈明确（顿帧/闪白/击退）"。

enum State { BOOT, MENU, PLAYING, PAUSED }

var state: int = State.BOOT

var _hitstop_until_ms: int = 0
var _hitstop_previous_scale: float = 1.0

func change_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	EventBus.game_state_changed.emit(new_state)

func start_playing() -> void:
	change_state(State.PLAYING)

func toggle_pause() -> void:
	if state == State.PLAYING:
		get_tree().paused = true
		change_state(State.PAUSED)
	elif state == State.PAUSED:
		get_tree().paused = false
		change_state(State.PLAYING)

func goto_scene(path: String) -> void:
	get_tree().paused = false
	change_state(State.BOOT)
	get_tree().change_scene_to_file(path)

## 战斗顿帧：短暂压低时间流速制造打击感。
## ignore_time_scale 的计时器负责恢复，保证顿帧本身不受 time_scale 影响；
## 恢复到"进入前"的缩放而非硬编码 1.0——调试面板设置的时间缩放不被吞掉（审核 2026-09-10 #6）。
func hitstop(duration: float = 0.09, time_scale: float = 0.05) -> void:
	if get_tree().paused:
		return
	var now := Time.get_ticks_msec()
	if now < _hitstop_until_ms:
		return
	_hitstop_until_ms = now + int(duration * 1000.0)
	_hitstop_previous_scale = Engine.time_scale
	Engine.time_scale = time_scale
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = _hitstop_previous_scale)
