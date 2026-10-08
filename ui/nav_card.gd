@tool
extends Button

@export var title := "PRODUCTION":
	set(value):
		title = value
		if is_node_ready():
			%Title.text = title

func _ready() -> void:
	%Title.text = title
	# Buttons don't size to their children; follow the content's height (the subline wraps).
	%Content.minimum_size_changed.connect(_fit)
	_fit()

func show_state(variation: StringName, badge: String, badge_variation: StringName, badge_color: Color, sub: String) -> void:
	theme_type_variation = variation
	%Badge.theme_type_variation = badge_variation
	%BadgeLabel.text = badge
	%BadgeLabel.add_theme_color_override("font_color", badge_color)
	%Sub.text = sub

func _fit() -> void:
	custom_minimum_size.y = %Content.get_combined_minimum_size().y
