# Surface physics and mud upgrade

This is an independently written approximation inspired by publicly documented
off-road mechanics. No SnowRunner/MudRunner executable, source, assets or game
configuration was extracted. REA instructions were consulted, but no REA binary
analysis was possible without a supplied game artifact and native provider.

## Changed behavior

- Separate asphalt, hard-ground and mud tire grip, with original coefficients.
- Wheelspin is excess tire tread speed relative to longitudinal contact velocity,
  rather than absolute RPM. Normal free rolling no longer counts as wheelspin.
- Terrain deformation depends on approximate per-wheel load, contact area and
  excess tread speed. Heavy loads and narrow tires dig more; coasting digs less.
- Mud resistance acts at contacting wheels and opposes horizontal contact motion.
  Deeper ruts relative to tire radius create stronger resistance.
- Vehicle-specific suspension travel, stiffness and damping for all six vehicles.
- A bounded pool of 256 clods flies in world space under gravity, hits the soil,
  flattens into short-lived deposits and retires. Emission follows contact,
  wetness, tire rotation and excess tread speed, including a stuck spinning tire.
- Three shallow swamp basins and wet rut shading give the trail deeper sections.
- Drivetrain torque is 35% stronger, with a taller final drive and fifth gear.
  Actual loaded wheel radius is now used for force conversion.

## Limits

The vehicle still uses Godot VehicleBody3D. Wheel load is an equal static-load
approximation over wheels in contact, not measured dynamic load. The terrain
world grid is 4 m, with a 25 cm local grid around the vehicle for tire-width
ruts. Soil support and the rendered rut use the same heights, updated at up to
8.3 Hz. Maximum displacement is 1.15 m, limited by softness. The car can bottom
out on its chassis before its wheels reach this depth. No simulated soft tires, suspension articulation, water
forces, winch, trailer or full soil solver is included. Snow/ice weather shaders
remain visual. Mud coefficients and suspension values require visible driving
playtests. Headless tests cannot verify rendering, vehicle feel or M4 GPU FPS.

## References

- Saber WheelFriction: https://expeditions-guides.saber.games/truck_modding/tags_and_attributes_of_trucks/truckwheels/trucktires/trucktire/wheelfriction/
- Saber Suspension: https://expeditions-guides.saber.games/truck_modding/tags_and_attributes_of_trucks/suspensionsetvariants/suspensionset/suspension/
- Saber Mud: https://expeditions-guides.saber.games/map_modding/creating_a_map/terrain/geometry_brushes_for_terrain/mud/
- Godot VehicleBody3D limitations: https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html

## Validation

- 14 surface physics checks passed.
- Existing terrain deformation/asphalt protection test passed.
- Existing drive tests passed for scout, cargo truck, heavy truck and Niva.
- Existing three-Lada model, wheel-contact and driving tests passed.
- Update installer tested for backup preservation, repeat application and
  rejection of conflicting local changes.
- The first sedan suspension tuning failed wheel-alignment checks; stiffness
  was reduced and the final three-Lada test passed without changing assertions.
- macOS sandbox certificate/editor-settings diagnostics and pre-existing
  ObjectDB exit warnings remain. No visible GPU or driving-feel validation.
