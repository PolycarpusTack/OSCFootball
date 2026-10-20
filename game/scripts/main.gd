class_name Match
extends Node2D
## Player 1's club (home) vs the AI's or player 2's (away), 11 a side: rules, possession,
## control switching, fouls, penalties, goals and kick-offs.

signal event(kind: String, team: Team)  # goal, shot, save, foul, penalty, or a super's name

enum State { KICKOFF, PLAY, GOAL, PENALTY, RESTART, HALF_TIME, FULL_TIME, SHOOTOUT }

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
const KEEPER_CLEAR := 9.15 * Pitch.PX_PER_M  # a keeper holding it waits until opponents are this far away
const KEEPER_MAX_HOLD := 6.0  # ... or this many seconds (the six-second rule)
const FOUL_MISS := 0.4  # a slide that misses the ball takes the man this often
# chance of a yellow and of a straight red for a foul, before aggression (0.7 → 1.3x)
const CARD_ODDS := {"behind": [0.45, 0.1], "front": [0.12, 0.0]}
const OFF_PITCH := Vector2(-500.0, -500.0)  # where a sent-off player waits out the match
# Chaos referee: a discipline meter per player, filled by what the referee sees (see offence)
const DISCIPLINE := {"foul from behind": 45.0, "foul": 30.0, "body check": 20.0, "chaos": 20.0}
const DISCIPLINE_FULL := 100.0  # a booking, and it starts again
const DISCIPLINE_COOL := 1.5  # per second of play: he forgets, slowly
const MOOD_FULL := 100.0  # the referee's mood with a side: 0 calm .. MOOD_FULL furious
const MOOD_GAIN := 0.5  # mood per point of discipline a seen offence adds
const MOOD_COOL := 1.0  # per second of play
const DISSENT := 20.0  # mood for "sorry" pressed when there's nothing to be sorry for
const PARRY_WINDOW := 0.5  # seconds after a called foul in which "Sorry, ref!" (special) counts
const WARNING_AT := 80.0  # a booking talked down to a warning leaves the meter here
const DIVE_RANGE := 2.5 * Pitch.PX_PER_M  # a dive needs an opponent this close to blame
const DIVE_FOOLS := 0.5  # chance an average diver fools a calm referee who sees it
const CAPTAIN_RANGE := 25.0 * Pitch.PX_PER_M  # the captain talks to him from this close
const CAPTAIN_CALMS := 40.0  # mood the captain talks him down by
const BLOW_UP_TELL := 1.2  # seconds he fumes, for all to see, before he blows his top
const WHISTLE_STUN_RANGE := 20.0 * Pitch.PX_PER_M  # ... stunning that side's players this close
const WHISTLE_STUN := 1.2  # seconds
const BLOWN_MOOD := 50.0  # his mood with that side once he's let off steam
const BRIBE_RANGE := 10.0 * Pitch.PX_PER_M  # an envelope is handed over from this close
const BRIBE_TIME := 30.0  # seconds of play he leans your way
const BRIBE_CAUGHT := 0.3  # chance the linesman saw it
const BRIBE_FLAG := 2.0  # seconds later he flags it
const REF_VIEW_ANGLE := deg_to_rad(50.0)  # either side of where he looks
const REF_VIEW_RANGE := 40.0 * Pitch.PX_PER_M
const REF_NEAR := 6.0 * Pitch.PX_PER_M  # this close he sees it whichever way he looks
const REF_TURN := 2.5  # radians a second his gaze turns toward the ball
const SKILL_GAIN := 10.0  # energy for beating an opponent with a nutmeg or rainbow
const NUTMEG_RANGE := 45.0  # an opponent this close in front can be nutmegged  # Chaos special: energy for a shoulder barge
const SHOT_RANGE := 40.0 * Pitch.PX_PER_M  # a "shot" kick from farther out is a punt or a blind pass, not a shot
const SHOOTOUT_KICKS := 5  # each, before sudden death
const SHOOTOUT_ORDER := [9, 10, 8, 7, 6, 5, 4, 3, 2, 1, 0]  # squad slots: strikers first, the keeper last
const CELEBRATIONS := ["aeropla", "celdnce", "celdnc2", "celdpnc", "vctflip", "victrun", "duckflp"]
const SQUADS := "res://data/squads.json"
const PORTRAITS := "res://assets/portraits/"
const CLUBS := "res://assets/clubs/"  # crests <SHORT>.png and boards <SHORT>_board.png
const CROWDS := "res://brand/crowds/"  # each club's supporters for the stands, <SHORT>.png
## Sound effects from SFX_GAME.BNK, identified by their spectra (ASSUMED: not confirmed
## by ear): short low thuds are ball contacts, ~3.8 kHz tones the referee's whistle.
const SFX := {
	"kick": "slot002", "pass": "slot012", "bounce": "slot001",
	"whistle": "slot030", "long_whistle": "slot029", "roar": "slot021", "ooh": "slot005",
}
const THUNDER_HOLD := 0.8  # seconds to hold shoot for a Thunder Strike (needs a full bar)
## The referee's own art (assets/sprites/oscf_roles) in place of the players' animations
const REFEREE_ART := {"xstandd": "ref_idle", "walk": "ref_run", "jog": "ref_run", "run": "ref_run",
	"rcard": "ref_card", "rpoint": "ref_point"}
