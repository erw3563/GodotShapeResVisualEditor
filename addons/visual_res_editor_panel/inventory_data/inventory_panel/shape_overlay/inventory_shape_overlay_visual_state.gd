class_name InventoryShapeOverlayVisualState
extends RefCounted
## 背包形状覆盖层视觉状态策略。
## 负责颜色决策与无效操作反馈状态机。

enum PreviewState {
	VALID,
	INVALID,
}

## 已放置物品边框颜色。
var placed_item_border_color: Color = Color(0.84, 0.88, 0.97, 1.0)
## 已放置物品填充颜色。
var placed_item_fill_color: Color = Color(0.64, 0.72, 0.9, 0.12)
## 预览可放置边框颜色。
var valid_border_color: Color = Color(0.37, 0.9, 0.53, 1.0)
## 预览不可放置边框颜色。
var invalid_border_color: Color = Color(1.0, 0.34, 0.34, 1.0)
## 预览可放置填充颜色。
var valid_fill_color: Color = Color(0.37, 0.9, 0.53, 0.2)
## 预览不可放置填充颜色。
var invalid_fill_color: Color = Color(1.0, 0.34, 0.34, 0.2)
## 无效操作反馈时边框短暂切换到的颜色。
var invalid_click_feedback_border_color: Color = Color(1.0, 0.95, 0.25, 1.0)
## 无效操作反馈时填充短暂切换到的颜色。
var invalid_click_feedback_fill_color: Color = Color(1.0, 0.95, 0.25, 0.25)

## 当前预览是否可放置。
var preview_state: PreviewState = PreviewState.VALID
## 是否正在播放无效操作反馈变色。
var is_invalid_feedback_active: bool = false
## 无效操作反馈的版本号，用于取消过期的定时器回调。
var invalid_feedback_version: int = 0
## 为 true 时反馈作用于预览框；为 false 时作用于 invalid_feedback_placed_item。
var invalid_feedback_is_preview: bool = false
## 无效操作反馈所针对的已放置物品；预览反馈时为 null。
var invalid_feedback_placed_item: ItemInstanceData

## 同步视觉状态配置。
func sync_config(
	target_placed_item_border_color: Color,
	target_placed_item_fill_color: Color,
	target_valid_border_color: Color,
	target_invalid_border_color: Color,
	target_valid_fill_color: Color,
	target_invalid_fill_color: Color,
	target_invalid_click_feedback_border_color: Color,
	target_invalid_click_feedback_fill_color: Color
) -> void:
	placed_item_border_color = target_placed_item_border_color
	placed_item_fill_color = target_placed_item_fill_color
	valid_border_color = target_valid_border_color
	invalid_border_color = target_invalid_border_color
	valid_fill_color = target_valid_fill_color
	invalid_fill_color = target_invalid_fill_color
	invalid_click_feedback_border_color = target_invalid_click_feedback_border_color
	invalid_click_feedback_fill_color = target_invalid_click_feedback_fill_color

## 设置预览状态。
func set_preview_state(is_valid: bool) -> void:
	preview_state = PreviewState.VALID if is_valid else PreviewState.INVALID

## 开始无效操作反馈并返回当前反馈版本号。
func start_invalid_feedback(item_instance_data: ItemInstanceData = null) -> int:
	invalid_feedback_version += 1
	invalid_feedback_is_preview = item_instance_data == null
	invalid_feedback_placed_item = item_instance_data
	is_invalid_feedback_active = true
	return invalid_feedback_version

## 判断反馈版本是否仍然有效。
func is_feedback_version_valid(target_feedback_version: int) -> bool:
	return target_feedback_version == invalid_feedback_version

## 重置无效操作反馈状态。
func clear_invalid_feedback_state() -> void:
	is_invalid_feedback_active = false
	invalid_feedback_is_preview = false
	invalid_feedback_placed_item = null

## 获取已放置物品边框颜色。
func get_placed_item_border_color(item_instance_data: ItemInstanceData) -> Color:
	if _is_placed_item_in_invalid_feedback(item_instance_data):
		return invalid_click_feedback_border_color
	return placed_item_border_color

## 获取已放置物品填充颜色。
func get_placed_item_fill_color(item_instance_data: ItemInstanceData) -> Color:
	if _is_placed_item_in_invalid_feedback(item_instance_data):
		return invalid_click_feedback_fill_color
	return placed_item_fill_color

## 获取预览边框颜色。
func get_preview_border_color() -> Color:
	if _is_preview_in_invalid_feedback():
		return invalid_click_feedback_border_color
	if preview_state == PreviewState.VALID:
		return valid_border_color
	return invalid_border_color

## 获取预览填充颜色。
func get_preview_fill_color() -> Color:
	if _is_preview_in_invalid_feedback():
		return invalid_click_feedback_fill_color
	if preview_state == PreviewState.VALID:
		return valid_fill_color
	return invalid_fill_color

## 判断指定已放置物品是否处于无效操作反馈中。
func _is_placed_item_in_invalid_feedback(item_instance_data: ItemInstanceData) -> bool:
	return is_invalid_feedback_active \
		and not invalid_feedback_is_preview \
		and item_instance_data == invalid_feedback_placed_item

## 判断预览框是否处于无效操作反馈中。
func _is_preview_in_invalid_feedback() -> bool:
	return is_invalid_feedback_active and invalid_feedback_is_preview
