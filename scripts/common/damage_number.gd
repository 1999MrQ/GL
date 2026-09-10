class_name DamageNumber extends Label3D
## 池化伤害数字 / 反应名提示（技术方案 4.1）：上浮 + 淡出 + 入场弹跳；暴击放大。
## 世界尺寸 ≈ font_size × pixel_size：46 × 0.01 ≈ 0.46m 高（2026-09-10 玩测反馈调大）。

const POOL_ID := &"damage_number"
const LIFETIME := 0.85
const RISE_SPEED := 1.6
const POP_TIME := 0.12

var _elapsed := 0.0

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	outline_size = 16
	pixel_size = 0.01
	font_size = 46

## 伤害数字
func setup(world_pos: Vector3, amount: float, color: Color, is_crit: bool) -> void:
	text = str(roundi(amount))
	position = world_pos
	_elapsed = 0.0
	modulate = color
	outline_modulate = Color(0.05, 0.05, 0.08, 1.0)
	font_size = 64 if is_crit else 46
	visible = true

## 文本提示（反应名等）：紫色系、稍小、同款上浮
func setup_label(world_pos: Vector3, label_text: String, color: Color) -> void:
	text = label_text
	position = world_pos
	_elapsed = 0.0
	modulate = color
	outline_modulate = Color(0.05, 0.05, 0.08, 1.0)
	font_size = 40
	visible = true

func _process(delta: float) -> void:
	_elapsed += delta
	position.y += RISE_SPEED * delta
	# 入场弹跳：0.12s 内从 1.4x 回落到 1.0x
	var pop := 1.0 + 0.4 * maxf(0.0, 1.0 - _elapsed / POP_TIME)
	scale = Vector3.ONE * pop
	# 后半段淡出
	modulate.a = clampf((LIFETIME - _elapsed) / (LIFETIME * 0.5), 0.0, 1.0)
	if _elapsed >= LIFETIME:
		PoolManager.despawn(POOL_ID, self)
