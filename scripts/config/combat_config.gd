class_name CombatConfig extends Resource
## P0 白模打击感参数（策划案 P0 验收：命中反馈明确——顿帧/闪白/击退）。

@export var hitstop_light_duration: float = 0.05
@export var hitstop_light_scale: float = 0.1
@export var hitstop_heavy_duration: float = 0.09
@export var hitstop_heavy_scale: float = 0.05
@export var flash_duration: float = 0.15
@export var knockback_light: float = 3.0
@export var knockback_heavy: float = 7.0
@export var attack_range: float = 1.1
## 敌人白模攻击伤害（策划案未定敌人 ATK，P0 取 30：约 36 次击杀 1100 HP 玩家）
@export var enemy_attack_damage: float = 30.0
