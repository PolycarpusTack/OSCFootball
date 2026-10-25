class_name Footballer
extends Node2D
## One player's body: movement, animation, carrying and kicking the ball.
## Who decides what to do (human input or AI) is up to the match: it sets
## `wish` every frame and calls shoot() / pass_to().

const RUN_SPEED := 170.0
const ACCEL := 900.0
const REACH := 14.0
const GIANT := 1.6  # sprite scale with the giant players modifier (looks only)
const PRESS_BLOCK_M := 2.5  # an opponent this close when a pass is played may block it (see _past_the_press)
const KICK_CONTACT := 0.15  # seconds into a kick animation the foot meets the ball
const THROW_RELEASE := 0.67  # the throw-in animation's hands are empty from tick 21 (frame 4)
const HEAD_HEIGHT := 36.0  # pitch pixels: where a throw-in leaves the hands
const CHEST_HEIGHT := 28.0  # an air ball below this is volleyed or chested, above it headed
const HEAD_TOP := 34.0  # highest ball a player heads standing; jumping adds up to 20
# seconds into each animation the head / foot / chest meets the ball (the jump's peak, the swing)
const AIR_CONTACT := {"header": 0.33, "divehed": 0.33, "vollkck": 0.4, "chest": 0.5}
const MARKER := Color(1.0, 0.95, 0.3)
const PRESSURE := 3.0 * Pitch.PX_PER_M  # an opponent closer than this unsettles a shot or pass
const BODY_CHECK_TIME := 0.8  # the shoulder-barge part of the bodychk animation (it goes on to land)
const BODY_CHECK_SPEED := 360.0
# skill moves: seconds into the animation the foot plays the ball, and how long it ties him up
# stamina: fatigue (0 fresh .. 1 spent) builds while running, a little faster with poor stamina,
# and goes off walking or standing; it costs top speed and acceleration
const TIRING := [0.012, 0.0045]  # per second running: stamina 40 .. 95
const RECOVERY := 0.004  # per second at walking pace or standing
# condition (CM3's): worn down over the whole match, more with poor stamina, and fatigue never
# recovers below what it has lost; a little comes back at half time, subs come on fresh
const WEAR := [0.012, 0.0042]  # condition lost per match minute running (a quarter of it walking): stamina 40 .. 95
const HALF_TIME_REST := 0.06
const TIRED_SPEED := 0.15  # top speed lost when spent
const TIRED_ACCEL := 0.2
const DIZZY_SPEED := 0.5
const SKILL_MOVES := {"nutmeg": [0.4, 0.7], "rainbow": [0.45, 0.75], "bckheel": [0.4, 0.7]}

var team: Team
var opponents: Team  # the other side, for how pressed he is
var role := "M"  # G, D, M or F
var number := 0
var display_name := ""  # shown in the HUD (the node name stays unique: "BRU 7")
var portrait: Texture2D  # pixel portrait for the HUD, or null
var stats := {}  # EA SPORTS FC ratings by name (data/squads.json), empty without a squad
var entry := {}  # his squad entry (data/squads.json): position, overall, ...; empty without a squad
var skin := Color.TRANSPARENT  # from the player's photo; transparent: FIFA 96's default
var hair := Color.TRANSPARENT
var pass_marker := Color.TRANSPARENT  # set while a human's pass would go to this player
var home := Vector2.ZERO  # kick-off spot as a pitch fraction (see Team.FORMATIONS)
var attack_spot := Vector2.ZERO  # the spot he holds when his side has the ball
var defend_spot := Vector2.ZERO  # ... and when it hasn't
var ball: Ball
var controlled := false
var marker := MARKER  # control ring colour: which human controls this player
var speed_factor := 1.0
var wish := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 4
var touch_cooldown := 0.0  # can't take the ball while > 0 (just kicked or lost it)
var think_timer := 0.0  # AI: time until the next pass/shoot decision
var ai_state := ""  # AI: what it last decided to do, for the debug overlay
var charge := 0.0  # 0..1 while the shoot button is held; drawn as a ring
var fatigue := 0.0  # 0 fresh .. 1 spent (see TIRING); the control ring empties with it
var condition := 1.0  # 1 fresh .. 0 spent over the match (see WEAR): fatigue stays at least 1 - condition
var marking: Footballer = null  # AI: the opponent he man-marks when defending (see CpuManager)
var yellow := false  # booked: a second yellow is a red
var sent_off := false  # red card: parked off the pitch for the rest of the match (see Match.book)
var dizzy_left := 0.0  # Chaos: seeing stars after a knockdown when tired (see Match.knock_down)
var discipline := 0.0  # Chaos: how far the referee's patience with him has run out, 0-100 (see Match.offence)
var fouls := 0  # fouls the referee has called on him this match: the more, the harsher (see Match.repeat_factor)
var warned := false  # Chaos: called over since his last booking (see Match.offence)
var chaos_lock := false  # controlled by ChaosActions through wind-up, active and recovery
var chaos_lift := 0.0  # cosmetic only; ball contacts use explicit action height windows
var chaos_rotation := 0.0

