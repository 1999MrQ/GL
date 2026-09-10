extends Node
## 全局信号总线（技术方案 2.1）：跨系统解耦通信的唯一通道。
## 战斗 / 任务 / UI 事件一律经此广播，系统之间禁止直接引用。

## —— 战斗 —— ##
## 一次攻击结算完成（命中方发出，供反馈系统订阅）
signal hit_landed(target: Node, result: Dictionary)
signal enemy_damaged(enemy: Node, amount: float, is_crit: bool)
signal enemy_died(enemy: Node)
signal player_damaged(amount: float)
signal player_died
## 等价交换（策划案 §6）：R 激活失败（素材不足等）→ HUD 提示
signal equivalence_failed(element: StringName)
## 元素事件（策划案 5.3：附着 / 反应）
signal element_applied(target: Node, element: StringName, gu: float)
signal reaction_triggered(target: Node, reaction_id: StringName)

## —— 表现层请求 —— ##
## 伤害数字请求（世界坐标），由 PoolManager 池化的 Label3D 消费
signal damage_number_requested(world_pos: Vector3, amount: float, color: Color, is_crit: bool)

## —— 流程 —— ##
signal game_state_changed(new_state: int)
## P1 队伍切换预留（策划案 5.1：1/2/3 切换，1s 公共冷却）
signal party_switched(to_index: int)
