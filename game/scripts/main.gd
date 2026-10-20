class_name Match
extends Node2D
## Player 1's club (home) vs the AI's or player 2's (away), 11 a side: rules, possession,
## control switching, fouls, penalties, goals and kick-offs.

signal event(kind: String, team: Team)  # goal, save, foul, penalty, or a super's name

enum State { KICKOFF, PLAY, GOAL, PENALTY, RESTART, HALF_TIME, FULL_TIME }

const GOAL_HALF_WIDTH := 7.32 / 2.0 * Pitch.PX_PER_M
const CROSSBAR := 2.44 * Pitch.PX_PER_M
const KEEPER_REACH := 24.0
const DIVE_REACH := 34.0
const PENALTY_SPOT := 11.0 * Pitch.PX_PER_M
const BOX_DEPTH := 16.5 * Pitch.PX_PER_M
const BOX_HALF_WIDTH := 40.32 / 2.0 * Pitch.PX_PER_M
const STEAL_RATE := 2.0  # chance per second of winning the ball when touching it
const AIR_SHOT_RANGE := 20.0 * Pitch.PX_PER_M  # headers and volleys go at goal from closer than this
const CLEAR_RANGE := 30.0 * Pitch.PX_PER_M  # and are cleared away this close to your own goal
const POST_HIT := 3.0  # pitch pixels from a post or the bar (ball plus post radius) that hit it
const AIR_REQUEST := 0.4  # seconds a header / volley button press waits for the ball
const DODGE_GAIN := 10.0  # energy for hopping over a slide (Chaos)
const BODY_CHECK_COST := 20.0
const KNOCK_FATIGUE := 0.1  # going down takes it out of you
const DIZZY_AT := 0.6  # Chaos: knocked down this tired, he sees stars
const DIZZY_TIME := 2.5
const FREE_KICK_RANGE := 30.0 * Pitch.PX_PER_M  # closer than this a free kick is a shot
const FOUL_MISS := 0.4  # a slide that misses the ball takes the man this often
# chance of a yellow and of a straight red for a foul, before aggression (0.7 → 1.3x)
const CARD_ODDS := {"behind": [0.45, 0.1], "front": [0.12, 0.0]}
const OFF_PITCH := Vector2(-500.0, -500.0)  # where a sent-off player waits out the match
const SKILL_GAIN := 10.0  # energy for beating an opponent with a nutmeg or rainbow
const NUTMEG_RANGE := 45.0  # an opponent this close in front can be nutmegged  # Chaos special: energy for a shoulder barge
const CELEBRATIONS := ["aeropla", "celdnce", "celdnc2", "celdpnc", "vctflip", "victrun", "duckflp"]
const SQUADS := "res://data/squads.json"
const PORTRAITS := "res://assets/portraits/"
const CLUBS := "res://assets/clubs/"  # crests <SHORT>.png and boards <SHORT>_board.png
## Sound effects from SFX_GAME.BNK, identified by their spectra (ASSUMED: not confirmed
## by ear): short low thuds are ball contacts, ~3.8 kHz tones the referee's whistle.
const SFX := {
	"kick": "slot002", "pass": "slot012", "bounce": "slot001",
	"whistle": "slot030", "long_whistle": "slot029", "roar": "slot021", "ooh": "slot005",
}
const HALF_SECONDS := 180.0  # real seconds per half; the match clock shows 45 minutes (ASSUMED default length)
const THUNDER_HOLD := 0.8  # seconds to hold shoot for a Thunder Strike (needs a full bar)

## Chaos Football: energy bars and super-shots. Classic Football: plain FIFA 96 rules,
## same players, ball and AI. Chosen on the title screen; kept between matches.
static var chaos := true
static var players := 1  # people playing: 1 (vs the AI) or 2 (home vs away); title screen
static var home_club := "Club Brugge"  # player 1's club (data/league.json); team select screen
static var away_club := "Anderlecht"  # the AI's or player 2's club

var ball: Ball
var home: Team
var away: Team
var humans: Array[Human] = []  # player 1 (home), player 2 (away) when two play
var referee: Footballer  # follows play, points to free kicks and shows the cards; nobody's team
var state := State.KICKOFF
var clock := 0.0  # seconds of play (stopped during goals, restarts, breaks)
var half := 1
var autoplay := false  # AI plays both sides (demo / attract mode)

var _state_left := 0.0
var _conceded: Team  # kicks off after the goal (an own goal too)
var _penalty_taker: Footballer
var _restart_kind := ""  # "throw-in", "corner" or "goal kick" while state is RESTART
var _restart_taker: Footballer
var _restart_taken := false  # the taker has started the throw / kick; play on once it's left them
var _offside: Array[Footballer] = []  # in an offside position when the last kick was played
var _banner_left := 0.0
var stadium := Stadium.new()
var _crowd := AudioStreamPlayer.new()
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _score_label := Label.new()  # "BRU  0 - 0  AND", between the two crests
var _clock_label := Label.new()
var _banner := Label.new()
var _player_labels: Array[Label] = []  # each human's controlled player's name, as in FIFA 96
var _player_portraits: Array[TextureRect] = []  # and their pixel portrait above it
var _energy_bars := {}  # Team -> ColorRect fill
var _energy_labels := {}  # Team -> Label
var _aim_arrows := Node2D.new()  # each human's shot arrow on the grass (see aim_arrow)


func _ready() -> void:
	_bind_inputs()
	Human.bind_inputs(players)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var world := Node2D.new()  # simulation in pitch pixels; visuals are placed through the stadium camera
	add_child(world)

	ball = Ball.new()
	ball.bounds = Pitch.field_rect().grow(Pitch.m(Pitch.MARGIN_M) - 4.0)
	world.add_child(ball)

	home = Team.from_league(home_club)
	away = Team.from_league(away_club)
	if away.clashes_with(home):
		away.wear_change_kit(home)
	home.side = 1
	away.side = -1
	humans.append(Human.new(home, 0))
	if players == 2:
		humans.append(Human.new(away, 1))
	for t in [home, away]:
		var board := CLUBS + "%s_board.png" % t.short
		if ResourceLoader.exists(board):
			stadium.club_boards.append(load(board))
	add_child(stadium)
	var squads := _load_squads()
	for t in [home, away]:
		var names: Array = squads.get(t.name, [])
		for i in Team.FORMATION.size():
			var p := Footballer.new()
			p.team = t
			p.role = Team.FORMATION[i][0]
			p.home = Team.FORMATION[i][1]
			p.ball = ball
			p.opponents = away if t == home else home
			p.number = names[i].number if i < names.size() else i + 1
			p.name = "%s %d" % [t.short, p.number]
			p.display_name = names[i].name if i < names.size() else p.name
			if i < names.size():
				p.stats = names[i].get("stats", {})
				if names[i].has("skin"):
					p.skin = Color(names[i].skin)
					p.hair = Color(names[i].hair)
				p.portrait = _portrait(names[i])
			p.speed_factor = 1.0 if human_for(t) else 0.94
			t.players.append(p)
			world.add_child(p)

	var black := Color("141414")
	var kit := {"shirt": black, "shirt2": black, "shorts": black, "socks": black, "boots": black}
	referee = Footballer.new()
	referee.team = Team.new("Referee", "REF", kit, kit)
	referee.ball = ball
	referee.name = "Referee"
	referee.speed_factor = 0.9
	world.add_child(referee)

	_start_crowd()
	for i in 6:
		_sfx_players.append(AudioStreamPlayer.new())
		add_child(_sfx_players[i])
	ball.kicked.connect(func(speed): play_sfx("kick" if speed > 400.0 else "pass", linear_to_db(clampf(speed / 600.0, 0.3, 1.0))))
	ball.kicked.connect(func(_speed): _note_offside())
	ball.bounced.connect(func(speed): play_sfx("bounce", linear_to_db(clampf(speed / 300.0, 0.15, 0.7))))
	_add_hud()
	_aim_arrows.top_level = true
	_aim_arrows.z_index = -3000  # on the grass, under every player
	_aim_arrows.draw.connect(_draw_aim_arrows)
	add_child(_aim_arrows)
	add_child(DebugOverlay.new(self))
	kickoff(away)
	stadium.follow(ball.position, 0.0)


