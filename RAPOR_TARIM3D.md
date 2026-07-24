# RAPOR — TARIM ÇEKİRDEĞİ (3D): tarla + ekim + sulama + hasat

Branch: `tarim-3d`. Referans: kökteki `farming_system.gd` (tasarım kodu;
oyun bunu yüklemez). Çalışan uyarlama: `scripts/farming.gd` (autoload
"Farming") + denge: `scripts/tarim_balance.gd`. 2D legacy'e DOKUNULMADI.

## Aşama 0 — Keşif: [ENTEGRASYON] noktalarının gerçek karşılıkları

| Referans kanca | Projedeki gerçek karşılık |
|---|---|
| TimeManager.day_started | `DayNight.dawn_started` (yeni gün ŞAFAKTA başlar; "sabah bonusu kancası" yorumu zaten orada) |
| GridWorld.get_depth | `world3d._depth.get(cell, 0)` |
| GridWorld su kontrolü | `world3d.is_water_source(cell)` + `pool_at(cell) >= 0` + `_ground_char == "~"` |
| GridWorld.is_occupied | `_objects.has(cell)` + `_placed.has(cell)` + `_solid_cells` |
| set_cell_visual("tilled") | GROUND_DEFS'e char EKLEMEDİK; `_cell_props` Farming.plots'a bakıp sürülü/ıslak rengi döndürür + `_refresh_terrain_at(cell)` parça yeniler (mevcut kazı kalıbı) |
| HUD.show_hint | `_spawn_floating_text(cell, reason, renk)` |
| Inventory API | `Inventory.get_count / remove_item / add_item` |
| WorldItems.scatter | `world3d._scatter_drops(cell, {"meyve": n})` (yerdeki eşya + loot hissi) |
| Alet STRIKE | `_describe_target` yeni tipler → `_apply_strike` match dalları (12.3 çerçevesi) |
| SaveManager çifti | world3d kayıt sözlüğüne `"farming"` anahtarı (chests kalıbı) |
| Araştırma | `farming_basics` düğümü ZATEN VAR (unlocks: hoe/watering_pot) → Türkçe id'ler ("capa","sulama_kabi") unlocks'a eklendi; tarifler böylece GERÇEKTEN kilitli doğar |

## Mimari kararlar
1. **Veri/görsel ayrımı korunur:** farming.gd yalnız veri+mantık;
   world3d `plot_changed`i dinler → zemin parçası + bitki düğümü yeniler.
2. **Zemin görseli için yeni GROUND char YOK** (kayıt/üreteç varsayımlarına
   dokunmamak için); sürülü/ıslak renk `_cell_props` içinde tek if.
3. **Sulama kabı TEK item** (`sulama_kabi`) + Farming'de 4'lük depo sayacı
   (kova_dolu ikilisi 1 kullanımlık; 4 kullanım için sayaç doğru model).
4. **Bitki görselleri prosedürel placeholder** (filiz silindir → fide koni →
   olgun çalı+meyve küreleri, olgun hafif salınım); `CROP_GLB` kancası:
   `assets/models/crops/berry_stage{0,1,2}.glb` varsa onlar yüklenir.
