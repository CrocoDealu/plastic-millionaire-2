extends VBoxContainer

signal action_pressed
signal upgrades_pressed

func _ready() -> void:
	%Action.pressed.connect(action_pressed.emit)
	%Upgrades.pressed.connect(upgrades_pressed.emit)

## feeds_text is the connector caption to the next machine; empty hides the connector.
func setup(display_name: String, sprite_text: String, feeds_text: String) -> void:
	%Name.text = display_name.to_upper()
	%Sprite.text = sprite_text
	%Connector.visible = not feeds_text.is_empty()
	%Feeds.text = feeds_text

func refresh(generator: GeneratorModel, game: RecyclerGame) -> void:
	var inventory: ResourceInventory = game.inventory
	var cycle := generator.cycle_time(game.global_speed)
	var done := not generator.pending_output.is_empty()
	var owned := generator.owned > 0
	var can_run := owned and inventory.can_afford(generator.recipe)

	var status: Array = ["NOT OWNED", &"StatusLocked", UiConst.LOCKED]
	if done:
		status = ["DONE", &"StatusDone", UiConst.ROOT]
	elif generator.running:
		status = ["RUNNING", &"StatusRunning", UiConst.ROOT]
	elif can_run:
		status = ["IDLE", &"StatusIdle", UiConst.TEXT]
	elif owned:
		status = ["NO INPUT", &"StatusNoInput", UiConst.WARN_TEXT]
	%Status.text = status[0]
	%StatusBadge.theme_type_variation = status[1]
	%Status.add_theme_color_override("font_color", status[2])

	var output_id: StringName = generator.output.keys()[0]
	var batch := int(generator.output[output_id]) * maxi(generator.owned, 1) * generator.output_multiplier()
	%Recipe.text = "%s → %d %s" % [game.recipe_text(generator.recipe), batch, output_id]
	%Levels.text = "SPD %d · x%d · OWNED %d" % [generator.speed_level, generator.output_multiplier(), generator.owned]

	var saturated := generator.is_speed_saturated(game.global_speed)
	var progress := 1.0 if done or (generator.running and saturated) else generator.cycle_progress if generator.running else 0.0
	%Fill.set_anchor(SIDE_RIGHT, progress, true)
	var left := cycle * (1.0 - generator.cycle_progress)
	if not owned:
		%Time.text = "Costs %s" % game.recipe_text(generator.purchase_cost)
	elif generator.running:
		%Time.text = "%.1fs left · %.1fs cycle" % [left, cycle]
	elif done:
		%Time.text = "Finished"
	else:
		%Time.text = "%.1fs cycle" % cycle

	_show_automation(%AutoIn, generator.auto_in)
	_show_automation(%AutoOut, generator.auto_out)

	var action: Button = %Action
	if not owned:
		action.text = "BUY MACHINE"
		action.theme_type_variation = &"ActionGreen" if inventory.can_afford(generator.purchase_cost) else &"ActionDark"
	elif done:
		action.text = "COLLECT %s" % UiConst.fmt(generator.pending_output.values().reduce(func(a: int, b: int) -> int: return a + b, 0))
		action.theme_type_variation = &"ActionGold"
	elif generator.running:
		action.text = "%.1fs" % left
		action.theme_type_variation = &"ActionDark"
	elif generator.auto_in:
		action.text = "WAITING FOR INPUT"
		action.theme_type_variation = &"ActionDark"
	else:
		action.text = "RUN"
		action.theme_type_variation = &"ActionGreen" if can_run else &"ActionDark"

	%Row.theme_type_variation = &"RowDone" if done else &"RowRunning" if generator.running else &"RowIdle"
	var flow := UiConst.GREEN if generator.running or generator.auto_out else UiConst.LINE
	%Dash.modulate = flow
	%Feeds.add_theme_color_override("font_color", flow)

func _show_automation(chip: PanelContainer, on: bool) -> void:
	chip.theme_type_variation = &"AutoChipOn" if on else &"AutoChipOff"
	chip.get_child(0).add_theme_color_override("font_color", UiConst.GREEN if on else UiConst.LOCKED)
