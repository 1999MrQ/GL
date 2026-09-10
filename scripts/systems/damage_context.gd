class_name DamageContext extends RefCounted
## 一次伤害结算的全部输入（技术方案 4.3：DamageContext 注入，纯数据无行为）。

var attacker: Node = null
var attacker_level: int = 1
var atk: float = 0.0
var skill_mult: float = 1.0
## 元素与附着量（策划案 5.3：普攻第三段 1GU / 炼成技 2GU / 爆发 4GU）；物理攻击留空
var element: StringName = &""
var aura_gu: float = 0.0
var crit_rate: float = 0.05
var crit_damage: float = 0.5
var element_mastery: float = 0.0
## 等价交换强化倍率（策划案 §6：血祭伤害乘区，P1 EquivalenceComponent 注入）
var equivalence_mult: float = 1.0
## P1 新增乘区：吸血比例（血祭 0.1）/ 反应效果时长乘区（质祭 ×2）/ 削霸量
var lifesteal: float = 0.0
var effect_duration_mult: float = 1.0
var poise_damage: float = 0.0
var knockback_force: float = 0.0
## 来源描述（调试与日志用，如 "艾登·普攻3"）
var source_name: String = ""

static func make(p_attacker: Node, p_level: int, p_atk: float, p_skill_mult: float) -> DamageContext:
	var ctx := DamageContext.new()
	ctx.attacker = p_attacker
	ctx.attacker_level = p_level
	ctx.atk = p_atk
	ctx.skill_mult = p_skill_mult
	return ctx

func with_element(p_element: StringName, p_gu: float) -> DamageContext:
	element = p_element
	aura_gu = p_gu
	return self
