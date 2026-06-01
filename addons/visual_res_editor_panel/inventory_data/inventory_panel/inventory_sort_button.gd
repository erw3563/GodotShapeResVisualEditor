class_name InventorySortButton
extends Button
## InventorySortButton 负责响应点击并触发背包整理。

## 需要整理的目标背包数据。
@export var inventory_data: InventoryData

func _ready() -> void:
	# 监听按钮按下事件，触发整理逻辑。
	pressed.connect(_on_pressed)

## 按钮按下后尝试整理背包。
func _on_pressed() -> void:
	if !is_instance_valid(inventory_data):
		return
	inventory_data.try_sort_inventory()
