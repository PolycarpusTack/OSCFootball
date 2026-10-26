class_name Puppet
extends Node3D
## A footballer in the 3D edition (ADR-005): our Blender footballer
## (tools/blender/footballer_gltf.py), posed from a Footballer's look() in the Stadium's world,
## in metres. It only draws; the match plays in pitch pixels as in the 2D editions.

const MODEL := "res://assets/models/footballer.glb"
const KIT_SHADER := preload("res://scripts/kit3d.gdshader")
const STRIPE := 0.16  # metres, as tools/blender/footballer.py stripes the shirt
const TURN := 12.0  # rad/s he turns toward his facing: the 8 directions, smoothed
## The model's own gaits for the game's: the run is its longer-striding sprint (footballer_gltf.py).
const GAITS := {"run": "sprint", "ref_run": "sprint", "jog": "jog"}
## m/s the planted foot moves back at the drawn pace (measured in Blender, slice 2 S-5): the cycle
## goes on by the ground he covers at this, so the feet don't slide.
const STRIDE := {"sprint": 4.91, "jog": 1.78}
const BLEND := 0.12  # seconds one animation fades into the next
const CHEST := 24.0  # pitch pixels up: the Chaos spin turns him about here, as the sprite does
## The animations drawn only in FIFA 96's art (and the referee's), as the nearest pose the model
## has. Everything else the game plays has its own (tools/blender/footballer.py, ANIMS).
const NEAREST := {
	"angryh": "xstandd", "belly": "fall", "bullref": "xstandd", "celfall": "fall", "collair": "fall",
	"dummyrf": "run", "fwdstnd": "xstandd", "getup": "xstandd", "gguball": "gmdctch", "ggus": "xstandd",
	"gguthit": "xstandd", "ghdball": "gmdctch", "ghithw": "glwthrw", "gldball": "gldsa", "gmoveon": "walk",
	"gpunchsa": "gpunchu", "gpunchsb": "gpunchu", "groin": "fall", "gsidest": "walk", "gstand": "xstandd",
	"gstball": "gmdctch", "gwkball": "walk", "injankl": "fall", "injured": "fall", "kneesld": "slide",
	"limpwlk": "walk", "rcard": "xstandd", "roll": "fall", "rpoint": "xstandd", "strut": "walk",
	"tphyrun": "victrun", "tphystb": "celdnce", "tphystd": "xstandd", "xcupfac": "xstandd",
	"xnswipe": "xstandd", "xrready": "xstandd", "xstand6": "xstandd", "xstand7": "xstandd",
	"xstand9": "xstandd", "xstanda": "xstandd",
	"ref_run": "run", "ref_idle": "xstandd", "ref_point": "xstandd", "ref_whistle": "xstandd", "ref_card": "xstandd",
}

static var _scene: PackedScene

var _body: Node3D  # the model; turned to face, spun and lifted for Chaos
var _player: AnimationPlayer
var _heading := NAN
var _stride := 0.0  # seconds into the gait's cycle at the drawn pace, gone on by distance
var _was := Vector3.INF  # where he was last shown


## `kit` the player's 2D kit material (Footballer, the kit shader's uniforms): its colours.
func _init(kit: ShaderMaterial) -> void:
	if _scene == null:
		_scene = load(MODEL)
	_body = _scene.instantiate()
	add_child(_body)
	_player = _body.find_child("AnimationPlayer", true, false)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_fill_rest(_player)
	_dress(kit)


## The pose for animation `anim` of the game: its own, or the nearest.
static func pose_for(anim: String, library: Array) -> String:
	anim = GAITS.get(anim, anim)
	return anim if anim in library else NEAREST.get(anim, "xstandd")


func animations() -> Array:
	return Array(_player.get_animation_list())


