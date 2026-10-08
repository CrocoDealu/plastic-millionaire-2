extends Control

## Wires RecyclerGame to the Control Room scene. Layout and styling live in main.tscn,
## ui/*.tscn and ui/control_room_theme.tres; this script only connects signals and updates values.

const GAME_SCRIPT := preload("res://recycler_game.gd")
const BAG_SCALE := 2.0
const BAG_TOP := 110.0
const TOAST_SECONDS := 2.6
const CLICK_EFFECT_SCENE := preload("res://effects/click_effect.tscn")
const BAG_BURST_SCENE := preload("res://effects/bag_burst.tscn")
const DROP_PICKUP_DELAY := 0.5
const DROP_COLORS := [Color("#ff8a65"), Color("#64b5f6"), Color("#81c784"), Color("#ba68c8"), Color("#ffd54f")]
const DROP_SIZES := [Vector2(34.0, 34.0), Vector2(42.0, 42.0), Vector2(50.0, 50.0)]
const GOLD_DROP_COLOR := Color("#d9a441")
const MESSAGE_KINDS := {
	&"info": [&"MessageInfo", UiConst.CYAN, "STATUS"],
	&"good": [&"MessageGood", UiConst.GREEN, "RECYCLED"],
	&"gold": [&"MessageGold", UiConst.GOLD, "VALUABLE"],
	&"warn": [&"MessageWarn", UiConst.WARN, "NEEDS ATTENTION"],
}

@export var scanlines := true

var game: RecyclerGame = GAME_SCRIPT.new()
var _dirty := true
var _refresh_timer := 0.0
var _collector_timer := 0.0
var _toast_timer := 0.0
var _bag_breaking := false
var _bag_tween: Tween
var _dragging_pickup := false

@onready var chips := {
	&"plastic": %ChipPlastic, &"flakes": %ChipFlakes, &"pellets": %ChipPellets,
	&"fabric": %ChipFabric, &"junk": %ChipJunk, &"gold": %ChipGold,
}
@onready var stock_rows := {
	&"plastic": %StockPlastic, &"flakes": %StockFlakes, &"pellets": %StockPellets,
	&"fabric": %StockFabric, &"junk": %StockJunk, &"gold": %StockGold,
}

func _ready() -> void:
	add_child(game)
	%Scanlines.visible = scanlines
	%Production.bind(game)
	%Modal.game = game
	%Production.upgrades_requested.connect(func(id: StringName) -> void: %Modal.open("gen:%s" % id))
	%NavProduction.pressed.connect(%Production.open)
	%NavShop.pressed.connect(%Modal.open.bind("shop"))
	%NavAutomation.pressed.connect(%Modal.open.bind("auto"))
	%NavMilestones.pressed.connect(%Modal.open.bind("ach"))
	%Sell.pressed.connect(game.sell_materials)
	for id: StringName in stock_rows:
		var value: float = game.resource_values.get(id, 0.0)
		stock_rows[id].set_price("$%.2f" % value if value < 1.0 else "$%d" % value)
	game.inventory_changed.connect(_mark_dirty)
	game.bag_changed.connect(_mark_dirty)
	game.message_changed.connect(_show_message)
	game.achievement_unlocked.connect(_show_toast)
	game.drops_spawned.connect(_spawn_drops)
	_show_message("Hit the bag, collect the drops and feed the production chain.", &"info")

func _process(delta: float) -> void:
	if _dragging_pickup and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_collect_under_mouse()
	else:
		_dragging_pickup = false
	_refresh_timer -= delta
	if _dirty or _refresh_timer <= 0.0:
		_refresh()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		%Toast.visible = _toast_timer > 0.0
	if game.is_collector_enabled():
		_collector_timer -= delta
		if _collector_timer <= 0.0:
			_collector_timer = game.collector_check_interval
			_collector_sweep()

# Click or drag over landed drops to collect them (ignored while an overlay is open).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_pickup = event.pressed and not (%Production.visible or %Modal.visible)
		if _dragging_pickup:
			_collect_under_mouse()

func _mark_dirty() -> void:
	_dirty = true

