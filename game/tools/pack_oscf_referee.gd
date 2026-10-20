extends SceneTree
## Package the referee sheets for the match: one strip per animation plus animations.json,
## in the same layout as the FIFA 96 player sheets (see AnimLibrary), so the referee draws
## through the same code. Also the effects sheet, for Effects: one strip and effects.json.
## Run after prepare_oscf_referee_sources.gd:
##
##     godot --headless --path game -s res://tools/pack_oscf_referee.gd

const ROOT := "res://assets/sprites/oscf_roles/"
const OUT := ROOT + "referee/"
const EFFECTS_OUT := ROOT + "effects/"
## sheet -> animation name in the game
const SHEETS := {"referee_idle": "ref_idle", "referee_run": "ref_run", "referee_whistle": "ref_whistle",
	"referee_card": "ref_card", "referee_point": "ref_point"}
## The FIFA 96 players stand with their feet 46 px below the top of the head; the referee
## sources stand 180 px tall.
const SCALE := 46.0 / 180.0
## drawn direction as AnimLibrary numbers them: away, up-right, right, down-right, toward camera
const DIRECTION := {"n": 0, "ne": 2, "e": 4, "se": 6, "s": 8}
const TICKS_PER_SECOND := 30.0  # AnimLibrary.TICKS_PER_SECOND


func _initialize() -> void:
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source_regions.json")).sheets
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var index := {}
	for sheet: String in SHEETS:
		var anim: String = SHEETS[sheet]
		var spec: Dictionary = regions[sheet]
		var source := Image.load_from_file(ROOT + sheet + ".png")
		source.convert(Image.FORMAT_RGBA8)
		var ticks := TICKS_PER_SECOND / float(spec.animations[sheet].fps)
		var strip := _pack(source, spec, ticks)
		if strip.image.save_png(OUT + anim + ".png") != OK:
			push_error("Could not save " + OUT + anim + ".png")
			quit(1)
			return
		index[anim] = strip.meta
	var file := FileAccess.open(OUT + "animations.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(index))
	print("Packed referee: ", index.keys())
	if not _pack_effects(regions.effects):
		quit(1)
		return
	quit()


## The effects sheet at the players' scale: every frame side by side in effects.png, and
## effects.json mapping each effect to {fps, frames: [{x, y, w, h, ax, ay}]}.
func _pack_effects(spec: Dictionary) -> bool:
	var source := Image.load_from_file(ROOT + "effects.png")
	source.convert(Image.FORMAT_RGBA8)
	var dust_row := int(spec.animations.dust_puff.row)
	var dust_ground := 0.0  # the dust rises from the ground: its frames stand on their lowest point
	for f: Dictionary in spec.frames:
		if int(f.row) == dust_row:
			dust_ground = maxf(dust_ground, f.rect[1] + f.rect[3])
	var sprites := []
	for f: Dictionary in spec.frames:
		var r: Array = f.rect
		var anchor: Array = f.anchor
		var ground: float = dust_ground if int(f.row) == dust_row else anchor[1]
		sprites.append({"image": _cut(source, r), "row": int(f.row), "column": int(f.column),
			"ax": roundi((anchor[0] - r[0]) * SCALE), "ay": roundi((ground - r[1]) * SCALE)})
	var width := 0
	var height := 0
	for s: Dictionary in sprites:
		width += s.image.get_width() + 1
		height = maxi(height, s.image.get_height())
	var strip := Image.create(width, height, false, Image.FORMAT_RGBA8)
	strip.fill(Color.TRANSPARENT)
	var index := {}
	var x := 0
	for name: String in spec.animations:
		var a: Dictionary = spec.animations[name]
		var frames := []
		for s: Dictionary in sprites.filter(func(s): return s.row == int(a.row)):
			var img: Image = s.image
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))
			frames.append({"x": x, "y": 0, "w": img.get_width(), "h": img.get_height(), "ax": s.ax, "ay": s.ay, "column": s.column})
			x += img.get_width() + 1
		frames.sort_custom(func(p, q): return p.column < q.column)
		for f: Dictionary in frames:
			f.erase("column")
		index[name] = {"fps": a.fps, "frames": frames}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECTS_OUT))
	if strip.save_png(EFFECTS_OUT + "effects.png") != OK:
		push_error("Could not save " + EFFECTS_OUT + "effects.png")
		return false
	var file := FileAccess.open(EFFECTS_OUT + "effects.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(index))
	print("Packed effects: ", index.keys())
	return true


## Every frame of one sheet, scaled down and laid side by side. Returns {image, meta}:
## meta maps drawn direction -> frames {x, y, w, h, ax, ay, t} in AnimLibrary's format.
func _pack(source: Image, spec: Dictionary, ticks: float) -> Dictionary:
	var sprites := []
	for f: Dictionary in spec.frames:
		var r: Array = f.rect
		var anchor: Array = f.anchor
		sprites.append({"image": _cut(source, r), "dir": DIRECTION[spec.directions[int(f.column)]], "row": int(f.row),
			"ax": roundi((anchor[0] - r[0]) * SCALE), "ay": roundi((anchor[1] - r[1]) * SCALE)})
	var width := 0
	var height := 0
	for s: Dictionary in sprites:
		width += s.image.get_width() + 1
		height = maxi(height, s.image.get_height())
	var strip := Image.create(width, height, false, Image.FORMAT_RGBA8)
	strip.fill(Color.TRANSPARENT)
	var meta := {}
	var x := 0
	for s: Dictionary in sprites:
		var img: Image = s.image
		strip.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))
		var frames: Array = meta.get_or_add(str(s.dir), [])
		frames.append({"x": x, "y": 0, "w": img.get_width(), "h": img.get_height(), "ax": s.ax, "ay": s.ay,
			"t": 1 + roundi(s.row * ticks)})
		x += img.get_width() + 1
	for frames: Array in meta.values():
		frames.sort_custom(func(a, b): return a.t < b.t)
	return {"image": strip, "meta": meta}


## The frame at `r` in `source`, scaled to the players' size with hard edges.
func _cut(source: Image, r: Array) -> Image:
	var sprite := source.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	var size := Vector2i(maxi(1, roundi(r[2] * SCALE)), maxi(1, roundi(r[3] * SCALE)))
	sprite.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in size.y:  # resampling leaves a faint halo; the match draws hard edges
		for x in size.x:
			var c := sprite.get_pixel(x, y)
			if c.a < 0.5:
				c = Color.TRANSPARENT
			elif c.g > 0.45 and c.r < c.g * 0.45 and c.b < c.g * 0.45:  # the card's key, as prepare_oscf_referee_sources.gd
				c = Color(0, 1, 0)
			else:
				c.a = 1.0
			sprite.set_pixel(x, y, c)
	return sprite