## Posed as `l` (Footballer.look()) shows him; `giant` scales him up as the sprite.
func show_look(l: Array, giant: float) -> void:
	visible = l[7]
	var name := pose_for(l[1], animations())
	var length := _player.get_animation(name).length
	var at := Vector3(l[0].x, 0.0, l[0].y) / Pitch.PX_PER_M
	var moved := at.distance_to(_was) if _was != Vector3.INF else 0.0
	_was = at
	var t: float = l[2]
	if STRIDE.has(name):
		if moved < 2.0:  # not a jump (a reset, a replay's cut)
			_stride += moved / STRIDE[name]
		t = _stride
	t = fposmod(t, length) if l[3] else minf(t, length)
	if _player.assigned_animation != name:
		_player.play(name, BLEND)
		_player.seek(t, false)
		_player.advance(0.0)
	else:
		var step := t - _player.current_animation_position
		if step >= 0.0 and step < 0.25:
			_player.advance(step)  # on in time, so a blend in progress goes on with it
		else:
			_player.seek(t, true)  # looped round, or a replay stepped back
	var face: Vector2 = Anims.FACING_VECTORS[l[4]]
	var want := atan2(-face.x, -face.y)  # the model faces -Z; pitch y is the world's z
	var delta := get_process_delta_time()
	_heading = want if is_nan(_heading) else _heading + clampf(angle_difference(_heading, want), -TURN * delta, TURN * delta)
	position = at
	scale = Vector3.ONE * giant
	# the Chaos spin is in the screen's plane, the camera's side-on: about the world's z
	var pivot := Vector3(0.0, CHEST / Pitch.PX_PER_M, 0.0)
	var spin := Basis(Vector3.BACK, -l[5])
	_body.transform = Transform3D(spin, pivot - spin * pivot + Vector3.UP * l[6] / Pitch.PX_PER_M) \
		* Transform3D(Basis(Vector3.UP, _heading), Vector3.ZERO)


## Each part's material is named after its kit slot (footballer_gltf.py); coloured from `kit`.
func _dress(kit: ShaderMaterial) -> void:
	var colours := {}
	for part in ["shirt", "shirt2", "shorts", "socks", "boots"]:
		colours[part] = _colour(kit, part, Color.WHITE)
	colours.skin = _colour(kit, "skin", Color(0.85, 0.66, 0.48)) if kit.get_shader_parameter("has_skin") else Color(0.85, 0.66, 0.48)
	colours.hair = _colour(kit, "hair", Color(0.2, 0.15, 0.1)) if kit.get_shader_parameter("has_hair") else Color(0.2, 0.15, 0.1)
	var made := {}
	for mesh: MeshInstance3D in _body.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var slot := mesh.mesh.surface_get_material(i).resource_name
			if not made.has(slot):
				var m := ShaderMaterial.new()
				m.shader = KIT_SHADER
				m.set_shader_parameter("colour", colours.get("shirt" if slot == "striped" else slot, Color.MAGENTA))
				if slot == "striped":
					m.set_shader_parameter("colour2", colours.shirt2)
					m.set_shader_parameter("stripe", STRIPE)
				made[slot] = m
			mesh.set_surface_override_material(i, made[slot])


static func _colour(kit: ShaderMaterial, part: String, otherwise: Color) -> Color:
	var v = kit.get_shader_parameter(part)
	return Color(v.x, v.y, v.z) if v is Vector3 else otherwise


## A joint an animation leaves alone (the exporter drops a joint that doesn't move in it) is
## keyed at its rest pose, so nothing carries over from the animation before. Once: the
## animations are shared by every puppet.
static func _fill_rest(player: AnimationPlayer) -> void:
	var lib := player.get_animation_library("")
	if lib.has_meta("filled"):
		return
	var tracks := {}
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		for t in a.get_track_count():
			tracks[[a.track_get_path(t), a.track_get_type(t)]] = true
	var base: Node = player.get_node(player.root_node)
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		for k in tracks:
			if a.find_track(k[0], k[1]) != -1:
				continue
			var joint: Node3D = base.get_node(NodePath(str(k[0])))
			var t := a.add_track(k[1])
			a.track_set_path(t, k[0])
			if k[1] == Animation.TYPE_ROTATION_3D:
				a.rotation_track_insert_key(t, 0.0, joint.quaternion)
			else:
				a.position_track_insert_key(t, 0.0, joint.position)
	lib.set_meta("filled", true)
