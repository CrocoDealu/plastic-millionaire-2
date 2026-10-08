@tool
extends Control

## Striped "sprite goes here" slot until real machine art exists.

@export var text := "machine sprite":
	set(value):
		text = value
		if is_node_ready():
			%Label.text = text

func _ready() -> void:
	%Label.text = text
