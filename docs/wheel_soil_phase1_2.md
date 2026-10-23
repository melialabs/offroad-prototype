# Wheel–soil physics, phase 1–2 (branch `physics/wheel-soil-phase1-2`)

Original approximations written for this prototype after the read-only audit in
`OFFROAD_REA_AUDIT.md`. No game asset, source or configuration value was copied; the
audit only suggested *what kinds* of quantities matter (per-surface friction zones,
viscosity, raised rut edges). **Nothing here has been run in Godot** (no editor was
available when it was written). Treat every constant as a first guess.

## What changed

| Area | File | Change |
|---|---|---|
| Per-wheel load | `offroad_surface.gd` `wheel_loads`, `vehicle.gd` `_update_wheel_state` | Weight is split by suspension compression (wheel node displacement vs. its mount) instead of an equal share. If Godot does not move the wheel node, all wheels report the same compression and the split stays equal. |
| Differential | `offroad_surface.gd` `traction_capacity`, `deliverable_force`; `vehicle.gd` | The old `diff_factor` and `mud_level` power fudge are gone. Godot gives all driven wheels the same `engine_force` (open-diff equal torque), so the limit is now per-wheel traction: open = weakest wheel (with a 25 % bias floor), locked = mean. A 15 % margin lets the limiting wheel actually spin. |
| Sinkage resistance | `offroad_surface.gd` `sinkage_resistance` | Velocity-independent resistance that grows with load and rut depth/radius. A sunk wheel must climb out instead of only feeling viscous drag. |
| Two-layer soil | `mud_patch.gd` | Per-cell `compaction`: wheels that roll without slipping firm the soil (less digging, more grip). `MAX_DEPTH * soft` remains the hard layer below. Compaction is kept in the same bounded cache as ruts. |
| Raised rut edges | `mud_patch.gd` `dig` | Displaced soil rises in a ring just outside the contact (max 12 cm). Negative depth is clamped to 0 wherever depth feeds grip, HUD or drag. |
| Chassis bottoming | `vehicle.gd` `_belly_clearance`, `offroad_surface.gd` `belly_*` | Clearance under the collider is sampled at three points. When it reaches the soil, part of the weight leaves the wheels and a drag force acts. |
| Static sinking | existing digging path | Digging already ran every physics step, so a parked truck keeps sinking; it now uses the real per-wheel load and slows as the soil compacts. |

## Not done (still open)

- Soft tire radius loss, true per-wheel torque (needs a custom wheel model instead of `VehicleBody3D`).
- Recovery beyond the existing tree winch: second vehicle, free ground anchors, stuck-state detection.
- Water, rivers, tracks persistence, mud on the body, grass crushing (phases 3–4).

## Verify before trusting

1. Run `tests/traction_phase_test.gd` and `tests/surface_physics_test.gd` headless.
2. Drive: dry ground, shallow/deep mud, spinning in place, heavy vs. light vehicle,
   diff lock on/off. Watch `truck.wheel_load_n`, `truck.belly_support` and `wheel_slip`.
3. If power feels dead on hard ground, raise `OffroadSurface.GRIP_TO_MU` or `SPIN_MARGIN`;
   if the truck never gets stuck, raise `SINK_RESISTANCE`.
4. Check that `VehicleWheel3D.position.y` really changes with suspension travel; if it does
   not, loads silently fall back to equal shares.

## Status (handoff)

- Done: code above; `tests/traction_phase_test.gd` and `tests/surface_physics_test.gd` pass headless on Godot 4.7.2,
  as do drive, mud_upgrade, terrain, powertrain, recovery_effects, cars, uaz and forest_drive tests.
- Pending: before/after comparison against commit `a883d84` (same truck, start pose, terrain, input):
  per-wheel load on flat/slope/braking/bump, standing throttle in mud, open vs locked diff on split grip,
  chassis bottoming, winch recovery from a rut, heavy vs light, asphalt stability. No such comparison has been run.
- Not verified: anything visual or any in-game driving feel.
- Water/river phase deliberately not started.
