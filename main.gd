extends Control

const DROP_BOX_SCRIPT := preload("res://drop_box.gd")
const CLICK_EFFECT_SCENE := preload("res://effects/click_effect.tscn")
const BAG_BURST_SCENE := preload("res://effects/bag_burst.tscn")
const BLACK_BAG_TEXTURE := preload("res://assets/black_bag.png")
const GREEN_BAG_TEXTURE := preload("res://assets/green_bag.png")
const BLACK_BAG_BREAK_HITS := 5
const GREEN_BAG_BREAK_HITS := 10
const BLACK_BAG_BOX_REWARD := 3
const GREEN_BAG_BOX_REWARD := 5
const DROP_PICKUP_DELAY := 0.5
const BASE_GOLD_SPAWN_CHANCE := 0.15
const BLUE_BAG_TEXTURE := preload("res://assets/green_bag.png")
const BOX_COLORS := [
	Color("#ff8a65"),
	Color("#64b5f6"),
	Color("#81c784"),
	Color("#ba68c8"),
	Color("#ffd54f"),
]
const BOX_SIZES := [
	Vector2(34.0, 34.0),
	Vector2(42.0, 42.0),
	Vector2(50.0, 50.0),
]
const BOX_CATEGORIES := [
	DropBox.Category.JUNK,
	DropBox.Category.PLASTIC,
]
const GOLD_COLOR := Color("#d9a441")

@onready var dispenser_button: Button = %Dispenser
@onready var count_label: Label = %Count
@onready var junk_count_label: Label = %JunkCount
@onready var plastic_count_label: Label = %PlasticCount
@onready var gold_label: Label = %Gold
@onready var box_layer: Node2D = $DroppedBoxes
@onready var ground: StaticBody2D = $Ground
@onready var ground_visual: ColorRect = $GroundVisual
@onready var upgrade_status_label: Label = %UpgradeStatus
@onready var power_upgrade_button: Button = %PowerUpgrade
@onready var drops_upgrade_button: Button = %DropsUpgrade
@onready var gold_upgrade_button: Button = %GoldUpgrade
@onready var auto_upgrade_button: Button = %AutoUpgrade
@onready var blue_upgrade_button: Button = %BlueUpgrade

var dropped_count := 0
var collected_count := 0
var junk_count := 0
var plastic_count := 0
var gold := 0
var rng := RandomNumberGenerator.new()
var ground_y := 0.0
var dragging_pickup := false
var dispenser_tween: Tween
var last_dispenser_click_position := Vector2.ZERO
var bag_hit_count := 0
var bag_is_breaking := false
var click_power := 1
var bonus_drops := 0
var gold_chance_bonus := 0.0
var auto_break_level := 0
var auto_break_elapsed := 0.0
var blue_bag_unlocked := false
var upgrade_buttons: Dictionary[StringName, Button] = {}

func _ready() -> void:
	rng.randomize()
	dispenser_button.gui_input.connect(_on_dispenser_gui_input)
	ground_y = get_viewport_rect().size.y - 88.0
	_update_ground()
	_update_resource_display()
	upgrade_buttons = {
		&"power": power_upgrade_button,
		&"drops": drops_upgrade_button,
		&"gold": gold_upgrade_button,
		&"auto": auto_upgrade_button,
		&"blue": blue_upgrade_button,
	}
	power_upgrade_button.pressed.connect(_buy_upgrade.bind(&"power"))
	drops_upgrade_button.pressed.connect(_buy_upgrade.bind(&"drops"))
	gold_upgrade_button.pressed.connect(_buy_upgrade.bind(&"gold"))
	auto_upgrade_button.pressed.connect(_buy_upgrade.bind(&"auto"))
	blue_upgrade_button.pressed.connect(_buy_upgrade.bind(&"blue"))
	_update_upgrade_panel()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and is_node_ready():
		ground_y = get_viewport_rect().size.y - 88.0
		_update_ground()

func _process(_delta: float) -> void:
	if dragging_pickup and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_collect_under_mouse(get_global_mouse_position())
	elif dragging_pickup:
		dragging_pickup = false
	if auto_break_level > 0 and not bag_is_breaking:
		auto_break_elapsed += _delta
		var auto_break_interval := maxf(1.8 - auto_break_level * 0.25, 0.55)
		if auto_break_elapsed >= auto_break_interval:
			auto_break_elapsed = 0.0
			last_dispenser_click_position = dispenser_button.global_position + dispenser_button.size * 0.5
			_drop_box()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_pickup = true
			_collect_under_mouse(event.position)
		else:
			dragging_pickup = false

