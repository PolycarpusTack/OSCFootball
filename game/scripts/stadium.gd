class_name Stadium
extends Node3D
## FIFA 96's "Virtual Stadium": the pitch, advertising boards, stands and goals in 3D,
## built from the original textures, seen through a side-on TV camera.
## Units are metres: x along the pitch (0..105), z across it (0..68), y up. The match
## simulates in pitch pixels (Pitch.PX_PER_M); to_screen() maps a pitch point to the
## screen so the 2D sprites can be drawn on top.

const TEX := "res://assets/stadium/"
const BOARD_DIST := 6.0  # advertising boards, metres outside the lines
const STAND_DIST := 8.5  # foot of the stands
const BOARD := Vector2(8.0, 1.0)  # one board texture (128x16) in metres
# our own boards in place of the original ones that advertise the original game; the set is
# used in the order 0 3 6 9 2 5 8 1 4 7, so the long and short ones alternate
const OWN_BOARDS := {5: "res://brand/board_oscf_full.png", 8: "res://brand/board_oscf.png",
	1: "res://brand/board_oscf_full.png", 7: "res://brand/board_oscf.png", 9: "res://brand/board_oscf_long.png"}
const CAM_OFFSET := Vector3(0.0, 15.0, 42.0)  # TV camera relative to what it looks at
const CAM_FOV := 30.0
const CAM_FOLLOW := 3.0  # how quickly the camera catches up, 1/s

var camera := Camera3D.new()
var shake := 0.0  # seconds of camera shake left; set by the match
var club_boards: Array[Texture2D] = []  # the two clubs' boards, mixed in with the originals; set before adding

var _look := Vector3(52.5, 0.0, 34.0)
var _rng := RandomNumberGenerator.new()  # own generator: shaking mustn't change the match's random sequence
var _length := Pitch.LENGTH_M
var _width := Pitch.WIDTH_M


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("7a9ccc")
	add_child(env)
	camera.fov = CAM_FOV
	camera.far = 600.0
	add_child(camera)
	_build_ground()
	_build_boards()
	_build_stands()
	for side in [0, 1]:
		_build_goal(side)
	follow(Pitch.field_rect().get_center(), 0.0)


## Screen position of a pitch point (pixels) at `height_px` above the grass, plus how
## many screen pixels one pitch pixel measures there (in z), for scaling sprites.
func to_screen(p: Vector2, height_px := 0.0) -> Vector3:
	var w := Vector3(p.x, height_px, p.y) / Pitch.PX_PER_M
	var s := camera.unproject_position(w)
	var up := camera.unproject_position(w + Vector3.UP)
	return Vector3(s.x, s.y, s.distance_to(up) / Pitch.PX_PER_M)


## Ease the camera toward the pitch point `focus` (pixels). delta 0 snaps.
func follow(focus: Vector2, delta: float) -> void:
	var target := Vector3(clampf(focus.x / Pitch.PX_PER_M, 14.0, _length - 14.0), 0.0,
		clampf(focus.y / Pitch.PX_PER_M, 18.0, _width - 8.0))
	_look = target if delta == 0.0 else _look.lerp(target, 1.0 - exp(-CAM_FOLLOW * delta))
	camera.position = _look + CAM_OFFSET
	camera.look_at(_look + Vector3(0, 0, -4.0))  # a little beyond the ball: more of the far side in view
	shake = maxf(0.0, shake - delta)
	camera.h_offset = _rng.randf_range(-1, 1) * 0.6 * shake
	camera.v_offset = _rng.randf_range(-1, 1) * 0.6 * shake


func _build_ground() -> void:
	# the 2D pitch drawing (grass texture + markings) baked into one texture
	var outer := Pitch.field_rect().grow(Pitch.m(Pitch.MARGIN_M))
	var vp := SubViewport.new()
	vp.size = Vector2i(outer.size)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	var pitch := Pitch.new()
	pitch.position = -outer.position
	vp.add_child(pitch)
	add_child(vp)
	var mat := _material(null)
	mat.albedo_texture = vp.get_texture()
	var a := Vector3(outer.position.x, 0, outer.position.y) / Pitch.PX_PER_M
	var b := Vector3(outer.end.x, 0, outer.end.y) / Pitch.PX_PER_M
	_quad([a, Vector3(b.x, 0, a.z), b, Vector3(a.x, 0, b.z)], mat)
	_bake_ground(vp, mat)
	# the strip between the boards and the stands
	var track := _material(null)
	track.albedo_color = Color("3e6b2a")
	var m := STAND_DIST + 1.0
	_quad([Vector3(-m - 20, -0.02, -m), Vector3(_length + m + 20, -0.02, -m),
		Vector3(_length + m + 20, -0.02, _width + m), Vector3(-m - 20, -0.02, _width + m)], track)


## Swap the live viewport texture for a mipmapped copy once it has been drawn, so the
## lines don't shimmer in the distance. Headless runs have nothing to copy: keep the live one.
func _bake_ground(vp: SubViewport, mat: StandardMaterial3D) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.generate_mipmaps()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	vp.queue_free()


