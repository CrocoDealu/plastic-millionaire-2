@tool
extends PanelContainer

@export var label := "PLASTIC":
	set(value):
		label = value
		_apply()
@export var color := Color.WHITE:
	set(value):
		color = value
		_apply()
@export var value_color := UiConst.TEXT:
	set(value):
		value_color = value
		_apply()

func _ready() -> void:
	_apply()

func set_value(text: String) -> void:
	%Value.text = text

func _apply() -> void:
	if not is_node_ready():
		return
	%Name.text = label
	%Swatch.color = color
	%Value.add_theme_color_override("font_color", value_color)