const YELLOW_CARD := Color("ffd400")
const RED_CARD := Color("e3102b")

## Chaos Football: energy bars and super-shots. Classic Football: plain FIFA 96 rules,
## same players, ball and AI. Chosen on the title screen; kept between matches.
static var chaos := true
static var players := 1  # people playing: 1 (vs the AI) or 2 (home vs away); title screen
static var home_club := "Club Brugge"  # player 1's club (data/league.json); team select screen
static var away_club := "Anderlecht"  # the AI's or player 2's club
# match options screen (match_options.gd); kept between matches like the above
static var half_minutes := 3  # real minutes per half; the clock shows 45 match minutes (ASSUMED default length)
static var offside_on := true
static var fouls_on := true  # off: a slide never takes the man (no free kicks or penalties from fouls)
static var cards_on := true
static var knockout := false  # level at full time: extra time (golden goal), then penalties

var ball: Ball
var home: Team
var away: Team
var humans: Array[Human] = []  # player 1 (home), player 2 (away) when two play
var referee: Footballer  # follows play, points to free kicks and shows the cards; nobody's team
var referee_gaze := Vector2.UP  # where he looks: toward the ball, turning at REF_TURN (Chaos view cone)
var ref_mood := {}  # Team -> his mood with that side (Chaos); angry, he books faster
var bribed := {}  # Team -> seconds of play he still leans its way (Chaos)
var _bribe_flag := {}  # Team -> seconds until the linesman flags its bribe
var _blow_up := {}  # he's fuming at a side: team, left (seconds until the whistle stun)
var referee_cone := true  # false: he sees everything (tests that aren't about him)
var state := State.KICKOFF
var clock := 0.0  # seconds of play (stopped during goals, restarts, breaks)
var half := 1
var half_seconds := half_minutes * 60.0  # real seconds of play per half
var autoplay := false  # AI plays both sides (demo / attract mode)

var _state_left := 0.0
var _conceded: Team  # kicks off after the goal (an own goal too)
var _penalty_taker: Footballer
var shootout := {}  # Team -> Array of bools, one per penalty taken in the shoot-out
var _shootout_team: Team  # takes the next (or the current) shoot-out penalty
var _shootout_live := false  # a shoot-out penalty is on its way: see _shootout
var _restart_kind := ""  # "throw-in", "corner" or "goal kick" while state is RESTART
var _restart_taker: Footballer
var _restart_taken := false  # the taker has started the throw / kick; play on once it's left them
var _keeper_held := 0.0  # seconds a keeper has held the ball in his box
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
var _discipline_bars: Array[ColorRect] = []  # Chaos: each human's player's discipline meter, under his portrait
var _player_portraits: Array[TextureRect] = []  # and their pixel portrait above it
var _energy_bars := {}  # Team -> ColorRect fill
var _energy_labels := {}  # Team -> Label
var _aim_arrows := Node2D.new()  # each human's shot arrow on the grass (see aim_arrow)
var _mood_meter := Node2D.new()  # Chaos: his mood with each side, over his head
var _parry := {}  # a human side's called foul still open to "Sorry, ref!": p, added, left
var stats: MatchStats  # for the full-time screen
var _full_time_panel := PanelContainer.new()
var chaos_actions: ChaosActions
var line_moves: LineMoves
var control_hints: ControlHints  # the prompts along the bottom


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
		var crowd := CROWDS + "%s.png" % t.short
		stadium.club_crowds.append(load(crowd) if ResourceLoader.exists(crowd) else null)
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
	referee.anim_names = REFEREE_ART
	referee.art_material = ShaderMaterial.new()
	referee.art_material.shader = preload("res://scripts/referee_card.gdshader")
	world.add_child(referee)

	_start_crowd()
	for i in 6:
		_sfx_players.append(AudioStreamPlayer.new())
		add_child(_sfx_players[i])
	ball.kicked.connect(func(speed): play_sfx("kick" if speed > 400.0 else "pass", linear_to_db(clampf(speed / 600.0, 0.3, 1.0))))
	ball.kicked.connect(func(_speed): _note_offside())
	ball.kicked.connect(func(_speed): _note_shot.call_deferred())  # deferred: the kicker sets kick_kind after the kick
	ball.bounced.connect(func(speed): play_sfx("bounce", linear_to_db(clampf(speed / 300.0, 0.15, 0.7))))
	_add_hud()
	_aim_arrows.top_level = true
	_aim_arrows.z_index = -3000  # on the grass, under every player
	_aim_arrows.draw.connect(_draw_aim_arrows)
	add_child(_aim_arrows)
	_mood_meter.top_level = true
	_mood_meter.z_index = 3000  # over the players
	_mood_meter.draw.connect(_draw_mood_meter)
	add_child(_mood_meter)
	add_child(DebugOverlay.new(self))
	add_child(PauseMenu.new())
	stats = MatchStats.new(self)
	chaos_actions = ChaosActions.new(self)
	add_child(chaos_actions)
	line_moves = LineMoves.new(self)
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


