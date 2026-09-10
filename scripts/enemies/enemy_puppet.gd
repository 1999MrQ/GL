class_name PuppetEnemy extends EnemyBase
## 锈蚀傀儡（策划案 §5.4：高防霸体、砸地 AOE）：
## 常驻霸体（免击退免硬直，破霸前）、金抗 +50%、砸地环形 AOE——教学目标：熔金破甲。

const SLAM_RADIUS := 2.6

func _ready() -> void:
	super()
	has_super_armor = true

## 砸地 AOE：以自身为圆心环形判定（替代矿工的近战点判）
func _strike() -> void:
	var cfg: CombatConfig = DataManager.config("combat")
	var origin := global_position + Vector3.UP * 0.5
	for target in Combat.melee_query(self, origin, SLAM_RADIUS, 2):
		var ctx := DamageContext.make(self, config.level, cfg.enemy_attack_damage * 1.3, 1.0)
		ctx.knockback_force = 6.0
		ctx.source_name = tr(config.display_name_key)
		Combat.resolve_attack(target, ctx)
	TransmuteRing.spawn(get_parent(), global_position, SLAM_RADIUS, Color(0.7, 0.55, 0.4))
