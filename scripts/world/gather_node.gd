class_name GatherNode extends Interactable
## 采集点（策划案 §8.1）：矿脉/药草/水镜露，F 采集入队包。
## 刷新规则（策划案 §8.1：野外采集点重新读档后刷新）——存档映射 P3 接入，白模一次性。

const TYPES := {
	&"ore": {"name_key": "GATHER_ORE", "field": "iron", "amount": 2, "color": Color(0.55, 0.6, 0.68)},
	&"herb": {"name_key": "GATHER_HERB", "field": "herb", "amount": 2, "color": Color(0.4, 0.75, 0.4)},
	&"dew": {"name_key": "GATHER_DEW", "field": "dew", "amount": 1, "color": Color(0.45, 0.8, 0.95)},
}

@export var resource_id: StringName = &"ore"
@export var node_id := "" ## 存档稳定 ID（区域布设方分配；空 = 不入存档）
@export var one_shot := false ## 洞窟内采集：一次性，读档不刷新（策划案 §8.1）

## 洞窟一次性采集的已采记录（静态注册表）。采集中节点即销毁，
## 存活节点无法回溯已采状态——注册表是唯一记录，GameSaveFlow 读写。
static var taken_one_shot_ids: Array[String] = []

var _taken := false
var _mesh: MeshInstance3D

func _ready() -> void:
	super()
	var info: Dictionary = TYPES[resource_id]
	_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = info["color"]
	mesh.material = mat
	_mesh.mesh = mesh
	_mesh.position.y = 0.4
	add_child(_mesh)

func interact(player: PlayerCharacter) -> void:
	if _taken:
		return
	_taken = true
	if one_shot and node_id != "":
		taken_one_shot_ids.append(node_id) # 洞窟一次性：读档后不刷新（策划案 §8.1）
	var info: Dictionary = TYPES[resource_id]
	var inventory: PartyInventory = player.inventory
	if inventory != null:
		inventory.add_resource(resource_id, info["amount"])
	remove_from_group("interactables")
	# 采集反馈：缩小消失
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", Vector3.ONE * 0.05, 0.25)
	tween.tween_callback(queue_free)

func taken() -> bool:
	return _taken

## 读档恢复：静默置为已采（不给资源、不播反馈）
func consume_silent() -> void:
	if _taken:
		return
	_taken = true
	remove_from_group("interactables")
	queue_free()

func prompt() -> String:
	if _taken:
		return ""
	var info: Dictionary = TYPES[resource_id]
	return "%s %s" % [tr("INTERACT_GATHER"), tr(info["name_key"])]
