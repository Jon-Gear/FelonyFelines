# ADR-0003 — Split-screen preserves the intentional 10 px camera-offset quirk

Status: **Accepted**

Deciders: Restructure spec (`RESTRUCTURE_PLAN.md`, user story 15), issue
Jon-Gear/FelonyFelines#14

Date: 2026-09-21

## Context

`camera_controller.gd:46` computes camera 2's target position with brother 1's
visual offset instead of brother 2's:

```
func get_player2_position():
	return player2.global_position + player1.player_visual_middle
```

`player_visual_middle` differs per brother: `Vector2(0, -50 + 10)` for brother 1
(player.gd:40) and `Vector2(0, -50)` for brother 2 (player.gd:45). The difference
is exactly 10 px. Player 1 (red) reads higher up and player 2 (blue) reads lower —
a small, deliberate-looking composition quirk. It looks intentional (red is
slightly taller on screen); it is shipped behavior, and the restructure must not
change what the player sees.

## Decision

The split-screen migration **preserves the 10 px camera-offset quirk exactly** —
the same reading difference, whatever the geometry refactor looks like. It is
recorded here so a future reviewer does not "fix" it as a bug. A dedicated task
can reverse it; no incidental task may.

## Consequences

- The quirk is now a documented decision instead of a silent bug — reviewers know
  not to "fix" it (user story 15).
- When the split-screen geometry becomes a pure function (user story 14), the
  offset rule is encoded in that function and tested; the behavior stays identical.
- A dedicated future task may reverse the quirk only with this ADR superseded.