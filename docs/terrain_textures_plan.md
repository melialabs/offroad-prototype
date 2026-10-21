# Terrain teksturaları: uyğunlaşdırma planı

## İstinadlar

İstifadəçinin göndərdiyi `offroad_texture_references.zip` (8 şəkil + lövhə) **yalnız konsept istinadıdır**: seamless deyil, real PBR deyil, 4K deyil,
README-yə görə son asset kimi istifadə olunmur. Palitra və görünüş üçün istinad götürülür. Real teksturalar Poly Haven-dən (CC0) seçilir.

## Seçilən CC0 dəst (1K, JPG)

| Layer | Səth | Poly Haven | Tile (m) |
|---|---|---|---|
| 0 | Torpaq yol | `rocks_ground_08` | 2.5 |
| 1 | Palçıq | `brown_mud_02` | 2.0 |
| 2 | Dərin palçıq | `brown_mud_03` | 2.0 |
| 3 | Daşlı səth | `ganges_river_pebbles` | 2.0 |
| 4 | Ot | `forest_ground_04` | 3.0 |
| 5 | Qar | `snow_02` | 3.0 |
| 6 | Qaya yamac | `rock_ground` | 5.0 |
| ayrı | Asfalt | `clean_asphalt` (yol overlay-i, sarı xətlər shader ilə) | 2.9 |
| shader | Buz | tekstura yox, aşağı roughness + mavi ton + çat | - |

## Texniki uyğunluq yoxlaması (mövcud `terrain.gd` ilə)

- **API toxunulmazdır:** `softness_at`, `depth_at`, `height_at`, `slope_at`, `road_distance_at`, `road_spawn`, `deform` dəyişmir. `vehicle.gd`, `main.gd` və testlər toxunulmur.
- **Fizika:** `soft[]` və `h/base` massivləri qalır. Palçıq maskası artıq həm fizikanı, həm də səth qarışığını idarə edir (tək həqiqət mənbəyi).
- **Qarışdırma:** 8 sampler problemi (7 layer × 3 xəritə) var. Həll: `Texture2DArray` (2 ədəd: albedo+height, normal+roughness).
  Çəki xəritəsi: 129×129 RGBA8 iki `ImageTexture` (vertex ilə eyni məsafə, xətti filtr). Sərt sərhədlər yoxdur:
  height-əsaslı qarışdırma + makro variasiya noise-u.
- **Deformasiya və izlər:** `deform()` dəyişən təpələrdə `depth01` hesablayır və bunu çəki xəritəsinin B kanalına yazır (qismən yenilənmə, mövcud dirty rect ilə).
  Dərinlik artdıqca dərin palçıq çəkisi artır, iz həndəsə ilə (real batma) və tekstura ilə (dərin palçıq) görünür.
- **Yağış, qar, buz:** `wetness`, `snow_amount`, `ice_amount` shader uniform-ları. Yağış: tünd albedo, aşağı roughness, palçıq çökəkliklərində gölməçə.
  Qar: yuxarı baxan səthlərdə və hündürlükdə, yolda nazik. Buz: yolda aşağı roughness, mavi ton. İndi yalnız görünüş, fizika 3-cü mərhələdə `SurfaceType` ilə.
- **Performans:** yalnız çəkisi > 0.01 olan layer-lər nümunələnir (`textureGrad`), yamac layer-i üçün tək nümunə (dominant ox). Mipmap + anizotropik filtr.
  Başlanğıcda 7 layer × 4 JPG yüklənir (quraşdırma vaxtı ölçülür), sonrakı addım: `.res` kimi sıxılmış bake.
- **Mac:** BCn sıxılması Apple Silicon-da dəstəklənir, Texture2DArray Metal-da işləyir. **Mac-də yoxlanmayıb.**

## Addımlar

1. Teksturaları yüklə (`assets/tex/terrain/`), `CREDITS.md`.
2. `terrain_textures.gd`: layer-ləri `Texture2DArray`-a yığır (paketləmə: albedo+height, normal RG+roughness B).
3. `terrain.gd`: çəki xəritələrini yarat, `_rebuild_mesh`-də depth kanalını yenilə, shader-i çoxlayerli qarışdırmaya keçir. Köhnə ground/asphalt məntiqi qalır.
4. Oyun içindən screenshot: asfalt → torpaq → palçıq → ot keçidləri, daş, yamac, iz, yağış, qar, buz.
5. Testlər: `terrain_test.gd`, sürüş testləri, vizual kadrlar.
6. Sonra 300×300 m xəritəyə keçid (ayrı mərhələ).
