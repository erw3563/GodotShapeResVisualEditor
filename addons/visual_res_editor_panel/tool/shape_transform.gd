class_name ShapeTransform
extends RefCounted

## 将单个格子按 90 度整数旋转，rotate_num 可为任意整数。
static func rotate_cell_90(cell:Vector2i, rotate_num:int) -> Vector2i:
	var n := posmod(rotate_num, 4)
	match n:
		0:
			return cell
		1:
			return Vector2i(-cell.y, cell.x)
		2:
			return Vector2i(-cell.x, -cell.y)
		3:
			return Vector2i(cell.y, -cell.x)
	return cell

## 批量旋转格子。
static func rotate_cells_90(cells:Array[Vector2i], rotate_num:int) -> Array[Vector2i]:
	if rotate_num == 0:
		return cells.duplicate()
	var result:Array[Vector2i] = []
	result.resize(cells.size())
	for i in range(cells.size()):
		result[i] = rotate_cell_90(cells[i], rotate_num)
	return result

## 批量平移格子。
static func translate_cells(cells:Array[Vector2i], offset:Vector2i) -> Array[Vector2i]:
	if offset == Vector2i.ZERO:
		return cells.duplicate()
	var result:Array[Vector2i] = []
	result.resize(cells.size())
	for i in range(cells.size()):
		result[i] = cells[i] + offset
	return result

## 组合变换：先旋转后平移。
static func transform_cells(cells:Array[Vector2i], rotate_num:int, offset:Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var rotated_cells := rotate_cells_90(cells, rotate_num)
	return translate_cells(rotated_cells, offset)
