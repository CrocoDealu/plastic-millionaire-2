extends Control

## Drives across the floor in one pass (left→right, then right→left next time),
## reporting drops its PickupZone touches until `capacity` is reached.

signal drop_touched(box: DropBox)

@export var speed := 500.0
## Gap kept from the stage edges at each end of a pass.
@export var edge_margin := 16.0

var capacity := 3
var _taken := 0
var _tween: Tween

func _ready() -> void:
	%PickupZone.body_entered.connect(_on_body_entered)

func is_sweeping() -> bool:
	return _tween != null and _tween.is_running()

func sweep() -> void:
	if is_sweeping():
		return
	var width := get_parent_area_size().x
	var left := edge_margin
	var right := width - size.x - edge_margin
	var target := right if position.x < width * 0.5 else left
	_taken = 0
	_tween = create_tween()
	_tween.tween_property(self, "position:x", target, absf(target - position.x) / speed)
	# Drops already under the box at the start never fire body_entered.
	for body in %PickupZone.get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	var box := body as DropBox
	if is_sweeping() and _taken < capacity and box != null and not box.is_collected:
		_taken += 1
		drop_touched.emit(box)