## A gamepad was plugged in or out: hand the pads out again.
func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	Human.bind_inputs(players)


func opponent(t: Team) -> Team:
	return away if t == home else home


## The player of `t` that should go for the ball (nearest outfield player to where it can be won).
func chaser(t: Team) -> Footballer:
	var at := ball_target()
	var best: Footballer = null
	for p in t.players:
		if p.role != "G" and not p.sent_off and (best == null or p.position.distance_squared_to(at) < best.position.distance_squared_to(at)):
			best = p
	return best


## Where to run to win the ball: a ball in the air where it comes down to head height.
func ball_target() -> Vector2:
	return ball.coming_down(Footballer.HEAD_TOP)


func nearest_opponent_distance(p: Footballer) -> float:
	var d := INF
	for o in opponent(p.team).players:
		d = minf(d, o.position.distance_to(p.position))
	return d


func kickoff(kicking: Team) -> void:
	state = State.KICKOFF
	_state_left = 1.2
	var centre := Pitch.field_rect().get_center()
	ball.stop_at(centre)
	referee.position = centre + Vector2(0.0, -Pitch.m(12.0))
	for t in [home, away]:
		for p in t.players:
			if p.sent_off:
				continue
			var spot: Vector2 = p.home
			spot.x = minf(spot.x * 0.9, 0.45)
			p.position = t.to_pitch(spot)
			p.velocity = Vector2.ZERO
			p.wish = Vector2.ZERO
			p.facing = 2 if t.side > 0 else 6
	var taker: Footballer = kicking.taker()
	taker.position = centre - Vector2(kicking.side * 12.0, 0)
	ball.take(taker)
	_banner.text = ""


## Leaving mid slow-mo (F1, Esc) mustn't leave the game running at Thunder Strike speed.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	_update_hud()
	_referee_follows()
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.text = ""
	match state:
		State.KICKOFF:
			_state_left -= delta
			if _state_left <= 0.0:
				state = State.PLAY
				play_sfx("whistle")
		State.GOAL:
			_state_left -= delta
			for t in [home, away]:
				for p in t.players:
					if not p.busy():
						p.wish = Vector2.ZERO
			if _state_left <= 0.0:
				kickoff(_conceded)
		State.PENALTY:
			_penalty(delta)
		State.RESTART:
			_restart(delta)
		State.HALF_TIME:
			_state_left -= delta
			if _state_left <= 0.0:
				half = 2
				for t in [home, away]:
					t.side = -t.side  # change ends
				kickoff(home)  # the away side kicked off the first half
		State.FULL_TIME:
			for t in [home, away]:
				for p in t.players:
					if not p.busy():
						p.wish = Vector2.ZERO
		State.PLAY:
			clock += delta
			if clock >= HALF_SECONDS * half:
				_end_half()
				return
			if not autoplay:
				_switch_control()
			for t in [home, away]:
				var h := human_for(t)
				for p in t.players:
					if h and p == h.controlled:
						_human_input(h, p)
					else:
						AI.think(p, self, delta)
			_clear_keepers_box()
			_resolve_possession(delta)
			if ball.holder and ball.holder.role != "G":
				ball.holder.team.gain(Supers.GAIN.dribble * delta)
			_check_frame()
			_check_goal()
			_check_out()


func _process(delta: float) -> void:
	var focus := ball.position
	if humans.size() == 1 and humans[0].controlled:  # two players: just follow the ball
		focus = focus.lerp(humans[0].controlled.position, 0.25)
	stadium.follow(focus, delta)
	for t in [home, away]:
		for p in t.players:
			p.place(stadium.to_screen(p.position))
	referee.place(stadium.to_screen(referee.position))
	ball.place(stadium.to_screen)
	_aim_arrows.queue_redraw()
	_update_energy_hud()


## The human (player 1 or 2) playing `t`, or null for an AI side.
func human_for(t: Team) -> Human:
	for h in humans:
		if h.team == t:
			return h
	return null


func _switch_control() -> void:
	for h in humans:
		var current := h.controlled
		var best: Footballer
		h.switch_lock = maxf(0.0, h.switch_lock - get_physics_process_delta_time())
		if ball.holder and ball.holder.team == h.team:
			best = ball.holder
		elif Input.is_action_just_pressed(h.action("switch")):  # manual: the next-nearest teammate to the ball
			for p in h.team.players:
				if p != current and p.role != "G" and (best == null
						or p.position.distance_to(ball.position) < best.position.distance_to(ball.position)):
					best = p
			h.switch_lock = 1.0
		elif h.switch_lock > 0.0:
			best = current
		else:
			best = chaser(h.team)
			if current and current.role != "G" and not ball.holder == current \
					and current.position.distance_to(ball.position) < best.position.distance_to(ball.position) + 30.0:
				best = current
		if best != current:
			if current:
				current.controlled = false
			h.controlled = best
			best.controlled = true
			best.marker = h.marker()


