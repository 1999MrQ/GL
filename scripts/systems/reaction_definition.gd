class_name ReactionDefinition extends Resource
## 单条元素反应定义（策划案 5.3 / 9.4）。
## 反应表数据驱动：第二期补反应只加 .tres 数据，不改代码。

enum ReactionType { AMPLIFY, TRANSFORM }

@export var id: StringName = &""
@export var name_key: String = "" ## 本地化 key（data/loc/zh.csv）
## 组合顺序 = 施加顺序（策划案 5.3 规则 5）：first_element 先附着，second_element 后手触发
@export var first_element: StringName = &""
@export var second_element: StringName = &""
@export var reaction_type: ReactionType = ReactionType.AMPLIFY
## 增幅反应：触发伤害倍率（蒸汽爆发 1.5 / 白雾弥漫 1.25）
## 剧变反应：剧变伤害倍率（熔金 2.0 / 锈蚀 1.0 / 淬火脆化 0 纯效果）
@export var damage_mult: float = 1.0
## 反应消耗双方附着的 GU 量（可调参数，策划案 5.3 规则 4"按倍率扣除，残留保留"）
@export var aura_cost: float = 1.0
## 附加效果 id：&"slow"（白雾减速）/ &"armor_break"（熔金破甲）/ &"dot"（锈蚀 DoT）/ &"stagger_up"（淬火硬直）
@export var effect_id: StringName = &""
@export var effect_duration: float = 0.0
## 效果强度：slow=减速比例 / armor_break=减防比例 / dot=剧变每秒伤害系数 / stagger_up=硬直时间倍率
@export var effect_value: float = 0.0

## 查表 key："先手元素|后手元素"
func key() -> String:
	return String(first_element) + "|" + String(second_element)
