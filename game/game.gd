extends Node

## Single source of truth for Box Exchange: money, inventory, machines, upgrades and the
## simulated market. UI reads state and calls the action methods; it never writes state.

signal changed
signal sold(i: int, q: int, total: float, auto: bool)
signal produced(i: int, q: int)
signal toast(title: String, sub: String, chime: bool)

enum Act { NONE, COLLECTED, STARTED, DENIED }

var save_path := "user://pm-v6-save.json"
const SAVE_EVERY := 10.0
const ECON_STEP := 0.1
const CANDLE_S := 5.0
const BROKER_EVERY := 5.0

var money := 0.0
var inv: Array[int] = [0, 0, 0, 0, 0]
var own: Array[int] = [0, 0, 0, 0, 0]
var mx: Array[Dictionary] = []
var up := {}
var market: Array[Dictionary] = []
var trades: Array[Dictionary] = []
var total_earned := 0.0
# Persisted view prefs.
var sel := 0
var chart := "candles"
var quotes := false
var rtab := "machines"
var buy_mode := "x1"
var reserve := true
var mute := false
# Playtest stats.
var play := 0.0
var ms := {}
var wait_cur := 0.0
var wait_max := 0.0
# Transient.
var new_mk := {}
var saved_at := 0.0
var autosave := true
var last_collected := 0

var _acc := 0.0
var _save_t := 0.0
var _broker_t := 0.0


func _ready() -> void:
	_fresh()
	load_save()


func _fresh() -> void:
	money = 0.0
	inv = [0, 0, 0, 0, 0]
	own = [0, 0, 0, 0, 0]
	mx.clear()
	for i in Defs.GENS.size():
		mx.append({spd = 0, yld = 0, ain = false, aout = false, in_on = true, out_on = true, run = false, t = 0.0, batch = 0, held = 0})
	up = {}
	trades.clear()
	total_earned = 0.0
	sel = 0
	chart = "candles"
	quotes = false
	rtab = "machines"
	buy_mode = "x1"
	reserve = true
	play = 0.0
	ms = {}
	wait_cur = 0.0
	wait_max = 0.0
	new_mk = {}
	_seed_market()


static func now() -> float:
	return Time.get_unix_time_from_system()


func _process(delta: float) -> void:
	var dt := minf(0.1, delta)
	_step_market(now())
	_acc += dt
	var ticked := false
	while _acc >= ECON_STEP:
		_acc -= ECON_STEP
		_econ(ECON_STEP)
		ticked = true
	_save_t += dt
	if autosave and _save_t >= SAVE_EVERY:
		save()
	if ticked:
		changed.emit()


# ---------------------------------------------------------------- queries

func ai(i: int) -> bool: return mx[i].ain and mx[i].in_on
func ao(i: int) -> bool: return mx[i].aout and mx[i].out_on
func cyc(i: int) -> float: return Defs.GENS[i].cyc * pow(0.8, mx[i].spd)
func mul(i: int) -> int: return 1 + mx[i].yld
func unlocked(i: int) -> bool: return i == 0 or own[i] > 0
func visible_tier(i: int) -> bool: return i == 0 or own[i - 1] > 0
func per_press() -> int: return 1 + (1 if up.has("heavy") else 0) + (2 if up.has("heavy2") else 0)
func market_open() -> bool: return ms.has("box1") or total_earned > 0.0 or inv[0] > 0
func modes_on() -> bool: return own.max() >= 5


func mu_cost(i: int, k: String) -> float:
	var b: float = Defs.GENS[i].cost
	match k:
		"spd": return b * 1.5 * pow(1.8, mx[i].spd)
		"yld": return b * 3.0 * pow(2.2, mx[i].yld)
	return b * 2.5


func mu_maxed(i: int, k: String) -> bool:
	return mx[i][k] >= Defs.MU_MAX if k == "spd" or k == "yld" else bool(mx[i][k])


func up_req_met(id: String) -> bool:
	match id:
		"sweep": return own[0] >= 1
		"heavy2": return up.has("heavy")
		"broker": return own[1] >= 1
		"insider": return own[1] >= 5
	return true


func reserve_of(i: int) -> int:
	var r := 0
	for j in Defs.GENS.size():
		r += Defs.GENS[j].inputs.get(i, 0) * own[j] * 2
	return r


func sellable(i: int) -> int:
	return maxi(0, inv[i] - (reserve_of(i) if reserve else 0))


