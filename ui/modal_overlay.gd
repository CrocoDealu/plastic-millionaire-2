class_name ModalOverlay
extends Control

## Shop, Automation, Milestones and Machine detail share this panel; open() picks the content.

const MODAL_ROW := preload("res://ui/modal_row.tscn")
const MAX_HEIGHT := 640.0
const BAG_SHOP_IDS: Array[StringName] = [&"shop_u_bag_dmg", &"shop_u_bag_gold", &"shop_u_bag_upgrade"]
const AUTOMATION_SHOP_IDS: Array[StringName] = [&"shop_u_collector_base", &"shop_u_collector_speed"]

var game: RecyclerGame
var _kind := ""
var _specs: Array = []

## kind: "shop", "auto", "ach" or "gen:<generator id>".
func open(kind: String) -> void:
	_kind = kind
	for row in %Rows.get_children():
		%Rows.remove_child(row)
		row.queue_free()
	var spec := _spec()
	for index in spec["rows"].size():
		var row := MODAL_ROW.instantiate()
		row.pressed.connect(_on_row_pressed.bind(index))
		%Rows.add_child(row)
	_show(spec)
	visible = true
	%Scroll.scroll_vertical = 0
	_fit()

func close() -> void:
	visible = false
	_kind = ""

func refresh() -> void:
	if visible:
		_show(_spec())

# Wrapped labels only know their height after layout, so size the scroll area a couple of frames later.
func _fit() -> void:
	%Panel.modulate.a = 0.0
	%Scroll.custom_minimum_size.y = 0
	await get_tree().process_frame
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Content.get_combined_minimum_size().y, MAX_HEIGHT - 44.0)
	%Panel.modulate.a = 1.0

func _show(spec: Dictionary) -> void:
	%Kicker.text = spec["kicker"]
	%Kicker.add_theme_color_override("font_color", spec["kicker_color"])
	%Title.text = spec["title"]
	%Sprite.visible = spec.has("sprite")
	%Sprite.text = spec.get("sprite", "")
	%Intro.text = spec["intro"]
	_specs = spec["rows"]
	var money: int = game.inventory.get_amount(&"money")
	for index in _specs.size():
		%Rows.get_child(index).show_spec(_specs[index], money)

func _on_row_pressed(index: int) -> void:
	var action: Callable = _specs[index].get("action", Callable())
	if action.is_valid():
		action.call()
		refresh()

func _on_close_pressed() -> void:
	close()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _spec() -> Dictionary:
	if _kind == "shop":
		var bag: BagSystem = game.bag
		var green: bool = game.shop_purchases.get(&"shop_u_bag_upgrade", false)
		return {
			"kicker": "SHOP · MONEY", "kicker_color": UiConst.GOLD, "title": "BAG UPGRADES",
			"intro": "Current bag: %s. %d damage per click, %d hits to burst, %d%% gold chance." % [
				"Reinforced Green Bag" if green else "Black Bag", bag.click_damage, bag.clicks_to_burst, roundi(bag.gold_chance * 100.0)],
			"rows": BAG_SHOP_IDS.map(_shop_row.bind("BAG")),
		}
	if _kind == "auto":
		return {
			"kicker": "AUTOMATION", "kicker_color": UiConst.GREEN, "title": "COLLECTION AUTOMATION",
			"intro": "Pick up bag drops without clicking. Machine Auto-In / Auto-Out lives in each machine's upgrades.",
			"rows": AUTOMATION_SHOP_IDS.map(_shop_row.bind("COLLECTION")),
		}
	if _kind == "ach":
		var unlocked: int = game.achievements.values().count(true)
		var rows: Array = []
		for id: StringName in game.achievements:
			var done: bool = game.achievements[id]
			var info: Array = RecyclerGame.ACHIEVEMENT_INFO[id]
			rows.append({"name": info[0], "tag": "+5% SPEED" if done else "", "desc": info[1],
				"button": "UNLOCKED" if done else "LOCKED", "style": "achieved" if done else "unachieved"})
		return {
			"kicker": "MILESTONES · %d/%d" % [unlocked, game.achievements.size()], "kicker_color": UiConst.GOLD, "title": "ACHIEVEMENTS",
			"intro": "Each one awards a Golden Masterbatch Pellet: +5%% global cycle speed. Current bonus: +%d%%." % (unlocked * 5),
			"rows": rows,
		}
	return _machine_spec(StringName(_kind.trim_prefix("gen:")))

