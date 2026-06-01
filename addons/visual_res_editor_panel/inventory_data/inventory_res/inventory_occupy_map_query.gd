class_name InventoryOccupyMapQuery
extends RefCounted
## InventoryOccupyMapQuery 负责背包占位图的只读查询（判定 + 寻位）。

#region 寻位
## 获取可放下物品的格子（按占位图模式分发）。
static func get_free_cell_to_place_item_by_mode(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	prefer_current_position: bool = true
) -> Vector2i:
	if occupy_map.is_shape_item:
		return get_free_cell_to_place_shape_item(occupy_map, item_instance_data, prefer_current_position)
	return get_free_cell_to_place_non_shape_item(occupy_map, item_instance_data, prefer_current_position)

#region 形状寻位
## 获取可放下物品的格子与朝向；优先当前朝向，再依次尝试 90°、180°、270° 旋转。
## 返回 Dictionary：cell（Vector2i）、rotate_num（int）。
static func get_free_cell_to_place_item_with_rotations(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	prefer_current_position: bool = true
) -> Dictionary:
	var original_rotate_num := item_instance_data.rotate_num
	if prefer_current_position and occupy_map.occupant_to_cells.has(item_instance_data):
		var current_center_cell := occupy_map.get_item_center_cell(item_instance_data)
		if current_center_cell != Vector2i(-1, -1):
			for step in range(4):
				var try_rotate_num := posmod(original_rotate_num + step, 4)
				var target_cells := item_instance_data.get_cells_with_rotate_num(
					try_rotate_num, current_center_cell
				)
				if occupy_map.can_occupy(target_cells, item_instance_data):
					return {"cell": current_center_cell, "rotate_num": try_rotate_num}
	for step in range(4):
		var try_rotate_num := posmod(original_rotate_num + step, 4)
		var shape_cells := item_instance_data.get_cells_with_rotate_num(try_rotate_num, Vector2i.ZERO)
		var free_cell := occupy_map.get_free_center_cell_to_shape_occupy(shape_cells, item_instance_data)
		if free_cell != Vector2i(-1, -1):
			return {"cell": free_cell, "rotate_num": try_rotate_num}
	return {"cell": Vector2i(-1, -1), "rotate_num": original_rotate_num}

## 获取可放下形状物品的格子，优先返回物品当前格子。
static func get_free_cell_to_place_shape_item(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	prefer_current_position: bool = true
) -> Vector2i:
	var placement := get_free_cell_to_place_item_with_rotations(
		occupy_map, item_instance_data, prefer_current_position
	)
	return placement.cell
#endregion

#region 非形状寻位
## 获取可放下非形状物品的格子，优先返回物品当前格子。
static func get_free_cell_to_place_non_shape_item(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	prefer_current_position: bool = true
) -> Vector2i:
	if prefer_current_position and occupy_map.occupant_to_cells.has(item_instance_data):
		var current_center_cell := occupy_map.get_item_center_cell(item_instance_data)
		if occupy_map.has_region_cell(current_center_cell) and !occupy_map.is_occupied(current_center_cell):
			return current_center_cell
	return occupy_map.get_first_free_cell()
#endregion
#endregion

#region 目标物品
## 收集目标占格内命中的不重复物品实例（可排除指定物品）。
static func get_unique_items_in_target_cells(
	occupy_map: InventoryOccupyMap,
	target_cells: Array[Vector2i],
	exclude_item_instance: ItemInstanceData = null
) -> Array[ItemInstanceData]:
	var unique_items: Array[ItemInstanceData] = []
	for target_cell in target_cells:
		var item_in_cell := occupy_map.get_item_in_cell(target_cell)
		if item_in_cell == null:
			continue
		if exclude_item_instance != null and item_in_cell == exclude_item_instance:
			continue
		if !unique_items.has(item_in_cell):
			unique_items.append(item_in_cell)
	return unique_items

