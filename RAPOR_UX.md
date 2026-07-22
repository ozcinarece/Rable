# RAPOR — Uzman UI/UX Denetimi + İyileştirme

Branch: `ux-denetim`. Anayasa: UI_DESIGN.md + UI_REVIZYON_1.md (krem/pastel
dil DEĞİŞMEZ). Oyun mantığına dokunulmadı — yalnız UI katmanı + girdi yüzeyleri.

> **Önemli bağlam:** Bu denetimden hemen önce, bir HUD değişikliği **cihazda**
> (Android export) `_ready`'yi yarıda patlatıp arayüzü kilitledi; CI'da (1280×720
> editor-import) görünmüyordu. Ders: **HUD kodu cihaza duyarlı**. Bu yüzden Perde 2'de
> yalnız **küçük, güvenli, deseni bozmayan** değişiklikler yapıldı (adlı fonksiyonlar,
> mevcut stil kalıpları; riskli çok-satırlı inline lambda YOK) ve her biri ayrı commit.

---

## HUD LAYOUT HARİTASI (denetimin temeli)

Kod, `.tscn` konumlarını `_ready`'de yeniden yerleştiriyor. Gerçek yerleşim:
- **Gün pill** (Gün X): sol üst (16,16).
- **Ayarlar** (eski "Yeni Oyun" butonu): sağ üst.
- **Dock** (Çanta / Üretim / Araştırma): sağ kenar, `anchor 0.44` (dikey orta),
  aşağı doğru ~288px büyür → ~0.84H'ye iner.
- **Barlar** (can/açlık/su): sol alt.
- **Taşı** (yapı geri-alma modu): sol alt, barların üstünde.
- **Hotbar**: alt orta.
- **Ana buton** (96px, bağlam eylemi): sağ alt (96–192px dipten).
- **Saldırı** (72px, silahken): sağ alt (208–280px dipten).
- **Hareket**: parmağı bas-sürükle = sanal joystick (her yerde).

---

## PERDE 1 — DENETİM BULGULARI (ekran ekran)

### HUD — genel

