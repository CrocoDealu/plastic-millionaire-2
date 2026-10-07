class_name ResourceInventory
extends RefCounted

signal changed(resource_id: StringName, amount: int)

var _amounts: Dictionary[StringName, int] = {}

func get_amount(resource_id: StringName) -> int:
	return _amounts.get(resource_id, 0)

func add(resource_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_amounts[resource_id] = get_amount(resource_id) + amount
	changed.emit(resource_id, _amounts[resource_id])

func remove(resource_id: StringName, amount: int) -> bool:
	if amount <= 0 or get_amount(resource_id) < amount:
		return false
	_amounts[resource_id] -= amount
	changed.emit(resource_id, _amounts[resource_id])
	return true

func can_afford(cost: Dictionary) -> bool:
	for resource_id in cost:
		if get_amount(StringName(resource_id)) < int(cost[resource_id]):
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for resource_id in cost:
		remove(StringName(resource_id), int(cost[resource_id]))
	return true

func snapshot() -> Dictionary:
	return _amounts.duplicate()
