@tool
extends Resource
class_name ItemData
## ItemData是物品的数据文件。它会记录物品长期不变的数据

const BASE_PART_TYPE := "Base"
const SHAPE_PART_TYPE := "Shape"

## 物品名称。
@export var item_name: String
## 物品图标。
@export var icon: Texture2D
## 物品最大可堆叠数量。
@export var max_num: int = 1
## 物品描述。
@export_multiline var item_description: String
## 物品形状。
@export var shape: Shape = Shape.new()
## 其它功能拼图（不包含基础信息与形状拼图）。
var _parts: Array[ItemPart] = []
@export var parts: Array[ItemPart]:
	get:
		return _parts
	set(value):
		_parts = _normalize_parts(value)

## 编辑器中非 @tool 的 Part 子资源为 placeholder，无法调用实例方法。
func _can_query_part_type(part: ItemPart) -> bool:
	if part == null:
		return false
	if !Engine.is_editor_hint():
		return true
	var part_script := part.get_script() as Script
	return part_script != null and part_script.is_tool()

## 获取拼图类型。无法读取时返回空字符串。
func _get_part_type(part: ItemPart) -> String:
	if !_can_query_part_type(part):
		return ""
	var part_script := part.get_script() as Script
	if part_script == null:
		return ""
	if !part_script.has_method("get_part_type"):
		return ""
	return part_script.call("get_part_type")

## 规范化拼图列表：过滤空值与基础/形状类型。
func _normalize_parts(parts_value: Array[ItemPart]) -> Array[ItemPart]:
	var normalized_parts: Array[ItemPart] = []
	for part in parts_value:
		if part == null:
			continue
		var part_type := _get_part_type(part)
		if part_type == BASE_PART_TYPE or part_type == SHAPE_PART_TYPE:
			continue
		normalized_parts.append(part)
	return normalized_parts

## 尝试添加数据
func try_add_part(item_part: ItemPart):
	if item_part == null:
		return
	var part_type := _get_part_type(item_part)
	if part_type == BASE_PART_TYPE or part_type == SHAPE_PART_TYPE:
		return
	if !_parts.has(item_part):
		_parts.append(item_part)

## 获取所有的拼图
func get_all_parts() -> Array[ItemPart]:
	_parts = _normalize_parts(_parts)
	return _parts.duplicate()

## 我们没有强制要求parts中每种Part只能有一个。但我们默认在需要一种且单个Part的时候取靠前的Part。
func get_type_part(type: String) -> ItemPart:
	_parts = _normalize_parts(_parts)
	var result_part: ItemPart
	for part in _parts:
		if type == _get_part_type(part):
			result_part = part
			break
	return result_part

## 获取所有的 type 类型的数据
func get_all_same_type_parts(type: String) -> Array[ItemPart]:
	_parts = _normalize_parts(_parts)
	var result_part: Array[ItemPart]
	for part in _parts:
		if type == _get_part_type(part):
			result_part.append(part)
	return result_part

## 是否有输入种类的拼图
func has_type_part(type: String) -> bool:
	_parts = _normalize_parts(_parts)
	var has_result := false
	for part in _parts:
		if type == _get_part_type(part):
			has_result = true
			break
	return has_result
