@tool
class_name InventoryData
extends Resource
## InventoryData是背包数据文件。

#region 信号
## 占位图合法区域大小变化时触发。
signal occupy_map_changed
## 背包整理完成时触发（整理流程内仅通过 item_position_changed 等细粒度信号通知变化，结束时发出本信号）。
signal sorted
## 物品添加时触发
signal item_added(item:ItemInstanceData)
## 物品移除时触发
signal item_removed(item:ItemInstanceData)
## 物品在背包内的中心格位置发生变化时触发（previous_cell 为变化前的中心格坐标）。
signal item_position_changed(item: ItemInstanceData, previous_cell: Vector2i)
## 物品在背包内旋转时触发。
signal item_rotated(item: ItemInstanceData)
## 占位图无法为物品找到合法位置时触发（重叠、越界且背包无可用空位等）。
signal item_cannot_be_handled(item: ItemInstanceData)
## 物品占位校正成功时触发（重叠或越界坐标已重新注册，previous_cell 为校正前的中心格坐标）。
signal item_corrected(item: ItemInstanceData, previous_cell: Vector2i)
## 物品移除时触发
signal item_removed_in_cell(item: ItemInstanceData, removed_center_cell: Vector2i)
## 全部物品移除时触发
signal inventory_cleared
#endregion

#region 数据字段
@export var item_instances:Array[ItemInstanceData]
## 背包占位图
@export var occupy_map:InventoryOccupyMap:
	set(value):
		_disconnect_occupy_map_signals()
		occupy_map = value
		_connect_occupy_map_signals()
#endregion

func _init() -> void:
	occupy_map = InventoryOccupyMap.new()

#region 初始化与信号绑定

## 连接当前占位图资源上的变化信号。
func _connect_occupy_map_signals() -> void:
	if !occupy_map:
		return
	_set_occupy_map_signal_connection(occupy_map.map_changed, occupy_map_changed.emit, true)
	_set_occupy_map_signal_connection(occupy_map.item_instance_added, _on_occupy_map_item_instance_added, true)
	_set_occupy_map_signal_connection(occupy_map.item_instance_removed, _on_occupy_map_item_instance_removed, true)
	_set_occupy_map_signal_connection(occupy_map.item_instance_position_changed, _on_occupy_map_item_instance_position_changed, true)
	_set_occupy_map_signal_connection(occupy_map.item_instance_rotated, _on_occupy_map_item_instance_rotated, true)
	_set_occupy_map_signal_connection(occupy_map.item_instance_cannot_be_handled, _on_occupy_map_item_instance_cannot_be_handled, true)
	_set_occupy_map_signal_connection(occupy_map.item_instance_corrected, _on_occupy_map_item_instance_corrected, true)

## 占位图新增物品实例时，同步背包列表并转发信号。
func _on_occupy_map_item_instance_added(item_instance_data: ItemInstanceData) -> void:
	if item_instances.has(item_instance_data):
		return
	item_instances.append(item_instance_data)
	item_added.emit(item_instance_data)

## 占位图移除物品实例时，同步背包列表并转发信号。
func _on_occupy_map_item_instance_removed(
	item_instance_data: ItemInstanceData,
	removed_center_cell: Vector2i
) -> void:
	item_instances.erase(item_instance_data)
	item_removed.emit(item_instance_data)
	item_removed_in_cell.emit(item_instance_data, removed_center_cell)

## 占位图物品换位时，转发位置变化信号。
func _on_occupy_map_item_instance_position_changed(
	item_instance_data: ItemInstanceData,
	previous_cell: Vector2i
) -> void:
	item_position_changed.emit(item_instance_data, previous_cell)

## 占位图物品旋转时，转发旋转信号。
func _on_occupy_map_item_instance_rotated(item_instance_data: ItemInstanceData) -> void:
	item_rotated.emit(item_instance_data)

## 占位图无法处理物品时，转发无法处理信号。
func _on_occupy_map_item_instance_cannot_be_handled(item_instance_data: ItemInstanceData) -> void:
	item_cannot_be_handled.emit(item_instance_data)

