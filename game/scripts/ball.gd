class_name Ball
extends Node2D
## Ball on the pitch plane (position) with a height above it (z).

const GRAVITY := 900.0
const ROLL_FRICTION := 1.2  # exponential decay per second while rolling
const BOUNCE := 0.5
const CRAZY_BOUNCE := 0.85  # the crazy bounce modifier: livelier, and off at an angle
const BANANA_TURN := 3.4  # rad/s the banana shot bends toward its target
const SUPER_HEIGHT := 12.0  # fireball / thunder skim along at this height
const TRAIL := 16
const ZIG_ZAG := 9.5  # px either side: what the old 6 px a tick at 60 ticks/s swung

signal kicked(speed: float)
signal bounced(speed: float)

const RADIUS_3D := 0.2  # metres: the 3D edition's ball, about twice real like the sprite, to be seen
const BALL_SHADER := preload("res://scripts/ball3d.gdshader")
const DRAW_SCALE := 0.5  # drawing only: the 16 px frames at full scale were a ball 0.9 m across (4x real)
var velocity := Vector2.ZERO
var z := 0.0
var vz := 0.0
var bounds := Rect2()  # set by the match; the ball bounces off its edges
var mouth := Vector2.ZERO  # indoors: half the goal's width and the net's depth, where it goes past the ends
var mouth_height := 0.0  # ... under the bar
var holder: Footballer = null  # player dribbling it, if any
var in_hands := false  # not drawn: a throw-in animation draws the ball in the thrower's hands
var last_touch: Footballer = null
var kick_kind := ""  # "pass", "shot" or a super's name, for the last kick
var power := ""  # active super ("fireball", "banana", "thunder") while it's in flight
var power_target := Vector2.ZERO
var prev_position := Vector2.ZERO  # before this frame's step: the match checks the goal frame against it
var prev_z := 0.0
var touch_revision := 0  # cancels Chaos flight effects on any kick, catch or reset
var curl := 0.0  # rad/s a curled kick turns toward curl_target; 0 once it's on line (see curl_to)
var curl_target := Vector2.ZERO

var _frames: Array[Texture2D] = []
var _roll := 0.0
var _power_time := 0.0
var _zig := 0.0  # Thunder Strike: how far off its line of flight the zig-zag has it now
var _trail: Array[Vector3] = []  # recent positions: pitch x, y and height z
var _sprite := Sprite2D.new()
var _fx := Node2D.new()  # shadow, glow and trail
var _to_screen: Callable
var puppet: MeshInstance3D = null  # the 3D edition's ball (Match.solid), made by the match
var _spin := Basis.IDENTITY  # its roll
var _was := Vector2.INF  # where it was drawn last, for the roll


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
	_place_at(position, z, in_hands, to_screen)
	_fx.visible = not in_hands
	_fx.queue_redraw()


func _place_at(at_pitch: Vector2, height: float, hidden: bool, to_screen: Callable) -> void:
	var ground: Vector3 = to_screen.call(at_pitch, 0.0)
	var at: Vector3 = to_screen.call(at_pitch, height + 2.0)
	_sprite.position = Vector2(at.x, at.y)
	_sprite.scale = Vector2.ONE * at.z * DRAW_SCALE
	_sprite.z_index = clampi(int(ground.y) + 1, -2000, 2000)
	_fx.z_index = _sprite.z_index - 1
	var solid := Match.solid and puppet != null
	_sprite.visible = not hidden and not solid
	if puppet:
		puppet.visible = solid and not hidden
		_roll_puppet(at_pitch, height)


## The 3D ball, at `at_pitch` and `height` (pitch pixels), turned by how far it has gone.
func _roll_puppet(at_pitch: Vector2, height: float) -> void:
	var r := RADIUS_3D
	var moved := (at_pitch - _was) / Pitch.PX_PER_M if _was != Vector2.INF else Vector2.ZERO
	_was = at_pitch
	if moved.length() > 0.0001 and moved.length() < 5.0:  # a jump (a reset, a replay's cut) doesn't spin it
		_spin = Basis(Vector3(-moved.y, 0.0, moved.x).normalized(), -moved.length() / r) * _spin
		_spin = _spin.orthonormalized()
	puppet.transform = Transform3D(_spin, Vector3(at_pitch.x, height, at_pitch.y) / Pitch.PX_PER_M + Vector3.UP * r)


