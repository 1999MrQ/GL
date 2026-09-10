class_name AuraVisualizer extends Node3D
## 元素附着可视化（白模阶段呈现层，2026-09-10 玩测反馈补齐）：
## 1. 宿主身体材质向附着元素主题色染色的强度随剩余 GU 变化
## 2. 头顶元素色光珠，随 GU 脉动，无附着时隐藏
## 染色用每实例复制的材质（surface override），不影响 FlashOverlay 的 material_overlay 通道。

var _aura: ElementAura
var _meshes: Array[MeshInstance3D] = []
var _orig_colors: Array[Color] = []
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _clock := 0.0

## 工厂：host 挂本节点，读取 aura 驱动 visual_root 的网格染色
static func attach(host: Node3D, visual_root: Node3D, aura: ElementAura) -> void:
	var viz := AuraVisualizer.new()
	viz.name = "AuraVisualizer"
	host.add_child(viz)
	viz._setup(visual_root, aura)

func _setup(visual_root: Node3D, aura: ElementAura) -> void:
	_aura = aura
	for entry in FlashOverlay.collect_meshes(visual_root):
		var mesh := entry as MeshInstance3D
		var src := mesh.get_active_material(0)
		if src is BaseMaterial3D:
			var dup := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			mesh.set_surface_override_material(0, dup)
			_meshes.append(mesh)
			_orig_colors.append(dup.albedo_color)
	_orb = MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.09
	orb_mesh.height = 0.18
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mesh.material = _orb_mat
	_orb.mesh = orb_mesh
	_orb.position = Vector3(0, 1.9, 0)
	_orb.visible = false
	add_child(_orb)

func _process(delta: float) -> void:
	_clock += delta
	# 宿主死亡后停止表现（死亡下沉时光珠不该悬在原地）
	var host := get_parent()
	if host != null and host.has_method("get_health"):
		var health: HealthComponent = host.call("get_health")
		if health == null or health.is_dead():
			_restore()
			return
	# 取最强附着元素
	var strongest := &""
	var best_gu := 0.0
	if _aura != null:
		for element in _aura.aura_elements():
			var gu := _aura.gu(element)
			if gu > best_gu:
				best_gu = gu
				strongest = element
	if strongest == &"":
		_restore()
		return
	var color := Elements.color(strongest)
	var strength := minf(0.65, 0.35 * best_gu)
	for i in _meshes.size():
		var mat := _meshes[i].get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = _orig_colors[i].lerp(color, strength)
	_orb.visible = true
	_orb_mat.albedo_color = color
	var pulse := 1.0 + 0.18 * sin(_clock * 6.0)
	_orb.scale = Vector3.ONE * pulse * clampf(0.5 + best_gu * 0.25, 0.5, 1.5)

func _restore() -> void:
	for i in _meshes.size():
		var mat := _meshes[i].get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = _orig_colors[i]
	_orb.visible = false
