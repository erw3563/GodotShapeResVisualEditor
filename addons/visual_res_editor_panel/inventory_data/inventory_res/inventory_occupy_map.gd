@tool
class_name InventoryOccupyMap
extends OccupyMap
## InventoryOccupyMap 是 InventoryData 专用的占位图资源。
## 该类在 OccupyMap 的基础上，提供 ItemInstanceData 友好的方法。

#region 信号
## 物品实例首次注册到占位图时触发。
signal item_instance_added(item_instance_data: ItemInstanceData)
## 物品实例从占位图移除时触发（removed_center_cell 为移除前的中心格坐标）。
signal item_instance_removed(item_instance_data: ItemInstanceData, removed_center_cell: Vector2i)
## 物品实例在占位图内的中心格位置发生变化时触发（previous_cell 为变化前的中心格坐标）。
signal item_instance_position_changed(item_instance_data: ItemInstanceData, previous_cell: Vector2i)
## 物品实例在占位图内旋转时触发。
signal item_instance_rotated(item_instance_data: ItemInstanceData)
## 单个物品实例占位校正完成时触发（重叠或越界坐标已重新注册）。
signal item_instance_corrected(item_instance_data: ItemInstanceData, previous_cell: Vector2i)
## 无法找到合法位置处理该物品实例时触发（重叠或越界且背包无可用空位）。
signal item_instance_cannot_be_handled(item_instance_data: ItemInstanceData)
#endregion

#region 数据字段
## 是否按形状物品规则处理占位。
@export var is_shape_item: bool = true
## 已在占位图中成功占据格子的物品实例。
@export var placed_item_instances: Array[ItemInstanceData] = []
## 尚未在占位图中占据格子的物品实例。
@export var unplaced_item_instances: Array[ItemInstanceData] = []
## 物品实例到其注册中心格的映射，用于在移除时获取稳定的原位置。
var occupant_to_center_cell: Dictionary = {}
#endregion

#region 区域初始化
## 初始化合法区域格子（会清空占据状态）。
func init_occupy_map(cells: Array[Vector2i] = []) -> void:
	if cells.is_empty():
		set_region_cells([Vector2i.ZERO])
	else:
		set_region_cells(cells)
#endregion

#region 校正
func _on_map_changed():
	super._on_map_changed()
	process_wrong_item_instances()

## 处理错误的物品实例，修正重叠或越界坐标并重新注册占位。
func process_wrong_item_instances() -> void:
	for item_instance_data in placed_item_instances.duplicate():
		process_wrong_item_instance(item_instance_data)
	for item_instance_data in unplaced_item_instances.duplicate():
		process_wrong_item_instance(item_instance_data)

## 校正单个物品实例的占位，成功校正时返回 true，无需校正或校正失败时返回 false。
func process_wrong_item_instance(item_instance_data: ItemInstanceData) -> bool:
	if item_instance_data == null:
		return false
	if is_shape_item:
		return _process_wrong_shape_item_instance(item_instance_data)
	else:
		return _process_wrong_non_shape_item_instance(item_instance_data)

## 将无法放置的物品移入未放置列表并发出信号。
func _handle_item_instance_cannot_be_placed(item_instance_data: ItemInstanceData) -> void:
	if item_instance_data == null:
		return
	placed_item_instances.erase(item_instance_data)
	if !unplaced_item_instances.has(item_instance_data):
		unplaced_item_instances.append(item_instance_data)
	item_instance_cannot_be_handled.emit(item_instance_data)
	print("物品 |" + item_instance_data.get_item_name() + "| 因空间不足而无法放置。")

#region 形状校正
## 校正形状物品的占位（支持自动旋转寻位）。
func _process_wrong_shape_item_instance(item_instance_data: ItemInstanceData) -> bool:
	var placement := InventoryOccupyMapQuery.get_free_cell_to_place_item_with_rotations(
		self, item_instance_data, true
	)
	if placement.cell == Vector2i(-1, -1):
		_handle_item_instance_cannot_be_placed(item_instance_data)
		return false
	if InventoryOccupyMapQuery.does_item_instance_need_correction(
			self, item_instance_data, placement.cell, placement.rotate_num):
		var previous_cell := get_item_center_cell(item_instance_data)
		if !try_register_item_instance_at_placement(
				item_instance_data, placement.cell, placement.rotate_num):
			return false
		item_instance_corrected.emit(item_instance_data, previous_cell)
	return true
#endregion