func make_puppet() -> MeshInstance3D:
	puppet = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS_3D
	sphere.height = RADIUS_3D * 2.0
	puppet.mesh = sphere
	var m := ShaderMaterial.new()
	m.shader = BALL_SHADER
	puppet.material_override = m
	return puppet


## For a replay: [where, how high, in someone's hands].
func look() -> Array:
	return [position, z, in_hands]


## Drawn as it was (`l` from look()); the ball itself stays where it is. No shadow or trail.
func show_look(l: Array, to_screen: Callable) -> void:
	_place_at(l[0], l[1], l[2], to_screen)
	_fx.visible = false


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
	_zig = 0.0
	_sprite.modulate = Supers.LIST[kind].colour.lightened(0.3)
	kicked.emit(v.length())


## Bend toward `target` at `rate` rad/s until the ball is on line for it. Kicked `bend` rad
## off that line, 2 x bend / flight time traces the arc that comes in on target (Footballer.kick_to).
func curl_to(target: Vector2, rate: float) -> void:
	curl = rate
	curl_target = target


func end_power() -> void:
	touch_revision += 1
	curl = 0.0
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
	prev_position = position
	prev_z = z
	if holder != null:  # the dribbler positions the ball
		_roll += velocity.length() * delta
		_update_sprite()
		return
	if power != "":
		_super_flight(delta)
	else:
		_normal_flight(delta)
	if bounds.size != Vector2.ZERO:
		var lo := bounds.position.x
		var hi := bounds.end.x
		var cy := bounds.get_center().y
		if mouth != Vector2.ZERO and absf(position.y - cy) < mouth.x and z < mouth_height:  # into the net
			lo -= mouth.y
			hi += mouth.y
		if position.x < lo or position.x > hi:
			velocity.x = -velocity.x * 0.6
			position.x = clampf(position.x, lo, hi)
			end_power()
		if mouth != Vector2.ZERO and (position.x < bounds.position.x or position.x > bounds.end.x):
			position.y = clampf(position.y, cy - mouth.x, cy + mouth.x)  # the side netting
		if position.y < bounds.position.y or position.y > bounds.end.y:
			velocity.y = -velocity.y * 0.6
			position.y = clampf(position.y, bounds.position.y, bounds.end.y)
			end_power()
	_roll += velocity.length() * delta
	_update_sprite()


## Where the ball will be when it next comes down through `height` (pitch pixels); where
## it is now if it won't (on the ground, or never that high).
func coming_down(height: float) -> Vector2:
	if holder != null or power != "" or (z <= height and vz <= 0.0):
		return position
	var disc := vz * vz + 2.0 * GRAVITY * (z - height)
	if disc < 0.0:
		return position
	return position + velocity * (vz + sqrt(disc)) / GRAVITY


func _normal_flight(delta: float) -> void:
	if curl > 0.0:
		var diff := wrapf((curl_target - position).angle() - velocity.angle(), -PI, PI)
		velocity = velocity.rotated(clampf(diff, -curl * delta, curl * delta))
		if absf(diff) <= curl * delta:
			curl = 0.0  # on line: it flies straight from here
	position += velocity * delta
	if z > 0.0 or vz > 0.0:
		vz -= GRAVITY * delta
		z += vz * delta
		if z <= 0.0:
			z = 0.0
			if absf(vz) > 80.0:
				bounced.emit(absf(vz))
			var crazy := Match.modifier("crazy bounce")
			vz = -vz * (CRAZY_BOUNCE if crazy else BOUNCE) if absf(vz) > 80.0 else 0.0
			velocity *= 0.85
			if crazy and vz > 0.0:
				velocity = velocity.rotated(randf_range(-0.6, 0.6))
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
			if power == "thunder":  # lightning zig-zag across the line of flight, by flight time (slow-mo too)
				var zig := sin(_power_time * 38.0) * ZIG_ZAG
				position += velocity.orthogonal().normalized() * (zig - _zig)
				_zig = zig
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
	if not (Match.solid and puppet):  # the 3D ball casts its own (Stadium.light_bodies)
		_fx.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
