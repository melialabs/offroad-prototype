# Meşə bitki örtüyü

Köhnə konus ağaclar və iynəşəkilli ot əvəzinə Poly Haven CC0 modelləri (optimallaşdırılmış) istifadə olunur.

## Mənbə və yükləmə

- `Offroad_Forest_Models.zip` yalnız 32 KB idi və 12 `.gltf` JSON faylını saxlayırdı, **`.bin` və tekstura faylları yox idi**.
  Səbəb: orijinal `download_assets.py` skriptinin `traverse()` funksiyası `url` sahəsi olan lüğətdə dayanır və `include` bölməsinə girmir.
- `tools/download_forest_assets.py` bu xətanı düzəldir, md5 yoxlayır və alfa xəritələrini də yükləyir (`Alpha` açarı da daxil).
  Nəticə: 12 modelin hamısı tam yükləndi (təxminən 1.8 GB), xətalar 0.
- Orijinallar `assets_src/polyhaven/` qovluğunda ayrıca saxlanılır (git-ə daxil deyil, `.gdignore` var).
- Lisenziya: hamısı CC0 (Poly Haven). Mənbə linkləri və müəlliflər `CREDITS.md`-dədir.

## Niyə optimallaşdırma lazım idi

Şam və küknar modelləri 4-17 milyon üçbucaqdır. İynələr ayrı-ayrı üçbucaqlardır (təpə sayı ≈ üçbucaq sayı),
buna görə adi decimate işləmir. `tools/blender_optimize.py` (Blender 4.5.14 LTS, SHA-256 yoxlanılıb):

1. glTF-i `numpy` ilə birbaşa oxuyur (Blender-ə 900 MB-lıq faylı import etmədən, bütün model 45 saniyəyə).
2. Odunu (gövdə, qabıq, ölü budaqlar) təpələri birləşdirib (`remove_doubles`) decimate edir. Uzaq LOD-larda nazik budaqlar atılır.
3. İynə/yarpaq üçbucaqlarını voksel klasterlərinə bölür, hər klaster üçün alfa kartlı budaq çubuqları (2-3 kart) qurur.
   Tekstura: `twig_diff` + `twig_alpha`-dan kəsilmiş RGBA (`assets/vegetation/textures/*_foliage.png`).
4. Hər model üçün 3 LOD (kiçik bitkilər üçün 1-2) `.glb` kimi ixrac edilir, materiallar Godot-da təyin olunur (`vegetation_assets.gd`).

Üçbucaq sayları (orijinal → LOD0 / LOD1 / LOD2):

| Model | Variant | Hündürlük (m) | Orijinal | LOD-lar |
|---|---|---|---|---|
| pine_tree_01 | a | 20.3 | 6,951,524 | 14,628 / 3,831 / 1,028 |
| pine_tree_01 | b | 14.8 | 4,234,432 | 12,414 / 3,358 / 923 |
| pine_tree_01 | c | 17.4 | 5,996,296 | 13,481 / 3,603 / 964 |
| fir_tree_01 | a | 18.8 | 4,176,819 | 13,509 / 3,472 / 803 |
| fir_tree_01 | b | 14.0 | 2,300,624 | 11,430 / 3,082 / 715 |
| fir_tree_01 | c | 14.4 | 505,494 | 10,487 / 2,908 / 699 |
| pine_sapling_medium | a | 11.3 | 2,662,894 | 11,295 / 5,662 / 4,068 |
| pine_sapling_medium | b | 8.9 | 1,872,357 | 9,225 / 4,250 / 3,034 |
| pine_sapling_medium | c | 6.8 | 1,502,888 | 7,455 / 2,376 / 1,666 |
| pine_sapling_small | b | 1.1 | 122,235 | 852 / 367 |
| pine_sapling_small | a | 1.3 | 142,506 | 1,026 / 388 |
| pine_sapling_small | c | 1.0 | 133,403 | 816 / 347 |
| tree_small_02 | a | 4.5 | 2,062,487 | 12,683 / 1,575 / 540 |
| shrub_02 | a | - | 7,590 | 7,590 / 2,499 / 700 |
| shrub_02 | b | - | 5,242 | 5,242 / 2,500 / 699 |
| shrub_02 | c | - | 9,234 | 9,234 / 2,500 / 700 |
| shrub_02 | d | - | 5,188 | 5,188 / 2,500 / 699 |
| shrub_04 | shrub04 | - | 27,327 | 8,000 / 2,500 / 2,199 |
| fern_02 | b | - | 2,384 | 2,384 / 500 |
| fern_02 | c | - | 2,248 | 2,248 / 500 |
| fern_02 | a | - | 784 | 784 / 499 |
| fern_02 | d | - | 816 | 816 / 499 |
| grass_medium_01 | smalla | - | 833 | 833 / 400 |
| grass_medium_01 | largeb | - | 4,626 | 4,626 / 400 |
| grass_medium_01 | midb | - | 1,257 | 1,257 / 400 |
| grass_medium_01 | midc | - | 1,466 | 1,466 / 399 |
| grass_medium_01 | mida | - | 2,287 | 2,287 / 400 |
| grass_bermuda_01 | mediuma | - | 17 | 17 / 17 |
| grass_bermuda_01 | mediumc | - | 20 | 20 / 20 |
| grass_bermuda_01 | seedlinga | - | 147 | 147 / 60 |
| grass_bermuda_01 | seedlingb | - | 140 | 140 / 60 |
| grass_bermuda_01 | seedlingc | - | 128 | 128 / 59 |
| grass_bermuda_01 | seedlingd | - | 268 | 268 / 60 |
| tree_stump_01 | treestump01 | - | 41,046 | 4,499 / 1,200 / 299 |
| dead_tree_trunk | deadtreetrunk | - | 101,802 | 5,000 / 1,200 / 300 |

