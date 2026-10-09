extends SceneTree

## Headless economy self-check: godot --headless -s res://tests/check_economy.gd

func _initialize() -> void:
	var g: Node = load("res://game/game.gd").new()
	g.save_path = "user://check_economy.json"
	root.add_child(g)  # runs _ready -> fresh state (no save at this path)
	g.reset()

	assert(is_equal_approx(g.gen_cost(0, 1), 12.0))
	assert(is_equal_approx(g.gen_cost(0, 10), 12.0 * (pow(1.15, 10) - 1.0) / 0.15))
	assert(not g.market_open())
	assert(g.press() == 1)
	g.collect_grey(1, true)
	assert(g.market_open() and g.inv[0] == 1)

	# Sale impact: price drops by min(0.3, q/depth), avg fill is halfway.
	g.inv[0] = 300
	var p0: float = g.market[0].p
	var total: float = g.sell("all")
	assert(is_equal_approx(g.market[0].p, p0 * 0.7))
	assert(is_equal_approx(total, 300 * p0 * 0.85))
	assert(g.inv[0] == 0 and g.trades.size() == 1)

	# Manual machine: RUN consumes nothing for the arm, output is held until COLLECT.
	g.money = 1000.0
	assert(g.buy_gen(0) and g.own[0] == 1)
	assert(g.gen_act(0) == g.Act.STARTED)
	for k in 21: g._econ(0.1)
	assert(g.mx[0].held == 1 and g.inv[0] == 0)
	assert(g.gen_act(0) == g.Act.COLLECTED and g.inv[0] == 1)

	# Vat consumes 3 GRY per batch; reserve keeps 2 cycles of input.
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

	# Speed / yield levels.
	assert(g.buy_mu(0, "spd") and is_equal_approx(g.cyc(0), 1.6))
	assert(g.buy_mu(0, "yld") and g.mul(0) == 2)

	# Save / load round trip.
	g.save()
	var m: float = g.money
	g._fresh()
	g.load_save()
	assert(is_equal_approx(g.money, m) and g.own[1] == 1 and g.mx[0].yld == 1 and g.mx[0].in_on == false)

	g.reset()
	print("economy OK")
	quit()
