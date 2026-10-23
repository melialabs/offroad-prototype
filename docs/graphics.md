# Graphics pass (Godot 4.7.2, Forward+ / Metal)

Base look (all profiles, `main.gd` `_setup_environment`): ACES tonemapping with a high white point, sky
ambient 0.62, sun 1.55, saturation 1.08 / contrast 1.05, depth fog that starts at 90 m with aerial
perspective so near objects stay clear and distant mountains sit in soft atmosphere. Glow is limited
(threshold 1.35, no bloom). Night closes the fog to 900 m.

Quality profiles (`graphics_quality.gd`, Options → Graphics, saved in `user://offroad_settings.cfg`):

| | LOW | MEDIUM (default) | HIGH | ULTRA |
|---|---|---|---|---|
| Sun shadows | 70 m, 2 splits, 2048 | 120 m, 2 splits, 2048 | 160 m, 4 splits, 4096 | 240 m, 4 splits, 8192, PCSS |
| Tree shadows | 25 m | 40 m | 60 m | 90 m |
| Vehicle reflection probe | – | – | yes | yes |
| SSAO | – | half-res | half-res | full-res |
| SSIL / SDFGI / SSR | – | – | – | yes |
| Volumetric fog | – | – | light | light |
| AA | FXAA | SMAA | TAA | TAA |
| Mesh LOD threshold | 4 | 2 | 1 | 0.6 |

Vehicle/surface effects (`wheel_effects.gd`, visual only, reads wheel state): surface classes asphalt,
gravel (road shoulder), dirt, grass, mud, water; dust tinted per surface and scaled by speed/slip (on
asphalt only when the tyres spin), water splash in the lake and swamp ponds, fading tread marks
(MultiMesh, 900 segments, 45 s), soft contact-shadow decal under the vehicle. Mud clods remain in
`MudSpray`. The chase camera follows suspension heave with a small damped offset.

Measured with `tools/bench_graphics.gd` (1600x900, vsync off, M4; FPS road / barn / forest):
before 142 / 103 / 58; LOW 155 / 110 / 78; MEDIUM 101 / 66 / 41; HIGH 86 / 58 / 37; ULTRA 48 / 32 / 23.
Metal does not report GPU frame time, so frame time is used. Comparison: `docs/graphics-before-after.jpg`.

## Photoreal pass (performance, colour, reflections)

Measured cost per MEDIUM component in the forest view (41 FPS base): all sun shadows off 76, 2 splits 52,
tree shadows to 30 m 46, SSAO off 46; AA/glow/LOD < 2 FPS each. Shadows dominate because trees are
redrawn into every cascade. Applied: MEDIUM uses 2 splits and a 2048 atlas, trees cast shadows to 40 m
(profile-driven `Vegetation.set_shadow_range`), and the tree shadow proxy uses the simplest LOD
(`Vegetation.shadow_proxy_lod = 2`). MEDIUM now: road 107, barn 82, forest 65 FPS (target 60 met; SSAO kept).
Repeated runs occasionally drop to ~24 FPS when macOS throttles the occluded benchmark window; such runs
were repeated and discarded.

Colour: foliage shader warms the cold blue-green textures toward chlorophyll green with per-plant tone
variation and yellow-green translucency; grass layer slightly warmer; asphalt darkened to a neutral warm grey.

Reflections: `water.gdshader` (lake and swamp ponds) with Schlick Fresnel, two-layer animated wave normals,
depth-based colour/opacity from the depth buffer, dielectric specular; sky radiance everywhere, SSR on ULTRA.
`vehicle_materials.gd` fixes glTF materials that defaulted to metallic=1/roughness=1: paint becomes a
clear-coated dielectric, glass is smooth and transparent, rubber rough, rims/chrome metallic; materials with
metal/roughness textures are untouched. HIGH/ULTRA add a vehicle ReflectionProbe that re-renders only after
the vehicle moves 8 m (at most every 1.5 s). Wet asphalt and puddles already exist in the terrain shader
(wetness lowers roughness, puddles become mirror-like).
