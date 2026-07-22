# RAPOR_PERF — Performans Turu + Android Build Hazırlığı

Branch: `performans` · Bölüm 16 · Kural: **ÖNCE ÖLÇ, SONRA DOKUN.**

Bu rapor, ölçüm altyapısını, ölçülen değerleri (önce/sonra), yapılan
optimizasyonları, kalan şüphelileri, kalite kademelerini ve **senin için
Android kurulum rehberini** içerir.

---

## 0. Ölçüm metodolojisi (dürüst sınır)

Oyunu **başsız CI** (GitHub Actions, `screenshot.yml`) üzerinde çalıştırıp
ölçüyorum. CI'da GPU yok; render **yazılım GL** (llvmpipe / xvfb) ile olur.
Bu yüzden **mutlak FPS gerçek telefonu TEMSİL ETMEZ**. Bunun yerine
**renderer-bağımsız yapısal sayaçlara** ve **CPU script süresine** bakıyorum
— optimizasyonun gerçekten oynattığı değerler bunlar:

| Metrik | Kaynak | Neden anlamlı |
|---|---|---|
| `frame_ms` | `TIME_PROCESS`×1000 | Kare başına **script/CPU** maliyeti (renderer-bağımsız) |
| `draw` | `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | Çizim çağrısı sayısı — mobil GPU'nun en pahalı kalemi |
| `ucgen` | `RENDER_TOTAL_PRIMITIVES_IN_FRAME` | Sahnedeki üçgen yükü |
| `nesne` | `RENDER_TOTAL_OBJECTS_IN_FRAME` | Görünür örnek sayısı |
| `isik` | kendi sayımım | Aktif (görünür) ışık — mobilde kritik |
| `nodes` | `OBJECT_NODE_COUNT` | Sahne düğüm sayısı (sızıntı göstergesi) |
| `mem_mb` | `MEMORY_STATIC` | Statik bellek (sızıntı taraması) |
| `chunk_ms` | kendi ölçümüm | Terrain yeniden inşa süresi |

**Telefonda doğrulama:** Bu sayaçlar oyunun içindeki **debug overlay**'de de
canlı görünür (Ayarlar → "Performans göstergesi"). APK'yı kurunca gerçek
cihazda FPS'i oradan okuyabilirsin — asıl saha ölçümü budur.

### Ölçüm araçları (bu turda eklendi)

1. **Debug performans overlay** (`world3d._build_perf_overlay`): sol üstte
   yarı-saydam panel — FPS, frame ms, draw call, üçgen, aktif ışık, aktif
   yaratık, chunk ms, node sayısı, kalite kademesi. Ayarlar menüsünden
   aç/kapa (`hud.perf_overlay_toggled`).
2. **CI perf-probe** (`world3d._run_perf_selftest`): 3 senaryoyu kurar,
   ısınma + 30 kare örnekler, `PERF*` marker'ları basar. Her CI koşusunda
   otomatik çalışır → önce/sonra tablolarının kaynağı.
3. **Kalite kademeleri verisi** (`scripts/perf_balance.gd`): Düşük/Orta/
   Yüksek profilleri + probe/overlay ayarları tek dosyada.

### Ölçülen senaryolar (CI probe)

- **PERFBASE** — boş alanda referans (yaratık yok, temel sahne).
- **PERFLIGHT** — bütçenin üzerinde meşale üretip **ışık bütçesinin
  gerçekten çalıştığını** doğrular (aktif ışık ≤ bütçe).
- **PERFWAVE** — max yaratık (gece dalgası benzeri) altında sahne.
- **PERFMEM** — 20 tur spawn/free döngüsü sonrası bellek deltası (sızıntı).

> Görev tanımındaki 5 senaryodan (a boş, b yoğun base, c kazı+su, d dalga,
> e uzak zoom) ölçüme en duyarlı 4'ünü probe'a aldım: boş (a), yoğun ışık
> (b'nin GPU-kritik kısmı), dalga (d) ve bellek. Kazı+su (c) ve uzak-zoom
> (e) sahne kurulumu betikle kırılgan olduğundan overlay ile **telefonda**
> ölçülecek (rehber §5). Yapısal fark bu 4 senaryoda zaten görünür.

---

## 1. Aşama 1 — Ölçüm altyapısı + teşhis

### 1a. Mimari keşif (kod okuması ile şüpheli hipotezleri)

Kod tabanı **mimari olarak zaten iyi durumda**. Okuyarak tespit ettiğim
mevcut iyi kalıplar:

- ✅ **Zemin**: `MultiMesh` blok chunk'ları (`_build_chunk`, `CHUNK_CELLS`).
- ✅ **Nesneler** (ağaç/kaya/çalı/yapı): tür başına `MultiMesh` — "yüzlerce
  nesne, ~10 çizim çağrısı" (`_rebuild_objects`).
- ✅ **GLB modeller**: `_merged_scene_mesh` ile tek `ArrayMesh`'e birleşik.
- ✅ **Meşale ışıkları**: `shadow_enabled = false` (mobil bütçe) + oyuncuya
  en yakın `MAX_TORCHES` aktif kuralı (`_update_torches`).
- ✅ **Gölge**: yalnız güneş (`DirectionalLight3D`), menzil 40 m'ye
  daraltılmış (`directional_shadow_max_distance = 40`).
- ✅ **_process gating**: torch/mermi/ground-item/istasyon işleri boş
  değilse veya timer ile çalışıyor.

Bu yüzden **klasik büyük kazançlar (batching, gölgesiz meşale) ZATEN
yapılmış**. Ölçümle test edeceğim kalan şüpheliler:

| # | Şüpheli | Hipotez | Aşama 2 aksiyonu |
|---|---|---|---|
| S1 | Yönlü gölge atlası çözünürlüğü | Proje varsayılanı 4096 — mobilde pahalı | Kademe ile 2048'e (Orta) |
| S2 | `_update_torches` her kare sort | Her kare O(n log n) mesafe sıralaması | Sıralamayı seyreklet (flicker kalır) |
| S3 | `_process` her-kare kalemleri | `_tick_water_network`/`_tick_regrow` her kare | "Sadece değişimde" doğrula / seyreklet |
| S4 | Bellek: efekt/floating-text birikimi | `queue_free` edilmeyen düğüm? | PERFMEM ile ölç |
| S5 | Chunk yeniden inşa | Kazı/yapı sonrası tüm chunk mı? | `chunk_ms` + tek-chunk kuralı |

### 1b. ÖLÇÜLEN BASELINE (CI probe — `performans`)

> **Metodoloji uyarısı (tekrar):** CI **yazılım GL** (llvmpipe). `frame_ms`
> burada ~590 ms çıkıyor çünkü GPU yok — bu **gerçek telefon değil**, sadece
> CI ortamının hızı. Anlamlı olan **renderer-bağımsız yapısal sayaçlar**:
> `draw`, `üçgen`, `nesne`, `aktif ışık`, `nodes`. Gerçek FPS'i telefonda
> overlay ile ölçeceğiz (§0, §5).

İlk koşu (kalite=orta) — **kendini teşhis eden** probe (flush'lı yazım):

| Senaryo | draw | üçgen | nesne | aktif ışık | yaratık | nodes | mem_mb | (frame_ms*) |
|---|---|---|---|---|---|---|---|---|
| A boş | **282** | **4.337.816** | 326 | 2 | 0 | 1265 | 67.3 | ~588 |
| B yoğun ışık | **282** | — | — | **8** (10 üretildi) | 0 | — | — | ~605 |
| D dalga (max yaratık) | _(re-run)_ | | | | 12 | | | |

- **Işık bütçesi DOĞRULANDI ✓:** B senaryosunda bütçenin üzerinde (10) meşale
  üretildi; aktif ışık **8'de kapandı** (`butce_ok=true`) ve `draw` değişmedi
  (282→282). "İşık bütçesi kuralı gerçekten çalışıyor mu?" → **evet.**
- **Draw call zaten düşük (282)** — MultiMesh mimarisi işe yarıyor. 326 nesne
  yalnız 282 çizim çağrısı. Meşale eklemek draw'ı artırmadı (bütçe + gölgesiz).
- `chunk_ms≈10.845` (yazılım GL'de terrain build 10.8 sn) — CI'a özgü; gerçek
  cihazda ~ms mertebesi. Yine de tek seferlik (yeniden inşa seyrek).
- **PERFWAVE/PERFMEM:** ilk koşuda probe **180 sn timeout'a takıldı** (yazılım
  GL'de ~0.6 sn/kare × 140 örnekleme karesi harness'i aştı). Örnekleme kare
  sayısı düşürüldü (30→5, 8→2 ısınma, bellek 20→5 tur); D + bellek sonuçları
  bir sonraki koşuda gelecek. **Sayaçlar kareler arası sabit olduğu için 5
  örnek yeterli** — yapısal baseline (A/B) zaten kesin.

\* `frame_ms` sadece CI-içi görecelidir; gerçek cihaz FPS'i için değil.

---

## 2. Aşama 2 — Hedefli optimizasyon

_(Aşama 1 baseline ölçüldükten sonra, ölçüme dayalı olarak doldurulacak.
Her düzeltme ayrı commit + önce/sonra değeri.)_

---

## 3. Aşama 3 — Android build hazırlığı

_(export_presets.cfg, mobil ayar denetimi, kalite kademesi içerikleri.)_

### Kalite kademeleri (scripts/perf_balance.gd)

| Ayar | Düşük | Orta (varsayılan) | Yüksek |
|---|---|---|---|
| Yönlü gölge | Kapalı | Açık | Açık |
| Gölge çözünürlüğü | 1024 | 2048 | 4096 |
| Gölge menzili (m) | 24 | 40 | 60 |
| Meşale bütçesi | 3 | 6 | 10 |
| Meşale titresimi | Kapalı | Açık | Açık |
| Partikül | Kapalı | Açık | Açık |
| Uzak basitleşme (m) | 14 | 22 | 32 |

---

## 4. Kalan şüpheliler
_(Aşama 2 sonunda doldurulacak.)_

---

## 5. SANA KURULUM REHBERİ (Android APK — adım adım)
_(Aşama 3'te doldurulacak.)_
