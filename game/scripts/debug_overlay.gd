class_name DebugOverlay
extends CanvasLayer
## F3: what the match is thinking. Above each player: number, AI decision (or HUMAN),
## and BUSY while an animation locks them. Ball: ring, line to the holder, last touch.
## Top right: frame rate, match state and clock, ball state.

const FONT_SIZE := 13

var match_: Match
var _canvas := Control.new()


func _init(m: Match) -> void:
	match_ = m
	layer = 10
	visible = false


func _ready() -> void:
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(_delta: float) -> void:
	if visible:
		_canvas.queue_redraw()


func _draw_overlay() -> void:
	var m := match_
	var font := ThemeDB.fallback_font
	var ball := m.ball
	var ball_at := _screen(ball.position, ball.z)
	for t in [m.home, m.away]:
		for p: Footballer in t.players:
			var s := m.stadium.to_screen(p.position)
			var head := Vector2(s.x, s.y - 44.0 * s.z)
			var text := "%d %s" % [p.number, "HUMAN" if p.controlled else p.ai_state]
			if p.busy():
				text += " BUSY"
			if p.touch_cooldown > 0.0:
				text += " cd%.1f" % p.touch_cooldown
			var colour: Color = Color.YELLOW if p == ball.holder else t.colour.lightened(0.5)
			_label(font, head, text, colour)
	_canvas.draw_arc(ball_at, 10.0, 0.0, TAU, 24, Color.YELLOW, 2.0)
	if ball.holder:
		var s := m.stadium.to_screen(ball.holder.position)
		_canvas.draw_line(ball_at, Vector2(s.x, s.y), Color.YELLOW, 2.0)
	var lines := [
		"FPS %d   time scale %.2f" % [Engine.get_frames_per_second(), Engine.time_scale],
		"%s  half %d  clock %.1f s" % [Match.State.keys()[m.state], m.half, m.clock],
		"holder %s   last touch %s" % [_name(ball.holder), _name(ball.last_touch)],
		"ball (%.0f, %.0f) z %.0f  speed %.0f  %s" % [ball.position.x, ball.position.y, ball.z,
			ball.velocity.length(), ball.power if ball.power != "" else ball.kick_kind],
		"mode %s   energy %s %.0f / %s %.0f" % ["CHAOS" if Match.chaos else "CLASSIC",
			m.home.short, m.home.energy, m.away.short, m.away.energy],
	]
	var size := _canvas.size
	var y := 14.0
	_canvas.draw_rect(Rect2(size.x - 380.0, 6.0, 374.0, lines.size() * 18.0 + 8.0), Color(0, 0, 0, 0.65))
	for line in lines:
		y += 18.0
		_canvas.draw_string(font, Vector2(size.x - 372.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)


func _screen(p: Vector2, height_px: float) -> Vector2:
	var s := match_.stadium.to_screen(p, height_px)
	return Vector2(s.x, s.y)


func _label(font: Font, at: Vector2, text: String, colour: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var pos := at - Vector2(w / 2.0, 0.0)
	_canvas.draw_rect(Rect2(pos - Vector2(2, FONT_SIZE), Vector2(w + 4, FONT_SIZE + 4)), Color(0, 0, 0, 0.55))
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


func _name(p: Footballer) -> String:
	return "%s %d" % [p.team.short, p.number] if p else "-"
