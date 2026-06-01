@tool
class_name InventoryHeldItemView
extends Control
## InventoryHeldItemView 负责显示鼠标手持物品的视觉层。

const ITEM_BOX = preload("res://addons/visual_res_editor_panel/inventory_data/inventory_panel/cell/inventory_item_box.tscn")

## 手持物品透明度，略微透明可减少遮挡感。
@export_range(0.1, 1.0, 0.01) var held_item_alpha: float = 0.9
## 手持物品缩放，略微放大可增强“拿起”反馈。
@export_range(0.8, 1.4, 0.01) var held_item_scale: float = 1.06

## 当前显示中的手持物品框。
var held_item_box: InventoryItemBox
## 当前手持物品数据引用。
var held_item_instance_data: ItemInstanceData
## 当前手持物品来源背包数据。
var source_inventory_data: InventoryData
## 当前手持物品来源中心格（拿取前在背包中的位置）。
var held_item_source_center_cell: Vector2i = Vector2i(-1, -1)
## 当前手持物品图标尺寸。
var held_item_texture_size: Vector2 = Vector2(32, 32)
## 当前手持物品格子尺寸。
var held_item_box_size: Vector2 = Vector2(32, 32)
## 手持物品中心偏移，用于把中心对齐到鼠标。
var held_item_center_offset: Vector2 = Vector2.ZERO
## 记录最近一次手持旋转所处的帧，避免同帧重复旋转。
var last_rotate_process_frame: int = -1
## 当前场景中收集到的形状预览覆盖层列表。
var shape_overlays: Array[InventoryShapeOverlay] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 100
	_collect_shape_overlays()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and !visible:
		return
	if !_is_ready_for_view_operations():
		return
	_collect_shape_overlays()
	_try_handle_rotate_input()
	_update_follow_position()
	_update_shape_preview()

## 设置手持物品显示。
func set_held_item(
	item_instance_data: ItemInstanceData,
	item_texture_size: Vector2,
	item_box_size: Vector2,
	source_inventory_data_value: InventoryData,
	source_center_cell: Vector2i = Vector2i(-1, -1)
) -> void:
	clear_held_item()
	if !is_instance_valid(item_instance_data):
		return
	held_item_instance_data = item_instance_data
	source_inventory_data = source_inventory_data_value
	held_item_source_center_cell = source_center_cell
	held_item_texture_size = item_texture_size
	held_item_box_size = item_box_size
	held_item_box = InventoryItemBox.new()
	held_item_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_item_box.init_cell(item_instance_data, item_texture_size, item_box_size)
	held_item_box.modulate = Color(1.0, 1.0, 1.0, held_item_alpha)
	held_item_box.scale = Vector2(held_item_scale, held_item_scale)
	held_item_center_offset = held_item_box.get_center() * held_item_scale
	add_child(held_item_box)
	visible = true
	if _is_ready_for_view_operations():
		_update_follow_position()
		_update_shape_preview()

## 当前是否存在手持物品。
func has_held_item() -> bool:
	return is_instance_valid(held_item_instance_data)

## 对外提供与输入控制器一致命名的手持状态判断。
func has_taking_item() -> bool:
	return has_held_item()

## 获取当前手持物品数据。
func get_held_item_instance_data() -> ItemInstanceData:
	return held_item_instance_data

## 获取当前手持物品拿取前的来源中心格。
func get_held_item_source_center_cell() -> Vector2i:
	return held_item_source_center_cell

## 判断手持物品是否来自指定背包。
func is_holding_from_inventory(target_inventory_data: InventoryData) -> bool:
	if !has_held_item():
		return false
	return source_inventory_data == target_inventory_data

## 尝试旋转手持物品，并保证同一帧只旋转一次。
func try_rotate_held_item_once_per_frame() -> bool:
	if !has_held_item():
		return false
	var current_process_frame := Engine.get_process_frames()
	if current_process_frame == last_rotate_process_frame:
		return false
	last_rotate_process_frame = current_process_frame
	held_item_instance_data.rotate_num += 1
	return true

## 对外尝试旋转手持物品；无手持物品时返回 false。
func try_rotate_taking_item() -> bool:
	return try_rotate_held_item_once_per_frame()

## 处理手持物品旋转输入。
func _try_handle_rotate_input() -> void:
	if Engine.is_editor_hint():
		return
	if !InputMap.has_action(&"click_right") or !Input.is_action_just_pressed(&"click_right"):
		return
	try_rotate_taking_item()

## 清理手持物品显示。
func clear_held_item() -> void:
	if is_instance_valid(held_item_box):
		held_item_box.queue_free()
	held_item_box = null
	held_item_instance_data = null
	source_inventory_data = null
	held_item_source_center_cell = Vector2i(-1, -1)
	held_item_texture_size = Vector2(32, 32)
	held_item_box_size = Vector2(32, 32)
	held_item_center_offset = Vector2.ZERO
	last_rotate_process_frame = -1
	visible = false
	_clear_shape_preview()

## 更新手持物品跟随鼠标的位置。
func _update_follow_position() -> void:
	if !is_instance_valid(held_item_box) or !_is_ready_for_view_operations():
		return
	global_position = get_global_mouse_position() - held_item_center_offset


## 节点是否已挂载到有效视口，可安全读取鼠标与场景树。
func _is_ready_for_view_operations() -> bool:
	return is_inside_tree() and get_viewport() != null


## 收集场景中的所有形状覆盖层。
func _collect_shape_overlays() -> void:
	shape_overlays.clear()
	if !_is_ready_for_view_operations():
		return
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	for node_item in scene_tree.get_nodes_in_group("inventory_shape_overlay"):
		var overlay := node_item as InventoryShapeOverlay
		if _can_use_shape_overlay(overlay):
			shape_overlays.append(overlay)


## 编辑器中非 @tool 的覆盖层为 placeholder，无法调用实例方法。
func _can_use_shape_overlay(overlay: InventoryShapeOverlay) -> bool:
	if !is_instance_valid(overlay):
		return false
	if !Engine.is_editor_hint():
		return true
	var overlay_script := overlay.get_script() as Script
	return overlay_script != null and overlay_script.is_tool()


## 更新全部背包的预览覆盖层显示。
func _update_shape_preview() -> void:
	if shape_overlays.is_empty():
		return
	if !has_held_item():
		_clear_shape_preview()
		return
	for overlay in shape_overlays:
		if !_can_use_shape_overlay(overlay):
			continue
		if !is_instance_valid(overlay.inventory_grid_panel):
			overlay.clear_preview()
			continue
		var grid_panel := overlay.inventory_grid_panel
		var mouse_cell := grid_panel.get_mouse_cell()
		if mouse_cell == Vector2i(-1, -1):
			overlay.clear_preview()
			continue
		if !is_instance_valid(overlay.inventory_data):
			overlay.clear_preview()
			continue
		var preview_cells := held_item_instance_data.get_cells(mouse_cell)
		# 预览判定与点击放下逻辑保持一致：可放置、可合并、可替换任一成立都显示可操作。
		var can_place := overlay.inventory_data.can_place_item_in_cell(held_item_instance_data, mouse_cell) \
			or overlay.inventory_data.can_merge_item_in_cell(held_item_instance_data, mouse_cell) \
			or overlay.inventory_data.can_replace_item_in_cell(held_item_instance_data, mouse_cell)
		overlay.set_preview_cells(preview_cells, can_place)

## 清理全部背包的预览覆盖层显示。
func _clear_shape_preview() -> void:
	if shape_overlays.is_empty():
		return
	for overlay in shape_overlays:
		if !_can_use_shape_overlay(overlay):
			continue
		overlay.clear_preview()
