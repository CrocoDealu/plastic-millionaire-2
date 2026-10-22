class_name Defs
extends RefCounted

## Economy constants and number formatting from the Contents Classified v6 handoff.

const BOXES := [
	{k = "GRY", name = "Grey Box", color = Color("#b9b5aa"), base = 0.02, depth = 300.0},
	{k = "RED", name = "Red Box", color = Color("#e0504a"), base = 0.12, depth = 120.0},
	{k = "AMB", name = "Amber Box", color = Color("#f0a422"), base = 2.0, depth = 50.0},
	{k = "TEA", name = "Teal Box", color = Color("#34b7a2"), base = 15.0, depth = 20.0},
	{k = "VIO", name = "Violet Box", color = Color("#9563de"), base = 200.0, depth = 8.0},
]
## `inputs` maps box index -> quantity per batch; `out` is a box index.
const GENS := [
	{id = "arm", name = "Press Arm", cost = 12.0, inputs = {}, out = 0, cyc = 2.0},
	{id = "vat", name = "Red Stacker", cost = 60.0, inputs = {0: 3}, out = 1, cyc = 0.5},
	{id = "kiln", name = "Amber Laminator", cost = 300.0, inputs = {1: 2, 0: 3}, out = 2, cyc = 2.0},
	{id = "fuse", name = "Teal Fuser", cost = 2500.0, inputs = {2: 3, 1: 4}, out = 3, cyc = 4.0},
	{id = "forge", name = "Violet Forge", cost = 15000.0, inputs = {3: 3, 2: 2}, out = 4, cyc = 4.0},
]
## Skill tree (design_ref/skill_tree.md, v8 handoff). Node: `br` branch, `k` slot shape (large /
## sharp / round), grid `c`,`r`, `par` parents (ALL needed), `d` description formatted with the stage's
## `e`, `fl` flavour, `st` stages. Stage: `n` name, `c` cost, `e` effect values, `g` [tier, count]
## machines needed (optional), `need` [node id, stages] owned elsewhere in the tree (optional), `fl`
## stage flavour (optional). Resource nodes (`tier`) come from TIER: per colour, Chute -> Speed ->
## Bulk discount and Hopper -> Yield -> Rated Capacity, which gates Speed / Yield past MU_MAX.
const SK_GLOBAL := [
	{id = "press", br = "centre", k = "large", c = 2, r = 4, par = [], d = "The press. You slam it.",
		fl = "The only machine in the building that still needs you.", st = [{n = "Box Press", c = 0.0, e = {}}]},
	{id = "heavy", br = "press", k = "round", c = 1, r = 2, par = ["press"], d = "+{add} boxes per press.",
		fl = "Two boxes per slam. Twice the conviction.", st = [
		{n = "Heavy Press", c = 40.0, e = {add = 1}},
		{n = "Hydraulic Press", c = 450.0, e = {add = 2}, fl = "Now with fluid. Don't ask which fluid."},
		{n = "Industrial Press", c = 4000.0, e = {add = 3}, g = [2, 1], fl = "Classified as heavy industry. Weighs about the same as before."}]},
	{id = "sweep", br = "press", k = "sharp", c = 2, r = 2, par = ["press"],
		d = "Drives across the press floor every {every}s, pushing up to {carry} boxes off the edge.",
		fl = "Pushes boxes off the edge. Legal calls it \"logistics.\"", st = [{n = "Floor Sweeper", c = 120.0, e = {every = 1.5, carry = 8}}]},
	{id = "die", br = "press", k = "round", c = 2, r = 0, par = ["sweep"], d = "Drops up to {reach} grade{s} behind your newest are worth ×%d per grade." % BUNDLE,
		fl = "Stamps old grades in bulk. QC signs off without looking, as is tradition.", st = [
		{n = "Die · Red", c = 120.0, e = {reach = 1, s = ""}, g = [1, 1]},
		{n = "Die · Amber", c = 600.0, e = {reach = 2, s = "s"}, g = [2, 1]},
		{n = "Die · Teal", c = 5000.0, e = {reach = 3, s = "s"}, g = [3, 1]},
		{n = "Die · Violet", c = 30000.0, e = {reach = 4, s = "s"}, g = [4, 1]}]},
	{id = "bell", br = "combo", k = "sharp", c = 3, r = 6, par = ["press"], d = "Slams up to {window}s apart keep the combo going.",
		fl = "Rings whenever you keep up. Has never rung for anyone else.", st = [{n = "Shift Bell", c = 150.0, e = {window = 0.9}}]},
	{id = "overdrive", br = "combo", k = "round", c = 4, r = 6, par = ["bell", "arm_in"],
		d = "At combo {min}+, machines make +{step}% per combo step (max +{cap}%).",
		fl = "The machines work harder when they hear you working. Nobody told them you're faking it.", st = [
		{n = "Overdrive", c = 250.0, e = {min = 5, step = 2, cap = 60}},
		{n = "Turbo Overdrive", c = 1500.0, e = {min = 5, step = 2, cap = 150}, fl = "Voids the warranty, the lease and one minor treaty."}]},
	{id = "overtime", br = "combo", k = "round", c = 3, r = 8, par = ["bell"], d = "At combo {min}+, machine output is ×{mul} on top of Overdrive.",
		fl = "Unpaid, obviously. The machines get time and a half.", st = [
		{n = "Overtime", c = 800.0, e = {min = 25, mul = 2}, g = [1, 3]},
		{n = "Double Shift", c = 9000.0, e = {min = 40, mul = 3}, g = [3, 1], fl = "Second shift starts before the first one ends. HR calls this \"synergy.\""}]},
	{id = "broker", br = "market", k = "sharp", c = 1, r = 6, par = ["press"], d = "Every {every}s, sells surplus of any box trading above its average.",
		fl = "Sells high on day one. Already beats the analysts.", st = [{n = "Broker Bot", c = 500.0, e = {every = 5.0}, g = [1, 1]}]},
	{id = "insider", br = "market", k = "round", c = 0, r = 8, par = ["broker"], d = "Your own sales move the price {cut}% less.",
		fl = "Your sales no longer crash the market. Its feelings are another matter.", st = [
		{n = "Market Maker", c = 1500.0, e = {cut = 50}, g = [1, 5]},
		{n = "Market Whisperer", c = 12000.0, e = {cut = 80}, g = [3, 1], fl = "The market now checks with you before it has feelings."}]},
	{id = "desk", br = "market", k = "round", c = 1, r = 8, par = ["broker"], d = "Broker Bot trades every {every}s.",
		fl = "The bot asked for a desk. It has no legs. It got the desk.", st = [
		{n = "Trading Desk", c = 1200.0, e = {every = 3.0}},
		{n = "Corner Office", c = 8000.0, e = {every = 1.5}, g = [2, 1], fl = "Window view of the market. The market is also a window."}]},
]
## Per machine tier: [chute, flavour, hopper, flavour, discount, flavour, capacity, flavour].
const TIER := [
	["Output Chute", "A hole in the floor, formally recognised as infrastructure.", "Self-Start", "The Arm no longer waits for you. It never really did.",
		"Bulk Procurement", "Arms now arrive in boxes. The boxes are grey. Nobody comments.", "Rated Capacity", "Re-rated by an inspector who was also, technically, a Press Arm."],
	["Stacker Chute", "Reds leave the Stacker on their own now. They've earned it.", "Stacker Hopper", "Greys now arrive by conveyor. Your hands have been promoted to red.",
		"Stacker Bulk Deal", "The more Stackers you buy, the less each one respects you.", "Red Certification", "Every red now certified as at least three greys. Audit pending."],
	["Laminator Chute", "Ambers exit single file. The Laminator insists.", "Laminator Hopper", "Facilities has asked it to stop laminating the hopper.",
		"Amber Futures", "Laminators pre-ordered at today's prices. Today is very confident.", "Gold Standard", "Amber is now officially worth what amber is worth."],
	["Fuser Chute", "Teals leave with a handshake. The Fuser insists on handshakes.", "Fuser Hopper", "Took over your inputs too. Sent a lovely card.",
		"Series A", "Investors fund more Fusers. Nobody has asked what a Teal is for.", "Hypergrowth", "Output is up and to the right. Mostly to the right."],
	["Forge Chute", "Violets come out on their own. Nobody is sure they went in.", "Forge Hopper", "The last input you will ever not touch.",
		"Purple Hands Discount", "Holders sold you Forges at a loss. They call it \"conviction.\"", "Unrated Capacity", "The inspector declined to rate it, then declined to discuss it."],
]
## Resource node costs are multiples of the tier's machine cost.
const SK_TIER_COST := {out = 2.5, inn = 2.5, disc = [5.0, 20.0], cap = [6.0, 18.0, 54.0]}
const SK_DISC_GROWTH := [1.13, 1.11]
const BRANCH := {centre = ["CENTRE", Color("#f5c518")], press = ["PRESS", Color("#f5c518")],
	combo = ["COMBO", Color("#e2702a")], market = ["MARKET", Color("#7bc96f")]}
