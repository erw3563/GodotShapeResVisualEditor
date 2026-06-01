@abstract
class_name ItemPart
extends Resource
## 物品数据基础，其子类会被ItemData所拥有,以实现各种类型的物品数据。
## 比如如果 ItemData 拥有 FoodItemData,则该 Item 具有食物功能

## 建议您在子类中重写。
## 因静态方法无法制成抽象方法，且判断该方法为静态方法重要性更高，所以无法强制要求重写。
static func get_part_type()->String:
	return ""

## 返回该类的描述面板,由子类实现
func get_description_panel():
	pass