5. **Işık kuralı BOŞ bırakıldı** (farming.gd'de işaretli — hikâye fazı).
6. **Sulama borusu KAPSAM DIŞI** — boru ağı hazır; tarla ucu TODO
   (farming.gd'de kanca yorumu).

## Denge (tarim_balance.gd — tek dosya)
| Sabit | Değer | Not |
|---|---|---|
| TILLED_DECAY_DAYS | 3 | boş tarla çime döner |
| SEED_RETURN_CHANCE | 0.6 | hasatta tohum iadesi |
| WATERING_CAN_USES | 4 | kap deposu |
| berry_bush | 3 evre, ürün meyve 2-3, tohum "tohum" | GDD §7 başlangıç ürünü |
| capa tarifi | 2 çubuk + 2 taş + 1 ip, tezgah | görev metni ("dal"≈çubuk) |
| sulama_kabi tarifi | 3 kil, ocak | fırın yok; ocak = pişirme istasyonu |

(Aşama 1-4 uygulama notları ve TEST SENARYOSU aşağıya eklenecek.)

## Aşama 1-3 — Uygulama (tek atomik commit; gerekçe commit mesajında)
- **Çapa:** `capa` profili (kürekten kısa öne-aşağı çekiş, kind "till");
  STRIKE → `_try_till` → `_till_valid` (düz+boş+kazısız+susuz çim/toprak)
  → `Farming.till_cell`. Geçersizse floating text sebep gösterir.
- **Ekim:** elde tohum + tarla → "Ek" bağlamı → `Farming.plant` + envanterden
  1 tohum düşer. Tohum flavor metni gerçeğe çevrildi (çelişki kapandı).
- **Büyüme:** `DayNight.dawn_started` → world3d `_on_farm_dawn`:
  ÖNCE bitişik-su otomatiği (`has_adjacent_water` → `water_free`),
  SONRA `Farming.day_tick()` (dün sulanmışsa +1 evre; ışık kuralı yeri boş).
- **Hasat:** olgun tarla, silahsız her elde "Hasat" → ürün `_scatter_drops`
  ile YERE SAÇILIR (2-3 meyve) + %60 tohum iadesi; hücre sürülü-boş kalır.
- **Sulama kabı:** tek item + Farming'de 4'lük depo; su kaynağı/havuz →
  "Doldur", tarla → "Sula"; ıslak zemin koyulaşır, sabah sıfırlanır.
- **Görseller:** sürülü/ıslak renk `_cell_props`'ta; bitki: filiz silindir →
  fide koni → meyveli çalı (+3 kırmızı meyve, hafif salınım); GLB kancası:
  `assets/models/crops/berry_bush_stage{0,1,2}.glb` varsa otomatik kullanılır.

## Aşama 4 — Kayıt + test
- Kayıt: dünya sözlüğüne `"farming"` anahtarı; yüklemede
  `Farming.from_save_data` (eski kayıtta anahtar yoksa temiz başlar);
  yeni oyunda tarlalar sıfırlanır.
- **FARMTEST** (CI, her koşuda): tarla aç → ek → sula → 2 şafak → olgun →
  hasat (saçılım) → 3 şafak bakımsız → çime dönüş → kayıt çifti birebir.
  Ek görsel kare: `3d_tarim.png` (3 evre yan yana + ıslak zemin).

## TEST SENARYOSU (telefonda sırayla)
1. Araştırma masasında "Tarım Temelleri"ni aç (4 odun + 2 taş).
2. Tezgahta çapa üret (2 çubuk + 2 taş + 1 ip); ocakta sulama kabı (3 kil).
3. Çapayı eline al → düz çimde "Çapala" → 6 hücre tarla aç (koyu toprak).
4. Tohumu eline al → tarlaya "Ek" → filiz görünmeli, tohum düşmeli.
5. Sulama kabıyla göl kenarında "Doldur" → tarlada "Sula" ×4 → toprak
   koyulaşır; 5. denemede "Kap boş" uyarısı.
6. Yatakta uyu (veya günü bekle) → sulananlar fide; ertesi gün olgun
   (salınan meyveli çalı).
7. "Hasat" → meyveler yere saçılır, topla; arada tohum iadesi gör.
8. Göl kenarına tarla + kürekle kanal → ertesi sabah kendiliğinden ıslak
   (kap harcamadan) — otomatik sulama.
9. Bir tarlayı boş bırak → 3 gün sonra çime döner.
10. Kaydet-çık-yükle → tarla/evre/ıslaklık/kap durumu birebir.

## Bilinen sınırlar
- Ses çalar yok (SFX adları TarimBalance.SFX'te veri olarak hazır).
- Sulama borusu tarla ucu KAPSAM DIŞI (boru ağı hazır; sonraki görev).
- Işık kuralı boş (farming.gd'de işaretli — hikâye fazıyla).
- Çapa/sulama kabı ikonları 2 harf placeholder (PNG yüklenince balta
  akışıyla bağlanır).
