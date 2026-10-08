extends Control

signal upgrades_requested(generator_id: StringName)

const MACHINE_ROW := preload("res://ui/machine_row.tscn")

var game: RecyclerGame
var _rows := {}

## One row per generator, so new machines in game_data.json just become new rows.
func bind(new_game: RecyclerGame) -> void:
	game = new_game
	var ids: Array = game.generators.keys()
	for index in ids.size():
		var id: StringName = ids[index]
		var generator := game.generators[id] as GeneratorModel
		var row := MACHINE_ROW.instantiate()
		%List.add_child(row)
		var feeds := ""
		if index < ids.size() - 1:
			var next := game.generators[ids[index + 1]] as GeneratorModel
			feeds = "%s FEED %s" % [String(generator.output.keys()[0]).to_upper(), next.display_name.to_upper()]
		row.setup(generator.display_name, UiConst.MACHINE_SPRITES.get(id, "machine sprite"), feeds)
		row.action_pressed.connect(_on_machine_action.bind(id))
		row.upgrades_pressed.connect(upgrades_requested.emit.bind(id))
		_rows[id] = row

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	if not visible:
		return
	var running := 0
	var done := 0
	for id: StringName in _rows:
		var generator := game.generators[id] as GeneratorModel
		running += int(generator.running)
		done += int(not generator.pending_output.is_empty())
		_rows[id].refresh(generator, game)
	%Kicker.text = "PRODUCTION · %d MACHINES · %d RUNNING · %d DONE" % [_rows.size(), running, done]

func _on_machine_action(id: StringName) -> void:
	var generator := game.generators[id] as GeneratorModel
	if generator.owned <= 0:
		game.buy_generator(id)
	elif not generator.pending_output.is_empty():
		game.collect_generator_output(id)
	elif not generator.running:
		game.run_generator(id)
	refresh()

func _on_collect_all_pressed() -> void:
	for id: StringName in _rows:
		game.collect_generator_output(id)
	refresh()

func _on_close_pressed() -> void:
	visible = false

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		visible = false
