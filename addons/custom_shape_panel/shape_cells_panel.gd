@tool
extends PanelContainer

## 当面板中的坐标按钮被切换时发出。
## shape_cells_property_editor.gd 会监听这个信号，并把新数组写回 Shape.cells。
signal cells_changed(new_cells: Array[Vector2i])

## 坐标面板以 (0, 0) 为中心向四个方向展开。
## 半径为 4 时，实际显示范围是 x: -4 到 4，y: -4 到 4。
const DEFAULT_AXIS_RADIUS := 4
const MIN_AXIS_RADIUS := 1
const MAX_AXIS_RADIUS := 12
const BUTTON_MINIMUM_SIZE := Vector2(48, 48)
const SELECTED_BUTTON_MODULATE := Color(1.6, 1.6, 1.6)
const NORMAL_BUTTON_MODULATE := Color.WHITE

## 场景中预留的容器和范围调整按钮。
## GridContainer 只负责排列按钮，具体坐标由 button_by_cell 字典记录。
@onready var grid_container: GridContainer = $MarginContainer/HBoxContainer2/HBoxContainer/GridContainer
@onready var x_decrease_button: Button = $"MarginContainer/HBoxContainer2/HBoxContainer2/X-Button"
@onready var x_increase_button: Button = $"MarginContainer/HBoxContainer2/HBoxContainer2/X+Button"
@onready var y_decrease_button: Button = $"MarginContainer/HBoxContainer2/HBoxContainer/VBoxContainer/Y-Button"
@onready var y_increase_button: Button = $"MarginContainer/HBoxContainer2/HBoxContainer/VBoxContainer/Y+Button"

## 当前面板绑定的 Shape 资源，由属性编辑器传入。
var shape_resource: Shape
## 当前已选中的坐标集合。这里是面板缓存，真正写回由 cells_changed 信号完成。
var cells: Array[Vector2i] = []
## 坐标到按钮节点的映射，用来刷新按钮选中状态。
var button_by_cell: Dictionary = {}
var status_label: Label
## 当前可见坐标范围的横向和纵向半径。
var x_radius := DEFAULT_AXIS_RADIUS
var y_radius := DEFAULT_AXIS_RADIUS

func _ready() -> void:
	_connect_resize_buttons()
	_build_layout()
	_refresh_buttons()

## 绑定当前正在编辑的 Shape 资源。
func set_shape_resource(new_shape_resource: Shape) -> void:
	shape_resource = new_shape_resource

## 从检查器同步 cells 数据到可视化按钮状态。
func set_cells(new_cells: Array[Vector2i]) -> void:
	cells = _get_unique_cells(new_cells)
	_refresh_buttons()

## 根据当前 x_radius 和 y_radius 重新生成坐标按钮。
## 重新生成只影响可见按钮，不会修改 cells 中已经保存的坐标数据。
func _build_layout() -> void:
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	button_by_cell.clear()

	# GridContainer 按列数自动换行，所以列数必须等于横向格子数量。
	grid_container.columns = x_radius * 2 + 1
	for cell_y in range(-y_radius, y_radius + 1):
		for cell_x in range(-x_radius, x_radius + 1):
			var cell := Vector2i(cell_x, cell_y)
			var cell_button := Button.new()
			cell_button.custom_minimum_size = BUTTON_MINIMUM_SIZE
			cell_button.focus_mode = Control.FOCUS_NONE
			cell_button.toggle_mode = true
			cell_button.tooltip_text = "(%d, %d)" % [cell.x, cell.y]
			cell_button.pressed.connect(_on_cell_button_pressed.bind(cell))
			button_by_cell[cell] = cell_button
			grid_container.add_child(cell_button)
	_refresh_resize_buttons()

## 切换按钮对应坐标是否属于 Shape.cells。
func _on_cell_button_pressed(cell: Vector2i) -> void:
	if cells.has(cell):
		cells.erase(cell)
	else:
		cells.append(cell)

	cells_changed.emit(cells.duplicate())
	_refresh_buttons()

## 调整可见坐标按钮范围，不直接修改 Shape.cells 数据。
## axis 决定修改横向还是纵向半径，amount 决定增加或减少。
func _change_grid_axis_radius(axis: Vector2i, amount: int) -> void:
	x_radius = clampi(x_radius + axis.x * amount, MIN_AXIS_RADIUS, MAX_AXIS_RADIUS)
	y_radius = clampi(y_radius + axis.y * amount, MIN_AXIS_RADIUS, MAX_AXIS_RADIUS)
	_build_layout()
	_refresh_buttons()

## 按照 cells 缓存刷新所有可见按钮的选中状态。
## 如果 cells 中存在当前不可见的坐标，它们会保留在数组中，等范围扩大后再显示。
func _refresh_buttons() -> void:
	if status_label != null:
		status_label.text = "cells: %d" % cells.size()

	for cell in button_by_cell:
		var cell_button := button_by_cell[cell] as Button
		var is_selected := cells.has(cell)
		cell_button.button_pressed = is_selected
		cell_button.modulate = SELECTED_BUTTON_MODULATE if is_selected else NORMAL_BUTTON_MODULATE
	_refresh_resize_buttons()

## 连接四个范围调整按钮。
## 这里使用 Vector2i.RIGHT 和 Vector2i.DOWN 只是为了表示“改 x 半径”或“改 y 半径”。
func _connect_resize_buttons() -> void:
	if x_decrease_button == null or x_increase_button == null or y_decrease_button == null or y_increase_button == null:
		return

	x_decrease_button.pressed.connect(_change_grid_axis_radius.bind(Vector2i.RIGHT, -1))
	x_increase_button.pressed.connect(_change_grid_axis_radius.bind(Vector2i.RIGHT, 1))
	y_decrease_button.pressed.connect(_change_grid_axis_radius.bind(Vector2i.DOWN, -1))
	y_increase_button.pressed.connect(_change_grid_axis_radius.bind(Vector2i.DOWN, 1))

## 在半径到达上下限时禁用对应按钮，避免无效点击。
func _refresh_resize_buttons() -> void:
	if x_decrease_button == null or x_increase_button == null or y_decrease_button == null or y_increase_button == null:
		return

	x_decrease_button.disabled = x_radius <= MIN_AXIS_RADIUS
	x_increase_button.disabled = x_radius >= MAX_AXIS_RADIUS
	y_decrease_button.disabled = y_radius <= MIN_AXIS_RADIUS
	y_increase_button.disabled = y_radius >= MAX_AXIS_RADIUS

## 保证 cells 中不会出现重复坐标，避免按钮状态和资源数据不一致。
func _get_unique_cells(input_cells: Array[Vector2i]) -> Array[Vector2i]:
	var unique_cells: Array[Vector2i] = []
	for cell in input_cells:
		if !unique_cells.has(cell):
			unique_cells.append(cell)
	return unique_cells