## 获取可被替换的唯一目标物品；条件不满足时返回 null。
static func get_replace_target_item(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	center_cell: Vector2i
) -> ItemInstanceData:
	if item_instance_data == null:
		return null
	var target_cells := item_instance_data.get_cells(center_cell)
	if target_cells.is_empty() or !are_all_cells_in_region(occupy_map, target_cells):
		return null
	var hit_items := get_unique_items_in_target_cells(occupy_map, target_cells, item_instance_data)
	if hit_items.size() != 1:
		return null
	var replace_target := hit_items[0]
	if replace_target == item_instance_data:
		return null
	if !occupy_map.can_occupy(target_cells, replace_target):
		return null
	return replace_target
#endregion

#region 判定添加
## 判断背包在当前模式下是否还能放入该物品（不进行融合）。
static func can_add_item_without_merge(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData
) -> bool:
	if occupy_map.is_full():
		return false
	if occupy_map.is_shape_item:
		return can_add_shape_item_without_merge(occupy_map, item_instance_data)
	return can_add_non_shape_item_without_merge(occupy_map, item_instance_data)

## 判断背包在当前模式下是否还能放入该物品（含融合空间）。
static func can_add_item(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData
) -> bool:
	var merge_space := 0
	for in_item_instance_data in get_all_tracked_item_instances(occupy_map):
		if in_item_instance_data.is_same_item(item_instance_data):
			merge_space += in_item_instance_data.get_remain_space_num()
			if merge_space >= item_instance_data.num:
				return true
	return can_add_item_without_merge(occupy_map, item_instance_data)

#region 形状添加判定
## 判断形状物品在任意朝向下是否还能放入背包。
static func can_add_shape_item_without_merge(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData
) -> bool:
	return can_shape_occupy_with_rotations(occupy_map, item_instance_data)

## 判断形状物品在任意朝向下是否还能放入背包。
static func can_shape_occupy_with_rotations(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData
) -> bool:
	var original_rotate_num := item_instance_data.rotate_num
	for step in range(4):
		var try_rotate_num := posmod(original_rotate_num + step, 4)
		var shape_cells := item_instance_data.get_cells_with_rotate_num(try_rotate_num, Vector2i.ZERO)
		if occupy_map.can_shape_occupy(shape_cells, item_instance_data):
			return true
	return false
#endregion

#region 非形状添加判定
## 判断非形状物品是否还能放入背包。
static func can_add_non_shape_item_without_merge(
	_occupy_map: InventoryOccupyMap,
	_item_instance_data: ItemInstanceData
) -> bool:
	return true
#endregion
#endregion

#region 判定放置
## 判断物品是否能够放置到指定格子（移动判定与放置共用此方法）。
static func can_place_item_in_cell(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	cell: Vector2i
) -> bool:
	if occupy_map.is_shape_item:
		return can_place_shape_item_in_cell(occupy_map, item_instance_data, cell)
	return can_place_non_shape_item_in_cell(occupy_map, cell)

## 判断手持物品是否可替换指定中心格范围内的唯一物品。
static func can_replace_item_in_cell(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	center_cell: Vector2i
) -> bool:
	return get_replace_target_item(occupy_map, item_instance_data, center_cell) != null

## 判断物品是否能与目标格子的物品融合。
static func can_merge_item_in_cell(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	cell: Vector2i
) -> bool:
	if !occupy_map.is_occupied(cell):
		return false
	var in_item := occupy_map.get_item_in_cell(cell)
	if in_item == null:
		return false
	return in_item.get_item_data() == item_instance_data.get_item_data() and !in_item.is_full()

#region 形状放置判定
## 判断形状物品是否能够放置到指定格子。
static func can_place_shape_item_in_cell(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	cell: Vector2i
) -> bool:
	return occupy_map.can_occupy(item_instance_data.get_cells(cell), item_instance_data)
#endregion

