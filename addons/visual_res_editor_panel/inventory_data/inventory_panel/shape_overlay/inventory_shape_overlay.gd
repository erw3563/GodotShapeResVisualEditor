@tool
class_name InventoryShapeOverlay
extends Control
## 背包形状覆盖层。
## 该节点持有 InventoryData，并根据其中物品占据格子自动生成边框。
## 同时支持手持物品预览边框显示。

enum PreviewState {
	VALID,
	INVALID,
}

## 网格面板（用于格子坐标转像素坐标）。
@export var inventory_grid_panel: InventoryGridPanel
## 背包数据（用于自动生成已放置物品边框）。
@export var inventory_data: InventoryData:
	set(value):
		_try_disconnect_inventory_data_signal()
		inventory_data = value
		_try_connect_inventory_data_signal()
		_try_auto_rebuild_placed_item_borders()

## 覆盖层级。
@export var overlay_z_index: int = 80
@export_group("Color")
## 边框厚度（像素）。
@export var border_width: float = 3.0
@export_subgroup("已放置")
## 已放置物品边框颜色。
@export var placed_item_border_color: Color = Color(0.84, 0.88, 0.97, 1.0)
## 已放置物品填充颜色。
@export var placed_item_fill_color: Color = Color(0.64, 0.72, 0.9, 0.12)
@export_subgroup("预览可放置")
## 预览可放置边框颜色。
@export var valid_border_color: Color = Color(0.37, 0.9, 0.53, 1.0)
## 预览可放置填充颜色。
@export var valid_fill_color: Color = Color(0.37, 0.9, 0.53, 0.2)
@export_subgroup("预览不可放置")
## 预览不可放置边框颜色。
@export var invalid_border_color: Color = Color(1.0, 0.34, 0.34, 1.0)
## 预览不可放置填充颜色。
@export var invalid_fill_color: Color = Color(1.0, 0.34, 0.34, 0.2)
@export_subgroup("无效操作闪烁")
## 无效操作反馈时边框短暂切换到的颜色。
@export var invalid_click_feedback_border_color: Color = Color(1.0, 0.95, 0.25, 1.0)
## 无效操作反馈时填充短暂切换到的颜色。
@export var invalid_click_feedback_fill_color: Color = Color(1.0, 0.95, 0.25, 0.25)
## 无效操作反馈变色持续时间。
@export var invalid_click_feedback_time: float = 0.18
@export_group("Texture")
## 单格完整框贴图（九宫格源图）；程序按 frame_border_margins 配置 NinePatchRect 绘制各暴露边。
@export var frame_texture: Texture2D:
	set(value):
		if frame_texture == value:
			return
		frame_texture = value
		_on_texture_config_changed()
## 源图像四边边框厚度 (left, top, right, bottom)，语义对齐 NinePatchRect 的 patch_margin。
@export var frame_border_margins: Vector4i = Vector4i(6, 6, 6, 6):
	set(value):
		if frame_border_margins == value:
			return
		frame_border_margins = value
		_on_texture_config_changed()
## 每个占格内部的填充贴图；尺寸为 cell_size，仅负责格内底色，不负责边框。
@export var fill_texture: Texture2D:
	set(value):
		if fill_texture == value:
			return
		fill_texture = value
		_on_texture_config_changed()


## 当前预览占用的格子坐标列表。
var preview_cells: Array[Vector2i] = []
## 当前预览是否可放置。
var preview_state: PreviewState = PreviewState.VALID
## 已放置物品边框与填充的子容器。
var placed_item_container: Control:
	get:
		if !is_instance_valid(placed_item_container):
			placed_item_container = _create_shape_container("PlacedItemContainer")
		return placed_item_container
## 手持物品预览边框与填充的子容器。
var preview_container: Control:
	get:
		if !is_instance_valid(preview_container):
			preview_container = _create_shape_container("PreviewContainer")
		return preview_container
## 贴图渲染策略（负责贴图绘制相关逻辑）。
var texture_render_strategy := InventoryShapeOverlayTextureRenderStrategy.new()
## 线条渲染策略（负责 draw 回退绘制逻辑）。
var line_render_strategy := InventoryShapeOverlayLineRenderStrategy.new()
## 视觉状态策略（负责颜色决策与无效反馈状态管理）。
var visual_state_strategy := InventoryShapeOverlayVisualState.new()

