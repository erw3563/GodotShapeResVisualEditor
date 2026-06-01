class_name InventoryShapeOverlayTextureRenderStrategy
extends RefCounted
## 背包形状覆盖层贴图渲染策略。
## 使用 NinePatchRect 与单张贴图，按暴露边配置 region_rect 与 patch_margin。

const SIDE_TOP := 1
const SIDE_RIGHT := 2
const SIDE_BOTTOM := 4
const SIDE_LEFT := 8

## 网格面板（用于格子坐标转像素坐标）。
var inventory_grid_panel: InventoryGridPanel
## 单格完整框贴图（九宫格源图）。
var frame_texture: Texture2D
## 源图四边边框厚度 (left, top, right, bottom)。
var frame_border_margins: Vector4i = Vector4i(6, 6, 6, 6)
## 占格填充贴图。
var fill_texture: Texture2D

## 同步渲染策略配置。
func sync_config(
	target_inventory_grid_panel: InventoryGridPanel,
	target_frame_texture: Texture2D,
	target_frame_border_margins: Vector4i,
	target_fill_texture: Texture2D
) -> void:
	inventory_grid_panel = target_inventory_grid_panel
	frame_texture = target_frame_texture
	frame_border_margins = target_frame_border_margins
	fill_texture = target_fill_texture

## 判断是否可用贴图模式绘制边框。
func has_all_texture_to_draw() -> bool:
	if frame_texture == null:
		return false
	var source_rect := _get_frame_source_rect()
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return false
	var margin_left := frame_border_margins.x
	var margin_top := frame_border_margins.y
	var margin_right := frame_border_margins.z
	var margin_bottom := frame_border_margins.w
	if margin_left <= 0 or margin_top <= 0 or margin_right <= 0 or margin_bottom <= 0:
		return false
	return margin_left + margin_right < source_rect.size.x \
		and margin_top + margin_bottom < source_rect.size.y

## 将一组形状格子绘制到目标容器。
func build_shape_to_container(
	target_cells: Array[Vector2i],
	target_container: Control,
	border_color: Color,
	fill_color: Color
) -> void:
	if !is_instance_valid(inventory_grid_panel):
		return
	var cell_lookup: Dictionary = {}
	for target_cell in target_cells:
		cell_lookup[target_cell] = true
	_build_fill_nodes(target_cells, target_container, fill_color)
	_build_frame_nine_patches(target_cells, cell_lookup, target_container, border_color)

## 创建填充节点（每个格子一张）。
func _build_fill_nodes(target_cells: Array[Vector2i], target_container: Control, fill_color: Color) -> void:
	for target_cell in target_cells:
		var cell_position := inventory_grid_panel.get_cell_local_position(target_cell)
		var cell_size := inventory_grid_panel.cell_size
		var fill_node: Control
		if fill_texture == null:
			var fill_color_rect := ColorRect.new()
			fill_color_rect.color = fill_color
			fill_node = fill_color_rect
		else:
			var fill_patch := NinePatchRect.new()
			_configure_fill_nine_patch(fill_patch, cell_size)
			fill_patch.modulate = fill_color
			fill_node = fill_patch
		fill_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_node.position = cell_position
		fill_node.size = cell_size
		target_container.add_child(fill_node)

## 为暴露边创建 NinePatchRect 边框条。
func _build_frame_nine_patches(
	target_cells: Array[Vector2i],
	cell_lookup: Dictionary,
	target_container: Control,
	frame_color: Color
) -> void:
	var source_rect := _get_frame_source_rect()
	var scale := _get_frame_display_scale(source_rect)
	for target_cell in target_cells:
		var side_mask := _get_exposed_side_mask(target_cell, cell_lookup)
		if side_mask == 0:
			continue
		var cell_position := inventory_grid_panel.get_cell_local_position(target_cell)
		var cell_size := inventory_grid_panel.cell_size
		for side_flag in [SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM, SIDE_LEFT]:
			if side_mask & side_flag == 0:
				continue
			var frame_patch := NinePatchRect.new()
			frame_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame_patch.modulate = frame_color
			frame_patch.draw_center = false
			_configure_edge_nine_patch(frame_patch, side_flag, source_rect, cell_position, cell_size, scale)
			target_container.add_child(frame_patch)

## 配置填充用 NinePatchRect（使用源图中心区域）。
func _configure_fill_nine_patch(target_patch: NinePatchRect, cell_size: Vector2) -> void:
	target_patch.texture = fill_texture
	var source_rect := _get_fill_source_rect()
	target_patch.region_rect = source_rect
	target_patch.patch_margin_left = frame_border_margins.x
	target_patch.patch_margin_top = frame_border_margins.y
	target_patch.patch_margin_right = frame_border_margins.z
	target_patch.patch_margin_bottom = frame_border_margins.w
	target_patch.draw_center = true

