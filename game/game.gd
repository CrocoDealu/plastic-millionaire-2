extends Node

## Single source of truth for Box Exchange: money, inventory, machines, upgrades and the
## simulated market. UI reads state and calls the action methods; it never writes state.

signal changed
signal sold(i: int, q: int, total: float, auto: bool)
signal produced(i: int, q: int)
signal toast(title: String, sub: String, chime: bool)
signal news(text: String)  # priority ticker headline
signal ended  # the box is opened: show the end card
signal finished(gen: int, q: int)  # a machine batch finished making `q` boxes

enum Act { NONE, COLLECTED, STARTED, DENIED }

var save_path := "user://pm-v6-save.json"
var _dirty := false
const SAVE_EVERY := 10.0
const ECON_STEP := 0.1

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
var mail_seen := 0  # inbox size when the INBOX tab was last open
var buy_mode := "x1"
var reserve := true
var mute := false
# Playtest stats.
var play := 0.0
var ms := {}
var ev := {}  # market event id -> play time it fires; fired ones are marked "ev_<id>"
var wait_cur := 0.0
var wait_max := 0.0
# Transient.
var new_mk := {}
var saved_at := 0.0
var autosave := true
var last_collected := 0
var opening := false  # the ending is running and hasn't reached the HR email yet
var armed := false  # the ??? slot is loaded: the next slam opens the box
var combo := 0
var _last_slam := -10.0
var _ending_on := false
var _news_seen := {}

var _acc := 0.0
var _save_t := 0.0
var _broker_t := 0.0


func _ready() -> void:
	_fresh()
	load_save()


func _fresh() -> void:
	money = 0.0
	inv = [0, 0, 0, 0, 0]
	own.assign(Defs.START_OWN)
	mx.clear()
	for i in Defs.GENS.size():
		mx.append({spd = 0, yld = 0, ain = false, aout = false, in_on = true, out_on = true, run = false, t = 0.0, batch = 0, held = 0, frac = 0.0})
	up = {}
	trades.clear()
	total_earned = 0.0
	sel = 0
	chart = "candles"
	quotes = false
	rtab = "machines"
	mail_seen = 0
	buy_mode = "x1"
	reserve = true
	play = 0.0
	ms = {}
	ev = {}
	opening = false
	armed = false
	combo = 0
	_ending_on = false
	wait_cur = 0.0
	wait_max = 0.0
	new_mk = {}
	_seed_market()


static func now() -> float:
	return Time.get_unix_time_from_system()


func _process(delta: float) -> void:
	var dt := minf(0.1, delta)
	if ms.is_empty():
		mark("start")
	if ms.has("opened") and not ms.has("end") and not _ending_on:
		_ending()  # also resumes one interrupted by a quit
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
		notify_changed()


# ---------------------------------------------------------------- queries

## Newest machine tier owned.
func newest() -> int:
	var t := 0
	for i in own.size():
		if own[i] > 0:
			t = i
	return t


## Ticker pool key in Defs.NEWS.
func stage() -> String:
	return "after" if ms.has("opened") else ["early", "mid", "mid", "late", "late"][newest()]


func title() -> String:
	var t: String = Defs.TITLES.start
	for k: String in Defs.TITLES:
		if ms.has(k) and not (k == "opened" and opening):
			t = Defs.TITLES[k]
	return t


## Next pooled headline: this stage's lines weigh 3x earlier stages', clue lines weigh more each
## stage, and nothing repeats until the pool is used up.
func news_line() -> String:
	if stage() == "after":
		return Defs.NEWS.after[0][0]
	var keys: Array = Defs.NEWS.keys()
	var s := keys.find(stage())
	var pool := []
	var total := 0.0
	for j in s + 1:
		for n: Array in Defs.NEWS[keys[j]]:
			if not _news_seen.has(n[0]):
				var w := (Defs.NEWS_STAGE_WEIGHT if j == s else 1.0) * (1.0 + s if n[1] else 1.0)
				pool.append([n[0], w])
				total += w
	if pool.is_empty():
		_news_seen.clear()
		return news_line()
	var roll := randf() * total
	for n: Array in pool:
		roll -= n[1]
		if roll <= 0.0:
			_news_seen[n[0]] = true
			return n[0]
	_news_seen[pool[-1][0]] = true
	return pool[-1][0]


