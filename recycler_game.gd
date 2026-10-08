class_name RecyclerGame
extends Node

const INVENTORY_SCRIPT := preload("res://resource_inventory.gd")
const BAG_SCRIPT := preload("res://bag_system.gd")
const GENERATOR_SCRIPT := preload("res://generator_model.gd")
const DATA_PATH := "res://game_data.json"

signal inventory_changed
signal bag_changed
signal drops_spawned(drops: Dictionary)
signal message_changed(text: String, kind: StringName)
signal event_changed(active: bool, seconds_left: float)
signal achievement_unlocked(achievement_id: StringName)

var inventory = INVENTORY_SCRIPT.new()
var bag = BAG_SCRIPT.new()
var resource_values: Dictionary[StringName, float] = {}
var sell_plastic_reserve := 40
var generator_data: Array[Dictionary] = []
var shop_data: Dictionary[StringName, Dictionary] = {}
var generators: Dictionary[StringName, RefCounted] = {}
var shop_purchases: Dictionary[StringName, bool] = {}
var loose_drops: Dictionary[StringName, int] = {}
var global_speed := 1.0
var event_timer := 0.0
var event_initial_timer := 240.0
var event_duration := 20.0
var event_bonus_resources: Dictionary[StringName, int] = {}
var starting_inventory: Dictionary[StringName, int] = {}
var achievement_speed_bonus := 1.05
var bag_texture_path := "res://assets/black_bag.png"
var event_active := false
var event_remaining := 0.0
var bags_burst := 0
var collector_capacity := 0
var collector_enabled := false
var collector_check_interval := 0.75
const ACHIEVEMENT_INFO := {
	&"first_bag": ["First Burst", "Tear open your first bag."],
	&"first_machine": ["First Machine", "Buy your first production machine."],
	&"first_pellets": ["Pellet Maker", "Produce your first Poly-Pellet."],
	&"first_fabric": ["Weaver", "Produce your first Eco-Fabric."],
	&"industrialist": ["Industrialist", "Own 10 machines."],
}
var achievements := {
	&"first_bag": false,
	&"first_machine": false,
	&"first_pellets": false,
	&"first_fabric": false,
	&"industrialist": false,
}

func _ready() -> void:
	var data := _load_data()
	_configure_data(data)
	for resource_id in starting_inventory:
		inventory.add(resource_id, starting_inventory[resource_id])
	bag.configure(data["bag"])
	for generator_config in generator_data:
		var generator := GENERATOR_SCRIPT.new()
		generator.configure(generator_config)
		generators[generator.id] = generator
	bag.burst.connect(_on_bag_burst)
	inventory.changed.connect(func(_resource_id: StringName, _amount: int) -> void:
		_check_achievements()
		inventory_changed.emit())

func _process(delta: float) -> void:
	for generator in generators.values():
		generator.tick(delta, inventory, global_speed)
	_update_event(delta)

func click_bag() -> void:
	bag.click()

func buy_generator(generator_id: StringName) -> bool:
	var generator = generators.get(generator_id)
	if generator == null or not inventory.spend(generator.purchase_cost):
		message_changed.emit("Not enough materials for that machine.", &"warn")
		return false
	generator.owned += 1
	_check_achievements()
	generator.changed.emit()
	message_changed.emit("%s purchased." % generator.display_name, &"good")
	return true

func run_generator(generator_id: StringName) -> void:
	var generator = generators.get(generator_id)
	if generator != null and not generator.start(inventory):
		message_changed.emit("%s needs %s to run." % [generator.display_name, recipe_text(generator.recipe)], &"warn")

func collect_generator_output(generator_id: StringName) -> void:
	var generator = generators.get(generator_id)
	if generator == null or generator.pending_output.is_empty():
		return
	var parts: Array[String] = []
	for resource_id in generator.pending_output:
		parts.append("%d %s" % [generator.pending_output[resource_id], resource_id])
	generator.collect_output(inventory)
	message_changed.emit("Collected %s from the %s." % [", ".join(parts), generator.display_name], &"good")

