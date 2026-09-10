class_name TransmuteRing extends Node3D
## 炼成阵占位特效（技术方案 §6 的白模替身：程序化炼成阵 Shader 为 P2 资产）。
## 贴地元素色光环，快速扩张后淡出。

static func spawn(parent: Node, pos: Vector3, radius: float, color: Color) -> void:
	var ring := TransmuteRing.new()
	ring.position = pos + Vector3.UP * 0.06
	parent.add_child(ring)
	var mesh_instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.92
	mesh.outer_radius = radius
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.8)
	mesh.material = mat
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3.ONE * 0.3
	ring.add_child(mesh_instance)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tween.chain().tween_callback(ring.queue_free)
