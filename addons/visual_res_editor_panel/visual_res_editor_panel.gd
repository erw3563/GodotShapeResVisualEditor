@tool
extends EditorPlugin

const ShapeCellsInspectorPlugin := preload("res://addons/visual_res_editor_panel/shape/shape_cells_inspector_plugin.gd")
const OccupyMapCellsInspectorPlugin := preload(
	"res://addons/visual_res_editor_panel/occupy/occupy_map_cells_inspector_plugin.gd"
)
const InventoryDataInspectorPlugin := preload(
	"res://addons/visual_res_editor_panel/inventory_data/inventory_data_inspector_plugin.gd"
)

var shape_cells_inspector_plugin: EditorInspectorPlugin
var occupy_map_cells_inspector_plugin: EditorInspectorPlugin
var inventory_data_inspector_plugin: EditorInspectorPlugin


## 可视化资源编辑面板：注册检查器扩展。
func _enter_tree() -> void:
	shape_cells_inspector_plugin = ShapeCellsInspectorPlugin.new()
	add_inspector_plugin(shape_cells_inspector_plugin)

	occupy_map_cells_inspector_plugin = OccupyMapCellsInspectorPlugin.new()
	add_inspector_plugin(occupy_map_cells_inspector_plugin)

	inventory_data_inspector_plugin = InventoryDataInspectorPlugin.new()
	add_inspector_plugin(inventory_data_inspector_plugin)


## 移除插件注册的检查器扩展。
func _exit_tree() -> void:
	if shape_cells_inspector_plugin != null:
		remove_inspector_plugin(shape_cells_inspector_plugin)
		shape_cells_inspector_plugin = null

	if occupy_map_cells_inspector_plugin != null:
		remove_inspector_plugin(occupy_map_cells_inspector_plugin)
		occupy_map_cells_inspector_plugin = null

	if inventory_data_inspector_plugin != null:
		remove_inspector_plugin(inventory_data_inspector_plugin)
		inventory_data_inspector_plugin = null
