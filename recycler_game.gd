class_name RecyclerGame
extends Node

const INVENTORY_SCRIPT := preload("res://resource_inventory.gd")
const BAG_SCRIPT := preload("res://bag_system.gd")
const GENERATOR_SCRIPT := preload("res://generator_model.gd")

signal inventory_changed
signal bag_changed
signal drops_spawned(drops: Dictionary)
signal generator_changed(generator: RefCounted)
signal message_changed(text: String)
signal event_changed(active: bool, seconds_left: float)
signal achievements_changed

const RESOURCE_VALUES := {
	&"plastic": 1,
	&"flakes": 5,
	&"pellets": 15,
	&"fabric": 50,
	&"gold": 100,
}
const GENERATOR_DATA := [
	{"id": "g1_sorter", "name": "Manual Sorting Table", "cost": {&"plastic": 20}, "cycle_time": 3.5, "recipe": {&"plastic": 5}, "output": {&"flakes": 2}},
	{"id": "g2_pelletizer", "name": "Melt Pelletizer", "cost": {&"flakes": 60, &"plastic": 50}, "cycle_time": 6.0, "recipe": {&"flakes": 4, &"plastic": 3}, "output": {&"pellets": 2}},
	{"id": "g3_loom", "name": "Weaving Loom", "cost": {&"pellets": 100, &"plastic": 120}, "cycle_time": 10.0, "recipe": {&"pellets": 5, &"plastic": 6}, "output": {&"fabric": 1}},
]
const SHOP_DATA := {
	&"shop_u_bag_dmg": {"name": "Heavy Duty Cutters", "cost": {&"money": 50}},
	&"shop_u_bag_gold": {"name": "Lucky Seams", "cost": {&"money": 200}},
	&"shop_u_collector_base": {"name": "Basic Collector Box", "cost": {&"money": 150}},
	&"shop_u_collector_speed": {"name": "Box Motor Upgrade", "cost": {&"money": 400}},
}

var inventory = INVENTORY_SCRIPT.new()
var bag = BAG_SCRIPT.new()
var generators: Dictionary[StringName, RefCounted] = {}
var shop_purchases: Dictionary[StringName, bool] = {}
var loose_drops: Dictionary[StringName, int] = {}
var global_speed := 1.0
var event_timer := 240.0
var event_active := false
var event_remaining := 0.0
var bags_burst := 0
var achievements := {
	&"first_bag": false,
	&"first_machine": false,
	&"first_pellets": false,
	&"first_fabric": false,
	&"industrialist": false,
}

func _ready() -> void:
	inventory.add(&"plastic", 1000000)
	inventory.add(&"money", 1000000)
	for data in GENERATOR_DATA:
		var generator := GENERATOR_SCRIPT.new()
		generator.configure(data)
		generator.changed.connect(generator_changed.emit.bind(generator))
		generators[generator.id] = generator
	bag.burst.connect(_on_bag_burst)
	inventory.changed.connect(func(_resource_id: StringName, _amount: int) -> void: inventory_changed.emit())

func _process(delta: float) -> void:
	for generator in generators.values():
		generator.tick(delta, inventory, global_speed)
	_update_event(delta)

func click_bag() -> void:
	bag.click()

func buy_generator(generator_id: StringName) -> bool:
	var generator = generators.get(generator_id)
	if generator == null or not inventory.spend(generator.purchase_cost):
		message_changed.emit("Not enough crafted resources for that machine.")
		return false
	generator.owned += 1
	_check_achievements()
	generator.changed.emit()
	message_changed.emit("%s purchased." % generator.display_name)
	return true

func run_generator(generator_id: StringName) -> void:
	var generator = generators.get(generator_id)
	if generator != null and not generator.start(inventory):
		message_changed.emit("That machine needs its recipe and must be idle.")

func collect_generator_output(generator_id: StringName) -> void:
	var generator = generators.get(generator_id)
	if generator != null:
		generator.collect_output(inventory)

func buy_generator_upgrade(generator_id: StringName, upgrade: StringName) -> void:
	var generator = generators.get(generator_id)
	if generator == null:
		return
	if upgrade == &"auto_in" and generator.auto_in_unlocked:
		generator.auto_in = not generator.auto_in
		generator.changed.emit()
		return
	if upgrade == &"auto_out" and generator.auto_out_unlocked:
		generator.auto_out = not generator.auto_out
		generator.changed.emit()
		return
	var costs := {
		&"speed": 100 + generator.speed_level * 150,
		&"multiplier": 250 + generator.multiplier_level * 350,
		&"auto_in": 500,
		&"auto_out": 500,
	}
	if not inventory.spend({&"money": costs[upgrade]}):
		message_changed.emit("You need more money for that upgrade.")
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

func buy_shop_upgrade(upgrade_id: StringName) -> void:
	if shop_purchases.get(upgrade_id, false):
		return
	var upgrade: Dictionary = SHOP_DATA.get(upgrade_id, {})
	if upgrade.is_empty() or not inventory.spend(upgrade["cost"]):
		message_changed.emit("You need more money for that shop upgrade.")
		return
	shop_purchases[upgrade_id] = true
	match upgrade_id:
		&"shop_u_bag_dmg": bag.click_damage += 1
		&"shop_u_bag_gold": bag.gold_chance += 0.05
		&"shop_u_collector_base": pass
		&"shop_u_collector_speed": global_speed *= 1.5
	message_changed.emit("%s purchased." % upgrade["name"])
	bag_changed.emit()

func sell_resource(resource_id: StringName) -> void:
	var amount := inventory.get_amount(resource_id)
	if amount <= 0 or not RESOURCE_VALUES.has(resource_id):
		return
	inventory.remove(resource_id, amount)
	inventory.add(&"money", amount * RESOURCE_VALUES[resource_id])
	message_changed.emit("Sold %d %s for $%d." % [amount, resource_id, amount * RESOURCE_VALUES[resource_id]])

func collect_loose_drops() -> void:
	for resource_id in loose_drops:
		inventory.add(resource_id, loose_drops[resource_id])
	loose_drops.clear()
	message_changed.emit("Loose drops collected.")

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
	message_changed.emit("Bag burst: %d plastic, %d junk." % [drops.get(&"plastic", 0), drops.get(&"junk", 0)])
	bags_burst += 1
	_check_achievements()

func is_collector_enabled() -> bool:
	return shop_purchases.get(&"shop_u_collector_base", false)

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
			global_speed *= 1.05
			message_changed.emit("Achievement unlocked: %s (+5%% cycle speed)." % String(achievement_id).replace("_", " ").capitalize())
			achievements_changed.emit()

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
			event_timer = 240.0
			event_changed.emit(false, 0.0)
			return
	event_timer -= delta
	if event_timer <= 0.0 and not event_active:
		event_active = true
		event_remaining = 20.0
		for resource_id in [&"plastic", &"flakes", &"pellets"]:
			inventory.add(resource_id, 10)
		message_changed.emit("Beach Cleanup Haul: bonus materials delivered.")
