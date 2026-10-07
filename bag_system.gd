class_name BagSystem
extends RefCounted

signal changed
signal burst(drops: Dictionary)

const CLICKS_TO_BURST := 10

var rng := RandomNumberGenerator.new()
var clicks := 0
var click_damage := 1
var gold_chance := 0.05

func _init() -> void:
	rng.randomize()

func click() -> void:
	clicks = mini(clicks + click_damage, CLICKS_TO_BURST)
	changed.emit()
	if clicks < CLICKS_TO_BURST:
		return
	clicks = 0
	var drops := {
		&"plastic": rng.randi_range(4, 7),
		&"junk": rng.randi_range(1, 3),
	}
	if rng.randf() < gold_chance:
		drops[&"gold"] = 1
	burst.emit(drops)
	changed.emit()

func progress() -> float:
	return float(clicks) / float(CLICKS_TO_BURST)
