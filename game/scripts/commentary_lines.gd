extends RefCounted
## The commentary's lines (Commentary), OSCF's own. A key is an event kind, or a goal's
## context under "goal." (see Commentary.goal_key); a missing key falls back a step at a time
## ("goal.equaliser.late" -> "goal.equaliser" -> "goal"). Tokens: {p1} who did it, {p2} the
## other man (fouled, beaten), {t} his side, {opp} the other side, {score} home-away, {min}.
## "p": priority, 0 chatter .. 2 the big moments (they clear the chatter waiting).

const LINES := {
	"goal": {"p": 2, "lines": [
		"GOAL! {p1} puts it away for {t}. {score}.",
		"{p1} scores! {t} lead the dance at {score}.",
		"In it goes! {p1}, and the net bulges. {score}.",
	]},
	"goal.opener": {"p": 2, "lines": [
		"{p1} breaks the deadlock! {t} lead {score}.",
		"First blood to {t}: {p1} with the opener.",
	]},
	"goal.equaliser": {"p": 2, "lines": [
		"{p1} levels it! {score}, and it's anybody's.",
		"Back on terms: {p1} for {t}. {score}.",
	]},
	"goal.equaliser.late": {"p": 2, "lines": [
		"{p1} equalises with the clock wheezing toward the tunnel! {score}!",
		"Late, late drama: {p1} drags {t} level at {score}!",
	]},
	"goal.equaliser.short": {"p": 2, "lines": [
		"Ten men, one ball, zero respect for the scoreline: {p1} makes it {score}!",
		"A man down and still level: {p1} for {t}. {score}.",
	]},
	"goal.late": {"p": 2, "lines": [
		"{p1} in the {min}th minute! {t} can smell it. {score}.",
		"A late one from {p1}, and {opp} are out of minutes. {score}.",
	]},
	"goal.back": {"p": 2, "lines": [
		"{p1} pulls one back for {t}. {score}: game on?",
		"{t} are not done yet: {p1} makes it {score}.",
	]},
	"goal.clincher": {"p": 2, "lines": [
		"{p1} makes it {score}. That's the coach's tie loosened.",
		"Surely that's that: {p1}, {score}.",
	]},
	"goal.hat_trick": {"p": 2, "lines": [
		"HAT-TRICK! {p1} wants the match ball and probably the corner flags too.",
		"Three for {p1}! Somebody fetch him a bag for the ball.",
	]},
	"goal.own": {"p": 2, "lines": [
		"{p1} finds the net. The wrong one, mind. {score}.",
		"Own goal! {p1} won't be sending that one to his mum. {score}.",
	]},
	"goal.golden": {"p": 2, "lines": [
		"GOLDEN GOAL! {p1} ends it for {t}!",
		"{p1}! Golden goal, and {opp} can go home.",
	]},
	"goal.fireball": {"p": 2, "lines": [
		"{p1} sets the ball on fire. The keeper declines to get involved. {score}.",
	]},
	"goal.banana": {"p": 2, "lines": [
		"{p1}'s banana bends round everybody and in. {score}. Physics is filing a complaint.",
	]},
	"goal.thunder": {"p": 2, "lines": [
		"THUNDER STRIKE! Somewhere a seismograph rings in sick. {score}.",
	]},
	"shot": {"p": 1, "lines": [
		"{p1} lets fly...",
		"{p1} has a go...",
		"{p1} pulls the trigger...",
	]},
	"shot.long": {"p": 1, "lines": [
		"{p1} tries his luck from way out...",
		"From distance, {p1}...",
	]},
	"shot.missed": {"p": 0, "lines": [
		"...and it's nowhere near.",
		"...the ball boys get some exercise.",
		"...row Z thanks him for the souvenir.",
	]},
	"fireball": {"p": 1, "lines": ["FIREBALL from {p1}..."]},
	"banana": {"p": 1, "lines": ["{p1} peels off a banana shot..."]},
	"thunder": {"p": 1, "lines": ["{p1} winds up the THUNDER STRIKE..."]},
	"save": {"p": 1, "lines": [
		"...and {p1} gets a glove on it!",
		"...{p1} says no!",
		"...saved by {p1}.",
	]},
	"woodwork": {"p": 1, "lines": [
		"...off the woodwork! The frame of the goal earns its wages.",
		"...it rattles the post!",
	]},
	"header": {"p": 0, "lines": ["{p1} gets his head to it.", "A header from {p1}."]},
	"volley": {"p": 0, "lines": ["{p1} hits it on the volley.", "First time, on the volley: {p1}."]},
	"clearance": {"p": 0, "lines": ["{p1} hoofs it clear.", "{p1} clears his lines. Subtlety: optional."]},
	"dodge": {"p": 0, "lines": ["{t} skip over the tackle.", "Hurdled! {t} ride the challenge."]},
	"nutmeg": {"p": 0, "lines": [
		"Through the legs! He'll tell his mum it didn't happen.",
		"Nutmeg! {p1} is enjoying himself.",
		"{p1} threads it through the legs. Rude, but effective.",
		"Megs! {p1} leaves a defender checking his shorts.",
	]},
	"rainbow": {"p": 0, "lines": [
		"{p1} flicks a rainbow over the top. Show-off.",
		"Rainbow flick from {p1}!",
		"{p1} goes over the top with the rainbow. The crowd go \"ooh\".",
		"Up and over: {p1} has been watching videos again.",
	]},
	"bckheel": {"p": 0, "lines": ["A cheeky backheel from {p1}."]},
	"body check won": {"p": 0, "lines": ["{t} go shoulder-first through the middle. Legal-ish.", "Body check! {t} win that one the hard way."]},
	"dizzy": {"p": 0, "lines": ["One of {t}'s lads is seeing stars. And possibly birds.", "Dizzy! Somebody hold up some fingers."]},
	"foul": {"p": 1, "lines": [
		"{p1} goes through {p2}. Free kick.",
		"Foul by {p1} on {p2}. The referee's having none of it.",
		"{p1} clatters {p2}, and the whistle goes.",
	]},
	"unseen foul": {"p": 1, "lines": [
		"{p1} takes {p2} clean out. The referee is admiring the floodlights.",
		"{p1} flattens {p2} and nobody in black saw a thing.",
	]},
	"late whistle": {"p": 1, "lines": [
		"Hang on: the referee spots {p2} still down. He's going back for it.",
		"Late whistle! The referee has finished his sightseeing.",
	]},
	"advantage": {"p": 0, "lines": ["The referee waves play on. Advantage {t}.", "Advantage! {t} carry on."]},
	"advantage played": {"p": 0, "lines": ["The advantage holds. He'll have a word at the next stoppage."]},
	"brought back": {"p": 0, "lines": ["No advantage after all: back for the free kick."]},
	"ref warning": {"p": 1, "lines": [
		"The referee calls {p1} over. The notebook is out and his name's getting underlined.",
		"A word in {p1}'s ear. That's the final warning, by the look of the finger.",
	]},
	"yellow card": {"p": 1, "lines": ["{p1} goes in the book.", "Yellow card for {p1}.", "{p1} is booked. He looks shocked. Nobody else does."]},
	"red card": {"p": 2, "lines": [
		"RED CARD! {p1} is off. {t} are a man down.",
		"Off you go, {p1}! Straight down the tunnel.",
	]},
	"red card.second": {"p": 2, "lines": [
		"Second yellow! {p1} is escorted to the naughty step.",
		"That's two yellows for {p1}, and two yellows make an early bath.",
	]},
	"last man": {"p": 1, "lines": ["{p2} was through, and {p1} was the last man. Uh-oh."]},
	"offside": {"p": 0, "lines": ["{p1} was offside by about a postcode.", "Flag's up: {p1} went too early."]},
	"penalty": {"p": 2, "lines": ["PENALTY to {t}!", "The referee points to the spot! Penalty, {t}."]},
	"corner": {"p": 0, "lines": ["Corner to {t}.", "{t} win a corner."]},
	"dive": {"p": 1, "lines": ["{p1} goes down like a sack of potatoes, and the referee isn't buying.", "Dive! {p1} gets a card for his acting."]},
	"dive bought": {"p": 1, "lines": ["{p1} goes down, and the referee falls for it. Somewhere a drama teacher weeps with pride."]},
	"sorry ref": {"p": 0, "lines": ["{t} put their hands up: \"Sorry, ref!\" It seems to work.", "The apology tour is in town: \"sorry, ref\"."]},
	"dissent": {"p": 0, "lines": ["{t} chirp at the referee. That won't help.", "Dissent from {t}. The referee's face says it all."]},
	"ref fuming": {"p": 1, "lines": ["The referee is FUMING with {t}. Steam: visible.", "Uh-oh, the referee's about to blow his top at {t}."]},
	"whistle stun": {"p": 1, "lines": ["WHISTLE STUN! {t}'s players are rooted to the spot.", "The referee lets rip on the whistle. {t} are stunned."]},
	"bribe caught": {"p": 2, "lines": ["The linesman saw the envelope! Penalty against {t}, and no refunds."]},
	"bribed call": {"p": 0, "lines": ["Play on, says a referee with a suspiciously new watch."]},
	"captain": {"p": 0, "lines": ["{t}'s captain has a calming word with the referee."]},
	"pinball": {"p": 0, "lines": ["{t} play a Pinball Pass. Physics has filed for leave."]},
	"stego": {"p": 0, "lines": ["Stego Sweep from {t}! Extinction-level tackle."]},
	"bass": {"p": 0, "lines": ["BASS DROP! {t} shake the grass loose."]},
	"rocket": {"p": 0, "lines": ["{t}'s keeper launches a Rocket Throw. Air traffic control is on the phone."]},
	"palm": {"p": 0, "lines": ["Palm Barrage! {t}'s keeper slaps it all away."]},
	"cyclone": {"p": 0, "lines": ["Cyclone Scissor from {t}! Somebody's been practising."]},
	"substitution": {"p": 0, "lines": ["A change for {t}.", "{t} make a substitution."]},
	"half time": {"p": 2, "lines": ["Half time, {score}. Orange slices and stern words.", "That's the half: {score}."]},
	"extra time": {"p": 2, "lines": ["Extra time, {score}. Legs are optional from here."]},
	"full time": {"p": 2, "lines": ["Full time: {score}.", "It's all over! {score}."]},
	"shoot-out": {"p": 1, "lines": ["Penalties! Somebody check on the goalkeepers' nerves."]},
}
