class_name ErosionWall extends StaticBody3D
## 蚀晶壁（策划案 §8.2 / 技术方案 §3.3）：
## 陡峭的蚀晶化表面，徒手不可攀（ClimbState.is_blocked 按本组判定）；
## 金元素技能命中后生成临时抓握点（ClimbHold，60s 消失）方可攀爬——
## "炼金术 × 探索"的结合点（策划案第一期亮点）。

const GROUP := "erosion_walls"

func _ready() -> void:
	add_to_group(GROUP)