## Every node, global then per tier, built once from SK_GLOBAL and TIER.
static var SK: Array = _build_sk()
static var SKM: Dictionary = _index_sk()


static func _build_sk() -> Array:
	var out := SK_GLOBAL.duplicate(true)
	for t in GENS.size():
		var g: Dictionary = GENS[t]
		var tx: Array = TIER[t]
		var m: float = g.cost
		var c0 := 3 + 3 * t
		var cost := SK_TIER_COST
		out.append({id = g.id + "_out", tier = t, br = "res", k = "sharp", c = c0, r = 4,
			par = [GENS[t - 1].id + "_in" if t else "press"], d = g.name + " output goes to the warehouse automatically.",
			fl = tx[1], st = [{n = tx[0], c = cost.out * m, e = {}, g = [t, 1]}]})
		out.append({id = g.id + "_in", tier = t, br = "res", k = "sharp", c = c0 + 1, r = 4, par = [g.id + "_out"],
			d = g.name + " pulls its inputs from the warehouse automatically." if t else "The Press Arm starts every cycle on its own.",
			fl = tx[3], st = [{n = tx[2], c = cost.inn * m, e = {}}]})
		var spd := []
		var yld := []
		for k in MU_STAGES:
			var gate := {need = [g.id + "_cap", k + 1 - MU_MAX]} if k >= MU_MAX else {}
			spd.append({n = "Speed " + ROMAN[k], c = m * MU_COST.spd.mul * pow(MU_COST.spd.growth, k),
				e = {pct = roundi(pow(SPD_STEP, k + 1) * 100.0)}}.merged(gate))
			yld.append({n = "Yield " + ROMAN[k], c = m * MU_COST.yld.mul * pow(MU_COST.yld.growth, k),
				e = {n = 1 + YLD_STEP * (k + 1)}}.merged(gate))
		out.append({id = g.id + "_spd", tier = t, br = "res", k = "round", c = c0, r = 2, par = [g.id + "_out"],
			d = g.name + " cycles in {pct}% of the base time.", fl = MU_FLAVOUR.spd, st = spd})
		out.append({id = g.id + "_yld", tier = t, br = "res", k = "round", c = c0 + 1, r = 2, par = [g.id + "_in"],
			d = g.name + " makes {n} boxes per batch.", fl = MU_FLAVOUR.yld, st = yld})
		out.append({id = g.id + "_disc", tier = t, br = "res", k = "round", c = c0, r = 0, par = [g.id + "_spd"],
			d = g.name + " price grows ×{growth} per copy instead of ×%s." % GEN_GROWTH, fl = tx[5],
			st = [{n = tx[4], c = cost.disc[0] * m, e = {growth = SK_DISC_GROWTH[0]}}, {n = tx[4] + " II", c = cost.disc[1] * m, e = {growth = SK_DISC_GROWTH[1]}}]})
		var caps := []
		for j in 3:
			caps.append({n = tx[6] + ["", " II", " III"][j], c = cost.cap[j] * m, e = {cap = MU_MAX + 1 + j}})
		out.append({id = g.id + "_cap", tier = t, br = "res", k = "round", c = c0 + 1, r = 0, par = [g.id + "_yld"],
			d = g.name + " Speed and Yield cap at {cap} levels.", fl = tx[7], st = caps})
	return out


