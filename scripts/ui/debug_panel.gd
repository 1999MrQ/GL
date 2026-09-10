extends CanvasLayer
## 调试面板（技术方案 10.2，仅 debug build 实例化）：F3 开关。
## FPS / DrawCall / 显存 / 节点数实时显示；快捷键：
## [ ] 时间缩放 · I 无敌 · T 传送回出生点 · K 清怪 · V 元素附着可视化
## 附着可视化开关经 SceneTree 元数据广播（避免与 EnemyBase 类名循环依赖）。

const AURA_VIZ_META := "gl_show_aura_viz"

@onready var text_label: Label = $Panel/Text

var _aura_viz := false
var _accum := 0.0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	var lines: Array[String] = []
	lines.append("FPS %d | DrawCall %d | VRAM %.0f MB" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
	])
	lines.append("Objects %d | Nodes %d | Enemies %d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		get_tree().get_node_count(),
		get_tree().get_nodes_in_group("enemies").size(),
	])
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var pos := player.global_position
		lines.append("Player %.1f, %.1f, %.1f" % [pos.x, pos.y, pos.z])
	lines.append("time_scale %.2f | invincible %s | aura_viz %s" % [
		Engine.time_scale,
		_get_player_invincible(),
		_aura_viz,
	])
	lines.append("[ ] timescale · I invincible · T teleport · K kill · V aura")
	text_label.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_BRACKETLEFT:
				Engine.time_scale = maxf(0.1, Engine.time_scale - 0.1)
			KEY_BRACKETRIGHT:
				Engine.time_scale = minf(3.0, Engine.time_scale + 0.1)
			KEY_I:
				_toggle_invincible()
			KEY_T:
				_teleport_player()
			KEY_K:
				_kill_all_enemies()
			KEY_V:
				_aura_viz = not _aura_viz
				get_tree().set_meta(AURA_VIZ_META, _aura_viz)

func _toggle_invincible() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
	if player != null:
		player.health.invincible = not player.health.invincible

func _get_player_invincible() -> String:
	var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
	return "on" if player != null and player.health.invincible else "off"

func _teleport_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
	if player != null:
		player.global_position = Vector3(0, 2, 10)
		player.horizontal_velocity = Vector3.ZERO
		player.vertical_velocity = 0.0

func _kill_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyBase:
			(enemy as EnemyBase).health.invincible = false
			(enemy as EnemyBase).health.take_damage(999999.0)