## Animations this body plays in place of the players' ones, e.g. the referee's own art:
## {"run": "ref_run", ...}. Together with `art_material`, which replaces the kit shader.
var anim_names := {}
var art_material: Material = null

var _anim := "xstandd"
var _anim_time := 0.0
var _action_left := 0.0  # while > 0 a one-shot animation plays and movement is ignored
var _actions := 0  # counts one-shot animations started: a wind-up knows if it was cut short
var _sprite := Sprite2D.new()
var _kit: Material  # the kit shader, for the palette-indexed FIFA 96 frames
var _own_kit: Material  # the same kit for our own RGBA art (Team.own_art_material)
var _rendered_kit: Material  # and for the Rendered player art (Team.rendered_material)
var _marks := Node2D.new()  # shadow, control ring and charge meter, drawn under the sprite


## The body is simulated in pitch pixels; the match places the visuals on screen
## each frame with place(), through the stadium camera.
func _ready() -> void:
	_sprite.centered = false
	var kit: ShaderMaterial = (team.keeper_material if role == "G" else team.outfield_material).duplicate()
	if skin.a > 0.0:
		kit.set_shader_parameter("skin", Vector3(skin.r, skin.g, skin.b))
		kit.set_shader_parameter("has_skin", true)
	if hair.a > 0.0:
		kit.set_shader_parameter("hair", Vector3(hair.r, hair.g, hair.b))
		kit.set_shader_parameter("has_hair", true)
	_kit = kit
	_own_kit = Team.own_art_material(kit, role == "G")
	_rendered_kit = Team.rendered_material(kit)
	_sprite.material = art_material if art_material else kit
	_sprite.top_level = true
	_marks.top_level = true
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	add_child(_sprite)


## `screen` from Stadium.to_screen(): x, y on screen and the scale there in z.
func place(screen: Vector3) -> void:
	var at := Vector2(screen.x, screen.y)
	_sprite.position = at
	_sprite.scale = Vector2.ONE * screen.z * (GIANT if Match.modifier("giant players") else 1.0)
	_sprite.rotation = chaos_rotation
	if chaos_rotation != 0.0 or chaos_lift != 0.0:
		var pivot := Vector2(0, -24)
		_sprite.position += (pivot - pivot.rotated(chaos_rotation) - Vector2(0, chaos_lift)) * screen.z
	_sprite.z_index = clampi(int(at.y), -2000, 2000)
	_marks.position = at
	_marks.scale = _sprite.scale
	_marks.z_index = _sprite.z_index - 1
	_marks.queue_redraw()


func has_ball() -> bool:
	return ball != null and ball.holder == self


func busy() -> bool:
	return _action_left > 0.0 or chaos_lock


func feet_front() -> Vector2:
	return position + Anims.FACING_VECTORS[facing] * 10.0


## A rating (EA SPORTS FC, 0-99) mapped onto lo..hi: 40 or less gives lo, 95 or more hi.
## Without ratings (no squad loaded) a player is average: halfway, today's behaviour.
func skill(stat: String, lo: float, hi: float) -> float:
	var v: float = stats.get(stat, 67.5)
	return lerpf(lo, hi, clampf((v - 40.0) / 55.0, 0.0, 1.0))


## `match_minutes` of play gone by: wear his condition down.
func wear(match_minutes: float) -> void:
	var rate := skill("stamina", WEAR[0], WEAR[1]) * (1.0 if velocity.length() > 120.0 else 0.25)
	condition = maxf(0.0, condition - rate * match_minutes)


