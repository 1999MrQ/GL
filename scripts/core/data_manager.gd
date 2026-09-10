extends Node
## 静态配置加载器（技术方案 2.1 / 7）：
## 静态只读配置 = Resource（.tres），运行时状态与存档 = JSON（C4 修正）。
## 这里加载的一切 .tres 视为常量，禁止在运行时修改后写回。

const _CONFIG_PATHS: Dictionary = {
	"camera": "res://resources/config/camera_config.tres",
	"movement": "res://resources/config/movement_config.tres",
	"combat": "res://resources/config/combat_config.tres",
	"char_aiden": "res://resources/config/char_aiden.tres",
	"char_lisea": "res://resources/config/char_lisea.tres",
	"char_kaven": "res://resources/config/char_kaven.tres",
	"enemy_miner": "res://resources/config/enemy_miner_config.tres",
	"enemy_hound": "res://resources/config/enemy_hound_config.tres",
	"enemy_puppet": "res://resources/config/enemy_puppet_config.tres",
	"enemy_mote": "res://resources/config/enemy_mote_config.tres",
	"enemy_overseer": "res://resources/config/enemy_overseer_config.tres",
	"reactions": "res://resources/reactions/reaction_table.tres",
}

var _cache: Dictionary = {}

## 按注册名取配置（带缓存）；未注册或加载失败直接断言，配置缺失应尽早暴露。
func config(cfg_name: String) -> Resource:
	if _cache.has(cfg_name):
		return _cache[cfg_name]
	assert(_CONFIG_PATHS.has(cfg_name), "DataManager: 未注册的配置名 %s" % cfg_name)
	var res: Resource = load(_CONFIG_PATHS[cfg_name])
	assert(res != null, "DataManager: 配置加载失败 %s" % _CONFIG_PATHS[cfg_name])
	_cache[cfg_name] = res
	return res

func registered_paths() -> Dictionary:
	return _CONFIG_PATHS.duplicate()
