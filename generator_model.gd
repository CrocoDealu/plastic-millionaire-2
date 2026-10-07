class_name GeneratorModel
extends RefCounted

const INVENTORY_SCRIPT := preload("res://resource_inventory.gd")

signal changed
signal output_ready(amounts: Dictionary)

var id: StringName
var display_name: String
var purchase_cost: Dictionary
var recipe: Dictionary
var output: Dictionary
var base_cycle_time: float
var owned := 0
var speed_level := 0
var multiplier_level := 0
var auto_in_unlocked := false
var auto_out_unlocked := false
var auto_in := false
var auto_out := false
var cycle_progress := 0.0
var running := false
var pending_output: Dictionary = {}

func configure(data: Dictionary) -> void:
	id = StringName(data["id"])
	display_name = data["name"]
	purchase_cost = data["cost"].duplicate()
	recipe = data["recipe"].duplicate()
	output = data["output"].duplicate()
	base_cycle_time = float(data["cycle_time"])

func cycle_time(global_speed: float) -> float:
	return base_cycle_time * pow(0.8, speed_level) / maxf(global_speed, 0.01)

func output_multiplier() -> int:
	return 1 << multiplier_level

func can_start(inventory: RefCounted) -> bool:
	return owned > 0 and not running and inventory.can_afford(recipe)

func start(inventory: RefCounted) -> bool:
	if not can_start(inventory):
		return false
	if not inventory.spend(recipe):
		return false
	running = true
	cycle_progress = 0.0
	changed.emit()
	return true

func tick(delta: float, inventory: RefCounted, global_speed: float) -> void:
	if owned <= 0:
		return
	if not running and auto_in:
		start(inventory)
	if not running:
		return
	cycle_progress += delta / cycle_time(global_speed)
	if cycle_progress < 1.0:
		changed.emit()
		return
	cycle_progress = 0.0
	running = false
	var completed_output := {}
	for resource_id in output:
		completed_output[StringName(resource_id)] = int(output[resource_id]) * owned * output_multiplier()
	if auto_out:
		for resource_id in completed_output:
			inventory.add(resource_id, completed_output[resource_id])
	else:
		for resource_id in completed_output:
			pending_output[resource_id] = pending_output.get(resource_id, 0) + completed_output[resource_id]
	output_ready.emit(completed_output)
	changed.emit()

func collect_output(inventory: RefCounted) -> void:
	for resource_id in pending_output:
		inventory.add(resource_id, pending_output[resource_id])
	pending_output.clear()
	changed.emit()