## Eased fair-price multiplier on box `i` from market events (1.0 when none touch it).
func ev_mul(i: int) -> float:
	var m := 1.0
	for k: String in ev:
		var pts: Array = Defs.EVENTS[k].fx.get(i, [])
		var a: float = play - ev[k]
		if pts.is_empty() or a < 0.0:
			continue
		var v: float = pts[-1][1]
		for j in range(1, pts.size()):
			if a < pts[j][0]:
				v = lerpf(pts[j - 1][1], pts[j][1], smoothstep(pts[j - 1][0], pts[j][0], a))
				break
		m *= v
	return m


## Your own sales' price impact on box `i` is scaled by an active event's `impact`.
func impact_mul(i: int) -> float:
	for k: String in ev:
		var e: Dictionary = Defs.EVENTS[k]
		var a: float = play - ev[k]
		if e.has("impact") and e.fx.has(i) and a >= 0.0 and a < e.fx[i][-1][0]:
			return e.impact
	return 1.0


func ai(i: int) -> bool: return mx[i].ain and mx[i].in_on
func ao(i: int) -> bool: return mx[i].aout and mx[i].out_on
func cyc(i: int) -> float: return Defs.GENS[i].cyc * pow(Defs.SPD_STEP, mx[i].spd)
func mul(i: int) -> int: return 1 + Defs.YLD_STEP * mx[i].yld
## A colour's market opens once you own its machine or first get one into the warehouse.
func unlocked(i: int) -> bool: return i == 0 or own[i] > 0 or ms.has("got%d" % i)
func visible_tier(i: int) -> bool: return i == 0 or own[i - 1] > 0
## Drops per slam.
func per_press() -> int:
	return 1 + (Defs.up("heavy").add if up.has("heavy") else 0) + (Defs.up("heavy2").add if up.has("heavy2") else 0)
func market_open() -> bool: return ms.has("box1") or total_earned > 0.0 or inv[0] > 0
func modes_on() -> bool: return own.max() >= Defs.BUY_MODES_AT


## Current combo, or 0 once the last slam is older than COMBO_WINDOW.
func combo_live() -> int:
	return combo if now() - _last_slam < Defs.COMBO_WINDOW else 0


## Machine output multiplier from the press upgrades; 1.0 unless the combo is alive.
func press_boost() -> float:
	var c := combo_live()
	var od := Defs.up("overdrive")
	if c < od.min or not up.has("overdrive"):
		return 1.0
	var cap: float = Defs.up("overdrive2" if up.has("overdrive2") else "overdrive").cap_pct
	var b := minf(od.step_pct * c, cap) / 100.0
	var ot := Defs.up("overtime")
	return (1.0 + b) * (float(ot.mul) if up.has("overtime") and c >= ot.min else 1.0)


func mu_cost(i: int, k: String) -> float:
	var b: float = Defs.GENS[i].cost
	match k:
		"spd", "yld": return b * Defs.MU_COST[k].mul * pow(Defs.MU_COST[k].growth, mx[i][k])
	return b * Defs.MU_COST.auto


func mu_maxed(i: int, k: String) -> bool:
	return mx[i][k] >= Defs.MU_MAX if k == "spd" or k == "yld" else bool(mx[i][k])


func up_req_met(id: String) -> bool:
	var u := Defs.up(id)
	if u.has("req_up"):
		return up.has(u.req_up)
	return own[u.req_gen] >= u.req_n if u.has("req_gen") else true


func reserve_of(i: int) -> int:
	var r := 0
	for j in Defs.GENS.size():
		r += Defs.GENS[j].inputs.get(i, 0) * own[j] * Defs.RESERVE_CYCLES
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
	var g := Defs.GEN_GROWTH
	var c: float = Defs.GENS[i].cost * pow(g, own[i])
	return c * (pow(g, q) - 1.0) / (g - 1.0)


func max_afford(i: int) -> int:
	var g := Defs.GEN_GROWTH
	var c: float = Defs.GENS[i].cost * pow(g, own[i])
	return maxi(0, floori(log(money * (g - 1.0) / c + 1.0) / log(g)))


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
	var cut: float = 1.0 - Defs.up("insider").cut_pct / 100.0 if up.has("insider") else 1.0
	var imp := minf(Defs.MAX_IMPACT, q / Defs.BOXES[i].depth) * cut * impact_mul(i)
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


