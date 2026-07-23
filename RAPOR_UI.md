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


---

## ENVANTER-MOCKUP — Sırt Çantası UI'ı mockup'a göre yeniden (branch: envanter-mockup)

**Tek doğruluk kaynağı:** `assets/mockups/backpack_ui_mockup.html`. UI_DESIGN /
REVIZYON ile çelişen her yerde mockup kazandı.

### Uygulananlar (mockup birebir)
1. **Sayfa:** %84 yükseklik, %96 genişlik, alta yaslı; 24px üst köşe; yükselme
   0.3sn ease-out; arkada karartma (mevcut backdrop). Zeminde çok soluk nokta
   dokusu (`ui_dots.gd`, 14px ızgara).
2. **İmza öğeler:** dikişli deri tutamaç (`ui_handle.gd`, 84×12 + kesik dikiş),
   panelden taşan koyu kahve sekme **"Sırt Çantası"** + doluluk **sekmenin
   içinde** ("14/16"), sağ üstte yuvarlak krem kapatma butonu (44px + gölge).
3. **Izgara 8×2:** 8 sütun sabit; slot boyu ekrana esner (64–104px, mockup 1fr).
   Kategori renkli daire slotlar + krem kapsül stack rozeti (daire dışına
   taşar) + boş slot soluk krem + seçili slotta **çift halka**. Kilitli slotlar
   çizilmez; tek çip: "🔒 +N slot · deri çanta ile" (kilit ikon + metin).
4. **Bilgi şeridi:** 68px ikon dairesi + ad + TEK satır flavor ("..." kırpma) +
   duruma göre pill'ler: Ye/Kuşan/Yerleştir dolgulu koyu, **At kırmızı
   KONTURLU** (danger).
5. **Dokunuş:** slot basışta %92 küçülme, pill basışta %94 pop (adlı
   fonksiyonlar — cihaz-kırılganlığı dersi gereği inline lambda YOK).
6. **Sandık aynı dil:** alttan sayfa + "Sandık" sekmesi + yuvarlak kapat +
   doku/tutamaç; içerik **iki kardeş sütun** (sol: Sandık + "Tümünü Al";
   sağ: Sırt Çantası + "Tümünü Koy"), sütun başlıkları koyu mini çip.
   Aktarım sinyalleri/oyun mantığı AYNEN korunmuştur.

### Mockup'tan sapmalar (gerekçeli)
- **Kilit çipi ızgaranın içinde değil altında:** GridContainer'da hücre
  birleştirme (span) yok; çip ızgara sonunda ayrı satırda. Görsel dil aynı.
- **Flavor "flavor" alanı olarak ayrı sözlükte** (`items.gd FLAVOR`):
  ITEMS satır yapısını (name+icon) bozmamak için; `description()` önce
  FLAVOR'a bakar. İşlevsel olarak istenenle aynı.
- **Sandık çift paneli tek sayfada iki sütun:** iki ayrı yüzen panel yerine
  tek sheet içinde kardeş sütunlar — mevcut aktarım listesi korunarak en
  düşük riskli birebir karşılık.
- Mockup'taki emoji ikonlar yerine oyunun mevcut 32px item ikonları
  (UI_DESIGN R0 kuralı; emoji fontu cihazda garanti değil).

### Flavor yazılan itemler (55)
Mockup başlangıç seti uyarlandı: odun, tas, yaprak(lif), meyve, pismis_et,
kova_dolu, mizrak, tohum, oz, merdiven, balta, ahsap_duvar. Aynı seste
yazılanlar: kalas, cubuk, ip, cakil, toprak, kil, kum, bakir, komur, altin,
cicek, mantar, cig_et, kazma, kurek, bicak, cekic, kova, metal_kova, sopa,
kilic, yay, sapan, ok, zirh, sapka, kukla, canta, tas_duvar, kapi, zemin,
tezgah, arastirma_masasi, kamp_evi, sandik, mesale, yatak, tuzak, ocak,
platform, kazik, boru, pompa, vana. Sayılar oyun verisiyle doğrulandı
(FOOD_SATIATION, hasar/koruma değerleri).

### Ekran oranı testi (8 sütun sabit, slot 64px altına düşmez)
- **16:9 (1280×720):** sheet 1228px; hücre (1184−84)/8 = 137 → üst sınır
  104px uygulanır. Izgara 916px, ortalanır. Dikey: 604px sayfada ızgara
  2×104 + şerit ~90 + tutamaç → bolca yer. ✔
- **19.5:9 (1560×720):** hücre 171 → yine 104px (üst sınır). ✔
- Alt sınır 64px yalnız <700px genişlikte devreye girer (hedef cihazlarda
  yok); formül: `clamp((0.96·W − 44 − 7·12)/8, 64, 104)`.

### Test adımları (telefonda)
1. Çanta aç: panel alttan 0.3sn'de yükseliyor mu, sekme "Sırt Çantası 14/16"?
2. Tutamaç dikişli, zeminde hafif nokta dokusu var mı?
3. Eşyaya dokun: çift halka + altta ad/flavor + pill'ler; At kırmızı konturlu mu?
4. Slot basışta küçülüyor, pill basışta pop yapıyor mu?
5. Doluluk sekmede güncelleniyor mu (eşya at/al)?
6. Sandığa dokun: aynı dil, iki sütun, Al/Koy çalışıyor mu?
7. Kapat (yuvarlak buton): oyun devam ediyor mu (girdi kilidi yok)?
- **Sekme gölgesi kaldırıldı:** Godot StyleBoxFlat gölgesi blursuz (ofsetli
  ikinci kutu gibi çizilir); koyu zeminde "çift sekme" yanılsaması yapıyordu.
  Mockup'ın yumuşak blur'una StyleBoxFlat ile ulaşılamıyor — sapma gerekçesi.
