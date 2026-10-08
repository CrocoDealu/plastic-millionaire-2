extends Control

const GAME_SCRIPT := preload("res://recycler_game.gd")
const DROP_BOX_SCRIPT := preload("res://drop_box.gd")
const CLICK_EFFECT_SCENE := preload("res://effects/click_effect.tscn")
const BAG_BURST_SCENE := preload("res://effects/bag_burst.tscn")
const CONSTANT_PROGRESS_SHADER := preload("res://effects/constant_progress.gdshader")

const DROP_PICKUP_DELAY := 0.5
const BOX_COLORS := [Color("#ff8a65"), Color("#64b5f6"), Color("#81c784"), Color("#ba68c8"), Color("#ffd54f")]
const BOX_SIZES := [Vector2(34.0, 34.0), Vector2(42.0, 42.0), Vector2(50.0, 50.0)]
const GOLD_COLOR := Color("#d9a441")
const ACHIEVEMENT_LOCKED_COLOR := Color("#587286")
const ACHIEVEMENT_UNLOCKED_COLOR := Color("#b9f58a")

var game = GAME_SCRIPT.new()

@onready var resource_labels: Dictionary[StringName, Label] = {
	&"plastic": %Plastic,
	&"flakes": %Flakes,
	&"pellets": %Pellets,
	&"fabric": %Fabric,
	&"money": %Money,
}
@onready var bag_button: Button = %BagButton
@onready var bag_texture: TextureRect = %BagTexture
@onready var message_label: Label = %Message
@onready var workshop_rows: Dictionary[StringName, Dictionary] = {
	&"g1_sorter": {"title": %G1Title, "recipe": %G1Recipe, "output": %G1Output, "rate": %G1Rate, "progress": %G1Progress, "buy": %G1Buy, "run": %G1Run, "collect": %G1Collect, "speed": %G1Speed, "multiplier": %G1Multiplier, "auto_in": %G1AutoIn, "auto_out": %G1AutoOut},
	&"g2_pelletizer": {"title": %G2Title, "recipe": %G2Recipe, "output": %G2Output, "rate": %G2Rate, "progress": %G2Progress, "buy": %G2Buy, "run": %G2Run, "collect": %G2Collect, "speed": %G2Speed, "multiplier": %G2Multiplier, "auto_in": %G2AutoIn, "auto_out": %G2AutoOut},
	&"g3_loom": {"title": %G3Title, "recipe": %G3Recipe, "output": %G3Output, "rate": %G3Rate, "progress": %G3Progress, "buy": %G3Buy, "run": %G3Run, "collect": %G3Collect, "speed": %G3Speed, "multiplier": %G3Multiplier, "auto_in": %G3AutoIn, "auto_out": %G3AutoOut},
}
@onready var shop_buttons: Dictionary[StringName, Button] = {
	&"shop_u_bag_dmg": %ShopBagDamage,
	&"shop_u_bag_gold": %ShopGoldChance,
	&"shop_u_bag_upgrade": %ShopBagUpgrade,
	&"shop_u_collector_base": %ShopCollector,
	&"shop_u_collector_speed": %ShopCollectorSpeed,
}
@onready var achievement_labels: Dictionary[StringName, Label] = {
	&"first_bag": %AchievementFirstBag,
	&"first_machine": %AchievementFirstMachine,
	&"first_pellets": %AchievementFirstPellets,
	&"first_fabric": %AchievementFirstFabric,
	&"industrialist": %AchievementIndustrialist,
}
@onready var box_layer: Node2D = $DroppedBoxes
@onready var ground: StaticBody2D = $Ground
@onready var ground_visual: ColorRect = $GroundVisual

var rng := RandomNumberGenerator.new()
var dropped_count := 0
var dragging_pickup := false
var bag_is_breaking := false
var bag_hit_count := 0
var bag_tween: Tween
var last_bag_hit_position := Vector2.ZERO
var constant_progress_material: ShaderMaterial
var collector_check_timer := 0.0

func _ready() -> void:
	rng.randomize()
	constant_progress_material = ShaderMaterial.new()
	constant_progress_material.shader = CONSTANT_PROGRESS_SHADER
	_center_bag_button_pivot()
	bag_button.gui_input.connect(_on_bag_gui_input)
	add_child(game)
	bag_button.pressed.connect(_on_bag_click)
	%SellMaterials.pressed.connect(_sell_refined)
	for generator_id in workshop_rows:
		var row: Dictionary = workshop_rows[generator_id]
		row["buy"].pressed.connect(game.buy_generator.bind(generator_id))
		row["run"].pressed.connect(game.run_generator.bind(generator_id))
		row["collect"].pressed.connect(game.collect_generator_output.bind(generator_id))
		for upgrade_id in [&"speed", &"multiplier", &"auto_in", &"auto_out"]:
			row[upgrade_id].pressed.connect(game.buy_generator_upgrade.bind(generator_id, upgrade_id))
	for upgrade_id in shop_buttons:
		shop_buttons[upgrade_id].pressed.connect(game.buy_shop_upgrade.bind(upgrade_id))
	game.inventory_changed.connect(_refresh)
	game.bag_changed.connect(_refresh_bag)
	game.generator_changed.connect(_refresh_generator)
	game.message_changed.connect(_show_message)
	game.achievements_changed.connect(_refresh_achievements)
	game.drops_spawned.connect(_spawn_drops)
	_update_ground()
	_refresh()

