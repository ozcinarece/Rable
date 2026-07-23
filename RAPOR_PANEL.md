# RAPOR — Envanter + Üretim Panelleri (mockup'lara göre)

Branch: `panel-mockup`. Tek doğruluk kaynağı:
`assets/mockups/backpack_ui_mockup.html` + `crafting_ui_mockup.html`.
UI_DESIGN/REVIZYON ile çelişen her noktada mockup kazandı.
Oyun mantığına dokunulmadı — Inventory/Crafting/Research fonksiyonları aynen.

## Aşama 1 — Ortak iskelet (TEK bileşen)
`hud.gd :: _build_sheet_chrome(root, panel, vbox, title)` — alttan yükselen
sayfa kalıbı: %90 boy, %96 en, 24px üst köşe, yukarı gölge, çok soluk nokta
dokusu (`ui_dots.gd`), dikişli deri tutamaç (`ui_handle.gd`), panelden taşan
koyu kahve sekme (`_make_tab`, sağ mini etiket döndürür), yuvarlak kapat
(`_style_round_close`). Yükselme animasyonu 0.3sn ease-out (panel başına
toggled fonksiyonunda). **Kullananlar:** envanter, sandık, üretim.

### Araştırma paneli için kullanım notu (ileride)
```gdscript
var cap := _build_sheet_chrome(research_root, research_panel,
        research_vbox, "Araştırma")   # cap: sekme içi sağ mini etiket
_style_round_close(research_close, research_root, research_panel.offset_top)
# toggled'da envanterdeki yükselme tween kalıbını kopyala (0.3sn)
```
Şart: `root` konteyner OLMAYAN Control (sekme/kapat panelden taşar),
panel `PanelContainer`, `vbox` panelin içindeki ana dikey düzen.

## Aşama 2 — Envanter
Önceki `envanter-mockup` görevinde mockup'a birebir yapılmıştı (8 sütun,
çift halka, kilit çipi, flavor, sandık iki kardeş sütun, dokunuşlar).
Bu görevde: %84 → **%90 boy** (mockup .sheet height:90%), iskelet ortak
bileşene taşındı. Doluluk YALNIZ sekmede ("Sırt Çantası 14/16") —
CapacityRow gizli. Flavor alanı: `items.gd :: FLAVOR` (55 eşya).

## Aşama 3 — Üretim (crafting mockup'ı)
- **Sol raf** (.rail): 92px dikey, kaydırılabilir; 60px kategori renkli
  daire + altında TAM kelime etiket (Tümü, Malzeme, Aletler, Savaş & Av,
  Yapılar, Tarım, Pişirme, Mühendislik — kırpma yok). Aktif: 6px sağa +
  3px koyu halka + tam opak; pasif %68.
- **Kartlar** (.card): 112px, 16px köşe, panel-koyu zemin, 64px kategori
  dairesi + ad. ÜÇ DURUM birebir ve GERÇEK veriden:
  - üretilebilir → tam renk
  - malzeme eksik → %55 soluk + sağ üstte kırmızı "eksik çeşit sayısı"
  - araştırılmamış → %45 soluk + grileşmiş daire/ikon + kilit ikonu
    (`Research.is_recipe_unlocked`)
  - seçili → 3px koyu halka + tam opak
- **Detay şeridi** (.strip, TAM genişlik): 68px ikon + ad + malzeme
  çipleri "ikon 3/5" (yeşil/kırmızı, gerçek envanter) + istasyon satırı
  üç seste: "Elde üretilir" (soft) / "✓ Tezgah yanında" (yeşil) /
  "⚠ Tezgah gerekli — uzaktasın" (amber) — `Crafting.near_station/
  near_hearth` gerçek yakınlık. TEK **Üret**: koşullar tamsa koyu-aktif,
  değilse gri-pasif, kilitliyse "Kilitli" (mockup .pill.go/.off).
  `max_craftable` üç kapıyı (araştırma+istasyon+malzeme) zaten içerir —
  buton durumu tek sorgu. Üretim başarısında **hotbara-uçan-ikon
  animasyonu aynen korundu** (`_fly_to_hotbar`).
- **Arama çubuğu YOK** (mockup kararı). `search_edit` gizli ama canlı
  (kod boş metin okur). **TODO:** tarif sayısı 60'ı aşarsa geri getir.

## Aşama 4 — Dokunuş + oranlar
- Kart basışta %95, slot %92, pill %94 küçülme (mockup :active süreleri).
- Yükseklik-duyarlı clamp: kart 112px sabit-min (mockup clamp(96,20vh,120)
  720p'de 120 tavanına dayanır); raf dairesi 60 (clamp 52..64); envanter
  slotu 64–104 formülü RAPOR_UI'da. Dokunma hedefleri: slot ≥64, kart 112,
  raf 60+etiket, pill ≥44 — hepsi ≥ hedef.
- 16:9 (1280×720): ana satır ~470px → kart 2 sıra + kaydırma; raf 8 giriş
  kaydırmalı. 19.5:9 (1560×720): aynı dikey, daha çok kart sütunu.

## Mockup'tan sapmalar (gerekçeli)
1. **Emoji ikonlar yerine oyun ikonları** (kategori/kart/çip): oyunda 32px
   item ikon seti var (R0 kuralı); emoji glyph'i cihaz fontunda garanti
   değil. ✓/⚠ işaretleri metinde kullanıldı (font destekliyor; CI temada
   doğrulanır).
2. **Kuyruk satırı korundu** (mockup'ta yok): üretim ilerlemesi kaybolamaz
   — strip'in altında, aynı krem dil.
3. **Eski panel "sahneleri" scenes/legacy_ui'ya taşınMAdı**: paneller ayrı
   sahne değil, HUD.tscn içinde düğüm. Silmek yerine gizlendi (TitleTab,
   TopRow/arama, CapacityRow) — tscn'de duruyorlar, kod referansları canlı.
   Ayrı dosya taşıma uygulanamaz; en yakın güvenli karşılık bu.
4. **Kart ızgarası HFlowContainer** (CSS auto-fill yerine): Godot'ta eş
   davranış; sütun sayısı genişlikten türeyip sarıyor.

## TEST SENARYOSU (telefonda sırayla)
1. Çanta aç → alttan 0.3sn yükselme, sekme "Sırt Çantası N/16" mi?
2. Slot seç → çift halka + flavor + Ye/Kuşan/At (At kırmızı konturlu);
   Ye çalışıyor, Kuşan ele alıyor mu?
3. Kapat (yuvarlak) → oyun akıyor mu? Üretim aç → aynı iskelet, sekme
   "Üretim", arama YOK.
4. Rafta kategori değiştir → aktif daire sağa kayıp halkalanıyor mu,
   etiketler tam kelime mi?
5. Kartlarda üç durumu gör: tam renkli bir tarif, eksikli soluk + kırmızı
   rozetli, kilitli gri + kilit ikonlu (araştırılmamış dal).
6. Eksikli tarif seç → çipler kırmızı, Üret gri-pasif (basılmıyor).
7. Tezgah tarifini tezgahtan UZAKTA seç → "⚠ Tezgah gerekli — uzaktasın",
   Üret pasif; tezgah yanına git → "✓ Tezgah yanında", Üret koyu-aktif.
8. Üret'e bas → ikon hotbara uçuyor, hotbar pop yapıyor mu?
9. Sandık aç → aynı dil, iki sütun Al/Koy çalışıyor mu?

## CI doğrulaması
`screenshot.yml` (branch): import temiz, oyun tam akış çalıştı; kareler
`3d_envanter.png`, `3d_uretim.png`.
