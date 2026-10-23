# Exhaust plume

`ExhaustSmoke` retains the real engine-state connection to `GameAudio`. Cranking
emits a little exhaust; the actual CRANKING → RUNNING transition gives a 1.8 s
burst. Warm petrol idle is faint. Diesel gets darker ignition smoke and brief
throttle-tip-in soot, not a permanent black idle cloud. Travel thins emissions.

The old unshaded circular sprite is replaced by a lit volume impostor shader.
Six samples through a shared seamless 32³ density field erode the outline and
create changing internal wisps. Random rolls/phases prevent repeated shapes.
Soft depth intersections avoid hard cuts into terrain/bodywork; ambient, sun
and lamps illuminate the plume without emissive night smoke. This approximates
smoke optically; it is not a fluid solver or a full-screen volumetric effect.

Gas inherits vehicle velocity, then loses jet momentum to the shared wind.
Buoyancy and curl broaden the plume, with optical density falling as it expands.
Births interpolate the moving mouth and transparent puffs sort back-to-front.
A fixed 144-puff ring, one shared small noise texture and cullable world bounds
limit cost. Metal frame rate has not been measured in this session.

Each vehicle has an open metal outlet. Passenger-car mouths were moved beyond
measured imported-body bounds (including bumpers/accessories); the procedural
trucks have upright stacks outside their cabs. Existing imported meshes,
physics and engine samples are unchanged. These are fitted outlets, not a
claim that every downloaded model already had accurate exhaust geometry.

Validation on macOS / Godot 4.7.2:
- `tests/exhaust_plume_test.gd`: state changes, wind transport, inherited
  velocity, dilution, expansion, depth ordering, shutdown, reset, all-nine
  outlet orientations and clearance from actual imported bumper geometry.
- `tests/recovery_effects_test.gd`: all-nine starter/smoke synchronization,
  ignition/idle/moving/off states, shared wind and bounded particle count.

GPU compilation, final appearance and frame rate still need a normal game run.
Native window rendering was unavailable in the automation environment. The
optional `tests/exhaust_render_test.gd` produces day/start/idle/diesel/night
captures in `/tmp` when run with a real window (omit `--headless`); it explicitly
skips on a headless renderer. Automated logic tests do not prove visual realism.
