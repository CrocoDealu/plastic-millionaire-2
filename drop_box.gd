class_name DropBox
extends RigidBody2D

enum Category {
	JUNK,
	PLASTIC,
	GOLD,
}

var box_size: Vector2 = Vector2(42.0, 42.0)
var box_color: Color = Color("#f2a65a")
var accent_color: Color = Color("#fff0c2")
var category: Category = Category.JUNK
var is_collected := false
var resource_id: StringName = &"junk"

func configure(new_size: Vector2, new_color: Color, new_category: int) -> void:
	box_size = new_size
	box_color = new_color
	accent_color = new_color.lightened(0.35)
	category = new_category
	resource_id = &"gold" if category == Category.GOLD else (&"junk" if category == Category.JUNK else &"plastic")
	_build_collision()
	queue_redraw()

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 1
	lock_rotation = false
	collision_layer = 2
	collision_mask = 1
	queue_redraw()

func _build_collision() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)
	var shape := RectangleShape2D.new()
	shape.size = box_size * 0.72
	collision.shape = shape

func _draw() -> void:
	var visual_size := box_size * 0.72
	var rect := Rect2(-visual_size * 0.5, visual_size)
	draw_style_box(_make_box_style(box_color, 8.0), rect)
	draw_line(
		Vector2(-visual_size.x * 0.28, -visual_size.y * 0.5 + 7.0),
		Vector2(visual_size.x * 0.28, -visual_size.y * 0.5 + 7.0),
		accent_color,
		3.0,
		true
	)
	if category == Category.GOLD:
		draw_circle(Vector2.ZERO, visual_size.x * 0.23, accent_color)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-4.0, 5.0),
			"$",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			box_color.darkened(0.35)
		)
	else:
		draw_circle(Vector2(visual_size.x * 0.22, visual_size.y * 0.23), 3.0, accent_color)

func _make_box_style(color: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius))
	return style