func net_rates() -> Array[float]:
	var r: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	for i in Defs.GENS.size():
		if own[i] == 0:
			continue
		var g: Dictionary = Defs.GENS[i]
		var c := cyc(i)
		r[g.out] += own[i] * mul(i) / c
		for k: int in g.inputs:
			r[k] -= own[i] * g.inputs[k] / c
	return r


func gen_cost(i: int, q: int) -> float:
	var c: float = Defs.GENS[i].cost * pow(1.15, own[i])
	return c * (pow(1.15, q) - 1.0) / 0.15


func max_afford(i: int) -> int:
	var c: float = Defs.GENS[i].cost * pow(1.15, own[i])
	return maxi(0, floori(log(money * 0.15 / c + 1.0) / log(1.15)))


func qty_for(i: int) -> int:
	var m := buy_mode if modes_on() else "x1"
	return 10 if m == "x10" else maxi(1, max_afford(i)) if m == "max" else 1


## The last 48 candles including the forming one.
func window(i: int) -> Array:
	var m := market[i]
	var cs: Array = m.candles.slice(-(Defs.N_CANDLES - 1))
	cs.append(m.cur)
	return cs


func avg_of(i: int) -> float:
	var cs := window(i)
	var s := 0.0
	for c: Dictionary in cs:
		s += c.c
	return s / cs.size()


func change_pct(i: int) -> float:
	var o: float = window(i)[0].o
	return (market[i].p - o) / o * 100.0


func sell_quote(i: int, q: int) -> Dictionary:
	var imp := minf(0.3, q / Defs.BOXES[i].depth) * (0.5 if up.has("insider") else 1.0)
	var avg: float = market[i].p * (1.0 - imp / 2.0)
	return {imp = imp, avg = avg, total = q * avg}


func sell_qty(mode: String, i: int) -> int:
	var a := sellable(i)
	match mode:
		"1": return mini(1, a)
		"10": return mini(10, a)
		"half": return floori(a / 2.0)
	return a


func sell_value() -> float:
	var v := 0.0
	for i in Defs.BOXES.size():
		if unlocked(i):
			v += sellable(i) * market[i].p
	return v


func warehouse_value() -> float:
	var v := 0.0
	for i in Defs.BOXES.size():
		v += inv[i] * market[i].p
	return v


func up_visible(u: Dictionary) -> bool:
	return visible_tier(u.tier)


## Everything purchasable right now (ignoring money): [{name, cost}], cheapest first.
func shop_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for i in Defs.GENS.size():
		if visible_tier(i):
			items.append({name = Defs.GENS[i].name, cost = gen_cost(i, 1)})
	for u: Dictionary in Defs.UPS:
		if not up.has(u.id) and up_visible(u) and up_req_met(u.id):
			items.append({name = u.name, cost = u.cost})
	for i in Defs.GENS.size():
		if own[i] > 0:
			for k in ["spd", "yld", "ain", "aout"]:
				if not mu_maxed(i, k):
					items.append({name = Defs.GENS[i].name, cost = mu_cost(i, k)})
	items.sort_custom(func(a, b): return a.cost < b.cost)
	return items


## Machine card buy + per-machine upgrades affordable right now.
func machine_affordable_count() -> int:
	var n := 0
	for i in Defs.GENS.size():
		if not visible_tier(i):
			continue
		if money >= gen_cost(i, qty_for(i)):
			n += 1
		n += machine_upgrades_affordable(i)
	return n


func machine_upgrades_affordable(i: int) -> int:
	if own[i] == 0:
		return 0
	var n := 0
	for k in ["spd", "yld", "ain", "aout"]:
		if not mu_maxed(i, k) and money >= mu_cost(i, k):
			n += 1
	return n


func upgrade_affordable_count() -> int:
	var n := 0
	for u: Dictionary in Defs.UPS:
		if up_visible(u) and not up.has(u.id) and up_req_met(u.id) and money >= u.cost:
			n += 1
	return n


# ---------------------------------------------------------------- simulation

func _seed_market() -> void:
	market.clear()
	var t := now()
	var start := floorf(t / CANDLE_S) * CANDLE_S - Defs.N_CANDLES * CANDLE_S
	for b: Dictionary in Defs.BOXES:
		var base: float = b.base
		var p := base * randf_range(0.9, 1.1)
		var candles := []
		for j in Defs.N_CANDLES:
			var o := p
			var h := o
			var l := o
			for s in 6:
				p += (base - p) * 0.03 + p * 0.022 * randfn(0.0, 1.0)
				p = maxf(base * 0.3, p)
				h = maxf(h, p)
				l = minf(l, p)
			candles.append({t = start + j * CANDLE_S, o = o, h = h, l = l, c = p, sold = 0})
		market.append({p = p, ph = randf() * TAU, candles = candles,
			cur = {t = start + Defs.N_CANDLES * CANDLE_S, o = p, h = p, l = p, c = p, sold = 0},
			upd = t, next = t + randf_range(0.2, 1.2)})


