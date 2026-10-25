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
	"glwctch", "gmdctch", "gjmctch", "gdkick"]

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
	var celebration := _drawn(p, "aeropla")
	print("rendered, aeropla (not rendered yet): %s, palette %s" % [celebration.sheet, celebration.palette])
	ok = ok and not anims.rendered("aeropla") and "players/" in celebration.sheet and "players/" in celebration.palette

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

	# the match options switch it
	var options = load("res://scripts/match_options.gd").new()
	root.add_child(options)
	await process_frame
	options._row = 8
	options._change(1)
	var after_options: bool = match_script.rendered
	print("match options, PLAYERS row: %s" % [options._rows()[8]])
	ok = ok and options._rows()[8][0] == "PLAYERS" and not after_options
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
