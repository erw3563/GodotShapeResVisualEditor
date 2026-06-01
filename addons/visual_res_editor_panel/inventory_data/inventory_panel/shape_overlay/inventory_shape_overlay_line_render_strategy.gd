class_name InventoryShapeOverlayLineRenderStrategy
extends RefCounted
## 背包形状覆盖层线条渲染策略。
## 负责 draw 回退模式下的填充与边框线条绘制。

## 网格面板（用于格子坐标转像素坐标）。
var inventory_grid_panel: InventoryGridPanel
## 回退边框线宽。
var border_width: float = 3.0
## 已放置物品的 draw 回退数据。
var placed_draw_shapes: Array[Dictionary] = []
## 预览边框的 draw 回退数据。
var preview_draw_shapes: Array[Dictionary] = []

## 同步渲染策略配置。
func sync_config(target_inventory_grid_panel: InventoryGridPanel, target_border_width: float) -> void:
	inventory_grid_panel = target_inventory_grid_panel
	border_width = target_border_width

## 追加一组 draw 回退绘制数据。
func build_shape_to_container(
	target_cells: Array[Vector2i],
	border_color: Color,
	fill_color: Color,
	is_preview_shape: bool
) -> void:
	var shape_data := {
		"cells": target_cells.duplicate(),
		"border_color": border_color,
		"fill_color": fill_color
	}
	if is_preview_shape:
		preview_draw_shapes.append(shape_data)
	else:
		placed_draw_shapes.append(shape_data)

## 清理指定分组的回退绘制数据。
## is_preview_shape 为 true 时清理预览数据，否则清理已放置数据。
func clear_shape_data(is_preview_shape: bool) -> void:
	if is_preview_shape:
		preview_draw_shapes.clear()
	else:
		placed_draw_shapes.clear()

## 绘制当前缓存的回退数据。
func draw_shapes(target_control: Control) -> void:
	_draw_shape_data_list(target_control, placed_draw_shapes)
	_draw_shape_data_list(target_control, preview_draw_shapes)

## 使用 draw 回退绘制多组形状边框。
func _draw_shape_data_list(target_control: Control, shape_data_list: Array[Dictionary]) -> void:
	for shape_data in shape_data_list:
		var target_cells := shape_data.get("cells", []) as Array[Vector2i]
		if target_cells.is_empty():
			continue
		var border_color := shape_data.get("border_color", Color.WHITE) as Color
		var fill_color := shape_data.get("fill_color", Color(1.0, 1.0, 1.0, 0.15)) as Color
		_draw_single_shape_fallback(target_control, target_cells, border_color, fill_color)

## 使用 draw 回退绘制单个形状。
func _draw_single_shape_fallback(target_control: Control, target_cells: Array[Vector2i], border_color: Color, fill_color: Color) -> void:
	if !is_instance_valid(inventory_grid_panel):
		return
	var cell_lookup: Dictionary = {}
	for target_cell in target_cells:
		cell_lookup[target_cell] = true

	for target_cell in target_cells:
		var cell_position := inventory_grid_panel.get_cell_local_position(target_cell)
		var cell_rect := Rect2(cell_position, inventory_grid_panel.cell_size)
		target_control.draw_rect(cell_rect, fill_color, true)

	for target_cell in target_cells:
		var cell_position := inventory_grid_panel.get_cell_local_position(target_cell)
		var cell_size := inventory_grid_panel.cell_size
		var top_cell := target_cell + Vector2i(0, -1)
		var right_cell := target_cell + Vector2i(1, 0)
		var bottom_cell := target_cell + Vector2i(0, 1)
		var left_cell := target_cell + Vector2i(-1, 0)

		var top_left_point := cell_position
		var top_right_point := cell_position + Vector2(cell_size.x, 0.0)
		var bottom_left_point := cell_position + Vector2(0.0, cell_size.y)
		var bottom_right_point := cell_position + Vector2(cell_size.x, cell_size.y)

		if !_lookup_has_cell(cell_lookup, top_cell):
			target_control.draw_line(top_left_point, top_right_point, border_color, border_width)
		if !_lookup_has_cell(cell_lookup, right_cell):
			target_control.draw_line(top_right_point, bottom_right_point, border_color, border_width)
		if !_lookup_has_cell(cell_lookup, bottom_cell):
			target_control.draw_line(bottom_left_point, bottom_right_point, border_color, border_width)
		if !_lookup_has_cell(cell_lookup, left_cell):
			target_control.draw_line(top_left_point, bottom_left_point, border_color, border_width)

## 判断格子是否存在于查找表中。
func _lookup_has_cell(cell_lookup: Dictionary, cell_index: Vector2i) -> bool:
	return cell_lookup.has(cell_index)
