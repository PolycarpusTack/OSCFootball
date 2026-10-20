class_name Pitch
extends Node2D
## Grass from the original pitch texture, markings drawn to real proportions.
## Origin is the top-left corner of the field of play; goals are left and right.
## Drawn once into a texture for the 3D pitch (see Stadium); goals are 3D.

const PX_PER_M := 18.0
const LENGTH_M := 105.0
const WIDTH_M := 68.0
const MARGIN_M := 6.0
const LINE := Color(1, 1, 1, 0.85)

var grass: Texture2D = preload("res://assets/pitch/grass.png")


static func m(v: float) -> float:
	return v * PX_PER_M


static func field_rect() -> Rect2:
	return Rect2(0, 0, m(LENGTH_M), m(WIDTH_M))


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -10


func _draw() -> void:
	var f := field_rect()
	var outer := f.grow(m(MARGIN_M))
	draw_texture_rect(grass, outer, true)
	# mowing stripes
	var stripe := m(LENGTH_M) / 14.0
	for i in 14:
		if i % 2 == 0:
			draw_rect(Rect2(i * stripe, 0, stripe, f.size.y), Color(0, 0, 0, 0.08))
	var w := 2.0
	draw_rect(f, LINE, false, w)
	var cx := f.size.x / 2.0
	var cy := f.size.y / 2.0
	draw_line(Vector2(cx, 0), Vector2(cx, f.size.y), LINE, w)
	draw_arc(Vector2(cx, cy), m(9.15), 0, TAU, 64, LINE, w)
	draw_circle(Vector2(cx, cy), 3.0, LINE)
	for side in [0, 1]:
		var x0 := 0.0 if side == 0 else f.size.x
		var dir := 1.0 if side == 0 else -1.0
		_box(x0, dir, m(16.5), m(40.32), cy, w)
		_box(x0, dir, m(5.5), m(18.32), cy, w)
		draw_circle(Vector2(x0 + dir * m(11), cy), 3.0, LINE)
		# penalty arc: the part of the 9.15 m circle round the spot outside the box
		var a := acos(5.5 / 9.15)
		var c := 0.0 if side == 0 else PI
		draw_arc(Vector2(x0 + dir * m(11), cy), m(9.15), c - a, c + a, 24, LINE, w)


func _box(x0: float, dir: float, depth: float, width: float, cy: float, w: float) -> void:
	var x1 := x0 + dir * depth
	var r := Rect2(minf(x0, x1), cy - width / 2.0, depth, width)
	draw_rect(r, LINE, false, w)