## 按边方向配置 NinePatchRect 的 region_rect、尺寸与 patch_margin。
func _configure_edge_nine_patch(
	target_patch: NinePatchRect,
	side_flag: int,
	source_rect: Rect2,
	cell_position: Vector2,
	cell_size: Vector2,
	display_scale: Vector2
) -> void:
	target_patch.texture = frame_texture
	var margin_left := frame_border_margins.x
	var margin_top := frame_border_margins.y
	var margin_right := frame_border_margins.z
	var margin_bottom := frame_border_margins.w
	var display_margin_left := float(margin_left) * display_scale.x
	var display_margin_top := float(margin_top) * display_scale.y
	var display_margin_right := float(margin_right) * display_scale.x
	var display_margin_bottom := float(margin_bottom) * display_scale.y
	match side_flag:
		SIDE_TOP:
			target_patch.position = cell_position
			target_patch.size = Vector2(cell_size.x, display_margin_top)
			target_patch.region_rect = Rect2(
				source_rect.position.x,
				source_rect.position.y,
				source_rect.size.x,
				margin_top
			)
			target_patch.patch_margin_left = margin_left
			target_patch.patch_margin_top = margin_top
			target_patch.patch_margin_right = margin_right
			target_patch.patch_margin_bottom = 0
		SIDE_RIGHT:
			target_patch.position = cell_position + Vector2(cell_size.x - display_margin_right, 0.0)
			target_patch.size = Vector2(display_margin_right, cell_size.y)
			target_patch.region_rect = Rect2(
				source_rect.position.x + source_rect.size.x - margin_right,
				source_rect.position.y,
				margin_right,
				source_rect.size.y
			)
			target_patch.patch_margin_left = margin_right
			target_patch.patch_margin_top = margin_top
			target_patch.patch_margin_right = 0
			target_patch.patch_margin_bottom = margin_bottom
		SIDE_BOTTOM:
			target_patch.position = cell_position + Vector2(0.0, cell_size.y - display_margin_bottom)
			target_patch.size = Vector2(cell_size.x, display_margin_bottom)
			target_patch.region_rect = Rect2(
				source_rect.position.x,
				source_rect.position.y + source_rect.size.y - margin_bottom,
				source_rect.size.x,
				margin_bottom
			)
			target_patch.patch_margin_left = margin_left
			target_patch.patch_margin_top = 0
			target_patch.patch_margin_right = margin_right
			target_patch.patch_margin_bottom = margin_bottom
		SIDE_LEFT:
			target_patch.position = cell_position
			target_patch.size = Vector2(display_margin_left, cell_size.y)
			target_patch.region_rect = Rect2(
				source_rect.position.x,
				source_rect.position.y,
				margin_left,
				source_rect.size.y
			)
			target_patch.patch_margin_left = margin_left
			target_patch.patch_margin_top = margin_top
			target_patch.patch_margin_right = 0
			target_patch.patch_margin_bottom = margin_bottom

## 获取边框源图在贴图坐标系中的矩形。
func _get_frame_source_rect() -> Rect2:
	if frame_texture is AtlasTexture:
		return (frame_texture as AtlasTexture).region
	return Rect2(0.0, 0.0, frame_texture.get_width(), frame_texture.get_height())

## 获取填充源图在贴图坐标系中的矩形。
func _get_fill_source_rect() -> Rect2:
	if fill_texture is AtlasTexture:
		return (fill_texture as AtlasTexture).region
	return Rect2(0.0, 0.0, fill_texture.get_width(), fill_texture.get_height())

## 源图尺寸映射到格子显示时的缩放比。
func _get_frame_display_scale(source_rect: Rect2) -> Vector2:
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return Vector2.ONE
	var cell_size := inventory_grid_panel.cell_size
	return Vector2(cell_size.x / source_rect.size.x, cell_size.y / source_rect.size.y)

## 获取当前格子暴露出的边框方向。
func _get_exposed_side_mask(target_cell: Vector2i, cell_lookup: Dictionary) -> int:
	var side_mask := 0
	var top_cell := target_cell + Vector2i(0, -1)
	var right_cell := target_cell + Vector2i(1, 0)
	var bottom_cell := target_cell + Vector2i(0, 1)
	var left_cell := target_cell + Vector2i(-1, 0)
	if !_lookup_has_cell(cell_lookup, top_cell):
		side_mask |= SIDE_TOP
	if !_lookup_has_cell(cell_lookup, right_cell):
		side_mask |= SIDE_RIGHT
	if !_lookup_has_cell(cell_lookup, bottom_cell):
		side_mask |= SIDE_BOTTOM
	if !_lookup_has_cell(cell_lookup, left_cell):
		side_mask |= SIDE_LEFT
	return side_mask

## 判断格子是否存在于查找表中。
func _lookup_has_cell(cell_lookup: Dictionary, cell_index: Vector2i) -> bool:
	return cell_lookup.has(cell_index)