## Shoot fires on release: tap = normal shot, hold = more power, hold THUNDER_HOLD with
## a full bar = Thunder Strike. A combo entered just before pressing (see ComboInput)
## turns the shot into that super if the bar allows.
func _human_input(h: Human, p: Footballer) -> void:
	p.wish = h.stick()
	var now := clock
	h.combo.feed(ComboInput.direction(p.wish, p.team.side), now)
	var aim: Vector2 = Anims.FACING_VECTORS[p.facing] if p.wish == Vector2.ZERO else p.wish.normalized()
	_mark_pass_target(h, AI.best_pass(p, self, aim) if p.has_ball() else null)
	if h.charging and not p.has_ball():
		h.charging = false
		p.charge = 0.0
	h.air_request_left = maxf(0.0, h.air_request_left - get_physics_process_delta_time())
	if not p.has_ball() and _ball_coming_in_air(p):
		for action in ["shoot", "pass"]:  # a header / volley: at goal, or to a teammate
			if Input.is_action_just_pressed(h.action(action)):
				h.air_request = action
				h.air_request_left = AIR_REQUEST
	if p.has_ball() and Input.is_action_just_pressed(h.action("switch")):  # with the ball: a skill move or a dodge
		var move := h.combo.skill_move(now)
		if move == "" or not skill_move(p, move):
			p.dodge()
		h.combo.clear()
	if Input.is_action_just_pressed(h.action("shoot")):
		if p.has_ball():
			h.charging = true
			h.charge_time = 0.0
			h.pending_combo = h.combo.detect(now)
		elif h.air_request_left <= 0.0 and not (h.combo.double_tap(now) and body_check(p)):
			p.slide()
	elif h.charging:
		h.charge_time += get_physics_process_delta_time()
		var full := p.team.energy >= Supers.cost("thunder")
		p.charge = minf(h.charge_time / THUNDER_HOLD, 1.0) if full else minf(h.charge_time / 0.6, 0.99)
		if not Input.is_action_pressed(h.action("shoot")) or h.charge_time > 1.5:
			h.charging = false
			p.charge = 0.0
			var target := _aim_shot(p, aim)
			var fired := h.charge_time >= THUNDER_HOLD and try_super(p, "thunder", _aim_shot(p, (p.team.goal_attacked() - p.position).normalized()))
			if not fired and h.pending_combo != "":
				fired = try_super(p, h.pending_combo, target)
			if not fired:
				p.shoot(target, clampf(h.charge_time / 0.6, 0.0, 1.0))
			h.combo.clear()
	elif Input.is_action_just_pressed(h.action("pass")) and p.has_ball():
		var mate := AI.best_pass(p, self, aim)
		if mate == null and p.role == "G":  # a keeper never plays it blind: best mate anywhere, else a punt upfield
			mate = AI.best_pass(p, self, Vector2.ZERO)
			aim = Vector2(p.team.side, 0.0)
		if mate and is_cross(p, mate):
			p.cross_to(mate)
		elif mate:
			p.pass_to(mate)
		elif p.role == "G":
			p.kick_to(p.position + aim * 450.0, 520.0, 300.0, "kick")
		else:
			p.kick_to(p.position + aim * 250.0, 380.0, 20.0, "kick")


## The shot arrow for `h`'s player while he has the ball: from him toward where a shot
## would go, 50 px long untouched, up to 170 px at full power as shoot is held; ring
## colour turning orange with power, the Thunder Strike colour once one is ready.
## Empty when there's nothing to show.
func aim_arrow(h: Human) -> Dictionary:
	var p := h.controlled
	if autoplay or state != State.PLAY or p == null or not p.has_ball():
		return {}
	var aim: Vector2 = Anims.FACING_VECTORS[p.facing] if p.wish == Vector2.ZERO else p.wish.normalized()
	var colour := h.marker().lerp(Color(1.0, 0.35, 0.1), p.charge)
	if p.charge >= 1.0:
		colour = Supers.LIST.thunder.colour
	return {"from": p.position, "dir": (_aim_shot(p, aim) - p.position).normalized(),
		"length": lerpf(50.0, 170.0, p.charge), "width": lerpf(4.5, 8.0, p.charge), "colour": colour}


## Drawn on the pitch plane: the arrow's outline in pitch pixels, each corner projected.
func _draw_aim_arrows() -> void:
	for h in humans:
		var a := aim_arrow(h)
		if a.is_empty():
			continue
		var d: Vector2 = a.dir
		var side: Vector2 = d.orthogonal() * a.width
		var from: Vector2 = a.from + d * 14.0  # clear of his feet
		var tip: Vector2 = from + d * a.length
		var neck := tip - d * 16.0
		var screen := PackedVector2Array()
		for q in [from + side, neck + side, neck + side * 2.6, tip, neck - side * 2.6, neck - side, from - side]:
			var at := stadium.to_screen(q)
			screen.append(Vector2(at.x, at.y))
		_aim_arrows.draw_colored_polygon(screen, Color(a.colour, 0.75))


func _mark_pass_target(h: Human, target: Footballer) -> void:
	if h.pass_target == target:
		return
	if h.pass_target:
		h.pass_target.pass_marker = Color.TRANSPARENT
	h.pass_target = target
	if target:
		target.pass_marker = h.marker()


## Spend energy on a super-shot by `p`. False (and nothing happens) if the bar is too low.
## The bar is spent, and the fanfare plays, only once his foot meets the ball.
func try_super(p: Footballer, kind: String, target: Vector2) -> bool:
	if not chaos or p.team.energy < Supers.cost(kind) or not p.has_ball() or p.busy():
		return false
	_super_connects(p, kind, target)
	return true


func _super_connects(p: Footballer, kind: String, target: Vector2) -> void:
	if not await p.super_shot(kind, target):
		return  # lost it in the wind-up
	p.team.energy = maxf(0.0, p.team.energy - Supers.cost(kind))
	flash(Supers.LIST[kind].title, 1.6)
	event.emit(kind, p.team)
	stadium.shake = 0.25
	if kind == "thunder":
		Engine.time_scale = 0.3
		stadium.shake = 0.8
		get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## Aim assist: when roughly facing the goal, shoot at it, biased to the side you lean.
func _aim_shot(p: Footballer, aim: Vector2) -> Vector2:
	var goal := p.team.goal_attacked()
	var to_goal := (goal - p.position).normalized()
	if aim.dot(to_goal) > 0.3 and p.position.distance_to(goal) < 700.0:
		return goal + Vector2(0, aim.y * GOAL_HALF_WIDTH * 0.7)
	return p.position + aim * 500.0


func _resolve_possession(delta: float) -> void:
	if ball.holder == null and Supers.unstoppable(ball.power):
		_plough_through()
		return
	if ball.holder == null:
		if ball.z > CROSSBAR * 1.2:
			return
		var best: Footballer = null
		var best_d := INF
		var best_in_air := false  # best meets it with his head, foot or chest, rather than taking it
		for t in [home, away]:
			for p in t.players:
				if p.touch_cooldown > 0.0 or (p.busy() and not p.sliding() and not p.diving()):
					continue
				var keeper: bool = p.role == "G" and p.position.distance_to(t.goal_defended()) < 200.0
				var reach := keeper_reach(p) if keeper else Footballer.REACH
				if not keeper and ball.kick_kind in ["pass", "cross"] and ball.last_touch and ball.last_touch.team != t:
					reach *= p.skill("interceptions", 0.8, 1.6)  # cutting out the other side's pass
				var in_air := not keeper and ball.z > 12.0
				if in_air and (ball.z > p.head_reach() or p.busy() or (ball.kick_kind == "rainbow" and ball.vz > 0.0)):
					continue
				var d := minf(p.feet_front().distance_to(ball.position), p.position.distance_to(ball.position))
				if d >= reach:
					continue
				if d < best_d:
					best = p
					best_d = d
					best_in_air = in_air
		if best and best_in_air:
			var winner := _air_duel(best)
			if not _caught_offside(winner):
				_air_touch(winner)
		elif best:
			_take(best)
		return
	var holder := ball.holder
	if holder.role == "G":
		return
	for o in opponent(holder.team).players:
		if o.body_checking() and o.touch_cooldown <= 0.0 and o.position.distance_to(holder.position) < Footballer.REACH + 8.0:
			_body_check_hits(o, holder)
			return
		if o.feet_front().distance_to(ball.position) > Footballer.REACH + 2.0 or o.touch_cooldown > 0.0:
			continue
		if o.sliding() and not holder.dodging() and not _human_controls(holder) \
				and randf() < holder.skill("reactions", 0.1, 0.45):
			holder.dodge()  # the AI sees it coming (one chance per slide: it's spent below either way)
		if holder.dodging():
			if o.sliding():
				o.touch_cooldown = 0.6  # the slide goes under him
				if chaos:
					flash("DODGE!", 0.8)
					holder.team.gain(DODGE_GAIN)
				event.emit("dodge", holder.team)
			continue
		var from_behind: bool = Anims.FACING_VECTORS[o.facing].dot(Anims.FACING_VECTORS[holder.facing]) > 0.5
		if o.sliding() and from_behind:
			_foul(o, holder)
			return
		if o.sliding() and randf() > o.skill("slidingTackle", 0.55, 1.0):
			o.touch_cooldown = 0.6  # missed: one try per slide
			if randf() < FOUL_MISS:  # took the man instead
				_foul(o, holder, false)
				return
			continue
		if o.sliding() or randf() < steal_rate(o, holder) * delta:
			ball.release()
			ball.last_touch = o  # his touch: if it runs out, it's the other side's ball
			ball.kick(Anims.FACING_VECTORS[o.facing] * 90.0, 0.0)
			ball.kick_kind = ""  # a tackle, not a pass: nobody's offside for it
			holder.touch_cooldown = 0.6
			o.team.gain(Supers.GAIN.tackle)
			if o.sliding() and randf() >= holder.skill("balance", 0.0, 0.5):  # good balance: stays up
				knock_down(holder, "fall")
			return


