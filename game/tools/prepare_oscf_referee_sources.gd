extends SceneTree
## Layout-only normalization of generated artwork; source images remain in raw/.
## Preserves separate frames/directions, standardizes the card's colour-key marker.
const ROOT := "res://assets/sprites/oscf_roles/"
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "preparation.json"))
	var result := {"frame_indices": "zero-based", "row_height": 256, "sheets": {}}
	for id: String in data:
		var spec: Dictionary = data[id]
		var output := Image.create(1536, int(spec.rows) * 256, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		var regions := []
		for pose: Dictionary in spec.poses:
			var image := Image.load_from_file(ROOT + pose.source)
			image.convert(Image.FORMAT_RGBA8)
			var r: Array = pose.rect
			var sprite := image.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
			if spec.get("largest_part_only", false):  # the crop catches bits of the neighbouring poses
				_keep_largest_part(sprite)
			var factor: float = float(pose.scale)
			var size := Vector2i(roundi(sprite.get_width() * factor), roundi(sprite.get_height() * factor))
			sprite.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
			if id == "referee_card":
				for y in size.y:
					for x in size.x:
						var c := sprite.get_pixel(x, y)
						if c.a > 0 and c.g > 0.45 and c.r < c.g * 0.45 and c.b < c.g * 0.45:
							sprite.set_pixel(x, y, Color(0, 1, 0, c.a))
			var col := int(pose.col)
			var row := int(pose.row)
			var left := roundi(col * 1536.0 / float(spec.cols))
			var right := roundi((col + 1) * 1536.0 / float(spec.cols))
			var root_at := Vector2i((left + right) / 2, row * 256 + (240 if spec.kind == "referee" else 128))
			var at := root_at - Vector2i(roundi(size.x * float(pose.get("anchor_x", 0.5))), size.y if spec.kind == "referee" or pose.get("grounded", false) else size.y / 2)
			if pose.get("grounded", false): at.y = row * 256 + 204 - size.y
			if at.x < left + 8 or at.x + size.x > right - 8 or at.y < row * 256 + 8 or at.y + size.y > (row + 1) * 256 - 8:
				push_error("Frame crosses safe cell margins: %s row%d col%d %s" % [id, row, col, Rect2i(at, size)])
				quit(1)
				return
			output.blit_rect(sprite, Rect2i(Vector2i.ZERO, size), at)
			regions.append({"row": row, "column": col, "rect": [at.x, at.y, size.x, size.y], "cell": [left, row * 256, right - left, 256], "anchor": [root_at.x, root_at.y]})
		if output.save_png(ROOT + id + ".png") != OK:
			quit(1)
			return
		result.sheets[id] = {"size": [1536, spec.rows * 256], "directions": spec.get("directions", []), "animations": spec.animations, "frames": regions}
	var file := FileAccess.open(ROOT + "source_regions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("Prepared ", data.size(), " transparent source sheets.")
	quit()


## Clear everything but the largest 8-connected opaque shape of `image`.
func _keep_largest_part(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var part := PackedInt32Array()
	part.resize(w * h)
	part.fill(-1)
	var sizes: Array[int] = []
	for start in w * h:
		if part[start] != -1 or image.get_pixel(start % w, start / w).a <= 0.1:
			continue
		var id := sizes.size()
		var stack: Array[int] = [start]
		part[start] = id
		var count := 0
		while not stack.is_empty():
			var i: int = stack.pop_back()
			count += 1
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var x: int = i % w + dx
					var y: int = i / w + dy
					if x < 0 or y < 0 or x >= w or y >= h or part[y * w + x] != -1:
						continue
					if image.get_pixel(x, y).a > 0.1:
						part[y * w + x] = id
						stack.append(y * w + x)
		sizes.append(count)
	var largest := sizes.find(sizes.max())
	for i in w * h:
		if part[i] != largest:
			image.set_pixel(i % w, i / w, Color.TRANSPARENT)