## Running flat out, without the ball: sprintSpeed, less when tired.
func top_speed() -> float:
	return RUN_SPEED * speed_factor * skill("sprintSpeed", 0.86, 1.14) * (1.0 - TIRED_SPEED * fatigue)


## How fast he gets going and turns (px/s per s): acceleration and agility, less when tired.
func accel() -> float:
	return ACCEL * skill("acceleration", 0.75, 1.25) * skill("agility", 0.85, 1.15) * (1.0 - TIRED_ACCEL * fatigue)


## Seconds to get to `at` from a standstill: reactions (0.3 s to 0.1 s to set off), the run-up
## to top speed, then flat out.
func time_to(at: Vector2) -> float:
	var top := maxf(top_speed(), 1.0)
	return skill("reactions", 0.3, 0.1) + position.distance_to(at) / top + top / (2.0 * accel())


func _physics_process(delta: float) -> void:
	touch_cooldown = maxf(0.0, touch_cooldown - delta)
	var w := Vector2.ZERO if busy() else wish.limit_length(1.0)
	if _anim in ["jump", "bodychk", "nutmeg", "rainbow", "bulldozer_clear"] and busy():  # a dodge, body check, skill move or charge: carries on at his speed
		w = velocity / maxf(RUN_SPEED, velocity.length())
	if chaos_lock:
		w = Vector2.ZERO
	var running := velocity.length() > 120.0
	fatigue = clampf(fatigue + (skill("stamina", TIRING[0], TIRING[1]) if running else -RECOVERY) * delta, 1.0 - condition, 1.0)
	var top := top_speed()
	if has_ball():
		top *= skill("dribbling", 0.9, 1.0)
	if dizzy_left > 0.0 and not busy():  # up off the floor, staggering about
		dizzy_left -= delta
		top *= DIZZY_SPEED
		touch_cooldown = maxf(touch_cooldown, 0.1)
	velocity = velocity.move_toward(w * top, accel() * delta)
	position += velocity * delta
	if velocity.length() > 10.0 and not diving():  # a keeper dives sideways, still facing the ball
		facing = Anims.facing_from(velocity)
	elif wish.length() > 0.1 and not busy():
		facing = Anims.facing_from(wish)

	if busy():
		_action_left -= delta
	else:
		_play(_locomotion_anim())
	if has_ball():  # a good dribbler keeps it close
		ball.position = ball.position.lerp(position + Anims.FACING_VECTORS[facing] * skill("dribbling", 16.0, 8.0), 0.6)
		ball.velocity = velocity

	_anim_time += delta
	var f := Anims.frame_at(_anim, facing, _anim_time, not busy())
	_sprite.texture = f.tex
	_sprite.offset = f.offset
	_sprite.flip_h = f.flip
	if not art_material:  # the referee brings his own
		_sprite.material = art_for(_anim)


## His kit for drawing `anim`: our RGBA art, the Rendered player art, or FIFA 96's frames.
func art_for(anim: String) -> Material:
	return _own_kit if Anims.own_art(anim) else _rendered_kit if Anims.rendered(anim) else _kit


func _draw_marks() -> void:
	if charge > 0.0:  # above the head, so the sprite doesn't hide it
		var full := charge >= 1.0
		var c := Supers.LIST.thunder.colour if full else Color(1.0, 0.5 + 0.4 * charge, 0.1)
		_marks.draw_arc(Vector2(0, -56), 9.0, -PI / 2.0, -PI / 2.0 + TAU * minf(charge, 1.0), 32, c, 3.0 if full else 2.0)
	_marks.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	_marks.draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
	if controlled:  # empties as he tires
		_marks.draw_arc(Vector2.ZERO, 12.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - 0.75 * fatigue), 24, marker, 2.0)
	_marks.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # undo the shadow's squash
	if dizzy_left > 0.0:  # stars circling his head
		for i in 3:
			var a := dizzy_left * 6.0 + TAU * i / 3.0
			_marks.draw_circle(Vector2(cos(a) * 9.0, -58.0 + sin(a) * 3.0), 2.0, Color(1.0, 0.9, 0.2))
	if pass_marker.a > 0.0:  # a small arrow over the head
		_marks.draw_colored_polygon(PackedVector2Array([Vector2(-5, -54), Vector2(5, -54), Vector2(0, -47)]), pass_marker)


