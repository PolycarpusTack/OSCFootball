extends SceneTree
## Deterministic atlas packing only. Preserves the generated source art and its alpha.
const ROOT := "res://brand/sprites/line_actions/"
const CELL := 192
const ORIGIN := Vector2i(96, 168)

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var report := {}
	for id: String in manifest.moves:
		var spec: Dictionary = manifest.moves[id]
		var source := Image.load_from_file(ROOT + str(spec.get("source", id + ".png")))
		if source == null:
			fail("Missing image: " + id)
			return
		source.convert(Image.FORMAT_RGBA8)
		var poses: Array[Image] = []
		var regions: Array[Rect2i] = []
		for i in 6:
			var r: Array = spec.regions[i]
			var bounds := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
			if bounds.size.x == 0 or bounds.size.y == 0:
				fail("Empty pose: %s %d" % [id, i])
				return
			if not Rect2i(Vector2i.ZERO, source.get_size()).encloses(bounds):
				fail("Invalid measured region: %s %d" % [id, i])
				return
			poses.append(source.get_region(bounds))
			regions.append(bounds)
		var factor := float(manifest.standing_height) / float(regions[0].size.y)
		var lift_scale := float(manifest.standing_height) / 48.0  # the lifts were measured at 48 px
		var sheet := Image.create(CELL * 6, CELL, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.TRANSPARENT)
		var details := []
		for i in 6:
			var pose: Image = poses[i]
			var size := Vector2i(maxi(1, roundi(pose.get_width() * factor)), maxi(1, roundi(pose.get_height() * factor)))
			pose.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
			var anchor_x: float = spec.get("anchor_x", [0.5, 0.5, 0.5, 0.5, 0.5, 0.5])[i]
			var at := ORIGIN - Vector2i(roundi(size.x * anchor_x), size.y + roundi(float(spec.lift[i]) * lift_scale))
			if at.x < 0 or at.y < 0 or at.x + size.x > CELL or at.y + size.y > CELL:
				fail("Pose exceeds atlas cell: %s %d" % [id, i])
				return
			sheet.blit_rect(pose, Rect2i(Vector2i.ZERO, size), at + Vector2i(i * CELL, 0))
			details.append({"source_rect": [regions[i].position.x, regions[i].position.y, regions[i].size.x, regions[i].size.y], "packed_rect": [at.x, at.y, size.x, size.y], "lift": spec.lift[i]})
		var path := ROOT + id + "_192.png"
		if sheet.save_png(path) != OK:
			fail("Cannot save " + path)
			return
		var texture := ImageTexture.create_from_image(sheet)
		texture.take_over_path(path)
		frames.add_animation(id)
		frames.set_animation_speed(id, 10.0)
		frames.set_animation_loop(id, false)
		for i in 6:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * CELL, 0, CELL, CELL)
			frames.add_frame(id, atlas, float(spec.duration[i]))
		report[id] = {"scale": factor, "poses": details}
	if ResourceSaver.save(frames, ROOT + "line_actions.tres") != OK:
		fail("Cannot save SpriteFrames")
		return
	var file := FileAccess.open(ROOT + "packed_regions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Packed %d actions / %d frames" % [frames.get_animation_names().size(), frames.get_animation_names().size() * 6])
	quit()

func fail(message: String) -> void:
	push_error(message)
	quit(1)
