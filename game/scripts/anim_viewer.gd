extends Node2D
## Browse every extracted player animation in all 8 directions.
## Up/Down: animation, Left/Right: speed, Esc/F1: back to the pitch.

var _names: Array = []
var _index := 0
var _time := 0.0
var _speed := 1.0
var _sprites: Array[Sprite2D] = []
var _label := Label.new()
var _kit: ShaderMaterial


func _ready() -> void:
	_names = Anims.names()
	_names.sort()
	_kit = Team.from_league("Club Brugge").outfield_material
	for facing in 8:
		var s := Sprite2D.new()
		s.centered = false
		s.scale = Vector2(3, 3)
		s.position = Vector2(110 + facing * 145, 380)
		add_child(s)
		_sprites.append(s)
	_label.position = Vector2(16, 12)
	add_child(_label)
	RenderingServer.set_default_clear_color(Color(0.2, 0.45, 0.2))


func _process(delta: float) -> void:
	_time += delta * _speed
	var anim: String = _names[_index]
	for facing in 8:
		var f := Anims.frame_at(anim, facing, _time)
		_sprites[facing].material = null if Anims.own_art(anim) else _kit  # the referee's art is RGBA
		_sprites[facing].texture = f.tex
		_sprites[facing].offset = f.offset
		_sprites[facing].flip_h = f.flip
	_label.text = "%s   (%d/%d)   speed x%.2f   %.2fs\nUp/Down: animation   Left/Right: speed   Esc: back" % [
		anim, _index + 1, _names.size(), _speed, Anims.length_seconds(anim)]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.physical_keycode:
		KEY_UP:
			_index = (_index - 1 + _names.size()) % _names.size(); _time = 0.0
		KEY_DOWN:
			_index = (_index + 1) % _names.size(); _time = 0.0
		KEY_LEFT:
			_speed = maxf(0.125, _speed / 2.0)
		KEY_RIGHT:
			_speed = minf(4.0, _speed * 2.0)
		KEY_ESCAPE, KEY_F1:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