static func _index_sk() -> Dictionary:
	var d := {}
	for nd: Dictionary in SK:
		d[nd.id] = nd
	return d

# Economy tuning. Every balance number the game logic uses lives here.
const START_OWN := [1, 0, 0, 0, 0]  # every run starts with one Press Arm
const GEN_GROWTH := 1.15  # machine price x this per one already owned
## Speed / Yield stage k (from 0) costs machine cost x `mul` x `growth`^k.
const MU_COST := {spd = {mul = 1.5, growth = 1.8}, yld = {mul = 3.0, growth = 2.2}}
const MU_MAX := 5  # speed / yield stages before Rated Capacity
const MU_STAGES := 8  # speed / yield stages with every Rated Capacity stage
const MU_FLAVOUR := {spd = "Faster. Nobody asked the machine whether it wanted to be faster.",
	yld = "More boxes out of the same boxes. Accounting has stopped asking how."}
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
const SPD_STEP := 0.8  # cycle time x this per speed level
const YLD_STEP := 1  # boxes added to every batch per yield level
const BUY_MODES_AT := 5  # x10 / MAX buy modes appear once any machine count reaches this
# Press.
const BUNDLE := 2  # a drop is worth this many boxes per tier behind the newest colour
const PRESS_ODDS := 20.0  # each older colour is this much likelier to drop than the next one up
const COMBO_WINDOW := 0.6  # slams closer than this (s) keep the combo alive (Shift Bell raises it)
const BROKER_EVERY := 5.0  # Broker Bot interval before the Trading Desk
# Market.
const MAX_IMPACT := 0.3  # one sale moves the price at most this much
const MAX_ORDERS := 12  # open asks on the book at once
const ASK_PCT := [-10, 200]  # ask price offset range vs last, in whole percent
const FILL_NEAR := 0.5  # an ask within this % of last shows as FILLING
const CANDLE_S := 5.0
const N_CANDLES := 48
## Price walk: pulled toward a fair price that swings ±`swing` around base, plus noise.
const MARKET := {
	pull = 0.07, noise = 0.02, swing = 0.28, period = 70.0, period_step = 23.0, floor = 0.25,
	tick_min = 0.25, tick_max = 1.5,
	# Pre-generated history on a fresh run.
	seed_jitter = 0.1, seed_pull = 0.03, seed_noise = 0.022, seed_floor = 0.3,
}
const EVENT_DELAY := [30.0, 90.0]  # a milestone's market event fires this many seconds later
## Seconds between ending steps: breaking headline, removal, crash, HR email, end card.
const ENDING_BEATS := [2.5, 7.0, 2.5, 3.0]
const NEWS_STAGE_WEIGHT := 3.0  # current-stage headlines vs earlier ones

