class_name CharacterConfig extends Resource
## 角色静态配置（策划案 §7 角色设计 / §9.2 技能倍率表）：基础属性 + 普攻风格 + E/Q 技能参数。
## 三角色各一份 .tres；数值均为策划案口径，白模±10% 微调项标注在 tres 内。

enum AttackStyle { MELEE, RANGED }
enum EquivalenceType { BLOOD, WISDOM, MATTER }

@export var display_name_key: String = "CHAR_AIDEN"
@export var element: StringName = Elements.METAL
@export var attack_style: AttackStyle = AttackStyle.MELEE
## 等价交换倾向（策划案 §6.2：代价类型与角色一一绑定）
@export var equivalence_type: EquivalenceType = EquivalenceType.BLOOD

## —— 基础属性（策划案 §9.1/9.3）—— ##
@export var base_hp: float = 1100.0
@export var base_atk: float = 22.0
@export var level: int = 1
@export var crit_rate: float = 0.05
@export var crit_damage: float = 0.5
@export var element_mastery: float = 0.0

## —— 普攻（三段；第三段附 1GU 本角色元素）—— ##
@export var attack_range: float = 1.1
@export var attack_style_ranged_distance: float = 14.0

## —— 炼成技 E（带冷却，策划案 §5.1）—— ##
## 形态：&"line" 直线 / &"toss_field" 投掷落地火域 / &"heal_ring" 环形治疗
@export var skill_e_shape: StringName = &"line"
@export var skill_e_name_key: String = "SKILL_E_AIDEN"
@export var skill_e_cooldown: float = 6.0
@export var skill_e_mult: float = 2.2
@export var skill_e_gu: float = 2.0
@export var skill_e_range: float = 6.0
@export var skill_e_poise_damage: float = 20.0
@export var skill_e_field_duration: float = 4.0 # toss_field：火域持续
@export var skill_e_heal_ratio: float = 0.12 # heal_ring：全队回复最大HP比例（随EM成长，白模）

## —— 炼成爆发 Q（能量 100，策划案 §6.3/§9.1）—— ##
## 形态：&"burst" 自身环绕 / &"cone" 扇形 / &"freeze_burst" 冻结爆发
@export var skill_q_shape: StringName = &"burst"
@export var skill_q_name_key: String = "SKILL_Q_AIDEN"
@export var skill_q_mult: float = 4.2
@export var skill_q_gu: float = 4.0
@export var skill_q_range: float = 3.5
@export var skill_q_poise_damage: float = 40.0
@export var skill_q_self_armor: float = 5.0 # burst：自身霸体秒数（艾登）
@export var skill_q_field_duration: float = 4.0 # cone：点燃地面
@export var skill_q_freeze: float = 2.0 # freeze_burst：冻结秒数（卡文）
