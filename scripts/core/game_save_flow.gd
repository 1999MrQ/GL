class_name GameSaveFlow extends RefCounted
## 存档编排（技术方案 §7 数据分块）：收集 party / inventory / world 三块写入 SaveManager，
## 读档时回放。P2 第二轮范围（进度报告 §8 下一步）：
## - 野外采集点读档后刷新（不持久化）；洞窟一次性采集与宝箱持久化（策划案 §8.1）
## - 传送阵解锁表、队伍 HP/MP/能量与背包一并往返
## 入口：main.gd 的 F5/F9（完整存档 UI 与自动存档为 P3 系统整合）。

const SLOT := 0

## 命名与 SaveManager 对齐；避免与全局内置 load() 同名（类内裸调用会误解析）
static func save_game(tree: SceneTree) -> bool:
	return SaveManager.save_game(SLOT, collect(tree))

static func load_game(tree: SceneTree) -> bool:
	var data := SaveManager.load_game(SLOT)
	if data.is_empty():
		return false
	apply(tree, data)
	return true

## 汇总当前世界与队伍状态（技术方案 §7 存档结构）
static func collect(tree: SceneTree) -> Dictionary:
	var payload := {}
	var party := tree.get_first_node_in_group("party") as PartyManager
	if party != null:
		var party_data: Dictionary = party.to_save()
		payload["party"] = party_data["party"]
		payload["inventory"] = party_data["inventory"]
	var chests: Array[String] = []
	for node in tree.get_nodes_in_group("interactables"):
		if node is Chest and node.opened() and node.node_id != "":
			chests.append(node.node_id)
	payload["world"] = {
		"cave_gathered": GatherNode.taken_one_shot_ids.duplicate(),
		"chests": chests,
		"teleports": TeleportGate.unlocked_ids.duplicate(),
	}
	return payload

## 回放存档：队伍资源 → 洞窟采集/宝箱 → 传送阵解锁
static func apply(tree: SceneTree, data: Dictionary) -> void:
	var party := tree.get_first_node_in_group("party") as PartyManager
	if party != null:
		party.apply_save(data)
	var world: Dictionary = data.get("world", {})
	# 洞窟一次性采集：注册表恢复为存档值（节点采集中即销毁，注册表是唯一记录）
	GatherNode.taken_one_shot_ids.clear()
	for id in world.get("cave_gathered", []):
		GatherNode.taken_one_shot_ids.append(id)
	var chests: Array = world.get("chests", [])
	for node in tree.get_nodes_in_group("interactables"):
		if node is GatherNode and node.node_id in GatherNode.taken_one_shot_ids:
			node.consume_silent()
		elif node is Chest and node.node_id != "" and node.node_id in chests:
			node.consume_silent()
	# 传送阵解锁表（静态注册表，跨场景重载一致——复审 2026-09-11 已核）
	TeleportGate.unlocked_ids.clear()
	for id in world.get("teleports", []):
		TeleportGate.unlocked_ids.append(StringName(id)) # JSON 往返 String → StringName 显式转
	for node in tree.get_nodes_in_group("interactables"):
		if node is TeleportGate:
			node.refresh_visual()
