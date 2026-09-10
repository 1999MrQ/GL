class_name PartyInventory extends RefCounted
## 队伍级背包（最小版，策划案 §9.6/§8.1）：P2 扩展采集资源。
## 完整背包/物品/装备 UI 与存档映射是 P3 背包屏的范畴。

var dust: int = 0 # 炼金尘（质之炼成代价源，击杀掉落）
var iron: int = 0 # 铁矿（矿脉）
var herb: int = 0 # 药草
var dew: int = 0 # 水镜露

func add_dust(amount: int) -> void:
	dust += maxi(0, amount)

func can_take_dust(amount: int) -> bool:
	return dust >= amount

func take_dust(amount: int) -> bool:
	if not can_take_dust(amount):
		return false
	dust -= amount
	return true

## 采集资源入包（resource_id：&"ore" / &"herb" / &"dew"）
func add_resource(resource_id: StringName, amount: int) -> void:
	match resource_id:
		&"ore":
			iron += amount
		&"herb":
			herb += amount
		&"dew":
			dew += amount
		_:
			push_warning("PartyInventory: 未知资源 %s" % resource_id)