## Kick the ball toward `target` (pitch position) with the given speed and lift; with `bend`
## (rad, either sign) it leaves that far off the line and curls in onto `target`.
func kick_to(target: Vector2, speed: float, lift: float, anim := "shoot", kind := "shot", bend := 0.0) -> void:
	if not await _wind_up(target, anim, KICK_CONTACT):
		return
	var line := target - ball.position
	ball.kick(line.normalized().rotated(bend) * speed, lift)
	if bend != 0.0:
		ball.curl_to(target, 2.0 * absf(bend) * speed / line.length())
	ball.kick_kind = kind
	if kind in ["pass", "cross"]:
		_past_the_press()


## A pass or cross just played: an opponent right on top of him only sometimes gets a foot to
## it (his interceptions); otherwise it's past him before he can react.
func _past_the_press() -> void:
	for o in opponents.players:
		if o.position.distance_to(position) < Pitch.m(PRESS_BLOCK_M) and randf() > o.skill("interceptions", 0.15, 0.45):
			o.touch_cooldown = maxf(o.touch_cooldown, 0.25)


## Shoot at `target`: finishing (longShots from beyond 20 m, or `stat`) decides how far
## off it goes, shotPower how hard. Long shots and free kicks curl in (curve: how much),
## so a keeper reading the ball's line off the boot reads it wrong.
## Throw-in: the animation shows the ball in the hands (the match hides the real one)
## until it lets go over the head.
func throw_in(target: Vector2, speed: float) -> void:
	var thrown := await _wind_up(target, "throwin", THROW_RELEASE)
	ball.in_hands = false
	if not thrown:
		return
	ball.z = HEAD_HEIGHT
	ball.kick((target - ball.position).normalized() * speed, 110.0)
	ball.kick_kind = "pass"


func shoot(target: Vector2, power := 0.5, stat := "") -> void:
	if stat == "":
		stat = "longShots" if position.distance_to(target) > 20.0 * Pitch.PX_PER_M else "finishing"
	var miss := skill(stat, 55.0, 6.0) * pressure_factor() * foot_factor(target)
	target += Vector2(0.0, randf_range(-miss, miss))
	var speed := lerpf(470.0, 660.0, power) * skill("shotPower", 0.88, 1.12)
	var bend := curl_bend() if stat in ["longShots", "freeKickAccuracy"] else 0.0
	kick_to(target, speed, lerpf(110.0, 170.0, power), "shoot", "shot", bend)


## A free kick over the wall: struck so it clears `wall_top` (pitch pixels up) `wall` pixels
## out from the ball and comes down under the bar at `target`, curled (curve). freeKickAccuracy
## decides how near it goes to where he aims and how well he judges the height: a poor one
## clips the wall or goes over.
func free_kick(target: Vector2, wall: float, wall_top: float) -> void:
	var err := skill("freeKickAccuracy", 16.0, 2.0)
	var miss := skill("freeKickAccuracy", 55.0, 6.0) * foot_factor(target)
	target += Vector2(0.0, randf_range(-miss, miss))
	var d := ball.position.distance_to(target)
	var over := wall_top + 6.0 - randf_range(0.0, err)  # height at the wall: a poor taker clips it
	var under := randf_range(10.0, 34.0) + randf_range(-err, err)  # height at the goal line
	# no air drag: z(t) = lift t - g t^2 / 2 through both heights fixes the speed and the lift
	var u2 := (over / wall - under / d) / (Ball.GRAVITY / 2.0 * (d - wall))
	if d <= wall or u2 <= 0.0:
		shoot(target, 0.8, "freeKickAccuracy")
		return
	var speed := clampf(1.0 / sqrt(u2), 420.0, 900.0)
	var t := wall / speed
	kick_to(target, speed, (over + Ball.GRAVITY / 2.0 * t * t) / t, "shoot", "shot", curl_bend())


## A cross into the box: lofted so it comes down at head height where `mate` is running to,
## whipped in with curve.
func cross_to(mate: Footballer) -> void:
	var speed := clampf(position.distance_to(mate.position) * 1.3, 330.0, 520.0)
	var lead := mate.position + mate.velocity * (KICK_CONTACT + position.distance_to(mate.position) / speed)
	var err := skill("crossing", 50.0, 6.0) * pressure_factor() * foot_factor(lead)
	lead += Vector2(randf_range(-err, err), randf_range(-err, err))
	var t := position.distance_to(lead) / speed
	kick_to(lead, speed, (HEAD_TOP + Ball.GRAVITY * t * t / 2.0) / t, "kick", "cross", curl_bend())


