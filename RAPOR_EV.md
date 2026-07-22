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

## Aşama 2 — İç mekan tespiti  ✅

### Kararlar
- **Kapalı alan algoritması** (`_recompute_indoor`): duvar/kapı bariyer sayılır
  (açık kapı da — ev kapısı da çevreler). Çatılı, bariyer-dışı bir hücreden
  flood-fill başlatılır; bölge harita KENARINA sızmıyorsa (kapalı) VE tüm
  hücreleri çatılıysa VE ≤ `INDOOR_MAX` (64) ise → İÇ MEKAN.
- **Çatıda delik = kapalı değil**: bölge çatısız bir hücreye taşarsa `all_roofed`
  bozulur → iç mekan olmaz (mühür şartı).
- **64 hücre sınırı**: "haritayı çatıyla kapla" istismarını keser.
- **Yalnızca yapı değişiminde** çalışır; kare başı DEĞİL (havuz/flood mantığının
  kardeşi). Global sorgu: `is_indoor(cell)`.
- **14.5 yol-bulma kancası** (`creature_balance.gd`): 14.5 maliyet tablosu veri +
  `INDOOR_COST_PENALTY = 20` + saf `traverse_cost(base, indoor)`. Yaratık A*'ı
  (Aşama 2+) bunu okuyacak → iç mekan "son çare". BASE_SAVUNMA 14.5 tablosuna
  "İç mekan: +20" satırı eklendi.
- **Tek test** (`_run_ev_cati_selftest`, boot'ta): oda kur → `is_indoor` doğru;
  duvar aç → mühür bozulur; destek gidince çatılar çöker; iç mekan `traverse_cost`
  = dış + 20 (kanca doğrulandı).

## Aşama 3 — İç mekanın anlamı (ev hissi)  ✅

### Kararlar
- **Sıcak ambiyans**: içeri girince hafif sıcak amber ton (alpha 0.16, 0.3 sn
  fade; `CanvasLayer 1`, `MOUSE_FILTER_IGNORE` → tıklamayı ASLA engellemez). Kare
  başı yalnız ucuz `is_indoor` sorgusu; değişimde tek tween.
- **Yatak bonusu**: doğuş yatağı iç mekandaysa ölüm sonrası +`HOME_INDOOR_RESPAWN
  _BONUS` (10) can + tokluk. Veri `survival_balance.gd`'de; `player_stats._die()`
  RESPAWN sonrası `world.home_spawn_bonus()` ile ekler.
- **Rozetler** (kozmetik): iç mekandaki yatak → "Ev", sandık → "güvende"
  (Label3D billboard). Sandık için mekanik bonus YOK (basit tutuldu).
- **"Bir evin var artık" pill'i**: ilk iç mekanda tek sefer (`flash_home_pill`,
  sıcak ton, abartısız). `home_celebrated` kayda yazılır → reload'da tekrar çıkmaz.

## Aşama 4 — Cila + entegrasyon + kayıt  ✅

### Kararlar
- **Kayıt** (SaveManager): `roofs` + `roof_structures` (hp/durum/yön) +
  `home_celebrated`. `is_indoor` KAYDEDİLMEZ — yüklemede duvar+çatılardan yeniden
  türer (`_recompute_indoor`, yapılar kurulduktan SONRA). Rozetler load'da tazelenir.
- **Performans**: iç mekan + destek/çökme YALNIZ yapı değişiminde (event-driven).
  Kare başı maliyet yalnız: çatı fade (oyuncu hücresi değişince, nadir) + ambiyans
  (tek sözlük sorgusu) → FPS etkisi ihmal edilebilir. Ayarlar → FPS göstergesiyle
  doğrulanabilir.
- **GLB kancası**: `assets/models/structures/{wood,brick}_roof.glb` varsa yüklenir
  (Aşama 1); yoksa prosedürel eğimli gable form.

---

## TEST SENARYOSU (elle, cihazda)
1. 4 duvar + kapı ile küçük oda kur.
2. Çatı döşe → **"Bir evin var artık"** pill'i.
3. İçeri gir → çatı **şeffaflaşır** + **sıcak ton**.
4. Yatağı içeri taşı → **"Ev"** rozeti; sandık içeri → **"güvende"**.
5. Öl → **bonuslu doğ** (+10 can/tokluk).
6. Duvarı kır → bağlantısız çatılar **çöker** (%25 saçılır).
7. Kaydet-yükle → çatılar, rozetler, "evin var" durumu korunur.

## BİLİNEN SORUNLAR / TODO
- Yağmur/hava sistemi YOK (tasarım dışı) — iç mekanın ileride en büyük anlamı bu
  olacak; TODO not düşüldü.
- `transparency` fade GLB çatılarda cihazda doğrulanmadı (GLB yok); prosedürelde
  çalışır.
- Sandık "güvende" rozeti salt kozmetik (mekanik koruma yok).