func _refresh() -> void:
	_dirty = false
	_refresh_timer = 0.1
	var inventory: ResourceInventory = game.inventory
	for id: StringName in chips:
		var amount := UiConst.fmt(inventory.get_amount(id))
		chips[id].set_value(amount)
		stock_rows[id].set_amount(amount)
	%Money.text = "$ %s" % UiConst.fmt(inventory.get_amount(&"money"))
	%Sell.text = "SELL MATERIALS · $ %s" % UiConst.fmt(game.sell_value(game.sellable_amounts()))
	_refresh_bag()
	var collector_on := game.is_collector_enabled()
	%CollectorBox.visible = collector_on
	%CollectorLabel.text = "COLLECTOR BOX · %d/SWEEP" % game.get_collector_capacity() if collector_on else "COLLECTOR BOX · NOT OWNED"
	%CollectorLabel.add_theme_color_override("font_color", UiConst.GREEN if collector_on else UiConst.LOCKED)
	_refresh_nav()
	%Production.refresh()
	%Modal.refresh()

func _refresh_bag() -> void:
	var bag: BagSystem = game.bag
	var green: bool = game.shop_purchases.get(&"shop_u_bag_upgrade", false)
	%BagName.text = "REINFORCED GREEN BAG" if green else "BLACK BAG"
	%BagStats.text = "DMG %d · GOLD %d%%" % [bag.click_damage, roundi(bag.gold_chance * 100.0)]
	var bag_rect: TextureRect = %Bag
	if bag_rect.texture.resource_path != game.bag_texture_path:
		bag_rect.texture = load(game.bag_texture_path)
		var bag_size := bag_rect.texture.get_size() * BAG_SCALE
		bag_rect.offset_left = -bag_size.x * 0.5
		bag_rect.offset_right = bag_size.x * 0.5
		bag_rect.offset_bottom = BAG_TOP + bag_size.y
		bag_rect.pivot_offset = bag_size * 0.5
	var remaining := bag.clicks_to_burst - bag.clicks
	var alpha := bag.alpha_stage_1
	if remaining <= bag.alpha_stage_2_remaining:
		alpha = bag.alpha_stage_3
	elif remaining <= bag.alpha_stage_1_remaining:
		alpha = bag.alpha_stage_2
	bag_rect.modulate.a = alpha
	%HpFill.set_anchor(SIDE_RIGHT, float(remaining) / float(bag.clicks_to_burst), true)
	%HpLabel.text = "%d / %d HITS LEFT" % [remaining, bag.clicks_to_burst]

func _refresh_nav() -> void:
	var total := game.generators.size()
	var running := 0
	var done := 0
	var stuck := 0
	for generator: GeneratorModel in game.generators.values():
		if not generator.pending_output.is_empty():
			done += 1
		elif generator.running:
			running += 1
		elif generator.owned > 0 and not game.inventory.can_afford(generator.recipe):
			stuck += 1
	if done > 0:
		%NavProduction.show_state(&"NavGold", "%d DONE" % done, &"BadgeGold", UiConst.ROOT, "%d machine%s ready to collect." % [done, "s" if done > 1 else ""])
	else:
		var sub := "%d machine%s waiting for input." % [stuck, "s" if stuck > 1 else ""] if stuck > 0 else "%d of %d machines running." % [running, total]
		%NavProduction.show_state(&"NavCyan", "%d/%d" % [running, total], &"BadgeGreen", UiConst.GREEN, sub)
	var owned := func(ids: Array[StringName]) -> int: return ids.filter(func(id: StringName) -> bool: return game.shop_purchases.get(id, false)).size()
	var unlocked: int = game.achievements.values().count(true)
	%NavShop.show_state(&"NavShop", "%d/%d" % [owned.call(ModalOverlay.BAG_SHOP_IDS), ModalOverlay.BAG_SHOP_IDS.size()], &"BadgeGoldDark", UiConst.GOLD, "Bag damage, gold chance, the green bag.")
	%NavAutomation.show_state(&"NavAutomation", "%d/%d" % [owned.call(ModalOverlay.AUTOMATION_SHOP_IDS), ModalOverlay.AUTOMATION_SHOP_IDS.size()], &"BadgeGreen", UiConst.GREEN, "Collector Box and Box Motor.")
	%NavMilestones.show_state(&"NavMilestones", "%d/%d" % [unlocked, game.achievements.size()], &"BadgeGold", UiConst.ROOT, "Golden Masterbatch: +%d%% speed." % (unlocked * 5))