func _process(_delta: float) -> void:
	if dragging_pickup and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_collect_under_mouse(get_global_mouse_position())
	elif dragging_pickup:
		dragging_pickup = false
	if game.is_collector_enabled():
		collector_check_timer -= _delta
		if collector_check_timer <= 0.0:
			collector_check_timer = game.collector_check_interval
			_auto_collect_drops()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and is_node_ready():
		_update_ground()
		_center_bag_button_pivot()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_pickup = event.pressed
		if event.pressed:
			_collect_under_mouse(event.position)

func _on_bag_click() -> void:
	if bag_is_breaking:
		return
	var center := bag_button.get_global_rect().get_center()
	var hit_position := last_bag_hit_position if last_bag_hit_position != Vector2.ZERO else center
	last_bag_hit_position = Vector2.ZERO
	_play_click_effect(hit_position)
	bag_hit_count += game.bag.click_damage
	_update_bag_alpha()
	_animate_bag_hit()
	if bag_hit_count >= game.bag.clicks_to_burst:
		_break_bag(center)

func _animate_bag_hit() -> void:
	if bag_tween != null and bag_tween.is_valid():
		bag_tween.kill()
	bag_button.scale = Vector2.ONE
	bag_tween = create_tween()
	bag_tween.tween_property(bag_button, "scale", Vector2(0.92, 0.92), 0.07)
	bag_tween.tween_property(bag_button, "scale", Vector2(1.04, 1.04), 0.12)
	bag_tween.tween_property(bag_button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC)
	game.click_bag()

func _center_bag_button_pivot() -> void:
	bag_button.pivot_offset = bag_button.size * 0.5

func _break_bag(center: Vector2) -> void:
	bag_is_breaking = true
	bag_button.disabled = true
	bag_button.visible = false
	var burst := BAG_BURST_SCENE.instantiate() as AnimatedSprite2D
	burst.global_position = center
	add_child(burst)
	burst.animation_finished.connect(_finish_bag_break.bind(burst))
	burst.play(&"burst")

func _play_click_effect(effect_position: Vector2) -> void:
	var effect := CLICK_EFFECT_SCENE.instantiate() as AnimatedSprite2D
	effect.global_position = effect_position
	effect.scale = Vector2(0.85, 0.85)
	add_child(effect)
	effect.animation_finished.connect(effect.queue_free)
	effect.play(&"click")

func _finish_bag_break(burst: AnimatedSprite2D) -> void:
	if is_instance_valid(burst):
		burst.queue_free()
	bag_hit_count = 0
	bag_is_breaking = false
	bag_button.disabled = false
	bag_button.visible = true
	bag_button.scale = Vector2.ONE
	bag_button.modulate.a = 1.0

func _on_bag_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		last_bag_hit_position = bag_button.get_global_transform_with_canvas() * event.position
	elif event is InputEventScreenTouch and event.pressed:
		last_bag_hit_position = event.position

func _update_bag_alpha() -> void:
	var remaining: int = game.bag.clicks_to_burst - bag_hit_count
	var alpha: float = game.bag.alpha_stage_1
	if remaining <= game.bag.alpha_stage_2_remaining:
		alpha = game.bag.alpha_stage_3
	elif remaining <= game.bag.alpha_stage_1_remaining:
		alpha = game.bag.alpha_stage_2
	bag_button.modulate.a = alpha

func _spawn_drops(drops: Dictionary) -> void:
	var origin := bag_button.global_position + bag_button.size * 0.5
	for resource_id in drops:
		for _i in int(drops[resource_id]):
			_spawn_drop(origin, StringName(resource_id))