## Recipe index past the last box: the one slam that opens a box (design_ref/story.md §7).
const MYSTERY := 5
const MYSTERY_INPUTS := {4: 500, 3: 500}
## TODO: replace with the real itch page before shipping.
const ITCH_URL := "https://example.itch.io/plastic-millionaire"

# Story text (design_ref/story.md). Keys are milestone ids from Game.ms unless noted.
## Career title = the last key here that's in Game.ms ("start" is marked on a fresh run).
const TITLES := {
	start = "Unpaid Intern, Grey Department",
	sell1 = "Junior Box Associate",
	vat = "Red Specialist",
	kiln = "Amber Specialist",
	fuse = "Director of Teal",
	forge = "Last Human on the Floor",
	opened = "Pending",
}
## [sender, body], delivered once when the milestone is first marked.
const EMAILS := {
	start = ["HR", "Welcome! You run the press. The Press Arm also runs the press. Please don't speak to the Arm; it's senior to you."],
	sell1 = ["Accounting", "Congratulations on your first sale. Please stop high-fiving the customer."],
	vat = ["HR", "Your grey-box duties now belong to the Red Stacker. You've been promoted to red. Same pay."],
	kiln = ["Facilities", "Please stop laminating your lunch. The Laminator is doing your old job and needs to concentrate."],
	broker = ["CEO", "Your bot outperformed the entire finance team. The finance team has been invited to a meeting with your bot."],
	fuse = ["Former CEO", "I've sold you the company. One thing: never open a box. Also, please let me keep my parking spot."],
	forge = ["Unknown sender", "Every tier is automated. The press has nothing left to make. Except one thing."],
	opened = ["HR", "Due to the events of today, the remainder of your career is pending. Please await further instructions."],
}
## Ticker pools by stage (Game.stage()). [headline, clue]: clue lines weigh more each stage.
const NEWS := {
	# Pool lines never quote a box's price move: only market events (EVENTS) move prices, and
	# a fake "AMB up 30%" would read as live market data.
	early = [
		["Local box company reports \"a normal amount of boxes\" this quarter.", false],
		["Intern seen pressing boxes. Supervisors confirm this is the job.", false],
		["Grey analysts describe the outlook as \"grey.\" Clients relieved.", false],
		["Breakroom coffee machine replaced with a box. Nobody has noticed.", false],
		["Red Box debuts. Marketing: \"Three greys, one vision.\"", false],
		["Consumers rediscover ambition. Ambition, it turns out, is red.", false],
		["HR reminds staff that boxes are not a personality.", false],
		["Survey: 0% of box owners have opened their box. \"Why would we?\"", true],
		["Press Arm named Employee of the Month for the 40th month running.", false],
		["GRY: the only box no human has touched in years.", false],
		["\"Nobody ever got fired for buying grey,\" says man buying grey.", false],
		["Pension funds confirm they are \"mostly grey, by volume.\"", false],
		["Red Box owners describe themselves as \"grey, but driven.\"", false],
		["Press Arm requests no meetings before 9. Request granted.", false],
		["Company picnic cancelled. Too many boxes on the lawn.", false],
		["New hire asks what the boxes are for. Is moved to a different floor.", true],
	],
	mid = [
		["Influencer reviews amber box without opening it. Calls it \"life-changing.\"", false],
		["Analysts upgrade Amber from \"Buy\" to \"Glow.\"", false],
		["First Box ETF launches. It is a box made of smaller boxes.", false],
		["Auditors count the greys in a Red Box. Get three. Recount. Still three.", false],
		["Company policy update: \"Boxes are for selling, not for looking in.\"", true],
		["Teal IPO oversubscribed 400x. Nobody can explain what a Teal Box is for.", false],
		["Short seller tries to count the boxes in a Teal. Gives up at nine.", false],
		["Central bank cuts rates \"to support the box.\"", false],
		["Philosophers ask: if a Red is three Greys, what is a Grey?", true],
		["Man who opened a box declines to discuss it. Moves to the countryside.", true],
		["Amber hoarders move their bunkers into bigger bunkers.", false],
		["Teal startup raises another round to work out what it does.", false],
		["Teal Box is built from eleven boxes. Investors call it \"synergy.\"", false],
		["Amber fans insist the glow is \"a feeling, not a light.\"", false],
		["Laminator requests a coffee break between layers. Denied.", false],
		["Grey holders unbothered. Grey holders are always unbothered.", false],
		["Leaked HR memo: \"Do not shake the boxes either.\"", true],
	],
	late = [
		["Violet trades on no news. Volume described as \"spiritual.\"", false],
		["Scientists confirm the Violet Box is \"mostly vibe.\"", false],
		["Poll: 71% want someone to open a box. 0% volunteer.", true],
		["Experts warn opening a box \"could affect prices.\"", true],
		["All eyes turn to the owner of the box company.", true],
		["Purple Hands forum declares Violet \"the last box you'll ever need.\"", false],
		["Violet holders refuse to sell, explain, or blink.", false],
		["Grey Box quietly remains the backbone of the economy. Nobody thanks it.", false],
		["Factory floor fully automated except one person, who is asked to stop helping.", false],
		["Nobody can count the boxes in a Violet. Nobody is allowed to try.", true],
		["Box company owner seen staring at a box for six hours.", true],
		["Regulators propose boxes stay closed \"for everyone's sake.\"", true],
		["Insurers refuse to cover \"whatever is in the box.\"", true],
	],
	after = [["Contents: still classified.", false]],
}
## Market events: fire once, 30-90s after the milestone (Game.ev). `fx` maps box index ->
## [[seconds, fair multiplier], ...], eased between points; a first point off 1.0 also hits the
## price instantly. `impact` scales your own sales' price drop until the last point.
const EVENTS := {
	sell1 = {head = "Report: World may have enough grey boxes.", fx = {0: [[0, 1.0], [60, 0.6], [300, 1.0]]}},
	vat = {head = "Leaked memo: Red Box is \"three greys in a trench coat.\"",
		fx = {1: [[0, 1.0], [20, 0.5], [150, 1.0]], 2: [[0, 1.0], [20, 1.2], [150, 1.0]]}},
	kiln = {head = "Influencer sleeps in amber box, wakes up \"different.\"",
		fx = {2: [[0, 1.0], [120, 3.0], [150, 0.3], [330, 1.0]]}},
	forge = {head = "Short sellers learn only 8 violet boxes exist.", fx = {4: [[0, 1.0], [5, 5.0], [180, 1.0]]}, impact = 2.0},
	# Fired by the ending itself, not on a timer.
	# Every market snaps to ~3% of its price, holds near zero for 90s, then claws back over ~5 min.
	opened = {head = "Every box market falls 97%. Nobody will say why.", fx = {
		0: [[0, 0.03], [90, 0.03], [420, 1.0]], 1: [[0, 0.03], [90, 0.03], [420, 1.0]],
		2: [[0, 0.03], [90, 0.03], [420, 1.0]], 3: [[0, 0.03], [90, 0.03], [420, 1.0]],
		4: [[0, 0.03], [90, 0.03], [420, 1.0]]}},
}
const ENDING := {
	tip = "You were told not to.",
	breaking = "BREAKING: Box opened. Contains ......",
	removed = "[This headline has been removed at the request of the Global Box Standard]",
	card = "End of demo. Follow to find out what's inside.",
}
## Keyed by machine id. Tree flavour lives in SK.
const FLAVOUR := {
	arm = "Was here before you. Will be here after you.",
	vat = "Stacks three greys until they become red. Nobody knows when it happens.",
	kiln = "Layers boxes onto boxes. The boxes were not consulted.",
	fuse = "Took your job. Was very gracious about it.",
	forge = "There is nothing left for your hands to make.",
}
## Market tab tooltips, by box index.
const REPS := [
	"The pension fund. The box everything else is made of. Deep, boring, indestructible. \"Nobody ever got fired for buying grey.\"",
	"Grey's ambitious older sibling. Made of three greys, priced like six.",
	"The gold bug. Hoarded in bunkers by people who don't trust grey.",
	"The startup. Built from eleven boxes, does nothing any of them couldn't. Huge growth anyway.",
	"The meme stock. So many boxes deep that nobody can count them. Thin market, unhinged swings. Holders call themselves \"the Purple Hands.\"",
]

