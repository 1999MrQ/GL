class_name ClimbHold extends StaticBody3D
## 临时攀爬抓握点（技术方案 §3.3）：金元素技能命中蚀晶壁生成，60s 超时消失。
## 生成后即普通 world 层碰撞体——攀爬入口的墙面探测命中它即视为可攀表面
## （不在 erosion_walls 组内，故不受"徒手不可攀"判定影响）。

const GROUP := "climb_holds"
const LIFETIME := 60.0
const SIZE := Vector3(0.55, 0.9, 0.3)

static func spawn(parent: Node, pos: Vector3, wall_normal: Vector3) -> ClimbHold:
	var hold := ClimbHold.new()
	hold.collision_layer = 1 # world
	hold.collision_mask = 0
	hold.position = pos + wall_normal * 0.18
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = SIZE
	col.shape = shape
	hold.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SIZE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Elements.color(Elements.METAL)
	box.material = mat
	mesh.mesh = box
	hold.add_child(mesh)
	parent.add_child(hold)
	# 子节点 Timer 随宿主释放，避免场景切换后悬挂回调（审核 2026-09-10 #5 约定）
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = LIFETIME
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		hold.queue_free()
	)
	hold.add_child(timer)
	timer.start()
	return hold

func _ready() -> void:
	add_to_group(GROUP)