func buy_generator_upgrade(generator_id: StringName, upgrade: StringName) -> void:
	var generator = generators.get(generator_id)
	if generator == null:
		return
	if upgrade == &"speed" and generator.is_speed_saturated(global_speed):
		return
	if upgrade == &"multiplier" and generator.is_multiplier_maxed():
		return
	if upgrade == &"auto_in" and generator.auto_in_unlocked:
		generator.auto_in = not generator.auto_in
		generator.changed.emit()
		return
	if upgrade == &"auto_out" and generator.auto_out_unlocked:
		generator.auto_out = not generator.auto_out
		generator.changed.emit()
		return
	if not generator.upgrade_data.has(upgrade) or not _spend_money(generator.upgrade_cost(upgrade)):
		return
	match upgrade:
		&"speed": generator.speed_level += 1
		&"multiplier": generator.multiplier_level += 1
		&"auto_in":
			generator.auto_in_unlocked = true
			generator.auto_in = true
		&"auto_out":
			generator.auto_out_unlocked = true
			generator.auto_out = true
	generator.changed.emit()
	message_changed.emit("%s upgraded." % generator.display_name, &"good")

func buy_shop_upgrade(upgrade_id: StringName) -> void:
	if shop_purchases.get(upgrade_id, false):
		return
	var upgrade: Dictionary = shop_data.get(upgrade_id, {})
	if upgrade.is_empty() or not is_shop_upgrade_available(upgrade_id):
		return
	if not _spend_money(int(upgrade["cost"].get(&"money", 0))):
		return
	shop_purchases[upgrade_id] = true
	var effect: Dictionary = upgrade.get("effect", {})
	bag.click_damage += int(effect.get("click_damage", 0))
	bag.gold_chance += float(effect.get("gold_chance", 0.0))
	collector_capacity += int(effect.get("collector_capacity", 0))
	collector_capacity += int(effect.get("collector_capacity_add", 0))
	collector_enabled = collector_enabled or bool(effect.get("collector_enabled", false))
	if effect.has("collector_check_interval"):
		collector_check_interval = float(effect["collector_check_interval"])
	global_speed *= float(effect.get("global_speed_multiplier", 1.0))
	if effect.has("bag_texture"):
		bag_texture_path = String(effect["bag_texture"])
	inventory_changed.emit()
	message_changed.emit("%s purchased." % upgrade["name"], &"good")
	bag_changed.emit()

func is_shop_upgrade_available(upgrade_id: StringName) -> bool:
	var required := StringName(shop_data.get(upgrade_id, {}).get(&"requires", ""))
	return required.is_empty() or shop_purchases.get(required, false)

# Flakes and pellets feed the chain, so they are never sold; plastic keeps a reserve.
func sellable_amounts() -> Dictionary:
	var amounts := {}
	for resource_id in resource_values:
		if resource_id == &"flakes" or resource_id == &"pellets":
			continue
		var reserve := sell_plastic_reserve if resource_id == &"plastic" else 0
		var amount := maxi(inventory.get_amount(resource_id) - reserve, 0)
		if amount > 0:
			amounts[resource_id] = amount
	return amounts

func sell_value(amounts: Dictionary) -> int:
	var total := 0.0
	for resource_id in amounts:
		total += amounts[resource_id] * resource_values[resource_id]
	return floori(total)

func sell_materials() -> void:
	var amounts := sellable_amounts()
	var total := sell_value(amounts)
	if total <= 0:
		message_changed.emit("Nothing to sell yet. Flakes and pellets are kept for the chain.", &"warn")
		return
	for resource_id in amounts:
		inventory.remove(resource_id, amounts[resource_id])
	inventory.add(&"money", total)
	message_changed.emit("Sold materials for $%d." % total, &"gold")

func recipe_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in recipe:
		parts.append("%d %s" % [recipe[resource_id], resource_id])
	return " + ".join(parts)

func _spend_money(cost: int) -> bool:
	if inventory.spend({&"money": cost}):
		return true
	message_changed.emit("Need $%d more." % (cost - inventory.get_amount(&"money")), &"warn")
	return false

func collect_drop(resource_id: StringName) -> void:
	if loose_drops.get(resource_id, 0) <= 0:
		return
	loose_drops[resource_id] -= 1
	inventory.add(resource_id, 1)