func _spawn_drop(origin: Vector2, resource_id: StringName) -> void:
	dropped_count += 1
	var box := DROP_BOX_SCRIPT.new()
	box.name = "DroppedItem_%d" % dropped_count
	var category := _category_for_resource(resource_id)
	var color: Color = GOLD_COLOR if category == DropBox.Category.GOLD else BOX_COLORS[rng.randi_range(0, BOX_COLORS.size() - 1)]
	box.configure(BOX_SIZES[rng.randi_range(0, BOX_SIZES.size() - 1)], color, category)
	box.global_position = origin
	box.rotation = rng.randf_range(-0.18, 0.18)
	box_layer.add_child(box)
	box.collision_layer = 0
	var pickup_timer := get_tree().create_timer(DROP_PICKUP_DELAY)
	pickup_timer.timeout.connect(_enable_drop_pickup.bind(box.get_instance_id()))
	box.apply_central_impulse(Vector2(rng.randf_range(-180.0, 180.0), rng.randf_range(-220.0, -100.0)))

func _category_for_resource(resource_id: StringName) -> int:
	if resource_id == &"gold":
		return DropBox.Category.GOLD
	if resource_id == &"junk":
		return DropBox.Category.JUNK
	return DropBox.Category.PLASTIC

func _enable_drop_pickup(instance_id: int) -> void:
	var box := instance_from_id(instance_id) as DropBox
	if is_instance_valid(box) and not box.is_collected:
		box.collision_layer = 2

