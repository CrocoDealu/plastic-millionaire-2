@tool
class_name ContentButton
extends Button

## A sprite Button whose first child (a Container) is the label layout, e.g. "SELL 10" over "$9.80".
## Sizes itself to the child plus the stylebox margins.

func _ready() -> void:
	var c := _content()
	if c:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.minimum_size_changed.connect(_fit)
	resized.connect(_layout)
	theme_changed.connect(_fit)
	_fit()


func _content() -> Control:
	return get_child(0) as Control if get_child_count() > 0 else null


func _fit() -> void:
	var c := _content()
	if c == null:
		return
	var sb := get_theme_stylebox(&"normal")
	custom_minimum_size = c.get_combined_minimum_size() + sb.get_minimum_size()
	_layout()


func _layout() -> void:
	var c := _content()
	if c == null:
		return
	var sb := get_theme_stylebox(&"normal")
	c.position = Vector2(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP))
	c.size = size - sb.get_minimum_size()