## 占位图物品校正成功时，转发校正成功信号。
func _on_occupy_map_item_instance_corrected(
	item_instance_data: ItemInstanceData,
	previous_cell: Vector2i
) -> void:
	item_corrected.emit(item_instance_data, previous_cell)

## 断开占位图资源上的变化信号。
func _disconnect_occupy_map_signals() -> void:
	if !occupy_map:
		return
	_set_occupy_map_signal_connection(occupy_map.map_changed, occupy_map_changed.emit, false)
	_set_occupy_map_signal_connection(occupy_map.item_instance_added, _on_occupy_map_item_instance_added, false)
	_set_occupy_map_signal_connection(occupy_map.item_instance_removed, _on_occupy_map_item_instance_removed, false)
	_set_occupy_map_signal_connection(occupy_map.item_instance_position_changed, _on_occupy_map_item_instance_position_changed, false)
	_set_occupy_map_signal_connection(occupy_map.item_instance_rotated, _on_occupy_map_item_instance_rotated, false)
	_set_occupy_map_signal_connection(occupy_map.item_instance_cannot_be_handled, _on_occupy_map_item_instance_cannot_be_handled, false)
	_set_occupy_map_signal_connection(occupy_map.item_instance_corrected, _on_occupy_map_item_instance_corrected, false)

## 根据目标状态设置占位图单条信号连接。
func _set_occupy_map_signal_connection(target_signal: Signal, target_callable: Callable, is_connect: bool) -> void:
	if is_connect:
		if !target_signal.is_connected(target_callable):
			target_signal.connect(target_callable)
	else:
		if target_signal.is_connected(target_callable):
			target_signal.disconnect(target_callable)

func init_occupy_map(cells: Array[Vector2i] = []) -> void:
	occupy_map.init_occupy_map(cells)
	process_wrong_item_instances()

## 按环形背包槽位数量初始化占位图（槽位沿 x 轴排列，单格物品模式）。
func init_loop_slot_occupy_map(slot_count: int) -> void:
	var slot_cells: Array[Vector2i] = []
	var safe_slot_count := maxi(1, slot_count)
	for slot_index in range(safe_slot_count):
		slot_cells.append(Vector2i(slot_index, 0))
	occupy_map.is_shape_item = false
	init_occupy_map(slot_cells)

func process_wrong_item_instances() -> void:
	for item_instance in item_instances.duplicate():
		if item_instance.num == 0:
			occupy_map.try_take_item_instance(item_instance)
#endregion

#region 跨背包转移
## 尝试移动所有物品至另一个背包
func try_move_item_instances_to_other_inventory_data(item_instance:ItemInstanceData,inventory_data:InventoryData):
	if can_take_item(item_instance):
		var res := inventory_data.try_add_item_with_merge(item_instance)
		if res:
			try_take_item(item_instance)
## 尝试移动所有物品至另一个背包
func try_move_all_item_instances_to_other_inventory_data(inventory_data:InventoryData):
	for item_instance in item_instances:
		if can_take_item(item_instance):
			var res := inventory_data.try_add_item_with_merge(item_instance)
			if res:
				try_take_item.call_deferred(item_instance)
#endregion

#region occupy_map交互接口
## 尝试将背包外的物品放置到指定格子；若物品已在背包内,请使用 try_move_item_to_cell方法。
func try_place_item_in_cell(item: ItemInstanceData, cell: Vector2i) -> bool:
	return occupy_map.try_place_item_instance_in_cell(item, cell)

## 尝试用输入物品替换目标格范围内的唯一物品，成功时返回被替换出的物品。
func try_replace_item_in_cell(item: ItemInstanceData, cell: Vector2i) -> ItemInstanceData:
	return occupy_map.try_replace_item_instance_in_cell(item, cell)

## 尝试将物品与指定格子内的同种未满物品融合。
func try_merge_item_in_cell(item: ItemInstanceData, cell: Vector2i) -> bool:
	return occupy_map.try_merge_item_instance_in_cell(item, cell)

## 尝试添加物品，不与现有物品进行融合
func try_add_item_without_merge(item:ItemInstanceData)->bool:
	return occupy_map.try_register_item_instance_at_free_cell(item)

