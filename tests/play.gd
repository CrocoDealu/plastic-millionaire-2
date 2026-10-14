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
	game.mark("got1")  # RED unlocked: the press drops grey bundles and red
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
	print("collected GRY/RED: ", game.inv[0], "/", game.inv[1])
	assert(game.inv[0] + game.inv[1] > 0)
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	# Ask all via the button: the boxes go on the book.
	game.select(0 if game.inv[0] > 0 else 1)
	for k in 3: await process_frame  # ASK buttons stretch: ALL moves once 10 / 50% hide
	var sell_all: Button = main.find_child("SellAll", true, false)
	await _click(sell_all.get_global_rect().get_center())
	print("open asks: ", game.orders.size(), " fills: ", game.trades.size())
	assert(game.orders.size() + game.trades.size() == 1)  # an ask at 0% may fill at once
	assert(main.get_node("Layout/Header").size.y == 64.0)
	# Buy an arm, hover its BUY button for the tooltip.
	game.money = 100.0
	var buy: Button = main.find_child("Machine0", true, false).get_node("%Buy")
	await _click(buy.get_global_rect().get_center())
	assert(game.own[0] == 2)
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
	# SKILL TREE tab opens the tree; clicking a node buys it; the close button shuts it.
	game.money = 1000.0
	await _click(main.find_child("TreeTab", true, false).get_global_rect().get_center())
	var canvas: Control = main.find_child("Canvas", true, false)
	assert(main.get_node("%SkillTree").visible)
	await _click(canvas.get_global_transform() * canvas.pos(Defs.SKM.sweep))
	assert(game.sk_own("sweep") == 1 and canvas.focus == "sweep")
	await _click(main.find_child("SkillTree", true, false).get_node("%Close").get_global_rect().get_center())
	assert(not main.get_node("%Modals").visible)
	# Sweeper: 12 resting boxes, one pass pushes 8 off and credits them only off the far edge.
	panel._drops.clear()
	for k in 12:
		panel._drops.append({x = 20.0 + k * 18.0, y = 300.0, s = 18.0, vx = 0.0, vy = 0.0, rot = 0.0, vr = 0.0, rest = true, c = 0, m = 1})
	var g0: int = game.inv[0]
	await create_timer(1.8).timeout
	assert(panel._sweeping and game.inv[0] == g0)
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].replace(".png", "_sweep.png"))
	await create_timer(2.2).timeout
	print("sweep: floor ", panel._drops.size(), " GRY +", game.inv[0] - g0)
	assert(panel._drops.size() == 4 and game.inv[0] == g0 + 8 and panel._sweep_dir < 0.0)
	print("play OK")
	quit()