#region 非形状校正
## 校正非形状物品（单格 / 循环槽位）的占位。
func _process_wrong_non_shape_item_instance(item_instance_data: ItemInstanceData) -> bool:
	var target_cell := InventoryOccupyMapQuery.get_free_cell_to_place_non_shape_item(self, item_instance_data)
	if target_cell == Vector2i(-1, -1):
		_handle_item_instance_cannot_be_placed(item_instance_data)
		return false
	if InventoryOccupyMapQuery.does_non_shape_item_instance_need_correction(
			self, item_instance_data, target_cell):
		var previous_cell := get_item_center_cell(item_instance_data)
		var is_corrected := false
		if occupant_to_cells.has(item_instance_data):
			is_corrected = try_move_item_instance_to_cell(item_instance_data, target_cell)
		else:
			is_corrected = try_place_item_instance_in_cell(item_instance_data, target_cell)
		if !is_corrected:
			return false
		item_instance_corrected.emit(item_instance_data, previous_cell)
	return true
#endregion
#endregion

#region 占据
## 尝试占据一组格子（列表维护由上层交互方法在成功后负责）。
func try_occupy(occupant: Variant, target_cells: Array[Vector2i]) -> bool:
	if !occupant is ItemInstanceData:
		return false
	var item_instance_data := occupant as ItemInstanceData
	if super.try_occupy(item_instance_data, target_cells):
		return true
	else:
		return false

## 释放某占据者占据的所有格子。
func release_occupant(occupant: Variant) -> void:
	if !occupant_to_cells.has(occupant):
		return
	super.release_occupant(occupant)
	occupant_to_center_cell.erase(occupant)


## 清空所有占据并同步清理中心格映射。
func clear_occupancy() -> void:
	var items_to_correct := placed_item_instances.duplicate()
	super.clear_occupancy()
	occupant_to_center_cell.clear()
	placed_item_instances.clear()

## 清空全部区域和占据并同步清理中心格映射。
func clear_all() -> void:
	super.clear_all()
	occupant_to_center_cell.clear()
	placed_item_instances.clear()
	unplaced_item_instances.clear()

## 尝试将物品实例注册到可用中心格（自动选择位置）。
func try_register_item_instance_at_free_cell(
	item_instance_data: ItemInstanceData,
	prefer_current_position: bool = true
) -> bool:
	if is_shape_item:
		return _try_register_shape_item_instance_at_free_cell(item_instance_data, prefer_current_position)
	else:
		return _try_register_non_shape_item_instance_at_free_cell(item_instance_data, prefer_current_position)

#region 形状注册
## 尝试将形状物品实例注册到可用中心格（支持自动旋转寻位）。
func _try_register_shape_item_instance_at_free_cell(
	item_instance_data: ItemInstanceData,
	prefer_current_position: bool = true
) -> bool:
	var placement := InventoryOccupyMapQuery.get_free_cell_to_place_item_with_rotations(
		self, item_instance_data, prefer_current_position
	)
	return try_register_item_instance_at_placement(
		item_instance_data, placement.cell, placement.rotate_num
	)
#endregion

#region 非形状注册
## 尝试将非形状物品实例注册到可用格子。
func _try_register_non_shape_item_instance_at_free_cell(
	item_instance_data: ItemInstanceData,
	prefer_current_position: bool = true
) -> bool:
	var target_cell := InventoryOccupyMapQuery.get_free_cell_to_place_non_shape_item(
		self, item_instance_data, prefer_current_position
	)
	if occupant_to_cells.has(item_instance_data):
		return try_move_item_instance_to_cell(item_instance_data, target_cell)
	return try_place_item_instance_in_cell(item_instance_data, target_cell)
#endregion

## 尝试重新布局物品实例（忽略当前坐标，重新寻找可用位置）。
func try_relayout_item_instance(item_instance_data: ItemInstanceData) -> bool:
	return try_register_item_instance_at_free_cell(item_instance_data, false)
#endregion

#region 获取占据
## 获取物品实例在占位图中的中心格坐标；未注册占位时返回 Vector2i(-1, -1)。
func get_item_center_cell(item_instance_data: ItemInstanceData) -> Vector2i:
	if item_instance_data == null:
		return Vector2i(-1, -1)
	if occupant_to_center_cell.has(item_instance_data):
		return occupant_to_center_cell[item_instance_data]
	if !occupant_to_cells.has(item_instance_data):
		return Vector2i(-1, -1)
	var inferred_center_cell := _infer_item_center_cell_from_occupancy(item_instance_data)
	if inferred_center_cell != Vector2i(-1, -1):
		occupant_to_center_cell[item_instance_data] = inferred_center_cell
	return inferred_center_cell