## Leaving mid slow-mo (F1, the pause menu) mustn't leave the game running at Thunder Strike speed.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	chaos_actions.tick(delta)
	line_moves.tick()
	_update_hud()
	_referee_follows()
	_sorry_ref(delta)
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
				if half > 2:  # golden goal
					_full_time("GOLDEN GOAL")
				else:
					kickoff(_conceded)
		State.PENALTY:
			_penalty(delta)
		State.RESTART:
			_restart(delta)
		State.HALF_TIME:
			_state_left -= delta
			if _state_left <= 0.0:
				half += 1
				for t in [home, away]:
					t.side = -t.side  # change ends
				kickoff(home if half % 2 == 0 else away)  # the away side kicked off the first half
		State.SHOOTOUT:
			_shootout(delta)
		State.FULL_TIME:
			for t in [home, away]:
				for p in t.players:
					if not p.busy():
						p.wish = Vector2.ZERO
		State.PLAY:
			clock += delta
			if _referee_temper(delta):
				return
			for t in [home, away]:
				for p in t.players:
					p.discipline = maxf(0.0, p.discipline - DISCIPLINE_COOL * delta)
				ref_mood[t] = maxf(0.0, ref_mood.get(t, 0.0) - MOOD_COOL * delta)
			if clock >= half_end():
				_end_half()
				return
			if not autoplay:
				_switch_control()
			for t in [home, away]:
				var h := human_for(t)
				for p in t.players:
					if p.chaos_lock:
						p.wish = Vector2.ZERO
						continue
					if h and p == h.controlled:
						_human_input(h, p)
					else:
						AI.think(p, self, delta)
			_clear_keepers_box(delta)
			_resolve_possession(delta)
			stats.tick(delta)
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
	_mood_meter.queue_redraw()
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
	if chaos:
		if Input.is_action_just_pressed(h.action("cycle_special")):
			chaos_actions.cycle(h)
		if Input.is_action_just_pressed(h.action("special")):
			if chaos_actions.activate(h, aim):
				h.charging = false
				p.charge = 0.0
				return
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
	if p.role == "G" and p.has_ball() and not keeper_may_release(p):
		h.charging = false
		p.charge = 0.0
		return  # opponents still close: he holds it
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
				fired = combo_move(p, h.pending_combo, target, aim)
			if not fired:
				if h.pending_combo != "":
					control_hints.combo_short(h, p, h.pending_combo)
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
	if chaos and referee_cone:  # the referee's view cone, faint on the grass
		var fan := PackedVector2Array()
		var area := Pitch.field_rect().grow(Pitch.m(3.0))
		for q in [referee.position] + range(9).map(func(i): return referee.position + referee_gaze.rotated(lerpf(-REF_VIEW_ANGLE, REF_VIEW_ANGLE, i / 8.0)) * REF_VIEW_RANGE):
			var at := stadium.to_screen((q as Vector2).clamp(area.position, area.end))
			fan.append(Vector2(at.x, at.y))
		if not Geometry2D.triangulate_polygon(fan).is_empty():  # by a touchline the clamped points can fold flat
			_aim_arrows.draw_colored_polygon(fan, Color(1.0, 1.0, 0.7, 0.13))
		fan.append(fan[0])
		_aim_arrows.draw_polyline(fan, Color(1.0, 1.0, 0.7, 0.3), 1.5)
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
		get_tree().create_timer(0.7, false, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## The move a combo entered before shoot makes: ↓↘→ is the player's line move (LineMoves),
## the Fireball for a striker; anything else the super of that name.
func combo_move(p: Footballer, kind: String, target: Vector2, aim: Vector2) -> bool:
	if kind == "fireball" and not LineMoves.for_line(p).is_empty():
		return chaos and line_moves.start(p, aim)
	return try_super(p, kind, target)


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
		if o.chaos_lock:
			continue
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
		if o.sliding() and from_behind and fouls_on:
			_foul(o, holder)
			return
		if o.sliding() and randf() > o.skill("slidingTackle", 0.55, 1.0):
			o.touch_cooldown = 0.6  # missed: one try per slide
			if fouls_on and randf() < FOUL_MISS:  # took the man instead
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
	offence(o, holder.position, "body check")
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
func _clear_keepers_box(delta: float) -> void:
	var k := ball.holder
	if k == null or k.role != "G" or not in_penalty_area(k.position, k.team):
		_keeper_held = 0.0
		return
	_keeper_held += delta
	for p in opponent(k.team).players:
		if in_penalty_area(p.position, k.team) and not p.busy():
			p.wish = Vector2(k.team.side, 0.0)  # away from the keeper's goal


## A keeper holding the ball may play it once opponents are KEEPER_CLEAR away, or after
## KEEPER_MAX_HOLD seconds (the AI and a human alike).
func keeper_may_release(k: Footballer) -> bool:
	return nearest_opponent_distance(k) >= KEEPER_CLEAR or _keeper_held >= KEEPER_MAX_HOLD


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
	if not referee_sees(victim.position):  # Chaos: play on
		flash("REF DIDN'T SEE IT!", 1.2)
		event.emit("unseen foul", by.team)
		return
	if bribed.has(by.team):  # Chaos: he looks the other way
		flash("PLAY ON!", 1.2)
		event.emit("bribed call", by.team)
		return
	victim.team.gain(Supers.GAIN.fouled)
	event.emit("foul", by.team)
	if in_penalty_area(victim.position, by.team):
		award_penalty(victim.team)
	else:
		_award_restart("free kick", victim.team, victim.position.clamp(Vector2.ZERO, Pitch.field_rect().size))
	if not cards_on:
		return
	var odds: Array = CARD_ODDS["behind" if from_behind else "front"]
	var r := randf() / by.skill("aggression", 0.7, 1.3)
	if r < odds[1]:
		book(by, true)
	elif chaos:  # yellows come from the discipline meter
		offence(by, victim.position, "foul from behind" if from_behind else "foul")
	elif r < odds[0] + odds[1]:
		book(by, false)


## The referee shows `p` a card. A second yellow is a red: off he goes, for the rest of the
## match (parked off the pitch, out of play).
func book(p: Footballer, red: bool) -> void:
	red = red or p.yellow
	p.yellow = true
	referee.facing = Anims.facing_from(p.position - referee.position)
	referee.art_material.set_shader_parameter("card", RED_CARD if red else YELLOW_CARD)
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
	var line := onside_depth(passer.team)
	for p in passer.team.players:
		var d := absf(goal_x - p.position.x)
		if p != passer and not p.sent_off and d < line:
			out.append(p)
	return out


## How close to the goal `attacking` attacks (pitch pixels from its goal line) a player can
## be and still be onside right now: the second-last defender, the ball or halfway, the
## nearest of them to the goal line counts.
func onside_depth(attacking: Team) -> float:
	var goal_x := attacking.goal_attacked().x
	var depths: Array[float] = []  # each defender's distance from his goal line
	for o in opponent(attacking).players:
		if not o.sent_off:
			depths.append(absf(goal_x - o.position.x))
	depths.sort()
	var line: float = depths[1] if depths.size() > 1 else 0.0
	var half_way := absf(goal_x - Pitch.field_rect().get_center().x)
	return minf(line, minf(absf(goal_x - ball.position.x), half_way))


## A kick at goal: a shot, header or volley at it, or a super-shot, from within SHOT_RANGE.
func _note_shot() -> void:
	var p := ball.last_touch
	if p == null or not (ball.kick_kind == "shot" or Supers.LIST.has(ball.kick_kind)):
		return
	var goal := p.team.goal_attacked()
	if p.position.distance_to(goal) < SHOT_RANGE and ball.velocity.dot(goal - p.position) > 0.0:
		event.emit("shot", p.team)


## On every kick in open play: who's offside for it (see _caught_offside).
func _note_offside() -> void:
	_offside.clear()
	if offside_on and state == State.PLAY and ball.last_touch:
		_offside = offside_players(ball.last_touch)


## `p` is about to play a ball a teammate last kicked (a pass, a cross, a shot back off the
## woodwork ...) while he was offside: a free kick to the other side where he is.
func _caught_offside(p: Footballer) -> bool:
	var passer := ball.last_touch
	if not p in _offside or ball.kick_kind == "" or passer == null or passer == p or passer.team != p.team:
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
	var to_ball := ball.position - referee.position
	if to_ball.length() > 1.0:
		var turn := REF_TURN * get_physics_process_delta_time()
		referee_gaze = Vector2.from_angle(rotate_toward(referee_gaze.angle(), to_ball.angle(), turn))
	var away_from := referee.position - ball.position
	var target := ball.position + (away_from.normalized() if away_from.length() > 1.0 else Vector2.UP) * Pitch.m(12.0)
	target = target.clamp(Vector2.ZERO, Pitch.field_rect().size)
	referee.wish = ((target - referee.position) / 40.0).limit_length(1.0)


## Chaos: whether the referee sees what happens at `pos` (in his view cone, or right by
## him). In Classic he sees everything.
func referee_sees(pos: Vector2) -> bool:
	if not chaos or not referee_cone:
		return true
	var to := pos - referee.position
	if to.length() < REF_NEAR:
		return true
	return to.length() < REF_VIEW_RANGE and absf(referee_gaze.angle_to(to)) < REF_VIEW_ANGLE


## Chaos: `p` did something rough (`kind`, see DISCIPLINE) at `pos`. If the referee saw it,
## p's discipline meter fills, faster the angrier he is with p's side, and so does his mood.
## Full, p is booked (a second time: sent off) and it starts again. A human side's foul
## (play has stopped) waits PARRY_WINDOW for "Sorry, ref!" first.
func offence(p: Footballer, pos: Vector2, kind: String) -> void:
	if not chaos or p.sent_off or not referee_sees(pos) or bribed.has(p.team):
		return
	var added: float = DISCIPLINE[kind] * (1.0 + ref_mood.get(p.team, 0.0) / MOOD_FULL)
	p.discipline += added
	ref_mood[p.team] = minf(MOOD_FULL, ref_mood.get(p.team, 0.0) + added * MOOD_GAIN)
	if state != State.PLAY and not autoplay and human_for(p.team) != null:
		if not _parry.is_empty():  # the one before it is judged now
			_judge(_parry.p)
		_parry = {"p": p, "added": added, "left": PARRY_WINDOW}
		return
	_judge(p)


## Chaos: `t`'s captain, the steadiest head on the pitch (highest composure).
func captain(t: Team) -> Footballer:
	var best: Footballer = null
	for p in t.players:
		if p.role != "G" and not p.sent_off and (best == null or p.stats.get("composure", 67.5) > best.stats.get("composure", 67.5)):
			best = p
	return best


## Chaos: `p` throws himself down next to an opponent. Unseen, nothing comes of it but the
## ball rolling free. Seen, the referee may fall for it, likelier for a cool head and less
## so the angrier he is with p's side: a foul on p by the nearest opponent. Or he sees
## through it: a yellow for diving, more mood, and a free kick to the other side.
func dive(p: Footballer) -> void:
	if ball.holder == p:
		ball.release()
	if not referee_sees(p.position):
		flash("NOBODY SAW IT", 1.0)
		return
	var blamed: Footballer = null
	for o in opponent(p.team).players:
		if not o.sent_off and (blamed == null or o.position.distance_to(p.position) < blamed.position.distance_to(p.position)):
			blamed = o
	if randf() < dive_odds(p):
		event.emit("dive bought", p.team)
		_foul(blamed, p, false)
		return
	event.emit("dive", p.team)
	ref_mood[p.team] = minf(MOOD_FULL, ref_mood.get(p.team, 0.0) + DISSENT)
	_award_restart("free kick", blamed.team, p.position.clamp(Vector2.ZERO, Pitch.field_rect().size))
	if cards_on:
		book(p, false)
	else:
		flash("DIVE!", 1.2)


## Chance the referee falls for `p`'s dive when he sees it.
func dive_odds(p: Footballer) -> float:
	if bribed.has(p.team):
		return 1.0
	return DIVE_FOOLS * p.skill("composure", 0.6, 1.4) * (1.0 - 0.8 * ref_mood.get(p.team, 0.0) / MOOD_FULL)


## Chaos: `t`'s captain has a word: the referee's mood with `t` drops by CAPTAIN_CALMS.
func calm_referee(t: Team) -> void:
	ref_mood[t] = maxf(0.0, ref_mood.get(t, 0.0) - CAPTAIN_CALMS)
	if _blow_up.get("team") == t:  # just in time
		_blow_up = {}
	flash("THE CAPTAIN CALMS HIM", 1.2)


## Chaos: `t` slips him an envelope. For BRIBE_TIME seconds of play he leans its way: its
## offences go unnoticed, its fouls are play on and he falls for every dive, and he's no
## longer angry with it. But the linesman may have seen it: see _referee_temper.
func bribe(t: Team) -> void:
	bribed[t] = BRIBE_TIME
	ref_mood[t] = 0.0
	if _blow_up.get("team") == t:
		_blow_up = {}
	if randf() < BRIBE_CAUGHT:
		_bribe_flag[t] = BRIBE_FLAG


## Chaos, every frame of play: bribes run out or are flagged by the linesman (a penalty
## against the briber, and the referee furious with it), and a referee furious with a side
## fumes for BLOW_UP_TELL seconds (puffed up, for all to see: get away from him, or send the
## captain), then blows his top: a whistle stun for that side's players near him. True if
## play stopped.
func _referee_temper(delta: float) -> bool:
	if not chaos:
		return false
	for t in bribed.keys():
		bribed[t] -= delta
		if bribed[t] <= 0.0:
			bribed.erase(t)
	for t in _bribe_flag.keys():
		_bribe_flag[t] -= delta
		if _bribe_flag[t] <= 0.0:
			_bribe_flag.erase(t)
			bribed.erase(t)
			ref_mood[t] = MOOD_FULL
			event.emit("bribe caught", t)
			award_penalty(opponent(t))
			flash("LINESMAN SAW THE BRIBE!\nPENALTY!", 2.5)
			return true
	if _blow_up.is_empty():
		for t in [home, away]:
			if ref_mood.get(t, 0.0) >= MOOD_FULL:
				_blow_up = {"team": t, "left": BLOW_UP_TELL}
				flash("THE REF IS FUMING!", BLOW_UP_TELL)
				event.emit("ref fuming", t)
				break
	elif _blow_up.left > delta:
		_blow_up.left -= delta
	else:
		_whistle_stun(_blow_up.team)
		_blow_up = {}
	return false


## The referee blows his top at `t`: its players within WHISTLE_STUN_RANGE of him are
## stunned (a dodge gets out of it), a stunned dribbler drops the ball, and he calms to
## BLOWN_MOOD with `t`.
func _whistle_stun(t: Team) -> void:
	play_sfx("long_whistle")
	flash("WHISTLE STUN!", 1.0)
	event.emit("whistle stun", t)
	ref_mood[t] = BLOWN_MOOD
	for p in t.players:
		if not p.sent_off and p.position.distance_to(referee.position) <= WHISTLE_STUN_RANGE \
				and chaos_actions.stun(p, WHISTLE_STUN) and ball.holder == p:
			ball.release()


## A full discipline meter: a booking, and it starts again.
func _judge(p: Footballer) -> void:
	if p.discipline >= DISCIPLINE_FULL:
		p.discipline = 0.0
		if cards_on:
			book(p, false)


## Chaos, "Sorry, ref!" (special, at a stoppage): just after your side's called foul, he
## takes back half of it, and a booking it earned becomes a warning. Any other time it's
## dissent and he gets angrier with your side. The open window is judged when it ends.
func _sorry_ref(delta: float) -> void:
	if not chaos or autoplay:
		return
	for h in humans:
		if not Input.is_action_just_pressed(h.action("special")):
			continue
		if not _parry.is_empty() and _parry.p.team == h.team:
			var p: Footballer = _parry.p
			p.discipline -= _parry.added / 2.0
			ref_mood[h.team] = maxf(0.0, ref_mood.get(h.team, 0.0) - _parry.added * MOOD_GAIN)
			if p.discipline >= DISCIPLINE_FULL:
				p.discipline = WARNING_AT
				flash("SORRY, REF!\nWARNING: %s" % p.display_name, 1.5)
			else:
				flash("SORRY, REF!", 1.0)
			event.emit("sorry ref", h.team)
			_parry = {}
		elif state in [State.RESTART, State.PENALTY]:
			ref_mood[h.team] = minf(MOOD_FULL, ref_mood.get(h.team, 0.0) + DISSENT)
			flash("DISSENT!", 1.0)
			event.emit("dissent", h.team)
	if not _parry.is_empty():
		_parry.left -= delta
		if _parry.left <= 0.0:
			var p: Footballer = _parry.p
			_parry = {}
			_judge(p)


## Over the referee's head: his mood with each side, a bar in each side's colour (home on
## top), "SORRY?" while a called foul is open to "Sorry, ref!", and a C over each human
## side's captain.
func _draw_mood_meter() -> void:
	if not chaos:
		return
	var at := stadium.to_screen(referee.position, Pitch.m(2.6))
	var w := 48.0
	if not _blow_up.is_empty():  # fuming: a pulsing ring in the side's colour, and !!
		var pulse := 1.0 + 0.25 * sin(_blow_up.left * 30.0)
		var s3 := stadium.to_screen(referee.position, Pitch.m(1.0))
		var ref_at := Vector2(s3.x, s3.y)
		_mood_meter.draw_arc(ref_at, 26.0 * pulse, 0.0, TAU, 32, Color.RED, 3.0)
		_mood_meter.draw_arc(ref_at, 20.0 * pulse, 0.0, TAU, 32, _blow_up.team.colour, 2.0)
		_mood_meter.draw_string(ThemeDB.fallback_font, Vector2(at.x + w / 2.0 + 4.0, at.y - 4.0), "!!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.RED)
	for i in bribed.size():  # a gold coin per side he's been bribed by, ringed in its colour
		var t: Team = bribed.keys()[i]
		var coin := Vector2(at.x - w / 2.0 - 10.0 - i * 16.0, at.y - 9.0)
		_mood_meter.draw_circle(coin, 7.0, t.colour)
		_mood_meter.draw_circle(coin, 5.0, Color(1.0, 0.8, 0.1))
		_mood_meter.draw_string(ThemeDB.fallback_font, coin + Vector2(-3.5, 4.5), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.25, 0.0))
	if autoplay:
		return
	for i in 2:
		var t: Team = [home, away][i]
		var bar := Rect2(at.x - w / 2.0, at.y - 16.0 + i * 8.0, w, 6.0)
		_mood_meter.draw_rect(bar, Color(0.15, 0.15, 0.15, 0.7))
		_mood_meter.draw_rect(Rect2(bar.position, Vector2(w * ref_mood.get(t, 0.0) / MOOD_FULL, bar.size.y)), t.colour)
		_mood_meter.draw_rect(bar, Color(1, 1, 1, 0.6), false, 1.0)
	for h in humans:  # a C over each human side's captain
		var cap := captain(h.team)
		if cap:
			var c := stadium.to_screen(cap.position, Pitch.m(2.4))
			_mood_meter.draw_string(ThemeDB.fallback_font, Vector2(c.x - 5.0, c.y), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.9, 0.2))
	if not _parry.is_empty():
		_mood_meter.draw_string(ThemeDB.fallback_font, Vector2(at.x - w / 2.0, at.y - 22.0), "SORRY?",
			HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1.0, 0.9, 0.2))


