class_name ClimbState extends StateBase
## 攀爬（策划案 §8.2 / 技术方案 §3.3）：
## ≥65° 陡面进入；墙面四向移动（2.5m/s）；体力 10/s，耗尽坠落；
## 跳离墙面 / 上爬过墙沿自动翻越（mantle）。

const CLIMB_SPEED := 2.5
const STAMINA_DRAIN := 10.0
## 表面倾角 θ 与法线关系：dot(normal, UP) = cos(θ)。θ ≥ 65° ⇔ normal.y ≤ cos65° ≈ 0.42
const MIN_STEEPNESS_DOT := 0.42

## 陡面判定（缓坡 normal.y≈0.94 不可爬；垂直墙 0.0 可爬）
static func is_climbable(wall_normal: Vector3) -> bool:
	return wall_normal.y <= MIN_STEEPNESS_DOT

## 蚀晶壁（策划案 §8.2）：表面蚀晶化的陡壁徒手不可攀——
## 需金元素技能生成抓握点（ClimbHold）后才可通过；攀爬入口（run/air）调用
static func is_blocked(wall: Dictionary) -> bool:
	var collider: Variant = wall.get("collider")
	return collider is Node and (collider as Node).is_in_group(ErosionWall.GROUP)

var wall_normal := Vector3.BACK

func enter(msg: Dictionary) -> void:
	var p := player()
	wall_normal = (msg.get("normal", Vector3.BACK) as Vector3)
	wall_normal.y = 0.0 # 水平化为贴墙/移动基准，斜面也不漂移
	if wall_normal.length_squared() < 0.01:
		wall_normal = Vector3.BACK
	wall_normal = wall_normal.normalized()
	p.vertical_velocity = 0.0
	p.face_toward(-wall_normal, 1.0)

func physics_update(delta: float) -> void:
	var p := player()
	# 体力（策划案 §5.2：攀爬 10/s；耗尽坠落）
	p.stamina.drain(STAMINA_DRAIN, delta)
	if p.stamina.stamina <= 0.0:
		sm.transition(&"air", {})
		return

	var input := p.actor_source.move_vector()
	var up_move := -input.y # 前推 = 向上爬

	# 贴墙检测：脱离墙面 → 上推翻越（mantle），否则脱离坠落
	var hit := p.probe_wall(-wall_normal)
	if hit.is_empty():
		if up_move > 0.3:
			p.vertical_velocity = 7.0 # 翻越墙沿
			p.horizontal_velocity = -wall_normal * 2.0
		else:
			p.vertical_velocity = 0.0
		sm.transition(&"air", {})
		return

	# 墙面四向移动：竖直直控（攀爬中无重力），水平沿墙面切线；并持续压向墙面
	var tangent := Vector3.UP.cross(wall_normal).normalized()
	p.vertical_velocity = up_move * CLIMB_SPEED
	p.horizontal_velocity = tangent * (-input.x) * CLIMB_SPEED - wall_normal * 1.5

	# 落地且主动下爬 → 回地面
	if p.is_on_floor() and up_move < -0.3:
		sm.transition(&"idle", {})
		return

	# 跳离墙面
	if p.jump_buffer_timer > 0.0:
		p.jump_buffer_timer = 0.0
		p.vertical_velocity = p.movement.jump_velocity * 0.8
		p.horizontal_velocity = -wall_normal * 4.0
		sm.transition(&"air", {})
