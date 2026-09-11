class_name PartyManager extends Node
## 队伍管理（技术方案 §3.2 / 策划案 §6.3）：3 角色常驻 + 即时切换。
## 规则：1s 公共冷却 / 位置对齐 / 资源不重置（CharacterRuntime）/ 后台 MP 2%/3s 恢复 /
## 后台角色不承担任何代价 / 非激活者关碰撞（技术方案 §3.2 与审核 R9）/ 切换入场 +10 能量。

signal active_changed(index: int)

const SWITCH_COOLDOWN := 1.0
const DEAD_REVIVE_SEC := 10.0
const PLAYER_LAYER := 2
const PLAYER_MASK := 5 # world + enemy_body
## 激活角色专用组：敌人索敌 / 灼热地板 / 调试面板只作用于当前操作角色。
## "player" 组含全部常驻成员，不能用于索敌（技术方案 §3.2：非激活者须从仇恨中移除）。
const ACTIVE_GROUP := "player_active"

const PLAYER_SCENE := preload("res://scenes/characters/player/player_character.tscn")
const INPUT_ACTIONS: Array[StringName] = [&"switch_1", &"switch_2", &"switch_3"]

var members: Array = [] # Array[PlayerCharacter]
var runtimes: Array = [] # Array[CharacterRuntime]
var active_index: int = 0
var inventory: PartyInventory = PartyInventory.new() # 队伍级炼金尘
var switch_cd: float = 0.0

var _revive_left: Array = [] # 每成员复活倒计时
var _spawn_position := Vector3.ZERO

func setup(spawn_position: Vector3, configs: Array) -> void:
	add_to_group("party")
	_spawn_position = spawn_position
	for i in configs.size():
		var cfg: CharacterConfig = configs[i] as CharacterConfig
		var member := PLAYER_SCENE.instantiate()
		member.position = spawn_position
		# 队伍资源在 add_child 之前注入（_ready 时可读）。
		# 注意 stats 必须显式覆盖——场景默认硬编码为艾登（审核 2026-09-10 P1：曾致三角色全为艾登）
		member.stats = cfg
		var rt := CharacterRuntime.new()
		member.bind_party(rt, inventory, self)
		add_child(member)
		_tint_member(member, cfg) # 白模外观差异化：身体向元素色染色
		members.append(member)
		runtimes.append(rt)
		_revive_left.append(0.0)
	_set_active(0, true)

## 每实例复制材质并按元素主题色染色（子资源默认共享，直接改会串色）
func _tint_member(member: PlayerCharacter, cfg: CharacterConfig) -> void:
	for entry in FlashOverlay.collect_meshes(member.visual_root):
		var mesh := entry as MeshInstance3D
		var src := mesh.get_active_material(0)
		if src is BaseMaterial3D:
			var dup := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			dup.albedo_color = dup.albedo_color.lerp(Elements.color(cfg.element), 0.45)
			mesh.set_surface_override_material(0, dup)

func _unhandled_input(event: InputEvent) -> void:
	for i in INPUT_ACTIONS.size():
		if event.is_action_pressed(INPUT_ACTIONS[i]):
			_request_switch(i)
			return

func _physics_process(delta: float) -> void:
	switch_cd = maxf(0.0, switch_cd - delta)
	for i in members.size():
		var member: PlayerCharacter = members[i]
		if not is_instance_valid(member):
			continue
		if i == active_index:
			member.runtime.tick_resources(delta) # 战斗/脱战 MP 恢复
			if member.health.is_dead():
				_handle_active_death(i)
		else:
			member.runtime.tick_reserve(delta) # 后台 MP 2%/3s（策划案 §6.3 第 3 条）
			if member.health.is_dead():
				_revive_left[i] -= delta
				if _revive_left[i] <= 0.0:
					member.revive_at(member.global_position)

func _request_switch(index: int) -> void:
	if index == active_index or switch_cd > 0.0:
		return
	if index >= members.size() or not is_instance_valid(members[index]):
		return
	if (members[index] as PlayerCharacter).health.is_dead():
		return # 不能切换到倒地成员
	_set_active(index, false)