func _on_bag_burst(drops: Dictionary) -> void:
	for resource_id in drops:
		loose_drops[resource_id] = loose_drops.get(resource_id, 0) + drops[resource_id]
	drops_spawned.emit(drops)
	bag_changed.emit()
	if drops.has(&"gold"):
		message_changed.emit("Bag burst! Something golden fell out. Grab it before the Box does.", &"gold")
	else:
		message_changed.emit("Bag burst! %d items scattered on the ground." % drops.values().reduce(func(a, b): return a + b, 0), &"good")
	bags_burst += 1
	_check_achievements()

func is_collector_enabled() -> bool:
	return collector_enabled

func get_collector_capacity() -> int:
	return collector_capacity

func _load_data() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open game data: %s" % DATA_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Game data must contain a JSON object.")
		return {}
	return parsed

func _configure_data(data: Dictionary) -> void:
	for resource_id in data.get("resources", {}):
		resource_values[StringName(resource_id)] = float(data["resources"][resource_id].get("sell_value", 0))
	sell_plastic_reserve = int(data.get("sell_plastic_reserve", sell_plastic_reserve))
	for generator_config in data.get("generators", []):
		var configured_generator: Dictionary = generator_config.duplicate(true)
		configured_generator["speed_saturation_threshold"] = data.get("generator_limits", {}).get("speed_saturation_threshold", 0.5)
		configured_generator["max_multiplier_level"] = data.get("generator_limits", {}).get("max_multiplier_level", 4)
		generator_data.append(_string_name_dictionary(configured_generator))
	for upgrade_id in data.get("shop_upgrades", {}):
		var upgrade: Dictionary = data["shop_upgrades"][upgrade_id]
		shop_data[StringName(upgrade_id)] = _string_name_dictionary(upgrade)
	event_initial_timer = float(data.get("event", {}).get("initial_timer", 240.0))
	event_timer = event_initial_timer
	event_duration = float(data.get("event", {}).get("duration", 20.0))
	for resource_id in data.get("event", {}).get("bonus_resources", {}):
		event_bonus_resources[StringName(resource_id)] = int(data["event"]["bonus_resources"][resource_id])
	for resource_id in data.get("starting_inventory", {}):
		starting_inventory[StringName(resource_id)] = int(data["starting_inventory"][resource_id])
	achievement_speed_bonus = float(data.get("achievement_speed_bonus", achievement_speed_bonus))
	bag_texture_path = String(data.get("bag", {}).get("texture", bag_texture_path))

func _string_name_dictionary(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in value:
		var converted = value[key]
		if converted is Dictionary:
			converted = _string_name_dictionary(converted)
		result[StringName(key)] = converted
	return result

func _check_achievements() -> void:
	var checks := {
		&"first_bag": bags_burst >= 1,
		&"first_machine": _owned_generator_count() >= 1,
		&"first_pellets": inventory.get_amount(&"pellets") >= 1,
		&"first_fabric": inventory.get_amount(&"fabric") >= 1,
		&"industrialist": _owned_generator_count() >= 10,
	}
	for achievement_id in checks:
		if checks[achievement_id] and not achievements[achievement_id]:
			achievements[achievement_id] = true
			global_speed *= achievement_speed_bonus
			message_changed.emit("Achievement unlocked: %s (+5%% cycle speed)." % ACHIEVEMENT_INFO[achievement_id][0], &"gold")
			achievement_unlocked.emit(achievement_id)

func _owned_generator_count() -> int:
	var total := 0
	for generator in generators.values():
		total += generator.owned
	return total

func _update_event(delta: float) -> void:
	if event_active:
		event_remaining -= delta
		event_changed.emit(true, event_remaining)
		if event_remaining <= 0.0:
			event_active = false
			event_timer = event_initial_timer
			event_changed.emit(false, 0.0)
			return
	event_timer -= delta
	if event_timer <= 0.0 and not event_active:
		event_active = true
		event_remaining = event_duration
		for resource_id in event_bonus_resources:
			inventory.add(resource_id, event_bonus_resources[resource_id])
		message_changed.emit("Beach Cleanup Haul: bonus materials delivered.", &"good")
