class_name TeleportGate extends Interactable
## 传送炼成阵（策划案 §8.1 ×3）：首次 F 解锁，再次 F 传送到下一个已解锁门（按 id 环序）。

static var unlocked_ids: Array[StringName] = [] ## 运行时状态；存档映射 P3 接入

@export var gate_id: StringName = &"gate_1"

var _ring: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	super()
	_ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0.4, 0.7, 1.0, 0.35) # 未解锁：暗淡
	mesh.material = _mat
	_ring.mesh = mesh
	_ring.position.y = 0.06
	add_child(_ring)
	if gate_id in unlocked_ids:
		_mat.albedo_color = Color(0.5, 1.0, 1.0, 0.7)

func is_unlocked() -> bool:
	return gate_id in unlocked_ids

func interact(player: PlayerCharacter) -> void:
	if not is_unlocked():
		unlocked_ids.append(gate_id)
		_mat.albedo_color = Color(0.5, 1.0, 1.0, 0.7)
		TransmuteRing.spawn(get_parent(), global_position, 1.4, Color(0.5, 1.0, 1.0))
		return
	# 已解锁 → 传送到下一个已解锁门（环序，跳过自己）
	var targets: Array = []
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is TeleportGate and node != self \
				and (node as TeleportGate).is_unlocked():
			targets.append(node)
	if targets.is_empty():
		return
	targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return String(a.gate_id) < String(b.gate_id))
	var idx := targets.find(self) if targets.has(self) else -1
	var destination := targets[0] as TeleportGate
	TransmuteRing.spawn(get_parent(), global_position, 1.4, Color(0.5, 1.0, 1.0))
	player.global_position = destination.global_position + Vector3.UP * 0.5
	player.horizontal_velocity = Vector3.ZERO
	player.vertical_velocity = 0.0
	TransmuteRing.spawn(destination.get_parent(), destination.global_position, 1.4, Color(0.5, 1.0, 1.0))

func prompt() -> String:
	return tr("INTERACT_UNLOCK") if not is_unlocked() else tr("INTERACT_TELEPORT")
