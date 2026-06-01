@tool
class_name InventoryItemsInputController
extends Node
## InventoryItemsInputController 负责背包交互逻辑（拿取、放置、旋转、Shift+左键快速转移等）。
## 指针事件由 InventoryGridPanel 的 gui_input 转发至 handle_pointer_input / refresh_mouse_pointed_item。

const HELD_ITEM_VIEW_SCRIPT = preload("res://addons/visual_res_editor_panel/inventory_data/inventory_extra_node/held_item_view/inventory_held_item_view.gd")
## 鼠标当前指向某个物品时发出。
signal mouse_pointed_item_instance(item_instance: ItemInstanceData)

## 当前控制器负责的背包数据。
@export var inventory_data: InventoryData
## 当前控制器负责的网格面板，用于计算鼠标所在格子。
@export var inventory_grid_panel: InventoryGridPanel
## 手持物品视图挂载父节点；为空时自动挂到当前场景。
@export var held_item_view_parent: Node
## 可选。绑定后 Shift+左键可将所指物品经转移中心移到对侧背包。
@export var inventory_transfer_center: InventoryTransferCenter

## 全局共享的手持物品视图（所有控制器共享）。
static var shared_held_item_view: InventoryHeldItemView
## 上一帧记录的鼠标指向物品，用于避免重复发射信号。
var _last_pointed_item_instance: ItemInstanceData

func _ready() -> void:
	add_to_group("InventoryItemsInputController")
	_try_bind_inventory_grid_panel()

## 将本控制器绑定到网格面板的 gui_input 转发链。
func _try_bind_inventory_grid_panel() -> void:
	if is_instance_valid(inventory_grid_panel):
		inventory_grid_panel.bind_items_input_controller(self)

## 处理网格面板转发的鼠标按键事件；返回 true 表示事件已消费。
func handle_pointer_input(mouse_button_event: InputEventMouseButton) -> bool:
	if mouse_button_event == null:
		return false
	if !mouse_button_event.pressed:
		return false
	if !is_instance_valid(inventory_data) or !is_instance_valid(inventory_grid_panel):
		return false
	if !inventory_grid_panel.is_mouse_in_cells():
		return false
	if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_left_mouse_button_event(mouse_button_event)
	if mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
		return _handle_right_mouse_button_event()
	return false

## 处理左键事件：Shift 快速转移，Ctrl 单个拿放，默认整组拿放。
func _handle_left_mouse_button_event(mouse_button_event: InputEventMouseButton) -> bool:
	if mouse_button_event.shift_pressed:
		_execute_quick_transfer_action()
		return true
	if mouse_button_event.ctrl_pressed:
		_execute_pick_or_lay_action(true)
		return true
	_execute_pick_or_lay_action(false)
	return true

## 处理右键事件：有手持时旋转手持物品，无手持时旋转悬停物品。
func _handle_right_mouse_button_event() -> bool:
	_execute_right_click_action()
	return true

## 执行拿放动作（单个或整组）。
func _execute_pick_or_lay_action(is_single_mode: bool) -> void:
	try_handle_pick_or_lay(is_single_mode)

## 执行快速转移动作。
func _execute_quick_transfer_action() -> void:
	try_quick_transfer_hover_item_to_opposite_inventory()

## 执行右键旋转动作。
func _execute_right_click_action() -> void:
	if has_taking_item():
		if is_instance_valid(shared_held_item_view):
			shared_held_item_view.try_rotate_taking_item()
		return
	try_rotate_hover_item_when_no_taking_item()

## 根据当前鼠标位置刷新悬停指向物品，变化时发出 mouse_pointed_item_instance。
func refresh_mouse_pointed_item() -> void:
	if !is_instance_valid(inventory_data) or !is_instance_valid(inventory_grid_panel):
		return
	var pointed_item_instance := _get_mouse_pointed_item_instance()
	if pointed_item_instance == _last_pointed_item_instance:
		return
	_last_pointed_item_instance = pointed_item_instance
	if pointed_item_instance != null:
		mouse_pointed_item_instance.emit(pointed_item_instance)

## 获取鼠标当前指向的物品实例，不在格子区域或无物品时返回 null。
func _get_mouse_pointed_item_instance() -> ItemInstanceData:
	if !inventory_grid_panel.is_mouse_in_cells():
		return null
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	if mouse_cell == Vector2i(-1, -1):
		return null
	return inventory_data.get_occupy_map().get_item_in_cell(mouse_cell)

## 尝试执行拿取或放置逻辑。
## - is_single_mode: 为 true 时执行“单个”模式。
func try_handle_pick_or_lay(is_single_mode: bool) -> void:
	if has_taking_item():
		if is_single_mode:
			try_lay_one_item_by_mouse()
		else:
			try_lay_item_by_mouse()
	else:
		if is_single_mode:
			try_pick_one_item_by_mouse()
		else:
			try_pick_item_by_mouse()

