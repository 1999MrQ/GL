class_name Chest extends Interactable
## 宝箱（策划案 §8.1：不刷新）：F 开启，给炼金尘与素材（掉落表 §9.6 白模版）。

var _opened := false
var _body: MeshInstance3D

func _ready() -> void:
	super()
	_body = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.55, 0.25)
	mesh.material = mat
	_body.mesh = mesh
	_body.position.y = 0.3
	add_child(_body)

func interact(player: PlayerCharacter) -> void:
	if _opened:
		return
	_opened = true
	remove_from_group("interactables")
	if player.inventory != null:
		player.inventory.add_dust(randi_range(10, 20))
		player.inventory.add_resource(&"ore", 2)
	# 白模反馈：箱体变亮绿
	var mat := (_body.mesh as BoxMesh).material as StandardMaterial3D
	mat.albedo_color = Color(0.5, 0.9, 0.5)
	TransmuteRing.spawn(get_parent(), global_position, 0.8, Color(1, 0.9, 0.4))

func prompt() -> String:
	return "" if _opened else tr("INTERACT_CHEST")