func _build_boards() -> void:
	var boards: Array[Texture2D] = []
	for i in 10:
		boards.append(load(OWN_BOARDS.get(i, TEX + "board%d.png" % i)))
	var back := _material(null)
	back.albedo_color = Color("202020")
	var d := BOARD_DIST
	# each side as a run of boards facing the pitch: start, direction along, count
	var runs := [
		[Vector3(-d, 0, -d), Vector3.RIGHT, ceili((_length + 2 * d) / BOARD.x)],
		[Vector3(_length + d, 0, _width + d), Vector3.LEFT, ceili((_length + 2 * d) / BOARD.x)],
		[Vector3(-d, 0, _width + d), Vector3.BACK * -1, ceili((_width + 2 * d) / BOARD.x)],
		[Vector3(_length + d, 0, -d), Vector3.BACK, ceili((_width + 2 * d) / BOARD.x)],
	]
	var n := 0
	for r in runs:
		var start: Vector3 = r[0]
		var along: Vector3 = r[1]
		var behind := Vector3.UP.cross(along) * 0.15  # back face, away from the pitch
		for i in r[2]:
			var a: Vector3 = start + along * BOARD.x * i
			var b: Vector3 = a + along * BOARD.x
			var top := Vector3.UP * BOARD.y
			var tex := boards[n % boards.size()]
			if not club_boards.is_empty() and i % 3 == 1:  # every third board: one of the clubs playing
				tex = club_boards[(i / 3) % club_boards.size()]
			_quad([a + top, b + top, b, a], _material(tex))
			_quad([b + top + behind, a + top + behind, a + behind, b + behind], back)
			n += 3  # step through the set so neighbours differ


func _build_stands() -> void:
	var crowd: Array[StandardMaterial3D] = [
		_material(load(TEX + "crowd.png")), _material(load(TEX + "crowd_stairs.png")),
		_material(load(TEX + "crowd.png")), _material(load(TEX + "crowd_tunnel.png")),
	]
	var front := _material(load(TEX + "front.png"))
	var roof := _material(load(TEX + "roof.png"))
	var dark := _material(null)
	dark.albedo_color = Color("1c1c22")
	var s := STAND_DIST
	var corner := 24.0  # stands run on past the corners so no sky shows through
	# [start, direction along the stand, length, roofed]. No stand on the near (camera) side:
	# the camera is always either in front of it (it's behind the camera) or behind it, when
	# play is near that touchline, and then it would hide the pitch.
	var stands := [
		[Vector3(-s - corner, 0, -s), Vector3.RIGHT, _length + 2 * (s + corner), true],
		[Vector3(_length + s, 0, -s), Vector3.BACK, _width + 2 * s, true],
		[Vector3(-s, 0, _width + s), Vector3.FORWARD, _width + 2 * s, true],
	]
	for st in stands:
		var start: Vector3 = st[0]
		var along: Vector3 = st[1]
		var length: float = st[2]
		var out := Vector3.UP.cross(along)  # away from the pitch
		var wall_h := 2.2
		var rise := Vector3.UP * 14.0 + out * 22.0  # crowd terraces from the wall top
		var seg := 12.0  # one crowd texture, metres wide (two tiers tall)
		var count := ceili(length / seg)
		for i in count:
			var a := start + along * seg * i
			var b := start + along * minf(seg * (i + 1), length)
			var k := (b - a).length() / seg
			var up := Vector3.UP * wall_h
			_quad([a + up, b + up, b, a], front, Vector2(k * 1.5, 1.0))
			var mat := crowd[i % crowd.size()] if i % 2 == 0 else crowd[0]
			_quad([a + up + rise, b + up + rise, b + up, a + up], mat, Vector2(k, 2.0))
			var top := up + rise
			_quad([a + top + Vector3.UP * 5.0, b + top + Vector3.UP * 5.0, b + top, a + top], dark)
			if st[3]:  # roof: sloping underside from the back of the stand out over the front rows
				var r0 := top + Vector3.UP * 5.0
				var r1 := up + Vector3.UP * 14.5 + out * 2.0
				_quad([a + r1, b + r1, b + r0, a + r0], roof, Vector2(k * 3.0, 2.0))


func _build_goal(side: int) -> void:
	var x := 0.0 if side == 0 else _length
	var dir := -1.0 if side == 0 else 1.0  # out of the pitch
	var half := 7.32 / 2.0
	var h := 2.44
	var depth := 2.0
	var cz := _width / 2.0
	var white := _material(null)
	white.albedo_color = Color(0.95, 0.95, 0.95)
	for z in [cz - half, cz + half]:
		_box(Vector3(x, h / 2.0, z), Vector3(0.12, h, 0.12), white)
	_box(Vector3(x, h, cz), Vector3(0.12, 0.12, half * 2.0 + 0.12), white)
	var net := _material(load("res://assets/goal/net/004_ball_4.png"))
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bx := x + dir * depth
	var reps := Vector2(half * 2.0 / 1.5, h / 1.5)
	var tl := Vector3(x, h, cz - half)
	var tr := Vector3(x, h, cz + half)
	var btl := Vector3(bx, h * 0.8, cz - half)
	var btr := Vector3(bx, h * 0.8, cz + half)
	var bbl := Vector3(bx, 0, cz - half)
	var bbr := Vector3(bx, 0, cz + half)
	_quad([btl, btr, bbr, bbl], net, reps)  # back
	_quad([tl, tr, btr, btl], net, Vector2(reps.x, depth / 1.5))  # roof
	_quad([tl, btl, bbl, Vector3(x, 0, cz - half)], net, Vector2(depth / 1.5, reps.y))  # sides
	_quad([tr, btr, bbr, Vector3(x, 0, cz + half)], net, Vector2(depth / 1.5, reps.y))


func _material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex:
		m.albedo_texture = tex
	return m


## A textured quad from four corners (top-left, top-right, bottom-right, bottom-left
## as seen from its front), the texture repeated `reps` times.
func _quad(c: Array, mat: Material, reps := Vector2.ONE) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := [Vector2(0, 0), Vector2(reps.x, 0), Vector2(reps.x, reps.y), Vector2(0, reps.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.add_vertex(c[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _box(center: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = center
	add_child(mi)
