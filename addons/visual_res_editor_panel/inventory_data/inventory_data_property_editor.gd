@tool
extends EditorProperty

const PANEL_SCENE := preload(
	"res://addons/visual_res_editor_panel/inventory_data/visual_inventory_data_editor_panel.tscn"
)
const VisualResEditorPopup := preload("res://addons/visual_res_editor_panel/visual_res_editor_popup.gd")

const POPUP_TITLE := "InventoryData 可视化编辑"
const POPUP_SIZE := Vector2i(900, 720)

var inventory_data_resource: InventoryData
var panel: Control
var popup_window: Window
var popup_panel: Control
var popup_helper: VisualResEditorPopup


func _init() -> void:
	panel = PANEL_SCENE.instantiate() as Control
	add_child(panel)
	set_bottom_editor(panel)
	set_label("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_popup()


## 绑定当前正在检查器中编辑的 InventoryData 资源。
func setup_inventory_data_resource(new_inventory_data_resource: InventoryData) -> void:
	inventory_data_resource = new_inventory_data_resource
	_connect_panel_signals()
	_sync_panel_state()


## 当检查器刷新时，同步最新背包数据到面板。
func _update_property() -> void:
	var edited_inventory_data := get_edited_object() as InventoryData
	if edited_inventory_data != null:
		inventory_data_resource = edited_inventory_data
	_sync_panel_state()


## 接收面板提交的背包修改。
func _on_panel_inventory_changed() -> void:
	if inventory_data_resource == null:
		return
	_commit_inventory_changes()
	_sync_panel_state()


## 在弹窗中打开一份新的可视化面板实例。
func _on_popup_requested() -> void:
	if popup_window != null and is_instance_valid(popup_window):
		popup_window.grab_focus()
		return

	popup_helper = VisualResEditorPopup.new()
	popup_panel = PANEL_SCENE.instantiate() as Control
	popup_window = popup_helper.open_panel(popup_panel, POPUP_TITLE, POPUP_SIZE)
	popup_window.tree_exited.connect(_on_popup_tree_exited)

	_connect_popup_panel_signals()
	_sync_panel_state()


func _connect_panel_signals() -> void:
	if panel == null:
		return
	if panel.has_signal("inventory_changed") and !panel.is_connected("inventory_changed", _on_panel_inventory_changed):
		panel.connect("inventory_changed", _on_panel_inventory_changed)
	if panel.has_signal("popup_requested") and !panel.is_connected("popup_requested", _on_popup_requested):
		panel.connect("popup_requested", _on_popup_requested)


func _connect_popup_panel_signals() -> void:
	if popup_panel == null:
		return
	if popup_panel.has_signal("inventory_changed") and !popup_panel.is_connected("inventory_changed", _on_panel_inventory_changed):
		popup_panel.connect("inventory_changed", _on_panel_inventory_changed)


func _sync_panel_state() -> void:
	if inventory_data_resource == null:
		return
	_apply_panel_state(panel)
	if popup_panel != null and is_instance_valid(popup_panel):
		_apply_panel_state(popup_panel)


func _apply_panel_state(target_panel: Control) -> void:
	if target_panel == null or inventory_data_resource == null:
		return
	target_panel.set_meta("inventory_data_resource", inventory_data_resource)
	if target_panel.has_method("set_inventory_data_resource"):
		target_panel.call("set_inventory_data_resource", inventory_data_resource)


func _commit_inventory_changes() -> void:
	if inventory_data_resource == null:
		return
	var duplicated_items: Array[ItemInstanceData] = []
	for item_instance in inventory_data_resource.item_instances:
		duplicated_items.append(item_instance)
	var edited_property := get_edited_property()
	if edited_property != StringName():
		emit_changed("item_instances", duplicated_items)
		emit_changed("occupy_map", inventory_data_resource.occupy_map)
	else:
		inventory_data_resource.emit_changed()


func _close_popup() -> void:
	if popup_window != null and is_instance_valid(popup_window):
		popup_window.queue_free()


func _on_popup_tree_exited() -> void:
	popup_window = null
	popup_panel = null
	popup_helper = null
