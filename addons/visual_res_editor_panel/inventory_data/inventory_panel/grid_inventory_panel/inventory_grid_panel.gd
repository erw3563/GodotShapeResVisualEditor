@tool
class_name InventoryGridPanel
extends GridContainer

const INVENTORY_CELL = preload("res://addons/visual_res_editor_panel/inventory_data/inventory_panel/cell/inventory_grid_cell.tscn")

#region 信号
signal updated
## 格子尺寸变化时发出。
signal cell_size_changed
#endregion

#region 导出属性与变量
@export var cell_size:Vector2 = Vector2(32,32):
	set(value):
		if cell_size == value:
			return
		cell_size = value
		update_cell()
		cell_size_changed.emit()
## 背包数据，网格面板可直接与其占位图交互。
@export var inventory_data: InventoryData:
	set(value):
		_try_disconnect_inventory_data_signal()
		inventory_data = value
		if !is_node_ready():
			await ready
		_try_connect_inventory_data_signal()
		sync_from_inventory_data()
			

var is_mouse_in:bool
var cell_panels:Array[Control]
## 当前网格边界尺寸（由 OccupyMap 推导）。
var grid_size: Vector2i = Vector2i.ZERO
## 网格索引对应的 OccupyMap 坐标原点，固定从 (0, 0) 开始。
var region_origin: Vector2i = Vector2i.ZERO
## 绑定的背包输入控制器，由 gui_input 转发指针事件。
var _items_input_controller: InventoryItemsInputController
#endregion

#region 生命周期
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func():is_mouse_in = false)
	if !mouse_exited.is_connected(_on_mouse_exited_grid):
		mouse_exited.connect(_on_mouse_exited_grid)
	_try_connect_inventory_data_signal()
	sync_from_inventory_data()
#endregion

#region 输入绑定
## 绑定背包输入控制器，由本面板统一接收 gui_input 并转发。
func bind_items_input_controller(controller: InventoryItemsInputController) -> void:
	if _items_input_controller == controller:
		return
	if is_instance_valid(_items_input_controller) and gui_input.is_connected(_on_gui_input):
		gui_input.disconnect(_on_gui_input)
	_items_input_controller = controller
	if is_instance_valid(_items_input_controller) and !gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if !is_instance_valid(_items_input_controller):
		return
	if event is InputEventMouseMotion:
		_items_input_controller.refresh_mouse_pointed_item()
		return
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if _items_input_controller.handle_pointer_input(mouse_button_event):
			accept_event()

## 鼠标离开网格时刷新悬停指向状态。
func _on_mouse_exited_grid() -> void:
	is_mouse_in = false
	if is_instance_valid(_items_input_controller):
		_items_input_controller.refresh_mouse_pointed_item()
#endregion

#region 网格构建
## 根据 OccupyMap 更新背包格子。
func update_cell():
	_clear_cell_panels()
	var occupy_map := _get_occupy_map()
	if occupy_map:
		_build_cells_from_occupy_map(occupy_map)
	else:
		_reset_grid_state()
	updated.emit()

## 清理当前所有格子控件。
func _clear_cell_panels() -> void:
	while cell_panels.size() != 0:
		var cell_panel = cell_panels.pop_back()
		cell_panel.queue_free()

## 从 (0, 0) 到边界最大值遍历并生成格子；合法区域用格子控件，空缺处用等大的空控件。
func _build_cells_from_occupy_map(occupy_map: OccupyMap) -> void:
	var region_cells := occupy_map.get_region_cells()
	if region_cells.is_empty():
		return
	
	var max_x := region_cells[0].x
	var max_y := region_cells[0].y
	for region_cell in region_cells:
		max_x = maxi(max_x, region_cell.x)
		max_y = maxi(max_y, region_cell.y)
	
	region_origin = Vector2i.ZERO
	grid_size = Vector2i(max_x + 1, max_y + 1)
	columns = maxi(grid_size.x, 1)
	for cell_y in range(grid_size.y):
		for cell_x in range(grid_size.x):
			var occupy_cell := Vector2i(cell_x, cell_y)
			var cell_panel: Control
			if occupy_map.has_region_cell(occupy_cell):
				cell_panel = INVENTORY_CELL.instantiate() as Control
				cell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				cell_panel = _create_empty_cell_panel()
			cell_panel.custom_minimum_size = cell_size
			cell_panels.append(cell_panel)
			add_child(cell_panel)

## 创建与格子等大的空控件，用于占位图边界内的非合法区域。
func _create_empty_cell_panel() -> Control:
	var empty_panel := Control.new()
	empty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return empty_panel

