class_name Ball
extends Node2D
## Ball on the pitch plane (position) with a height above it (z).

const GRAVITY := 900.0
const ROLL_FRICTION := 1.2  # exponential decay per second while rolling
const BOUNCE := 0.5
const BANANA_TURN := 3.4  # rad/s the banana shot bends toward its target
const SUPER_HEIGHT := 12.0  # fireball / thunder skim along at this height
const TRAIL := 16

signal kicked(speed: float)
signal bounced(speed: float)

const DRAW_SCALE := 0.5  # drawing only: the 16 px frames at full scale were a ball 0.9 m across (4x real)
var velocity := Vector2.ZERO
var z := 0.0
var vz := 0.0
var bounds := Rect2()  # set by the match; the ball bounces off its edges
var holder: Footballer = null  # player dribbling it, if any
var in_hands := false  # not drawn: a throw-in animation draws the ball in the thrower's hands
var last_touch: Footballer = null
var kick_kind := ""  # "pass", "shot" or a super's name, for the last kick
var power := ""  # active super ("fireball", "banana", "thunder") while it's in flight
var power_target := Vector2.ZERO

var _frames: Array[Texture2D] = []
var _roll := 0.0
var _power_time := 0.0
var _trail: Array[Vector3] = []  # recent positions: pitch x, y and height z
var _sprite := Sprite2D.new()
var _fx := Node2D.new()  # shadow, glow and trail
var _to_screen: Callable


## Simulated in pitch pixels like the players; place() puts the visuals on screen.
func _ready() -> void:
	for i in 8:
		_frames.append(load("res://brand/ball/ball_%d.png" % i))
	_sprite.texture = _frames[0]
	_sprite.top_level = true
	_fx.top_level = true
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	add_child(_sprite)


## `to_screen` is Stadium.to_screen (pitch point, height -> screen x, y and scale).
func place(to_screen: Callable) -> void:
	_to_screen = to_screen
	var ground: Vector3 = to_screen.call(position, 0.0)
	var at: Vector3 = to_screen.call(position, z + 2.0)
	_sprite.position = Vector2(at.x, at.y)
	_sprite.scale = Vector2.ONE * at.z * DRAW_SCALE
	_sprite.z_index = clampi(int(ground.y) + 1, -2000, 2000)
	_fx.z_index = _sprite.z_index - 1
	_sprite.visible = not in_hands
	_fx.visible = not in_hands
	_fx.queue_redraw()


func kick(v: Vector2, up: float) -> void:
	velocity = v
	vz = up
	end_power()
	kicked.emit(v.length())


func launch_super(kind: String, v: Vector2, up: float, target: Vector2) -> void:
	velocity = v
	vz = up
	power = kind
	power_target = target
	_power_time = 0.0
	_sprite.modulate = Supers.LIST[kind].colour.lightened(0.3)
	kicked.emit(v.length())


func end_power() -> void:
	power = ""
	_trail.clear()
	_sprite.modulate = Color.WHITE


func take(player: Footballer) -> void:
	holder = player
	last_touch = player
	z = 0.0
	vz = 0.0
	end_power()


func release() -> void:
	holder = null


func stop_at(p: Vector2) -> void:
	holder = null
	in_hands = false
	position = p
	velocity = Vector2.ZERO
	z = 0.0
	vz = 0.0
	end_power()


func _physics_process(delta: float) -> void:
	if holder != null:  # the dribbler positions the ball
		_roll += velocity.length() * delta
		_update_sprite()
		return
	if power != "":
		_super_flight(delta)
	else:
		_normal_flight(delta)
	if bounds.size != Vector2.ZERO:
		if position.x < bounds.position.x or position.x > bounds.end.x:
			velocity.x = -velocity.x * 0.6
			position.x = clampf(position.x, bounds.position.x, bounds.end.x)
			end_power()
		if position.y < bounds.position.y or position.y > bounds.end.y:
			velocity.y = -velocity.y * 0.6
			position.y = clampf(position.y, bounds.position.y, bounds.end.y)
			end_power()
	_roll += velocity.length() * delta
	_update_sprite()


func _normal_flight(delta: float) -> void:
	position += velocity * delta
	if z > 0.0 or vz > 0.0:
		vz -= GRAVITY * delta
		z += vz * delta
		if z <= 0.0:
			z = 0.0
			if absf(vz) > 80.0:
				bounced.emit(absf(vz))
			vz = -vz * BOUNCE if absf(vz) > 80.0 else 0.0
			velocity *= 0.85
	else:
		velocity *= exp(-ROLL_FRICTION * delta)


func _super_flight(delta: float) -> void:
	_power_time += delta
	match power:
		"banana":
			var diff := wrapf((power_target - position).angle() - velocity.angle(), -PI, PI)
			velocity = velocity.rotated(clampf(diff, -BANANA_TURN * delta, BANANA_TURN * delta))
			position += velocity * delta  # no drag while it bends
			if z > 0.0 or vz > 0.0:
				vz -= GRAVITY * delta
				z = maxf(0.0, z + vz * delta)
				if z == 0.0:
					vz = 0.0
		"fireball", "thunder":
			z = move_toward(z, SUPER_HEIGHT, 60.0 * delta)
			vz = 0.0
			position += velocity * delta
			if power == "thunder":  # lightning zig-zag across the line of flight
				position += velocity.orthogonal().normalized() * cos(_power_time * 38.0) * 6.0
	_trail.append(Vector3(position.x, position.y, z + 2.0))
	if _trail.size() > TRAIL:
		_trail.pop_front()
	if _power_time > 3.0 or velocity.length() < 200.0:
		end_power()


func _update_sprite() -> void:
	_sprite.texture = _frames[int(_roll / 6.0) % _frames.size()]


## Drawn in screen space (the trail is projected point by point), so _fx has no transform.
func _draw_fx() -> void:
	if not _to_screen.is_valid():
		return
	var ground: Vector3 = _to_screen.call(position, 0.0)
	var s := ground.z
	if power != "":
		var c: Color = Supers.LIST[power].colour
		var prev := Vector2.ZERO
		for i in _trail.size():
			var k := float(i + 1) / _trail.size()
			var t: Vector3 = _to_screen.call(Vector2(_trail[i].x, _trail[i].y), _trail[i].z)
			var p := Vector2(t.x, t.y)
			if power == "thunder" and i > 0:
				_fx.draw_line(prev, p, Color(1, 1, 1, k), 3.0 * k * s)
			_fx.draw_circle(p, (2.0 + 6.0 * k) * s, Color(c, 0.12 + 0.45 * k))
			prev = p
		_fx.draw_circle(_sprite.position, 11.0 * s, Color(c, 0.35))
	var r := 5.0 * s * clampf(1.0 - z / 300.0, 0.4, 1.0)
	_fx.draw_set_transform(Vector2(ground.x, ground.y), 0.0, Vector2(1.0, 0.45))
	_fx.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