func _on_bag_gui_input(event: InputEvent) -> void:
	if _bag_breaking or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var bag_rect: TextureRect = %Bag
	_play_click_effect(bag_rect.get_global_transform_with_canvas() * event.position)
	if _bag_tween != null and _bag_tween.is_valid():
		_bag_tween.kill()
	bag_rect.scale = Vector2.ONE
	_bag_tween = create_tween()
	_bag_tween.tween_property(bag_rect, "scale", Vector2(0.92, 0.92), 0.07)
	_bag_tween.tween_property(bag_rect, "scale", Vector2(1.04, 1.04), 0.12)
	_bag_tween.tween_property(bag_rect, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC)
	game.click_bag()

func _play_click_effect(effect_position: Vector2) -> void:
	var effect := CLICK_EFFECT_SCENE.instantiate() as AnimatedSprite2D
	%Effects.add_child(effect)
	effect.global_position = effect_position
	effect.scale = Vector2(0.85, 0.85)
	effect.animation_finished.connect(effect.queue_free)
	effect.play(&"click")

# Runtime-spawned effects and physics drops are the only nodes built in code.
func _spawn_drops(drops: Dictionary) -> void:
	var bag_rect: TextureRect = %Bag
	var center := bag_rect.get_global_rect().get_center()
	_bag_breaking = true
	bag_rect.visible = false
	var burst := BAG_BURST_SCENE.instantiate() as AnimatedSprite2D
	%Effects.add_child(burst)
	burst.global_position = center
	burst.animation_finished.connect(func() -> void:
		burst.queue_free()
		_bag_breaking = false
		bag_rect.visible = true
		bag_rect.scale = Vector2.ONE)
	burst.play(&"burst")
	for id: StringName in drops:
		for _i in int(drops[id]):
			_spawn_drop(center, id)

func _spawn_drop(origin: Vector2, resource_id: StringName) -> void:
	var box := DropBox.new()
	var category := DropBox.Category.GOLD if resource_id == &"gold" else DropBox.Category.JUNK if resource_id == &"junk" else DropBox.Category.PLASTIC
	var color: Color = GOLD_DROP_COLOR if category == DropBox.Category.GOLD else DROP_COLORS.pick_random()
	box.configure(DROP_SIZES.pick_random(), color, category)
	%DroppedBoxes.add_child(box)
	box.global_position = origin
	box.rotation = randf_range(-0.18, 0.18)
	box.collision_layer = 0
	get_tree().create_timer(DROP_PICKUP_DELAY).timeout.connect(func() -> void:
		if is_instance_valid(box) and not box.is_collected:
			box.collision_layer = 2)
	box.apply_central_impulse(Vector2(randf_range(-180.0, 180.0), randf_range(-220.0, -100.0)))

func _collect_under_mouse() -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collision_mask = 2
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
	# Fly into the matching inventory chip in the top bar.
	var target: Vector2 = chips[box.resource_id].get_global_rect().get_center()
	var tween := box.create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "global_position", target, 0.28).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(box, "scale", Vector2(0.1, 0.1), 0.28).set_trans(Tween.TRANS_BACK)
	tween.tween_property(box, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(box.queue_free)

func _collector_sweep() -> void:
	var boxes: Array = %DroppedBoxes.get_children().filter(func(box: DropBox) -> bool: return not box.is_collected)
	if boxes.is_empty():
		return
	var stage: Control = %Stage
	_step_move(%CollectorBox, Vector2(boxes[0].global_position.x - stage.global_position.x - 22.0, %CollectorBox.position.y), 0.4, 6)
	for box: DropBox in boxes.slice(0, game.get_collector_capacity()):
		_collect_box(box)

# The Collector Box moves in discrete pixel steps (CSS steps(n)), never a smooth tween.
func _step_move(node: Control, target: Vector2, duration: float, steps: int) -> Tween:
	var origin := node.position
	var tween := node.create_tween()
	tween.tween_method(func(t: float) -> void: node.position = origin.lerp(target, floorf(t * steps) / steps), 0.0, 1.0, duration)
	return tween

func _show_message(text: String, kind: StringName) -> void:
	var look: Array = MESSAGE_KINDS.get(kind, MESSAGE_KINDS[&"info"])
	%Message.theme_type_variation = look[0]
	%MessageTag.text = look[2]
	%MessageTag.add_theme_color_override("font_color", look[1])
	%MessageText.text = text

func _show_toast(achievement_id: StringName) -> void:
	%ToastName.text = RecyclerGame.ACHIEVEMENT_INFO[achievement_id][0]
	%Toast.visible = true
	_toast_timer = TOAST_SECONDS
	_mark_dirty()