## 重置网格状态（无占位图或占位图为空时使用）。
func _reset_grid_state() -> void:
	grid_size = Vector2i.ZERO
	region_origin = Vector2i.ZERO
	columns = 1

## 获取当前绑定的占位图资源。
func _get_occupy_map() -> OccupyMap:
	if inventory_data == null:
		return null
	return inventory_data.get_occupy_map()
#endregion

#region InventoryData 同步
## 连接 inventory_data 的占位图区域大小变化信号。
func _try_connect_inventory_data_signal() -> void:
	if !inventory_data:
		return
	if !inventory_data.occupy_map_changed.is_connected(sync_from_inventory_data):
		inventory_data.occupy_map_changed.connect(sync_from_inventory_data)
		

## 断开 inventory_data 的占位图区域大小变化信号。
func _try_disconnect_inventory_data_signal() -> void:
	if !inventory_data:
		return
	if inventory_data.occupy_map_changed.is_connected(sync_from_inventory_data):
		inventory_data.occupy_map_changed.disconnect(sync_from_inventory_data)

## 强制从 inventory_data 同步占位图与网格尺寸（引用未变时也可调用）。
func sync_from_inventory_data() -> void:
	if inventory_data == null:
		_clear_cell_panels()
	else:
		var inventory_occupy_map := inventory_data.get_occupy_map()
		if inventory_occupy_map:
			update_cell()
#endregion

#region 获取
## 获取当前网格边界尺寸（由 OccupyMap 推导）。
func get_grid_dimensions() -> Vector2i:
	return grid_size

## 获取网格面板中的格子间距（来自 GridContainer 主题常量）。
func get_cell_distance() -> Vector2i:
	var horizontal_separation := get_theme_constant("h_separation")
	var vertical_separation := get_theme_constant("v_separation")
	return Vector2i(horizontal_separation, vertical_separation)

## 获取单个格子的步进尺寸（格子大小 + 网格间距）。
func get_cell_step() -> Vector2:
	var cell_distance := get_cell_distance()
	return Vector2(cell_size.x + cell_distance.x, cell_size.y + cell_distance.y)

## 根据 OccupyMap 格子坐标获取其在面板局部空间中的左上角位置。
func get_cell_local_position(cell_index: Vector2i) -> Vector2:
	var step := get_cell_step()
	var local_cell_index := cell_index - region_origin
	return Vector2(step.x * local_cell_index.x, step.y * local_cell_index.y)

## 根据面板局部坐标获取所在 OccupyMap 格子坐标；越界或非合法区域时返回 (-1, -1)。
func get_cell_by_local_position(local_position: Vector2) -> Vector2i:
	var step := get_cell_step()
	if step.x <= 0 or step.y <= 0 or grid_size == Vector2i.ZERO:
		return Vector2i(-1, -1)
	var grid_index := Vector2i(int(local_position.x / step.x), int(local_position.y / step.y))
	if grid_index.x < 0 or grid_index.y < 0 or grid_index.x >= grid_size.x or grid_index.y >= grid_size.y:
		return Vector2i(-1, -1)
	var cell_index := region_origin + grid_index
	if !has_cell(cell_index):
		return Vector2i(-1, -1)
	return cell_index

## 获取鼠标当前所在的格子坐标；
func get_mouse_cell() -> Vector2i:
	return get_cell_by_local_position(get_local_mouse_position())

## 获取当前网格总尺寸（包含格子间距）。
func get_grid_size() -> Vector2:
	var step := get_cell_step()
	return Vector2(grid_size.x * step.x, grid_size.y * step.y)

## 获取当前网格控件总数（含边界内空缺控件）。
func get_cell_num()->int:
	return cell_panels.size()

## 获取当前占位图合法区域格子坐标列表。
func get_cells()->Array[Vector2i]:
	var occupy_map := _get_occupy_map()
	if occupy_map == null:
		return []
	return occupy_map.get_region_cells()
#endregion

#region 判断
## 判断格子坐标是否为占位图合法区域。
func has_cell(cell_index: Vector2i) -> bool:
	var occupy_map := _get_occupy_map()
	if occupy_map == null:
		return false
	return occupy_map.has_region_cell(cell_index)

## 判断面板局部坐标是否落在有效格子中。
func is_local_position_in_cells(local_position: Vector2) -> bool:
	return get_cell_by_local_position(local_position) != Vector2i(-1, -1)

## 鼠标当前是否位于有效格子中。
func is_mouse_in_cells() -> bool:
	return get_mouse_cell() != Vector2i(-1, -1)
#endregion
