class_name Team
extends RefCounted
## A side in the match: name, kits, formation and its players.

const KIT_SHADER := preload("res://scripts/kit.gdshader")
const PALETTE := preload("res://assets/sprites/players/palette.png")

## 4-4-2, as fractions of the pitch: x from own goal line (0) to the opponent's (1).
const FORMATION := [
	["G", Vector2(0.02, 0.50)],
	["D", Vector2(0.20, 0.15)], ["D", Vector2(0.17, 0.38)], ["D", Vector2(0.17, 0.62)], ["D", Vector2(0.20, 0.85)],
	["M", Vector2(0.42, 0.15)], ["M", Vector2(0.38, 0.38)], ["M", Vector2(0.38, 0.62)], ["M", Vector2(0.42, 0.85)],
	["F", Vector2(0.60, 0.40)], ["F", Vector2(0.60, 0.60)],
]

var name: String
var short: String
var side := 1  # +1 attacks toward the right-hand goal, -1 toward the left
var score := 0
var energy := 0.0  # super-shot meter, 0..Supers.MAX_ENERGY
var players: Array[Footballer] = []
var colour: Color  # main shirt colour, for the HUD
var outfield_material: ShaderMaterial
var keeper_material: ShaderMaterial


func _init(team_name: String, abbreviation: String, kit: Dictionary, keeper_kit: Dictionary) -> void:
	name = team_name
	short = abbreviation
	colour = kit.shirt
	outfield_material = make_material(kit)
	keeper_material = make_material(keeper_kit)


static func make_material(kit: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = KIT_SHADER
	m.set_shader_parameter("palette", PALETTE)
	for part in kit:
		var c: Color = kit[part]
		m.set_shader_parameter(part, Vector3(c.r, c.g, c.b))
	return m


## Pitch position (pixels) for a formation spot, seen from this team's end.
func to_pitch(spot: Vector2) -> Vector2:
	var field := Pitch.field_rect()
	var x := spot.x if side > 0 else 1.0 - spot.x
	return Vector2(x * field.size.x, spot.y * field.size.y)


func goal_attacked() -> Vector2:
	var field := Pitch.field_rect()
	return Vector2(field.size.x if side > 0 else 0.0, field.size.y / 2.0)


func goal_defended() -> Vector2:
	var field := Pitch.field_rect()
	return Vector2(0.0 if side > 0 else field.size.x, field.size.y / 2.0)


func gain(amount: float) -> void:
	if not Match.chaos:  # Classic Football has no energy bar
		return
	energy = clampf(energy + amount, 0.0, Supers.MAX_ENERGY)


func keeper() -> Footballer:
	return players[0]


static func club_brugge() -> Team:
	return Team.new("Club Brugge", "BRU",
		{"shirt": Color("0a5cc4"), "shirt2": Color("16161a"), "shorts": Color("1a1a1e"), "socks": Color("1a1a1e"), "boots": Color("111111")},
		{"shirt": Color("f2d21c"), "shirt2": Color("f2d21c"), "shorts": Color("1a1a1e"), "socks": Color("f2d21c"), "boots": Color("111111")})


static func anderlecht() -> Team:
	return Team.new("Anderlecht", "AND",
		{"shirt": Color("5b2a86"), "shirt2": Color("5b2a86"), "shorts": Color("5b2a86"), "socks": Color("5b2a86"), "boots": Color("111111")},
		{"shirt": Color("2f9e44"), "shirt2": Color("2f9e44"), "shorts": Color("1a1a1e"), "socks": Color("2f9e44"), "boots": Color("111111")})