# Design tokens scripts need for state-driven colours; static looks live in ui/theme.tres.
const INK := Color("#06080f")
const BG := Color("#141416")
const LINE := Color("#3a3a3d")
const DIM_LINE := Color("#2d2d30")
const TEXT := Color("#ece8df")
const SOFT := Color("#bdb8ad")
const MUTED := Color("#9a968c")
const FAINT := Color("#77746c")
const DEAD := Color("#4a4a4d")
const CAUTION := Color("#f5c518")
const ORANGE := Color("#e2702a")
const GOLD := Color("#ffd166")
const UP := Color("#7bc96f")
const DOWN := Color("#e0504a")
const WARN := Color("#ff9a8a")
const LIT_BG := Color("#3a3010")

const _SUF := ["", "K", "M", "B", "T", "Qa", "Qi"]


## add_theme_color_override re-themes and relayouts `c` even when the colour is unchanged
## (~0.1ms each), so refresh paths go through this instead.
static func tint(c: Control, name: StringName, col: Color) -> void:
	if not c.has_theme_color_override(name) or c.get_theme_color(name) != col:
		c.add_theme_color_override(name, col)

## Inputs of gen `i`'s recipe; MYSTERY has its own.
static func inputs(i: int) -> Dictionary:
	return MYSTERY_INPUTS if i == MYSTERY else GENS[i].inputs

