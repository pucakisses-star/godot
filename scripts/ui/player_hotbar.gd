class_name PlayerHotbar
extends PanelContainer

## The quick-use row: ten slots keyed 1-9 and 0, each bound to a
## backpack item. The bar only displays and clicks; binding happens in
## the inventory screen, consumption in the scene's use handler.

const SLOT_SIZE := Vector2(40.0, 40.0)

var _get_settings: Callable
var _get_inventory: Callable
var _on_use: Callable

var _buttons: Array[Button] = []
var _counts: Array[Label] = []
var _keys: Array[Label] = []

func setup(get_settings: Callable, get_inventory: Callable, on_use: Callable) -> void:
	_get_settings = get_settings
	_get_inventory = get_inventory
	_on_use = on_use
	_build_ui()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.11, 0.08, 0.92)
	style.border_color = Color(0.6, 0.48, 0.32, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for index in GearService.HOTBAR_SLOTS:
		var slot_button := Button.new()
		slot_button.custom_minimum_size = SLOT_SIZE
		slot_button.expand_icon = true
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.24, 0.18, 0.13, 1.0)
		slot_style.border_color = Color(0.48, 0.38, 0.27, 1.0)
		slot_style.set_border_width_all(2)
		slot_style.set_corner_radius_all(4)
		slot_button.add_theme_stylebox_override("normal", slot_style)
		var hover_style := slot_style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.85, 0.72, 0.45, 1.0)
		slot_button.add_theme_stylebox_override("hover", hover_style)
		slot_button.add_theme_stylebox_override("pressed", hover_style)
		slot_button.pressed.connect(func() -> void:
			if _on_use.is_valid():
				_on_use.call(index))
		row.add_child(slot_button)
		_buttons.append(slot_button)
		var key_label := Label.new()
		key_label.text = str((index + 1) % 10)
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.66, 1.0))
		key_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
		key_label.add_theme_constant_override("outline_size", 3)
		key_label.position = Vector2(3.0, 1.0)
		slot_button.add_child(key_label)
		_keys.append(key_label)
		var count_label := Label.new()
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
		count_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
		count_label.add_theme_constant_override("outline_size", 3)
		count_label.position = Vector2(SLOT_SIZE.x - 19.0, SLOT_SIZE.y - 16.0)
		slot_button.add_child(count_label)
		_counts.append(count_label)

func refresh() -> void:
	if _buttons.is_empty():
		return
	var settings: Dictionary = _get_settings.call()
	var inventory: Dictionary = _get_inventory.call()
	var bindings: Array = GearService.hotbar_bindings(settings)
	for index in _buttons.size():
		var slot_button := _buttons[index]
		var item_name := String(bindings[index])
		if item_name.is_empty():
			slot_button.icon = null
			slot_button.tooltip_text = "Empty — bind items from the pack (I)"
			slot_button.modulate = Color(1.0, 1.0, 1.0, 0.65)
			_counts[index].text = ""
			continue
		var carried := int(inventory.get(item_name, 0))
		slot_button.icon = ItemDefsService.icon_texture(item_name)
		slot_button.tooltip_text = "%s ×%d" % [item_name, carried]
		# A dry binding waits, dimmed, for resupply.
		slot_button.modulate = Color.WHITE if carried > 0 else Color(1.0, 1.0, 1.0, 0.35)
		_counts[index].text = "×%d" % carried if carried > 1 else ""

func flash(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	var slot_button := _buttons[index]
	slot_button.modulate = Color(1.6, 1.5, 1.1, 1.0)
	var tween := create_tween()
	tween.tween_property(slot_button, "modulate", Color.WHITE, 0.3)

## Docks the bar bottom-center of its parent control.
func reposition() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	reset_size()
	position = Vector2((parent_control.size.x - size.x) * 0.5, parent_control.size.y - size.y - 10.0)