## A skill move by `p` with the ball (see Footballer.skill_touch). The nutmeg slips it
## through the legs of the opponent in front and on 5 m (dribbling against his
## defensiveAwareness; when it fails he has it). The rainbow flicks it over everyone's head
## to land 5 m on (ballControl, or it drops short). The backheel plays it to a teammate
## behind. In Chaos, beating an opponent with one flashes and earns energy.
func skill_move(p: Footballer, kind: String) -> bool:
	if not p.has_ball() or p.busy():
		return false
	var ahead: Vector2 = Anims.FACING_VECTORS[p.facing]
	var o := opponent_ahead(p)
	var beaten: Footballer = null
	var v := ahead * 200.0
	var up := 0.0
	var touch := "dribble"
	match kind:
		"nutmeg":
			if o and randf() < nutmeg_odds(p, o):
				beaten = o
		"rainbow":
			if randf() < p.skill("ballControl", 0.5, 1.0):
				v = ahead * 120.0
				up = 370.0  # up to 76 px: nobody touches it going up
				touch = "rainbow"
				beaten = o
			else:  # scuffed: drops at his feet
				v = ahead * 60.0
				up = 150.0
		"bckheel":
			var mate := AI.best_pass(p, self, -ahead)
			var to := mate.position + mate.velocity * 0.4 if mate else p.position - ahead * 80.0
			var err := p.skill("shortPassing", 40.0, 4.0) * p.pressure_factor()
			to += Vector2(randf_range(-err, err), randf_range(-err, err))
			v = (to - p.position).normalized() * clampf(p.position.distance_to(to) * 1.6, 180.0, 420.0)
			up = 20.0
			touch = "pass"
	if beaten:
		beaten.touch_cooldown = Footballer.SKILL_MOVES[kind][0] + 0.8  # left standing, from now: the wind-up is safe from him
	_skill_connects(p, kind, v, up, touch, beaten)
	return true


## The skill move's event, and the Chaos fanfare for beating a man, once the touch is made.
func _skill_connects(p: Footballer, kind: String, v: Vector2, up: float, touch: String, beaten: Footballer) -> void:
	if not await p.skill_touch(kind, v, up, touch):
		return  # lost it in the wind-up
	event.emit(kind, p.team)
	if beaten and chaos:
		flash("NUTMEG!" if kind == "nutmeg" else "RAINBOW!", 0.8)
		p.team.gain(SKILL_GAIN)


## Chance a nutmeg by `p` gets through `o`'s legs: even between equals.
func nutmeg_odds(p: Footballer, o: Footballer) -> float:
	return clampf(0.5 * p.skill("dribbling", 0.6, 1.4) / o.skill("defensiveAwareness", 0.6, 1.4), 0.1, 0.9)


## The nearest opponent right in front of `p` (within NUTMEG_RANGE, 45 degrees either side
## of where he faces), or null.
func opponent_ahead(p: Footballer) -> Footballer:
	var best: Footballer = null
	for o in opponent(p.team).players:
		var off := o.position - p.position
		if off.length() < NUTMEG_RANGE and off.normalized().dot(Anims.FACING_VECTORS[p.facing]) > 0.7 \
				and (best == null or off.length() < best.position.distance_to(p.position)):
			best = o
	return best


## Chaos special: a shoulder barge (a dash, then shoot, without the ball). Costs energy.
func body_check(p: Footballer) -> bool:
	if not chaos or p.has_ball() or p.team.energy < BODY_CHECK_COST or not p.body_check():
		return false
	p.team.energy -= BODY_CHECK_COST
	event.emit("body check", p.team)
	return true


## A body check reaches the dribbler: strength against strength (and his balance) decides
## who goes down. One try per barge. A dodge beats it.
func _body_check_hits(o: Footballer, holder: Footballer) -> void:
	o.touch_cooldown = 1.0
	if holder.dodging():
		return
	stadium.shake = maxf(stadium.shake, 0.2)
	if randf() < body_check_odds(o, holder):
		ball.release()
		ball.kick(Anims.FACING_VECTORS[o.facing] * 120.0, 0.0)
		ball.last_touch = o
		holder.touch_cooldown = 0.8
		o.touch_cooldown = 0.3  # he can run onto it
		flash("BODY CHECK!", 1.0)
		knock_down(holder, "stumble")
		event.emit("body check won", o.team)
	else:
		knock_down(o, "stumble")  # bounced off him
		o.velocity = Vector2.ZERO


## `p` goes down (`anim`): it tires him, and in Chaos a tired player gets up dizzy.
func knock_down(p: Footballer, anim: String) -> void:
	p.perform(anim)
	p.fatigue = minf(1.0, p.fatigue + KNOCK_FATIGUE)
	if chaos and p.fatigue >= DIZZY_AT and p.dizzy_left <= 0.0:
		p.dizzy_left = DIZZY_TIME
		flash("DIZZY!", 1.0)
		event.emit("dizzy", p.team)


## Chance a body check by `o` knocks `holder` off the ball: even between equals.
func body_check_odds(o: Footballer, holder: Footballer) -> float:
	return clampf(0.5 * o.skill("strength", 0.6, 1.4) / holder.skill("strength", 0.6, 1.4) / holder.skill("balance", 0.9, 1.1), 0.1, 0.9)


func _human_controls(p: Footballer) -> bool:
	var h := human_for(p.team) if not autoplay else null
	return h != null and h.controlled == p


## A human's player with a ball in the air coming his way (pressing shoot then heads or
## volleys it instead of sliding).
func _ball_coming_in_air(p: Footballer) -> bool:
	return ball.holder == null and (ball.z > 12.0 or ball.vz > 0.0) and ball_target().distance_to(p.position) < 90.0