func in_penalty_area(pos: Vector2, defending: Team) -> bool:
	var goal := defending.goal_defended()
	return absf(pos.x - goal.x) < BOX_DEPTH and absf(pos.y - goal.y) < BOX_HALF_WIDTH


func award_penalty(attacking: Team, taker: Footballer = null) -> void:
	var defending := opponent(attacking)
	var goal := attacking.goal_attacked()
	var spot := goal - Vector2(attacking.side * PENALTY_SPOT, 0)
	state = State.PENALTY
	_state_left = 2.5
	ball.stop_at(spot)
	flash("PENALTY!", 2.0)
	play_sfx("long_whistle")
	event.emit("penalty", attacking)
	_penalty_taker = taker if taker else attacking.taker()
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
	get_tree().create_timer(Footballer.KICK_CONTACT, false).timeout.connect(
		func(): keeper.dive(Vector2(0, guess), randf() < 0.5))
	if shootout.is_empty():
		state = State.PLAY
	else:
		state = State.SHOOTOUT
		_shootout_live = true
		_state_left = 3.0  # the longest a kick can take to be decided


## Clock time the current half ends: 45 match minutes a half, 15 in extra time.
func half_end() -> float:
	return half_seconds * half if half <= 2 else half_seconds * 2.0 + half_seconds / 3.0 * (half - 2)