## 尝试将已在背包内的物品移动到指定格子。
func try_move_item_to_cell(item: ItemInstanceData, cell: Vector2i) -> bool:
	return occupy_map.try_move_item_instance_to_cell(item, cell)

## 尝试旋转背包中的物品（默认顺时针 90 度）。
func try_rotate_item_in_inventory(item_instance_data: ItemInstanceData, rotate_step: int = 1) -> bool:
	return occupy_map.try_rotate_item_instance(item_instance_data, rotate_step)

## 尽力旋转背包中的物品，依次尝试 90°、180°、270° 旋转。
func try_rotate_item_in_inventory_best_effort(item_instance_data: ItemInstanceData) -> bool:
	return occupy_map.try_rotate_item_instance_best_effort(item_instance_data)

## 从背包中拿出特定物品
func try_take_item(item:ItemInstanceData)->bool:
	return occupy_map.try_take_item_instance(item)

## 向背包内添加物品，并与现有同种未满物品尝试合并。
func try_add_item_with_merge(item:ItemInstanceData)->bool:
	var unfull_same_items = get_unfull_same_items(item)
	for unfull_same_item in unfull_same_items:
		unfull_same_item.try_merge_item(item)
		if item.num == 0:
			break
	if item.num == 0:
		return true
	else:
		return try_add_item_without_merge(item)

## 从背包中拿出物品
func try_take_same_item(item_data:ItemData)->ItemInstanceData:
	var same_items = get_item_instance_datas_from_item_data(item_data)
	if !same_items.is_empty():
		var take_item = same_items.pop_front()
		if can_take_item(take_item):
			if !occupy_map.try_take_item_instance(take_item):
				return null
			return take_item
	return null

## 清除所有物品
func clear_all_item() -> void:
	if item_instances.is_empty():
		return
	item_instances.clear()
	occupy_map.clear_occupancy()
	inventory_cleared.emit()
#endregion

#region 整理流程
## 整理背包
func _sort():
	item_instances.sort_custom(_sort_by_name)
	merge_all_same_item()
	replace_all_item_instances()
## 尝试整理背包，成功后会发出 sorted 信号。
func try_sort_inventory() -> bool:
	if item_instances.is_empty():
		return false
	_sort()
	sorted.emit()
	return true
## 根据物品的名字判断物品a是否应该在物品b的前面
func _sort_by_name(item_instance_data_a:ItemInstanceData,item_instance_data_b:ItemInstanceData):
	if item_instance_data_a.get_item_name().casecmp_to(item_instance_data_b.get_item_name()) == 1:
		return true
	return false
## 刷新所有物品实例
func replace_all_item_instances():
	var previous_center_cells: Dictionary = {}
	for item in item_instances:
		if item.get_item_num() != 0:
			previous_center_cells[item] = occupy_map.get_item_center_cell(item)
	occupy_map.clear_occupancy()
	var zero_items:Array[ItemInstanceData]
	for item in item_instances:
		if item.get_item_num() == 0:
			zero_items.append(item)
			continue
		var previous_cell: Vector2i = previous_center_cells.get(item, Vector2i(-1, -1))
		if occupy_map.try_relayout_item_instance(item):
			var new_center_cell := occupy_map.get_item_center_cell(item)
			if previous_cell != new_center_cell:
				item_position_changed.emit(item, previous_cell)
	for zero_item in zero_items:
		item_instances.erase(zero_item)
## 合并所有的物品
func merge_all_same_item():
	var unfull_items := get_unfull_items()
	for item in unfull_items:
		var unfull_same_items := get_unfull_same_items(item)
		unfull_same_items.erase(item)
		for unfull_same_item in unfull_same_items:
			item.try_merge_item(unfull_same_item)
			if unfull_same_item.num == 0:
				unfull_items.erase(unfull_same_item)
				item_instances.erase(unfull_same_item)
			if item.num == item.get_item_max_num():
				break
#endregion

#region 查询接口
## 获取背包数据中的所有物品实例数据
func get_item_instances()->Array[ItemInstanceData]:
	return item_instances