## An outfield player meets a ball in the air: at goal near the opponents' goal, cleared
## near his own, headed on to a teammate in between, or chested down when it's low. A
## human's shoot / pass press (just before) chooses: at goal, or to a teammate.
func _air_touch(p: Footballer) -> void:
	var goal := p.team.goal_attacked()
	var high := ball.z > Footballer.CHEST_HEIGHT
	var h := human_for(p.team) if not autoplay else null
	var aim := Vector2.ZERO
	var choice := "control"
	if h and h.controlled == p and h.air_request_left > 0.0:
		choice = h.air_request
		h.air_request_left = 0.0
		aim = h.stick().normalized()
	elif p.position.distance_to(goal) < AIR_SHOT_RANGE:
		choice = "shoot"
	elif p.position.distance_to(p.team.goal_defended()) < CLEAR_RANGE:
		choice = "clear"
	elif high:
		choice = "pass"
	var anim := "header" if high else "vollkck"
	match choice:
		"shoot":
			var stat := "headingAccuracy" if high else "volleys"
			var target := _aim_shot(p, aim) if aim != Vector2.ZERO else goal + Vector2(0, randf_range(-0.6, 0.6) * GOAL_HALF_WIDTH)
			var miss := p.skill(stat, 50.0, 8.0)
			target += Vector2(0.0, randf_range(-miss, miss))
			if not high and randf() < 0.3:
				anim = "divehed"  # a diving header to a low cross
			var speed := 420.0 if anim != "vollkck" else 600.0 * p.skill("shotPower", 0.88, 1.12)
			p.air_touch(anim, (target - ball.position).normalized() * speed, -40.0 if anim != "vollkck" else 40.0, "shot")
			event.emit("volley" if anim == "vollkck" else "header", p.team)
		"clear":  # upfield and out toward the nearer touchline
			var wing := signf(ball.position.y - Pitch.field_rect().size.y / 2.0)
			p.air_touch(anim, Vector2(p.team.side, 0.6 * wing).normalized() * 420.0, 220.0, "pass")
			event.emit("clearance", p.team)
		"pass":
			var mate := AI.best_pass(p, self, aim)
			var to := mate.position if mate else p.position + Vector2(p.team.side * 200.0, 0.0)
			p.air_touch("header", (to - ball.position).normalized() * clampf(ball.position.distance_to(to) * 1.4, 200.0, 380.0), 120.0, "pass")
			event.emit("header", p.team)
		_:
			p.air_touch("chest")
			_take(p)


## `p` is about to meet a ball in the air: a stronger opponent close enough to go up with
## him (10 px beyond reach, the ball within his reach) wins it instead.
func _air_duel(p: Footballer) -> Footballer:
	var winner := p
	for o in opponent(p.team).players:
		if o.role == "G" or o.busy() or o.touch_cooldown > 0.0 or ball.z > o.head_reach():
			continue
		if o.position.distance_to(ball.position) < Footballer.REACH + 10.0 \
				and o.skill("strength", 0.0, 1.0) > winner.skill("strength", 0.0, 1.0):
			winner = o
	return winner


## Out wide within `metres` of the goal line `p` attacks.
func wide_within(p: Footballer, metres: float) -> bool:
	return p != null and absf(p.position.y - Pitch.field_rect().size.y / 2.0) > BOX_HALF_WIDTH * 0.7 \
		and absf(p.team.goal_attacked().x - p.position.x) < Pitch.m(metres)


## Out wide in the last third: a pass from here to a teammate in the box is a cross.
func wide_in_final_third(p: Footballer) -> bool:
	return wide_within(p, Pitch.LENGTH_M / 3.0)


## A pass from `p` to `mate` that's a cross: from out wide in the last third to a teammate
## in the box, or running into it (where he'll be when the ball comes down).
func is_cross(p: Footballer, mate: Footballer) -> bool:
	return wide_in_final_third(p) and in_penalty_area(mate.position + mate.velocity * 0.8, opponent(p.team))


## Keeper's reach for a ball: reflexes standing, diving in a dive.
func keeper_reach(k: Footballer) -> float:
	return DIVE_REACH * k.skill("gkDiving", 0.8, 1.2) if k.diving() else KEEPER_REACH * k.skill("gkReflexes", 0.8, 1.2)


## Chance per second that `tackler`, touching the ball, takes it off `holder`.
func steal_rate(tackler: Footballer, holder: Footballer) -> float:
	return STEAL_RATE * tackler.skill("standingTackle", 0.5, 1.5) / holder.skill("ballControl", 0.6, 1.4) \
		* tackler.skill("strength", 0.8, 1.2) / holder.skill("strength", 0.8, 1.2)


## A keeper with the ball in his hands can't be challenged: opponents (AI or human)
## walk out of his penalty area until he has played it.
func _clear_keepers_box() -> void:
	var k := ball.holder
	if k == null or k.role != "G" or not in_penalty_area(k.position, k.team):
		return
	for p in opponent(k.team).players:
		if in_penalty_area(p.position, k.team) and not p.busy():
			p.wish = Vector2(k.team.side, 0.0)  # away from the keeper's goal


## Fireball / Thunder: anyone in the way is knocked flat. A keeper can sometimes
## smother a fireball; nobody holds a Thunder Strike.
func _plough_through() -> void:
	for t in [home, away]:
		for p in t.players:
			if p == ball.last_touch or p.touch_cooldown > 0.0:
				continue
			var reach := KEEPER_REACH if p.role == "G" else Footballer.REACH + 4.0
			if p.position.distance_to(ball.position) > reach:
				continue
			if p.role == "G" and ball.power == "fireball" and randf() < 0.3:
				_take(p)
				return
			knock_down(p, "fall")
			p.touch_cooldown = 1.0
			p.velocity = ball.velocity.normalized() * 120.0
			ball.velocity *= 0.92
			stadium.shake = maxf(stadium.shake, 0.2)


func _take(p: Footballer) -> void:
	if _caught_offside(p):
		return
	_offside.clear()
	var fast := ball.velocity.length() > 250.0
	var shot_on_goal := ball.last_touch != null and ball.last_touch.team != p.team
	if ball.kick_kind in ["pass", "cross"] and ball.last_touch and ball.last_touch != p and ball.last_touch.team == p.team:
		p.team.gain(Supers.GAIN.pass)
	ball.kick_kind = ""
	ball.take(p)
	if p.role == "G" and fast:
		if not p.diving():
			p.perform("gjmctch" if ball.z > 30.0 else "gmdctch" if ball.z > 12.0 else "glwctch")
		p.think_timer = 0.0
		if shot_on_goal:
			flash("SAVE!", 1.2)
			event.emit("save", p.team)
			play_sfx("ooh", -4.0)
			p.team.gain(Supers.GAIN.save)


## Slide tackle that took the player, not the ball: a free kick where it happened (a penalty
## in the box), and maybe a card, likelier from behind and from an aggressive player.
func _foul(by: Footballer, victim: Footballer, from_behind := true) -> void:
	knock_down(victim, "fall")
	victim.touch_cooldown = 0.0
	by.touch_cooldown = 1.0  # one foul per slide: the slider is still on the ball for a moment
	victim.team.gain(Supers.GAIN.fouled)
	event.emit("foul", by.team)
	if in_penalty_area(victim.position, by.team):
		award_penalty(victim.team)
	else:
		_award_restart("free kick", victim.team, victim.position.clamp(Vector2.ZERO, Pitch.field_rect().size))
	var odds: Array = CARD_ODDS["behind" if from_behind else "front"]
	var r := randf() / by.skill("aggression", 0.7, 1.3)
	if r < odds[1]:
		book(by, true)
	elif r < odds[0] + odds[1]:
		book(by, false)


