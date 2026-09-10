class_name StateMachine extends RefCounted
## 轻量有限状态机（技术方案 3.1：GDScript FSM）。
## P1 接入 AnimationTree 后，在状态 enter/exit 内追加动画转移调用即可。

signal state_changed(from: StringName, to: StringName)

var agent: Node
var states: Dictionary = {} # StringName -> StateBase
var current_id: StringName = &""
var current: StateBase = null

func _init(p_agent: Node, p_states: Dictionary, p_initial: StringName) -> void:
	agent = p_agent
	states = p_states
	for id in states:
		states[id].sm = self
	current = states[p_initial]
	current_id = p_initial
	current.enter({})

## 同状态重入 = exit → enter(msg)，用于连段换段（attack → attack 第二段）
func transition(to: StringName, msg: Dictionary = {}) -> void:
	var next: StateBase = states.get(to)
	if next == null:
		push_warning("StateMachine: 未知状态 %s" % to)
		return
	if current != null:
		current.exit()
	var from := current_id
	current = next
	current_id = to
	current.enter(msg)
	state_changed.emit(from, to)

func physics_process(delta: float) -> void:
	if current != null:
		current.physics_update(delta)

func process(delta: float) -> void:
	if current != null:
		current.update(delta)
