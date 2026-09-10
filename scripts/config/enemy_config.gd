class_name EnemyConfig extends Resource
## 敌人白模配置（策划案 5.4 / 9.2 敌人防御与抗性简表）。
## P0 首个敌人：蚀化矿工（教学对象：缓慢近战）。

@export var display_name_key: String = "ENEMY_MINER"
@export var level: int = 1
## 教学怪 HP 基准 ×1.5（策划案 9.3 示例校验：1 级 ≈ 33，三段普攻击杀）
@export var hp_tier_mult: float = 1.5
## DEF = 层级系数 × 等级（策划案 9.2：小怪 3×等级 / 傀儡精英 5×等级）
@export var def_level_mult: float = 3.0
## 元素抗性（策划案 9.2 敌人简表：水元素 水抗+30%/火抗-10%，傀儡 金抗+50%）
@export var resist_fire: float = 0.0
@export var resist_water: float = 0.0
@export var resist_metal: float = 0.0
## 霸体条上限（0 = 无霸体条；精英/傀儡使用，策划案 §5.2）
@export var poise_max: float = 0.0
@export var move_speed: float = 3.2
@export var aggro_radius: float = 12.0
@export var attack_range: float = 1.9
@export var attack_windup: float = 0.45
@export var attack_recover: float = 0.9
@export var attack_cooldown: float = 1.4
@export var attack_damage: float = 30.0
@export var knockback_resist: float = 0.2
@export var stagger_time: float = 0.35