## 当前是否正在拿取物品。
func has_taking_item() -> bool:
	if !is_instance_valid(shared_held_item_view):
		return false
	return shared_held_item_view.has_taking_item()

## 尝试拿取鼠标当前指向的物品。
func try_pick_item_by_mouse() -> void:
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	if mouse_cell == Vector2i(-1, -1):
		return
	var hover_item := inventory_data.get_occupy_map().get_item_in_cell(mouse_cell)
	if hover_item == null:
		return
	var source_center_cell := inventory_data.get_occupy_map().get_item_center_cell(hover_item)
	if !inventory_data.try_take_item(hover_item):
		return
	pick_item_instance(hover_item, source_center_cell)

## 尝试拿取鼠标当前指向物品中的一个。
func try_pick_one_item_by_mouse() -> void:
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	if mouse_cell == Vector2i(-1, -1):
		return
	var hover_item := inventory_data.get_occupy_map().get_item_in_cell(mouse_cell)
	if hover_item == null:
		return
	var split_item := hover_item.split(1)
	if split_item == null:
		try_pick_item_by_mouse()
		return
	pick_item_instance(split_item)

## 从背包中拿出指定物品实例并创建拖拽格子。
func pick_item_instance(
	item_instance_data: ItemInstanceData,
	source_center_cell: Vector2i = Vector2i(-1, -1)
) -> void:
	_ensure_shared_held_item_view()
	if is_instance_valid(shared_held_item_view):
		var item_cell_size := _get_grid_cell_size()
		shared_held_item_view.set_held_item(
			item_instance_data,
			item_cell_size,
			item_cell_size,
			inventory_data,
			source_center_cell
		)

## 尝试将鼠标拿取的物品放下。
func try_lay_item_by_mouse() -> void:
	if !has_taking_item():
		return
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	if mouse_cell == Vector2i(-1, -1):
		return
	var taking_item_instance_data := shared_held_item_view.get_held_item_instance_data()
	if inventory_data.can_place_item_in_cell(taking_item_instance_data, mouse_cell):
		if inventory_data.try_place_item_in_cell(taking_item_instance_data, mouse_cell):
			_clear_taking_item_box()
	elif inventory_data.can_merge_item_in_cell(taking_item_instance_data, mouse_cell):
		inventory_data.try_merge_item_in_cell(taking_item_instance_data, mouse_cell)
		if taking_item_instance_data.num == 0:
			_clear_taking_item_box()
	elif inventory_data.can_replace_item_in_cell(taking_item_instance_data, mouse_cell):
		var replaced_item := inventory_data.try_replace_item_in_cell(taking_item_instance_data, mouse_cell)
		if replaced_item != null:
			_clear_taking_item_box()
			pick_item_instance(replaced_item, mouse_cell)
	else:
		_play_invalid_place_feedback()

## 尝试将鼠标拿取物品中的一个放下。
func try_lay_one_item_by_mouse() -> void:
	if !has_taking_item():
		return
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	if mouse_cell == Vector2i(-1, -1):
		return
	var taking_item_instance_data := shared_held_item_view.get_held_item_instance_data()
	if inventory_data.can_place_item_in_cell(taking_item_instance_data, mouse_cell):
		var split_item := taking_item_instance_data.split(1)
		if split_item == null:
			try_lay_item_by_mouse()
			return
		inventory_data.try_place_item_in_cell(split_item, mouse_cell)
	elif inventory_data.can_merge_item_in_cell(taking_item_instance_data, mouse_cell):
		var split_item_for_merge := taking_item_instance_data.split(1)
		if split_item_for_merge:
			inventory_data.try_merge_item_in_cell(split_item_for_merge, mouse_cell)
		else:
			inventory_data.try_merge_item_in_cell(taking_item_instance_data, mouse_cell)
		if taking_item_instance_data.num == 0:
			_clear_taking_item_box()
	else:
		_play_invalid_place_feedback()

## 无手持物品时，尝试旋转鼠标指向的背包内物品。
func try_rotate_hover_item_when_no_taking_item() -> void:
	if has_taking_item():
		return
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	var hover_item := inventory_data.get_occupy_map().get_item_in_cell(mouse_cell)
	if hover_item == null:
		return
	if !inventory_data.try_rotate_item_in_inventory_best_effort(hover_item):
		_play_invalid_rotate_feedback(hover_item)

