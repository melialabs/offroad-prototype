# Mountain roads: 2048 m world

An original deterministic world assembled from the project's existing terrain,
road shader, vegetation and simple original landmark meshes. No third-party
game map or models were downloaded or copied.

- Playable bounds: 2048 x 2048 m (4.19 square kilometres).
- Paved loop: approximately 6.1 km, 8 m wide, maximum centreline grade 10%.
- Muddy shortcut through the central valley and lake region.
- Three broad mountain masses, wooded hills, a lake basin and outer ridges.
- Depot shelter, quarry blocks, mountain pass, forest camp and lake stop.
- Reflective-style roadside marker posts and text signs.
- GPS stays at bottom left with position and heading; M expands the overview.
- Crossing the 1010 m world boundary returns the vehicle to the starting road.

Terrain uses a 513 x 513 height grid at 4 m spacing. 256 chunks of 128 m
share border samples and use independent meshes and height-map colliders.
Deformation rebuilds affected chunks and neighbours rather than the entire
world. A separate smooth paved ribbon supplies the road collision surface.
Trees are capped at 6000 and use the existing LOD/MultiMesh system. Other
plants are placed at lower world-scale density; current seed produces about
90000 total vegetation instances distributed across the whole map.

The world is generated from a fixed seed, not reshuffled at every launch.
This keeps routes, navigation and tests reproducible. Its layout varies terrain
forms and vegetation rather than repeating a small terrain tile verbatim.

## Validation and limits

World-size, closed-loop route, grade, bounds and shared-collider seam tests
passed. Terrain generation and chunk construction took about 1.6 seconds in
an isolated headless run on this host. This excludes loading vegetation,
vehicles and GPU resources and is not a full startup or FPS benchmark.
The surface-physics, terrain, menu and vehicle regression tests were run.

A moving 48 m square around the car uses 25 cm soil samples for narrow tire
ruts. Nine 16 m patches share boundary heights; up to 256 visited patches
retain their ruts for the current session. Three shallow swamp basins lie along
the valley shortcut. Roadside structures are simple prototype geometry. Visual quality,
GPU FPS, distant terrain and every kilometre of driving still require a visible
playtest on the Mac; headless tests cannot establish those properties.
