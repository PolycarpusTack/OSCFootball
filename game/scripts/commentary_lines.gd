extends RefCounted
## The commentary's lines (Commentary), OSCF's own. A key is an event kind, or a goal's
## context under "goal." (see Commentary.goal_key); a missing key falls back a step at a time
## ("goal.equaliser.late" -> "goal.equaliser" -> "goal"). Tokens: {p1} who did it, {p2} the
## other man (fouled, beaten; in a lull, anybody else on the pitch), {t} his side, {opp} the
## other side, {score} home-away, {min} the minute.
## "p": priority, 0 chatter .. 2 the big moments (they clear the chatter waiting).
## "lines": serious commentary, said in either mode. "chaos": over the top, said only in Chaos
## football, on top of the serious ones. "lull" is said in quiet open play (Commentary.LULL).

const LINES := {
	"goal": {"p": 2, "lines": [
		"GOAL! {p1} finishes it off for {t}. {score}.",
		"{p1} scores! {t} extend their lead: {score}.",
		"In it goes! {p1} with the finish. {score}.",
		"{p1} makes no mistake. It's {score}.",
		"That's a fine finish from {p1}. {t} lead {score}.",
		"{p1} picks his spot and tucks it away. {score}.",
		"Goal for {t}, and {p1} is the man. {score}.",
	], "chaos": [
		"{p1} scores and celebrates by pretending to be a lawnmower. {score}.",
		"GOAL! {p1} kisses the badge, the corner flag and a confused steward. {score}.",
		"{p1} scores, and the {t} end launches an inflatable flamingo onto the pitch. {score}.",
		"In it goes! The net needed that. {score}.",
		"{p1} scores and immediately asks about a statue. {score}.",
		"{p1} finds the net and does a dance nobody has seen before. Nobody wants to see it again. {score}.",
	]},
	"goal.opener": {"p": 2, "lines": [
		"{p1} breaks the deadlock! {t} lead {score}.",
		"The first goal goes to {t}: {p1}. {score}.",
		"{p1} opens the scoring for {t}.",
		"{t} are in front, and it's {p1} who's put them there. {score}.",
		"Finally the breakthrough: {p1} for {t}. {score}.",
		"{p1} gets the opener. {opp} have work to do.",
	], "chaos": [
		"First blood to {t}: {p1} with the opener.",
		"{p1} scores the first and sets off on a lap of honour. Of the car park. {score}.",
		"{p1} opens the scoring. The scoreboard operator wakes up with a start. {score}.",
	]},
	"goal.equaliser": {"p": 2, "lines": [
		"{p1} levels it! {score}, and it's anybody's.",
		"Back on terms: {p1} for {t}. {score}.",
		"{t} are level! {p1} with the equaliser. {score}.",
		"{p1} pulls {t} level at {score}.",
		"All square: {p1} makes it {score}.",
		"The equaliser, and it's {p1}. {score}.",
	], "chaos": [
		"{p1} equalises and points at the name on his own shirt for a full minute. {score}.",
		"Level! The {t} end throws a sofa. Nobody knows where they got a sofa. {score}.",
	]},
	"goal.equaliser.late": {"p": 2, "lines": [
		"{p1} equalises in minute {min}! {score}!",
		"Late drama: {p1} drags {t} level at {score}!",
		"{t} rescue it late on! {p1}! {score}.",
		"Just when {opp} thought they'd done it: {p1}! {score}.",
	], "chaos": [
		"{p1} equalises with the clock wheezing toward the tunnel! {score}!",
		"{p1} levels it so late the groundsman had already started mowing. {score}!",
	]},
	"goal.equaliser.short": {"p": 2, "lines": [
		"A man down and still level: {p1} for {t}. {score}.",
		"{t} are short-handed, but {p1} has them back on terms. {score}.",
		"Against the odds, {p1} equalises for {t}. {score}.",
	], "chaos": [
		"Ten men, one ball, zero respect for the scoreline: {p1} makes it {score}!",
		"{t} are a man short, so {p1} has decided to play for two. {score}!",
	]},
	"goal.late": {"p": 2, "lines": [
		"{p1}, in minute {min}! {t} can see the finish line. {score}.",
		"A late one from {p1}, and {opp} are running out of time. {score}.",
		"{p1} with a late goal that could decide it. {score}.",
		"Late in the game, and {p1} might just have won it. {score}.",
	], "chaos": [
		"{p1} scores so late the referee is already halfway into his coat. {score}.",
		"{p1}! The {opp} fans who left early will be hearing about this. {score}.",
	]},
	"goal.back": {"p": 2, "lines": [
		"{p1} pulls one back for {t}. {score}: game on?",
		"{t} are not done yet: {p1} makes it {score}.",
		"{p1} gives {t} hope. {score}.",
		"A goal back for {t}, through {p1}. {score}.",
		"{p1} reduces the arrears. {score}.",
	], "chaos": [
		"{p1} pulls one back and celebrates like he's won the league. It's {score}. Steady on.",
		"{t} pull one back! {p1} celebrates by hugging the referee, who did not ask for this. {score}.",
	]},
	"goal.clincher": {"p": 2, "lines": [
		"{p1} makes it {score}. That should be that.",
		"Surely that's that: {p1}, {score}.",
		"{p1} puts the game beyond {opp}. {score}.",
		"{p1} with the goal that settles it. {score}.",
	], "chaos": [
		"{p1} makes it {score}. That's the coach's tie loosened.",
		"{p1} makes it {score}. The {opp} fans start reading their programmes.",
	]},
	"goal.hat_trick": {"p": 2, "lines": [
		"HAT-TRICK! Three for {p1}!",
		"That's three for {p1}! A hat-trick to remember.",
		"{p1} completes his hat-trick. What a performance.",
	], "chaos": [
		"HAT-TRICK! {p1} wants the match ball and probably the corner flags too.",
		"Three for {p1}! Somebody fetch him a bag for the ball.",
		"{p1} has a hat-trick and is now legally allowed to name a stand after himself.",
	]},
	"goal.own": {"p": 2, "lines": [
		"Own goal! {p1} turns it into his own net. {score}.",
		"{p1} gets the last touch, and it's an own goal. {score}.",
		"Oh dear: an own goal by {p1}. {score}.",
		"Unlucky for {p1}: into his own net. {score}.",
	], "chaos": [
		"{p1} finds the net. The wrong one, mind. {score}.",
		"Own goal! {p1} won't be sending that one to his mum. {score}.",
		"{p1} scores at the wrong end and looks around for someone to blame. {score}.",
	]},
	"goal.golden": {"p": 2, "lines": [
		"GOLDEN GOAL! {p1} ends it for {t}!",
		"{p1}! Golden goal, and it's all over.",
		"Sudden death, and {p1} delivers it. {t} win it!",
	], "chaos": [
		"{p1} ends it! {opp} can go home. Some of them already have.",
	]},
	"goal.fireball": {"p": 2, "lines": [
		"{p1} sets the ball on fire. The keeper declines to get involved. {score}.",
		"FIREBALL! {p1} scores, and the net is now mostly smoke. {score}.",
	]},
	"goal.banana": {"p": 2, "lines": [
		"{p1}'s banana bends round everybody and in. {score}. Physics is filing a complaint.",
		"{p1} curls it round the wall, the keeper and a passing satellite. {score}.",
	]},
	"goal.thunder": {"p": 2, "lines": [
		"THUNDER STRIKE! Somewhere a seismograph rings in sick. {score}.",
		"THUNDER STRIKE from {p1}! The keeper is still checking if he has all his fingers. {score}.",
	]},
	"shot": {"p": 1, "lines": [
		"{p1} lets fly...",
		"{p1} has a go...",
		"{p1} pulls the trigger...",
		"{p1} shoots...",
		"Here's {p1}, he shoots...",
		"{p1} tries his luck...",
	], "chaos": [
		"{p1} shoots with his eyes closed...",
		"{p1} hits it like it owes him money...",
		"{p1} shoots! A pigeon ducks...",
	]},
	"shot.long": {"p": 1, "lines": [
		"{p1} tries his luck from way out...",
		"From distance, {p1}...",
		"{p1} from long range...",
		"A speculative effort from {p1}...",
	], "chaos": [
		"{p1} shoots from his own postcode...",
		"{p1} from so far out it needs a passport...",
	]},
	"shot.missed": {"p": 0, "lines": [
		"...and it's nowhere near.",
		"...and it's wide.",
		"...over the bar.",
		"...and it drifts past the post.",
		"...not troubling the keeper.",
		"...he'll be disappointed with that.",
	], "chaos": [
		"...the ball boys get some exercise.",
		"...row Z thanks him for the souvenir.",
		"...a seagull in the car park has been informed.",
		"...that one's still going.",
	]},
	"fireball": {"p": 1, "lines": ["FIREBALL from {p1}...", "{p1} sets the ball alight..."]},
	"banana": {"p": 1, "lines": ["{p1} peels off a banana shot...", "{p1} bends one like a boomerang..."]},
	"thunder": {"p": 1, "lines": ["{p1} winds up the THUNDER STRIKE...", "The sky goes dark. {p1} is about to hit it..."]},
	"save": {"p": 1, "lines": [
		"...and {p1} gets a glove on it!",
		"...{p1} says no!",
		"...saved by {p1}.",
		"...a fine save from {p1}.",
		"...{p1} is equal to it.",
		"...{p1} gets down well to keep it out.",
	], "chaos": [
		"...{p1} saves it with his face. He seems fine. Mostly.",
		"...{p1} catches it and checks it for fingerprints.",
		"...{p1} says no, and then says it again, louder.",
	]},
	"woodwork": {"p": 1, "lines": [
		"...it rattles the post!",
		"...off the crossbar!",
		"...the woodwork comes to the rescue!",
		"...against the frame of the goal!",
	], "chaos": [
		"...off the woodwork! The frame of the goal earns its wages.",
		"...the post is not amused.",
		"...DOINK. The crossbar will feel that tomorrow.",
	]},
	"header": {"p": 0, "lines": [
		"{p1} gets his head to it.",
		"A header from {p1}.",
		"{p1} rises highest.",
		"Headed on by {p1}.",
	], "chaos": [
		"{p1} heads it with the forehead of a man who has headed many things.",
		"{p1} nods it on. His hair didn't move.",
	]},
	"volley": {"p": 0, "lines": [
		"{p1} hits it on the volley.",
		"First time, on the volley: {p1}.",
		"{p1} meets it on the volley.",
		"{p1} strikes it first time.",
	], "chaos": [
		"{p1} volleys it and very nearly volleys himself.",
	]},
	"clearance": {"p": 0, "lines": [
		"{p1} hoofs it clear.",
		"{p1} clears.",
		"{p1} gets it away.",
		"Cleared by {p1}.",
	], "chaos": [
		"{p1} clears his lines. Subtlety: optional.",
		"{p1} launches it into low orbit.",
	]},
	"dodge": {"p": 0, "lines": [
		"{t} skip over the tackle.",
		"Hurdled! {t} ride the challenge.",
	]},
	"nutmeg": {"p": 0, "lines": [
		"Through the legs! Nutmeg from {p1}.",
		"Nutmeg! {p1} is enjoying himself.",
		"{p1} threads it through the defender's legs.",
	], "chaos": [
		"Through the legs! He'll tell his mum it didn't happen.",
		"{p1} threads it through the legs. Rude, but effective.",
		"Megs! {p1} leaves a defender checking his shorts.",
	]},
	"rainbow": {"p": 0, "lines": [
		"Rainbow flick from {p1}!",
		"{p1} flicks it over the defender's head.",
	], "chaos": [
		"{p1} flicks a rainbow over the top. Show-off.",
		"{p1} goes over the top with the rainbow. The crowd go \"ooh\".",
		"Up and over: {p1} has been watching videos again.",
	]},
	"bckheel": {"p": 0, "lines": [
		"A cheeky backheel from {p1}.",
		"{p1} with the backheel.",
	], "chaos": [
		"{p1} backheels it without looking. Or possibly without knowing.",
	]},
	"body check won": {"p": 0, "lines": ["{t} go shoulder-first through the middle. Legal-ish.", "Body check! {t} win that one the hard way."]},
	"dizzy": {"p": 0, "lines": ["One of {t}'s lads is seeing stars. And possibly birds.", "Dizzy! Somebody hold up some fingers."]},
	"foul": {"p": 1, "lines": [
		"{p1} goes through {p2}. Free kick.",
		"Foul by {p1} on {p2}. The referee's having none of it.",
		"{p1} clatters {p2}, and the whistle goes.",
		"A late challenge from {p1} on {p2}.",
		"{p1} catches {p2}, and that's a free kick.",
		"{p2} is brought down by {p1}.",
	], "chaos": [
		"{p1} tackles {p2} like he's settling a family argument.",
		"{p1} goes through {p2}, then politely asks if he's alright.",
		"{p2} goes down. {p1} is already explaining with both hands.",
	]},
	"unseen foul": {"p": 1, "lines": [
		"{p1} takes {p2} out, but the referee didn't see it.",
		"{p2} is down after a challenge from {p1}, and play goes on.",
	], "chaos": [
		"{p1} takes {p2} clean out. The referee is admiring the floodlights.",
		"{p1} flattens {p2} and nobody in black saw a thing.",
	]},
	"late whistle": {"p": 1, "lines": [
		"Hang on: the referee spots {p2} still down. He's going back for it.",
		"The referee brings it back: {p2} was fouled.",
	], "chaos": [
		"Late whistle! The referee has finished his sightseeing.",
	]},
	"advantage": {"p": 0, "lines": ["The referee waves play on. Advantage {t}.", "Advantage! {t} carry on."]},
	"advantage played": {"p": 0, "lines": ["The advantage holds. He'll have a word at the next stoppage."]},
	"brought back": {"p": 0, "lines": ["No advantage after all: back for the free kick."]},
	"ref warning": {"p": 1, "lines": [
		"The referee calls {p1} over. That's a final warning.",
		"A stern word for {p1} from the referee.",
	], "chaos": [
		"The referee calls {p1} over. The notebook is out and his name's getting underlined.",
		"A word in {p1}'s ear. That's the final warning, by the look of the finger.",
	]},
	"yellow card": {"p": 1, "lines": [
		"{p1} goes in the book.",
		"Yellow card for {p1}.",
		"{p1} is booked.",
		"The referee shows {p1} the yellow card.",
		"A caution for {p1}.",
		"{p1} picks up a yellow.",
	], "chaos": [
		"{p1} is booked. He looks shocked. Nobody else does.",
		"Yellow for {p1}, who argues so hard he nearly gets another one.",
	]},
	"red card": {"p": 2, "lines": [
		"RED CARD! {p1} is sent off. {t} are a man down.",
		"Off you go, {p1}! Straight down the tunnel.",
		"The referee shows {p1} the red card.",
		"{p1} is sent off! A big blow for {t}.",
	], "chaos": [
		"RED! {p1} leaves the pitch slowly, by the scenic route.",
		"{p1} is sent off and tries to shake the referee's hand. The referee is not having it.",
	]},
	"red card.second": {"p": 2, "lines": [
		"Second yellow! {p1} is off.",
		"That's two yellows for {p1}, and he has to go.",
	], "chaos": [
		"Second yellow! {p1} is escorted to the naughty step.",
		"That's two yellows for {p1}, and two yellows make an early bath.",
	]},
	"last man": {"p": 1, "lines": [
		"{p2} was through, and {p1} was the last man.",
	], "chaos": [
		"{p2} was through, and {p1} was the last man. Uh-oh.",
	]},
	"offside": {"p": 0, "lines": [
		"Flag's up: {p1} went too early.",
		"{p1} is caught offside.",
		"Offside against {p1}.",
	], "chaos": [
		"{p1} was offside by about a postcode.",
		"{p1} was so offside he was nearly in the car park.",
	]},
	"penalty": {"p": 2, "lines": [
		"PENALTY to {t}!",
		"The referee points to the spot! Penalty, {t}.",
		"Penalty! {t} have a chance from the spot.",
	], "chaos": [
		"PENALTY! The {opp} bench throws its water bottles in protest. All of them.",
	]},
	"corner": {"p": 0, "lines": [
		"Corner to {t}.",
		"{t} win a corner.",
		"It's a corner for {t}.",
		"{t} force a corner.",
	], "chaos": [
		"Corner to {t}. Everybody in the box starts holding shirts.",
		"{t} win a corner, and their centre-backs jog up like it's a holiday.",
	]},
	"dive": {"p": 1, "lines": [
		"{p1} goes down too easily, and the referee isn't buying.",
		"Dive! {p1} is booked for simulation.",
	], "chaos": [
		"{p1} goes down like a sack of potatoes, and the referee isn't buying.",
		"Dive! {p1} gets a card for his acting.",
	]},
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
	"substitution": {"p": 0, "lines": [
		"A change for {t}.",
		"{t} make a substitution.",
		"{t} make a change.",
	], "chaos": [
		"A change for {t}. The sub has been warming up since kick-off and is now mostly sweat.",
	]},
	"half time": {"p": 2, "lines": [
		"That's the half: {score}.",
		"The referee blows for half time. {score}.",
		"Half time, and it's {score}.",
	], "chaos": [
		"Half time, {score}. Orange slices and stern words.",
		"Half time: {score}. The players go in, the mascot comes out and attempts a backflip.",
	]},
	"extra time": {"p": 2, "lines": [
		"Extra time, {score}.",
		"Level after ninety: extra time, {score}.",
	], "chaos": [
		"Extra time, {score}. Legs are optional from here.",
	]},
	"full time": {"p": 2, "lines": [
		"Full time: {score}.",
		"It's all over! {score}.",
		"The final whistle goes. {score}.",
		"That's it: {score} at full time.",
	], "chaos": [
		"Full time: {score}. The crowd heads for the exits and the pies.",
	]},
	"shoot-out": {"p": 1, "lines": [
		"Penalties it is!",
		"It goes to a penalty shoot-out.",
	], "chaos": [
		"Penalties! Somebody check on the goalkeepers' nerves.",
	]},
	"lull": {"p": 0, "lines": [
		"{t} keep the ball, probing for an opening.",
		"Patient build-up from {t}.",
		"{p1} looks for a pass. Nothing on just yet.",
		"{t} are happy to move it around at the back.",
		"{opp} sit deep and wait.",
		"It's {score}, in minute {min}.",
		"{p1} takes his time on the ball.",
		"Not much between the sides at the moment.",
		"The {t} supporters are in good voice.",
		"Both sides are still feeling each other out.",
		"{t} switch the play, looking for space on the other flank.",
		"{opp} are pressing, but {t} keep their composure.",
	], "chaos": [
		"Someone in the crowd has brought a trombone. Someone else has brought a second trombone. This is escalating.",
		"A pitch invader! No, it's a seagull. It's had more touches than {opp}'s midfield.",
		"{p2} has stopped to tie his laces. Both of them. In the middle of play.",
		"The {t} fans have started a conga line in the upper tier. Security has joined in.",
		"{p2} is waving at someone in the stands. It might be his mum. It might be his bank manager.",
		"A beach ball is bouncing around the away end. It's moving better than {opp}'s back line.",
		"{p2} appears to be arguing with his own shadow. The shadow is winning.",
		"The mascot has fallen over. The crowd gives it a standing ovation.",
		"Somebody in row F is eating a full roast dinner. With gravy.",
		"{p2} has just checked his hair in the shine of the advertising boards.",
		"The {t} supporters are singing a song about {p1}. Most of it rhymes.",
		"{p2} is jogging backwards for no reason anybody can explain.",
		"A Mexican wave goes round the ground and gets stuck at the directors' box.",
		"The floodlights flicker. {p2} looks personally offended.",
		"{p1} has the ball and the look of a man with a plan. Nobody else has seen the plan.",
		"Someone has thrown a rubber chicken onto the pitch. The referee pockets it for later.",
		"{p2} is doing his stretches in the centre circle. During play.",
		"Half the {opp} end is doing the hokey cokey. The other half is doing it wrong.",
		"A dog has got into the stadium. Three stewards are chasing it, and the dog is winning.",
		"{p2} just asked the linesman what the score is. It's {score}, {p2}.",
		"The drummer in the {t} end has lost his sticks and carries on with two bananas.",
		"{p2} is shouting instructions at his teammates. They're ignoring him, which is a tactic in itself.",
	]},
}
