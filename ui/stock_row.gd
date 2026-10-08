@tool
extends HBoxContainer

@export var display_name := "Plastic":
	set(value):
		display_name = value
		_apply()
@export var color := Color.WHITE:
	set(value):
		color = value
		_apply()
@export var name_color := UiConst.TEXT:
	set(value):
		name_color = value
		_apply()

func _ready() -> void:
	_apply()

func set_amount(text: String) -> void:
	%Name.text = "%s x%s" % [display_name, text]

func set_price(text: String) -> void:
	%Price.text = text

func _apply() -> void:
	if not is_node_ready():
		return
	%Name.text = display_name
	%Swatch.color = color
	%Name.add_theme_color_override("font_color", name_color)