func _end_half() -> void:
	play_sfx("long_whistle")
	ball.stop_at(ball.position)
	for t in [home, away]:
		for p in t.players:
			p.wish = Vector2.ZERO
	var level := home.score == away.score
	if half == 1 or (half == 2 and knockout and level) or half == 3:
		if half == 1:
			for t in [home, away]:
				for p in t.players:
					p.fatigue *= 0.5  # the break
		state = State.HALF_TIME
		_state_left = 4.0
		flash("HALF TIME" if half == 1 else "EXTRA TIME\nGOLDEN GOAL WINS" if half == 2 else "EXTRA TIME\nSECOND HALF", 4.0)
		event.emit("half time" if half == 1 else "extra time", home)
	elif half == 4:  # still level after extra time
		_start_shootout()
	else:
		_full_time("FULL TIME")


## The match is over: `heading` over the score, the winners celebrate.
func _full_time(heading: String) -> void:
	state = State.FULL_TIME
	var winner := match_winner()
	var line := "%s %d - %d %s" % [home.short, home.score, away.score, away.short]
	if not shootout.is_empty():
		line += "\n%s WIN %d - %d ON PENALTIES" % [winner.short, shootout[winner].count(true), shootout[opponent(winner)].count(true)]
	event.emit("full time", home)
	_show_full_time(heading, line)
	if winner:
		for p in winner.players:
			if not p.sent_off:
				p.perform(CELEBRATIONS[randi() % CELEBRATIONS.size()])


