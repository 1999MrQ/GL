class_name PartyInventory extends RefCounted
## 队伍级背包（最小版，策划案 §9.6）：P1 仅承载炼金尘（质之炼成的代价来源）。
## 击杀掉落 1-3 尘；完整背包/物品/装备是 P3 背包屏与存档的范畴。

var dust: int = 0

func add_dust(amount: int) -> void:
	dust += maxi(0, amount)

func can_take_dust(amount: int) -> bool:
	return dust >= amount

func take_dust(amount: int) -> bool:
	if not can_take_dust(amount):
		return false
	dust -= amount
	return true
