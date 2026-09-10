class_name CameraConfig extends Resource
## 相机手感参数（技术方案 3.1：调参集中配置化，P0 全部时间给手感）。

@export var mouse_sensitivity: float = 0.0028
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 40.0
@export var spring_length: float = 4.5
@export var spring_margin: float = 0.25
## 肩后视角：x 越肩偏移 / y 头部高度
@export var shoulder_offset: Vector3 = Vector3(0.45, 1.55, 0.0)
@export var fov: float = 60.0
