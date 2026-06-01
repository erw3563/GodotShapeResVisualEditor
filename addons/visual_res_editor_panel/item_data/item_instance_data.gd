@tool
class_name ItemInstanceData
extends Resource
## ItemInstanceData 是物品的数据。它负责记录物品会经常变化的数据。

signal num_changed(num:int)
signal rotate_num_changed(num:int)

## 物品数据
@export var item_data:ItemData:
	set(value):
		item_data = value
		
		update_inventory_item_data()
## 物品数量
@export var num:int = 1:
	set(value):
		num = clampi(value,0,get_item_max_num())
		num_changed.emit(num)
## 表示物品旋转了90*rotate_num度数
@export_range(0,3) var rotate_num:int:
	set(value):
		rotate_num = value
		if rotate_num > 3:
			rotate_num = 0
		rotate_num_changed.emit(rotate_num)

## 初始化 ItemInstanceData ，该方法需要手动调用。
func init(item_data_:ItemData,num_:int = 1) -> void:
	item_data = item_data_
	num = num_
## 更新背包物品数据
func update_inventory_item_data() -> void:
	if item_data == null:
		return
	item_data.max_num = max(1, item_data.max_num)
## 尝试将物品与自身堆叠
func try_merge_item(inventory_item_data:ItemInstanceData)->bool:
	if item_data != inventory_item_data.item_data:
		return false
	if num >= get_item_max_num():
		return false
	
	if num + inventory_item_data.num <= get_item_max_num():
		# 自身数量加要堆叠的物品数量小于物品的最大堆叠数量
		num += inventory_item_data.num
		inventory_item_data.num = 0
	else:
		# 自身数量加要堆叠的物品数量大于物品的最大堆叠数量
		inventory_item_data.num = num + inventory_item_data.num - get_item_max_num()
		num = get_item_max_num()
	return true
## 将自身一分为二
## - split_num: 分离出的物品数量，如果不足则将返回null。
func split(split_num:int)->ItemInstanceData:
	var new_inventory_item_data:ItemInstanceData
	if num <= split_num:
		new_inventory_item_data = null
	else:
		num -= split_num
		new_inventory_item_data = ItemInstanceData.new()
		new_inventory_item_data.init(item_data,split_num)
	return new_inventory_item_data

func is_full()->bool:
	return num >= get_item_max_num()

#region 获取数据方法
## 获取物品数据
func get_item_data()->ItemData:
	return item_data
## 获取物品名字
func get_item_name()->String:
	if item_data == null:
		return ""
	return item_data.item_name
## 获取物品图标纹理
func get_item_icon()->Texture2D:
	if item_data == null:
		return null
	return item_data.icon
## 获取当前的物品数量
func get_item_num()->int:
	return num
## 获取单堆最大可堆叠数量
func get_item_max_num()->int:
	if item_data == null:
		return 1
	return max(1, item_data.max_num)
## 获取还能放置的物品数量
func get_remain_space_num()->int:
	return get_item_max_num() - num
## 获取物品描述文本
func get_item_description()->String:
	if item_data == null:
		return ""
	return item_data.item_description
## 获取该物品当前旋转状态下占据的格子坐标。
## custom_center 为占位图内的中心格坐标。
func get_cells(custom_center: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var local_cells:Array[Vector2i]
	if item_data and item_data.shape:
		local_cells = item_data.shape.get_cells()
	else:
		local_cells = [Vector2i(0,0)]
	return ShapeTransform.transform_cells(local_cells, rotate_num, custom_center)
## 获取该物品在指定旋转状态下占据的格子坐标，不会修改当前 rotate_num。
func get_cells_with_rotate_num(custom_rotate_num: int, custom_center: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var local_cells:Array[Vector2i]
	if item_data and item_data.shape:
		local_cells = item_data.shape.get_cells()
	else:
		local_cells = [Vector2i(0,0)]
	var normalized_rotate_num := posmod(custom_rotate_num, 4)
	return ShapeTransform.transform_cells(local_cells, normalized_rotate_num, custom_center)
## 获取物品中心坐标。返回的坐标会根据 custom_center 进行坐标转换
func get_center_cell(custom_center: Vector2i = Vector2i.ZERO) -> Vector2i:
	var local_cell := Vector2i(0,0)
	var transform_cell = ShapeTransform.transform_cells([local_cell], rotate_num, custom_center)
	return transform_cell[0]
## 获取物品的正方形大小
func get_shape_size()->Vector2i:
	if item_data == null or item_data.shape == null or item_data.shape.cells.is_empty():
		return Vector2i(1,1)
	var min_x := item_data.shape.cells[0].x
	var max_x := item_data.shape.cells[0].x
	var min_y := item_data.shape.cells[0].y
	var max_y := item_data.shape.cells[0].y
	for cell in item_data.shape.cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	return Vector2i(max_x - min_x + 1, max_y - min_y + 1)
#endregion

#region 判断
func is_same_item(item_instance_data:ItemInstanceData)->bool:
	return item_instance_data.get_item_data() == item_data
#endregion