func _drop_box() -> void:
	if bag_is_breaking:
		return
	var effect_position := last_dispenser_click_position
	if effect_position == Vector2.ZERO:
		effect_position = get_viewport().get_mouse_position()
	if effect_position == Vector2.ZERO:
		effect_position = dispenser_button.global_position + dispenser_button.size * 0.5
	last_dispenser_click_position = Vector2.ZERO
	_play_click_effect(effect_position)
	bag_hit_count += click_power
	var break_hits := GREEN_BAG_BREAK_HITS if blue_bag_unlocked else BLACK_BAG_BREAK_HITS
	if bag_hit_count >= break_hits:
		_break_bag()

	if dispenser_tween != null and dispenser_tween.is_valid():
		dispenser_tween.kill()
	dispenser_button.scale = Vector2.ONE
	dispenser_tween = create_tween()
	dispenser_tween.tween_property(
		dispenser_button,
		"scale",
		Vector2(0.9, 0.9),
		0.09
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dispenser_tween.tween_property(
		dispenser_button,
		"scale",
		Vector2(1.06, 1.06),
		0.16
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dispenser_tween.tween_property(
		dispenser_button,
		"scale",
		Vector2.ONE,
		0.2
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _break_bag() -> void:
	bag_is_breaking = true
	dispenser_button.disabled = true
	dispenser_button.visible = false
	var bag_center := dispenser_button.get_global_transform() * (dispenser_button.size * 0.5)
	var burst := BAG_BURST_SCENE.instantiate() as AnimatedSprite2D
	burst.global_position = bag_center
	burst.animation_finished.connect(_finish_bag_break.bind(burst))
	add_child(burst)
	burst.play(&"burst")
	var reward_count := GREEN_BAG_BOX_REWARD if blue_bag_unlocked else BLACK_BAG_BOX_REWARD
	reward_count += bonus_drops
	if blue_bag_unlocked:
		reward_count += 2
	for _i in reward_count:
		_spawn_box(bag_center)

func _finish_bag_break(burst: AnimatedSprite2D) -> void:
	if is_instance_valid(burst):
		burst.queue_free()
	bag_hit_count = 0
	bag_is_breaking = false
	dispenser_button.disabled = false
	dispenser_button.visible = true
	_update_dispenser_bag()

func _spawn_box(origin: Vector2) -> void:
	dropped_count += 1
	var box := DROP_BOX_SCRIPT.new() as DropBox
	box.name = "DroppedBox_%d" % dropped_count
	var category := _roll_drop_category()
	var color: Color = GOLD_COLOR if category == DropBox.Category.GOLD else BOX_COLORS[rng.randi_range(0, BOX_COLORS.size() - 1)]
	box.configure(
		BOX_SIZES[rng.randi_range(0, BOX_SIZES.size() - 1)],
		color,
		category
	)
	box.global_position = origin
	box.rotation = rng.randf_range(-0.18, 0.18)
	box_layer.add_child(box)
	box.collision_layer = 0
	get_tree().create_timer(DROP_PICKUP_DELAY).timeout.connect(_enable_box_pickup.bind(box))
	box.apply_central_impulse(Vector2(rng.randf_range(-140.0, 140.0), rng.randf_range(-180.0, -80.0)))

func _roll_drop_category() -> DropBox.Category:
	if rng.randf() < BASE_GOLD_SPAWN_CHANCE + gold_chance_bonus:
		return DropBox.Category.GOLD
	return BOX_CATEGORIES[rng.randi_range(0, BOX_CATEGORIES.size() - 1)]

func _enable_box_pickup(box: DropBox) -> void:
	if is_instance_valid(box) and not box.is_collected:
		box.collision_layer = 2

func _update_dispenser_bag() -> void:
	if blue_bag_unlocked:
		dispenser_button.icon = BLUE_BAG_TEXTURE
	else:
		dispenser_button.icon = BLACK_BAG_TEXTURE

func _on_dispenser_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		last_dispenser_click_position = dispenser_button.get_global_mouse_position()
	elif event is InputEventScreenTouch and event.pressed:
		last_dispenser_click_position = get_global_mouse_position()

func _play_click_effect(effect_position: Vector2) -> void:
	var effect := CLICK_EFFECT_SCENE.instantiate() as AnimatedSprite2D
	effect.global_position = effect_position
	effect.animation_finished.connect(effect.queue_free)
	add_child(effect)
	effect.play(&"click")

func _update_ground() -> void:
	ground.position = Vector2(get_viewport_rect().size.x * 0.5, ground_y + 12.0)
	ground_visual.position = Vector2(0.0, ground_y)
	ground_visual.size = Vector2(get_viewport_rect().size.x, 24.0)

func _collect_under_mouse(mouse_position: Vector2) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_position
	query.collide_with_bodies = true
	query.collision_mask = 2
	var hits := space_state.intersect_point(query, 32)
	for hit in hits:
		var body := hit.get("collider") as DropBox
		if body != null and is_instance_valid(body):
			_collect_box(body)

func _collect_box(box: DropBox) -> void:
	if box.is_collected:
		return
	box.is_collected = true
	box.freeze = true
	box.collision_layer = 0
	if box.category == DropBox.Category.GOLD:
		gold += 1
	else:
		collected_count += 1
	if box.category == DropBox.Category.PLASTIC:
		plastic_count += 1
	elif box.category == DropBox.Category.JUNK:
		junk_count += 1
	_update_resource_display()
	var target := Vector2(120.0, 90.0)
	if box.category == DropBox.Category.GOLD:
		target = Vector2(get_viewport_rect().size.x - 120.0, 90.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "global_position", target, 0.22).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(box, "scale", Vector2(0.1, 0.1), 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(box, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(box.queue_free)

func _update_resource_display() -> void:
	count_label.text = str(collected_count)
	junk_count_label.text = "Junk: %d" % junk_count
	plastic_count_label.text = "Plastic: %d" % plastic_count
	gold_label.text = str(gold)

func _buy_upgrade(upgrade: StringName) -> void:
	match upgrade:
		&"power":
			var cost := _power_cost()
			if junk_count < cost:
				_show_upgrade_status("Need %d junk for Stronger Fingers." % cost)
				return
			junk_count -= cost
			click_power += 1
			_show_upgrade_status("Stronger Fingers upgraded to level %d." % click_power)
		&"drops":
			var cost := _drops_cost()
			if plastic_count < cost:
				_show_upgrade_status("Need %d plastic for Bigger Bags." % cost)
				return
			plastic_count -= cost
			bonus_drops += 1
			_show_upgrade_status("Bigger Bags upgraded to level %d." % (bonus_drops + 1))
		&"gold":
			var cost := _gold_detector_cost()
			if gold < cost:
				_show_upgrade_status("Need %d gold for the Gold Detector." % cost)
				return
			gold -= cost
			gold_chance_bonus += 0.05
			_show_upgrade_status("Gold chance increased to %d%%." % roundi((BASE_GOLD_SPAWN_CHANCE + gold_chance_bonus) * 100.0))
		&"auto":
			var cost := _auto_cost()
			if gold < cost:
				_show_upgrade_status("Need %d gold to hire a collector." % cost)
				return
			gold -= cost
			auto_break_level += 1
			_show_upgrade_status("Collector level %d hired." % auto_break_level)
		&"blue":
			if blue_bag_unlocked:
				_show_upgrade_status("Blue Bags are already unlocked.")
				return
			if plastic_count < 50:
				_show_upgrade_status("Need 50 plastic to unlock Blue Bags.")
				return
			plastic_count -= 50
			blue_bag_unlocked = true
			_show_upgrade_status("Blue Bags unlocked: +2 boxes per break.")
			_update_dispenser_bag()
	_update_resource_display()
	_update_upgrade_panel()

func _power_cost() -> int:
	return 15 * click_power

func _drops_cost() -> int:
	return 10 * (bonus_drops + 1)

func _gold_detector_cost() -> int:
	return 4 + roundi(gold_chance_bonus * 100.0) * 2

func _auto_cost() -> int:
	return 8 * (auto_break_level + 1)

func _update_upgrade_panel() -> void:
	if upgrade_buttons.is_empty():
		return
	upgrade_buttons[&"power"].text = "Stronger Fingers  |  %d junk" % _power_cost()
	upgrade_buttons[&"drops"].text = "Bigger Bags  |  %d plastic" % _drops_cost()
	upgrade_buttons[&"gold"].text = "Gold Detector  |  %d gold" % _gold_detector_cost()
	upgrade_buttons[&"auto"].text = "Hire Collector  |  %d gold" % _auto_cost()
	upgrade_buttons[&"blue"].text = "Blue Bags  |  %s" % ("UNLOCKED" if blue_bag_unlocked else "50 plastic")
	upgrade_buttons[&"blue"].disabled = blue_bag_unlocked

func _show_upgrade_status(message: String) -> void:
	if upgrade_status_label != null:
		upgrade_status_label.text = message
