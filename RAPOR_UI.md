# UI REVİZYON 1 — Uygulama Raporu

Otonom mod. Branch: `ui-revizyon-1`. Kaynak: `UI_REVIZYON_1.md` (UI_DESIGN.md
üstüne). **Yalnız UI katmanı** — oyun mantığı/veri/sistem davranışı
değişmedi (yeme mantığı aynı, sadece tetik yüzeyi; "Yeni Oyun" işlevi aynı,
sadece menüye taşındı). Aşama başına bir commit; oyun her commit'te açılır.

## Aşama 1 — R0 genel kural altyapısı (commit 1)

**Teşhis → çözüm:**
- **İkon doluluk (%65):** `ui_slot.gd` ikon kenar payı 14px → **10px**
  (`ICON_INSET`), 64px slotta ikon ~44px = **%69**. "Koca daire içinde
  minik ikon" kalktı.
- **Panel açıkken karartma + HUD gizleme:** `_setup_backdrop()` bir
  `overlay_dim` (`UIColors.OVERLAY_DIM`) ColorRect ekler; `_update_backdrop()`
  herhangi bir panel (envanter/üretim/araştırma/sandık) açılınca overlay'i
  aktif panelin ALTINA + her şeyin ÜSTÜNE alır ve **oyun HUD öğelerini
  gizler** (dock butonları, hotbar, ana/taşı butonları, Gün pill'i, stat
  paneli). Böylece Gün pill'i ↔ panel başlığı çakışması da çözüldü.
  Toggle'lara ve `show_chest`/`close_chest`'e bağlandı.
- **Kilit çipi:** Kilitli slotlar tek tek çizilmiyor; envanter ızgarası
  yalnız `get_slot_count()` kadar açık slot gösteriyor, ızgara sonunda tek
  kompakt çip: **"+N slot (deri çanta ile)"** (`_build_lock_chip`,
  `_refresh`'te güncellenir). Boş kilitli daire gürültüsü gitti.
- **Kırpık etiket taraması:** Kalan kırpık etiketler (kategori sekmesi
  "Tü/Ma", araştırma "Ar") yapısal olarak Aşama 2 (dock) ve Aşama 4
  (sekmeler) ile ikon+tam-etikete dönüşecek; envanter 2-harf placeholder'ı
  UI_DESIGN'ın izinli kuralı (ikon yoksa) — korunur.

**Değişen dosyalar:** `scripts/ui_slot.gd`, `scripts/hud.gd`.

## Aşama 2 — R1 dock + R2 ana/saldırı + Ayarlar menüsü (commit 2)

**Teşhis → çözüm:**
- **R1 dock:** Dağınık beyaz daireler yerine `_build_dock()` sağ kenarda tek
  dikey dock (anchor 0.44, başparmak bölgesi, 12px aralık). Üç buton
  (envanter/craft/araştırma) entry VBox'lara taşındı: **68px kategori renkli
  DOLGULU daire** (çanta=bal turuncu, üretim=ahşap bej, araştırma=bilgi
  mavisi) + **%68 dolduran koyu kahve ikon** + altında **13px mini etiket**
  ("Çanta"/"Üretim"/"Araştırma"). Araştırmaya `arastirma_masasi.png` ikonu
  verildi → "Ar" kırpık etiketi kalktı. Boş krem daire yok.
- **R1 Ayarlar menüsü:** `reset_button` artık "Yeni Oyun" değil; **"Ayarlar"
  toggle**'ı. `_build_settings_menu()` ortalanmış panel açar (overlay_dim ile).
  İçinde **"Yeni Oyun"** iki adımlı onayla (yanlışlıkla silme koruması) +
  Kapat. Kamera/Görünüm debug butonları (world3d) artık ayrı CanvasLayer'da
  ve **yalnızca Ayarlar açıkken görünür** (`settings_toggled` sinyali →
  `_cam_layer.visible`). HUD'da yalnızca oyun eylemleri kaldı.
- **R2 ana buton (96px):** dolgulu **ink_dark daire** + büyük bağlam ikonu
  (krem) + butonun İÇİNDE alt mini etiket (`CTX_LABELS`: Kes/Kaz/Topla/Aç/
  Ye...). "+"/nişan placeholder'ı **kaldırıldı** (bağlam yokken fist + boş
  etiket).
- **R2 saldırı (72px):** danger pastel dolgu + kılıç + "Saldır" etiketi;
  sadece silahken (mevcut kural). Ana butonla 16px arayla dikey hizalı.
- **R2 "Taşı" (yapı geri-alma) butonu** sağ-alt kümeden çıkarıldı → sol-alt
  kompakt pill (işlev korundu). Sağ altta yalnızca ana+saldırı kaldı.

**Değişen dosyalar:** `scripts/hud.gd`, `scripts/world3d.gd` (yalnız UI gating).

## Aşama 3 — R3 envanter + ORTAK bilgi şeridi bileşeni (commit 3)