## Node `id`'s description for stage `st` (a SK stage dict).
static func sk_desc(id: String, st: Dictionary) -> String:
	return SKM[id].d.format(st.e)

## Branch colour of a node: its box colour for resource nodes.
static func sk_color(nd: Dictionary) -> Color:
	return BOXES[nd.tier].color if nd.has("tier") else BRANCH[nd.br][1]

## "2 RED + 3 GRY" for recipe `i`'s inputs.
static func recipe(i: int) -> String:
	var parts := []
	for k: int in inputs(i):
		parts.append("%d %s" % [inputs(i)[k], BOXES[k].k])
	return " + ".join(parts)

static func fmt(n: float) -> String:
	var a := absf(n)
	if a < 1000.0:
		return "%.1f" % n if a < 10.0 and fmod(n, 1.0) != 0.0 else str(floori(n))
	var i := 0
	var v := a
	while v >= 1000.0 and i < _SUF.size() - 1:
		v /= 1000.0
		i += 1
	var s := ("%.1f" % v) if v < 100.0 else ("%.0f" % v)
	return ("-" if n < 0.0 else "") + s.trim_suffix(".0") + _SUF[i]

static func cash(n: float) -> String:
	return "$" + ("%.2f" % n if absf(n) < 100.0 else fmt(n))

## Price step on the tape: a tenth of a cent for sub-dollar boxes (greys trade for cents).
static func tick(p: float) -> float:
	return 0.001 if p < 1.0 else 0.01 if p < 10.0 else 0.1

static func px(p: float) -> String:
	return "%.3f" % p if p < 1.0 else "%.2f" % p if p < 10.0 else "%.1f" % p if p < 1000.0 else fmt(p)

static func rt(r: float) -> String:
	return "%.2f" % r if absf(r) < 1.0 else "%.1f" % r if absf(r) < 10.0 else fmt(r)

## A per-second rate as whole boxes; a trickle under half a box a second reads "<1", not 0.
static func whole(r: float) -> String:
	return "<1" if r > 0.0 and r < 0.5 else fmt(roundi(r))

static func pct(v: float, digits := 1) -> String:
	return ("+" if v >= 0.0 else "") + ("%." + str(digits) + "f%%") % v

## Wall-clock HH:MM:SS for a unix timestamp in seconds.
static func clock(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t) + _tz_bias())
	return "%02d:%02d:%02d" % [d.hour, d.minute, d.second]

static func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().bias) * 60
