# Street Up - Complete v0 Rules + Setup Plan

## Game Vision
Street Up starts as a simple 7-on-7 **American football** street game (not soccer).
The first playable goal is not polished multiplayer yet.
The first goal is:
- Two AI teams.
- Moving the ball up the field.
- Scoring in opposite end zones.
- Repeating drives so we can tune football AI behavior.

## Visual Identity (Current Prototype)
- Field color: Green.
- End zones:
	- One Red.
	- One Blue.
- Team look:
	- Red team uses red capsule/bean players.
	- Blue team uses blue capsule/bean players.
- Direction:
	- Blue offense attacks the red end zone.
	- Red offense attacks the blue end zone.

## Prototype Player Model Rules
- Everyone is a simple bean/capsule for now.
- The football is a simple bean/ball placeholder.
- No realistic player models required in v0.

## Core 7-on-7 Format
- 7 players on offense.
- 7 players on defense.
- Smaller street field than full 11-man football.
- Fast possessions and short match flow.

## Roles (Temporary + Flexible)
For v0, role assignment is light and can change during play.
- Offense can include:
	- QB
	- Center/snapping role
	- Utility backs
	- Receivers
- Defense can include:
	- Rusher(s)
	- Coverage defenders
	- Deep defenders

## In-Game Role Switching (Planned)
- Players can vote/switch into different roles during the game.
- Formal role-lock rules are postponed.
- Priority is gameplay flow over strict roster restrictions.

## Ball + Drive Rules (Simple)
- Start each drive at a consistent yard line (ex: own 25).
- 4 downs to gain a first down.
- First down distance can be 10-15 yards depending on map scale.
- Turnover on downs if not converted.

## Scoring Rules
- Touchdown = 6 points.
- Conversion try after touchdown:
	- Short try = 1 point.
	- Longer try = 2 points.
- Safety = 2 points.
- Punts/field goals optional and can remain disabled in v0.

## Live Play Rules
- Snap starts each play.
- One forward pass allowed from behind line of scrimmage.
- Lateral/backward passes allowed.
- Play ends when ball carrier is down/tagged, out of bounds, or pass incomplete.
- Interceptions are live-ball turnovers.

## AI Football Behavior (Current Target)
- Offense aligns in formation before the snap.
- Play call alternates between run concepts and pass concepts.
- QB drops back, reads receiver separation, and throws when a route opens.
- Receivers run route trees (vertical, break, slant-like paths).
- Run plays use a handoff with lane + evade behavior.
- Defense mixes rushers and coverage defenders that trail assigned routes.
- Tackles and incompletions end plays; downs and distance update every snap.


## Random Player Attributes (Current Prototype)
- Each player spawns with random speed, sprint, awareness, and tackle ratings.
- Fast defenders can chase down breakaway carriers instead of always losing the race.
- Stat ranges stay close enough for fairness, but still create play-to-play variety.

## Pursuit and Contain Rules (Current Prototype)
- If the ball carrier gets past the line, the full defense switches to chase mode.
- Defenders do not stop at old assignments once the carrier breaks contain.
- Offense tries to protect the carrier with non-carrier teammates while receivers run routes until the catch event.

## Contact + Camera Prototype Rules
- Players have body collision/push behavior so teams must fight through traffic.
- Ball carriers lose speed when defenders make close contact.
- Camera follows the ball during live plays so action stays centered.

## Clock + Match Rules
- Keep it simple for now:
	- 2 halves.
	- Short running clock.
- Fine-grain late-game clock logic can be added after core AI feels good.

## AI-vs-AI Priority (Main Development Goal)
Before expanding features, we need stable AI football flow:
- AI offense chooses a carrier/target and advances.
- AI defense pursues and stops plays.
- Teams alternate possession correctly.
- Teams can repeatedly score drives in opposite directions.
- Movement and spacing look readable and football-like.

## Street Games Mode (Roadmap)
Later, Street Up will include a long-term team-building mode: **Street Games**.
- Inspired by dynasty/team-build progression loops.
- Build a squad from neighborhood talent.
- Grow roster quality over time.
- Progress through stronger competition.

## v0 Success Checklist
- Green field loads.
- Blue and red end zones are visible and correct.
- 7 blue beans + 7 red beans spawn.
- Ball/bean tracks possession.
- Two AI teams run continuously.
- Possessions change after stops/scores.
- Score updates when end zone reached.
- AI can run real football-like pass and run decisions.

## What Comes Next After v0
- Better route logic and pursuit angles.
- Play-call presets.
- Improved tackling/contact outcomes.
- Human control takeover for one or more players.
- Online/local game options.