## 获取指定格子中的物品实例。
func get_item_in_cell(cell: Vector2i) -> ItemInstanceData:
	return get_occupant(cell) as ItemInstanceData
#endregion

#region 物品列表维护
## 将物品实例登记为已放置，并从未放置列表移除。
func _add_to_placed_item_instance(item_instance_data: ItemInstanceData) -> void:
	if item_instance_data == null:
		return
	unplaced_item_instances.erase(item_instance_data)
	if !placed_item_instances.has(item_instance_data):
		placed_item_instances.append(item_instance_data)
#endregion

#region 交互
## 记录物品实例在占位图中的中心格坐标。
func _sync_item_instance_center_cell(item_instance_data: ItemInstanceData, center_cell: Vector2i) -> void:
	occupant_to_center_cell[item_instance_data] = center_cell

#region 形状交互
## 尝试将物品实例按指定中心格与朝向注册到占位图。
func try_register_item_instance_at_placement(
	item_instance_data: ItemInstanceData,
	target_cell: Vector2i,
	target_rotate_num: int
) -> bool:
	if item_instance_data == null or target_cell == Vector2i(-1, -1):
		return false
	var original_rotate_num := item_instance_data.rotate_num
	var is_already_placed := occupant_to_cells.has(item_instance_data)
	var previous_cell := get_item_center_cell(item_instance_data) if is_already_placed else Vector2i(-1, -1)
	item_instance_data.rotate_num = target_rotate_num
	if !InventoryOccupyMapQuery.can_place_item_in_cell(self, item_instance_data, target_cell):
		item_instance_data.rotate_num = original_rotate_num
		return false
	var target_cells := item_instance_data.get_cells(target_cell)
	if !try_occupy(item_instance_data, target_cells):
		item_instance_data.rotate_num = original_rotate_num
		return false
	_sync_item_instance_center_cell(item_instance_data, target_cell)
	_add_to_placed_item_instance(item_instance_data)
	if is_already_placed:
		if previous_cell != target_cell:
			item_instance_position_changed.emit(item_instance_data, previous_cell)
	else:
		item_instance_added.emit(item_instance_data)
	if target_rotate_num != original_rotate_num:
		item_instance_rotated.emit(item_instance_data)
	return true

## 尝试旋转占位图中的物品实例（默认顺时针 90 度）。
func try_rotate_item_instance(item_instance_data: ItemInstanceData, rotate_step: int = 1) -> bool:
	if item_instance_data == null or !occupant_to_cells.has(item_instance_data):
		return false
	if !InventoryOccupyMapQuery.can_rotate_item_in_place(self, item_instance_data, rotate_step):
		return false
	var center_cell := get_item_center_cell(item_instance_data)
	var target_rotate_num := posmod(item_instance_data.rotate_num + rotate_step, 4)
	var target_cells := InventoryOccupyMapQuery.get_target_cells_for_rotate(self, item_instance_data, rotate_step)
	if target_cells.is_empty():
		return false
	if !try_occupy(item_instance_data, target_cells):
		return false
	item_instance_data.rotate_num = target_rotate_num
	_sync_item_instance_center_cell(item_instance_data, center_cell)
	_add_to_placed_item_instance(item_instance_data)
	item_instance_rotated.emit(item_instance_data)
	return true

## 尽力旋转占位图中的物品实例，依次尝试 90°、180°、270° 旋转。
func try_rotate_item_instance_best_effort(item_instance_data: ItemInstanceData) -> bool:
	for rotate_step in [1, 2, 3]:
		if try_rotate_item_instance(item_instance_data, rotate_step):
			return true
	return false
#endregion

## 尝试为物品实例注册占据位置。
func try_add_item_instance(item_instance_data: ItemInstanceData) -> bool:
	return try_register_item_instance_at_free_cell(item_instance_data)

## 尝试将物品实例放置到指定中心格（仅适用于尚未注册在位图中的物品）。
func try_place_item_instance_in_cell(item_instance_data: ItemInstanceData, center_cell: Vector2i) -> bool:
	if item_instance_data == null or occupant_to_cells.has(item_instance_data):
		return false
	if !InventoryOccupyMapQuery.can_place_item_in_cell(self, item_instance_data, center_cell):
		return false
	if try_occupy(item_instance_data, item_instance_data.get_cells(center_cell)):
		_sync_item_instance_center_cell(item_instance_data, center_cell)
		_add_to_placed_item_instance(item_instance_data)
		item_instance_added.emit(item_instance_data)
		return true
	return false

