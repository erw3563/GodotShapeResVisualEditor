@tool
extends EditorProperty

const PANEL_SCENE := preload("res://addons/custom_shape_panel/custom_shape_panel.tscn")

var shape_resource: Shape
var panel: Control


func _init() -> void:
	panel = PANEL_SCENE.instantiate() as Control
	add_child(panel)
	set_bottom_editor(panel)


## 绑定当前正在检查器中编辑的 Shape 资源。
func setup_shape_resource(new_shape_resource: Shape) -> void:
	shape_resource = new_shape_resource
	_connect_panel_signals()
	_sync_panel_state()


## 当检查器属性刷新时，同步最新 cells 数据到面板实例。
func _update_property() -> void:
	var edited_shape_resource := get_edited_object() as Shape
	if edited_shape_resource != null:
		shape_resource = edited_shape_resource

	_sync_panel_state()


## 接收未来可视化面板提交的 cells 修改。
func _on_panel_cells_changed(new_cells: Array) -> void:
	var normalized_cells := _get_normalized_cells(new_cells)
	emit_changed(get_edited_property(), normalized_cells)
	_sync_panel_state(normalized_cells)


func _connect_panel_signals() -> void:
	if panel == null or !panel.has_signal("cells_changed"):
		return
	if panel.is_connected("cells_changed", _on_panel_cells_changed):
		return

	panel.connect("cells_changed", _on_panel_cells_changed)


func _sync_panel_state(override_cells: Variant = null) -> void:
	if panel == null or shape_resource == null:
		return

	var current_cells: Array = shape_resource.cells
	if override_cells is Array:
		current_cells = override_cells

	var normalized_cells := _get_normalized_cells(current_cells)
	panel.set_meta("shape_resource", shape_resource)
	panel.set_meta("cells", normalized_cells)

	if panel.has_method("set_shape_resource"):
		panel.call("set_shape_resource", shape_resource)
	if panel.has_method("set_cells"):
		panel.call("set_cells", normalized_cells)


func _get_normalized_cells(input_cells: Array) -> Array[Vector2i]:
	var normalized_cells: Array[Vector2i] = []
	for cell in input_cells:
		if cell is Vector2i and !normalized_cells.has(cell):
			normalized_cells.append(cell)
	return normalized_cells