## Who won: more goals, else the shoot-out; null for a draw.
func match_winner() -> Team:
	if home.score != away.score:
		return home if home.score > away.score else away
	if shootout.is_empty():
		return null
	var h: int = shootout[home].count(true)
	var a: int = shootout[away].count(true)
	return null if h == a else home if h > a else away


func _start_shootout() -> void:
	shootout = {home: [], away: []}
	_shootout_team = away  # the away side kicked off the match: home shoots first
	state = State.SHOOTOUT
	_shootout_live = false
	_state_left = 3.0
	flash("PENALTIES", 3.0)
	event.emit("shoot-out", home)


## Shoot-out: between kicks, wait and set up the next; while one is live, only the keeper
## may touch it, and it's decided by the goal line, the keeper holding it, going out, or
## stopping.
func _shootout(delta: float) -> void:
	_state_left -= delta
	for t in [home, away]:
		for p in t.players:
			if not p.busy():
				p.wish = Vector2.ZERO
	if not _shootout_live:
		if _state_left <= 0.0:
			_shootout_team = opponent(_shootout_team)
			award_penalty(_shootout_team, _shootout_taker(_shootout_team))
		return
	var keeper := opponent(_shootout_team).keeper()
	for t in [home, away]:
		for p in t.players:
			if p != keeper:
				p.touch_cooldown = maxf(p.touch_cooldown, 0.5)
	_resolve_possession(delta)
	_check_frame()
	var scored := goal_crossed() == _shootout_team
	var out := not Pitch.field_rect().has_point(ball.position)
	var dead := ball.holder != null or out or _state_left <= 0.0 \
		or (ball.velocity.length() < 20.0 and ball.z <= 0.0 and _state_left < 2.5)
	if not scored and not dead:
		return
	_shootout_live = false
	shootout[_shootout_team].append(scored)
	if scored:
		play_sfx("roar")
	_state_left = 2.0
	var h: Array = shootout[home]
	var a: Array = shootout[away]
	flash("%s\n%s %d - %d %s" % ["SCORED!" if scored else "SAVED!" if ball.holder == keeper else "MISSED!",
		home.short, h.count(true), a.count(true), away.short], 2.0)
	event.emit("shoot-out goal" if scored else "shoot-out miss", _shootout_team)
	if _shootout_decided():
		_full_time("FULL TIME")