**Teşhis → çözüm:**
- **Yerleşim:** Dar sağ şerit **iptal**. Envanter artık **ortalanmış geniş
  panel** (yatay ekran, %80 genişlik: anchor 0.1–0.9) ve **alttan yukarı
  kayar** (bottom-sheet; dikey slide 0.25sn). `HUD.tscn` InventoryRoot
  anchorları + `_on_inventory_toggled` dikey kaymaya çevrildi.
- **Slotlar:** Izgara **4 → 8 sütun** (16 slot tek bakışta, 2 satır). Slot
  64px + %69 ikon (Aşama 1).
- **ORTAK bilgi şeridi (TEK bileşen):** `scripts/ui_info_strip.gd`
  (`UiInfoStrip`) — solda büyük ikon dairesi, ortada ad + **tek satır**
  açıklama (uzun metin `OVERRUN_TRIM_ELLIPSIS` ile "…"), sağda eylem
  pill'leri. **R4/R5'te yeniden kullanılacak.** Envanterde eski dikey bilgi
  kutusu gizlendi, bant panelin altına yaslandı (spacer). Pill'ler:
  **Ye / Kuşan(Bırak) / Yerleştir / At** — hepsi mevcut sinyallere bağlı
  (yeme mantığı değişmedi).
- **Öğretici metin:** "Bir eşyaya dokun…" yalnız **ilk açılışta**; sonra
  kısa "Bir eşya seç." (`_inv_first`), kalıcı yer kaplamaz.

**Değişen/eklenen dosyalar:** `scripts/ui_info_strip.gd` (yeni),
`scripts/hud.gd`, `scenes/HUD.tscn`.

## Aşama 4 — R4 üretim ızgarası + detay bandı + sekmeler (commit 4)

**Teşhis → çözüm:**
- **Liste → ızgara:** Tarifler artık **88px kare kart** (`HFlowContainer`
  akışkan ızgara): kategori dairesi + %65 ikon + altında ad. Satır başına
  Üret **iptal**. Craftlanamayan kart **%55 soluk** + sağ üstte **eksik
  malzeme sayısı** danger rozeti.
