extends SceneTree
## The player art: Pixel draws FIFA 96's sprites; Rendered draws the animations rendered by
## tools/blender (the everyday ones, the specials' and the Chaos line moves) through their
## own palette in the player's kit, and falls back to FIFA 96's for the rest. In Pixel the line
## moves play a FIFA 96 stand-in. The match options and the pause menu switch it.
## godot --headless --path game -s res://tests/rendered_test.gd

const RENDERED := ["run", "jog", "xstandd", "kick", "vollkck", "bicycle", "tackle", "header", "nutmeg",
	"mark", "fall", "gpound", "glwthrw", "gpunchu", "power_strike", "bulldozer_clear", "grapple_tackle",
	"laser_pass", "whirlwind_turn", "cannon_punt", "rising_fist", "stepover_storm", "walk", "shoot", "slide",
	"throwin", "jump", "chest", "stumble", "push", "bodychk", "divehed", "ghdsa", "ghdsb", "gldsa", "gldsb",
	"glwctch", "gmdctch", "gjmctch", "gdkick", "bckheel", "rainbow", "aeropla", "victrun", "celdnce", "celdnc2",
	"celdpnc", "duckflp", "vctflip"]

var m: Node
var match_script: GDScript  # Match; the class can't be named here


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	match_script = m.get_script()
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the play
	m._state_left = 1e9
	var anims = root.get_node("Anims")
	var p = m.home.players[6]
	var ok := true

	# Pixel: FIFA 96's frames and palette
	match_script.rendered = false
	var pixel := _drawn(p, "run")
	print("pixel run: %s, palette %s" % [pixel.sheet, pixel.palette])
	ok = ok and "players/" in pixel.sheet and "players/" in pixel.palette
	var strike := _drawn(p, "power_strike")
	print("pixel power_strike: %s, palette %s" % [strike.sheet, strike.palette])
	ok = ok and "players/" in strike.sheet and "players/" in strike.palette

	# Rendered: our frames, our palette, the same kit colours; for every rendered animation
	match_script.rendered = true
	for anim in RENDERED:
		var d := _drawn(p, anim)
		var kit_kept: bool = p.art_for(anim).get_shader_parameter("shirt") == p._kit.get_shader_parameter("shirt")
		print("rendered %s: %s, palette %s, kit kept %s" % [anim, d.sheet, d.palette, kit_kept])
		ok = ok and anims.rendered(anim) and "oscf_rendered/" in d.sheet and "oscf_rendered/" in d.palette and kit_kept

	# not rendered yet: FIFA 96's frames with FIFA 96's palette
	var dummy := _drawn(p, "dummyrf")
	print("rendered, dummyrf (not rendered): %s, palette %s" % [dummy.sheet, dummy.palette])
	ok = ok and not anims.rendered("dummyrf") and "players/" in dummy.sheet and "players/" in dummy.palette

	# every rendered animation has the five drawn directions and FIFA 96's length
	for anim in RENDERED:
		var dirs: Array = anims._rendered[anim].keys()
		dirs.sort()
		var length: float = anims.length_seconds(anim)
		match_script.rendered = false
		var pixel_length: float = anims.length_seconds(anim)
		match_script.rendered = true
		print("%s: directions %s, %.2f s (pixel %.2f s)" % [anim, dirs, length, pixel_length])
		ok = ok and dirs == [0, 2, 4, 6, 8] and is_equal_approx(length, pixel_length)

	# a keeper's dive: facing the ball in both arts; Rendered, down to the side the dive goes
	var keeper = m.home.keeper()
	var ball_at: Vector2 = m.ball.position
	for rendered in [true, false]:
		match_script.rendered = rendered
		for side in [-1.0, 1.0]:
			keeper._action_left = 0.0
			keeper.position = ball_at - Vector2(100.0, 0.0)  # the ball to his right on screen: he faces right
			keeper.velocity = Vector2.ZERO
			keeper.dive(Vector2(0.0, side), true)  # up the screen is his left
			keeper._physics_process(0.05)
			var anim: String = keeper._anim
			var good: bool
			if rendered:
				good = keeper.facing == 2 and anim == ("ghdsa" if side < 0.0 else "ghdsb")
			else:  # FIFA 96's dives all go to his left
				good = anim.begins_with("ghds") and keeper.facing == 2
			print("%s dive %s: %s, facing %d" % ["rendered" if rendered else "pixel", "up" if side < 0.0 else "down", anim, keeper.facing])
			ok = ok and good
	keeper._action_left = 0.0
	match_script.rendered = true

	# the F1 animation viewer draws the Rendered art through its own palette too
	var viewer = load("res://scripts/anim_viewer.gd").new()
	root.add_child(viewer)
	await process_frame
	viewer._index = viewer._names.find("kick")
	viewer._process(0.0)
	var viewer_palette: Texture2D = viewer._sprites[2].material.get_shader_parameter("palette")
	print("viewer, rendered kick: palette %s, label '%s'" % [viewer_palette.resource_path, viewer._label.text.get_slice("\n", 0)])
	ok = ok and "oscf_rendered/" in viewer_palette.resource_path and "[Rendered]" in viewer._label.text
	viewer.queue_free()

	# the match options switch it
	var options = load("res://scripts/match_options.gd").new()
	root.add_child(options)
	await process_frame
	options._row = 8
	options._change(1)  # Rendered -> 3D (slice 2: PIXEL, RENDERED, 3D)
	var three_d: Array = options._rows()[8]
	var solid: bool = match_script.solid and match_script.rendered
	options._change(1)  # -> Pixel
	var after_options: bool = match_script.rendered or match_script.solid
	print("match options, PLAYERS row: %s, then %s" % [three_d, options._rows()[8]])
	ok = ok and three_d == ["PLAYERS", "3D"] and solid and options._rows()[8] == ["PLAYERS", "PIXEL"] and not after_options
	# P-1-AC2: the font follows it, on a Label already on screen: Pixelify Sans for Pixel, Exo 2 for Rendered
	var shown: Label = options._labels[0]
	var font = shown.get_theme_font("font")
	var pixel_font: String = font.resource_path if font is FontFile else font.base_font.resource_path
	options._change(1)
	var rendered_font: String = shown.get_theme_font("font").base_font.resource_path
	options._change(1)
	options._change(1)  # past 3D, back to Pixel
	var heading = options.get_child(1).get_theme_font("font")  # MATCH OPTIONS
	print("font: Pixel %s (heading %s), Rendered %s" % [pixel_font.get_file(), heading.base_font.resource_path.get_file(), rendered_font.get_file()])
	ok = ok and pixel_font.ends_with("OSCFJersey.ttf") and rendered_font.ends_with("Exo2-Italic.ttf") \
		and heading.base_font.resource_path.ends_with("PixelifySans.ttf")
	options.queue_free()

	# and so does the pause menu, mid-match
	var pause
	for c in m.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"):
			pause = c
	pause._pick = pause.ITEMS.find("PLAYERS")
	pause._choose()
	print("pause menu PLAYERS: rendered %s, row '%s'" % [match_script.rendered, pause._rows[pause._pick].text])
	ok = ok and match_script.rendered and "RENDERED" in pause._rows[pause._pick].text

	match_script.rendered = false
	print("RENDERED TEST PASSED" if ok else "RENDERED TEST FAILED")
	quit(0 if ok else 1)


## {sheet, palette} `p` draws `anim` from: its frame (facing right) and his kit for it.
func _drawn(p, anim: String) -> Dictionary:
	var f: Dictionary = root.get_node("Anims").frame_at(anim, 2, 0.0)
	var mat: ShaderMaterial = p.art_for(anim)
	return {"sheet": f.tex.atlas.resource_path, "palette": mat.get_shader_parameter("palette").resource_path}
