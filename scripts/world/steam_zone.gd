class_name SteamZone extends Node3D
## 蒸汽安全区（策划案 §5.4 BOSS 三阶段）：水元素技能打地板生成，
## 区内玩家免疫灼热地板伤害。HeatZone 结算时查询本组。

const GROUP := "steam_zones"

var radius: float = 3.0

func _ready() -> void:
	add_to_group(GROUP)

static func spawn(parent: Node, pos: Vector3, p_radius: float, duration: float) -> SteamZone:
	var zone := SteamZone.new()
	zone.radius = p_radius
	zone.position = pos + Vector3.UP * 0.05
	parent.add_child(zone)
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = p_radius
	mesh.bottom_radius = p_radius
	mesh.height = 0.04
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.95, 1.0, 0.4)
	mesh.material = mat
	disc.mesh = mesh
	disc.position.y = 0.06
	zone.add_child(disc)
	var tween := zone.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.1, duration)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	timer.timeout.connect(zone.queue_free)
	zone.add_child(timer)
	timer.start()
	return zone

static func covers(point: Vector3, tree: SceneTree) -> bool:
	for zone in tree.get_nodes_in_group(GROUP):
		var z := zone as Node3D
		if z != null and z.global_position.distance_to(point) <= (zone as SteamZone).radius:
			return true
	return false
