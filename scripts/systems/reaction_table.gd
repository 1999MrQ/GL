class_name ReactionTable extends Resource
## 元素反应表（技术方案 4.2）：key = "先手元素|后手元素" → ReactionDefinition。
## 数据源：resources/reactions/reaction_table.tres（与策划案 5.3 第一期反应表一一对应）。

@export var reactions: Array = [] # Array[ReactionDefinition]

var _index: Dictionary = {}

func build_index() -> void:
	_index.clear()
	for entry in reactions:
		var rd := entry as ReactionDefinition
		if rd == null:
			continue
		_index[rd.key()] = rd

func find(first_element: StringName, second_element: StringName) -> ReactionDefinition:
	if _index.is_empty():
		build_index()
	return _index.get(String(first_element) + "|" + String(second_element))

func by_id(reaction_id: StringName) -> ReactionDefinition:
	if _index.is_empty():
		build_index()
	for entry in _index.values():
		if entry.id == reaction_id:
			return entry
	return null

func size() -> int:
	if _index.is_empty():
		build_index()
	return _index.size()
