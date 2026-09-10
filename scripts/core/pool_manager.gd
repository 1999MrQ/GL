extends Node
## 通用节点池（技术方案 2.1）：投射物 / 命中特效 / 伤害数字等高频节点复用。
## 用法：register_pool(&"damage_number", scene) → spawn() → 用完 despawn()。

var _pools: Dictionary = {} # StringName -> { "scene": PackedScene, "free": Array[Node] }

func register_pool(pool_id: StringName, scene: PackedScene, initial_size: int = 0) -> void:
	if _pools.has(pool_id):
		return
	var free_list: Array[Node] = []
	_pools[pool_id] = {"scene": scene, "free": free_list}
	for i in initial_size:
		free_list.append(_instantiate(pool_id))

## 从池中取节点（未挂树），调用方负责 add_child 与初始化。
## 池内可能残留已被释放的节点（PoolManager 是 Autoload，寿命长于场景——
## 场景整体释放后池会持有悬空引用），取用时剔除失效节点（审核 2026-09-10 #4）。
func spawn(pool_id: StringName) -> Node:
	if not _pools.has(pool_id):
		push_warning("PoolManager: 未注册的池 %s" % pool_id)
		return null
	var free_list: Array = _pools[pool_id]["free"]
	while not free_list.is_empty():
		var node: Variant = free_list.pop_back() # 无类型中转；对已释放实例只能用 is_instance_valid 探测
		if is_instance_valid(node):
			return node
	return _instantiate(pool_id)

## 归还节点：自动脱离场景树并回池。
func despawn(pool_id: StringName, node: Node) -> void:
	if node == null:
		return
	if not _pools.has(pool_id):
		node.queue_free()
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	_pools[pool_id]["free"].append(node)
func _instantiate(pool_id: StringName) -> Node:
	return (_pools[pool_id]["scene"] as PackedScene).instantiate()
