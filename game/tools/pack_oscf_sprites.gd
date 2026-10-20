extends SceneTree
## Package generated RGBA artwork; do not alter the source sheets.
## Run after source_regions.json has been generated.

const ROOT := "res://assets/sprites/oscf_starter/"
const CELL := 64
const FEET := Vector2i(32, 58)
const DIRECTIONS := ["n", "ne", "e", "se", "s"]

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source_regions.json"))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var metadata := {}
	for action: String in ["idle", "run", "kick"]:
		var spec: Dictionary = manifest[action]
		var source := Image.load_from_file(ROOT + action + ".png")
		var rows: Array = spec.rows
		var atlas := Image.create(CELL * 5, CELL * rows.size(), false, Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		# One scale per animation preserves the relative pose sizes.
		var factor := 48.0 / float(spec.reference_height)
		for row in rows.size():
			for col in 5:
				var bounds: Array = rows[row][col]
				var rect := Rect2i(int(bounds[0]), int(bounds[1]), int(bounds[2]), int(bounds[3]))
				var sprite := source.get_region(rect)
				# Discard low-alpha generated background remnants before resampling.
				for y in sprite.get_height():
					for x in sprite.get_width():
						var c := sprite.get_pixel(x, y)
						if c.a < 0.5:
							sprite.set_pixel(x, y, Color.TRANSPARENT)
				var target := Vector2i(maxi(1, roundi(rect.size.x * factor)), maxi(1, roundi(rect.size.y * factor)))
				if target.x > CELL or target.y > FEET.y:
					push_error("Sprite exceeds its cell: %s %d %d" % [action, row, col])
					quit(1)
					return
				sprite.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)
				var at := Vector2i(col * CELL + FEET.x - target.x / 2, row * CELL + FEET.y - target.y)
				atlas.blit_rect(sprite, Rect2i(Vector2i.ZERO, target), at)
		var path := ROOT + action + "_64.png"
		var err := atlas.save_png(path)
		if err != OK:
			push_error("Could not save " + path)
			quit(1)
			return
		# External texture path makes the resource portable after editor import.
		var texture := ImageTexture.create_from_image(atlas)
		texture.take_over_path(path)
		for col in 5:
			var animation: String = action + "_" + DIRECTIONS[col]
			frames.add_animation(animation)
			frames.set_animation_speed(animation, float(spec.fps))
			frames.set_animation_loop(animation, action != "kick")
			for row in rows.size():
				var tile := AtlasTexture.new()
				tile.atlas = texture
				tile.region = Rect2(col * CELL, row * CELL, CELL, CELL)
				frames.add_frame(animation, tile)
		metadata[action] = {"frames": rows.size(), "fps": spec.fps, "loop": action != "kick"}
	var result := ResourceSaver.save(frames, ROOT + "footballer.tres")
	if result != OK:
		push_error("Could not save SpriteFrames resource")
		quit(1)
		return
	print("Packed OSCF starter: ", metadata)
	quit()