## How far off line (rad, either way) a curled kick of his leaves: curve 40 none, 95 0.3.
func curl_bend() -> float:
	return skill("curve", 0.0, 0.3) * (1.0 if randf() < 0.5 else -1.0)


## Kicking toward `target` more than 20 degrees across his body (to his left for a
## right-footer) is with his weaker foot: aim error x1 with 5 weak-foot stars (or no
## squad) up to x1.6 with 1.
func foot_factor(target: Vector2) -> float:
	var heading: Vector2 = velocity if velocity.length() > 20.0 else Anims.FACING_VECTORS[facing]
	var across := heading.normalized().cross((target - position).normalized())  # < 0: to his left
	if absf(across) < 0.35 or (across < 0.0) == (entry.get("preferred_foot", "right") == "left"):
		return 1.0
	return 1.0 + (5 - int(entry.get("weak_foot", 5))) * 0.15


## How much an opponent close by spoils his aim: 1 with nobody within PRESSURE, up to
## 1.8x (composure 40) or 1.1x (95) with one right on him.
func pressure_factor() -> float:
	var nearest := INF
	if opponents:
		for o in opponents.players:
			nearest = minf(nearest, o.position.distance_to(position))
	var closeness := clampf(1.0 - nearest / PRESSURE, 0.0, 1.0)
	return lerpf(1.0, skill("composure", 1.8, 1.1), closeness)


## Hop over a slide tackle with the ball: safe from tackles for the first part of the
## jump, longer with better reactions. Returns false if he's busy.
func dodge() -> bool:
	if busy():
		return false
	_play_action("jump")
	return true


## Shoulder barge toward where he faces (Chaos special): see Match.body_check.
func body_check() -> bool:
	if busy():
		return false
	_play_action("bodychk")
	_action_left = BODY_CHECK_TIME
	velocity = Anims.FACING_VECTORS[facing] * BODY_CHECK_SPEED
	return true


func body_checking() -> bool:
	return busy() and _anim == "bodychk"


## A skill move (see Match.skill_move): `anim` plays without turning him, and at its
## contact frame the ball leaves with `v` and `up`.
func skill_touch(anim: String, v: Vector2, up: float, kind: String) -> bool:
	if busy():
		return false
	var timing: Array = SKILL_MOVES[anim]
	var played := await _wind_up(position + Anims.FACING_VECTORS[facing], anim, timing[0])
	if _anim == anim:  # not knocked over meanwhile
		_action_left = minf(_action_left, timing[1] - timing[0])
	if played:
		ball.kick(v, up)
		ball.kick_kind = kind
	return played


## In the safe part of a dodge: slides and tackles miss him.
func dodging() -> bool:
	return busy() and _anim == "jump" and _anim_time < skill("reactions", 0.25, 0.45)


## Highest ball (pitch pixels) this player can head.
func head_reach() -> float:
	return HEAD_TOP + skill("jumping", 8.0, 20.0)


## Meet a ball in the air with a header, volley or chest: the animation starts at its
## contact frame, since the ball is already there, and the ball leaves with `v` and `up`.
## No `kind`: chested down, and the match gives him the ball.
func air_touch(anim: String, v := Vector2.ZERO, up := 0.0, kind := "") -> void:
	_play_action(anim, AIR_CONTACT[anim])
	if kind == "":
		return
	facing = Anims.facing_from(v)
	ball.last_touch = self  # before the kick: the match judges offside on it
	ball.kick(v, up)
	ball.kick_kind = kind
	touch_cooldown = 0.35


