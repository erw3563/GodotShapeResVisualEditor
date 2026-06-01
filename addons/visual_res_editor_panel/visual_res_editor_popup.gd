@tool
extends RefCounted

const DEFAULT_POPUP_SIZE := Vector2i(720, 720)
const DEFAULT_MIN_SIZE := Vector2i(320, 320)


## 在编辑器主窗口中弹出可视化面板。
func open_panel(
	panel: Control,
	title: String,
	preferred_size: Vector2i = DEFAULT_POPUP_SIZE
) -> Window:
	var popup_window := Window.new()
	popup_window.title = title
	popup_window.size = preferred_size
	popup_window.min_size = DEFAULT_MIN_SIZE
	popup_window.transient = true
	popup_window.unresizable = false

	var margin_container := MarginContainer.new()
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 8)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_right", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	popup_window.add_child(margin_container)

	_prepare_panel_for_popup(panel)
	margin_container.add_child(panel)

	popup_window.close_requested.connect(popup_window.hide)
	popup_window.close_requested.connect(popup_window.queue_free)

	EditorInterface.get_base_control().add_child(popup_window)
	popup_window.popup_centered()
	return popup_window


## 弹窗内使用全屏伸展布局，避免场景里为检查器预留的居中偏移。
func _prepare_panel_for_popup(panel: Control) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
