# Mənbələr və lisenziyalar

## Skaut maşın modeli

This work is based on "Jeep Wrangler (free)" (https://sketchfab.com/3d-models/jeep-wrangler-free-4528c95e2c0c425585fc3a3f49f6bad9) by 3DFU_XXX (https://sketchfab.com/3DFU_XXX) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

Dəyişikliklər: model oyunda "Skaut" adı ilə istifadə olunur, təkərlər ayrı meshlərə bölünüb,
ölçü və mövqe fizikaya uyğunlaşdırılıb. "Jeep" və "Wrangler" adları Stellantis brendləridir və oyunda
göstərilmir. Redizayn mərhələsində model öz dizaynımızla əvəz olunacaq.

## Ağaclar

Kenney "Nature Kit" 2.1 (https://kenney.nl), CC0. Lisenziya: assets/models/License.txt

## Torpaq teksturası

Poly Haven "Forest Ground 04" (https://polyhaven.com/a/forest_ground_04), CC0, 1K.

## Fizika parametrləri üçün istinad

Rigs of Rods sənədləri (https://docs.rigsofrods.org) yalnız rəqəmləri və ideyaları öyrənmək üçün oxunub. Kod götürülməyib.

## Asfalt teksturası

Poly Haven "Clean Asphalt" (https://polyhaven.com/a/clean_asphalt), CC0, 1K. Sarı xətlər shader ilə çəkilir.

## Terrain teksturaları (1K, CC0, Poly Haven)

rocks_ground_08 (torpaq yol), brown_mud_02 (palçıq), brown_mud_03 (dərin palçıq), ganges_river_pebbles (daşlı səth),
rocky_terrain_02 (ot), snow_02 (qar), rock_ground (qaya yamac). Mənbə: https://polyhaven.com/textures

Qeyd: istifadəçinin `offroad_texture_references.zip` faylındakı şəkillər yalnız vizual istinad kimi istifadə olunub,
oyuna daxil edilməyib.

## Meşə modelləri (Poly Haven, CC0)

Mənbə: https://polyhaven.com (lisenziya CC0, atribusiya məcburi deyil, mənbə və müəlliflər qeyd olunur).
Orijinallar `assets_src/polyhaven/` qovluğunda saxlanılır (git-ə daxil edilmir), oyunda isə `tools/blender_optimize.py` ilə
hazırlanmış optimallaşdırılmış versiyalar (`assets/vegetation/`) istifadə olunur. Yükləmə: `python tools/download_forest_assets.py`.

| Model | Müəlliflər | Mənbə |
|---|---|---|
| Pine Tree 01 | Rob Tuytel (photography), Rico Cilliers (modeling) | https://polyhaven.com/a/pine_tree_01 |
| Pine Sapling Medium | Rob Tuytel (photography), Rico Cilliers (modeling) | https://polyhaven.com/a/pine_sapling_medium |
| Pine Sapling Small | Rob Tuytel (photography), Rico Cilliers (modeling) | https://polyhaven.com/a/pine_sapling_small |
| Fir Tree 01 | Rob Tuytel (photography), Rico Cilliers (modeling) | https://polyhaven.com/a/fir_tree_01 |
| Tree Small 02 | Rico Cilliers (All) | https://polyhaven.com/a/tree_small_02 |
| Shrub 02 | Rico Cilliers (All) | https://polyhaven.com/a/shrub_02 |
| Shrub 04 | Rico Cilliers (All) | https://polyhaven.com/a/shrub_04 |
| Fern 02 | Rob Tuytel (scanning), Rico Cilliers (modeling) | https://polyhaven.com/a/fern_02 |
| Grass Medium 01 | Rob Tuytel (Photography), Rico Cilliers (Modeling) | https://polyhaven.com/a/grass_medium_01 |
| Grass Bermuda 01 | Rico Cilliers (All) | https://polyhaven.com/a/grass_bermuda_01 |
| Tree Stump 01 | Rob Tuytel (All) | https://polyhaven.com/a/tree_stump_01 |
| Dead Tree Trunk | Rob Tuytel (All) | https://polyhaven.com/a/dead_tree_trunk |

## Lada modelləri (Sketchfab, CC BY 4.0)

Modellər `tools/blender_vehicle_prep.py` ilə oyun üçün hazırlanıb (miqyas, təkərlərin ayrılması, tekstura kiçildilməsi, VAZ 2106-da üçbucaqların azaldılması). Müəlliflərə aid hüquqlar saxlanılır.

- **Lada Niva** — Greg McKechnie (https://sketchfab.com/mckechniegreg6), https://sketchfab.com/3d-models/lada-niva-26ebf5872bce4ff4ad2baee41882d6b2, CC BY 4.0
- **LADA 2107** — tiunov.se (https://sketchfab.com/tiunov.se), https://sketchfab.com/3d-models/lada-2107-31201f80892b404a8e49c272490a664c, CC BY 4.0
- **Lada VAZ 2106 AZELOW Style Classic Soviet Car 3D** — Abram (https://sketchfab.com/AbramBusiness), https://sketchfab.com/3d-models/lada-vaz-2106-azelow-style-classic-soviet-car-3d-7e4171a38afb406681ae5e74db56fa99, CC BY 4.0

## İstifadəçinin təqdim etdiyi UAZ modelləri

- **Uaz 452 "Bukhanka"** — Lisnik234 (https://sketchfab.com/Lisnik234),
  https://sketchfab.com/3d-models/uaz-452-bukhanka-80dc40288f8b4b59a6b2a7593b8387d2,
  CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
- **Post Apocalyptic UAZ** və **UAZ 469 Classic (1973)** — istifadəçinin təqdim
  etdiyi fayllar. Fayllarda müəllif/lisenziya qeydi yoxdur; onlara CC0 və ya CC BY
  lisenziyası aid edilmir. İlkin metadata saxlanılıb.

Dəyişikliklər: dünya transformları tətbiq edilib, dörd təkər və həqiqi fənər
üzləri ayrılıb, teksturalar 1K-a kiçildilib, fizika və qaraj önizləmələri hazırlanıb.
`tools/prepare_uaz_models.py` ilə təkrar hazırlamaq mümkündür.

## Səslər

Mühərrik və avtomobil effektləri `game_audio.gd` ilə sintez olunur. Meşə, quşlar, gecə həşəratları, bayquş və su səsləri real CC0 qeydləridir. Müəlliflər, mənbələr və emal məlumatları: [assets/audio/CREDITS.md](assets/audio/CREDITS.md) və [SOURCES.json](assets/audio/SOURCES.json).
