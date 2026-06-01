class_name InventoryItemBox
extends Control

signal item_box_freed

@export var texture_rect: TextureRect
@export var label: Label

var item_instance_data: ItemInstanceData
var center_pos: Vector2
var invalid_placement_feedback_tween: Tween
var feedback_tween: Tween
var _panel_container: PanelContainer

func _ready() -> void:
	_ensure_ui_nodes()

func _enter_tree() -> void:
	if !is_inside_tree():
		return
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	await scene_tree.process_frame
	if !is_inside_tree() or item_instance_data == null:
		return
	update_item_rotate(item_instance_data.rotate_num)

func get_center() -> Vector2:
	return center_pos

func get_item_instance_data() -> ItemInstanceData:
	return item_instance_data

## 初始化物品格子显示。
func init_cell(item_instance_data_: ItemInstanceData, item_texture_size: Vector2, item_box_size: Vector2) -> void:
	_ensure_ui_nodes()
	item_instance_data = item_instance_data_
	item_instance_data.num_changed.connect(update_item_num_lable)
	item_instance_data.rotate_num_changed.connect(update_item_rotate)
	# 获取物品占据的格子数量
	var item_data := item_instance_data.item_data
	var item_size: Vector2i = item_instance_data.get_shape_size()
	# 设置物品和物品框大小
	custom_minimum_size = Vector2(item_size.x * item_box_size.x, item_size.y * item_box_size.y)
	# 获取中心位置
	var center_cell = item_instance_data.get_center_cell(Vector2i(0, 0))
	center_pos = Vector2(center_cell.x * item_box_size.x, center_cell.y * item_box_size.y) + item_box_size / 2
	## 贴图相关
	texture_rect.texture = item_data.icon
	_panel_container.custom_minimum_size = Vector2(item_size.x * item_texture_size.x, item_size.y * item_texture_size.y)
	_panel_container.pivot_offset = Vector2(center_cell) * item_box_size + item_box_size / 2
	label.pivot_offset_ratio = Vector2(0.5, 0.5)
	update_item_rotate(item_instance_data.rotate_num)
	## 数量文本相关
	label.text = str(item_instance_data.num)

func update_item_num_lable(num: int) -> void:
	label.text = str(num)
	if num == 0:
		item_box_freed.emit()
		queue_free()

func update_item_rotate(rotate_num: int) -> void:
	if !is_instance_valid(_panel_container) || !is_instance_valid(label):
		return
	_panel_container.rotation = PI / 2 * rotate_num
	label.rotation = -PI / 2 * rotate_num

## 确保 UI 节点存在，支持纯代码创建 InventoryItemBox。
func _ensure_ui_nodes() -> void:
	if is_instance_valid(texture_rect) and is_instance_valid(label):
		if !is_instance_valid(_panel_container):
			_panel_container = texture_rect.get_parent() as PanelContainer
		return
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if !is_instance_valid(_panel_container):
		_panel_container = get_node_or_null("PanelContainer") as PanelContainer
		if !is_instance_valid(_panel_container):
			_panel_container = _create_panel_container()
			add_child(_panel_container)
	if !is_instance_valid(texture_rect):
		texture_rect = _panel_container.get_node_or_null("TextureRect") as TextureRect
		if !is_instance_valid(texture_rect):
			texture_rect = _create_texture_rect()
			_panel_container.add_child(texture_rect)
	if !is_instance_valid(label):
		label = _panel_container.get_node_or_null("Label") as Label
		if !is_instance_valid(label):
			label = _create_label()
			_panel_container.add_child(label)

## 创建与场景资源一致的 PanelContainer。
func _create_panel_container() -> PanelContainer:
	var panel_container := PanelContainer.new()
	panel_container.name = "PanelContainer"
	panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_container.add_theme_stylebox_override("panel", _create_panel_style())
	panel_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel_container.offset_right = 39.0
	panel_container.offset_bottom = 36.0
	return panel_container

## 创建与场景资源一致的 TextureRect。
func _create_texture_rect() -> TextureRect:
	var texture_rect_node := TextureRect.new()
	texture_rect_node.name = "TextureRect"
	texture_rect_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return texture_rect_node

## 创建与场景资源一致的 Label。
func _create_label() -> Label:
	var label_node := Label.new()
	label_node.name = "Label"
	label_node.modulate = Color(0.94, 0, 0, 1)
	label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label_node.text = "00"
	label_node.label_settings = LabelSettings.new()
	return label_node

## 创建与场景资源一致的 Panel 样式。
func _create_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.6, 0.6, 0.6, 0)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_detail = 1
	return panel_style