## The referee shows `p` a card. A second yellow is a red: off he goes, for the rest of the
## match (parked off the pitch, out of play).
func book(p: Footballer, red: bool) -> void:
	red = red or p.yellow
	p.yellow = true
	referee.facing = Anims.facing_from(p.position - referee.position)
	referee.perform("rcard")
	flash("%s CARD\n%s" % ["RED" if red else "YELLOW", p.display_name], 2.0)
	event.emit("red card" if red else "yellow card", p.team)
	if not red:
		return
	p.sent_off = true
	p.visible = false
	p.controlled = false
	p.position = OFF_PITCH
	p.velocity = Vector2.ZERO
	p.wish = Vector2.ZERO
	p.touch_cooldown = INF
	if ball.holder == p:
		ball.release()
	for h in humans:
		if h.controlled == p:
			h.controlled = null
			h.switch_lock = 0.0


## Players of `passer`'s team in an offside position as he plays it: in the opponents'
## half, nearer their goal line than the ball and than the second-last defender.
func offside_players(passer: Footballer) -> Array[Footballer]:
	var out: Array[Footballer] = []
	var goal_x := passer.team.goal_attacked().x
	var depths: Array[float] = []  # each defender's distance from his goal line
	for o in opponent(passer.team).players:
		if not o.sent_off:
			depths.append(absf(goal_x - o.position.x))
	depths.sort()
	var line: float = depths[1] if depths.size() > 1 else 0.0
	var half_way := absf(goal_x - Pitch.field_rect().get_center().x)
	var ball_depth := absf(goal_x - ball.position.x)
	for p in passer.team.players:
		var d := absf(goal_x - p.position.x)
		if p != passer and not p.sent_off and d < half_way and d < line and d < ball_depth:
			out.append(p)
	return out


## On every kick in open play: who's offside for it (see _caught_offside).
func _note_offside() -> void:
	_offside.clear()
	if state == State.PLAY and ball.last_touch:
		_offside = offside_players(ball.last_touch)


## `p` is about to play a teammate's pass or cross he was offside for: a free kick to the
## other side where he is.
func _caught_offside(p: Footballer) -> bool:
	var passer := ball.last_touch
	if not p in _offside or not ball.kick_kind in ["pass", "cross"] or passer == null or passer == p or passer.team != p.team:
		return false
	_offside.clear()
	_award_restart("free kick", opponent(p.team), p.position.clamp(Vector2.ZERO, Pitch.field_rect().size))
	flash("OFFSIDE", 1.5)
	event.emit("offside", p.team)
	return true


## Keeps 12 m from the ball, on whichever side he's on, inside the lines.
func _referee_follows() -> void:
	if referee.busy():
		return
	var away_from := referee.position - ball.position
	var target := ball.position + (away_from.normalized() if away_from.length() > 1.0 else Vector2.UP) * Pitch.m(12.0)
	target = target.clamp(Vector2.ZERO, Pitch.field_rect().size)
	referee.wish = ((target - referee.position) / 40.0).limit_length(1.0)


func in_penalty_area(pos: Vector2, defending: Team) -> bool:
	var goal := defending.goal_defended()
	return absf(pos.x - goal.x) < BOX_DEPTH and absf(pos.y - goal.y) < BOX_HALF_WIDTH


func award_penalty(attacking: Team) -> void:
	var defending := opponent(attacking)
	var goal := attacking.goal_attacked()
	var spot := goal - Vector2(attacking.side * PENALTY_SPOT, 0)
	state = State.PENALTY
	_state_left = 2.5
	ball.stop_at(spot)
	flash("PENALTY!", 2.0)
	play_sfx("long_whistle")
	event.emit("penalty", attacking)
	_penalty_taker = attacking.taker()
	var box_edge := goal.x - attacking.side * (BOX_DEPTH + 30.0)
	for t in [home, away]:
		for p in t.players:
			p.wish = Vector2.ZERO
			p.velocity = Vector2.ZERO
			if p.role == "G" and t == defending:
				p.position = goal + Vector2(attacking.side * -6.0, 0)
				p.facing = 6 if attacking.side > 0 else 2
			elif p == _penalty_taker:
				p.position = spot - Vector2(attacking.side * 45.0, 10.0)
				p.facing = Anims.facing_from(spot - p.position)
			elif in_penalty_area(p.position, defending) or absf(p.position.x - goal.x) < BOX_DEPTH + 30.0:
				p.position.x = box_edge - attacking.side * randf_range(0.0, 60.0)


func _penalty(delta: float) -> void:
	_state_left -= delta
	if _state_left > 0.0:
		return
	var taker := _penalty_taker
	var spot := ball.position
	if taker.position.distance_to(spot) > Footballer.REACH:
		taker.wish = (spot - taker.position).normalized() * 0.6
		return
	taker.wish = Vector2.ZERO
	var goal := taker.team.goal_attacked()
	var corner := -1.0 if randf() < 0.5 else 1.0
	var h := human_for(taker.team)
	if h and not autoplay:
		var lean := Input.get_axis(h.action("move_up"), h.action("move_down"))
		if lean != 0.0:
			corner = signf(lean)
	taker.shoot(goal + Vector2(0, corner * GOAL_HALF_WIDTH * 0.75), 0.5, "penalties")
	var keeper := opponent(taker.team).keeper()
	var guess := corner if randf() < 0.45 else -corner
	get_tree().create_timer(Footballer.KICK_CONTACT).timeout.connect(
		func(): keeper.dive(Vector2(0, guess), randf() < 0.5))
	state = State.PLAY


func _end_half() -> void:
	play_sfx("long_whistle")
	ball.stop_at(ball.position)
	for t in [home, away]:
		for p in t.players:
			p.wish = Vector2.ZERO
	if half == 1:
		for t in [home, away]:
			for p in t.players:
				p.fatigue *= 0.5  # the break
		state = State.HALF_TIME
		_state_left = 4.0
		flash("HALF TIME", 4.0)
		event.emit("half time", home)
	else:
		state = State.FULL_TIME
		flash("FULL TIME\n%s %d - %d %s" % [home.short, home.score, away.score, away.short], 1e9)
		event.emit("full time", home)
		var winner: Team = home if home.score > away.score else away if away.score > home.score else null
		if winner:
			for p in winner.players:
				p.perform(CELEBRATIONS[randi() % CELEBRATIONS.size()])


func flash(text: String, seconds: float) -> void:
	_banner.text = text
	_banner_left = seconds


## Ball over the touchline: throw-in. Over the goal line: corner or goal kick.
func _check_out() -> void:
	var f := Pitch.field_rect()
	if state != State.PLAY or f.has_point(ball.position) or ball.last_touch == null:
		return
	var b := ball.position
	var last := ball.last_touch.team
	if b.y < 0.0 or b.y > f.size.y:
		_award_restart("throw-in", opponent(last), Vector2(clampf(b.x, 0.0, f.size.x), clampf(b.y, 0.0, f.size.y)))
		return
	var defending := home if (b.x < 0.0) == (home.side > 0) else away  # whose goal line it is
	if last == defending:
		_award_restart("corner", opponent(defending), Vector2(clampf(b.x, 0.0, f.size.x), 0.0 if b.y < f.size.y / 2.0 else f.size.y))
	else:
		_award_restart("goal kick", defending, defending.goal_defended() + Vector2(defending.side * Pitch.m(5.5), 0.0))


