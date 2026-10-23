# Graphics pass (Godot 4.7.2, Forward+ / Metal)

Base look (all profiles, `main.gd` `_setup_environment`): ACES tonemapping with a high white point, sky
ambient 0.62, sun 1.55, saturation 1.08 / contrast 1.05, depth fog that starts at 90 m with aerial
perspective so near objects stay clear and distant mountains sit in soft atmosphere. Glow is limited
(threshold 1.35, no bloom). Night closes the fog to 900 m.

Quality profiles (`graphics_quality.gd`, Options → Graphics, saved in `user://offroad_settings.cfg`):

| | LOW | MEDIUM (default) | HIGH | ULTRA |
|---|---|---|---|---|
| Sun shadows | 70 m, 2 splits | 120 m, 4 splits | 160 m, 4 splits | 240 m, 4 splits, PCSS |
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