#region 生命周期
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("inventory_shape_overlay")
	z_index = overlay_z_index
	_sync_render_strategy_config()
	_sync_layout_with_grid_panel()
	_try_auto_rebuild_placed_item_borders()

func _process(_delta: float) -> void:
	_sync_layout_with_grid_panel()

func _draw() -> void:
	line_render_strategy.draw_shapes(self)
#endregion

#region 对外接口
## 显示预览格子；格子与可放置状态均未变化时跳过重建。
func set_preview_cells(cells: Array[Vector2i], is_valid: bool) -> void:
	var target_preview_state := PreviewState.VALID if is_valid else PreviewState.INVALID
	if preview_state == target_preview_state and _are_preview_cells_equal(preview_cells, cells):
		return
	preview_cells = cells.duplicate()
	preview_state = target_preview_state
	visual_state_strategy.set_preview_state(is_valid)
	_rebuild_preview_borders()

## 清空当前预览显示。
func clear_preview() -> void:
	if preview_cells.is_empty():
		return
	preview_state = PreviewState.VALID
	preview_cells.clear()
	line_render_strategy.clear_shape_data(true)
	visual_state_strategy.clear_invalid_feedback_state()
	_clear_container_children(preview_container)
	queue_redraw()

## 主动刷新已放置物品边框。
func refresh_placed_item_borders() -> void:
	_rebuild_placed_item_borders()

## 播放无效操作反馈，目标框短暂变色。
## item_instance_data 为 null 时作用于预览框（如放置失败）；否则作用于该已放置物品框（如旋转失败）。
func play_invalid_action_feedback(item_instance_data: ItemInstanceData = null) -> void:
	var is_preview_feedback := item_instance_data == null
	if is_preview_feedback and preview_cells.is_empty():
		return
	var current_feedback_version := visual_state_strategy.start_invalid_feedback(item_instance_data)
	if is_preview_feedback:
		_rebuild_preview_borders()
	else:
		_rebuild_placed_item_borders()
	await get_tree().create_timer(invalid_click_feedback_time).timeout
	if not visual_state_strategy.is_feedback_version_valid(current_feedback_version):
		return
	visual_state_strategy.clear_invalid_feedback_state()
	if is_preview_feedback:
		_rebuild_preview_borders()
	else:
		_rebuild_placed_item_borders()
#endregion

#region 边框重建
## 重建已放置物品边框。
func _rebuild_placed_item_borders() -> void:
	_clear_container_children(placed_item_container)
	line_render_strategy.clear_shape_data(false)
	_sync_render_strategy_config()
	if inventory_data == null:
		queue_redraw()
		return
	for item_instance_data in inventory_data.get_item_instances():
		if item_instance_data == null:
			continue
		var target_cells := inventory_data.get_occupy_map().get_cells_of_occupant(item_instance_data)
		if target_cells.is_empty():
			continue
		_build_shape_to_container(
			target_cells,
			placed_item_container,
			visual_state_strategy.get_placed_item_border_color(item_instance_data),
			visual_state_strategy.get_placed_item_fill_color(item_instance_data)
		)
	queue_redraw()

## 重建手持物品预览边框。
func _rebuild_preview_borders() -> void:
	_clear_container_children(preview_container)
	line_render_strategy.clear_shape_data(true)
	_sync_render_strategy_config()
	if preview_cells.is_empty():
		queue_redraw()
		return
	_build_shape_to_container(
		preview_cells,
		preview_container,
		visual_state_strategy.get_preview_border_color(),
		visual_state_strategy.get_preview_fill_color()
	)
	queue_redraw()

## 将一组形状格子绘制到目标容器。
func _build_shape_to_container(
	target_cells: Array[Vector2i],
	target_container: Control,
	border_color: Color,
	fill_color: Color
) -> void:
	if !is_instance_valid(inventory_grid_panel):
		return
	if texture_render_strategy.has_all_texture_to_draw():
		texture_render_strategy.build_shape_to_container(target_cells, target_container, border_color, fill_color)
	else:
		line_render_strategy.build_shape_to_container(target_cells, border_color, fill_color, target_container == preview_container)
#endregion

#region InventoryData 信号
## 连接 InventoryData 相关信号。
func _try_connect_inventory_data_signal() -> void:
	if inventory_data:
		set_connection_inventory_data_signal(true)

