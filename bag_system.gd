class_name BagSystem
extends RefCounted

signal changed
signal burst(drops: Dictionary)

var rng := RandomNumberGenerator.new()
var clicks_to_burst := 10
var clicks := 0
var click_damage := 1
var gold_chance := 0.05
var plastic_min := 4
var plastic_max := 7
var junk_min := 1
var junk_max := 3
var alpha_stage_1_remaining := 7
var alpha_stage_1 := 1.0
var alpha_stage_2_remaining := 3
var alpha_stage_2 := 0.65
var alpha_stage_3 := 0.3

func _init() -> void:
	rng.randomize()

func configure(data: Dictionary) -> void:
	clicks_to_burst = int(data.get("clicks_to_burst", clicks_to_burst))
	click_damage = int(data.get("click_damage", click_damage))
	gold_chance = float(data.get("gold_chance", gold_chance))
	plastic_min = int(data.get("plastic_min", plastic_min))
	plastic_max = int(data.get("plastic_max", plastic_max))
	junk_min = int(data.get("junk_min", junk_min))
	junk_max = int(data.get("junk_max", junk_max))
	alpha_stage_1_remaining = int(data.get("alpha_stage_1_remaining", alpha_stage_1_remaining))
	alpha_stage_1 = float(data.get("alpha_stage_1", alpha_stage_1))
	alpha_stage_2_remaining = int(data.get("alpha_stage_2_remaining", alpha_stage_2_remaining))
	alpha_stage_2 = float(data.get("alpha_stage_2", alpha_stage_2))
	alpha_stage_3 = float(data.get("alpha_stage_3", alpha_stage_3))

func click() -> void:
	clicks = mini(clicks + click_damage, clicks_to_burst)
	changed.emit()
	if clicks < clicks_to_burst:
		return
	clicks = 0
	var drops := {
		&"plastic": rng.randi_range(plastic_min, plastic_max),
		&"junk": rng.randi_range(junk_min, junk_max),
	}
	if rng.randf() < gold_chance:
		drops[&"gold"] = 1
	burst.emit(drops)
	changed.emit()

func progress() -> float:
	return float(clicks) / float(clicks_to_burst)
