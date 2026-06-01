class_name InventoryRefillCenter
extends Node
## InventoryRefillController 负责在运行时下发补货规则，并绑定目标 InventoryData。

## 当前绑定的目标背包数据。
@export var target_inventory_data: InventoryData:
	set(value):
		if target_inventory_data:
			_disconnect_inventory_signals(target_inventory_data)
		target_inventory_data = value
		if !target_inventory_data:
			return
		_connect_inventory_signals(target_inventory_data)
		_refill_if_possible()
## 运行时补货规则，键为 ItemData，值为目标保底数量。
@export var refill_rules: Dictionary[ItemData,int] = {}
## 运行时裁剪规则，键为 ItemData，值为目标封顶数量。
@export var reduce_rules: Dictionary[ItemData,int] = {}

## 绑定目标背包数据，并自动建立物品增删监听。
func bind_inventory_data(inventory_data: InventoryData) -> void:
	_set_target_inventory_data(inventory_data)
## 解绑当前背包数据并移除监听。
func unbind_inventory_data() -> void:
	_set_target_inventory_data(null)
## 设置目标背包数据。切换时会自动断开旧连接并连接新目标。
func _set_target_inventory_data(inventory_data: InventoryData) -> void:
	target_inventory_data = inventory_data

## 连接目标背包的物品变化信号。
func _connect_inventory_signals(inventory_data: InventoryData) -> void:
	if !inventory_data.item_added.is_connected(_on_inventory_item_added):
		inventory_data.item_added.connect(_on_inventory_item_added)
	if !inventory_data.item_removed_in_cell.is_connected(_on_inventory_item_removed_in_cell):
		inventory_data.item_removed_in_cell.connect(_on_inventory_item_removed_in_cell)

## 断开目标背包的物品变化信号。
func _disconnect_inventory_signals(inventory_data: InventoryData) -> void:
	if inventory_data.item_added.is_connected(_on_inventory_item_added):
		inventory_data.item_added.disconnect(_on_inventory_item_added)
	if inventory_data.item_removed_in_cell.is_connected(_on_inventory_item_removed_in_cell):
		inventory_data.item_removed_in_cell.disconnect(_on_inventory_item_removed_in_cell)

## 由外部系统批量下发运行时补货规则。
func set_runtime_refill_rules(runtime_rules: Dictionary) -> void:
	refill_rules = runtime_rules.duplicate()
	_refill_if_possible()

## 由外部系统下发单条运行时补货规则。
## - target_num <= 0 时移除该规则。
func set_runtime_refill_rule(item_data: ItemData, target_num: int) -> void:
	if !item_data:
		push_warning("设置补货规则失败：item_data 为空")
		return
	if target_num <= 0:
		refill_rules.erase(item_data)
	else:
		refill_rules[item_data] = target_num
	_refill_if_possible()

## 移除一条运行时补货规则。
func remove_runtime_refill_rule(item_data: ItemData) -> void:
	if !item_data:
		return
	refill_rules.erase(item_data)

## 清空所有运行时补货规则。
func clear_runtime_refill_rules() -> void:
	refill_rules.clear()

## 由外部系统批量下发运行时裁剪规则。
func set_runtime_reduce_rules(runtime_rules: Dictionary) -> void:
	reduce_rules = runtime_rules.duplicate()
	_refill_if_possible()

## 由外部系统下发单条运行时裁剪规则。
## - target_num < 0 时移除该规则。
## - target_num == 0 时表示该物品在背包中的数量上限为 0。
func set_runtime_reduce_rule(item_data: ItemData, target_num: int) -> void:
	if !item_data:
		push_warning("设置裁剪规则失败：item_data 为空")
		return
	if target_num < 0:
		reduce_rules.erase(item_data)
	else:
		reduce_rules[item_data] = target_num
	_refill_if_possible()

## 移除一条运行时裁剪规则。
func remove_runtime_reduce_rule(item_data: ItemData) -> void:
	if !item_data:
		return
	reduce_rules.erase(item_data)

## 清空所有运行时裁剪规则。
func clear_runtime_reduce_rules() -> void:
	reduce_rules.clear()

## 在目标 InventoryData 支持时触发补货逻辑。
func _refill_if_possible() -> void:
	if !target_inventory_data:
		return
	_refill_to_minimum_num()
	_reduce_to_maximum_num()

## 将目标物品数量补到运行时下限。
func _refill_to_minimum_num() -> void:
	for item_data in refill_rules.keys():
		_refill_item_to_minimum_num(item_data)

