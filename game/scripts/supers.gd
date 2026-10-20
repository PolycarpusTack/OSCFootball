class_name Supers
extends RefCounted
## The super-shots: what they cost, how they're kicked and what the ball does.
## Ball behaviour lives in ball.gd (`power`), knock-downs in main.gd.

const MAX_ENERGY := 100.0

const LIST := {
	"fireball": {
		"title": "FIREBALL!", "cost": 50.0, "anim": "power_strike", "contact": 0.35,  # the striker's line move
		"speed": 900.0, "lift": 0.0, "colour": Color(1.0, 0.55, 0.1),
	},
	"banana": {
		"title": "BANANA SHOT!", "cost": 50.0, "anim": "vollkck", "contact": 0.2,
		"speed": 640.0, "lift": 30.0, "colour": Color(1.0, 0.92, 0.2),
	},
	"thunder": {
		"title": "THUNDER STRIKE!", "cost": 100.0, "anim": "bicycle", "contact": 0.35,
		"speed": 1100.0, "lift": 0.0, "colour": Color(0.55, 0.9, 1.0),
	},
}

## Energy rewards (per event, dribbling per second).
const GAIN := {
	"pass": 6.0, "tackle": 10.0, "save": 15.0, "fouled": 20.0, "conceded": 25.0, "dribble": 2.5,
}


static func cost(kind: String) -> float:
	return LIST[kind].cost


## Supers that plough through players instead of being stopped by them.
static func unstoppable(kind: String) -> bool:
	return kind == "fireball" or kind == "thunder"
