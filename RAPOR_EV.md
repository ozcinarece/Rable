# RAPOR — Ev/Çatı Paketi (İç Mekan Sistemi)

Branch: `ev-cati`. Dokümanlar: YAPI_SISTEMI.md, BASE_SAVUNMA.md,
GAME_DESIGN Bölüm 6, UI_DESIGN + UI_REVIZYON_1.

Altın kural: kapsam disiplini, oyun her commit'te çalışır, yaratık
davranışına dokunma (yalnız belirtilen veri kancası).

---

## Aşama 1 — Çatı parçaları  ✅

### Kararlar

**1. Çatı ayrı bir ÜST KATMAN.** Oyun hücre-başına-tek-yapı modeli
kullanıyor (`_placed[cell]`). Ama çatı "duvar üstüne" konabilmeli, yani
duvarla aynı hücreyi paylaşmalı. Çözüm: çatılar `_placed`'e DOKUNMADAN
paralel bir katmanda tutulur:
- `_roofs` (hücre → çatı id)
- `_roof_nodes` (hücre → görsel, duvar üstü Y=1.18)
- `_roof_structures` (ayrı `StructureManager` — hp/durum/yön/kayıt aynı
  mantık, ayrı anahtar uzayı). Böylece bir hücrede hem duvar hem çatı
  bağımsız hp taşıyabilir.

**2. İki katalog gerçeği.** Oyunun AKTİF ekonomisi Türkçe id'li
(`recipes.gd`/`items.gd`/`PLACE_MODELS`), GDD kataloğu İngilizce
(`item_db`/`recipe_db`/`research.gd`). Bu ayrımı bozmadan çatıyı HER İKİ
yere de ekledim:
- Aktif (oynanır): `ahsap_cati`, `tugla_cati` — üretim menüsünde "Yapılar"
  sekmesinde görünür, hemen craftlanır (mevcut Türkçe tarifler gibi
  araştırmadan bağımsız = "yönetilmeyen").
- GDD: `wood_roof`, `brick_roof` + `roof_mastery` ("Çatı Ustalığı")
  araştırma düğümü (İnşaat dalı, önkoşul `basic_building`). Bu düğüm
  İngilizce çatı id'lerini yönetir — mevcut İngilizce ağacın uykuda ama
  hazır durması desenine birebir uyar. `LEGACY_MAP`: ahsap_cati→wood_roof,
  tugla_cati→brick_roof.

**3. Denge sayıları (veride).**
| Çatı | max_hp | Maliyet | Nerede |
|------|--------|---------|--------|
| ahsap_cati (Ahşap) | 60 | 4 kalas | elde (istasyonsuz) |
| tugla_cati (Tuğla, K2) | 120 | 3 kil + 1 taş | tezgah |

- Görev "4 wood / 3 brick" diyordu. Aktif ekonomide "wood" = kalas
  zinciri (duvar da kalas ister), "brick" = **kil** (items.gd: kil =
  "fırın çağı tuğla malzemesi"; kazıdan çıkar, K2 kapısı). Tuğla malzemesi
  aktif ekonomide craftlanamadığı için sağlam varyantı kil'e bağladım —
  hem "3" adedini hem "K2 tuğla" temasını korur. GDD `brick_roof` gerçek
  `brick` (3) ister (recipe_db).

**4. Yerleştirme kuralı.** `_roof_place_valid(cell)`:
- Hücre altında duvar/kapı (`behavior` wall|door) varsa → geçerli.
- Yoksa, ortogonal komşularından biri çatıysa → geçerli (bitişik uzatma).
- İkisi de yoksa → **"desteksiz"** rozeti (mevcut hayalet/geçerlilik
  sistemiyle; kırmızı hayalet + neden etiketi).
- Hem hızlı-dokunma (`_try_place`) hem hayalet-modu (`_place_valid`) bu
  tek kuralı kullanır.

**5. Çökme.** Bir duvar/kapı yıkılınca (`_release_structure_cell` →
`_recompute_roof_support`) tüm çatı ağı yeniden değerlendirilir: duvara
oturan çatılardan BFS ile ulaşılamayan çatılar **çöker** (malzemenin
%25'i saçılır, iade yok — YAPI_SISTEMI 13.4 yıkım kuralıyla tutarlı).

**6. Görünürlük çözümü (top-down klasiği).** Oyuncu çatılı hücreye
girince o çatı grubu (`_roof_group` flood-fill) 0.3 sn'de yumuşakça
şeffaflaşır (`GeometryInstance3D.transparency` → 0.82; hem prosedürel hem
GLB için çalışır). Dışarı çıkınca geri gelir. Yeniden hesap yalnız oyuncu
HÜCRESİ değişince yapılır (kare başı flood yok — perf).

**7. Görsel.** GLB kancası hazır: `assets/models/structures/wood_roof.glb`
/ `brick_roof.glb` varsa yüklenir; yoksa prosedürel **eğimli gable form**
(iki eğik panel + mahya kirişi + alın tahtası — düz kutu değil, ev
silüeti okunur). Ahşap = sıcak kahve, tuğla = kiremit kırmızısı.

### Bilinen sorunlar / TODO
- Kayıt (çatılar + `_roof_structures`) Aşama 4'te SaveManager'a bağlanacak
  (şu an oturum içi çalışır, kaydedilmez).
- İç mekan tespiti (kapalı alan) Aşama 2.
- `transparency` fade GLB çatılarda test edilmedi (GLB henüz yok);
  prosedürelde çalışır.

---

## Aşama 2 — İç mekan tespiti  ⏳ (sırada)
## Aşama 3 — İç mekanın anlamı  ⏳
## Aşama 4 — Cila + entegrasyon + kayıt  ⏳
