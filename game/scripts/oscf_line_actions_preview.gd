extends Node2D
## Generated-art review scene. Does not alter match animations or action bindings.
const RESOURCE := "res://brand/sprites/line_actions/line_actions.tres"
const MOVES := ["power_strike", "bulldozer_clear", "grapple_tackle", "laser_pass", "whirlwind_turn", "cannon_punt", "rising_fist", "stepover_storm"]
const ROLES := ["STRIKER", "DEFENDER", "DEFENDER", "MIDFIELDER", "MIDFIELDER", "KEEPER", "KEEPER", "WINGER"]
var actors: Array[AnimatedSprite2D] = []
var paused := false
var flipped := false
var speed := 1.0
var status: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("14252b"))
	label("OSCF / LINE SPECIALS", Vector2(28, 18), 28)
	label("Space pause · R replay · F mirror · Left/Right speed · Esc quit", Vector2(28, 57), 18)
	var frames: SpriteFrames = load(RESOURCE).duplicate()
	for id in MOVES: frames.set_animation_loop(id, true)
	for i in MOVES.size():
		var corner := Vector2((i % 4) * 320, 105 + (i / 4) * 275)
		label(ROLES[i], corner + Vector2(18, 0), 14)
		label(MOVES[i].replace("_", " ").to_upper(), corner + Vector2(18, 23), 20)
		for small in [false, true]:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.centered = false
			sprite.offset = Vector2(-96, -168)
			sprite.position = corner + Vector2(254 if small else 125, 222)
			sprite.scale = Vector2.ONE * (1.0 if small else 2.5)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(sprite)
			actors.append(sprite)
			sprite.play(MOVES[i])
	status = label("", Vector2(28, 675), 16)
	update_status()

func label(text: String, at: Vector2, size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", size)
	add_child(node)
	return node

func update_status() -> void:
	for actor in actors:
		actor.flip_h = flipped
		actor.speed_scale = 0.0 if paused else speed
	status.text = "%.2fx · %s · large / game-size views · RGBA art prototypes; not live match integration" % [speed, "LEFT" if flipped else "RIGHT"]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	match event.physical_keycode:
		KEY_SPACE: paused = not paused
		KEY_F: flipped = not flipped
		KEY_R:
			for actor in actors: actor.set_frame_and_progress(0, 0)
		KEY_LEFT: speed = maxf(0.25, speed / 2.0)
		KEY_RIGHT: speed = minf(2.0, speed * 2.0)
		KEY_ESCAPE: get_tree().quit()
	update_status()