## 获取背包占位图资源。
func get_occupy_map() -> InventoryOccupyMap:
	return occupy_map
## 获取背包内所有拥有 item_data 数据的背包物品数量
func get_item_instance_num_from_item_data(item_data:ItemData)->int:
	var num:int = 0
	for item_in_inventory in item_instances:
		if item_in_inventory.item_data == item_data:
			num += 1
	return num
## 获取背包内所有拥有 item_data 数据的物品总数量（num 求和）。
func get_item_total_num_from_item_data(item_data: ItemData) -> int:
	var total_num: int = 0
	for item_in_inventory in item_instances:
		if item_in_inventory.item_data == item_data:
			total_num += item_in_inventory.num
	return total_num
## 获取背包内所有拥有 item_data 数据的背包物品数据
func get_item_instance_datas_from_item_data(item_data:ItemData)->Array[ItemInstanceData]:
	var same_items:Array[ItemInstanceData]
	for item_in_inventory in item_instances:
		if item_in_inventory.item_data == item_data:
			same_items.append(item_in_inventory)
	return same_items
## 获取背包内种类相同且堆叠未满的物品
func get_unfull_same_items(item:ItemInstanceData)->Array[ItemInstanceData]:
	var same_items:Array[ItemInstanceData] = get_item_instance_datas_from_item_data(item.item_data)
	var unfull_items:Array[ItemInstanceData]
	for item_in_inventory in same_items:
		if item_in_inventory.num < item.get_item_max_num():
			unfull_items.append(item_in_inventory)
	return unfull_items
## 获取背包内种类相同且堆叠未满的物品
func get_unfull_items()->Array[ItemInstanceData]:
	var unfull_items:Array[ItemInstanceData]
	for item in item_instances:
		if item.num < item.get_item_max_num():
			unfull_items.append(item)
	return unfull_items
#endregion

#region 基础判断
## 背包数据中是否有此类物品
func has_item_data(item_data:ItemData)->bool:
	for item_in_inventory in item_instances:
		if item_in_inventory.item_data == item_data:
			return true
	return false
## 背包数据中是否有该物品实例数据
func has_item_instance(item_instance:ItemInstanceData)->bool:
	return item_instances.has(item_instance)
## 该物品是否能够拿取
func can_take_item(_item_instance_data:ItemInstanceData)->bool:
	return true
## 判断背包中的物品是否能够按指定步数旋转。
func can_rotate_item_in_inventory(item_instance_data: ItemInstanceData, rotate_step: int = 1) -> bool:
	if item_instance_data == null:
		return false
	if !has_item_instance(item_instance_data):
		return false
	return InventoryOccupyMapQuery.can_rotate_item_in_place(occupy_map, item_instance_data, rotate_step)
#endregion

#region occupy_map 委托判断
## 判断背包是否已满
func is_full() -> bool:
	return occupy_map.is_full()
## 判断背包是否能够添加该物品
func can_add_item(item: ItemInstanceData) -> bool:
	return InventoryOccupyMapQuery.can_add_item(occupy_map, item)
## 判断背包是否能够直接添加该物品（不进行融合）。
func can_add_item_without_merge(item: ItemInstanceData) -> bool:
	return InventoryOccupyMapQuery.can_add_item_without_merge(occupy_map, item)
## 判断指定格子中的目标物品是否可以与传入物品融合。
func can_merge_item_in_cell(item: ItemInstanceData, cell: Vector2i) -> bool:
	return InventoryOccupyMapQuery.can_merge_item_in_cell(occupy_map, item, cell)
## 判断指定格子是否可以放置该物品。
func can_place_item_in_cell(item: ItemInstanceData, cell: Vector2i) -> bool:
	return InventoryOccupyMapQuery.can_place_item_in_cell(occupy_map, item, cell)
## 判断指定格子是否可以被该物品替换放置。
func can_replace_item_in_cell(item: ItemInstanceData, cell: Vector2i) -> bool:
	return InventoryOccupyMapQuery.can_replace_item_in_cell(occupy_map, item, cell)
#endregion
