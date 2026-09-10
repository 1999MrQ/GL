class_name Elements
## 元素定义（策划案 5.3 / 术语表）：第一期 3 元素，第二期补齐至 6。
## 全项目引用此处常量，禁止散落字符串字面量。

const FIRE := &"fire"
const WATER := &"water"
const METAL := &"metal"

const ALL: Array[StringName] = [FIRE, WATER, METAL]

## 元素主题色（技术方案 6.3：特效按元素色重着色复用）
static func color(element: StringName) -> Color:
	match element:
		FIRE:
			return Color(1.0, 0.45, 0.15)
		WATER:
			return Color(0.25, 0.75, 1.0)
		METAL:
			return Color(0.92, 0.78, 0.35)
		_:
			return Color.WHITE

## 本地化 key（data/loc/zh.csv）
static func display_key(element: StringName) -> String:
	return "ELEMENT_" + String(element).to_upper()
