class_name Defs
extends RefCounted

## Economy constants and number formatting from the Box Exchange v6 handoff.

const BOXES := [
	{k = "GRY", name = "Grey Box", color = Color("#b9b5aa"), base = 1.0, depth = 300.0},
	{k = "RED", name = "Red Box", color = Color("#e0504a"), base = 6.0, depth = 120.0},
	{k = "AMB", name = "Amber Box", color = Color("#f0a422"), base = 30.0, depth = 50.0},
	{k = "TEA", name = "Teal Box", color = Color("#34b7a2"), base = 220.0, depth = 20.0},
	{k = "VIO", name = "Violet Box", color = Color("#9563de"), base = 1500.0, depth = 8.0},
]
## `inputs` maps box index -> quantity per batch; `out` is a box index.
const GENS := [
	{id = "arm", name = "Press Arm", cost = 12.0, inputs = {}, out = 0, cyc = 2.0},
	{id = "vat", name = "Red Stacker", cost = 60.0, inputs = {0: 3}, out = 1, cyc = 3.0},
	{id = "kiln", name = "Amber Laminator", cost = 300.0, inputs = {1: 2, 0: 3}, out = 2, cyc = 5.0},
	{id = "fuse", name = "Teal Fuser", cost = 2500.0, inputs = {2: 3, 1: 4}, out = 3, cyc = 8.0},
	{id = "forge", name = "Violet Forge", cost = 15000.0, inputs = {3: 3, 2: 2}, out = 4, cyc = 12.0},
]
const UPS := [
	{id = "heavy", tier = 0, name = "Heavy Press", cost = 40.0, desc = "Each slam crafts 2 boxes (uses 2× inputs).", req_t = ""},
	{id = "sweep", tier = 0, name = "Floor Sweeper", cost = 120.0, desc = "Drives across the press floor every 1.5s, pushing up to 8 boxes off the edge.", req_t = "OWN 1 ARM"},
	{id = "heavy2", tier = 0, name = "Hydraulic Press", cost = 450.0, desc = "Each slam crafts 4 boxes (uses 4× inputs).", req_t = "HEAVY PRESS"},
	{id = "broker", tier = 1, name = "Broker Bot", cost = 500.0, desc = "Every 5s, sells surplus of any box trading above its average.", req_t = "OWN 1 STACKER"},
	{id = "insider", tier = 1, name = "Market Maker", cost = 1500.0, desc = "Halves the price drop caused by your own sales.", req_t = "OWN 5 STACKERS"},
]
const MILESTONES := [
	["box1", "Market open"], ["press1", "First press"], ["sell1", "First sale"],
	["auto", "First Auto-In"], ["vat", "Stacker · RED"], ["sweep", "Sweeper"], ["kiln", "Laminator · AMB"],
	["broker", "Broker Bot"], ["fuse", "Fuser · TEA"], ["forge", "Forge · VIO"],
]
## Press target past the last box: the one slam that opens a box (design_ref/story.md §7).
const MYSTERY := 5
const MYSTERY_INPUTS := {4: 3, 3: 3}
## TODO: replace with the real itch page before shipping.
const ITCH_URL := "https://example.itch.io/plastic-millionaire"

