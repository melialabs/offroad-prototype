# "Offroad Azərbaycan" map (2048 x 2048 m)

Built from the illustrated reference map. Plan and all region sizes live in `map_layout.gd` (`MapLayout`);
`MudTerrain` uses it for heights, roads, water and masks. x = east, z = south (GPS north = -z).

| Region | Where | How |
|---|---|---|
| Snowy north range | z < -480 | rising ridged mountains, peak snow above 125 m (terrain shader) |
| Göl (lake) | (0, -650), 235 x 118 m | basin, water at 9 m (`water.gdshader`) |
| River | lake east end → south-east edge | carved bed, water ribbon, 2 waterfalls; road bridges (deck, pillar, rails) |
| Qaya kanyonu | NE rectangle | 40 m plateau, creek gorge with 4 falls, orange rock tint, bare ground |
| Mədən | (690, 110), r 190 | 36 m deep terraced open pit, bare dirt/gravel; storage ruin, dirt and stone piles |
| Şəhər | (40, 10) | flat plateau, street grid, ~117 procedural houses/apartment blocks (`map_features.gd`) |
| Meşə zonası | west-centre | dense forest on a 110 m hill; Hill Climb park moved here (`HillClimbCatalog.OFFSET`) |
| Palçıq bataqlığı | (-480, 170) | low soft ground, 4 ponds, trail loop |
| Başlanğıc qarajı | (-200, 560) | flat yard, utility building, spawn |

Roads are several polylines in one array with gap flags (`MudTerrain._road_gap`); every consumer
(asphalt ribbon, lamps, GPS, vegetation, bridges) skips gap segments. Trails and rivers use the same scheme.
Scattered props (`WorldProps.SCATTER`): small rocks, boulders, fallen trees, river logs. Barns moved to
swamp-west, canyon and south-east forest; three more checked sites are reserved for the next vehicles.
