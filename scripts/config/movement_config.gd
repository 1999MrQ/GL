class_name MovementConfig extends Resource
## 角色控制器手感参数（技术方案 3.1：重力自实现 + 手感三件套）。
## 数值均为白模初值，P0 手感打磨期运行时热调后回写此处。

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.5
@export var accel: float = 40.0
@export var decel: float = 50.0
@export var air_control: float = 0.35
@export var jump_velocity: float = 8.5
@export var gravity: float = 22.0
@export var max_fall_speed: float = 40.0
## 手感三件套：土狼时间 / 跳跃输入缓冲（技术方案 3.1）
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.15
@export var rotate_speed: float = 12.0
