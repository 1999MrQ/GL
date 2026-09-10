class_name Projectile extends Area3D
## 直线投射物（游荡水元素的水弹，技术方案 §4.1：投射物池化）。
## 命中玩家角色 / 超时 / 碰世界即归还池。

const POOL_ID := &"water_bolt"
const SPEED := 9.0
const LIFETIME := 3.0

var direction := Vector3.FORWARD
var damage: float = 15.0
var shooter: Node = null

var _life_left: float = LIFETIME

func launch(from: Vector3, dir: Vector3, p_damage: float, p_shooter: Node) -> void:
	global_position = from
	direction = dir.normalized()
	damage = p_damage
	shooter = p_shooter
	_life_left = LIFETIME
	visible = true
	set_deferred("monitoring", true)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_despawn()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("get_health"):
		var ctx := DamageContext.make(shooter, 2, damage, 1.0)
		ctx.source_name = "水弹"
		ctx.knockback_force = 3.0
		Combat.resolve_attack(body, ctx)
	_despawn()

func _despawn() -> void:
	set_deferred("monitoring", false)
	PoolManager.despawn(POOL_ID, self)