func _shootout_decided() -> bool:
	var h: Array = shootout[home]
	var a: Array = shootout[away]
	var hg := h.count(true)
	var ag := a.count(true)
	if h.size() <= SHOOTOUT_KICKS and a.size() <= SHOOTOUT_KICKS:  # out of reach with the kicks left?
		return hg + SHOOTOUT_KICKS - h.size() < ag or ag + SHOOTOUT_KICKS - a.size() < hg
	return h.size() == a.size() and hg != ag  # sudden death


## The next of `t`'s players in SHOOTOUT_ORDER who's still on, round again after all.
func _shootout_taker(t: Team) -> Footballer:
	var on := SHOOTOUT_ORDER.filter(func(i): return not t.players[i].sent_off)
	return t.players[on[shootout[t].size() % on.size()]]


## The full-time screen: result, the stats side by side, Man of the Match.
func _show_full_time(heading: String, result: String) -> void:
	_banner.text = ""
	for c in _full_time_panel.get_children():
		c.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_full_time_panel.add_child(column)
	column.add_child(_screen_label(heading, 44, Color(1, 0.85, 0.2)))
	column.add_child(_screen_label(result, 30, Color.WHITE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	column.add_child(grid)
	var rows := [["POSSESSION", "%d%%" % stats.possession_percent(home), "%d%%" % stats.possession_percent(away)]]
	for stat in MatchStats.ROWS:
		rows.append([stat.to_upper(), str(stats.counts[home][stat]), str(stats.counts[away][stat])])
	for r in rows:
		grid.add_child(_screen_label(r[1], 22, home.colour.lightened(0.4)))
		grid.add_child(_screen_label(r[0], 20, Color(0.85, 0.85, 0.85)))
		grid.add_child(_screen_label(r[2], 22, away.colour.lightened(0.4)))
	var motm := stats.man_of_the_match()
	if motm:
		column.add_child(_screen_label("MAN OF THE MATCH: %s (%s)" % [motm.display_name, motm.team.short], 24, Color(1, 0.85, 0.2)))
	column.add_child(_screen_label("SPACE: BACK TO THE TITLE", 16, Color(0.8, 0.8, 0.8)))
	_full_time_panel.visible = true


func _screen_label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


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


## The team the ball has just gone in for (over a goal line, between the posts, under the
## bar), or null.
func goal_crossed() -> Team:
	var field := Pitch.field_rect()
	var x := ball.position.x
	if x > 0.0 and x < field.size.x:
		return null
	if absf(ball.position.y - field.size.y / 2.0) >= GOAL_HALF_WIDTH or ball.z >= CROSSBAR:
		return null
	return home if (x >= field.size.x) == (home.side > 0) else away


func _check_goal() -> void:
	var scorers := goal_crossed()
	if scorers == null:
		return
	var field := Pitch.field_rect()
	var x := ball.position.x
	scorers.score += 1
	_conceded = opponent(scorers)
	ball.stop_at(Vector2(clampf(x, -14.0, field.size.x + 14.0), ball.position.y))
	state = State.GOAL
	_state_left = 3.5
	flash("%s\n%s" % ["GOLDEN GOAL!" if half > 2 else "GOAL!", scorers.name], 3.5)
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
	if key.ends_with("whistle") and referee and not referee.busy():  # he's the one blowing it
		referee.perform("ref_whistle")


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
		if chaos:
			var back := ColorRect.new()
			back.color = Color(0, 0, 0, 0.6)
			back.position = face.position + Vector2(0, 84)
			back.size = Vector2(80, 6)
			layer.add_child(back)
			var fill := ColorRect.new()  # in the back: shown and hidden with it
			fill.position = Vector2(1, 1)
			fill.size = Vector2(0, 4)
			back.add_child(fill)
			_discipline_bars.append(fill)
	control_hints = ControlHints.new(self)
	add_child(control_hints)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	layer.add_child(_banner)
	_full_time_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_full_time_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_full_time_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.03, 0.06, 0.88)
	box.set_content_margin_all(24.0)
	_full_time_panel.add_theme_stylebox_override("panel", box)
	_full_time_panel.visible = false
	layer.add_child(_full_time_panel)


func _crest(t: Team) -> TextureRect:
	var r := TextureRect.new()
	var path := CLUBS + "%s.png" % t.short
	r.texture = load(path) if ResourceLoader.exists(path) else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(28, 28) if r.texture else Vector2.ZERO
	return r


func _update_hud() -> void:
	var minutes := clock / half_seconds * 45.0  # match time: 45 minutes a half
	_score_label.text = " %s  %d - %d  %s " % [home.short, home.score, away.score, away.short]
	_clock_label.text = "    %02d:%02d " % [int(minutes), int(fmod(minutes, 1.0) * 60.0)]
	for i in humans.size():
		var p := humans[i].controlled
		_player_labels[i].text = p.display_name if p and not autoplay else ""
		_player_portraits[i].texture = p.portrait if p and not autoplay else null
		if i < _discipline_bars.size():
			_discipline_bars[i].get_parent().visible = p != null and not autoplay
			var d := p.discipline / DISCIPLINE_FULL if p and not autoplay else 0.0
			_discipline_bars[i].size.x = 78.0 * d
			_discipline_bars[i].color = Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.15, 0.1), d)


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