## 切换 = 位置对齐 + 激活交接（策划案/技术方案 §3.2）。
## 无论初始还是切换，都统一"激活目标、禁用其余"——否则初始时其他成员
## 保持可见与碰撞（正是审核 R9 要防的问题，本轮集成测试曾抓住）。
func _set_active(index: int, initial: bool) -> void:
	var previous: PlayerCharacter = members[active_index] \
		if (not initial and active_index < members.size()) else null
	var pivot: Vector3 = (previous as PlayerCharacter).global_position \
		if previous != null else _spawn_position

	# 禁用除目标外的所有成员
	for j in members.size():
		if j == index:
			continue
		var other: PlayerCharacter = members[j]
		if not is_instance_valid(other):
			continue
		other.visible = false
		other.process_mode = Node.PROCESS_MODE_DISABLED
		other.collision_layer = 0
		other.collision_mask = 0
		other.camera_rig.camera.current = false
		other.remove_from_group(ACTIVE_GROUP) # 敌人 AI / 灼热地板只认激活者（技术方案 §3.2"从仇恨列表移除"）

	# 激活目标（位置对齐：出现在被切换者位置，策划案 §3.2）
	var member: PlayerCharacter = members[index]
	member.global_position = Vector3(pivot.x, member.global_position.y, pivot.z)
	member.visible = true
	member.process_mode = Node.PROCESS_MODE_INHERIT
	member.collision_layer = PLAYER_LAYER
	member.collision_mask = PLAYER_MASK
	member.add_to_group(ACTIVE_GROUP)
	# 资源不重置：HP 从 runtime 恢复（后台期间受伤/治疗都记录在 runtime）
	member.health.hp = clampf(member.runtime.hp, 1.0, member.runtime.max_hp)
	member.camera_rig.camera.current = true
	if not initial:
		member.runtime.gain_energy(10.0) # 策划案 §9.1：切换入场 +10 能量
	member.fsm.transition(&"idle", {})

	active_index = index
	if not initial:
		switch_cd = SWITCH_COOLDOWN
		EventBus.party_switched.emit(index)
	active_changed.emit(index)

func _handle_active_death(i: int) -> void:
	# 优先切到存活成员（战斗不中断）
	for j in members.size():
		if j != i and is_instance_valid(members[j]) and not (members[j] as PlayerCharacter).health.is_dead():
			_set_active(j, false)
			_start_revive_timer(i)
			return
	# 全灭：全员回出生点复活（白模简化；死亡/重生屏为 P3 清单）
	for j in members.size():
		var member: PlayerCharacter = members[j]
		member.process_mode = Node.PROCESS_MODE_INHERIT
		member.revive_at(_spawn_position)
	_revive_left[i] = 0.0
	_set_active(i, true)

func _start_revive_timer(i: int) -> void:
	_revive_left[i] = DEAD_REVIVE_SEC

# —— 存档（技术方案 §7：party / inventory 分块；P2 第二轮接入，编排见 GameSaveFlow）—— #

## 汇总队伍运行时与背包（HP/MP/能量随角色保存，策划案 §6.3-3）
func to_save() -> Dictionary:
	var party := {}
	for rt in runtimes:
		party[String(rt.character_id)] = {
			"hp": rt.hp,
			"mp": rt.mp,
			"energy": rt.energy,
		}
	return {
		"party": party,
		"inventory": {
			"dust": inventory.dust,
			"iron": inventory.iron,
			"herb": inventory.herb,
			"dew": inventory.dew,
		},
	}

## 回放存档：runtime 是权威存储，回写后同步激活成员的组件视图
func apply_save(data: Dictionary) -> void:
	var party: Dictionary = data.get("party", {})
	for rt in runtimes:
		var d: Dictionary = party.get(String(rt.character_id), {})
		if d.is_empty():
			continue
		rt.hp = clampf(float(d.get("hp", rt.hp)), 1.0, rt.max_hp)
		rt.mp = clampf(float(d.get("mp", rt.mp)), 0.0, rt.max_mp)
		rt.energy = clampf(float(d.get("energy", rt.energy)), 0.0, CharacterRuntime.MAX_ENERGY)
	var inv: Dictionary = data.get("inventory", {})
	inventory.dust = int(inv.get("dust", inventory.dust))
	inventory.iron = int(inv.get("iron", inventory.iron))
	inventory.herb = int(inv.get("herb", inventory.herb))
	inventory.dew = int(inv.get("dew", inventory.dew))
	if active_index < members.size() and is_instance_valid(members[active_index]):
		var active: PlayerCharacter = members[active_index]
		active.health.hp = clampf(active.runtime.hp, 1.0, active.runtime.max_hp)
