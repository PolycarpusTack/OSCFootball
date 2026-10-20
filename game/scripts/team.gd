class_name Team
extends RefCounted
## A side in the match: name, kits, formation and its players.

const KIT_SHADER := preload("res://scripts/kit.gdshader")
const PALETTE := preload("res://assets/sprites/players/palette.png")
const LEAGUE := "res://data/league.json"

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


## Who takes kick-offs and penalties: the number 10 slot, or another outfield player if
## he's been sent off.
func taker() -> Footballer:
	if not players[9].sent_off:
		return players[9]
	for p in players:
		if p.role != "G" and not p.sent_off:
			return p
	return players[9]


func keeper() -> Footballer:
	return players[0]


## The league's clubs in table order, as in data/league.json.
static func league() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(LEAGUE))
	return data.teams if data is Dictionary else []


## A club from data/league.json by name.
static func from_league(club: String) -> Team:
	for d in league():
		if d.name == club:
			var kit := {"boots": Color("111111")}
			for part in d.kit:
				kit[part] = Color(d.kit[part])
			var keeper := Color(d.keeper)
			return Team.new(d.name, d.short, kit,
				{"shirt": keeper, "shirt2": keeper, "shorts": Color("1a1a1e"), "socks": keeper, "boots": Color("111111")})
	push_error("no club %s in %s" % [club, LEAGUE])
	return null


## Shirts too alike to tell apart on the pitch?
func clashes_with(other: Team) -> bool:
	return Vector3(colour.r, colour.g, colour.b).distance_to(Vector3(other.colour.r, other.colour.g, other.colour.b)) < 0.35


## Switch to a plain change kit (not the club's real away kit) that contrasts with `other`.
func wear_change_kit(other: Team) -> void:
	var light := other.colour.get_luminance() > 0.5
	var main := Color("1a1a1e") if light else Color("f2f2f2")
	var trim := Color("f2f2f2") if light else Color("1a1a1e")
	colour = main
	outfield_material = make_material({"shirt": main, "shirt2": main, "shorts": trim, "socks": main, "boots": Color("111111")})