func _shop_row(id: StringName, tag: String) -> Dictionary:
	var upgrade: Dictionary = game.shop_data[id]
	var row := {"name": upgrade[&"name"], "tag": tag, "desc": upgrade[&"description"], "cost": int(upgrade[&"cost"].get(&"money", 0)),
		"action": game.buy_shop_upgrade.bind(id)}
	if game.shop_purchases.get(id, false):
		row.merge({"button": "OWNED", "style": "owned", "action": Callable()}, true)
	elif not game.is_shop_upgrade_available(id):
		row.merge({"button": "NEEDS BOX", "style": "locked", "action": Callable()}, true)
	return row

func _machine_spec(id: StringName) -> Dictionary:
	var generator := game.generators[id] as GeneratorModel
	var cycle := generator.cycle_time(game.global_speed)
	var multiplier := generator.output_multiplier()
	var output_id: StringName = generator.output.keys()[0]
	var rows: Array = [
		{"name": "Machines · OWNED %d" % generator.owned, "tag": game.recipe_text(generator.purchase_cost).to_upper(),
			"desc": "Each machine adds a full batch to every cycle.", "button": "BUY",
			"style": "afford" if game.inventory.can_afford(generator.purchase_cost) else "expensive",
			"action": game.buy_generator.bind(id)},
	]
	if generator.is_speed_saturated(game.global_speed):
		rows.append({"name": "Speed · LV %d" % generator.speed_level, "tag": "%.2fs" % cycle, "desc": "Cycle time is at its limit.", "button": "MAXED", "style": "owned"})
	else:
		rows.append({"name": "Speed · LV %d" % generator.speed_level, "tag": "%.1fs → %.1fs" % [cycle, cycle * 0.8],
			"desc": "Reduces cycle time by 20%.", "cost": generator.upgrade_cost(&"speed"),
			"action": game.buy_generator_upgrade.bind(id, &"speed")})
	var multiplier_name := "Multiplier · LV %d/%d" % [generator.multiplier_level, generator.max_multiplier_level]
	if generator.is_multiplier_maxed():
		rows.append({"name": multiplier_name, "tag": "x%d" % multiplier, "desc": "Output yield is at its limit.", "button": "MAXED", "style": "owned"})
	else:
		rows.append({"name": multiplier_name, "tag": "x%d → x%d" % [multiplier, multiplier * 2],
			"desc": "Doubles output yield per batch.", "cost": generator.upgrade_cost(&"multiplier"),
			"action": game.buy_generator_upgrade.bind(id, &"multiplier")})
	for upgrade: Array in [[&"auto_in", "Auto-In", "Consumes resources and starts cycles on its own.", generator.auto_in_unlocked, generator.auto_in],
			[&"auto_out", "Auto-Out", "Automatically collects finished goods.", generator.auto_out_unlocked, generator.auto_out]]:
		var row := {"name": upgrade[1], "tag": "AUTOMATION", "desc": upgrade[2], "cost": generator.upgrade_cost(upgrade[0]),
			"action": game.buy_generator_upgrade.bind(id, upgrade[0])}
		if upgrade[3]:
			row.merge({"button": "ON" if upgrade[4] else "OFF", "style": "owned" if upgrade[4] else "toggle_off"}, true)
		rows.append(row)
	return {
		"kicker": "MACHINE %d / %d" % [game.generators.keys().find(id) + 1, game.generators.size()], "kicker_color": UiConst.CYAN,
		"title": generator.display_name.to_upper(),
		"sprite": "%s · animated when running" % UiConst.MACHINE_SPRITES.get(id, "machine sprite"),
		"intro": "%s → %d %s every %.1fs." % [game.recipe_text(generator.recipe), int(generator.output[output_id]) * maxi(generator.owned, 1) * multiplier, output_id, cycle],
		"rows": rows,
	}