**P0 · Dock ile Saldırı butonu çakışıyor** (kullanıcı bildirdi: "saldır ile
araştırma üst üste")
- Kanıt: Dock `anchor 0.44`'ten aşağı ~288px büyüyor (≈0.44H→0.84H). Saldırı
  butonu dipten 208–280px (≈0.61H–0.72H, H=720). İkisi de sağ kenarda (dock
  16–84px, saldırı 36–108px sağdan) → **Araştırma düğmesi Saldırı'nın üstüne
  biniyor**. Geniş oranlı telefonda daha da belirgin.
- Öneri: Dock çıpasını yukarı al (`0.44 → ~0.30`) ki aşağı büyürken alt-sağ
  eylem kümesine değmesin. (UYGULANDI — P0-1.)

**P0 · Sanal joystick ile sol-alt UI çakışması riski**
- Kanıt: Hareket "her yerde bas-sürükle". Sol altta Barlar + "Taşı" butonu var.
  "Taşı" butonu `MOUSE_FILTER_STOP` → orada başlayan sürükleme joystick'i
  tetiklemez (buton yutar). Barlar salt-görsel; onların üstünde sürükleme
  çalışır ama görsel olarak "buraya basma" hissi vermiyor.
- Öneri: Barları `MOUSE_FILTER_IGNORE` yap (zaten görselse), "Taşı" küçük kalsın.
  Düşük etki; P1 olarak işaretlendi.

**P1 · "Taşı" butonu keşfedilebilir değil**
- Kanıt: "Taşı" = yapı geri-alma modu; ama yeni oyuncu ne yaptığını anlamaz
  (ikon yok, sadece metin). Nadir bir eylem sürekli ekranda.
- Öneri: İkon ekle (el/taşıma) veya Ayarlar/uzun-basış altına gizle. P1.

**P1 · Ayarlar butonu metin ("Ayarlar") — dock ikon dilinden kopuk**
- Kanıt: Sağ üstte düz metinli buton; gerisi ikon-pill. R1 "debug butonları
  Ayarlar'a" diyor ama Ayarlar'ın kendisi de dişli ikonuyla olmalı.
- Öneri: Dişli (⚙) ikonu + küçük etiket. P1.

### Envanter paneli
**P1 · İlk-açılış öğretici metni kalıcı** (UI_REVIZYON R3: "bir kez")
- Kanıt: InfoStrip'te "Bir eşyaya dokun..." metni her zaman duruyor (seçim yokken).
  Kural "ilk açılışta bir kez" diyor.
- Öneri: seçim yokken kısa ipucu kalabilir ama "bir kez" davranışı için bir
  `seen` bayrağı. Düşük öncelik (mevcut hâli zararsız). P1/P2 sınırı.

### Üretim paneli
**P1 · Kategori sekmeleri kırpılma riski** — "Tümü" + 7 kategori dikeyde;
küçük ekranda taşabilir. Kanıt: `_build_category_buttons` 8 pill dikey. Öneri:
scroll veya 2 sütun. P1 (ekran boyuna bağlı).

### Araştırma paneli
**P0 · (DÜZELTİLDİ) Kapatınca girdi kilidi** — panel kendi X'iyle kapanınca
overlay inmiyordu → tüm ekran kilitleniyordu. Hotfix'te `_on_research_closed`
ile çözüldü (adlı fonksiyon).

### Ayarlar / Kamera
**P0 · (DÜZELTİLDİ) Kamera paneli tıklanamıyordu** — HUD overlay (layer 3)
kamera panelini (layer 2) örtüyordu → layer 4'e alındı.
**Görünüm bölümü kaldırıldı** (kullanıcı isteği).

### Başlangıç menüsü (Devam Et / Yeni Oyun)
**P0? · Tıklanamama şikâyeti (doğrulanamadı)** — kod incelemesinde layer 80'de,
önünde engel yok, ağaç duraklatılmıyor. Butonlar sağlamlaştırıldı (PrimaryButton
+ STOP filtre). Cihaz doğrulaması bekliyor.

### Ölüm / doğuş, uyku, gece uyarısı
**P1 · Gün-sonu / ölüm özeti yok** (F: eksik parça). Ölünce sadece "Yeniden
doğdun" floating text. Öneri: kısa özet pill'i. → P2 (Onay Bekleyen).

---

## PERDE 2 — UYGULANAN DÜZELTMELER

### P0-1 · Dock/Saldırı çakışması (UYGULANDI)
- **Önce:** `dock.anchor_top/bottom = 0.44` → dock aşağı büyürken Araştırma,
  Saldırı butonunun üstüne biniyordu.
- **Sonra:** `0.30` — dock daha yukarıda başlar, alt-sağ eylem kümesine değmez.
  Tek satır, güvenli (mevcut anchor mantığı).

---

## ONAY BEKLEYEN P2'LER (senin seçimin — gerekçeli)

1. **Ayarlar içeriği: Ses aç/kapa + titreşim** — şu an Ayarlar'da kalite + FPS
   var; ses/titreşim yok. Etki: yüksek (temel mobil beklentisi). Risk: düşük.
2. **Duraklatma davranışı** — panel açıkken oyun devam ediyor (açlık akıyor).
   Tek-oyuncu için panel açıkken `get_tree().paused = true` düşünülebilir. Etki:
   orta. Risk: orta (autoload'lar process_mode ayarı ister). **Karar senin.**
3. **Hotbar'a hızlı eşya atama** — envanterden bir eşyayı hotbar slotuna atama
   yolu yok. Etki: yüksek (oynanış akıcılığı). Risk: orta.
4. **Etkileşim ipucu balonu** — hedefin üstünde mini ikon (ağaç=balta, kaya=kazma).
   Etki: orta (keşfedilebilirlik). Risk: düşük.
5. **Hasar yönü göstergesi** — hasar alınca ekran kenarında yön parıltısı. Etki:
   orta (yaratık fazında kritik). Risk: düşük.
6. **Gün-sonu / ölüm özeti pill'i** — "Gün 3 bitti: +2 öz, 1 ölüm". Etki: orta.
   Risk: düşük.
7. **Sol-el modu** — joystick/buton yerlerini yatay aynala (Ayarlar toggle).
   Etki: erişilebilirlik. Risk: orta.

---

## SENİN İÇİN 10 DAKİKALIK KONTROL TURU (telefonda, sıralı)

1. **Açılış:** Oyun açılıyor mu? HUD krem/pastel, ikonlar dolu mu? (patlama testi)
2. **Sağ kenar:** Çanta/Üretim/Araştırma dock'u Saldırı butonuyla çakışıyor mu?
   (P0-1 sonrası çakışmamalı.)
3. **Araştırma:** Aç → X ile kapat → oyun devam ediyor mu? (kilit testi)
4. **Ayarlar:** Aç → Kamera yakınlık/açı kaydırıcıları çalışıyor mu? Görünüm yok mu?
5. **Envanter:** Aç → eşyaya dokun → alt bilgi şeridi geliyor mu? X ile kapat.
6. **Üretim:** Kategori sekmeleri sığıyor mu, kart→detay bandı akıcı mı?
7. **Yerleştirme:** Bir duvar eline al → hayalet + Onayla/Döndür/İptal net mi?
8. **Saldırı:** Silah eline al → Saldırı butonu çıkıyor mu, ana butonla karışmıyor mu?
9. **Hareket:** Bas-sürükle joystick sol-alt barlarla/Taşı ile takışıyor mu?
10. **Balta:** Elde balta sapından mı tutuluyor?
