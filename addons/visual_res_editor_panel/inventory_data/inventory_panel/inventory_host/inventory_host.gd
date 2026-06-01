@tool
class_name InventroyHost
extends Control

@export var inventory_data:InventoryData
## 背包格子尺寸，创建背包面板时会应用到网格面板。
@export var cell_size: Vector2 = Vector2(48, 48)
## 创建背包面板时是否同时创建输入交互控件。
@export var allow_interaction: bool = true

@export_tool_button("创建背包面板") var create_action = _create_inventory_panel
@export_tool_button("移除背包面板") var remove_action = _remove_inventory_panel

var grid_panel:InventoryGridPanel
var items_panel:InventoryItemsPanel
var shape_overlay: InventoryShapeOverlay
var items_input_controller: InventoryItemsInputController

func _create_inventory_panel():
	_remove_inventory_panel()
	_create_inventory_grid_panel()
	_create_inventory_shape_overlay()
	_create_inventory_items_panel()
	if allow_interaction:
		_create_inventory_items_input_controller()

func _remove_inventory_panel():
	for child in get_children():
		remove_child(child)
		child.queue_free()
	grid_panel = null
	items_panel = null
	shape_overlay = null
	items_input_controller = null

func _create_inventory_grid_panel():
	grid_panel = InventoryGridPanel.new()
	grid_panel.name = "InventoryGridPanel"
	grid_panel.cell_size = cell_size
	grid_panel.inventory_data = inventory_data
	add_child(grid_panel)
	if owner:
		grid_panel.owner = owner
	else:
		grid_panel.owner = self

## 创建背包形状覆盖层，用于已放置物品边框与手持物品预览。
func _create_inventory_shape_overlay() -> void:
	shape_overlay = InventoryShapeOverlay.new()
	shape_overlay.name = "InventoryShapeOverlay"
	shape_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape_overlay.inventory_grid_panel = grid_panel
	shape_overlay.inventory_data = inventory_data
	add_child(shape_overlay)
	if owner:
		shape_overlay.owner = owner
	else:
		shape_overlay.owner = self

func _create_inventory_items_panel():
	items_panel = GridInventoryItemsPanel.new()
	items_panel.name = "GridInventoryItemsPanel"
	items_panel.inventory_data = inventory_data
	items_panel.inventory_grid_panel = grid_panel
	add_child(items_panel)
	if owner:
		items_panel.owner = owner
	else:
		items_panel.owner = self

## 创建背包输入交互控件，用于处理拿取、放置与旋转等操作。
func _create_inventory_items_input_controller() -> void:
	items_input_controller = InventoryItemsInputController.new()
	items_input_controller.name = "InventoryItemsInputController"
	items_input_controller.inventory_data = inventory_data
	items_input_controller.inventory_grid_panel = grid_panel
	items_input_controller.held_item_view_parent = self
	add_child(items_input_controller)
	grid_panel.bind_items_input_controller(items_input_controller)
	if owner:
		items_input_controller.owner = owner
	else:
		items_input_controller.owner = self
