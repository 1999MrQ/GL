class_name TrainingDummy extends StaticBody3D
## 训练假人：无 AI 木桩，用于 P0 连段 / 反应手感验证。被打死后原地复活。

const RESPAWN_SEC := 3.0
const MAX_HP := 500.0

var health: HealthComponent
var aura: ElementAura
var status: StatusHolder
var flash: FlashOverlay

func _ready() -> void:
	health = HealthComponent.new()
	health.max_hp = MAX_HP
	health.died.connect(_on_died)
	add_child(health)

	aura = ElementAura.new()
	aura.setup(DataManager.config("reactions"))
	add_child(aura)

	status = StatusHolder.new()
	status.setup(health)
	add_child(status)

	flash = FlashOverlay.new()
	flash.setup(FlashOverlay.collect_meshes($VisualRoot), DataManager.config("combat").flash_duration)
	add_child(flash)

	# 附着可视化：身体元素染色 + 头顶光珠（玩测反馈 2026-09-10）
	AuraVisualizer.attach(self, $VisualRoot, aura)

func _physics_process(delta: float) -> void:
	status.tick(delta)

## Combat 目标接口
func get_health() -> HealthComponent:
	return health

func get_defense() -> float:
	return 0.0

func get_resistance(_element: StringName) -> float:
	return 0.0

func get_aura() -> ElementAura:
	return aura

func status_holder() -> StatusHolder:
	return status

func apply_hit_reaction(_result: Dictionary, _ctx: DamageContext) -> void:
	flash.flash()

func _on_died() -> void:
	set_deferred("collision_layer", 0)
	$VisualRoot.visible = false
	# 子节点 Timer 随宿主释放，避免场景切换后对已释放对象回调（审核 2026-09-10 #5）
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = RESPAWN_SEC
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		_respawn()
	)
	add_child(timer)
	timer.start()

func _respawn() -> void:
	if not is_inside_tree():
		return
	health.set_full()
	$VisualRoot.visible = true
	set_deferred("collision_layer", 4) # layer_3 = enemy_body
	flash.flash(0.6)