- **Detay bandı (ORTAK bileşen):** Karta dokun → alt `UiInfoStrip` bandı
  dolar: büyük ikon + ad + **malzeme çipleri (3/5 yeşil-kırmızı, ikonlu)** +
  **istasyon durumu** ("Tezgah gerekli — yanında değilsin" artık BURADA) +
  TEK büyük **"Üret"**. `set_chips()` bileşene eklendi (R5'te de kullanılır).
- **Kategori sekmeleri:** Sol dikey **56px**, kategori RENKLİ dolgulu daire +
  **ikon** (o kategorinin ilk tarifinin ikonu; "Tümü"=anahtar). Kırpık "Tü/Ma"
  etiketleri **kalktı** (isim tooltip + detay bandında). Aktif sekme 1.08x +
  tam opak.
- **Arama:** Üstte tek satır (mevcut) korundu; kart ızgarası artık üst şeridi
  israf etmiyor.

**Değişen dosyalar:** `scripts/hud.gd`, `scripts/ui_info_strip.gd`,
`scenes/HUD.tscn`.

## Aşama 5 — R5 araştırma + R6 HUD barları + R7 hotbar (commit 5)

**R5 araştırma:**
- Düğüm dairesine **ikon** eklendi (açtığı ilk tarifin ikonu, %65 doluluk);
  **boş bej daireler** kalktı. Kilitli/gizli düğümde ikon **soluk** (desatüre
  hissi) / gizli.
- Taşan "5 Dal + 3 Çakıl Taşı" düğüm metni **kısaltıldı** ("Hazır"/"Malzeme"),
  düğüm etiketi `clip_text`. Tam maliyet artık **alt bilgi bandında ikon+sayı
  çipleri** (`_set_cost_chips`, yeterlilik renkli 3/5). Bant kalıbı korunur
  (ad + açtıkları + maliyet çipleri + "Araştır").

**R6 HUD barları + "Ye":**
- Sol alttaki **krem kutu KALDIRILDI** (StatsPanel zemini `StyleBoxEmpty`).
  3 **çıplak bar** (140x14) + solda 20px ikon + ince koyu kontur; arkada dünya
  görünür. Bar değişiminde (hasar/yeme) **0.3sn nabız** (`_pulse_stat_bar`).
- **"Ye" HUD butonu TAMAMEN KALDIRILDI.** Yeme akışı: hotbarda yiyecek
  seçiliyken ana buton "Ye" bağlamı (R2) + envanter bilgi şeridi "Ye" pill'i.
  Yeme **mantığı değişmedi** (yalnız tetik yüzeyi).

**R7 hotbar:**
- Seçili slot **1.15x + alt nokta** (`ui_slot._draw`). Hotbar **hep 5
  kullanılabilir slot**; kilit ikonları kaldırıldı (kilit yalnız envanterde).

**Değişen dosyalar:** `scripts/ui_research.gd`, `scripts/hud.gd`,
`scripts/ui_slot.gd`.

## Aşama 6 — Doğrulama, önce/sonra, test senaryosu (commit 6)

### ÖNCE → SONRA (özet)
| Alan | ÖNCE (teşhis) | SONRA |
|---|---|---|
| İkon oranı | koca daire + minik ikon | ikon kabın ≥%65'i (slot/dock/kart/bant) |
| Panel odağı | oyun panelin arkasında capcanlı | overlay_dim karartma + HUD gizlenir |
| Kilitli slot | tek tek boş bej daireler | tek çip "+N slot (deri çanta ile)" |
| Sağ butonlar | dağınık beyaz daireler | tek dikey dock: renkli daire + ikon + etiket |
| Yeni Oyun | HUD'da (yanlış basılır) | Ayarlar menüsünde, iki adımlı onay |
| Ana buton | anlamsız "+"/nişan | ink_dark daire + bağlam ikonu + "Kes/Kaz.." |
| Envanter | dar sağ şerit | ortalanmış geniş panel, alttan kayar, 8 sütun |
| Bilgi/detay | sıkışık çok satır | ORTAK bant: ikon+ad+tek satır/çip+pill |
| Üretim | dev boş satırlar, satır başına Üret | 88px kart ızgarası + detay bandı + tek Üret |
| Sekmeler | kırpık "Tü/Ma" | 56px renkli daire + ikon (tooltip) |
| Araştırma | boş bej daireler, taşan maliyet | düğüm ikonu + maliyet çipleri (bantta) |
| HUD barları | hantal krem kutu + "Ye" butonu | çıplak barlar + nabız; "Ye" kaldırıldı |
| Hotbar | 1.12x, kilitli ikonlar | 1.15x + alt nokta; hep 5 slot |

### TEST SENARYOSU (senin için)
1. **Panel karartma:** Çanta/Üretim/Araştırma/Ayarlar aç → arka plan kararır,
   HUD öğeleri kaybolur (Gün pill'i panel başlığıyla çakışmaz). Kapat → geri gelir.
2. **Dock:** Sağ kenarda 3 renkli dolu daire + ikon + altında "Çanta/Üretim/
   Araştırma". Boş krem daire yok.
3. **Ayarlar:** Sağ üst "Ayarlar" → menü açılır; "Yeni Oyun"a bir bas → "Emin
   misin?" → tekrar bas → sıfırlar. Kamera/Görünüm butonları menü açıkken görünür.
4. **Ana/saldırı:** Ağaca yaklaş → ana buton "Kes" + balta ikonu. Silah kuşan →
   72px "Saldır" belirir. "+"/nişan yok. Sağ altta başka şey yok ("Taşı" sol-altta).
5. **Envanter:** Çanta → panel **alttan yukarı** kayar, ortalanmış, **8 sütun**.
   Bir slota dokun → alt bant: ikon+ad+açıklama+**Ye/Kuşan/Yerleştir/At**. İlk
   açılışta öğretici metin, sonra kaybolur.
6. **Üretim:** Kartlar **88px ızgara**. Craftlanamayan soluk + kırmızı eksik-sayı
   rozeti. Karta dokun → alt bant: **malzeme çipleri (3/5 yeşil-kırmızı)** +
   istasyon durumu + tek **Üret**. Sol sekmeler renkli ikon (kırpık etiket yok).
7. **Araştırma:** Düğümlerde **ikon** (kilitli soluk). Düğüme dokun → altta ikon +
   açtıkları + **maliyet çipleri** + "Araştır".
8. **HUD:** Sol altta kutu YOK; 3 çıplak bar. Hasar al → can barı nabız atar.
   Yiyecek ye → açlık barı nabız. Kalıcı "Ye" butonu yok.
9. **Hotbar:** Slot seç → 1.15x + **alt nokta**. Kilitli slot ikonu yok.

### CI doğrulaması
Her aşama `screenshot.yml` ile CI'da doğrulandı: import temiz (parse hatası yok),
oyun tam adım çalıştı, mevcut öz-testler (PLACEUI/CHESTTEST/EATTEST/SAVELOAD/
TOOLDUP/TIMETEST…) korunur — **UI katmanı oyun mantığını bozmadı**. Kareler:
`3d_envanter.png`, `3d_uretim.png`, `3d_arastirma.png`, `3d_yasam.png`.

### Bilinen sınırlar / TODO
- **Envanter bottom-sheet** yatay ekran için ortalanmış geniş panele optimize;
  dikey (portre) telefonda gerçek bottom-sheet oranı ince ayar isteyebilir.
- **Kategori ikonları** temsilîdir (kategorinin ilk tarifinin ikonu); özel
  kategori ikonları ileride eklenebilir.
- **Araştırma düğüm maliyeti** düğüm içinde kısa durum ("Hazır/Malzeme");
  tam ikon+sayı çipleri alt bantta (küçük kart içine sığdırmak yerine).
- **"Taşı" (yapı geri-alma)** sol-alta taşındı; ileride Ayarlar/bağlam menüsüne
  de alınabilir.
- Gündüz/gece, kayıt, yaşam, base sistemleri **dokunulmadı** (yalnız UI).