func _step_market(t: float) -> void:
	for i in market.size():
		var m := market[i]
		var base: float = Defs.BOXES[i].base
		if t >= m.next:
			var dt := minf(2.0, t - m.upd)
			var fair := base * (1.0 + 0.28 * sin(play / (70.0 + i * 23.0) + m.ph))
			var p: float = m.p + (fair - m.p) * minf(1.0, 0.07 * dt) + m.p * 0.02 * randfn(0.0, 1.0) * sqrt(dt)
			p = maxf(base * 0.25, p)
			m.p = p
			m.upd = t
			m.next = t + randf_range(0.25, 1.5)
			m.cur.c = p
			m.cur.h = maxf(m.cur.h, p)
			m.cur.l = minf(m.cur.l, p)
		if t >= m.cur.t + CANDLE_S:
			m.candles.append(m.cur)
			if m.candles.size() > Defs.N_CANDLES:
				m.candles = m.candles.slice(-Defs.N_CANDLES)
			m.cur = {t = maxf(m.cur.t + CANDLE_S, floorf(t / CANDLE_S) * CANDLE_S), o = m.p, h = m.p, l = m.p, c = m.p, sold = 0}


func _econ(dt: float) -> void:
	play += dt
	for i in Defs.GENS.size():
		if own[i] == 0:
			continue
		var x := mx[i]
		var out: int = Defs.GENS[i].out
		if ao(i) and x.held > 0:
			_land(out, x.held)
			x.held = 0
		if not x.run and ai(i) and (ao(i) or x.held == 0):
			_start_gen(i)
		if not x.run:
			continue
		x.t += dt
		if x.t < cyc(i):
			continue
		x.run = false
		x.t = 0.0
		var q: int = x.batch * mul(i)
		if ao(i):
			_land(out, q)
		else:
			x.held += q
	if up.has("broker"):
		_broker_t += dt
		if _broker_t >= BROKER_EVERY:
			_broker_t = 0.0
			for i in Defs.BOXES.size():
				var q := sellable(i)
				if unlocked(i) and q > 0 and market[i].p >= avg_of(i):
					_do_sell(i, q, true)
	var budget := money + sell_value()
	if shop_items().any(func(it): return it.cost <= budget):
		wait_cur = 0.0
	else:
		wait_cur += dt
		wait_max = maxf(wait_max, wait_cur)


func _land(i: int, q: int) -> void:
	inv[i] += q
	produced.emit(i, q)


func _start_gen(i: int) -> bool:
	var g: Dictionary = Defs.GENS[i]
	var b := own[i]
	for k: int in g.inputs:
		b = mini(b, floori(inv[k] / float(g.inputs[k])))
	if b <= 0:
		return false
	for k: int in g.inputs:
		inv[k] -= b * g.inputs[k]
	mx[i].run = true
	mx[i].t = 0.0
	mx[i].batch = b
	return true


func _do_sell(i: int, q: int, auto: bool) -> float:
	var quote := sell_quote(i, q)
	var m := market[i]
	m.p *= 1.0 - quote.imp
	m.upd = now()
	m.cur.c = m.p
	m.cur.l = minf(m.cur.l, m.p)
	m.cur.sold += q
	inv[i] -= q
	money += quote.total
	total_earned += quote.total
	trades.push_front({t = now(), i = i, q = q, avg = quote.avg, total = quote.total, auto = auto})
	trades.resize(mini(trades.size(), 20))
	mark("sell1")
	sold.emit(i, q, quote.total, auto)
	return quote.total


func mark(key: String) -> void:
	if not ms.has(key):
		ms[key] = play


# ---------------------------------------------------------------- actions

## Called by the press stage per slam; returns how many grey boxes to spawn.
func press() -> int:
	mark("press1")
	return per_press()


## Grey boxes picked up from the press floor (by hand, sweeper, or floor overflow).
func collect_grey(n: int, by_hand := false) -> void:
	var first := not ms.has("box1")
	mark("box1")
	inv[0] += n
	produced.emit(0, n)
	if first and by_hand:
		toast.emit("EXCHANGE OPEN", "Grey boxes now trade on the market. Sell them to buy your first Press Arm.", true)
	changed.emit()


