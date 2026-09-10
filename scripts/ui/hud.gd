extends CanvasLayer
## P1 战斗 HUD（策划案 §10 屏清单中的 HUD 战斗件；完整 13 屏为 P3）：
## HP/MP/体力/能量 + E·Q 技能状态 + 队伍栏 + 炼金尘 + R 渐晕 + 反应提示。
## 文案全部走本地化 key（data/loc/zh.csv）。

@onready var hp_bar: ProgressBar = $Root/TopLeft/HPRow/HPBar
@onready var mp_bar: ProgressBar = $Root/TopLeft/MPRow/MPBar
@onready var stamina_bar: ProgressBar = $Root/TopLeft/StaminaRow/StaminaBar
@onready var energy_bar: ProgressBar = $Root/TopLeft/EnergyRow/EnergyBar
@onready var e_label: Label = $Root/TopLeft/SkillRow/ELabel
@onready var q_label: Label = $Root/TopLeft/SkillRow/QLabel
@onready var r_label: Label = $Root/TopLeft/SkillRow/RLabel
@onready var party_bar: VBoxContainer = $Root/PartyBar
@onready var dust_label: Label = $Root/PartyBar/DustLabel
@onready var reaction_label: Label = $Root/ReactionLabel
@onready var interact_hint: Label = $Root/InteractHint
@onready var hint_label: Label = $Root/HintLabel
@onready var law_label: Label = $Root/LawLabel

var _player: PlayerCharacter
var _party: PartyManager
var _reaction_timer := 0.0
var _member_slots: Array = [] # [{name, bar}]
var _failed_timer := 0.0

func _ready() -> void:
	EventBus.reaction_triggered.connect(_on_reaction_triggered)
	EventBus.equivalence_failed.connect(_on_equivalence_failed)

func _find_party() -> void:
	if _party != null and is_instance_valid(_party):
		return
	_party = get_tree().get_first_node_in_group("party") as PartyManager
	if _party != null and _member_slots.is_empty():
		_build_party_bar()

func _build_party_bar() -> void:
	for i in _party.members.size():
		var member: PlayerCharacter = _party.members[i]
		var row := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = tr(member.stats.display_name_key)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Elements.color(member.stats.element))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(240, 8)
		bar.max_value = 1.0
		bar.step = 0.001
		bar.value = 1.0
		bar.show_percentage = false
		row.add_child(name_label)
		row.add_child(bar)
		party_bar.add_child(row)
		_member_slots.append({"name": name_label, "bar": bar})

func _process(delta: float) -> void:
	_find_party()
	if _party != null and is_instance_valid(_party.members[_party.active_index]):
		_player = _party.members[_party.active_index]
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerCharacter
		if _player == null:
			return

	# 资源条
	hp_bar.value = _player.health.ratio()
	mp_bar.value = _player.runtime.mp / _player.runtime.max_mp
	stamina_bar.value = _player.stamina.ratio()
	energy_bar.value = _player.runtime.energy / CharacterRuntime.MAX_ENERGY

	# 技能状态
	if _player.runtime.e_cooldown_left > 0.0:
		e_label.text = "E %s %.1fs" % [tr(_player.stats.skill_e_name_key), _player.runtime.e_cooldown_left]
	else:
		e_label.text = "E %s 就绪" % tr(_player.stats.skill_e_name_key)
	if _player.runtime.can_cast_burst():
		q_label.text = "Q %s 就绪" % tr(_player.stats.skill_q_name_key)
	else:
		q_label.text = "Q %s 充能 %d%%" % [tr(_player.stats.skill_q_name_key), roundi(_player.runtime.energy)]
	r_label.text = "★ R 等价交换已激活" if _player.equivalence_active else ""

	# 队伍栏
	if _party != null:
		for i in _member_slots.size():
			var member: PlayerCharacter = _party.members[i]
			if not is_instance_valid(member):
				continue
			var slot: Dictionary = _member_slots[i]
			(slot["bar"] as ProgressBar).value = member.health.ratio()
			var is_active := i == _party.active_index
			var is_dead := member.health.is_dead()
			var alpha := 1.0 if is_active else (0.25 if is_dead else 0.55)
			(slot["name"] as Label).modulate = Color(1, 1, 1, alpha)
			(slot["bar"] as ProgressBar).modulate = Color(1, 1, 1, alpha)
			(slot["name"] as Label).text = ("▶ " if is_active else "") + tr(member.stats.display_name_key)
		dust_label.text = "%s × %d" % [tr("HUD_DUST"), _party.inventory.dust]

	# R 渐晕（技术方案 §9：屏幕边缘元素色）
	var vignette_on := _player.equivalence_active
	var color := Color(Elements.color(_player.stats.element), 0.3)
	for node_name in ["VignetteTop", "VignetteBottom", "VignetteLeft", "VignetteRight"]:
		var rect: ColorRect = $Root.get_node(node_name) as ColorRect
		rect.visible = vignette_on
		rect.color = color

	# 交互提示（P2：采集/宝箱/传送阵）
	var interactable := _player.current_interactable
	if interactable != null and interactable.has_method("prompt"):
		var text: String = interactable.call("prompt")
		interact_hint.visible = text != ""
		interact_hint.text = "[F] " + text if text != "" else ""
	else:
		interact_hint.visible = false

	# 反应提示与 R 激活失败提示
	if _reaction_timer > 0.0:
		_reaction_timer -= delta
		if _reaction_timer <= 0.0:
			reaction_label.visible = false
	if _failed_timer > 0.0:
		_failed_timer -= delta
		law_label.modulate = Color(1.6, 0.5, 0.5)
		if _failed_timer <= 0.0:
			law_label.modulate = Color(1, 1, 1)

func _on_reaction_triggered(_target: Node, reaction_id: StringName) -> void:
	var table: ReactionTable = DataManager.config("reactions")
	var rd := table.by_id(reaction_id)
	if rd == null:
		return
	reaction_label.text = tr(rd.name_key)
	reaction_label.visible = true
	_reaction_timer = 1.6

func _on_equivalence_failed(_element: StringName) -> void:
	_failed_timer = 0.6
