class_name Footballer
extends Node2D
## One player's body: movement, animation, carrying and kicking the ball.
## Who decides what to do (human input or AI) is up to the match: it sets
## `wish` every frame and calls shoot() / pass_to().

const RUN_SPEED := 170.0
const ACCEL := 900.0
const REACH := 14.0
const KICK_CONTACT := 0.15  # seconds into a kick animation the foot meets the ball
const MARKER := Color(1.0, 0.95, 0.3)

var team: Team
var role := "M"  # G, D, M or F
var number := 0
var home := Vector2.ZERO  # formation spot as a pitch fraction (see Team.FORMATION)
var ball: Ball
var controlled := false
var speed_factor := 1.0
var wish := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 4
var touch_cooldown := 0.0  # can't take the ball while > 0 (just kicked or lost it)
var think_timer := 0.0  # AI: time until the next pass/shoot decision
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
	_sprite.material = team.keeper_material if role == "G" else team.outfield_material
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


func _physics_process(delta: float) -> void:
	touch_cooldown = maxf(0.0, touch_cooldown - delta)
	var w := Vector2.ZERO if busy() else wish.limit_length(1.0)
	velocity = velocity.move_toward(w * RUN_SPEED * speed_factor, ACCEL * delta)
	position += velocity * delta
	if velocity.length() > 10.0:
		facing = Anims.facing_from(velocity)
	elif wish.length() > 0.1 and not busy():
		facing = Anims.facing_from(wish)

	if busy():
		_action_left -= delta
	else:
		_play(_locomotion_anim())
	if has_ball():
		ball.position = ball.position.lerp(feet_front(), 0.6)
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
		_marks.draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, MARKER, 2.0)


## Kick the ball toward `target` (pitch position) with the given speed and lift.
func kick_to(target: Vector2, speed: float, lift: float, anim := "shoot", kind := "shot") -> void:
	if not await _wind_up(target, anim, KICK_CONTACT):
		return
	ball.kick((target - ball.position).normalized() * speed, lift)
	ball.kick_kind = kind


func shoot(target: Vector2, power := 0.5) -> void:
	kick_to(target, lerpf(470.0, 660.0, power), lerpf(110.0, 170.0, power), "shoot", "shot")


func pass_to(mate: Footballer) -> void:
	var lead := mate.position + mate.velocity * 0.4
	var dist := position.distance_to(lead)
	kick_to(lead, clampf(dist * 1.6, 220.0, 520.0), 20.0 if dist < 300.0 else 160.0, "kick", "pass")


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


func _play_action(anim: String) -> void:
	_anim = anim
	_anim_time = 0.0
	_action_left = Anims.length_seconds(anim)


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
