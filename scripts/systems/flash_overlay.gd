class_name FlashOverlay extends Node
## 受击闪白（P0 验收项之一）：对目标的所有 MeshInstance3D 挂 material_overlay，
## 用一层白色/元素色透明材质做快速淡出，不污染原材质。

var _mat: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _duration: float = 0.15
var _time_left: float = 0.0
var _strength: float = 0.85

## meshes: 任意含 MeshInstance3D 的数组（用 collect_meshes 采集）
func setup(meshes: Array, duration: float = 0.15) -> void:
	_duration = duration
	for entry in meshes:
		if entry is MeshInstance3D:
			_meshes.append(entry)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.albedo_color = Color(1, 1, 1, 0)
	for mesh in _meshes:
		mesh.material_overlay = _mat

func flash(strength: float = 0.85, color: Color = Color(1, 1, 1)) -> void:
	_strength = strength
	_time_left = _duration
	color.a = 0.0
	_mat.albedo_color = color

func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = maxf(0.0, _time_left - delta)
	var fade := _time_left / _duration if _duration > 0.0 else 0.0
	_mat.albedo_color.a = _strength * fade

## 采集 root 子树内全部 MeshInstance3D
static func collect_meshes(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			out.append(node)
		stack.append_array(node.get_children())
	return out
