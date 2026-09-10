class_name CameraRig extends Node3D
## 第三人称越肩相机（技术方案 3.1）：SpringArm3D 碰撞收缩防穿墙（P0 验收项）。
## yaw 由本节点 rotation.y 承担，pitch 由 SpringArm3D.rotation.x 承担。

@export var config: CameraConfig

@onready var spring: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _pitch: float = 0.0

func initialize(_player: Node3D) -> void:
	spring.spring_length = config.spring_length
	spring.margin = config.spring_margin
	spring.collision_mask = 1 # 只与世界层碰撞，杜绝被角色自身遮挡抖动
	camera.fov = config.fov
	position = Vector3(0.0, config.shoulder_offset.y, 0.0)
	spring.position = Vector3(config.shoulder_offset.x, 0.0, 0.0)
	_pitch = deg_to_rad(-12.0)
	spring.rotation.x = _pitch

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		rotation.y -= motion.relative.x * config.mouse_sensitivity
		_pitch = clampf(
			_pitch - motion.relative.y * config.mouse_sensitivity,
			deg_to_rad(config.pitch_min_deg),
			deg_to_rad(config.pitch_max_deg))
		spring.rotation.x = _pitch

## 相机水平前向（移动 / 攻击朝向基准）
func forward_flat() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func right_flat() -> Vector3:
	var right := global_transform.basis.x
	right.y = 0.0
	return right.normalized()