func machine_upgrades_affordable(i: int) -> int:
	if own[i] == 0:
		return 0
	var n := 0
	for k in ["spd", "yld", "ain", "aout"]:
		if not mu_maxed(i, k) and money >= mu_cost(i, k):
			n += 1
	return n


# ---------------------------------------------------------------- simulation

func _seed_market() -> void:
	market.clear()
	var t := now()
	var start := floorf(t / Defs.CANDLE_S) * Defs.CANDLE_S - Defs.N_CANDLES * Defs.CANDLE_S
	for b: Dictionary in Defs.BOXES:
		var base: float = b.base
		var mk := Defs.MARKET
		var p := base * randf_range(1.0 - mk.seed_jitter, 1.0 + mk.seed_jitter)
		var candles := []
		for j in Defs.N_CANDLES:
			var o := p
			var h := o
			var l := o
			for s in 6:
				p += (base - p) * mk.seed_pull + p * mk.seed_noise * randfn(0.0, 1.0)
				p = maxf(base * mk.seed_floor, p)
				h = maxf(h, p)
				l = minf(l, p)
			candles.append({t = start + j * Defs.CANDLE_S, o = o, h = h, l = l, c = p, sold = 0})
		market.append({p = p, ph = randf() * TAU, candles = candles,
			cur = {t = start + Defs.N_CANDLES * Defs.CANDLE_S, o = p, h = p, l = p, c = p, sold = 0},
			upd = t, next = t + randf_range(0.2, 1.2)})


func _step_market(t: float) -> void:
	for i in market.size():
		var m := market[i]
		var base: float = Defs.BOXES[i].base
		if t >= m.next:
			var mk := Defs.MARKET
			var dt := minf(2.0, t - m.upd)
			var em := ev_mul(i)
			var fair: float = base * em * (1.0 + mk.swing * sin(play / (mk.period + i * mk.period_step) + m.ph))
			var p: float = m.p + (fair - m.p) * minf(1.0, mk.pull * dt) + m.p * mk.noise * randfn(0.0, 1.0) * sqrt(dt)
			p = maxf(base * mk.floor * minf(1.0, em), p)  # crashes may dig below the floor while they last
			m.p = p
			m.upd = t
			m.next = t + randf_range(mk.tick_min, mk.tick_max)
			m.cur.c = p
			m.cur.h = maxf(m.cur.h, p)
			m.cur.l = minf(m.cur.l, p)
		if t >= m.cur.t + Defs.CANDLE_S:
			m.candles.append(m.cur)
			if m.candles.size() > Defs.N_CANDLES:
				m.candles = m.candles.slice(-Defs.N_CANDLES)
			m.cur = {t = maxf(m.cur.t + Defs.CANDLE_S, floorf(t / Defs.CANDLE_S) * Defs.CANDLE_S), o = m.p, h = m.p, l = m.p, c = m.p, sold = 0}


func _econ(dt: float) -> void:
	play += dt
	for k: String in ev:
		if play >= ev[k] and not ms.has("ev_" + k):
			mark("ev_" + k)
			for i: int in Defs.EVENTS[k].fx:
				market[i].p *= Defs.EVENTS[k].fx[i][0][1]
			news.emit(Defs.EVENTS[k].head)
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
		var boost := press_boost()
		var f: float = x.batch * mul(i) * boost + x.frac  # fractions carry so small boosts aren't lost
		var q := floori(f)
		x.frac = f - q
		finished.emit(i, q)
		if ao(i):
			_land(out, q)
		else:
			x.held += q
	if up.has("broker"):
		_broker_t += dt
		if _broker_t >= Defs.up("broker").every:
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


## Every box entering the warehouse goes through here (machines, press floor, sweeper).
func _land(i: int, q: int) -> void:
	var fresh := not unlocked(i)
	inv[i] += q
	produced.emit(i, q)
	if not ms.has("box1"):
		mark("box1")
		toast.emit("EXCHANGE OPEN", "Grey boxes now trade on the market. Sell them to buy a Red Stacker.", true)
	elif fresh:
		mark("got%d" % i)
		new_mk[i] = now()
		toast.emit("NEW MARKET · %s" % Defs.BOXES[i].k, "%ses now trade on the exchange." % Defs.BOXES[i].name, true)


