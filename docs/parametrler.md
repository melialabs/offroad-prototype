# Rigs of Rods parametrləri (yalnız istinad üçün)

Mənbə: [Truck fayl formatı sənədi](https://docs.rigsofrods.org/vehicle-creation/fileformat-truck/) (səhifənin yalnız ilk yarısı oxunub).
Kod kopyalanmayıb, yalnız rəqəmlər və ideyalar götürülüb. Rigs of Rods GPL v3-dür.

## Mühərrik və qutu (`engine`, `engoption`)

| Parametr | RoR sənədindəki nümunə | Məna |
|---|---|---|
| Min / maks dövr | 1000 / 1500 | Avtomatın aşağı/yuxarı dəyişmə dövrü. Qırmızı xətt = maks × 1.25 |
| Moment | 8000 N·m | Böyük yük maşını nümunəsi |
| Əsas ötürmə (diferensial) | 2.00 | Son azaldıcı |
| Geri / neytral / 1-ci / 2-ci dişli | 10.85 / 10.00 / 13.86 / 9.52 | Dişlilər 1.00-a qədər azalır, siyahı `-1.0` ilə bitir |
| Mühərrik ətaləti | 10.0 (kiçik mühərrik: 0.5–1.0) | Aşağı dəyər tez sürətlənir |
| Mufta qüvvəsi | 10000 (yük maşını), 5000 (avtomobil) | |
| Boş / dayanma dövrü | 800 / 300 | |

## Asma (`shocks`)

| Parametr | Nümunə | Qeyd |
|---|---|---|
| Yay sərtliyi | 200000 | |
| Sönmə | 10000 | Qayda: `2 × √(asılan kütlə × yay sərtliyi)` |
| Sıxılma/uzanma həddi | 0.3 / 0.3 | Ilkin uzunluğun payı kimi |
| Əvvəlcədən sıxılma | 1.0 | Əyilmiş asmanı düzəltmək üçün |

`shocks2` sıxılma və uzanma sönməsini ayırır. `shocks3` yavaş və sürətli sönməni ayırır.

## Təkər (`wheels`, `wheels2`)

| Parametr | Nümunə |
|---|---|
| Radius | 0.54 m (`wheels`), 0.625 m (`wheels2` təkəri) |
| Kütlə | 200 kq (ötürməsiz), 400 kq (aparıcı) |
| Yay / sönmə | 800000 / 4000 |
| `wheels2` disk və təkər | disk yayı 900000, təkər yayı 200000–400000, təkər sönməsi 2000 |

## Palçıq

Palçıqda tutuşma sənəddə **tapılmadı**. RoR bunu `groundmodels.cfg`-də saxlayır. Tapdığım yeganə iz tərcümə mətnidir: "adhesion velocity" parametri palçıqdan çıxmağı asanlaşdırır, dəyər 1 olanda "real palçıq" olur.
Sonrakı addım: `groundmodels.cfg` faylının rəsmi mənbə repodakı dəyərlərinə baxmaq. Yalnız rəqəmlər, kod yox.

## Bizim Godot prototipi üçün təklif (`vehicle.gd` dəyişdirilməyib)

Bu təkliflər RoR-un fiziki modelinə əsaslanmır. Godot-un `VehicleBody3D`-si fərqli işləyir və rəqəmləri birbaşa köçürmək olmaz.

1. **Dişli qutusu əlavə et:** hazırda `engine_force` sadə hesablanır. RoR kimi dişli nisbətləri (13.86 → 1.0) və dövrə görə moment əyrisi sürətlənməni real edər.
2. **Sönmə qaydası:** `damping ≈ 2 × √(kütlə × sərtlik)` Godot-un `damping_compression` və `damping_relaxation` dəyərlərini seçmək üçün başlanğıc nöqtə kimi yaxşıdır (ölçü vahidləri fərqlidir, sınaqla uyğunlaşdır).
3. **Kütlə nisbəti:** RoR-da aparıcı təkər (400 kq) ötürməsizdən (200 kq) iki dəfə ağırdır. Təkər kütləsini nəzərə almaq isə `VehicleBody3D`-də mümkün deyil. Bunun üçün öz təkər fizikamızı yazmaq lazım ola bilər.
4. **Palçıq:** `GRIP_HARD` ilə `GRIP_MUD` arasındakı keçidi "adhesion velocity" ideyası ilə qur: dayanan təkər palçıqda tam batır, sürət artdıqca tutuşma qismən qayıdır.
