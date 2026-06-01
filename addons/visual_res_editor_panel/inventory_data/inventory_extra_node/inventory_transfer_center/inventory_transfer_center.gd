class_name InventoryTransferCenter
extends Node
## InventoryTransferCenter 是背包物品的快速传递节点。

## 源背包，一个 InventoryTransferCenter 只负责这一个源背包。
@export var source_inventory_data: InventoryData
## 目标背包，一个 InventoryTransferCenter 只负责这一个目标背包。
@export var target_inventory_data: InventoryData

#region 背包绑定
## 绑定当前中心负责的源背包和目标背包。
func bind_inventory_data(source_inventory_data_to_bind: InventoryData, target_inventory_data_to_bind: InventoryData) -> void:
	source_inventory_data = source_inventory_data_to_bind
	target_inventory_data = target_inventory_data_to_bind
## 清空当前中心绑定的背包。
func clear_inventory_binding() -> void:
	source_inventory_data = null
	target_inventory_data = null
## 判断当前中心是否已经绑定可用的源背包和目标背包。
func has_inventory_binding() -> bool:
	if source_inventory_data == null or target_inventory_data == null:
		return false
	if source_inventory_data == target_inventory_data:
		return false
	return true
## 返回当前中心绑定的目标背包。
func get_target_inventory_data() -> InventoryData:
	return target_inventory_data
#endregion

## 把一个物品实例转移到当前绑定的目标背包。
func try_transfer_item_instance_to_target(item_instance_data: ItemInstanceData) -> bool:
	if !has_inventory_binding():
		return false
	if item_instance_data == null:
		return false
	if !source_inventory_data.has_item_instance(item_instance_data):
		return false
	if !source_inventory_data.can_take_item(item_instance_data):
		return false
	if !target_inventory_data.can_add_item(item_instance_data):
		return false
	# 先放入目标背包，再从源背包移除，确保失败时不丢失物品。
	if target_inventory_data.try_add_item_with_merge(item_instance_data):
		return source_inventory_data.try_take_item(item_instance_data)
	else:
		return false

## 把一个物品实例从目标背包移回当前绑定的源背包。
func try_transfer_item_instance_to_source(item_instance_data: ItemInstanceData) -> bool:
	if !has_inventory_binding():
		return false
	if item_instance_data == null:
		return false
	if !target_inventory_data.has_item_instance(item_instance_data):
		return false
	if !target_inventory_data.can_take_item(item_instance_data):
		return false
	if !source_inventory_data.can_add_item(item_instance_data):
		return false
	# 先放入源背包，再从目标背包移除，确保失败时不丢失物品。
	if source_inventory_data.try_add_item_with_merge(item_instance_data):
		return target_inventory_data.try_take_item(item_instance_data)
	else:
		return false

## 从「一侧」背包把指定物品实例移到对侧：物品须在源则进目标，须在目标则回源。
## from_inventory_data 必须是当前绑定的源或目标之一，且物品须属于该背包。
func try_transfer_item_instance_to_opposite_from_inventory(from_inventory_data: InventoryData, item_instance_data: ItemInstanceData) -> bool:
	if !has_inventory_binding() or item_instance_data == null or from_inventory_data == null:
		return false
	if from_inventory_data == source_inventory_data:
		return try_transfer_item_instance_to_target(item_instance_data)
	if from_inventory_data == target_inventory_data:
		return try_transfer_item_instance_to_source(item_instance_data)
	return false

## 把源背包全部可转移物品移到当前绑定的目标背包。
func try_transfer_all_item_instances_to_target() -> int:
	if !has_inventory_binding():
		return 0
	var transferred_count := 0
	var source_items := source_inventory_data.get_item_instances().duplicate()
	for source_item_instance in source_items:
		if try_transfer_item_instance_to_target(source_item_instance):
			transferred_count += 1
	return transferred_count

## 把目标背包全部可转移物品移回当前绑定的源背包。
func try_transfer_all_item_instances_to_source() -> int:
	if !has_inventory_binding():
		return 0
	var transferred_count := 0
	var target_items := target_inventory_data.get_item_instances().duplicate()
	for target_item_instance in target_items:
		if try_transfer_item_instance_to_source(target_item_instance):
			transferred_count += 1
	return transferred_count
