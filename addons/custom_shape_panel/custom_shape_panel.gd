@tool
extends EditorPlugin

const ShapeCellsInspectorPlugin := preload("res://addons/custom_shape_panel/shape_cells_inspector_plugin.gd")

var shape_cells_inspector_plugin: EditorInspectorPlugin


## 注册 Shape 的 cells 可视化属性编辑器。
func _enter_tree() -> void:
	shape_cells_inspector_plugin = ShapeCellsInspectorPlugin.new()
	add_inspector_plugin(shape_cells_inspector_plugin)


## 移除插件注册的检查器扩展。
func _exit_tree() -> void:
	if shape_cells_inspector_plugin == null:
		return

	remove_inspector_plugin(shape_cells_inspector_plugin)
	shape_cells_inspector_plugin = null