## 尝试从占位图中移除物品实例。
func try_remove_item_instance(item_instance_data: ItemInstanceData) -> bool:
	if item_instance_data == null or !occupant_to_cells.has(item_instance_data):
		return false
	var removed_center_cell := get_item_center_cell(item_instance_data)
	release_occupant(item_instance_data)
	placed_item_instances.erase(item_instance_data)
	unplaced_item_instances.erase(item_instance_data)
	item_instance_removed.emit(item_instance_data, removed_center_cell)
	return true

## 尝试从占位图中拿取物品实例。
func try_take_item_instance(item_instance_data: ItemInstanceData) -> bool:
	return try_remove_item_instance(item_instance_data)

## 尝试将位图内的物品实例移动到指定中心格。
func try_move_item_instance_to_cell(item_instance_data: ItemInstanceData, center_cell: Vector2i) -> bool:
	if item_instance_data == null or !occupant_to_cells.has(item_instance_data):
		return false

	var previous_cell := get_item_center_cell(item_instance_data)
	if previous_cell == center_cell:
		return true

	if InventoryOccupyMapQuery.can_place_item_in_cell(self, item_instance_data, center_cell):
		if try_occupy(item_instance_data, item_instance_data.get_cells(center_cell)):
			_sync_item_instance_center_cell(item_instance_data, center_cell)
			_add_to_placed_item_instance(item_instance_data)
			item_instance_position_changed.emit(item_instance_data, previous_cell)
			return true
	return false

## 尝试将物品实例与目标格子处的物品实例合并。
func try_merge_item_instance_in_cell(item_instance_data: ItemInstanceData, cell: Vector2i) -> bool:
	if item_instance_data == null:
		return false
	if !InventoryOccupyMapQuery.can_merge_item_in_cell(self, item_instance_data, cell):
		return false
	var target_item := get_item_in_cell(cell)
	if target_item == null or target_item == item_instance_data:
		return false
	if !target_item.try_merge_item(item_instance_data):
		return false
	if item_instance_data.num == 0 and occupant_to_cells.has(item_instance_data):
		try_remove_item_instance(item_instance_data)
	return true

## 尝试用物品实例替换目标格范围内的唯一物品，成功时返回被替换出的物品实例。
func try_replace_item_instance_in_cell(item_instance_data: ItemInstanceData, center_cell: Vector2i) -> ItemInstanceData:
	var replace_target := InventoryOccupyMapQuery.get_replace_target_item(self, item_instance_data, center_cell)
	if replace_target == null:
		return null
	var replaced_center_cell := get_item_center_cell(replace_target)
	if try_remove_item_instance(replace_target):
		var is_placed := false
		if occupant_to_cells.has(item_instance_data):
			is_placed = try_move_item_instance_to_cell(item_instance_data, center_cell)
		else:
			is_placed = try_place_item_instance_in_cell(item_instance_data, center_cell)
		if !is_placed:
			try_place_item_instance_in_cell(replace_target, replaced_center_cell)
			return null
		return replace_target
	else:
		return null

## 根据当前占据格子反推物品实例的中心格。
func _infer_item_center_cell_from_occupancy(item_instance_data: ItemInstanceData) -> Vector2i:
	var occupied_cells := get_cells_of_occupant(item_instance_data)
	if occupied_cells.is_empty():
		return Vector2i(-1, -1)
	if !is_shape_item or occupied_cells.size() == 1:
		return occupied_cells[0]
	var local_cells: Array[Vector2i]
	if item_instance_data.item_data and item_instance_data.item_data.shape:
		local_cells = item_instance_data.item_data.shape.get_cells()
	else:
		local_cells = [Vector2i.ZERO]
	var rotated_local_cells := ShapeTransform.rotate_cells_90(local_cells, item_instance_data.rotate_num)
	var inferred_center_cell := occupied_cells[0] - rotated_local_cells[0]
	if _are_cell_sets_equal(item_instance_data.get_cells(inferred_center_cell), occupied_cells):
		return inferred_center_cell
	return Vector2i(-1, -1)

## 判断两组格子坐标是否表示同一占据区域。
func _are_cell_sets_equal(cells_a: Array[Vector2i], cells_b: Array[Vector2i]) -> bool:
	if cells_a.size() != cells_b.size():
		return false
	for cell in cells_a:
		if !cells_b.has(cell):
			return false
	return true
#endregion