func _award_restart(kind: String, team: Team, spot: Vector2) -> void:
	state = State.RESTART
	_state_left = 1.2
	_restart_kind = kind
	play_sfx("whistle")
	flash(kind.to_upper(), 1.2)
	event.emit(kind, team)
	var taker := team.keeper()
	if kind != "goal kick":
		var best_d := INF
		for p in team.players:
			if p.role != "G" and not p.sent_off and not p.busy() and p.position.distance_to(spot) < best_d:
				best_d = p.position.distance_to(spot)
				taker = p
	_restart_taker = taker
	_restart_taken = false
	taker.ai_state = "take " + kind
	# square to the line (diagonal at a corner), with the ball just inside the pitch
	var to_centre := Pitch.field_rect().get_center() - spot
	var into_pitch := Vector2(0.0, signf(to_centre.y))
	if kind in ["goal kick", "free kick"]:
		into_pitch = Vector2(team.side, 0.0)
	elif kind == "corner":
		into_pitch = Vector2(signf(to_centre.x), signf(to_centre.y)).normalized()
	spot += into_pitch * 4.0
	taker.position = spot - into_pitch * 10.0
	taker.velocity = Vector2.ZERO
	taker.wish = Vector2.ZERO
	taker.facing = Anims.facing_from(into_pitch)
	ball.stop_at(spot)
	ball.take(taker)
	ball.in_hands = kind == "throw-in"  # the throw-in animation has it in the hands
	_keep_opponents_back()
	if kind == "free kick":
		referee.facing = Anims.facing_from(Vector2(team.side, 0.0))
		referee.perform("rpoint")


## Opponents stay 9.15 m from the ball until it's taken, and out of the penalty area
## at a goal kick. Called every frame of the restart, or the AI walks them back in.
func _keep_opponents_back() -> void:
	var team := _restart_taker.team
	var spot := ball.position
	for p in opponent(team).players:
		var away_from := p.position - spot
		if away_from.length() < Pitch.m(9.15):
			var dir := away_from.normalized() if away_from.length() > 1.0 else Vector2(team.side, 0.0)
			p.position = spot + dir * Pitch.m(9.15)
		if _restart_kind == "goal kick" and in_penalty_area(p.position, team):
			p.position.x = team.goal_defended().x + team.side * (BOX_DEPTH + 1.0)


## Everyone repositions; the taker waits for the pause (and for the human's pass or
## shoot press when it's their throw), then plays the ball back in.
func _restart(delta: float) -> void:
	_state_left -= delta
	var taker := _restart_taker
	if not autoplay:
		_switch_control()
	for t in [home, away]:
		for p in t.players:
			if p != taker:
				AI.think(p, self, delta)
	_keep_opponents_back()
	taker.wish = Vector2.ZERO
	if _restart_taken:
		if ball.holder != taker:  # it's left the taker: play on, from inside the lines
			_restart_taken = false
			var f := Pitch.field_rect().grow(-2.0)
			ball.position = ball.position.clamp(f.position, f.end)
			state = State.PLAY
		elif not taker.busy():  # the throw / kick didn't happen: take it again
			_restart_taken = false
		return
	if _state_left > 0.0:
		return
	var h := human_for(taker.team)
	var aim := Vector2.ZERO
	var goal := taker.team.goal_attacked()
	var shoot := taker.position.distance_to(goal) < FREE_KICK_RANGE  # the AI's call at a free kick
	if h and not autoplay:
		aim = h.stick()
		if aim != Vector2.ZERO:
			taker.facing = Anims.facing_from(aim)
		var go := Input.is_action_just_pressed(h.action("pass")) or Input.is_action_just_pressed(h.action("shoot"))
		if go:
			shoot = Input.is_action_just_pressed(h.action("shoot"))
		elif _state_left > -6.0:
			return
	if _restart_kind == "throw-in" and aim != Vector2.ZERO:
		var into := Vector2(0.0, signf(Pitch.field_rect().get_center().y - taker.position.y))
		if aim.normalized().dot(into) < 0.3:  # a stick pointing out of play: fold it back in
			aim = (Vector2(aim.x, 0.0).normalized() + into).normalized()
	var mate := AI.best_pass(taker, self, aim.normalized())
	match _restart_kind:
		"throw-in":
			var target := mate.position + mate.velocity * 0.3 if mate else taker.position + (aim if aim != Vector2.ZERO else (goal - taker.position).normalized()) * 200.0
			taker.throw_in(target, clampf(taker.position.distance_to(target) * 1.2, 180.0, 340.0))
		"corner":  # cross into the box
			var target := goal - Vector2(taker.team.side * Pitch.m(randf_range(6.0, 12.0)), Pitch.m(randf_range(-8.0, 8.0)))
			taker.kick_to(target, taker.position.distance_to(target) * 1.3, 230.0, "kick", "pass")
		"goal kick":
			var target := mate.position if mate else taker.position + Vector2(taker.team.side * 500.0, 0.0)
			target = target if mate and mate.position.distance_to(taker.position) > 250.0 \
				else taker.position + Vector2(taker.team.side * 520.0, randf_range(-150.0, 150.0))
			taker.kick_to(target, 560.0, 230.0, "gdkick", "pass")
		"free kick":  # a shot (freeKickAccuracy) from close enough, else played on
			if shoot:
				var at := _aim_shot(taker, aim.normalized()) if aim != Vector2.ZERO else goal + Vector2(0.0, randf_range(-0.7, 0.7) * GOAL_HALF_WIDTH)
				taker.shoot(at, 0.8, "freeKickAccuracy")
			elif mate:
				taker.pass_to(mate)
			else:
				taker.kick_to(taker.position + (goal - taker.position).normalized() * 450.0, 480.0, 200.0, "kick", "pass")
	_restart_taken = true  # play on once the ball has left the taker (see above)


## Posts and crossbar: a ball that crossed a goal line this frame (between where it was and
## where it is) close to the frame hits it. Off the outside of a post or the front of the bar
## it comes back out; off the inside of a post it goes in, off the underside of the bar
## down and in half the time; off the top of the bar it loops over.
func _check_frame() -> void:
	var f := Pitch.field_rect()
	var a := ball.prev_position
	var b := ball.position
	if a.x < 0.0 or a.x > f.size.x:
		return  # already beyond the line
	for line: float in [0.0, f.size.x]:
		if (a.x - line) * (b.x - line) > 0.0 or a.x == line:
			continue  # didn't reach this line this frame
		var t: float = (line - a.x) / (b.x - a.x)
		var y := lerpf(a.y, b.y, t)
		var z := lerpf(ball.prev_z, ball.z, t)
		var off := absf(y - f.size.y / 2.0) - GOAL_HALF_WIDTH  # < 0: between the posts
		var out := -signf(b.x - a.x)  # x direction back into the field
		var hit := ""
		if absf(off) < POST_HIT and z < CROSSBAR + POST_HIT:
			hit = "POST!"
			if off >= 0.0:  # outside half: back out, pushed away from the goal
				ball.position = Vector2(line + out * POST_HIT, y)
				ball.velocity = Vector2(-ball.velocity.x * 0.6, ball.velocity.y + signf(y - f.size.y / 2.0) * absf(ball.velocity.x) * 0.3)
			else:  # inside half: in off the post
				ball.velocity.y = -signf(y - f.size.y / 2.0) * maxf(absf(ball.velocity.y), absf(ball.velocity.x) * 0.3)
		elif off < 0.0 and absf(z - CROSSBAR) < POST_HIT:
			hit = "CROSSBAR!"
			if z >= CROSSBAR:  # over the top
				ball.vz = absf(ball.vz) * 0.5 + 150.0
			elif randf() < 0.5:  # down and in
				ball.z = CROSSBAR - POST_HIT
				ball.vz = -absf(ball.vz) - 200.0
			else:  # down and back out
				ball.position = Vector2(line + out * POST_HIT, y)
				ball.z = CROSSBAR - POST_HIT
				ball.velocity.x = -ball.velocity.x * 0.5
				ball.vz = -absf(ball.vz) * 0.5 - 100.0
		if hit != "":
			ball.end_power()
			flash(hit, 1.0)
			play_sfx("bounce")
			play_sfx("ooh", -4.0)
			event.emit("woodwork", ball.last_touch.team if ball.last_touch else home)
		return