# Story text (design_ref/story.md). Keys are milestone ids from Game.ms unless noted.
## Career title = the last key here that's in Game.ms ("start" is marked on a fresh run).
const TITLES := {
	start = "Unpaid Intern, Red Department",
	sell1 = "Junior Box Associate",
	vat = "Amber Specialist",
	kiln = "Director of Teal",
	broker = "VP of Box Liquidity",
	fuse = "Owner & Chief Box Officer",
	forge = "Last Human on the Floor",
	opened = "Pending",
}
## [sender, body], delivered once when the milestone is first marked.
const EMAILS := {
	start = ["HR", "Welcome! The Press Arm handles grey. You handle red. Please don't speak to the Arm; it's senior to you."],
	sell1 = ["Accounting", "Congratulations on your first sale. Please stop high-fiving the customer."],
	vat = ["HR", "Your red-box duties now belong to the Red Stacker. You've been promoted to amber. Same pay."],
	kiln = ["Facilities", "Please stop laminating your lunch. The Laminator is doing your old job and needs to concentrate."],
	broker = ["CEO", "Your bot outperformed the entire finance team. The finance team has been invited to a meeting with your bot."],
	fuse = ["Former CEO", "I've sold you the company. One thing: never open a box. Also, please let me keep my parking spot."],
	forge = ["Unknown sender", "Every tier is automated. The press has nothing left to make. Except one thing."],
	opened = ["HR", "Due to the events of today, the remainder of your career is pending. Please await further instructions."],
}
## Ticker pools by stage (Game.stage()). [headline, clue]: clue lines weigh more each stage.
const NEWS := {
	early = [
		["Local box company reports \"a normal amount of boxes\" this quarter.", false],
		["Intern seen pressing boxes. Supervisors confirm this is the job.", false],
		["GRY closes flat for 14th straight session. Analysts: \"Good.\"", false],
		["Breakroom coffee machine replaced with a box. Nobody has noticed.", false],
		["Red Box debuts. Marketing: \"Three greys, one vision.\"", false],
		["RED up 6% as consumers rediscover ambition.", false],
		["HR reminds staff that boxes are not a personality.", false],
		["Survey: 0% of box owners have opened their box. \"Why would we?\"", true],
		["Press Arm named Employee of the Month for the 40th month running.", false],
		["GRY: the only box no human has touched in years.", false],
	],
	mid = [
		["AMB up 30% after influencer unboxes amber box, finds nothing, calls it \"life-changing.\"", false],
		["Analysts upgrade Amber from \"Buy\" to \"Glow.\"", false],
		["First Box ETF launches. It is a box made of smaller boxes.", false],
		["RED falls 12% after audit finds it is \"basically three greys.\"", false],
		["Company policy update: \"Boxes are for selling, not for looking in.\"", true],
		["Teal IPO oversubscribed 400x. Nobody can explain what a Teal Box is for.", false],
		["TEA slides 8% after short seller counts the boxes it's made of.", false],
		["Central bank cuts rates \"to support the box.\"", false],
		["Philosophers ask: if a Red is three Greys, what is a Grey?", true],
		["Man who opened a box declines to discuss it. Moves to the countryside.", true],
	],
	late = [
		["VIO up 900% on no news. Volume described as \"spiritual.\"", false],
		["Scientists confirm the Violet Box is \"mostly vibe.\"", false],
		["Poll: 71% want someone to open a box. 0% volunteer.", true],
		["Experts warn opening a box \"could affect prices.\"", true],
		["All eyes turn to the owner of the box company.", true],
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
## Keyed by machine id, upgrade id, or machine-upgrade key (ain / aout).
const FLAVOUR := {
	arm = "Was here before you. Will be here after you.",
	vat = "Stacks three greys until they become red. Nobody knows when it happens.",
	kiln = "Layers boxes onto boxes. The boxes were not consulted.",
	fuse = "Took your job. Was very gracious about it.",
	forge = "There is nothing left for your hands to make.",
	heavy = "Two boxes per slam. Twice the inputs, twice the conviction.",
	sweep = "Pushes boxes off the edge. Legal calls it \"logistics.\"",
	heavy2 = "Now with fluid. Don't ask which fluid.",
	broker = "Sells high on day one. Already beats the analysts.",
	insider = "Your sales no longer crash the market. Its feelings are another matter.",
	ain = "Feeds the machine. Lately the machine says thank you.",
	aout = "Empties the machine so it can go back to feeling nothing.",
}
## Market tab tooltips, by box index.
const REPS := [
	"The pension fund. The box everything else is made of. Deep, boring, indestructible. \"Nobody ever got fired for buying grey.\"",
	"Grey's ambitious older sibling. Made of three greys, priced like six.",
	"The gold bug. Hoarded in bunkers by people who don't trust grey.",
	"The startup. Built from eleven boxes, does nothing any of them couldn't. Huge growth anyway.",
	"The meme stock. So many boxes deep that nobody can count them. Thin market, unhinged swings. Holders call themselves \"the Purple Hands.\"",
]
const MU_MAX := 5
const N_CANDLES := 48

# Design tokens scripts need for state-driven colours; static looks live in ui/theme.tres.
const INK := Color("#06080f")
const BG := Color("#141416")
const CARD := Color("#202023")
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
const GOLD_LABEL := Color("#e8c48a")
const UP := Color("#7bc96f")
const DOWN := Color("#e0504a")
const WARN := Color("#ff9a8a")
const AFFORD_BORDER := Color("#5a4a14")
const LIT_BG := Color("#3a3010")

const _SUF := ["", "K", "M", "B", "T", "Qa", "Qi"]


## add_theme_color_override re-themes and relayouts `c` even when the colour is unchanged
## (~0.1ms each), so refresh paths go through this instead.
static func tint(c: Control, name: StringName, col: Color) -> void:
	if not c.has_theme_color_override(name) or c.get_theme_color(name) != col:
		c.add_theme_color_override(name, col)

## Recipe for crafting box tier `i` (GENS[i].out == i); MYSTERY has its own.
static func inputs(i: int) -> Dictionary:
	return MYSTERY_INPUTS if i == MYSTERY else GENS[i].inputs

## "2 RED + 3 GRY" for tier `i`'s inputs.
static func recipe(i: int) -> String:
	var parts := []
	for k: int in inputs(i):
		parts.append("%d %s" % [inputs(i)[k], BOXES[k].k])
	return " + ".join(parts)

## Ticker / chip label for a press target.
static func tk(i: int) -> String:
	return "???" if i == MYSTERY else BOXES[i].k

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

static func px(p: float) -> String:
	return "%.2f" % p if p < 10.0 else "%.1f" % p if p < 1000.0 else fmt(p)

static func rt(r: float) -> String:
	return "%.2f" % r if absf(r) < 1.0 else "%.1f" % r if absf(r) < 10.0 else fmt(r)

static func pct(v: float, digits := 1) -> String:
	return ("+" if v >= 0.0 else "") + ("%." + str(digits) + "f%%") % v

## Wall-clock HH:MM:SS for a unix timestamp in seconds.
static func clock(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t) + _tz_bias())
	return "%02d:%02d:%02d" % [d.hour, d.minute, d.second]

static func mmss(s: float) -> String:
	return "%02d:%02d" % [floori(s / 60.0), floori(fmod(s, 60.0))]

static func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().bias) * 60