## 无手持物品时，经转移中心将鼠标指向的物品移到对侧背包。
func try_quick_transfer_hover_item_to_opposite_inventory() -> void:
	if has_taking_item():
		return
	if !is_instance_valid(inventory_transfer_center):
		return
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	if mouse_cell == Vector2i(-1, -1):
		return
	var hover_item := inventory_data.get_occupy_map().get_item_in_cell(mouse_cell)
	if hover_item == null:
		return
	if inventory_transfer_center.try_transfer_item_instance_to_opposite_from_inventory(inventory_data, hover_item):
		return
	_play_invalid_quick_transfer_feedback(hover_item)

## 清理当前拖拽物品格子状态。
func _clear_taking_item_box() -> void:
	if is_instance_valid(shared_held_item_view):
		shared_held_item_view.clear_held_item()


## 将手持物品放回来源背包（优先原格子），并清除手持显示。
static func try_restore_held_item_to_source_inventory() -> bool:
	if !is_instance_valid(shared_held_item_view) or !shared_held_item_view.has_held_item():
		return false
	var held_item_instance_data := shared_held_item_view.get_held_item_instance_data()
	var source_inventory_data := shared_held_item_view.source_inventory_data
	if !is_instance_valid(held_item_instance_data) or !is_instance_valid(source_inventory_data):
		shared_held_item_view.clear_held_item()
		return false

	var restored := false
	var original_cell := shared_held_item_view.get_held_item_source_center_cell()
	if original_cell != Vector2i(-1, -1) and source_inventory_data.can_place_item_in_cell(held_item_instance_data, original_cell):
		restored = source_inventory_data.try_place_item_in_cell(held_item_instance_data, original_cell)
	if !restored:
		restored = source_inventory_data.try_add_item_with_merge(held_item_instance_data)
	if !restored:
		restored = source_inventory_data.try_add_item_without_merge(held_item_instance_data)
	if !restored:
		push_warning("无法将手持物品放回背包，物品可能丢失。")

	shared_held_item_view.clear_held_item()
	return restored

## 播放不可放置点击反馈，反馈只作用于覆盖层绘制的物品框。
func _play_invalid_place_feedback() -> void:
	if !is_instance_valid(shared_held_item_view):
		return
	for overlay in shared_held_item_view.shape_overlays:
		if !is_instance_valid(overlay):
			continue
		if !is_instance_valid(overlay.inventory_grid_panel):
			continue
		var mouse_cell := overlay.inventory_grid_panel.get_mouse_cell()
		if mouse_cell == Vector2i(-1, -1):
			continue
		overlay.play_invalid_action_feedback()
		break

## 播放旋转失败反馈，反馈只作用于覆盖层绘制的已放置物品框。
func _play_invalid_rotate_feedback(item_instance_data: ItemInstanceData) -> void:
	if !is_instance_valid(shared_held_item_view):
		return
	for overlay in shared_held_item_view.shape_overlays:
		if !is_instance_valid(overlay):
			continue
		if overlay.inventory_data != inventory_data:
			continue
		overlay.play_invalid_action_feedback(item_instance_data)
		return

## 快速转移失败时，在与旋转失败相同的覆盖层上播放反馈。
func _play_invalid_quick_transfer_feedback(item_instance_data: ItemInstanceData) -> void:
	_play_invalid_rotate_feedback(item_instance_data)

## 确保全局手持物品视图已创建并挂载到可见树中。
func _ensure_shared_held_item_view() -> void:
	var parent_node := _get_held_item_view_parent()
	if !is_instance_valid(parent_node):
		return
	if is_instance_valid(shared_held_item_view):
		_mount_shared_held_item_view(parent_node)
		return
	shared_held_item_view = HELD_ITEM_VIEW_SCRIPT.new() as InventoryHeldItemView
	_mount_shared_held_item_view(parent_node)


## 获取手持物品视图的挂载父节点。
func _get_held_item_view_parent() -> Node:
	if is_instance_valid(held_item_view_parent):
		return held_item_view_parent
	if is_inside_tree():
		var current_scene := get_tree().current_scene
		if is_instance_valid(current_scene):
			return current_scene
	if is_instance_valid(self):
		return self
	return null


## 获取网格面板的格子尺寸，用于初始化拖拽物品格子。
func _get_grid_cell_size() -> Vector2:
	if !is_instance_valid(inventory_grid_panel):
		return Vector2.ZERO
	return inventory_grid_panel.cell_size


## 将手持物品视图挂到指定父节点（同步挂载，避免 deferred 导致 viewport 为空）。
func _mount_shared_held_item_view(parent_node: Node) -> void:
	if !is_instance_valid(shared_held_item_view) or !is_instance_valid(parent_node):
		return
	if shared_held_item_view.get_parent() == parent_node:
		return
	if shared_held_item_view.get_parent() != null:
		shared_held_item_view.get_parent().remove_child(shared_held_item_view)
	parent_node.add_child(shared_held_item_view)
