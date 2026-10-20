class_name Footballer
extends Node2D
## One player's body: movement, animation, carrying and kicking the ball.
## Who decides what to do (human input or AI) is up to the match: it sets
## `wish` every frame and calls shoot() / pass_to().

const RUN_SPEED := 170.0
const ACCEL := 900.0
const REACH := 14.0
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
const SKILL_MOVES := {"nutmeg": [0.4, 0.7], "rainbow": [0.45, 0.75], "bckheel": [0.4, 0.7]}

var team: Team
var opponents: Team  # the other side, for how pressed he is
var role := "M"  # G, D, M or F
var number := 0
var display_name := ""  # shown in the HUD (the node name stays unique: "BRU 7")
var portrait: Texture2D  # pixel portrait for the HUD, or null
var stats := {}  # EA SPORTS FC ratings by name (data/squads.json), empty without a squad
var skin := Color.TRANSPARENT  # from the player's photo; transparent: FIFA 96's default
var hair := Color.TRANSPARENT
var pass_marker := Color.TRANSPARENT  # set while a human's pass would go to this player
var home := Vector2.ZERO  # formation spot as a pitch fraction (see Team.FORMATION)
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

var _anim := "xstandd"
var _anim_time := 0.0
var _action_left := 0.0  # while > 0 a one-shot animation plays and movement is ignored
var _sprite := Sprite2D.new()
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
	_sprite.material = kit
	_sprite.top_level = true
	_marks.top_level = true
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	add_child(_sprite)


## `screen` from Stadium.to_screen(): x, y on screen and the scale there in z.
func place(screen: Vector3) -> void:
	var at := Vector2(screen.x, screen.y)
	_sprite.position = at
	_sprite.scale = Vector2.ONE * screen.z
	_sprite.z_index = clampi(int(at.y), -2000, 2000)
	_marks.position = at
	_marks.scale = _sprite.scale
	_marks.z_index = _sprite.z_index - 1
	_marks.queue_redraw()


func has_ball() -> bool:
	return ball != null and ball.holder == self


func busy() -> bool:
	return _action_left > 0.0


func feet_front() -> Vector2:
	return position + Anims.FACING_VECTORS[facing] * 10.0


