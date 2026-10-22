# Extreme Hill Climb

A modular activity system using the existing Godot VehicleBody3D vehicles,
2048 m terrain, quarter-metre mud patches, forest assets, audio and GPS.
No engine migration or replacement map is involved.

## Playing

The amber/colored ground rings and ▲ GPS icons are discovery points. A roadside
hub is just beside the starting depot; two more are near the quarry and forest
camp. Twelve start bays are on the western face of the eastern mountain,
X 240–605 / Z 155–440. Stop upright inside a ring for 0.7 seconds, then press E.
At a roadside hub, [ / ] selects any enabled route before confirmation.

The same selected vehicle, tires, AWD, differential, fuel and engine state are
used. A three-second countdown positions the vehicle in the route's stopping
bay. E controls AWD again while driving; Q/F/T retain their existing functions.
Follow the numbered checkpoints and the highlighted GPS route in order.

- R: retry from the starting bay (also available while driving).
- Backspace: exit. An abandoned/failed run returns to its discovery location;
  Free Roam after a finish leaves the vehicle at the summit.
- Results: Replay, Next Challenge or Free Roam; Enter replays, Tab selects next.
- Esc: existing pause menu. Countdown, race clock and the vehicle pause with the menu.
- Garage selection ends the activity before switching vehicles. Number-key
  swaps are blocked during a run so one vehicle earns each record.

Easy courses use broad dirt tracks. Medium courses introduce rocks, switchbacks
and a water cut. Hard courses use deep mud, narrower shelves and boulder steps.
Extreme routes include a roughly 90% checkpoint-to-checkpoint grade, 3.4–3.6 m
wide sections, hairpins and muddy ruts. Rock support uses hard-surface grip and does not deform the mud beneath it.
Existing traction, gearing, suspension
and mud resistance determine whether a vehicle can climb. There is no scripted
uphill propulsion. Some vehicles and tire choices may be unable to finish.
Two marked bypasses trade extra distance for a way around large obstacles.

## Records and failure

The timer starts after the countdown. Every intermediate checkpoint must be
reached in order, including its height. A swept position test catches legitimate
crossings at speed; large resets cannot award checkpoints. Rollover, leaving
the route for ten seconds, falling through the surface, vehicle substitution
and the generous route time limit lead to Retry/Exit. Getting stuck is allowed;
a delayed hint suggests low range, AWD, differential and tires.

Gold is awarded within the route's target time, Silver within 1.5 times that
limit, Bronze for other completed attempts. Personal best, medal and completion
count are stored per route and vehicle in `user://hill_climb_records.cfg`.
Writes use a temporary file and preserve the previous `.bak`. Existing unknown
sections are retained. An unreadable save is not overwritten; results report a
save failure while retaining the session record in memory. Other game files
and saved progress are not edited.

## Modules and switches

- `hill_climb_catalog.gd`: twelve authored routes, difficulty, widths and medal times.
- `hill_climb_zone.gd`: spatially indexed local terrain sculpting and initial ruts.
- `hill_climb_activity.gd`: confirmation, input ownership and activity lifecycle.
- `hill_climb_records.gd`: independent progress storage and backup.
- `hill_climb_world.gd`: distance-limited discovery rings, posts, collision rocks,
  shallow trenches, summit signs and reused pine assets via MultiMesh.
- `hill_climb_ui.gd`: prompt, countdown, race HUD and result buttons.

Set `offroad/hill_climb_enabled=false` in project settings to omit the park and
activity system entirely. `activities.set_activity_enabled(route_id, false)`
disables an individual route's discovery/start and GPS markers and cancels an
active attempt safely. This choice persists. Existing park scenery remains
when individual activities are disabled.

Sculpting is bounded to about 0.104 km² (2.5% of the world). Asphalt and an 18 m
road corridor are protected, as is the existing valley trail. Only roughly
3400 of 263169 world height samples change. Vegetation placement retains the original random sequence; outside-park plant
transforms and tree/wood collision positions remain unchanged. Inside the zone,
only track vegetation is cleared and hillside plants follow the new surface.
No road spline, existing vehicle model or landmark is replaced. Near the car, quarter-metre colliders include
pre-existing ruts and new wheel deformation. Distant terrain remains coarse.
Mud clods retain the bounded 256-instance pool. No large light beams, continuous
activity lights or per-frame terrain rebuilds were added.

## Validation and limits

- 95 activity/record assertions cover all twelve ordered finishes, confirmation,
  drive-through rejection, retry, exit, next challenge, medals, vehicle-specific
  records, persistence, disable flags, idempotent finish and corrupt-save protection.
- Full-scene integration covers actual buffered keyboard input, E/AWD isolation,
  countdown, pause/resume, results UI buttons, R versus road reset, Backspace,
  garage transitions and shared GPS state.
- Baseline comparison verifies all terrain outside the zone, all protected roads
  and the existing valley trail keep their previous heights. The feature-off
  world has the original heightfield.
- A full before/after forest comparison preserves all outside-park vegetation
  instance transforms, not just terrain heights.
- A real-physics scout probe climbed the easy entry: about 15 m travel and 3.4 m
  rise. This is an entry check, not proof all routes are completable in all cars.
- Existing mud/sinking, map/road seams, audio, menu and Lada driving checks pass.

This is an authored playable prototype. Course medal times and the hardest
obstacles still need human driving tests and balancing. Shallow trench water
is visual, without buoyancy or a fluid solver. Headless tests do not verify
Metal rendering, visible art quality, audio balance or frame rate on the M4.
