class_name Team
extends RefCounted
## A side in the match: name, kits, formation and its players.

const KIT_SHADER := preload("res://scripts/kit.gdshader")
const PALETTE := preload("res://assets/sprites/players/palette.png")
const LEAGUE := "res://data/league.json"

## Formations, slot by slot: the position on the team sheet, the role (G, D, M, F) and three
## spots as fractions of the pitch, x from own goal line (0) to the opponent's (1), y across
## (slot 1's touchline at 0): where he lines up for a kick-off, and the spot he holds when his
## side has the ball (wide and high) and when it hasn't (narrow and deep); AI.hold_spot shifts
## it with the ball. Slot 0 is the keeper; slots 9 and 10 the two most advanced players (they
## take kick-offs and penalties and attack crosses). Our own numbers, not CM3's tables.
const FORMATIONS := {
	"4-4-2": [
		{"pos": "GK", "role": "G", "spot": Vector2(0.02, 0.50), "attack": Vector2(0.14, 0.50), "defend": Vector2(-0.02, 0.50)},
		{"pos": "RB", "role": "D", "spot": Vector2(0.20, 0.15), "attack": Vector2(0.34, 0.10), "defend": Vector2(0.14, 0.24)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.38), "attack": Vector2(0.27, 0.36), "defend": Vector2(0.13, 0.41)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.62), "attack": Vector2(0.27, 0.64), "defend": Vector2(0.13, 0.59)},
		{"pos": "LB", "role": "D", "spot": Vector2(0.20, 0.85), "attack": Vector2(0.34, 0.90), "defend": Vector2(0.14, 0.76)},
		{"pos": "RM", "role": "M", "spot": Vector2(0.42, 0.15), "attack": Vector2(0.58, 0.10), "defend": Vector2(0.36, 0.24)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.38, 0.38), "attack": Vector2(0.50, 0.38), "defend": Vector2(0.32, 0.42)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.38, 0.62), "attack": Vector2(0.50, 0.62), "defend": Vector2(0.32, 0.58)},
		{"pos": "LM", "role": "M", "spot": Vector2(0.42, 0.85), "attack": Vector2(0.58, 0.90), "defend": Vector2(0.36, 0.76)},
		{"pos": "ST", "role": "F", "spot": Vector2(0.60, 0.40), "attack": Vector2(0.74, 0.40), "defend": Vector2(0.52, 0.44)},
		{"pos": "ST", "role": "F", "spot": Vector2(0.60, 0.60), "attack": Vector2(0.74, 0.60), "defend": Vector2(0.52, 0.56)},
	],
	"4-3-3": [
		{"pos": "GK", "role": "G", "spot": Vector2(0.02, 0.50), "attack": Vector2(0.14, 0.50), "defend": Vector2(-0.02, 0.50)},
		{"pos": "RB", "role": "D", "spot": Vector2(0.20, 0.15), "attack": Vector2(0.36, 0.12), "defend": Vector2(0.14, 0.24)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.38), "attack": Vector2(0.27, 0.36), "defend": Vector2(0.13, 0.41)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.62), "attack": Vector2(0.27, 0.64), "defend": Vector2(0.13, 0.59)},
		{"pos": "LB", "role": "D", "spot": Vector2(0.20, 0.85), "attack": Vector2(0.36, 0.88), "defend": Vector2(0.14, 0.76)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.38, 0.30), "attack": Vector2(0.52, 0.30), "defend": Vector2(0.32, 0.36)},
		{"pos": "CDM", "role": "M", "spot": Vector2(0.30, 0.50), "attack": Vector2(0.40, 0.50), "defend": Vector2(0.25, 0.50)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.38, 0.70), "attack": Vector2(0.52, 0.70), "defend": Vector2(0.32, 0.64)},
		{"pos": "RW", "role": "F", "spot": Vector2(0.56, 0.15), "attack": Vector2(0.72, 0.10), "defend": Vector2(0.46, 0.22)},
		{"pos": "ST", "role": "F", "spot": Vector2(0.62, 0.50), "attack": Vector2(0.76, 0.50), "defend": Vector2(0.54, 0.50)},
		{"pos": "LW", "role": "F", "spot": Vector2(0.56, 0.85), "attack": Vector2(0.72, 0.90), "defend": Vector2(0.46, 0.78)},
	],
	"4-5-1": [
		{"pos": "GK", "role": "G", "spot": Vector2(0.02, 0.50), "attack": Vector2(0.14, 0.50), "defend": Vector2(-0.02, 0.50)},
		{"pos": "RB", "role": "D", "spot": Vector2(0.20, 0.15), "attack": Vector2(0.32, 0.12), "defend": Vector2(0.13, 0.24)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.38), "attack": Vector2(0.26, 0.36), "defend": Vector2(0.12, 0.41)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.62), "attack": Vector2(0.26, 0.64), "defend": Vector2(0.12, 0.59)},
		{"pos": "LB", "role": "D", "spot": Vector2(0.20, 0.85), "attack": Vector2(0.32, 0.88), "defend": Vector2(0.13, 0.76)},
		{"pos": "RM", "role": "M", "spot": Vector2(0.40, 0.15), "attack": Vector2(0.56, 0.10), "defend": Vector2(0.32, 0.22)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.34, 0.38), "attack": Vector2(0.46, 0.38), "defend": Vector2(0.28, 0.42)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.34, 0.62), "attack": Vector2(0.46, 0.62), "defend": Vector2(0.28, 0.58)},
		{"pos": "LM", "role": "M", "spot": Vector2(0.40, 0.85), "attack": Vector2(0.56, 0.90), "defend": Vector2(0.32, 0.78)},
		{"pos": "ST", "role": "F", "spot": Vector2(0.62, 0.50), "attack": Vector2(0.76, 0.50), "defend": Vector2(0.50, 0.50)},
		{"pos": "CAM", "role": "M", "spot": Vector2(0.48, 0.50), "attack": Vector2(0.62, 0.46), "defend": Vector2(0.40, 0.50)},
	],
	"5-3-2": [
		{"pos": "GK", "role": "G", "spot": Vector2(0.02, 0.50), "attack": Vector2(0.14, 0.50), "defend": Vector2(-0.02, 0.50)},
		{"pos": "RWB", "role": "D", "spot": Vector2(0.24, 0.12), "attack": Vector2(0.48, 0.08), "defend": Vector2(0.16, 0.20)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.32), "attack": Vector2(0.27, 0.30), "defend": Vector2(0.13, 0.36)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.15, 0.50), "attack": Vector2(0.24, 0.50), "defend": Vector2(0.11, 0.50)},
		{"pos": "CB", "role": "D", "spot": Vector2(0.17, 0.68), "attack": Vector2(0.27, 0.70), "defend": Vector2(0.13, 0.64)},
		{"pos": "LWB", "role": "D", "spot": Vector2(0.24, 0.88), "attack": Vector2(0.48, 0.92), "defend": Vector2(0.16, 0.80)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.38, 0.32), "attack": Vector2(0.50, 0.30), "defend": Vector2(0.32, 0.38)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.36, 0.50), "attack": Vector2(0.46, 0.50), "defend": Vector2(0.30, 0.50)},
		{"pos": "CM", "role": "M", "spot": Vector2(0.38, 0.68), "attack": Vector2(0.50, 0.70), "defend": Vector2(0.32, 0.62)},
		{"pos": "ST", "role": "F", "spot": Vector2(0.60, 0.40), "attack": Vector2(0.74, 0.40), "defend": Vector2(0.52, 0.44)},
		{"pos": "ST", "role": "F", "spot": Vector2(0.60, 0.60), "attack": Vector2(0.74, 0.60), "defend": Vector2(0.52, 0.56)},
	],
}
const DEFAULT_FORMATION := "4-4-2"

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
	var y := 1.0 - spot.y if side > 0 else spot.y  # spot y 0 is the right flank, whichever way the side attacks
	return Vector2(x * field.size.x, y * field.size.y)


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