## 将目标物品数量裁到运行时上限。
func _reduce_to_maximum_num() -> void:
	for item_data in reduce_rules.keys():
		_reduce_item_to_maximum_num(item_data)

## 物品添加时触发上限裁剪。
func _on_inventory_item_added(item_instance_data: ItemInstanceData) -> void:
	if !target_inventory_data:
		return
	if item_instance_data == null or item_instance_data.item_data == null:
		return
	if !reduce_rules.has(item_instance_data.item_data):
		return
	# 延后到当前信号分发结束后再执行，避免增删信号重入导致显示层顺序错乱。
	call_deferred("_deferred_reduce_item_to_maximum_num", item_instance_data.item_data, item_instance_data)

## 物品移除时触发下限补货，优先使用移除时的原中心格补货。
func _on_inventory_item_removed_in_cell(item_instance_data: ItemInstanceData, removed_center_cell: Vector2i) -> void:
	if !target_inventory_data:
		return
	if item_instance_data == null or item_instance_data.item_data == null:
		return
	if !refill_rules.has(item_instance_data.item_data):
		return
	# 延后执行，避免与当前移除流程重入互相干扰。
	call_deferred("_deferred_refill_item_to_minimum_num", item_instance_data.item_data, removed_center_cell)

## 延后执行单物品裁剪，防止增删信号重入导致视图残留。
func _deferred_reduce_item_to_maximum_num(item_data: ItemData, preferred_item_instance_data: ItemInstanceData) -> void:
	if !target_inventory_data:
		return
	if item_data == null:
		return
	var valid_preferred_item_instance_data: ItemInstanceData = null
	if preferred_item_instance_data != null and target_inventory_data.has_item_instance(preferred_item_instance_data):
		valid_preferred_item_instance_data = preferred_item_instance_data
	_reduce_item_to_maximum_num(item_data, valid_preferred_item_instance_data)

## 延后执行单物品补货，防止与当前移除流程重入。
func _deferred_refill_item_to_minimum_num(item_data: ItemData, preferred_cell: Vector2i) -> void:
	if !target_inventory_data:
		return
	if item_data == null:
		return
	_refill_item_to_minimum_num(item_data, preferred_cell)

## 精准补齐单个物品到下限；可选优先补在指定格子。
func _refill_item_to_minimum_num(item_data: ItemData, preferred_cell: Vector2i = Vector2i(-1, -1)) -> void:
	if !refill_rules.has(item_data):
		return
	var minimum_num: int = refill_rules[item_data]
	if minimum_num <= 0:
		return
	if reduce_rules.has(item_data):
		# 同时存在上下限时，先将下限钳制到上限，避免规则冲突导致来回变化。
		minimum_num = mini(minimum_num, reduce_rules[item_data])
	# 补货按同种物品 num 总和判断，不按实例（堆数）判断。
	var current_total_num := target_inventory_data.get_item_total_num_from_item_data(item_data)
	if current_total_num >= minimum_num:
		return
	var need_add_num := minimum_num - current_total_num
	while need_add_num > 0:
		var item_instance_data := ItemInstanceData.new()
		item_instance_data.init(item_data, need_add_num)
		need_add_num -= item_instance_data.num
		var is_add_successful := false
		if preferred_cell != Vector2i(-1, -1):
			is_add_successful = target_inventory_data.try_place_item_in_cell(item_instance_data, preferred_cell)
			preferred_cell = Vector2i(-1, -1)
		if !is_add_successful:
			is_add_successful = target_inventory_data.try_add_item_with_merge(item_instance_data)
		if !is_add_successful:
			break

## 精准裁剪单个物品到上限；可选优先移除变化物品。
func _reduce_item_to_maximum_num(item_data: ItemData, preferred_item_instance_data: ItemInstanceData = null) -> void:
	if !reduce_rules.has(item_data):
		return
	var maximum_num: int = reduce_rules[item_data]
	if maximum_num < 0:
		return
	var item_instance_num := target_inventory_data.get_item_instance_num_from_item_data(item_data)
	if item_instance_num <= maximum_num:
		return
	# 这里按“物品实例数量（堆数）”裁剪，避免与 item_instance_data.num（堆叠数量）混用。
	var need_remove_num := item_instance_num - maximum_num
	if preferred_item_instance_data != null and preferred_item_instance_data.item_data == item_data:
		if target_inventory_data.has_item_instance(preferred_item_instance_data):
			if target_inventory_data.try_take_item(preferred_item_instance_data):
				need_remove_num -= 1
	while need_remove_num > 0:
		var removed_item := target_inventory_data.try_take_same_item(item_data)
		if removed_item == null:
			break
		need_remove_num -= 1
