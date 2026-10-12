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
	g.up["heavy"] = true
	g.up["heavy2"] = true
	assert(g.press().size() == 4)
	# Every unlocked colour drops, older ones bundled x10 per tier behind the newest.
	g.own[2] = 1
	g.mark("got1")
	assert(g.top_colour() == 2 and g.bundle(0) == 100 and g.bundle(1) == 10 and g.bundle(2) == 1)
	var seen := {}
	for k in 300: seen[g.press_pick()] = true
	assert(seen.size() == 3 and not seen.has(3))
	# Combo: slams inside the window chain; press upgrades boost machines only while it lives.
	g.combo = 0
	for k in 10: g.press()
	assert(g.combo == 10 and g.combo_live() == 10 and is_equal_approx(g.press_boost(), 1.0))
	g.up["overdrive"] = true
	assert(is_equal_approx(g.press_boost(), 1.2))
	g.combo = 30
	assert(is_equal_approx(g.press_boost(), 1.4))
	g.up["overtime"] = true
	g.up["overdrive2"] = true
	assert(is_equal_approx(g.press_boost(), 3.2))
	g._last_slam -= 1.0  # combo broken
	assert(g.combo_live() == 0 and is_equal_approx(g.press_boost(), 1.0))
	g.press()
	assert(g.combo == 1)
	g.own[2] = 0
	g.ms.erase("got1")
	g.up.clear()
	g.inv.assign([1, 0, 0, 0, 0])

	# Sale impact: price drops by min(0.3, q/depth), avg fill is halfway.
	g.inv[0] = 300
	var p0: float = g.market[0].p
	var total: float = g.sell("all")
	assert(is_equal_approx(g.market[0].p, p0 * 0.7))
	assert(is_equal_approx(total, 300 * p0 * 0.85))
	assert(g.inv[0] == 0 and g.trades.size() == 1)

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

	# Auto-in + auto-out run unattended.
	assert(g.buy_mu(0, "ain") and g.buy_mu(0, "aout"))
	var before: int = g.inv[0]
	for k in 41: g._econ(0.1)
	assert(g.inv[0] >= before + 2)
	g.toggle_auto(0, "ain")
	assert(not g.ai(0))

	# A batch finishing mid-combo gets the boost; fractions carry to the next batch.
	g.up["overdrive"] = true
	g.combo = 5
	g._last_slam = g.now()
	g.toggle_auto(0, "ain")
	var b0: int = g.inv[0]
	for k in 21: g._econ(0.1)  # one 2s cycle of 2 arms: 2 * 1.1 = 2.2
	assert(g.inv[0] == b0 + 2 and is_equal_approx(g.mx[0].frac, 0.2))
	g.toggle_auto(0, "ain")
	g.up.erase("overdrive")
	g.combo = 0

	# Speed / yield levels.
	assert(g.buy_mu(0, "spd") and is_equal_approx(g.cyc(0), 1.6))
	assert(g.buy_mu(0, "yld") and g.mul(0) == 2)

	# Save / load round trip.
	g.quotes = true
	g.save()
	var m: float = g.money
	g._fresh()
	g.load_save()
	assert(is_equal_approx(g.money, m) and g.own[1] == 1 and g.mx[0].yld == 1 and g.mx[0].in_on == false and g.quotes)

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