#region 非形状放置判定
## 判断非形状物品是否能够放置到指定格子。
static func can_place_non_shape_item_in_cell(occupy_map: InventoryOccupyMap, cell: Vector2i) -> bool:
	return !occupy_map.is_occupied(cell)
#endregion
#endregion

#region 判定旋转
## 判断物品在背包内按指定步数旋转后是否仍可占据当前中心格。
static func can_rotate_item_in_place(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	rotate_step: int = 1
) -> bool:
	if item_instance_data == null:
		return false
	var center_cell := occupy_map.get_item_center_cell(item_instance_data)
	if center_cell == Vector2i(-1, -1):
		return false
	var target_rotate_num := posmod(item_instance_data.rotate_num + rotate_step, 4)
	var target_cells := item_instance_data.get_cells_with_rotate_num(target_rotate_num, center_cell)
	return occupy_map.can_occupy(target_cells, item_instance_data)

## 获取物品在背包内按指定步数旋转后的目标占据格子。
static func get_target_cells_for_rotate(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	rotate_step: int = 1
) -> Array[Vector2i]:
	if item_instance_data == null:
		return []
	var center_cell := occupy_map.get_item_center_cell(item_instance_data)
	if center_cell == Vector2i(-1, -1):
		return []
	var target_rotate_num := posmod(item_instance_data.rotate_num + rotate_step, 4)
	return item_instance_data.get_cells_with_rotate_num(target_rotate_num, center_cell)
#endregion

#region 判定校正
## 判断物品实例在当前占位状态下是否需要校正。
static func does_item_instance_need_correction(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	target_cell: Vector2i,
	target_rotate_num: int = -1
) -> bool:
	if !occupy_map.occupant_to_cells.has(item_instance_data):
		return true
	if occupy_map.get_item_center_cell(item_instance_data) != target_cell:
		return true
	if occupy_map.is_shape_item:
		return does_shape_item_instance_need_correction(
			occupy_map, item_instance_data, target_cell, target_rotate_num
		)
	return does_non_shape_item_instance_need_correction(occupy_map, item_instance_data, target_cell)

#region 形状校正判定
## 判断形状物品实例是否需要校正。
static func does_shape_item_instance_need_correction(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	target_cell: Vector2i,
	target_rotate_num: int = -1
) -> bool:
	if target_rotate_num >= 0 and item_instance_data.rotate_num != target_rotate_num:
		return true
	var check_rotate_num := item_instance_data.rotate_num
	if target_rotate_num >= 0:
		check_rotate_num = target_rotate_num
	return !occupy_map.can_occupy(
		item_instance_data.get_cells_with_rotate_num(check_rotate_num, target_cell),
		item_instance_data
	)
#endregion

#region 非形状校正判定
## 判断非形状物品实例是否需要校正。
static func does_non_shape_item_instance_need_correction(
	occupy_map: InventoryOccupyMap,
	item_instance_data: ItemInstanceData,
	target_cell: Vector2i
) -> bool:
	if !occupy_map.has_region_cell(target_cell):
		return true
	return occupy_map.get_occupant(target_cell) != item_instance_data
#endregion
#endregion

#region 内部工具
## 获取已放置与未放置物品实例的合并列表（去重）。
static func get_all_tracked_item_instances(occupy_map: InventoryOccupyMap) -> Array[ItemInstanceData]:
	var all_item_instances: Array[ItemInstanceData] = []
	all_item_instances.append_array(occupy_map.placed_item_instances)
	for item_instance_data in occupy_map.unplaced_item_instances:
		if !all_item_instances.has(item_instance_data):
			all_item_instances.append(item_instance_data)
	return all_item_instances

## 判断目标占格是否全部位于合法区域内。
static func are_all_cells_in_region(occupy_map: InventoryOccupyMap, target_cells: Array[Vector2i]) -> bool:
	for target_cell in target_cells:
		if !occupy_map.has_region_cell(target_cell):
			return false
	return true
#endregion
