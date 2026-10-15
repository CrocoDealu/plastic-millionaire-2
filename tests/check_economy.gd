extends SceneTree

## Headless economy self-check: godot --headless -s res://tests/check_economy.gd

func _initialize() -> void:
	var g: Node = load("res://game/game.gd").new()
	g.save_path = "user://check_economy.json"
	root.add_child(g)  # runs _ready -> fresh state (no save at this path)
	g.reset()

	assert(is_equal_approx(g.gen_cost(0, 1), 12.0 * 1.15))  # the free arm counts toward the price
	assert(is_equal_approx(g.gen_cost(0, 10), 12.0 * 1.15 * (pow(1.15, 10) - 1.0) / 0.15))
	# Fresh run: one free arm; the press always slams and makes grey from nothing.
	assert(g.own[0] == 1 and not g.market_open())
	assert(g.press() == [[0, 1]] and g.ms.has("press1"))
	g.collect(0, 1)
	assert(g.market_open() and not g.unlocked(1))
	# Heavy + Hydraulic: 4 drops per slam.
	g.sk["heavy"] = 2
	assert(g.press().size() == 4)
	# Every unlocked colour drops; older ones are bundled x10 per tier behind the newest, up to
	# the Press Die's reach.
	g.own[2] = 1
	g.mark("got1")
	assert(g.top_colour() == 2 and g.bundle(0) == 1)
	g.sk["die"] = 1
	assert(g.bundle(0) == 10 and g.bundle(1) == 10 and g.bundle(2) == 1)
	g.sk["die"] = 2
	assert(g.bundle(0) == 100 and g.bundle(1) == 10 and g.bundle(2) == 1)
	var seen := {}
	for k in 300: seen[g.press_pick()] = true
	assert(seen.size() == 3 and not seen.has(3))
	# Combo: slams inside the window chain; press upgrades boost machines only while it lives.
	g.combo = 0
	for k in 10: g.press()
	assert(g.combo == 10 and g.combo_live() == 10 and is_equal_approx(g.press_boost(), 1.0))
	g.sk["overdrive"] = 1
	assert(is_equal_approx(g.press_boost(), 1.2))
	g.combo = 30
	assert(is_equal_approx(g.press_boost(), 1.4))
	g.sk["overtime"] = 1
	g.sk["overdrive"] = 2
	assert(is_equal_approx(g.press_boost(), 3.2))
	g.combo = 50
	g.sk["overtime"] = 2
	assert(is_equal_approx(g.press_boost(), 6.0))  # Double Shift x3 at 40+
	g._last_slam -= 1.0  # combo broken
	assert(g.combo_live() == 0 and is_equal_approx(g.press_boost(), 1.0))
	g.press()
	assert(g.combo == 1)
	# Shift Bell widens the combo window.
	assert(is_equal_approx(g.combo_window(), Defs.COMBO_WINDOW))
	g.sk["bell"] = 1
	g._last_slam = g.now() - 0.8
	assert(g.combo_live() == 1 and is_equal_approx(g.combo_window(), 0.9))
	g.own[2] = 0
	g.ms.erase("got1")
	g.sk = {"press": 1}
	g.inv.assign([1, 0, 0, 0, 0])

	# Asks: boxes leave the warehouse onto the book and fill whole at exactly their price once
	# the market reaches it; the price then drops by min(0.3, q/depth).
	g.inv[0] = 300
	g.set_ask(g.market[0].p * 3.0)  # any price, way above the market
	var o: Dictionary = g.place_ask("all")
	assert(g.inv[0] == 0 and g.orders.size() == 1 and g.on_book(0) == 300 and g.sell_qty("1", 0) == 0)
	assert(is_equal_approx(o.px, snappedf(g.market[0].p * 3.0, 0.01)))
	g._fill_orders()
	assert(g.orders.size() == 1 and g.trades.is_empty())  # not reached yet
	g.cancel_ask(o.id)
	assert(g.inv[0] == 300 and g.orders.is_empty())
	o = g.place_ask("all")
	g.market[0].p = o.px
	g._fill_orders()
	assert(g.orders.is_empty() and is_equal_approx(g.market[0].p, o.px * 0.7))
	assert(is_equal_approx(g.money, 300 * o.px) and g.trades[0].kind == "ask")
	g.set_ask(0.12)
	g.ask_step(1)
	assert(is_equal_approx(g.ask_price(0), 0.13))
	g.set_ask(0.0)
	assert(g.ask_price(0) == snappedf(g.market[0].p, 0.01))  # cleared: follows the last price again
	# Book holds at most MAX_ORDERS asks.
	g.inv[0] = 100
	for k in Defs.MAX_ORDERS: g.place_ask("1")
	assert(g.orders.size() == Defs.MAX_ORDERS and g.place_ask("1").is_empty())
	for x in g.orders.duplicate(): g.cancel_ask(x.id)
	assert(g.inv[0] == 100)
	# Quick sell: everything sellable now, at half the market fill.
	var m0: float = g.money
	var full: float = g.sell_quote(0, 100).total
	assert(g.sell_surplus() and g.inv[0] == 0)
	assert(is_equal_approx(g.money - m0, full * Defs.QUICK_SELL) and g.trades[0].kind == "quick")
	g.money = 0.0

	# First sale: Accounting email, junior title, and the GRY event scheduled 30-90s out.
	assert(g.title() == Defs.TITLES.sell1)
	var at: float = g.ev.sell1 - g.ms.sell1
	assert(at >= 30.0 and at <= 90.0)
	var play0: float = g.play
	g.play = g.ev.sell1 + 60.0
	assert(is_equal_approx(g.ev_mul(0), 0.6) and is_equal_approx(g.ev_mul(1), 1.0))
	g.play = g.ev.sell1 + 1000.0
	assert(is_equal_approx(g.ev_mul(0), 1.0))
	g.play = play0

	# Manual machine: RUN consumes nothing for the arm, output is held until COLLECT.
	g.money = 1000.0
	assert(g.buy_gen(0) and g.own[0] == 2)
	assert(g.gen_act(0) == g.Act.STARTED)
	for k in 21: g._econ(0.1)
	assert(g.mx[0].held == 2 and g.inv[0] == 0)
	assert(g.gen_act(0) == g.Act.COLLECTED and g.inv[0] == 2)

	# Red Stacker consumes 3 GRY per batch; reserve keeps 2 cycles of input.
	assert(g.buy_gen(1))
	g.inv[0] = 7
	assert(g.reserve_of(0) == 6 and g.sellable(0) == 1)
	assert(g.gen_act(1) == g.Act.STARTED and g.inv[0] == 4)

	# Tree: Output Chute needs its parent and money; Chute + Self-Start run the arm unattended.
	g.money = 1000.0
	assert(not g.buy_sk("arm_in") and not g.node_info("arm_in").ok)  # parent arm_out missing
	# Only owned nodes and the ones one step past them are revealed.
	assert(g.node_info("press").shown and g.node_info("arm_out").shown and not g.node_info("arm_in").shown)
	assert(not g.node_info("die").shown and not g.node_info("overdrive").shown)
	assert(g.buy_sk("arm_out") and g.buy_sk("arm_in") and g.mx[0].aout and g.mx[0].ain and g.ms.has("auto"))
	assert(not g.buy_sk("arm_in"))  # one stage only
	assert(g.node_info("overdrive").shown and not g.node_info("overdrive").ok)  # one parent of two
	assert(g.node_info("vat_out").g_ok and not g.node_info("fuse_out").g_ok)  # gate: own 1 of the tier
	assert(g.node_info("fuse_out").hidden and not g.node_info("kiln_out").hidden)
	# Staged node gates: Industrial Press needs a Laminator.
	g.sk["heavy"] = 2
	assert(not g.node_info("heavy").ok and g.node_info("heavy").g_ok == false)
	g.sk.erase("heavy")
	# Bulk Procurement lowers the arm's price growth.
	var c0: float = g.gen_cost(0, 1)
	g.sk["arm_disc"] = 1
	assert(is_equal_approx(g.gen_cost(0, 1), 12.0 * pow(1.13, g.own[0])) and g.gen_cost(0, 1) < c0)
	g.sk.erase("arm_disc")
	var before: int = g.inv[0]
	for k in 41: g._econ(0.1)
	assert(g.inv[0] >= before + 2)
	g.toggle_auto(0, "ain")
	assert(not g.ai(0))

	# A batch finishing mid-combo gets the boost; fractions carry to the next batch.
	g.sk["overdrive"] = 1
	g.combo = 5
	g._last_slam = g.now()
	g.toggle_auto(0, "ain")
	var b0: int = g.inv[0]
	for k in 21: g._econ(0.1)  # one 2s cycle of 2 arms: 2 * 1.1 = 2.2
	assert(g.inv[0] == b0 + 2 and is_equal_approx(g.mx[0].frac, 0.2))
	g.toggle_auto(0, "ain")
	g.sk.erase("overdrive")
	g.combo = 0

	# Speed / Yield are tree stages; stages past MU_MAX need Rated Capacity.
	g.money = 100000.0
	assert(g.buy_sk("arm_spd") and is_equal_approx(g.cyc(0), 1.6))
	assert(g.buy_sk("arm_yld") and g.mul(0) == 2)
	g.sk["arm_spd"] = 5
	assert(not g.node_info("arm_spd").g_ok and not g.buy_sk("arm_spd"))
	g.sk["arm_cap"] = 1
	assert(g.buy_sk("arm_spd") and g.sk_own("arm_spd") == 6 and not g.node_info("arm_spd").g_ok)
	assert(is_equal_approx(Defs.SKM.arm_spd.st[1].c, 12.0 * 1.5 * 1.8))
	g.sk.erase("arm_cap")
	g.sk["arm_spd"] = 1
	g.money = 1000.0

	# Save / load round trip.
	g.quotes = true
	g.sel = 0  # buying the first Stacker selected RED
	g.inv[0] = 50  # above the machine reserve
	g.place_ask("1")
	g.set_ask(7.5)
	g.save()
	var m: float = g.money
	g._fresh()
	g.load_save()
	assert(is_equal_approx(g.money, m) and g.own[1] == 1 and g.mul(0) == 2 and g.mx[0].in_on == false and g.quotes)
	assert(g.orders.size() == 1 and g.orders[0].q == 1 and is_equal_approx(g.ask_px[0], 7.5))
	assert(g.sk_own("arm_in") == 1 and g.sk_own("press") == 1)
	g.cancel_ask(g.orders[0].id)
	g.set_ask(0.0)

	# Pre-tree save: flat upgrades and bought auto toggles become tree stages.
	var tree_sk: Dictionary = g.sk.duplicate()
	g.save()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.save_path))
	d.erase("sk")
	d["up"] = {heavy = true, heavy2 = true, overdrive = true, sweep = true}
	d.mx[1].aout = true
	d.mx[2].yld = 3  # machine-modal level from before the tree
	FileAccess.open(g.save_path, FileAccess.WRITE).store_string(JSON.stringify(d))
	g._fresh()
	g.load_save()
	var want := {"press": 1, "heavy": 2, "sweep": 1, "overdrive": 1, "arm_out": 1, "arm_in": 1, "vat_out": 1, "kiln_yld": 3}
	assert(g.sk.size() == want.size() and want.keys().all(func(k): return g.sk.get(k) == want[k]))
	g.sk = tree_sk
	g.mx[1].aout = false
	g.save()  # g reloads this file when it joins the tree below

	# Ending: once loaded, the Forge's ??? slam takes 3 VIO + 3 TEA (no box), runs the sequence,
	# then the press goes back to dispensing.
	await process_frame  # g joins the tree (and gets timers) only once _initialize yields
	var heard := []
	var mail := []
	var ended := [false]
	g.news.connect(func(t): heard.append(t))
	g.toast.connect(func(t, _s, _c): mail.append(t))
	g.ended.connect(func(): ended[0] = true)
	g.own[4] = 1
	g.mark("forge")
	assert(mail.has("Unknown sender") and g.title() == Defs.TITLES.forge)
	g.inv.assign([0, 0, 0, 2, 7])
	assert(g.mystery_shown() and not g.can_open())
	g.toggle_arm()
	assert(not g.armed)  # can't load without 3 VIO + 3 TEA
	g.inv.assign([0, 0, 0, 7, 7])
	assert(g.press().size() == 1 and g.inv[3] == 7)  # not loaded: a normal slam
	g.toggle_arm()
	assert(g.armed and g.press() == [] and g.inv[3] == 4 and g.inv[4] == 4 and g.ms.has("opened"))
	assert(not g.mystery_shown() and not g.armed and g.opening and g.title() == Defs.TITLES.forge)
	var p_tea: float = g.market[3].p
	var p_vio: float = g.market[4].p
	var total_s := 0.5
	for b: float in Defs.ENDING_BEATS: total_s += b
	await create_timer(total_s).timeout
	assert(ended[0] and g.ms.has("end") and g.ms.has("ev_opened"))
	assert(heard == [Defs.ENDING.breaking, Defs.ENDING.removed, Defs.EVENTS.opened.head])
	assert(mail.has("HR") and g.title() == "Pending")
	assert(g.market[3].p < p_tea * 0.1 and g.market[4].p < p_vio * 0.1)
	for i in 5: assert(g.ev_mul(i) < 0.05)  # every market near zero
	assert(g.inbox()[0] == "opened" and g.inbox().has("forge"))  # newest first
	assert(g.stage() == "after" and g.news_line() == "Contents: still classified.")
	assert(g.press().size() == 1)  # back to dispensing
	# The Forge event doubles your VIO sales' impact while it lasts.
	g.ev["forge"] = g.play
	assert(g.impact_mul(4) == 2.0 and g.impact_mul(3) == 1.0)
	# Opened, fired events and sent emails survive save / load.
	g.save()
	g._fresh()
	g.load_save()
	assert(g.ms.has("opened") and g.ms.has("end") and g.ms.has("ev_opened") and g.ev.has("opened"))
	assert(g.ms.has("sell1") and g.ev.has("sell1") and not g.mystery_shown() and g.title() == "Pending")

	g.reset()
	print("economy OK")
	quit()