func buy_gen(i: int) -> bool:
	var q := qty_for(i)
	var cost := gen_cost(i, q)
	if money < cost or not visible_tier(i):
		return false
	var first := own[i] == 0
	money -= cost
	own[i] += q
	if first:
		mark(Defs.GENS[i].id)
		if i == 0:
			toast.emit("FIRST MACHINE", "Press RUN to start it. Click the card for Auto-In and Auto-Out.", true)
		else:
			var nxt: String = "%s is now visible in Machines." % Defs.GENS[i + 1].name if i + 1 < Defs.GENS.size() else "Every machine is built."
			toast.emit("NEW MARKET · %s" % Defs.BOXES[i].k, "%ses now trade on the exchange. %s" % [Defs.BOXES[i].name, nxt], true)
			sel = i
			new_mk[i] = now()
	save()
	changed.emit()
	return true


func buy_up(id: String) -> bool:
	var u: Dictionary = Defs.UPS.filter(func(x): return x.id == id)[0]
	if up.has(id) or not up_req_met(id) or money < u.cost:
		return false
	money -= u.cost
	up[id] = true
	mark(id)
	toast.emit(u.name.to_upper(), u.desc, false)
	save()
	changed.emit()
	return true


func buy_mu(i: int, k: String) -> bool:
	if mu_maxed(i, k):
		return false
	var cost := mu_cost(i, k)
	if own[i] == 0 or money < cost:
		return false
	money -= cost
	if k == "spd" or k == "yld":
		mx[i][k] += 1
	else:
		mx[i][k] = true
	if k == "ain":
		mark("auto")
	save()
	changed.emit()
	return true


## RUN / COLLECT button on a machine card. For COLLECTED the qty is in `last_collected`.
func gen_act(i: int) -> Act:
	var x := mx[i]
	if x.run or (ai(i) and x.held == 0):
		return Act.NONE
	if x.held > 0:
		last_collected = x.held
		_land(Defs.GENS[i].out, x.held)
		x.held = 0
		changed.emit()
		return Act.COLLECTED
	if own[i] > 0 and _start_gen(i):
		changed.emit()
		return Act.STARTED
	return Act.DENIED


func toggle_auto(i: int, k: String) -> void:
	if not mx[i][k]:
		return
	var f := "in_on" if k == "ain" else "out_on"
	mx[i][f] = not mx[i][f]
	changed.emit()


## Sells from the selected market. Returns the total earned (0 if nothing was sellable).
func sell(mode: String) -> float:
	var q := sell_qty(mode, sel)
	if q <= 0:
		return 0.0
	var total := _do_sell(sel, q, false)
	changed.emit()
	return total


func sell_surplus() -> bool:
	var any := false
	for i in Defs.BOXES.size():
		var q := sellable(i)
		if unlocked(i) and q > 0:
			_do_sell(i, q, false)
			any = true
	changed.emit()
	return any


func select(i: int) -> bool:
	if not unlocked(i):
		return false
	sel = i
	changed.emit()
	return true


## View prefs (chart, quotes, rtab, buy_mode, reserve, mute).
func set_pref(key: String, value: Variant) -> void:
	set(key, value)
	changed.emit()


# ---------------------------------------------------------------- persistence

func save() -> void:
	_save_t = 0.0
	if not autosave:
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({v = 1, money = money, inv = inv, own = own, up = up, trades = trades,
		mute = mute, buy_mode = buy_mode, reserve = reserve, play = play, ms = ms, wait_max = wait_max,
		total_earned = total_earned, sel = sel, chart = chart, mx = mx, rtab = rtab}))
	saved_at = now()


func load_save() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not d is Dictionary or d.get("v") != 1.0:
		return
	money = d.get("money", 0.0)
	for i in 5:
		inv[i] = int(d.inv[i])
		own[i] = int(d.own[i])
		for key: String in mx[i]:
			if d.mx[i].has(key):
				mx[i][key] = type_convert(d.mx[i][key], typeof(mx[i][key]))
	up = d.get("up", {})
	trades.assign(d.get("trades", []).map(func(t): t.i = int(t.i); t.q = int(t.q); return t))
	mute = d.get("mute", false)
	buy_mode = d.get("buy_mode", "x1")
	reserve = d.get("reserve", true)
	play = d.get("play", 0.0)
	ms = d.get("ms", {})
	wait_max = d.get("wait_max", 0.0)
	total_earned = d.get("total_earned", 0.0)
	sel = int(d.get("sel", 0))
	chart = d.get("chart", "candles")
	rtab = d.get("rtab", "machines")
	saved_at = now()


func reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var keep_mute := mute
	_fresh()
	mute = keep_mute
	changed.emit()