## Pass to `mate`, ahead of him if he's running: vision decides how far ahead (the ball
## takes about 0.8 s to get there, so even 95 leaves him checking his run a little).
## `space` (px): a through ball, that much further on toward the goal he attacks.
func pass_to(mate: Footballer, space := 0.0) -> void:
	var lead := mate.position + mate.velocity * skill("vision", 0.15, 0.65)
	lead += (mate.team.goal_attacked() - mate.position).normalized() * space
	var dist := position.distance_to(lead)
	var stat := "gkKicking" if role == "G" else "longPassing" if dist > 300.0 else "shortPassing"
	var err := skill(stat, 40.0, 4.0) * pressure_factor() * foot_factor(lead)
	lead += Vector2(randf_range(-err, err), randf_range(-err, err))
	var speed := clampf(dist * 1.6, 220.0, 520.0)
	var lift := 20.0 if dist < 300.0 else 160.0
	if role == "G":  # keepers loft it over the players waiting at the edge of the box, landing at the mate
		lift = Ball.GRAVITY * (dist / speed) / 2.0
	kick_to(lead, speed, lift, "kick", "pass")


## A super-shot (see Supers.LIST) at `target`. The banana starts off wide and bends in.
func super_shot(kind: String, target: Vector2) -> bool:
	var s: Dictionary = Supers.LIST[kind]
	if not await _wind_up(target, s.anim, s.contact):
		return false
	var dir := (target - ball.position).normalized()
	if kind == "banana":
		dir = dir.rotated(0.75 if randf() < 0.5 else -0.75)
	ball.launch_super(kind, dir * s.speed, s.lift, target)
	ball.kick_kind = kind
	return true


## A Chaos line move's kick (see LineMoves): `anim` plays facing `target`, and at
## `contact` seconds the ball leaves toward it with `speed` and `up`.
func move_kick(anim: String, contact: float, target: Vector2, speed: float, up: float, kind: String) -> bool:
	if not await _wind_up(target, anim, contact):
		return false
	ball.kick((target - ball.position).normalized() * speed, up)
	ball.kick_kind = kind
	return true


## Play a kick animation facing `target`; true if the foot still meets the ball (false
## too if he was slid or knocked down meanwhile: another animation took over).
func _wind_up(target: Vector2, anim: String, contact: float) -> bool:
	if busy():
		return false
	facing = Anims.facing_from(target - position)
	_play_action(anim)
	var mine := _actions
	await get_tree().create_timer(contact, false).timeout  # held while the match is paused
	if _actions != mine:
		return false
	if has_ball() or (ball.holder == null and ball.position.distance_to(feet_front()) < REACH * 1.8):
		ball.release()
		ball.last_touch = self
		touch_cooldown = maxf(touch_cooldown, 0.35)
		return true
	return false


func slide() -> void:
	if busy():
		return
	_play_action("slide")
	velocity = Anims.FACING_VECTORS[facing] * 300.0


func sliding() -> bool:
	return _anim == "slide" and busy()


## Goalkeeper dive along `dir` (pitch direction), high or low. He faces the ball and keeps
## that facing through the dive (see _physics_process), going down to his left or right.
## The Rendered art has a dive each way (a left, b right). FIFA 96 only drew dives to the
## left (a and b two of them), mostly sideways into the screen; it plays one of those.
func dive(dir: Vector2, high: bool) -> void:
	if busy():
		return
	var to_ball := ball.position - position
	if to_ball.length() > 1.0:
		facing = Anims.facing_from(to_ball)
	var anim := "ghds" if high else "glds"
	if Anims.rendered(anim + "b"):
		anim += "a" if dir.dot(Anims.FACING_VECTORS[(facing + 6) % 8]) >= 0.0 else "b"  # (facing + 6): his left
	else:
		anim += "a" if randf() < 0.5 else "b"
	_play_action(anim)
	velocity = dir.normalized() * 320.0


func diving() -> bool:
	return busy() and _anim.begins_with("g") and _anim.contains("ds")


## A one-shot animation with no ball involved (dives, celebrations ...).
func perform(anim: String) -> void:
	_play_action(anim)


func _play_action(anim: String, from := 0.0) -> void:
	anim = anim_names.get(anim, anim)
	_actions += 1
	_anim = anim
	_anim_time = from
	_action_left = Anims.length_seconds(anim) - from


func _locomotion_anim() -> String:
	var speed := velocity.length()
	if speed > 120.0:
		return "run"
	if speed > 50.0:
		return "jog"
	if speed > 5.0:
		return "walk"
	return "xstandd"


func _play(anim: String) -> void:
	anim = anim_names.get(anim, anim)
	if anim != _anim:
		_anim = anim
		_anim_time = 0.0