## 断开 InventoryData 相关信号。
func _try_disconnect_inventory_data_signal() -> void:
	if inventory_data:
		set_connection_inventory_data_signal(false)

func set_connection_inventory_data_signal(ensure:bool):
	_set_signal_connection(inventory_data.item_added, _on_inventory_item_changed, ensure)
	_set_signal_connection(inventory_data.item_removed, _on_inventory_item_changed, ensure)
	_set_signal_connection(inventory_data.item_position_changed, _on_inventory_item_changed, ensure)
	_set_signal_connection(inventory_data.item_corrected, _on_inventory_item_changed, ensure)
	_set_signal_connection(inventory_data.item_rotated, _on_inventory_item_changed, ensure)
	_set_signal_connection(inventory_data.item_cannot_be_handled, _on_inventory_item_changed, ensure)
	_set_signal_connection(inventory_data.sorted, _on_inventory_items_changed, ensure)
	_set_signal_connection(inventory_data.inventory_cleared, _on_inventory_cleared, ensure)
	_set_signal_connection(inventory_data.occupy_map_changed, _on_inventory_items_changed, ensure)

## 统一管理信号连接状态。
func _set_signal_connection(target_signal: Signal, target_callable: Callable, is_connect: bool) -> void:
	if is_connect:
		if !target_signal.is_connected(target_callable):
			target_signal.connect(target_callable)
	else:
		if target_signal.is_connected(target_callable):
			target_signal.disconnect(target_callable)

## 物品增删时重建边框（参数仅用于匹配各信号签名，不使用）。
func _on_inventory_item_changed(
		_item_instance_data: ItemInstanceData = null,
		_previous_cell: Vector2i = Vector2i.ZERO
) -> void:
	_try_auto_rebuild_placed_item_borders()

## 物品状态变化时重建边框。
func _on_inventory_items_changed() -> void:
	_try_auto_rebuild_placed_item_borders()

## 背包清空时清理边框。
func _on_inventory_cleared() -> void:
	_clear_container_children(placed_item_container)
	line_render_strategy.clear_shape_data(false)
	queue_redraw()
#endregion

#region 已放置边框同步策略

## 在允许自动同步时才重建已放置物品边框。
func _try_auto_rebuild_placed_item_borders() -> void:
	_rebuild_placed_item_borders()
#endregion

#region 布局与容器
## 判断两组预览格子坐标是否完全一致。
func _are_preview_cells_equal(cells_a: Array[Vector2i], cells_b: Array[Vector2i]) -> bool:
	if cells_a.size() != cells_b.size():
		return false
	for cell_index in range(cells_a.size()):
		if cells_a[cell_index] != cells_b[cell_index]:
			return false
	return true

## 根据网格面板同步覆盖层尺寸与位置。
func _sync_layout_with_grid_panel() -> void:
	if !is_instance_valid(inventory_grid_panel):
		visible = false
		return
	visible = true
	position = inventory_grid_panel.position
	size = inventory_grid_panel.get_grid_size()

## 创建形状覆盖子容器。
func _create_shape_container(container_name: String) -> Control:
	var container := Control.new()
	container.name = container_name
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 0.0
	container.offset_top = 0.0
	container.offset_right = 0.0
	container.offset_bottom = 0.0
	add_child(container)
	return container

## 清理目标容器的所有子节点。
func _clear_container_children(target_container: Control) -> void:
	if !is_instance_valid(target_container):
		return
	for child_node in target_container.get_children():
		child_node.queue_free()

## 贴图配置变更时刷新边框显示。
func _on_texture_config_changed() -> void:
	if !is_node_ready():
		return
	_sync_render_strategy_config()
	_try_auto_rebuild_placed_item_borders()
	if !preview_cells.is_empty():
		_rebuild_preview_borders()
	else:
		queue_redraw()

## 同步渲染策略所需配置。
func _sync_render_strategy_config() -> void:
	texture_render_strategy.sync_config(
		inventory_grid_panel,
		frame_texture,
		frame_border_margins,
		fill_texture
	)
	line_render_strategy.sync_config(inventory_grid_panel, border_width)
	visual_state_strategy.sync_config(
		placed_item_border_color,
		placed_item_fill_color,
		valid_border_color,
		invalid_border_color,
		valid_fill_color,
		invalid_fill_color,
		invalid_click_feedback_border_color,
		invalid_click_feedback_fill_color
	)
#endregion