func _check_goal() -> void:
	var field := Pitch.field_rect()
	var x := ball.position.x
	if x > 0.0 and x < field.size.x:
		return
	var in_mouth := absf(ball.position.y - field.size.y / 2.0) < GOAL_HALF_WIDTH and ball.z < CROSSBAR
	if not in_mouth:
		return
	var scorers := home if (x >= field.size.x) == (home.side > 0) else away
	scorers.score += 1
	_conceded = opponent(scorers)
	ball.stop_at(Vector2(clampf(x, -14.0, field.size.x + 14.0), ball.position.y))
	state = State.GOAL
	_state_left = 3.5
	flash("GOAL!\n%s" % scorers.name, 3.5)
	opponent(scorers).gain(Supers.GAIN.conceded)
	play_sfx("roar")
	stadium.shake = 0.4
	event.emit("goal", scorers)
	var scorer := ball.last_touch
	if scorer and scorer.team == scorers:
		var options := CELEBRATIONS.filter(func(a): return Anims.has(a))
		scorer.perform(options[randi() % options.size()])
	var tween := create_tween()
	tween.tween_property(_crowd, "volume_db", 2.0, 0.3)
	tween.tween_interval(2.5)
	tween.tween_property(_crowd, "volume_db", -8.0, 1.0)


func _portrait(entry: Dictionary) -> Texture2D:
	var path := PORTRAITS + ("%d.png" % entry.id if entry.get("portrait", false) else "unknown.png")
	return load(path) if ResourceLoader.exists(path) else null


func _load_squads() -> Dictionary:
	if not FileAccess.file_exists(SQUADS):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SQUADS))
	return data if data is Dictionary else {}


func play_sfx(key: String, volume_db := 0.0) -> void:
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = load("res://assets/audio/sfx/%s.wav" % SFX[key])
	p.volume_db = volume_db
	p.play()


func _start_crowd() -> void:
	var stream: AudioStreamWAV = load("res://assets/audio/crowd/slot055.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_crowd.stream = stream
	_crowd.volume_db = -8.0
	add_child(_crowd)
	_crowd.play()


func _add_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 10)
	layer.add_child(panel)
	var row := HBoxContainer.new()  # crest, score, crest, clock
	panel.add_child(row)
	_score_label.add_theme_font_size_override("font_size", 22)
	_clock_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_crest(home))
	row.add_child(_score_label)
	row.add_child(_crest(away))
	row.add_child(_clock_label)
	for i in (2 if chaos else 0):  # energy bars: Chaos only
		var t: Team = [home, away][i]
		var y := 56.0 + i * 22.0
		var back := ColorRect.new()
		back.color = Color(0, 0, 0, 0.6)
		back.position = Vector2(12, y)
		back.size = Vector2(204, 16)
		layer.add_child(back)
		var fill := ColorRect.new()
		fill.position = Vector2(14, y + 2)
		fill.size = Vector2(0, 12)
		fill.color = t.colour.lightened(0.15)
		layer.add_child(fill)
		var half := ColorRect.new()  # marks the 50 needed for a fireball / banana
		half.color = Color(1, 1, 1, 0.5)
		half.position = Vector2(14 + 100, y + 2)
		half.size = Vector2(1, 12)
		layer.add_child(half)
		var label := Label.new()
		label.position = Vector2(222, y - 4)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		layer.add_child(label)
		_energy_bars[t] = fill
		_energy_labels[t] = label
	for h in humans:  # alone: centred; two players: player 1 left, player 2 right
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", h.marker())
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		label.position.y -= 40
		if humans.size() == 2:
			label.position.x += -300.0 if h.index == 0 else 300.0
		layer.add_child(label)
		_player_labels.append(label)
		var face := TextureRect.new()
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.size = Vector2(80, 80)
		face.position = Vector2(640.0 - 40.0 + (0.0 if humans.size() == 1 else (-300.0 if h.index == 0 else 300.0)), 720.0 - 160.0)
		layer.add_child(face)
		_player_portraits.append(face)
	var help := Label.new()
	if humans.size() == 1:
		help.text = "WASD: move  Space: shoot (hold = power) / slide  X: pass  "
		if chaos:
			help.text += "↓↘→ / ←→ then Space: supers  Hold Space, full bar: THUNDER  "
	else:
		help.text = "P1: WASD, Space shoot, X pass   P2: arrows, Enter shoot, Right Shift pass   "
		if chaos:
			help.text += "↓↘→ / ←→ then shoot: supers   "
	help.text += "Pad: stick, B shoot, A pass   F1: anims  F3: debug"
	help.position = Vector2(12, 694)
	help.add_theme_font_size_override("font_size", 14)
	layer.add_child(help)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	layer.add_child(_banner)


func _crest(t: Team) -> TextureRect:
	var r := TextureRect.new()
	var path := CLUBS + "%s.png" % t.short
	r.texture = load(path) if ResourceLoader.exists(path) else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(28, 28) if r.texture else Vector2.ZERO
	return r


func _update_hud() -> void:
	var minutes := clock / HALF_SECONDS * 45.0  # match time: 45 minutes a half
	_score_label.text = " %s  %d - %d  %s " % [home.short, home.score, away.score, away.short]
	_clock_label.text = "    %02d:%02d " % [int(minutes), int(fmod(minutes, 1.0) * 60.0)]
	for i in humans.size():
		var p := humans[i].controlled
		_player_labels[i].text = p.display_name if p and not autoplay else ""
		_player_portraits[i].texture = p.portrait if p and not autoplay else null


func _update_energy_hud() -> void:
	for t in _energy_bars:
		var fill: ColorRect = _energy_bars[t]
		fill.size.x = 200.0 * t.energy / Supers.MAX_ENERGY
		var label: Label = _energy_labels[t]
		var full: bool = t.energy >= Supers.MAX_ENERGY
		label.text = "%s  %s" % [t.short, "MAX!" if full else "SUPER" if t.energy >= 50.0 else ""]
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		label.modulate = Color(1, 1, 0.3).lerp(Color.WHITE, pulse) if full else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if state == State.FULL_TIME and (event.is_action_pressed("shoot") or event.is_action_pressed("p2_shoot")):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	if event.is_action_pressed("anim_viewer"):
		get_tree().change_scene_to_file("res://scenes/anim_viewer.tscn")


static func _bind_inputs() -> void:
	var keys := {"anim_viewer": [KEY_F1], "debug_overlay": [KEY_F3]}  # players' controls: Human.bind_inputs
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
