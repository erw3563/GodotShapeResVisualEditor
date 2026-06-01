@tool
extends PanelContainer

## 背包数据在编辑器中被修改时发出。
signal inventory_changed
## 请求在独立弹窗中打开可视化面板。
signal popup_requested

const CELL_SIZE := Vector2(48, 48)

@onready var item_data_picker: EditorResourcePicker = $MarginContainer/VBox/Toolbar/ItemDataPicker
@onready var amount_spin: SpinBox = $MarginContainer/VBox/Toolbar/AmountSpin
@onready var add_button: Button = $MarginContainer/VBox/ViewControls/AddButton
@onready var delete_button: Button = $MarginContainer/VBox/ViewControls/DeleteButton
@onready var pop_button: Button = $MarginContainer/VBox/PopButton
@onready var inventory_grid_panel: InventoryGridPanel = $MarginContainer/VBox/ScrollContainer/InventoryViewRoot/InventoryGridPanel
@onready var inventory_items_panel: GridInventoryItemsPanel = $MarginContainer/VBox/ScrollContainer/InventoryViewRoot/InventoryItemsPanel
@onready var inventory_shape_overlay: InventoryShapeOverlay = $MarginContainer/VBox/ScrollContainer/InventoryViewRoot/InventoryShapeOverlay
@onready var inventory_items_input_controller: InventoryItemsInputController = $InventoryItemsInputController

var inventory_data: InventoryData


func _ready() -> void:
	add_to_group("inventory_data_editor_panel")
	_sync_inventory_panels()


func _exit_tree() -> void:
	_restore_held_item_if_from_current()


## 绑定当前正在编辑的 InventoryData 资源。
func set_inventory_data_resource(new_inventory_data_resource: InventoryData) -> void:
	if new_inventory_data_resource == inventory_data:
		return
	_restore_held_item_if_from_current()
	inventory_data = new_inventory_data_resource
	_sync_inventory_panels()

## 将 InventoryData 同步到运行时背包面板组件。
func _sync_inventory_panels() -> void:
	if inventory_grid_panel:
		inventory_grid_panel.cell_size = CELL_SIZE
		inventory_grid_panel.inventory_data = inventory_data
	if inventory_items_panel:
		inventory_items_panel.inventory_grid_panel = inventory_grid_panel
		inventory_items_panel.inventory_data = inventory_data
	if inventory_shape_overlay:
		inventory_shape_overlay.inventory_grid_panel = inventory_grid_panel
		inventory_shape_overlay.inventory_data = inventory_data
	if inventory_items_input_controller:
		inventory_items_input_controller.held_item_view_parent = self
		inventory_items_input_controller.inventory_grid_panel = inventory_grid_panel
		inventory_items_input_controller.inventory_data = inventory_data
	if inventory_grid_panel and inventory_items_input_controller:
		inventory_grid_panel.bind_items_input_controller(inventory_items_input_controller)

## 按数量 spin 向背包添加物品；超过单堆上限时分批创建实例（与补货逻辑一致）。
func _on_add_button_pressed() -> void:
	if inventory_data == null:
		return
	var selected_item_data := item_data_picker.get_edited_resource() as ItemData
	if selected_item_data == null:
		return
	var remaining_amount := int(amount_spin.value)
	while remaining_amount > 0:
		var new_item_instance := ItemInstanceData.new()
		new_item_instance.init(selected_item_data, remaining_amount)
		var batch_amount := new_item_instance.num
		if batch_amount <= 0:
			break
		if !inventory_data.try_add_item_with_merge(new_item_instance):
			break
		remaining_amount -= batch_amount

func _on_delete_button_pressed() -> void:
	if inventory_data == null:
		return
	var held_item_view := InventoryItemsInputController.shared_held_item_view
	if is_instance_valid(held_item_view) and held_item_view.has_taking_item():
		if held_item_view.is_holding_from_inventory(inventory_data):
			held_item_view.clear_held_item()
		return
	if inventory_grid_panel == null or !inventory_grid_panel.is_mouse_in_cells():
		return
	var mouse_cell := inventory_grid_panel.get_mouse_cell()
	if mouse_cell == Vector2i(-1, -1):
		return
	var hover_item := inventory_data.get_occupy_map().get_item_in_cell(mouse_cell) as ItemInstanceData
	if hover_item == null:
		return
	inventory_data.try_take_item(hover_item)

func _on_pop_button_pressed() -> void:
	popup_requested.emit()

## 若当前手持物品来自本面板背包，则放回来源格子后再清除手持显示。
func _restore_held_item_if_from_current() -> void:
	if inventory_data == null:
		return
	var held_item_view := InventoryItemsInputController.shared_held_item_view
	if !is_instance_valid(held_item_view) or !held_item_view.is_holding_from_inventory(inventory_data):
		return
	InventoryItemsInputController.try_restore_held_item_to_source_inventory()
