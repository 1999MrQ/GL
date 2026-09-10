class_name HeatZone extends Node3D
## 灼热地板（策划案 §5.4 BOSS 三阶段：地板变为灼热金属）。
## 场地内的玩家每 0.5s 结算 2.5 伤害（5/s）；站在蒸汽安全区内免疫。

const GROUP := "heat_zones"
const TICK_SEC := 0.5
const DAMAGE_PER_SEC := 5.0

var radius: float = 15.0

var _acc := 0.0

static func spawn(parent: Node, pos: Vector3, p_radius: float) -> HeatZone:
	var zone := HeatZone.new()
	zone.radius = p_radius
	zone.position = pos + Vector3.UP * 0.04
	parent.add_child(zone)
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = p_radius
	mesh.bottom_radius = p_radius
	mesh.height = 0.04
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.35, 0.1, 0.4)
	mesh.material = mat
	disc.mesh = mesh
	disc.position.y = 0.05
	zone.add_child(disc)
	return zone

func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc < TICK_SEC:
		return
	_acc -= TICK_SEC
	var center := global_position
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead():
			continue
		var flat := player.global_position - center
		flat.y = 0.0
		if flat.length() <= radius and not SteamZone.covers(player.global_position, get_tree()):
			player.health.take_damage(DAMAGE_PER_SEC * TICK_SEC)
