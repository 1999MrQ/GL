class_name DamageFormulas
## 伤害与成长公式（策划案 9.2 / 9.3）。
## 纯函数：输入纯数据输出纯结果，无副作用、不访问场景树——
## 可在 tests/ 与模拟器中批量校准（技术方案 4.3 / 10.2：改数值先跑测试再进游戏）。

## ============ 策划案 9.2 伤害公式 ============

## 防御减免 = min(0.7, DEF / (DEF + 200 + 10 × 攻击方等级))
static func defense_reduction(defense: float, attacker_level: int) -> float:
	return minf(0.7, defense / (defense + 200.0 + 10.0 * float(attacker_level)))

## 抗性系数 = 1 - 抗性%（抗性区间 [-20%, +50%]，负抗性即增伤）
static func resistance_factor(resistance: float) -> float:
	return 1.0 - resistance

## 单次面板伤害（不含暴击与反应系数；实际结算的暴击由 Combat 现场掷骰）。
## 防御减免以 (1 - 减免比例) 作为乘数（策划案 9.2 示例：25级 E = 43×2.2×0.86 ≈ 81）
static func hit_damage(atk: float, skill_mult: float, attacker_level: int,
		defense: float, resistance: float, reaction_mult: float = 1.0) -> float:
	return atk * skill_mult \
		* (1.0 - defense_reduction(defense, attacker_level)) \
		* resistance_factor(resistance) \
		* reaction_mult

## 期望伤害（含暴击期望 1 + 暴击率×暴击伤害，策划案 9.2 完整公式；供数值模拟与校表）
static func expected_damage(atk: float, skill_mult: float, attacker_level: int,
		defense: float, resistance: float,
		crit_rate: float, crit_damage: float, reaction_mult: float = 1.0) -> float:
	var crit_expectation := 1.0 + crit_rate * crit_damage
	return hit_damage(atk, skill_mult, attacker_level, defense, resistance, reaction_mult) \
		* crit_expectation

## 剧变反应固定伤害（策划案 9.2）：
## 剧变伤害 = (20 + 4 × 角色等级) × 反应倍率 × (1 + EM / (EM + 400))
static func transformative_damage(character_level: int, reaction_mult: float, element_mastery: float) -> float:
	return (20.0 + 4.0 * float(character_level)) \
		* reaction_mult \
		* (1.0 + element_mastery / (element_mastery + 400.0))

## ============ 策划案 9.3 成长曲线模板 ============

## 角色 HP = 基础HP × (1 + 0.045 × (等级-1))，每次突破额外 +8%
static func character_max_hp(base_hp: float, level: int, breakthrough_count: int = 0) -> float:
	return base_hp * (1.0 + 0.045 * float(level - 1)) * pow(1.08, float(breakthrough_count))

## 角色 ATK = 基础ATK × (1 + 0.04 × (等级-1))，每次突破额外 +6%
static func character_atk(base_atk: float, level: int, breakthrough_count: int = 0) -> float:
	return base_atk * (1.0 + 0.04 * float(level - 1)) * pow(1.06, float(breakthrough_count))

## 敌人 HP：小怪 = 22 × 等级^1.05；精英 ×6；BOSS ×20（tier_mult 传 6.0 / 20.0）
static func enemy_max_hp(level: int, tier_mult: float = 1.0) -> float:
	return 22.0 * pow(float(level), 1.05) * tier_mult
