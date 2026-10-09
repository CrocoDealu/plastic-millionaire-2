extends SceneTree

## Renders main.tscn and saves a PNG: godot -s res://tests/shot.gd -- out.png [seconds] [setup]
## setup: "fresh" (default), "mid" (some machines + market open), "modal", "settings", "quotes", "upgrades".

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shot.png"
	var secs := float(args[1]) if args.size() > 1 else 1.5
	var setup := args[2] if args.size() > 2 else "fresh"
	await process_frame  # let autoloads run _ready before touching state
	var game: Node = root.get_node("Game")
	game.save_path = "user://shot.json"
	game.autosave = false
	game.reset()
	if setup != "fresh":
		game.collect_grey(40, false)
		game.money = 5000.0
		for i in 3: game.buy_gen(i)
		for k in 4: game.buy_gen(0)
		game.buy_mu(0, "ain"); game.buy_mu(0, "aout")
		game.buy_up("heavy"); game.buy_up("sweep")
		game.inv.assign([140, 23, 4, 0, 0])
		game.sel = 1
		game.money = 812.4
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	if setup == "modal": main.open_machine(1)
	if setup == "settings": main.open_settings()
	if setup == "quotes": game.set_pref("quotes", true)
	if setup == "upgrades": game.set_pref("rtab", "upgrades"); game.set_pref("chart", "line")
	await create_timer(secs).timeout
	await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
