class_name GroundField extends Node3D
## 持续型元素区域（策划案 §7.2 火域 / §7.3 Q 点燃地面）。
## 技术方案 §4.1：Area3D/持续判定用于火域类；本实现按固定节拍对区域内敌人
## 附着元素（1GU/2s）并造成百分比 ATK 元素伤害，走 Combat 统一管线。

const TICK_SEC := 2.0

var radius: float = 2.5
var duration: float = 4.0
var element: StringName = Elements.FIRE
var gu_per_tick: float = 1.0
var damage_mult_per_tick: float = 0.6
var attacker: Node = null
var attacker_level: int = 1
var attacker_atk: float = 0.0

var _elapsed: float = 0.0
var _tick_acc: float = TICK_SEC # 首跳立即

static func spawn(parent: Node, pos: Vector3, p_radius: float, p_duration: float,
		p_element: StringName, p_attacker: Node, p_atk: float,
		damage_mult_per_tick: float = 0.6, gu: float = 1.0) -> GroundField:
	var field := GroundField.new()
	field.radius = p_radius
	field.duration = p_duration
	field.element = p_element
	field.attacker = p_attacker
	field.attacker_level = p_attacker.level if p_attacker is PlayerCharacter else 1
	field.attacker_atk = p_atk
	field.damage_mult_per_tick = damage_mult_per_tick
	field.gu_per_tick = gu
	field.position = pos
	parent.add_child(field)
	# 占位视觉：贴地元素色圆盘（炼成阵 Shader 为技术方案 §6，P2 资产）
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = p_radius
	mesh.bottom_radius = p_radius
	mesh.height = 0.04
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Elements.color(p_element), 0.35)
	mesh.material = mat
	disc.mesh = mesh
	disc.position.y = 0.03
	field.add_child(disc)
	var tween := field.create_tween()
	tween.tween_property(disc, "transparency", 1.0, p_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return field

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick_acc += delta
	if _tick_acc >= TICK_SEC:
		_tick_acc -= TICK_SEC
		_tick()
	if _elapsed >= duration:
		queue_free()

## 一跳：区域内所有敌方目标 附着 + 伤害（与普攻同一结算管线）
func _tick() -> void:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.5)
	params.collision_mask = 4 # layer_3 = enemy_body
	params.collide_with_bodies = true
	var space := get_world_3d().direct_space_state
	for result in space.intersect_shape(params, 32):
		var target: Variant = result.get("collider")
		if target == null or not (target is Object) or not (target as Object).has_method("get_health"):
			continue
		var ctx := DamageContext.make(attacker, attacker_level, attacker_atk, damage_mult_per_tick)
		ctx.attacker_level = attacker_level
		ctx.with_element(element, gu_per_tick)
		Combat.resolve_attack(target, ctx)