func _collect_under_mouse(mouse_position: Vector2) -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_position
	query.collide_with_bodies = true
	query.collision_mask = 2
	query.exclude = [ground.get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_point(query, 32):
		var box := hit.get("collider") as DropBox
		if box != null:
			_collect_box(box)

func _collect_box(box: DropBox) -> void:
	if box.is_collected:
		return
	box.is_collected = true
	box.freeze = true
	box.collision_layer = 0
	game.collect_drop(box.resource_id)
	var target := Vector2(100.0, 50.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "global_position", target, 0.28).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(box, "scale", Vector2(0.1, 0.1), 0.28).set_trans(Tween.TRANS_BACK)
	tween.tween_property(box, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(box.queue_free)

func _auto_collect_drops() -> void:
	var collected := 0
	for child in box_layer.get_children():
		if collected >= game.get_collector_capacity():
			break
		var box := child as DropBox
		if box != null and not box.is_collected:
			_collect_box(box)
			collected += 1

func _update_ground() -> void:
	var y := get_viewport_rect().size.y - 92.0
	ground.position = Vector2(get_viewport_rect().size.x * 0.5, y + 12.0)
	ground_visual.position = Vector2(0.0, y)
	ground_visual.size = Vector2(get_viewport_rect().size.x, 24.0)

func _refresh() -> void:
	for resource_id in resource_labels:
		resource_labels[resource_id].text = "%s: %s" % [String(resource_id).capitalize(), _abbreviate(game.inventory.get_amount(resource_id))]
	for generator_id in workshop_rows:
		_refresh_generator(game.generators[generator_id])
	for upgrade_id in shop_buttons:
		var upgrade: Dictionary = game.shop_data[upgrade_id]
		var purchased: bool = game.shop_purchases.get(upgrade_id, false)
		shop_buttons[upgrade_id].text = "%s | Purchased" % upgrade["name"] if purchased else "%s | %s" % [upgrade["name"], _cost_text(upgrade["cost"])]
		shop_buttons[upgrade_id].disabled = purchased
		shop_buttons[upgrade_id].tooltip_text = _shop_upgrade_tooltip(upgrade_id, upgrade)
	_refresh_bag()
	_refresh_achievements()

func _refresh_generator(generator) -> void:
	if not workshop_rows.has(generator.id):
		return
	var row: Dictionary = workshop_rows[generator.id]
	row["title"].text = "%s | Owned: %d" % [generator.display_name, generator.owned]
	row["recipe"].text = "Recipe: %s" % _cost_text(generator.recipe)
	row["output"].text = "Stored output: %s" % _output_text(generator.pending_output)
	row["rate"].text = _production_rate_text(generator)
	row["progress"].value = generator.cycle_progress * 100.0
	row["buy"].text = "Buy | %s" % _cost_text(generator.purchase_cost)
	var speed_saturated: bool = generator.is_speed_saturated(game.global_speed)
	row["progress"].material = constant_progress_material if speed_saturated else null
	if speed_saturated:
		row["progress"].value = 100.0
	row["collect"].disabled = generator.pending_output.is_empty() or (speed_saturated and generator.auto_out)
	row["run"].disabled = generator.running or generator.owned == 0 or (speed_saturated and generator.auto_in)
	row["speed"].visible = not speed_saturated
	row["multiplier"].visible = not generator.is_multiplier_maxed()
	row["speed"].text = "Speed $%d" % _generator_upgrade_cost(generator, &"speed")
	row["multiplier"].text = "Yield $%d" % _generator_upgrade_cost(generator, &"multiplier")
	row["auto_in"].text = _automation_text("Auto-In", generator.auto_in_unlocked, generator.auto_in)
	row["auto_out"].text = _automation_text("Auto-Out", generator.auto_out_unlocked, generator.auto_out)
	row["speed"].tooltip_text = "Speed upgrade\nCurrent level: %d\nReduces cycle time by 20%% per level.\nNext level cycle time: %.2fs." % [
		generator.speed_level,
		generator.cycle_time(game.global_speed) * 0.8,
	]
	row["multiplier"].tooltip_text = "Yield multiplier\nCurrent level: %d\nDoubles output per level.\nNext level output: %dx." % [
		generator.multiplier_level,
		generator.output_multiplier() * 2,
	]
	row["auto_in"].tooltip_text = _automation_tooltip("Auto-In", generator.auto_in_unlocked, generator.auto_in, "Automatically starts a cycle when recipe resources are available.")
	row["auto_out"].tooltip_text = _automation_tooltip("Auto-Out", generator.auto_out_unlocked, generator.auto_out, "Automatically transfers completed output into inventory.")

func _generator_upgrade_cost(generator, upgrade_id: StringName) -> int:
	var upgrade: Dictionary = generator.upgrade_data.get(upgrade_id, {})
	var level: int = generator.speed_level if upgrade_id == &"speed" else generator.multiplier_level
	return int(upgrade.get("cost", 0)) + int(upgrade.get("cost_increment", 0)) * level

func _automation_text(label: String, unlocked: bool, enabled: bool) -> String:
	if not unlocked:
		return "%s $500" % label
	return "%s: ON" % label if enabled else "%s: OFF" % label

func _production_rate_text(generator) -> String:
	var cycle_time: float = generator.cycle_time(game.global_speed)
	var speed_saturated: bool = generator.is_speed_saturated(game.global_speed)
	var unit := "s" if speed_saturated else "cycle"
	if generator.owned <= 0 or cycle_time <= 0.0:
		var empty_resource_id: StringName = StringName(generator.output.keys()[0])
		return "Production: 0 %s/%s" % [String(empty_resource_id).capitalize(), unit]
	var rate_parts: Array[String] = []
	for resource_id in generator.output:
		var cycle_output: int = int(generator.output[resource_id]) * generator.owned * generator.output_multiplier()
		var amount: float = float(cycle_output) / cycle_time if speed_saturated else float(cycle_output)
		var precision: String = "%.2f" if speed_saturated else "%.0f"
		rate_parts.append("%s %s/%s" % [precision % amount, String(resource_id).capitalize(), unit])
	return "Production: %s" % ", ".join(rate_parts)

func _automation_tooltip(label: String, unlocked: bool, enabled: bool, description: String) -> String:
	if not unlocked:
		return "%s\n%s\nCurrent state: Locked\nNext purchase: unlocks this feature for $500 and turns it ON." % [label, description]
	var state := "ON" if enabled else "OFF"
	var next_state := "OFF" if enabled else "ON"
	return "%s\n%s\nCurrent state: %s\nNext click: turns it %s for free." % [label, description, state, next_state]

func _refresh_bag() -> void:
	_update_bag_alpha()
	bag_texture.texture = load(game.bag_texture_path)

func _refresh_achievements() -> void:
	for achievement_id in achievement_labels:
		var unlocked: bool = game.achievements[achievement_id]
		var label: Label = achievement_labels[achievement_id]
		label.text = ("✓ " if unlocked else "○ ") + String(achievement_id).replace("_", " ").capitalize()
		label.add_theme_color_override("font_color", ACHIEVEMENT_UNLOCKED_COLOR if unlocked else ACHIEVEMENT_LOCKED_COLOR)

func _sell_refined() -> void:
	for resource_id in [&"flakes", &"pellets", &"fabric", &"gold"]:
		game.sell_resource(resource_id)

func _show_message(text: String) -> void:
	message_label.text = text

func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in cost:
		parts.append("%d %s" % [cost[resource_id], String(resource_id)])
	return ", ".join(parts)

func _output_text(output: Dictionary) -> String:
	if output.is_empty():
		return "None"
	var parts: Array[String] = []
	for resource_id in output:
		parts.append("%s %s" % [_abbreviate(int(output[resource_id])), String(resource_id)])
	return ", ".join(parts)

func _shop_upgrade_tooltip(upgrade_id: StringName, upgrade: Dictionary) -> String:
	var description: String = String(upgrade.get("description", "Improves the recycling operation."))
	if game.shop_purchases.get(upgrade_id, false):
		return "%s\nPurchased and active.\nNo further level." % description
	return "%s\nNext purchase: %s." % [description, _cost_text(upgrade["cost"])]

func _abbreviate(value: int) -> String:
	if value >= 1000000:
		return "%.1fm" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fk" % (float(value) / 1000.0)
	return str(value)
