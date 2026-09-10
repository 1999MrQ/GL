extends Node
## JSON 存档读写（技术方案 7）：schema_version 自 1 起，预留版本迁移。
## 文件格式：首行 = 校验和（正文文本 hash），其余 = JSON 正文——
## 满足"存档校验和防手改（单机轻度防呆）"（技术方案 §7；审核 2026-09-10 #7）。
## P0 仅提供读写骨架；party / world 的完整存档映射在 P3 系统整合接入。

const SAVE_DIR := "user://saves"
const SCHEMA_VERSION := 1

func save_game(slot: int, data: Dictionary) -> bool:
	var payload: Dictionary = data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 存档写入失败 slot=%d" % slot)
		return false
	var json := JSON.stringify(payload, "\t")
	file.store_string(str(json.hash()) + "\n" + json)
	file.close()
	return true

func load_game(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var sep := text.find("\n")
	if sep < 0:
		push_warning("SaveManager: 存档格式无效（缺校验和）slot=%d" % slot)
		return {}
	var checksum := int(text.substr(0, sep))
	var json := text.substr(sep + 1)
	if checksum != json.hash():
		push_warning("SaveManager: 校验和不匹配（文件被手改或损坏）slot=%d" % slot)
		return {}
	var parsed: Variant = JSON.parse_string(json)
	if parsed is Dictionary and int(parsed.get("schema_version", 0)) <= SCHEMA_VERSION:
		return parsed
	push_warning("SaveManager: 存档不可读或版本过新 slot=%d" % slot)
	return {}

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]