## Batches of gen `i`'s recipe the warehouse covers, up to `cap`.
func batches(i: int, cap: int) -> int:
	var ins := Defs.inputs(i)
	var b := cap
	for k: int in ins:
		b = mini(b, floori(inv[k] / float(ins[k])))
	return maxi(0, b)


## Consumes up to `cap` batches of gen `i`'s inputs; returns how many were taken.
func _take(i: int, cap: int) -> int:
	var b := batches(i, cap)
	for k: int in Defs.inputs(i):
		inv[k] -= b * Defs.inputs(i)[k]
	return b


func _start_gen(i: int) -> bool:
	var b := _take(i, own[i])
	if b <= 0:
		return false
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


## Every `changed` listener refreshes its part of the UI (~20ms in total), so state changes are
## coalesced into at most one emit per frame.
func notify_changed() -> void:
	if not _dirty:
		_dirty = true
		_emit_changed.call_deferred()


func _emit_changed() -> void:
	_dirty = false
	changed.emit()


## Milestones fire once: they schedule their market event and send their email.
func mark(key: String) -> void:
	if ms.has(key):
		return
	ms[key] = play
	if key == "opened":
		return  # the ending sequence runs its own event and email
	if Defs.EVENTS.has(key):
		ev[key] = play + randf_range(Defs.EVENT_DELAY[0], Defs.EVENT_DELAY[1])
	if Defs.EMAILS.has(key):
		_mail(key)


## Emails received so far (EMAILS keys), newest first. The HR "opened" email waits for its beat.
func inbox() -> Array:
	var ks := Defs.EMAILS.keys().filter(func(k): return ms.has(k) and not (k == "opened" and opening))
	var order := Defs.EMAILS.keys()
	ks.sort_custom(func(a, b): return ms[a] > ms[b] or (ms[a] == ms[b] and order.find(a) > order.find(b)))
	return ks


func _mail(key: String) -> void:
	toast.emit(Defs.EMAILS[key][0], Defs.EMAILS[key][1], true)


## The ??? slam (story.md §7). Runs once "opened" is marked; "end" marks it finished.
func _ending() -> void:
	_ending_on = true
	opening = true
	news.emit(Defs.ENDING.breaking)
	if not await _beat(Defs.ENDING_BEATS[0]):
		return
	news.emit(Defs.ENDING.removed)
	if not await _beat(Defs.ENDING_BEATS[1]):
		return
	if not ev.has("opened"):
		ev["opened"] = play  # every market crashes (VIO soars) on the next econ tick
	if not await _beat(Defs.ENDING_BEATS[2]):
		return
	_mail("opened")
	opening = false  # title -> Pending
	notify_changed()
	if not await _beat(Defs.ENDING_BEATS[3]):
		return
	mark("end")
	_ending_on = false
	save()
	ended.emit()


## Waits `s`; false if a reset wiped the opened box meanwhile (the sequence then stops).
func _beat(s: float) -> bool:
	await get_tree().create_timer(s).timeout
	return ms.has("opened")


# ---------------------------------------------------------------- actions

## Newest unlocked colour. Unlocks are contiguous (visible_tier gates each on the one before).
func top_colour() -> int:
	var top := 0
	for i in Defs.BOXES.size():
		if unlocked(i):
			top = i
	return top


## Boxes one press drop is worth: x10 per tier the colour sits behind the newest unlocked one.
func bundle(i: int) -> int:
	return int(pow(Defs.BUNDLE, top_colour() - i))


## Colour of one press drop: any unlocked colour, weighted 3:1 per tier toward older ones.
func press_pick() -> int:
	var top := top_colour()
	var o := Defs.PRESS_ODDS
	var r := randf() * (pow(o, top + 1) - 1.0) / (o - 1.0)  # sum of o^0..o^top
	for i in top:
		r -= pow(o, top - i)
		if r < 0.0:
			return i
	return top


## The ??? slot shows once you own a Forge, until the box is opened (design_ref/story.md §7).
func mystery_shown() -> bool:
	return own[Defs.GENS.size() - 1] > 0 and not ms.has("opened")


func can_open() -> bool:
	return mystery_shown() and batches(Defs.MYSTERY, 1) > 0


