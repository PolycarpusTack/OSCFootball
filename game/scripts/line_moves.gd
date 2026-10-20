class_name LineMoves
extends RefCounted
## Chaos: ↓↘→ then shoot, with the ball, does a different move on each line. The striker's
## is the Fireball (see Supers, drawn with the Power Strike); the others are below. Each
## plays its own art from brand/sprites/line_actions. Like the supers, the bar is spent only
## once the foot meets the ball: lose it in the wind-up and it costs nothing.

const LIST := {
	"D": {"id": "bulldozer", "title": "BULLDOZER CLEAR!", "cost": 40.0, "anim": "bulldozer_clear", "contact": 0.35},
	"M": {"id": "laser", "title": "LASER PASS!", "cost": 30.0, "anim": "laser_pass", "contact": 0.35},
	"G": {"id": "cannon", "title": "CANNON PUNT!", "cost": 30.0, "anim": "cannon_punt", "contact": 0.35},
}
const CHARGE_SPEED := 300.0  # the Bulldozer runs at whoever's in the way, ball at his feet ...
const CHARGE_REACH := Footballer.REACH + 10.0  # ... and flattens anyone this close
const CLEAR_SPEED := 640.0  # then hoofs it upfield
const CLEAR_LIFT := 300.0
const LASER_SPEED := 760.0  # flat and on the money: no aim error, too fast for most to cut out
const PUNT_SPEED := 720.0  # a drop-kick from the hands, far upfield
const PUNT_LIFT := 340.0
const REACH := 1000.0  # pitch pixels ahead a clearance or punt is aimed at

var match_game: Match
var _charging := {}  # Footballer -> the opponents he has flattened this charge


func _init(m: Match) -> void:
	match_game = m


## The ↓↘→ move `p` would do: his line's entry in LIST, or {} for a striker (the Fireball).
static func for_line(p: Footballer) -> Dictionary:
	return LIST.get(p.role, {})


## `p`'s line move along `aim`. False (and nothing happens) when he can't: Classic, no ball,
## busy, the bar too low, or a keeper who must still hold it.
func start(p: Footballer, aim: Vector2) -> bool:
	var move := for_line(p)
	if move.is_empty() or not Match.chaos or not p.has_ball() or p.busy() or p.team.energy < move.cost:
		return false
	if p.role == "G" and not match_game.keeper_may_release(p):
		return false
	_connect(p, move, aim if aim.length_squared() > 0.01 else Vector2(p.team.side, 0.0))
	return true


func _connect(p: Footballer, move: Dictionary, aim: Vector2) -> void:
	var target := p.position + upfield(p, aim) * REACH
	var speed := PUNT_SPEED
	var up := PUNT_LIFT
	var kind := "clear"
	match move.id:
		"bulldozer":
			p.velocity = upfield(p, aim) * CHARGE_SPEED
			_charging[p] = []
			speed = CLEAR_SPEED
			up = CLEAR_LIFT
		"laser":
			var mate := AI.best_pass(p, match_game, aim)
			target = mate.position + mate.velocity * 0.3 if mate else p.position + aim.normalized() * REACH
			speed = LASER_SPEED
			up = 0.0
			kind = "pass"
	var played: bool = await p.move_kick(move.anim, move.contact, target, speed, up, kind)
	_charging.erase(p)
	if not played:
		return  # lost it in the wind-up
	p.team.energy = maxf(0.0, p.team.energy - move.cost)
	match_game.flash(move.title, 1.2)
	match_game.event.emit(move.id, p.team)
	if move.id != "laser":
		match_game.stadium.shake = maxf(match_game.stadium.shake, 0.25)


## `aim`, but never back toward his own goal: clearances and punts go upfield.
static func upfield(p: Footballer, aim: Vector2) -> Vector2:
	var a := aim.normalized()
	return Vector2(maxf(a.x * p.team.side, 0.5) * p.team.side, a.y).normalized()


## Each physics tick: a charging Bulldozer flattens the opponents he runs into (once each).
## A dodge hops over him. The referee judges it like any Chaos rough stuff.
func tick() -> void:
	for p: Footballer in _charging.keys():
		var flattened: Array = _charging[p]
		for o in match_game.opponent(p.team).players:
			if o.sent_off or o in flattened or o.dodging() or o.position.distance_to(p.position) > CHARGE_REACH:
				continue
			flattened.append(o)
			o.touch_cooldown = maxf(o.touch_cooldown, 0.8)
			match_game.knock_down(o, "fall")
			match_game.offence(p, o.position, "chaos")
			match_game.stadium.shake = maxf(match_game.stadium.shake, 0.2)