## A rating (EA SPORTS FC, 0-99) mapped onto lo..hi: 40 or less gives lo, 95 or more hi.
## Without ratings (no squad loaded) a player is average: halfway, today's behaviour.
func skill(stat: String, lo: float, hi: float) -> float:
	var v: float = stats.get(stat, 67.5)
	return lerpf(lo, hi, clampf((v - 40.0) / 55.0, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	touch_cooldown = maxf(0.0, touch_cooldown - delta)
	var w := Vector2.ZERO if busy() else wish.limit_length(1.0)
	if _anim in ["jump", "bodychk", "nutmeg", "rainbow"] and busy():  # a dodge, body check or skill move: carries on at his speed
		w = velocity / maxf(RUN_SPEED, velocity.length())
	var top := RUN_SPEED * speed_factor * skill("sprintSpeed", 0.86, 1.14)
	if has_ball():
		top *= skill("dribbling", 0.9, 1.0)
	velocity = velocity.move_toward(w * top, ACCEL * skill("acceleration", 0.75, 1.25) * skill("agility", 0.85, 1.15) * delta)
	position += velocity * delta
	if velocity.length() > 10.0:
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


func _draw_marks() -> void:
	if charge > 0.0:  # above the head, so the sprite doesn't hide it
		var full := charge >= 1.0
		var c := Supers.LIST.thunder.colour if full else Color(1.0, 0.5 + 0.4 * charge, 0.1)
		_marks.draw_arc(Vector2(0, -56), 9.0, -PI / 2.0, -PI / 2.0 + TAU * minf(charge, 1.0), 32, c, 3.0 if full else 2.0)
	_marks.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	_marks.draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
	if controlled:
		_marks.draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, marker, 2.0)
	if pass_marker.a > 0.0:  # a small arrow over the head (undo the shadow's squash first)
		_marks.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_marks.draw_colored_polygon(PackedVector2Array([Vector2(-5, -54), Vector2(5, -54), Vector2(0, -47)]), pass_marker)


## Kick the ball toward `target` (pitch position) with the given speed and lift.
func kick_to(target: Vector2, speed: float, lift: float, anim := "shoot", kind := "shot") -> void:
	if not await _wind_up(target, anim, KICK_CONTACT):
		return
	ball.kick((target - ball.position).normalized() * speed, lift)
	ball.kick_kind = kind


## Shoot at `target`: finishing (longShots from beyond 20 m, or `stat`) decides how far
## off it goes, shotPower how hard.
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
	var miss := skill(stat, 55.0, 6.0) * pressure_factor()
	target += Vector2(0.0, randf_range(-miss, miss))
	var speed := lerpf(470.0, 660.0, power) * skill("shotPower", 0.88, 1.12)
	kick_to(target, speed, lerpf(110.0, 170.0, power), "shoot", "shot")


## A cross into the box: lofted so it comes down at head height where `mate` is running to.
func cross_to(mate: Footballer) -> void:
	var speed := clampf(position.distance_to(mate.position) * 1.3, 330.0, 520.0)
	var lead := mate.position + mate.velocity * (KICK_CONTACT + position.distance_to(mate.position) / speed)
	var err := skill("crossing", 50.0, 6.0) * pressure_factor()
	lead += Vector2(randf_range(-err, err), randf_range(-err, err))
	var t := position.distance_to(lead) / speed
	kick_to(lead, speed, (HEAD_TOP + Ball.GRAVITY * t * t / 2.0) / t, "kick", "cross")


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
func skill_touch(anim: String, v: Vector2, up: float, kind: String) -> void:
	if busy():
		return
	var timing: Array = SKILL_MOVES[anim]
	var played := await _wind_up(position + Anims.FACING_VECTORS[facing], anim, timing[0])
	_action_left = minf(_action_left, timing[1] - timing[0])
	if played:
		ball.kick(v, up)
		ball.kick_kind = kind


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
	ball.kick(v, up)
	ball.kick_kind = kind
	ball.last_touch = self
	touch_cooldown = 0.35


func pass_to(mate: Footballer) -> void:
	var lead := mate.position + mate.velocity * 0.4
	var dist := position.distance_to(lead)
	var stat := "gkKicking" if role == "G" else "longPassing" if dist > 300.0 else "shortPassing"
	var err := skill(stat, 40.0, 4.0) * pressure_factor()
	lead += Vector2(randf_range(-err, err), randf_range(-err, err))
	var speed := clampf(dist * 1.6, 220.0, 520.0)
	var lift := 20.0 if dist < 300.0 else 160.0
	if role == "G":  # keepers loft it over the players waiting at the edge of the box, landing at the mate
		lift = Ball.GRAVITY * (dist / speed) / 2.0
	kick_to(lead, speed, lift, "kick", "pass")


## A super-shot (see Supers.LIST) at `target`. The banana starts off wide and bends in.
func super_shot(kind: String, target: Vector2) -> void:
	var s: Dictionary = Supers.LIST[kind]
	if not await _wind_up(target, s.anim, s.contact):
		return
	var dir := (target - ball.position).normalized()
	if kind == "banana":
		dir = dir.rotated(0.75 if randf() < 0.5 else -0.75)
	ball.launch_super(kind, dir * s.speed, s.lift, target)
	ball.kick_kind = kind


## Play a kick animation facing `target`; true if the foot still meets the ball.
func _wind_up(target: Vector2, anim: String, contact: float) -> bool:
	if busy():
		return false
	facing = Anims.facing_from(target - position)
	_play_action(anim)
	await get_tree().create_timer(contact).timeout
	if has_ball() or (ball.holder == null and ball.position.distance_to(feet_front()) < REACH * 1.8):
		ball.release()
		ball.last_touch = self
		touch_cooldown = 0.35
		return true
	return false


func slide() -> void:
	if busy():
		return
	_play_action("slide")
	velocity = Anims.FACING_VECTORS[facing] * 300.0


func sliding() -> bool:
	return _anim == "slide" and busy()


## Goalkeeper dive along `dir` (pitch direction), high or low.
func dive(dir: Vector2, high: bool) -> void:
	if busy():
		return
	_play_action(("ghds" if high else "glds") + ("a" if randf() < 0.5 else "b"))
	velocity = dir.normalized() * 320.0


func diving() -> bool:
	return busy() and _anim.begins_with("g") and _anim.contains("ds")


## A one-shot animation with no ball involved (dives, celebrations ...).
func perform(anim: String) -> void:
	_play_action(anim)


func _play_action(anim: String, from := 0.0) -> void:
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
	if anim != _anim:
		_anim = anim
		_anim_time = 0.0