## Loads / unloads the ??? slot. Opening is opt-in so combo slams can't open the box by accident.
func toggle_arm() -> void:
	armed = not armed and can_open()
	notify_changed()


## Called by the press stage per click. Returns the slam's drops as [colour, boxes] pairs;
## empty for the ??? slam, which opens the box instead.
func press() -> Array:
	var t := now()
	combo = combo + 1 if t - _last_slam < Defs.COMBO_WINDOW else 1
	_last_slam = t
	mark("press1")
	if armed and can_open():
		armed = false
		_take(Defs.MYSTERY, 1)
		mark("opened")
		save()
		_ending()
		notify_changed()
		return []
	armed = false
	var drops := []
	for j in per_press():
		var c := press_pick()
		drops.append([c, bundle(c)])
	notify_changed()
	return drops


## `n` boxes of colour `i` picked up from the press floor (by hand, sweeper, or floor overflow).
func collect(i: int, n: int) -> void:
	_land(i, n)
	notify_changed()


func buy_gen(i: int) -> bool:
	var q := qty_for(i)
	var cost := gen_cost(i, q)
	if money < cost or not visible_tier(i):
		return false
	var first := own[i] == 0
	var fresh := not unlocked(i)
	money -= cost
	own[i] += q
	if first:
		mark(Defs.GENS[i].id)
		var nxt: String = "The press now makes %ses too." % Defs.BOXES[i].name if i < Defs.GENS.size() - 1 else "Every machine is built."
		toast.emit("%s BUILT" % Defs.GENS[i].name.to_upper(), nxt, true)
		if fresh:
			sel = i
			new_mk[i] = now()
	save()
	notify_changed()
	return true


func buy_up(id: String) -> bool:
	var u := Defs.up(id)
	if up.has(id) or not up_req_met(id) or money < u.cost:
		return false
	money -= u.cost
	up[id] = true
	mark(id)
	toast.emit(u.name.to_upper(), Defs.desc(u), false)
	save()
	notify_changed()
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
	notify_changed()
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
		notify_changed()
		return Act.COLLECTED
	if own[i] > 0 and _start_gen(i):
		notify_changed()
		return Act.STARTED
	return Act.DENIED


func toggle_auto(i: int, k: String) -> void:
	if not mx[i][k]:
		return
	var f := "in_on" if k == "ain" else "out_on"
	mx[i][f] = not mx[i][f]
	notify_changed()


## Sells from the selected market. Returns the total earned (0 if nothing was sellable).
func sell(mode: String) -> float:
	var q := sell_qty(mode, sel)
	if q <= 0:
		return 0.0
	var total := _do_sell(sel, q, false)
	notify_changed()
	return total


func sell_surplus() -> bool:
	var any := false
	for i in Defs.BOXES.size():
		var q := sellable(i)
		if unlocked(i) and q > 0:
			_do_sell(i, q, false)
			any = true
	notify_changed()
	return any


func select(i: int) -> bool:
	if not unlocked(i):
		return false
	sel = i
	notify_changed()
	return true


## View prefs (chart, quotes, rtab, buy_mode, reserve, mute).
func set_pref(key: String, value: Variant) -> void:
	set(key, value)
	notify_changed()


# ---------------------------------------------------------------- persistence

func save() -> void:
	_save_t = 0.0
	if not autosave:
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({v = 1, money = money, inv = inv, own = own, up = up, trades = trades,
		mute = mute, buy_mode = buy_mode, reserve = reserve, play = play, ms = ms, ev = ev, wait_max = wait_max,
		total_earned = total_earned, sel = sel, chart = chart, quotes = quotes, mx = mx, rtab = rtab, mail_seen = mail_seen}))
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
		own[i] = int(d.own[i]) if i else maxi(1, int(d.own[i]))
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
	ev = d.get("ev", {})
	wait_max = d.get("wait_max", 0.0)
	total_earned = d.get("total_earned", 0.0)
	sel = int(d.get("sel", 0))
	chart = d.get("chart", "candles")
	quotes = d.get("quotes", false)
	rtab = d.get("rtab", "machines")
	mail_seen = int(d.get("mail_seen", 0))
	saved_at = now()


func reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var keep_mute := mute
	_fresh()
	mute = keep_mute
	notify_changed()
