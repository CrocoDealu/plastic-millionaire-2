extends SceneTree

## Drives main.tscn with synthetic mouse input: presses, collects, sells, buys an arm.
## godot -s res://tests/play.gd -- out.png

func _click(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = root.get_final_transform() * p  # canvas -> window px (stretch scale)
		e.global_position = e.position
		root.push_input(e)
		await process_frame


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.save_path = "user://play.json"
	game.autosave = false
	game.reset()
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var stage: Control = main.find_child("Stage", true, false)
	var press_at := stage.get_global_rect().position + Vector2(128, 120)
	for k in 8:
		await _click(press_at)
		await create_timer(0.12).timeout
	assert(game.ms.has("press1"))
	await create_timer(1.5).timeout
	var panel: Node = main.find_child("PressPanel", true, false)
	var n0: int = panel._drops.size()
	print("drops on floor: ", n0, " resting: ", panel._drops.filter(func(d): return d.rest).size())
	for k in 6:
		if panel._drops.is_empty(): break
		var d: Dictionary = panel._drops[-1]
		await _click(stage.get_global_rect().position + Vector2(d.x + d.s / 2.0, d.y + d.s / 2.0))
	print("GRY after collect: ", game.inv[0], " market open: ", game.market_open())
	assert(game.inv[0] > 0 and game.market_open())
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	# Sell all via the button, then buy an arm if affordable.
	var sell_all: Button = main.find_child("SellAll", true, false)
	await _click(sell_all.get_global_rect().get_center())
	print("money after sell: ", game.money, " trades: ", game.trades.size())
	assert(game.trades.size() == 1)
	assert(main.get_node("Layout/Header").size.y == 64.0)
	# Buy an arm, hover its BUY button for the tooltip.
	game.money = 100.0
	var buy: Button = main.find_child("Machine0", true, false).get_node("%Buy")
	await _click(buy.get_global_rect().get_center())
	assert(game.own[0] == 1)
	var m := InputEventMouseMotion.new()
	m.position = root.get_final_transform() * (buy.get_global_rect().get_center() + Vector2(4, 0))
	m.global_position = m.position
	root.push_input(m)
	await create_timer(0.5).timeout
	assert(root.get_node("Fx")._tip.visible)
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].replace(".png", "_tip.png"))
	# Card body click opens the modal; backdrop click closes it.
	var card: Control = main.find_child("Machine0", true, false)
	await _click(card.get_global_rect().position + Vector2(150, 12))
	assert(main.get_node("%Modals").visible)
	await _click(Vector2(20, 400))
	assert(not main.get_node("%Modals").visible)
	print("play OK")
	quit()
