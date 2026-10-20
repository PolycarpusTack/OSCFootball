extends SceneTree
## Pack the special-move artwork using measured rectangles and body anchors.
## Input coordinates and timing are in source_regions.json; sources stay intact.

const ROOT := "res://assets/sprites/oscf_specials/"
const CELL := 192
const ORIGIN := Vector2i(64, 168)

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source_regions.json"))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var count := 0
	for action: String in manifest:
		var spec: Dictionary = manifest[action]
		var source := Image.load_from_file(ROOT + action + ".png")
		var poses: Array = spec.poses
		var sheet := Image.create(CELL * poses.size(), CELL, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.TRANSPARENT)
		var factor := 48.0 / float(spec.reference_height)
		for i in poses.size():
			var pose: Dictionary = poses[i]
			var b: Array = pose.rect
			var sprite := source.get_region(Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3])))
			# Wide poses can overlap a neighbour's bounding rectangle. Keep only
			# the connected character selected by the measured component seed.
			sprite = _isolate(sprite, Vector2i(int(pose.seed[0]), int(pose.seed[1])))
			var size := Vector2i(maxi(1, roundi(float(b[2]) * factor)), maxi(1, roundi(float(b[3]) * factor)))
			sprite.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
			var anchor := Vector2i(roundi(float(pose.anchor[0]) * factor), roundi(float(pose.anchor[1]) * factor))
			var position := ORIGIN - anchor - Vector2i(0, int(pose.lift))
			if position.x < 0 or position.y < 0 or position.x + size.x > CELL or position.y + size.y > CELL:
				push_error("Frame outside cell: %s:%d" % [action, i])
				quit(1)
				return
			sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, size), position + Vector2i(i * CELL, 0))
		var path := ROOT + action + "_192.png"
		if sheet.save_png(path) != OK:
			quit(1)
			return
		var texture := ImageTexture.create_from_image(sheet)
		texture.take_over_path(path)
		frames.add_animation(action)
		frames.set_animation_speed(action, 10.0)
		frames.set_animation_loop(action, false)
		for i in poses.size():
			var tile := AtlasTexture.new()
			tile.atlas = texture
			tile.region = Rect2(i * CELL, 0, CELL, CELL)
			frames.add_frame(action, tile, float(poses[i].duration))
			count += 1
	if ResourceSaver.save(frames, ROOT + "special_actions.tres") != OK:
		quit(1)
		return
	print("Packed ", count, " special-action frames; ", manifest.size(), " moves.")
	quit()

func _isolate(source: Image, seed: Vector2i) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue: Array[Vector2i] = [seed]
	var index := 0
	while index < queue.size():
		var p := queue[index]
		index += 1
		if p.x < 0 or p.y < 0 or p.x >= width or p.y >= height:
			continue
		var flat := p.y * width + p.x
		if visited[flat]:
			continue
		visited[flat] = 1
		var colour := source.get_pixelv(p)
		if colour.a <= 0.5:
			continue
		result.set_pixelv(p, colour)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(p + direction)
	return result