Optimallaşdırılmış aktivlər: `assets/vegetation/` (təxminən 53 MB).

## Yerləşdirmə (`vegetation.gd`)

- Deterministik toxum (`1234`), eyni nəticə. 70 klaster mərkəzi, Qauss-vari paylanma, ağaclar arasında minimum məsafə.
- Növ seçimi: hündürlük, rütubət (su səviyyəsinə yaxınlıq + noise) və yamac. Dağda küknar, nəm yerdə enliyarpaq, qarışıq şam.
- Alt bitki: ağacların ətrafında ayıqulağı, kollar, kiçik fidanlar; çay sahilində əlavə sıxlıq; ölü gövdə və kötüklər.
- Yol dəhlizi təmiz (ağac: yoldan 9+ m, alt bitki 6+ m), dərin palçıqda və dik daşlı yamacda azaldılır, havada asılı qalmır (bilinear hündürlük).
- Toqquşma: ağaclar (silindr), kötük (silindr) və ölü gövdə (qutu) üçün `TreeColliders`. Qaya modeli ZIP-də yox idi, ona görə qaya toqquşması tətbiq olunmayıb.
- Fəsil hazırlığı: `Vegetation.apply_season_tint(Color)` foliage materiallarının rəngini dəyişir (`docs/vegetation/payiz_ton_16.png`).
  Qar üçün shader parametri sonrakı mərhələdir.

## Performans optimizasiyası

- `MultiMeshInstance3D` hissələrə (chunk) bölünür, hər LOD ayrıca node, məsafəyə görə görünmə.
- **Kölgə:** LOD0 ağac kölgə salmır, əvəzinə LOD1 mesh-i yalnız kölgə üçün çəkilir (70 m-ə qədər). Bu dəyişiklik və kaskad azaltma
  meşədə kadr vaxtını 17.2 ms-dən təxminən 9.2 ms-ə endirdi. Günəş kölgə kaskadı 4-dən 2-yə, məsafə 120-dən 90 m-ə salındı.
- LOD keçidində sönmə (`VISIBILITY_RANGE_FADE_SELF`) söndürülüb: alfa-scissor yarpaqları yox edir (yalnız gövdə qalır).
  Sərt keçid, margin yalnız histerezisdir.
- Alt bitki kölgə salmır, qısa görünmə məsafələri (22-65 m).

## Ölçmələr (Windows, RTX 3060, 1280x720, vsync söndürülü, `tests/perf_probe.gd`)

| Vəziyyət | Orta kadr vaxtı | FPS | p99 | draw call | üçbucaq/kadr |
|---|---|---|---|---|---|
| Əvvəl (konus ağac), yol | 2.37 ms | 420 | 3.35 ms (299 FPS) | 136 | 0.22 M |
| İlk versiya (kölgə optimizasiyasız), meşə içi | 17.2 ms | 58 | 18.3 ms (55 FPS) | 1729 | 6.5 M |
| İndi, yol üzərində | 5.3 ms | 189 | 6.2 ms (162 FPS) | 538 | 1.83 M |
| İndi, ən sıx ağac klasterində | 9.2 ms | 109 | 10.2 ms (98 FPS) | 630 | 2.89 M |

İlk kadra qədər yükləmə: təxminən 4.6 s (bitkisiz təxminən 3.5 s).
**MacBook Air M4-də ölçülməyib.** 60 FPS Windows-da ölçülüb və tutulur, Mac üçün təsdiqlənməyib.

## Testlər

- `tests/vegetation_test.gd` (başsız): ağac sayı, yol dəhlizi, palçıq, yamac, havada asılma, minimum məsafə, toqquşma şüaları, determinizm, asfaltda bitki yoxdur.
- `tests/forest_drive_test.gd` (başsız): maşın ağaca sürülür, gövdədən keçmir, sürət 0.1 m/s-yə düşür.
- `tests/vegetation_shots.gd`: 5 kameradan (yol, yol kənarı, palçıq cığırı, çay sahili, ümumi) kadrlar. Əvvəl/sonra: `docs/vegetation/evvel_*.png`, `sonra_*.png` (eyni kameralar).
- `tests/perf_probe.gd -- 600 road|forest`: kadr vaxtı, draw call, üçbucaq, yükləmə vaxtı.
- Mövcud testlər (`drive_test` 3 texnika, `terrain_test`, `model_test`) dəyişməyib və keçir.

## Məlum məhdudiyyətlər

- Uzaq LOD-lar alfa kartlarla qurulur: yaxından orijinal iynə həndəsəsi qədər sıx deyil.
- Ot dəstələri (Poly Haven) kiçikdir (0.2 m), 2-4 dəfə böyüdülüb; daha sıx örtük üçün instansiya sayı artırıla bilər.
- Çay (axan su) xəritədə yoxdur, çay sahili əvəzinə göl kənarları (su səviyyəsi -2.4 m) istifadə olunur.
- Mac üçün LOD0/LOD1 üçbucaq büdcəsi ayrıca yoxlanmalıdır.
